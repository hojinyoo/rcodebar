import Foundation
import Combine

/// UserDefaults-backed settings and host list — no config file, per BRIEF.md.
@MainActor
final class HostStore: ObservableObject {
    private enum Keys {
        static let hosts = "hosts"
        static let autoOpen = "autoOpenEnabled"
    }

    @Published private(set) var hosts: [RemoteHost] = []
    @Published var autoOpenEnabled: Bool {
        didSet { defaults.set(autoOpenEnabled, forKey: Keys.autoOpen) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoOpenEnabled = defaults.object(forKey: Keys.autoOpen) as? Bool ?? true
        self.hosts = Self.load(from: defaults)
    }

    var whitelist: Set<String> { Set(hosts.map(\.alias)) }

    func addHost(alias: String) {
        let trimmed = alias.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !hosts.contains(where: { $0.alias == trimmed }) else { return }
        hosts.append(RemoteHost(alias: trimmed))
        persist()
    }

    func removeHost(alias: String) {
        hosts.removeAll { $0.alias == alias }
        persist()
    }

    func recordOpen(host: String, path: String, date: Date) {
        guard let index = hosts.firstIndex(where: { $0.alias == host }) else { return }
        hosts[index].lastOpenDate = date
        hosts[index].lastOpenPath = path
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(hosts) else { return }
        defaults.set(data, forKey: Keys.hosts)
    }

    private static func load(from defaults: UserDefaults) -> [RemoteHost] {
        guard let data = defaults.data(forKey: Keys.hosts),
              let decoded = try? JSONDecoder().decode([RemoteHost].self, from: data) else {
            return []
        }
        return decoded
    }
}
