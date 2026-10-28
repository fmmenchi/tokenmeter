import SwiftUI

enum SettingsWindow {
    static let id = "settings"
}

struct SettingsView: View {
    let meter: Meter

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { meter.launchAtLogin },
                set: { meter.setLaunchAtLogin($0) }))
            Text("tokenmeter registers itself the first time it runs. Turning this off is respected: it will not turn itself back on.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }
}
