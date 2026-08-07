import Foundation

enum SSHConfigWriterError: Error {
    case couldNotCreateDirectory
}

/// The only thing allowed to touch the user's ssh config, and only after
/// explicit confirmation in the UI. Always a brand-new file under
/// config.d/ — never an edit into the middle of an existing one.
enum SSHConfigWriter {
    static func remoteForwardSnippetPath(alias: String) -> String {
        "~/.ssh/config.d/rcodebar-\(alias)"
    }

    @discardableResult
    static func writeRemoteForwardSnippet(alias: String) throws -> String {
        let path = (remoteForwardSnippetPath(alias: alias) as NSString).expandingTildeInPath
        let dir = (path as NSString).deletingLastPathComponent
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir, isDirectory: &isDir) {
            guard (try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)) != nil else {
                throw SSHConfigWriterError.couldNotCreateDirectory
            }
        }
        let content = """
        Host \(alias)
             RemoteForward 47000 127.0.0.1:47000
        """ + "\n"
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }
}
