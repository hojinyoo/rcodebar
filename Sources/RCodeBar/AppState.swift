import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let store: HostStore
    let listener: Listener

    @Published var statuses: [String: HostStatus] = [:]

    private var timer: Timer?

    init() {
        let store = HostStore()
        self.store = store
        self.listener = Listener(store: store)
        if store.autoOpenEnabled {
            listener.start()
        }
        refreshStatuses()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatuses() }
        }
    }

    var liveHostCount: Int {
        statuses.values.filter { $0 == .green }.count
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
        for host in store.hosts {
            let alias = host.alias
            statuses[alias] = statuses[alias] ?? .unknown
            Task {
                let status = await StatusChecker.probe(host: alias)
                self.statuses[alias] = status
            }
        }
    }
}
