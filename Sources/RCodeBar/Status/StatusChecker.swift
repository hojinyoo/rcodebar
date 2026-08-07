import Foundation

/// Per-host tunnel probe from BRIEF.md:
///   ssh -o BatchMode=yes -o ConnectTimeout=3 <host> 'exec 3<>/dev/tcp/127.0.0.1/47000'
/// rc 0 -> green, ssh ok but that fails -> amber, ssh itself fails -> grey.
/// Always the absolute /usr/bin/ssh: a GUI app has no shell PATH.
enum StatusChecker {
    private static let sshPath = "/usr/bin/ssh"
    private static let probeCommand = "exec 3<>/dev/tcp/127.0.0.1/47000"

    /// Runs off the calling thread's async context — never call from the UI thread synchronously.
    static func probe(host: String) async -> HostStatus {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshPath)
            process.arguments = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=3",
                host,
                probeCommand,
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { proc in
                // ssh's own connect/auth failures exit 255; anything else nonzero
                // means ssh reached the host and the remote command itself failed.
                switch proc.terminationStatus {
                case 0: continuation.resume(returning: .green)
                case 255: continuation.resume(returning: .grey)
                default: continuation.resume(returning: .amber)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .grey)
            }
        }
    }
}
