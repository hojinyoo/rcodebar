import Foundation
import Network
import AppKit
import OSLog

private let log = Logger(subsystem: "com.hojinyoo.rcodebar", category: "listener")

/// Owns the TCP channel the pod's `code` talks to. Bound to loopback only —
/// never widen this to all interfaces, the pod is assumed multi-user.
@MainActor
final class Listener {
    static let port: NWEndpoint.Port = 47000

    private var listener: NWListener?
    private let store: HostStore

    private(set) var isRunning = false

    init(store: HostStore) {
        self.store = store
    }

    func start() {
        guard listener == nil else { return }

        // requiredInterfaceType (not requiredLocalEndpoint, which errors EINVAL
        // for inbound listeners) is what actually restricts this to loopback —
        // unreachable from any real network interface. Never widen this.
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true

        guard let listener = try? NWListener(using: params, on: Self.port) else {
            log.error("failed to create listener on port \(Self.port.rawValue)")
            return
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                Task { @MainActor in self?.stop() }
            }
        }
        listener.start(queue: .main)
        self.listener = listener
        isRunning = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection, buffer: LineBuffer())
    }

    private func receive(_ connection: NWConnection, buffer: LineBuffer) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: LineBuffer.capBytes) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                var buffer = buffer
                if let data, !data.isEmpty {
                    switch buffer.append(data) {
                    case .needMore:
                        if isComplete || error != nil {
                            connection.cancel()
                        } else {
                            self.receive(connection, buffer: buffer)
                        }
                    case .line(let line):
                        self.handle(line: line, on: connection)
                    case .tooLong:
                        self.respond("ERR too long", on: connection)
                    }
                } else if isComplete || error != nil {
                    connection.cancel()
                } else {
                    self.receive(connection, buffer: buffer)
                }
            }
        }
    }

    private func handle(line: String, on connection: NWConnection) {
        switch RequestParser.parse(line, whitelist: store.whitelist) {
        case .ok(let host, let uri):
            guard let url = URL(string: uri) else {
                respond("ERR invalid uri", on: connection)
                return
            }
            NSWorkspace.shared.open(url)
            let path = String(uri.dropFirst(RequestParser.prefix.count + host.count))
            store.recordOpen(host: host, path: path, date: Date())
            respond("OK", on: connection)
        case .err(let reason):
            respond("ERR \(reason)", on: connection)
        }
    }

    private func respond(_ message: String, on connection: NWConnection) {
        let data = Data("\(message)\n".utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
