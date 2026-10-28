import SwiftUI
import TokenMeterCore

struct MenuContent: View {
    let meter: Meter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snapshot = meter.snapshot {
                ForEach(snapshot.providers, id: \.provider) { ProviderBlock(snapshot: $0) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Read \(snapshot.generatedAt, style: .relative) ago")
                    if let quotaAge = snapshot.claudeQuotaUpdatedAt {
                        Text("Claude quota from \(quotaAge, style: .relative) ago")
                    } else {
                        Text("Claude quota: status line has not run yet")
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
                SettingsLink { Text("Limits…") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 300)
        .task { await meter.refresh() }
    }
}
