import AppKit
import SwiftUI
import TokenMeterCore

enum SettingsWindow {
    static let id = "settings"
}

struct SettingsView: View {
    let meter: Meter
    /// The section shown. The window opens on General, or on Accounts when Add it on a banner opened it (ADR 0014).
    @State private var tab = SettingsTab.general

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabs(selection: $tab)
            Divider()
            // A fixed height, so the window does not jump when the tab changes; a section taller than it scrolls.
            Form { section }
                .formStyle(.grouped)
                .frame(height: 410)
        }
        .frame(width: 500)
        .onAppear { if meter.pendingAccount != nil { tab = .accounts } }
        .onChange(of: meter.pendingAccount?.folder) { _, folder in if folder != nil { tab = .accounts } }
        .onDisappear { NSApplication.shared.setActivationPolicy(.accessory) }
    }

    @ViewBuilder private var section: some View {
        switch tab {
        case .general: general
        case .accounts: AccountsTab(meter: meter)
        case .skin: SkinGroup(meter: meter)
        case .notifications: NotificationsGroup(meter: meter)
        case .updates: UpdatesGroup(updater: meter.updater)
        }
    }

    @ViewBuilder private var general: some View {
        Group {
            BarsDisplayGroup(meter: meter)
            Toggle("Launch at login", isOn: Binding(
                get: { meter.launchAtLogin },
                set: { meter.setLaunchAtLogin($0) }))
            Text("tokenmeter registers itself the first time it runs. Turning this off is respected: it will not turn itself back on.")
                .font(.caption).foregroundStyle(.secondary)
            ClaudeSetupGroup(meter: meter)
            Button("Show the welcome again") { WelcomeWindow.shared.showAgain() }
        }
    }
}
