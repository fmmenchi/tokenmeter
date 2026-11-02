import AppKit
import SwiftUI
import TokenMeterCore

/// The group "Notifications" in Settings (ADR 0012): a note, and a switch with its line for each kind of notice. When macOS has the
/// notifications of the app turned off, a line that says so and a button for System Settings, and the switches dimmed.
struct NotificationsGroup: View {
    let meter: Meter

    private static let kinds: [(kind: NoticeKind, title: String, detail: String)] = [
        (.almostOut, "Almost out", "Under 10% left."),
        (.runningLow, "Running low", "Under 30% left."),
        (.willRunOut, "Will run out before the reset", "At the current pace the quota will not last until the reset."),
    ]

    var body: some View {
        Section {
            Text("Tells you when a window is running out, once for each window and each reset. Only the windows you show.")
                .font(.caption).foregroundStyle(.secondary)
            if meter.noticesBlocked { blockedRow }
            ForEach(Self.kinds, id: \.kind) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Toggle(item.title, isOn: Binding(
                        get: { meter.enabledNotices.contains(item.kind) },
                        set: { meter.setNotice(item.kind, enabled: $0) }))
                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                }
                .disabled(meter.noticesBlocked)
                .opacity(meter.noticesBlocked ? 0.45 : 1)
            }
        } header: {
            Text("Notifications")
        }
        // The person may have changed it in System Settings since this window last opened.
        .task { await meter.refreshNoticePermission() }
    }

    private var blockedRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(.orange).frame(width: 8, height: 8)
                Text("Notifications are turned off for tokenmeter in System Settings.")
            }
            Spacer()
            Button("Open System Settings") { Self.openSystemSettings() }
        }
    }

    /// Opens the notification settings of the Mac; where that address is not known it opens System Settings.
    private static func openSystemSettings() {
        let notifications = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        let settings = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        if let notifications, NSWorkspace.shared.open(notifications) { return }
        NSWorkspace.shared.open(settings)
    }
}
