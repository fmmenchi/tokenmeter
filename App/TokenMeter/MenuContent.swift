import SwiftUI
import TokenMeterCore

struct MenuContent: View {
    let meter: Meter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snapshot = meter.snapshot {
                ForEach(snapshot.providers, id: \.provider) { ProviderBlock(snapshot: $0) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Read \(snapshot.generatedAt, style: .relative) ago")
                    ForEach(snapshot.providers, id: \.provider) { provider in
                        if let quotaAge = provider.quotaUpdatedAt {
                            Text("\(provider.title) quota from \(quotaAge, style: .relative) ago")
                        } else if let hint = provider.setupHint {
                            Text(hint)
                        }
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
            if !meter.widgetCanRead {
                Text("No App Group: set DEVELOPMENT_TEAM in Local.xcconfig for the widget.")
                    .font(.caption2).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Button {
                    Task { await meter.refresh() }
                } label: {
                    if meter.isRefreshing { ProgressView().controlSize(.small) } else { Text("Refresh") }
                }
                .disabled(meter.isRefreshing)
                Button("Settings…") {
                    // An accessory app cannot show a regular window in front: become a regular app
                    // while Settings is open (SettingsView puts it back on disappear).
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: SettingsWindow.id)
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 300)
        .task { await meter.refresh() }
    }
}
