import SwiftUI
import AppKit

struct HostRow: View {
    @ObservedObject var state: AppState
    let host: RemoteHost
    let onRemove: () -> Void

    @State private var expanded = false
    @State private var displayName = ""
    @State private var defaultPath = ""
    @State private var showAddForwardConfirm = false
    @State private var showAddForwardResult = false
    @State private var addForwardMessage = ""

    private var status: HostStatus { state.probeResults[host.alias]?.status ?? .unknown }
    private var detail: String? { state.probeResults[host.alias]?.detail }
    private var hasForward: Bool? { state.forwardStatus[host.alias] }

    private var dotColor: Color {
        switch status {
        case .green: return .green
        case .amber: return .yellow
        case .grey: return .gray
        case .unknown: return .gray.opacity(0.4)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                    .help(status.label)

                VStack(alignment: .leading, spacing: 2) {
                    Text(host.effectiveDisplayName).font(.system(size: 13, weight: .medium))
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

                Button {
                    expanded.toggle()
                    if expanded { state.checkForward(alias: host.alias) }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }

            if expanded {
                detailPanel
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            displayName = host.displayName ?? ""
            defaultPath = host.defaultPath ?? ""
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Display name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { state.store.setDisplayName(alias: host.alias, name: displayName) }

            HStack {
                TextField("Default path (e.g. /home/dev/project)", text: $defaultPath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.store.setDefaultPath(alias: host.alias, path: defaultPath) }
                Button("Open") { state.openNow(host: host) }
                    .disabled(defaultPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Toggle("Enabled", isOn: Binding(
                get: { host.enabled },
                set: { state.store.setEnabled(alias: host.alias, enabled: $0) }
            ))

            HStack {
                Button("Test Now") { state.testNow(alias: host.alias) }
                if status != .green, let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            forwardRow

            Button("Copy Snippet", action: copySnippet)
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.leading, 16)
        .alert("RemoteForward added", isPresented: $showAddForwardResult) {
            Button("OK") {}
        } message: {
            Text(addForwardMessage)
        }
    }

    private var forwardRow: some View {
        Group {
            switch hasForward {
            case .none:
                Text("Checking RemoteForward…").font(.caption).foregroundStyle(.secondary)
            case .some(true):
                Label("RemoteForward configured", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            case .some(false):
                VStack(alignment: .leading, spacing: 4) {
                    Label("RemoteForward missing", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                    Button("Add RemoteForward…") { showAddForwardConfirm = true }
                        .font(.caption)
                }
            }
        }
        .confirmationDialog(
            "Write ~/.ssh/config.d/rcodebar-\(host.alias)?",
            isPresented: $showAddForwardConfirm,
            titleVisibility: .visible
        ) {
            Button("Write File") { addRemoteForward() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            Creates a new file (does not edit any existing one):

            Host \(host.alias)
                 RemoteForward 47000 127.0.0.1:47000

            You'll still need to run `ssh -O exit \(host.alias)` and reconnect \
            for an existing ControlMaster to pick up the new forward.
            """)
        }
    }

    private func addRemoteForward() {
        switch state.addRemoteForward(alias: host.alias) {
        case .success(let path):
            addForwardMessage = "Wrote \(path).\nRun `ssh -O exit \(host.alias)` then reconnect to pick it up."
        case .failure(let error):
            addForwardMessage = "Failed: \(error)"
        }
        showAddForwardResult = true
    }

    private func copySnippet() {
        let snippet = "RemoteForward 47000 127.0.0.1:47000"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet, forType: .string)
    }
}
