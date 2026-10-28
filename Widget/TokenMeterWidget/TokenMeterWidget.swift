import SwiftUI
import TokenMeterCore
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry { UsageEntry(date: .now, snapshot: nil) }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func entry() -> UsageEntry {
        UsageEntry(date: .now, snapshot: SnapshotStore.appGroupStore()?.read())
    }
}

struct UsageWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.providers, id: \.provider) { ProviderBlock(snapshot: $0) }
                Spacer(minLength: 0)
                Text(snapshot.generatedAt, style: .relative).font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            Text("Open tokenmeter once to publish usage.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

@main
struct TokenMeterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenMeterWidget", provider: UsageProvider()) { entry in
            UsageWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("AI quota")
        .description("Remaining Claude and ChatGPT quota.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
