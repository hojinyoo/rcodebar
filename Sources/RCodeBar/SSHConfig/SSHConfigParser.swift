import Foundation
import Darwin

/// Discovers host aliases by parsing ~/.ssh/config and following `Include`
/// directives — the same files ssh itself reads, so this stays in sync with
/// whatever config.d layout the user actually has. Read-only, never writes.
enum SSHConfigParser {
    /// file/glob readers are injectable so tests never touch the real filesystem.
    static func discoverHosts(
        from entryPath: String,
        readFile: (String) -> String? = defaultRead,
        expandGlob: (String) -> [String] = defaultGlob
    ) -> [String] {
        var visited = Set<String>()
        var queue = [entryPath]
        var seen = Set<String>()
        var ordered: [String] = []

        while !queue.isEmpty {
            let path = queue.removeFirst()
            guard !visited.contains(path) else { continue }
            visited.insert(path)
            guard let content = readFile(path) else { continue }

            for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty, !line.hasPrefix("#") else { continue }
                let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }

                switch parts[0].lowercased() {
                case "include":
                    for token in parts[1].split(separator: " ") {
                        queue.append(contentsOf: expandGlob(String(token)))
                    }
                case "host":
                    let tokens = parts[1].split(separator: " ").map(String.init)
                    if let alias = concreteAlias(from: tokens), !seen.contains(alias) {
                        seen.insert(alias)
                        ordered.append(alias)
                    }
                default:
                    continue
                }
            }
        }
        return ordered
    }

    /// `Host *` and other pure-wildcard-only entries are not real, connectable
    /// hosts — skip them. `ldev ldev*` offers the concrete first token
    /// (`ldev`); `cys*` alone offers `cys` (this config's own convention: the
    /// wildcard base is itself a valid alias). Anything left wildcarded on
    /// both ends (`*_jupy*`) is a forwarding shortcut, not a host — skipped.
    static func concreteAlias(from tokens: [String]) -> String? {
        let globChars = CharacterSet(charactersIn: "*?[]!")
        guard !tokens.isEmpty, tokens != ["*"] else { return nil }

        for token in tokens where token != "*" {
            if token.rangeOfCharacter(from: globChars) == nil {
                return token
            }
        }
        for token in tokens where token != "*" {
            var stripped = token
            while stripped.hasSuffix("*") { stripped.removeLast() }
            if !stripped.isEmpty, stripped.rangeOfCharacter(from: globChars) == nil {
                return stripped
            }
        }
        return nil
    }

    private static func defaultRead(_ path: String) -> String? {
        try? String(contentsOfFile: (path as NSString).expandingTildeInPath, encoding: .utf8)
    }

    private static func defaultGlob(_ pattern: String) -> [String] {
        let expanded = (pattern as NSString).expandingTildeInPath
        var gt = glob_t()
        defer { globfree(&gt) }
        guard glob(expanded, 0, nil, &gt) == 0 else { return [] }
        return (0..<Int(gt.gl_matchc)).compactMap { i in
            gt.gl_pathv[i].map { String(cString: $0) }
        }
    }
}
