import Foundation

/// Result of validating one request line against the trust boundary: fixed
/// prefix, host on the whitelist, nothing else ever reaches NSWorkspace.open.
enum ParseResult: Equatable {
    case ok(host: String, uri: String)
    case err(String)
}

enum RequestParser {
    static let prefix = "vscode://vscode-remote/ssh-remote+"

    static func parse(_ line: String, whitelist: Set<String>) -> ParseResult {
        guard line.hasPrefix(prefix) else { return .err("invalid uri") }
        let rest = line.dropFirst(prefix.count)
        guard let slash = rest.firstIndex(of: "/"), rest.startIndex != slash else {
            return .err("invalid uri")
        }
        let host = String(rest[rest.startIndex..<slash])
        guard whitelist.contains(host) else { return .err("unknown host") }
        return .ok(host: host, uri: line)
    }
}
