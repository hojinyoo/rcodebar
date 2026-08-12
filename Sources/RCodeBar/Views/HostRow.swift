import SwiftUI
import AppKit

struct HostRow: View {
    @ObservedObject var state: AppState
    let host: RemoteHost
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var expanded = false
    @State private var hovering = false
    @State private var copied = false
    @State private var showRemoveConfirm = false
    @State private var showAddForwardConfirm = false
    @State private var showAddForwardResult = false
    @State private var addForwardMessage = ""

    private var status: HostStatus { state.probeResults[host.alias]?.status ?? .unknown }
    private var detail: String? { state.probeResults[host.alias]?.detail }
    private var hasForward: Bool? { state.forwardStatus[host.alias] }

    // Distinct shape per status, not just hue — the dot has to stay readable
    // for a colour-blind reader and in a greyscale screenshot.
    private var statusIcon: (name: String, color: Color) {
        guard host.enabled else { return ("slash.circle", .secondary) }
        switch status {
        case .green: return ("checkmark.circle.fill", .green)
        case .amber: return ("exclamationmark.triangle.fill", .orange)
        case .grey: return ("xmark.circle.fill", .secondary)
        case .unknown: return ("circle.dotted", .secondary)
        }
    }

    private var statusLabel: String { host.enabled ? status.label : "Disabled" }

    private var lastOpenSummary: String {
        guard let path = host.lastOpenPath, let date = host.lastOpenDate else { return "never opened" }
        return "\(path) · \(date.formatted(.relative(presentation: .named)))"
    }

    /// The row can be truncated and renamed, so the tooltip is where the full
    /// alias, status and absolute open time stay reachable.
    private var rowTooltip: String {
        var lines = ["ssh: \(host.alias)", statusLabel]
        if let path = host.lastOpenPath, let date = host.lastOpenDate {
            lines.append("last opened \(path)\n\(date.formatted(date: .abbreviated, time: .shortened))")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { expanded.toggle() }
                if expanded { state.checkForward(alias: host.alias) }
            } label: {
                summary
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.primary.opacity(0.07) : .clear)
            )
            .onHover { hovering = $0 }
            .accessibilityLabel("\(host.effectiveDisplayName), \(statusLabel)")
            .accessibilityHint(expanded ? "Collapse details" : "Expand details")
            .contextMenu {
                Button("Test Now") { state.testNow(alias: host.alias) }
                Button("Copy RemoteForward Snippet", action: copySnippet)
                Divider()
                Button("Remove Host…", role: .destructive) { showRemoveConfirm = true }
            }

            if expanded {
                detailPanel
            }
        }
        // Not on detailPanel: the context menu can ask to remove a collapsed
        // row, and a dialog attached to a view that isn't there never shows.
        .confirmationDialog(
            "Remove \(host.effectiveDisplayName)?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Host", role: .destructive, action: onRemove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            RCodeBar will stop opening windows for \(host.alias), and its display name and \
            default path are forgotten. Your ssh config is left untouched.
            """)
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: statusIcon.name)
                .foregroundStyle(statusIcon.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(host.effectiveDisplayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(host.enabled ? .primary : .secondary)
                Text(lastOpenSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .help(rowTooltip)
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text("Display name")
                        .font(.caption)
                        .gridColumnAlignment(.trailing)
                    EditableField(prompt: host.alias, value: host.displayName ?? "") {
                        state.store.setDisplayName(alias: host.alias, name: $0)
                    }
                }
                GridRow {
                    Text("Default path")
                        .font(.caption)
                    HStack(spacing: 6) {
                        EditableField(prompt: "/home/dev/project", value: host.defaultPath ?? "") {
                            state.store.setDefaultPath(alias: host.alias, path: $0)
                        }
                        Button("Open") { state.openNow(host: host) }
                            .disabled((host.defaultPath ?? "").isEmpty)
                    }
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Toggle("Allow auto-open", isOn: Binding(
                        get: { host.enabled },
                        set: { state.store.setEnabled(alias: host.alias, enabled: $0) }
                    ))
                    .help("A disabled host is rejected by the listener exactly like an unknown one.")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tunnel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline) {
                    Label {
                        Text(statusLabel)
                    } icon: {
                        Image(systemName: statusIcon.name).foregroundStyle(statusIcon.color)
                    }
                    Spacer()
                    Button("Test Now") { state.testNow(alias: host.alias) }
                }
                .font(.caption)

                if status != .green, let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                forwardRow
            }

            HStack {
                Spacer()
                Button("Remove Host…", role: .destructive) { showRemoveConfirm = true }
                    .font(.caption)
            }
        }
        .controlSize(.small)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
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
                Text("Checking RemoteForward…")
                    .foregroundStyle(.secondary)
            case .some(true):
                Label("RemoteForward configured", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            case .some(false):
                VStack(alignment: .leading, spacing: 6) {
                    Label("RemoteForward missing", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    HStack(spacing: 6) {
                        Button("Add RemoteForward…") { showAddForwardConfirm = true }
                        Button(copied ? "Copied" : "Copy Snippet",
                               systemImage: copied ? "checkmark" : "doc.on.doc",
                               action: copySnippet)
                    }
                }
            }
        }
        .font(.caption)
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
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}

/// Commits on every keystroke instead of only `.onSubmit`: this popover can be
/// dismissed without the field ever resigning first responder, and an edit
/// silently dropped on close is worse than an extra UserDefaults write.
private struct EditableField: View {
    let prompt: String
    let value: String
    let commit: (String) -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(prompt: String, value: String, commit: @escaping (String) -> Void) {
        self.prompt = prompt
        self.value = value
        self.commit = commit
        _text = State(initialValue: value)
    }

    var body: some View {
        TextField(prompt, text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onChange(of: text) { _, new in commit(new) }
            // Re-seed only while idle: the store trims, so echoing its value
            // back mid-edit would eat a space the moment it's typed.
            .onChange(of: value) { _, new in if !focused { text = new } }
    }
}
