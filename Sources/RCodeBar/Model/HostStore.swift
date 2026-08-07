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

    // Disabled hosts must be rejected exactly like unknown ones — the
    // listener whitelist is this set, so excluding them here is sufficient.
    var whitelist: Set<String> { Set(hosts.filter(\.enabled).map(\.alias)) }

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

    func setEnabled(alias: String, enabled: Bool) {
        guard let index = hosts.firstIndex(where: { $0.alias == alias }) else { return }
        hosts[index].enabled = enabled
        persist()
    }

    func setDisplayName(alias: String, name: String) {
        guard let index = hosts.firstIndex(where: { $0.alias == alias }) else { return }
        hosts[index].displayName = name.trimmingCharacters(in: .whitespaces)
        persist()
    }

    func setDefaultPath(alias: String, path: String) {
        guard let index = hosts.firstIndex(where: { $0.alias == alias }) else { return }
        hosts[index].defaultPath = path.trimmingCharacters(in: .whitespaces)
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
