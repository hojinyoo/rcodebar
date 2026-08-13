import Foundation
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    let store: HostStore
    let listener: Listener

    @Published var probeResults: [String: ProbeResult] = [:]
    @Published var forwardStatus: [String: Bool] = [:] // nil (absent) = not checked yet
    @Published private(set) var discoveredAliases: [String] = []

    private var timer: Timer?
    private var storeChanges: AnyCancellable?

    init() {
        let store = HostStore()
        self.store = store
        self.listener = Listener(store: store)
        // SwiftUI does not follow a nested ObservableObject: without this the
        // popover only picks up host/toggle edits on the next 30s probe tick.
        storeChanges = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        if store.autoOpenEnabled {
            listener.start()
        }
        refreshStatuses()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatuses() }
        }
    }

    var liveHostCount: Int {
        probeResults.values.filter { $0.status == .green }.count
    }

    func toggleAutoOpen() {
        store.autoOpenEnabled.toggle()
        if store.autoOpenEnabled {
            listener.start()
        } else {
            listener.stop()
        }
    }

    func refreshStatuses() {
        discoveredAliases = SSHConfigParser.discoverHosts(from: "~/.ssh/config")
        for host in store.hosts {
            testNow(alias: host.alias)
        }
    }

    /// Runs the probe for one host immediately, outside the 30s cadence —
    /// backs both the periodic refresh and the popover's "Test Now" button.
    func testNow(alias: String) {
        if probeResults[alias] == nil {
            probeResults[alias] = ProbeResult(status: .unknown, detail: nil)
        }
        Task {
            let result = await StatusChecker.probe(host: alias)
            self.probeResults[alias] = result
        }
    }

    func checkForward(alias: String) {
        Task {
            let hasForward = await RemoteForwardChecker.check(host: alias)
            self.forwardStatus[alias] = hasForward
        }
    }

    /// Hosts discovered by parsing ~/.ssh/config (following Include), minus
    /// ones already added — feeds the popover's picker. Reads off the cached
    /// list: parsing here would re-read the file on every render of the popover.
    var discoverableHosts: [String] {
        let existing = Set(store.hosts.map(\.alias))
        return discoveredAliases.filter { !existing.contains($0) }
    }

    /// Manual "Open" trigger from a host row's default path — same URI
    /// shape and NSWorkspace.open call the listener uses, just without the
    /// network hop.
    func openNow(host: RemoteHost) {
        guard let path = host.defaultPath, !path.isEmpty else { return }
        let uri = "\(RequestParser.prefix)\(host.alias)\(path)"
        guard let url = URL(string: uri) else { return }
        NSWorkspace.shared.open(url)
        store.recordOpen(host: host.alias, path: path, date: Date())
    }

    /// Only ever called after the user confirms in the UI — writes a new
    /// file under config.d/, never touches an existing one.
    func addRemoteForward(alias: String) -> Result<String, Error> {
        do {
            let path = try SSHConfigWriter.writeRemoteForwardSnippet(alias: alias)
            checkForward(alias: alias)
            return .success(path)
        } catch {
            return .failure(error)
        }
    }
}
