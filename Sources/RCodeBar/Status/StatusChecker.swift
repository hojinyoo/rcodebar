import Foundation

struct ProbeResult: Equatable {
    var status: HostStatus
    var detail: String? // ssh's stderr tail, only set when status isn't green
}

/// Per-host tunnel probe from BRIEF.md:
///   ssh -o BatchMode=yes -o ConnectTimeout=3 <host> 'exec 3<>/dev/tcp/127.0.0.1/47000'
/// rc 0 -> green, ssh ok but that fails -> amber, ssh itself fails -> grey.
/// Always the absolute /usr/bin/ssh: a GUI app has no shell PATH.
enum StatusChecker {
    private static let sshPath = "/usr/bin/ssh"
    private static let probeCommand = "exec 3<>/dev/tcp/127.0.0.1/47000"
    private static let detailTailLines = 3

    /// Runs off the calling thread's async context — never call from the UI thread synchronously.
    static func probe(host: String) async -> ProbeResult {
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
            let errorPipe = Pipe()
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrText = String(decoding: data, as: UTF8.self)
                // ssh's own connect/auth failures exit 255; anything else nonzero
                // means ssh reached the host and the remote command itself failed.
                switch proc.terminationStatus {
                case 0:
                    continuation.resume(returning: ProbeResult(status: .green, detail: nil))
                case 255:
                    continuation.resume(returning: ProbeResult(status: .grey, detail: tail(stderrText)))
                default:
                    continuation.resume(returning: ProbeResult(status: .amber, detail: tail(stderrText)))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: ProbeResult(status: .grey, detail: "\(error)"))
            }
        }
    }

    private static func tail(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: "\n").suffix(detailTailLines).joined(separator: "\n")
    }
}
