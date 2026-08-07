import SwiftUI

struct HostRow: View {
    let host: RemoteHost
    let status: HostStatus
    let onCopySnippet: () -> Void
    let onRemove: () -> Void

    private var dotColor: Color {
        switch status {
        case .green: return .green
        case .amber: return .yellow
        case .grey: return .gray
        case .unknown: return .gray.opacity(0.4)
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
                .help(status.label)

            VStack(alignment: .leading, spacing: 2) {
                Text(host.alias).font(.system(size: 13, weight: .medium))
                if let path = host.lastOpenPath, let date = host.lastOpenDate {
                    Text("\(path) · \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("never opened")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Copy Snippet", action: onCopySnippet)
                .buttonStyle(.link)
                .font(.caption)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
