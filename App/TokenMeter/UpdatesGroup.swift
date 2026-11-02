import SwiftUI

/// The group "Updates" at the foot of Settings (ADR 0011): the installed version once, in the title; the switch; what it contacts;
/// and a status line with its button, in five states.
struct UpdatesGroup: View {
    let updater: Updater
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Toggle("Update automatically", isOn: Binding(
                get: { updater.automaticallyChecks },
                set: { updater.setAutomaticallyChecks($0) }))
                .disabled(!updater.isConfigured)
            Text(note).font(.caption).foregroundStyle(.secondary)
            statusRow
        } header: {
            HStack {
                Text("Updates")
                Spacer()
                Text("Version \(Updater.versionText)").foregroundStyle(.secondary)
            }
        }
    }

    private var note: String {
        updater.isConfigured
            ? "Checks once a day for a newer version, tells you, and installs it when you agree. It sends nothing about you or your usage."
            : "This build has no signing key, so it does not look for updates."
    }

    @ViewBuilder private var statusRow: some View {
        switch updater.state {
        case .available(let version, let notes):
            VStack(alignment: .leading, spacing: 6) {
                Text("\(version) is available")
                HStack {
                    Spacer()
                    if let notes { Button("What's new") { openURL(notes) }.buttonStyle(.link) }
                    Button("Install and restart") { updater.checkNow() }.fontWeight(.semibold)
                }
            }
        default:
            HStack {
                statusText
                Spacer()
                Button(updater.state == .failed ? "Try again" : "Check now") { updater.checkNow() }
                    .disabled(!updater.isConfigured || updater.state == .checking)
            }
        }
    }

    @ViewBuilder private var statusText: some View {
        switch updater.state {
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }.foregroundStyle(.secondary)
        case .upToDate:
            Text("You're up to date · checked \(checked)").foregroundStyle(.secondary)
        case .failed:
            HStack(spacing: 6) {
                Circle().fill(.orange).frame(width: 8, height: 8)
                Text("Couldn't check for updates")
            }
            .foregroundStyle(.secondary)
        default:
            Text(updater.lastChecked.map { "Last checked \(Self.when($0))" } ?? "Not checked yet").foregroundStyle(.secondary)
        }
    }

    private var checked: String { updater.lastChecked.map(Self.when) ?? "just now" }

    /// "today, 9:41" or the date, in the user's own format.
    private static func when(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDateInToday(date) ? "today, \(time)" : date.formatted(date: .abbreviated, time: .shortened)
    }
}
