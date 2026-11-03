import SwiftUI
import TokenMeterCore

@main
struct TokenMeterApp: App {
    @State private var meter = Meter()
    @NSApplicationDelegateAdaptor(TokenMeterDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(meter: meter)
        } label: {
            Image(nsImage: meter.needsAttention ? MenuBarIcon.withDot : MenuBarIcon.image)
                .accessibilityLabel(meter.needsAttention ? "tokenmeter, needs attention" : "tokenmeter")
        }
        .menuBarExtraStyle(.window)

        // A plain window, not `Settings`: SettingsLink does not open from a menu-bar-only app.
        Window("Settings", id: SettingsWindow.id) {
            SettingsView(meter: meter)
        }
        .windowResizability(.contentSize)

    }
}
