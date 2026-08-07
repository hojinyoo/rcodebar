import SwiftUI
import AppKit

@main
struct RCodeBarApp: App {
    @StateObject private var state = AppState()

    init() {
        // Menu-bar-only: no Dock icon, no app switcher entry. Belt-and-suspenders
        // with the Info.plist LSUIElement key set by the packaged .app bundle.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Label("\(state.liveHostCount)", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .menuBarExtraStyle(.window)
    }
}
