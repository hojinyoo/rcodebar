import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var state: AppState
    @State private var manualAlias = ""
    @State private var showManualEntry = false
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
                        state: state,
                        host: host,
                        onRemove: { state.store.removeHost(alias: host.alias) }
                    )
                }
            }

            addHostControl

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
        .frame(width: 340)
    }

    @ViewBuilder
    private var addHostControl: some View {
        let discovered = state.discoverableHosts
        if showManualEntry {
            HStack {
                TextField("host alias", text: $manualAlias)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addManualHost)
                Button("Add", action: addManualHost)
                    .disabled(manualAlias.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { showManualEntry = false }
            }
        } else if discovered.isEmpty {
            Button("Add Host…") { showManualEntry = true }
                .font(.caption)
        } else {
            Menu("Add Host") {
                ForEach(discovered, id: \.self) { alias in
                    Button(alias) { state.store.addHost(alias: alias) }
                }
                Divider()
                Button("Type manually…") { showManualEntry = true }
            }
            .font(.caption)
        }
    }

    private func addManualHost() {
        state.store.addHost(alias: manualAlias)
        manualAlias = ""
        showManualEntry = false
    }
}
