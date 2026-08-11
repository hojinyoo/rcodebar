import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var state: AppState
    @State private var manualAlias = ""
    @State private var showManualEntry = false
    @State private var startAtLogin = LoginItem.isEnabled
    @FocusState private var manualFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            hostSection
            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Auto-open remote windows")
                    .font(.headline)
                Spacer()
                Toggle("Auto-open remote windows", isOn: Binding(
                    get: { state.store.autoOpenEnabled },
                    set: { _ in state.toggleAutoOpen() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }
            Text(state.listener.isRunning
                 ? "Listening on 127.0.0.1:47000"
                 : "Stopped — the pod falls back to a clickable link")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
    }

    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Hosts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                addHostControl
            }

            if showManualEntry {
                manualEntryField
            }

            if state.store.hosts.isEmpty {
                Text("No hosts yet — add one with +.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(state.store.hosts) { host in
                    HostRow(
                        state: state,
                        host: host,
                        onRemove: { state.store.removeHost(alias: host.alias) }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Toggle("Start at Login", isOn: $startAtLogin)
                .controlSize(.small)
                .onChange(of: startAtLogin) { _, newValue in
                    LoginItem.setEnabled(newValue)
                }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .keyboardShortcut("q")
        }
        .padding(12)
    }

    private var manualEntryField: some View {
        HStack(spacing: 6) {
            TextField("host alias", text: $manualAlias)
                .textFieldStyle(.roundedBorder)
                .focused($manualFieldFocused)
                .onSubmit(addManualHost)
            Button("Add", action: addManualHost)
                .disabled(manualAlias.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel") {
                manualAlias = ""
                showManualEntry = false
            }
        }
        .controlSize(.small)
        .onAppear { manualFieldFocused = true }
    }

    @ViewBuilder
    private var addHostControl: some View {
        let discovered = state.discoverableHosts
        if discovered.isEmpty {
            Button {
                showManualEntry = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add a host by alias")
        } else {
            Menu {
                ForEach(discovered, id: \.self) { alias in
                    Button(alias) { state.store.addHost(alias: alias) }
                }
                Divider()
                Button("Type manually…") { showManualEntry = true }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add a host from ~/.ssh/config")
        }
    }

    private func addManualHost() {
        state.store.addHost(alias: manualAlias)
        manualAlias = ""
        showManualEntry = false
    }
}
