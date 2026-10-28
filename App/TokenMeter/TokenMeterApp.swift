import SwiftUI
import TokenMeterCore

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

        Settings {
            SettingsView(meter: meter)
        }
    }
}
