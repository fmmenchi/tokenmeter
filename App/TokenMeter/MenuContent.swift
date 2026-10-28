import SwiftUI
import TokenMeterCore

struct MenuContent: View {
    let meter: Meter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snapshot = meter.snapshot {
                ForEach(snapshot.providers, id: \.provider) { ProviderBlock(snapshot: $0) }
                Text("Updated \(snapshot.generatedAt, style: .relative) ago")
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
                Button("Refresh") { Task { await meter.refresh() } }
                SettingsLink { Text("Limits…") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 300)
    }
}
