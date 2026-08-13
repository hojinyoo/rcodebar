import Foundation

enum HostStatus: Equatable {
    case green  // tunnel up end to end
    case amber  // ssh works, RemoteForward missing
    case grey  // no ssh connection
    case unknown  // not probed yet

    var label: String {
        switch self {
        case .green: return "Connected"
        case .amber: return "RemoteForward missing"
        case .grey: return "No connection"
        case .unknown: return "Checking…"
        }
    }
}

/// Persisted fields only. `status` is runtime/transient — probed live, never saved.
struct RemoteHost: Codable, Identifiable, Equatable {
    var alias: String
    var displayName: String?
    var defaultPath: String?
    var enabled: Bool
    var lastOpenDate: Date?
    var lastOpenPath: String?

    var id: String { alias }

    var effectiveDisplayName: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? alias : trimmed
    }

    init(
        alias: String, displayName: String? = nil, defaultPath: String? = nil, enabled: Bool = true,
        lastOpenDate: Date? = nil, lastOpenPath: String? = nil
    ) {
        self.alias = alias
        self.displayName = displayName
        self.defaultPath = defaultPath
        self.enabled = enabled
        self.lastOpenDate = lastOpenDate
        self.lastOpenPath = lastOpenPath
    }

    // Custom decode: `enabled` didn't exist in hosts persisted by earlier
    // versions — default it to true rather than failing to decode them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alias = try c.decode(String.self, forKey: .alias)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        defaultPath = try c.decodeIfPresent(String.self, forKey: .defaultPath)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        lastOpenDate = try c.decodeIfPresent(Date.self, forKey: .lastOpenDate)
        lastOpenPath = try c.decodeIfPresent(String.self, forKey: .lastOpenPath)
    }
}
