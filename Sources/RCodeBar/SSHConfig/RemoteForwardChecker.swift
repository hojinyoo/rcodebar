import Foundation

/// Asks ssh itself whether a host's effective config (Include, patterns, and
/// all) carries the RemoteForward for our port — parsing config files can
/// tell us a host exists, but not whether ssh will actually apply the
/// forward, so this shells out to `ssh -G` instead of re-deriving it.
enum RemoteForwardChecker {
    private static let sshPath = "/usr/bin/ssh"

    static func hasForward(in sshGOutput: String, port: Int) -> Bool {
        for line in sshGOutput.split(separator: "\n") {
            let parts = line.split(separator: " ")
            guard parts.count >= 2, parts[0].lowercased() == "remoteforward" else { continue }
            if parts[1] == String(port) { return true }
        }
        return false
    }

    static func check(host: String, port: Int = 47000) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshPath)
            process.arguments = ["-G", host]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                continuation.resume(returning: hasForward(in: output, port: port))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
