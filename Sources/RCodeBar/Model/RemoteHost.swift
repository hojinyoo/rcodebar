import Foundation

enum HostStatus: Equatable {
    case green   // tunnel up end to end
    case amber   // ssh works, RemoteForward missing
    case grey    // no ssh connection
    case unknown // not probed yet

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
    var lastOpenDate: Date?
    var lastOpenPath: String?

    var id: String { alias }
}
