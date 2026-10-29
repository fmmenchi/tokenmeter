import AppKit
import SwiftUI

enum SettingsWindow {
    static let id = "settings"
}

struct SettingsView: View {
    let meter: Meter

    private var claudeStatusText: String {
        guard meter.autoSetUpClaude else { return "Off: tokenmeter does not touch Claude Code's settings." }
        switch meter.claudeStatusLine {
        case .set: return "Done: Claude's status line now feeds tokenmeter."
        case .alreadySet: return "Claude's status line already feeds tokenmeter."
        case .notInstalled: return "Claude Code not found. Checked again at every launch."
        case .otherStatusLine: return "Another status line is in use and was left alone. See the guide."
        case .unreadableSettings: return "Claude's settings.json could not be read, so it was left alone."
        case nil: return "Checked at every launch; never replaces a status line you set."
        }
    }

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { meter.launchAtLogin },
                set: { meter.setLaunchAtLogin($0) }))
            Text("tokenmeter registers itself the first time it runs. Turning this off is respected: it will not turn itself back on.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Set up the Claude quota automatically", isOn: Binding(
                get: { meter.autoSetUpClaude },
                set: { meter.setAutoSetUpClaude($0) }))
            Text(claudeStatusText)
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 380)
        .padding()
        .onDisappear { NSApplication.shared.setActivationPolicy(.accessory) }
    }
}
