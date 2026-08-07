import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var state: AppState
    @State private var newHostAlias = ""
    @State private var startAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Auto-open (\(state.listener.isRunning ? "listening" : "stopped"))", isOn: Binding(
                get: { state.store.autoOpenEnabled },
                set: { _ in state.toggleAutoOpen() }
            ))

            Divider()

            if state.store.hosts.isEmpty {
                Text("No hosts yet — add one below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.store.hosts) { host in
                    HostRow(
                        host: host,
                        status: state.statuses[host.alias] ?? .unknown,
                        onCopySnippet: { copySnippet(for: host.alias) },
                        onRemove: { state.store.removeHost(alias: host.alias) }
                    )
                }
            }

            HStack {
                TextField("host alias", text: $newHostAlias)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addHost)
                Button("Add", action: addHost)
                    .disabled(newHostAlias.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            Toggle("Start at Login", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { _, newValue in
                    LoginItem.setEnabled(newValue)
                }

            Button("Quit RCodeBar") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private func addHost() {
        state.store.addHost(alias: newHostAlias)
        newHostAlias = ""
    }

    private func copySnippet(for alias: String) {
        let snippet = "RemoteForward 47000 127.0.0.1:47000"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet, forType: .string)
    }
}
