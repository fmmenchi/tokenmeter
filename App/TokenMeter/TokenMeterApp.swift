import SwiftUI
import TokenMeterCore

enum LimitsWindow {
    static let id = "limits"
}

@main
struct TokenMeterApp: App {
    @State private var meter = Meter()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(meter: meter)
        } label: {
            Label(meter.menuBarTitle, systemImage: "gauge.with.dots.needle.50percent")
        }
        .menuBarExtraStyle(.window)

        // A plain window, not `Settings`: SettingsLink does not open from a menu-bar-only app.
        Window("Limits", id: LimitsWindow.id) {
            SettingsView(meter: meter)
        }
        .windowResizability(.contentSize)
    }
}
