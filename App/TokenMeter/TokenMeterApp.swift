import SwiftUI
import TokenMeterCore

@main
struct TokenMeterApp: App {
    @State private var meter = Meter()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(meter: meter)
        } label: {
            Label {
                Text(meter.menuBarTitle)
            } icon: {
                Image(nsImage: MenuBarIcon.image)
            }
        }
        .menuBarExtraStyle(.window)

        // A plain window, not `Settings`: SettingsLink does not open from a menu-bar-only app.
        Window("Settings", id: SettingsWindow.id) {
            SettingsView(meter: meter)
        }
        .windowResizability(.contentSize)

    }
}
