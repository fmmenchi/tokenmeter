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
        let current = entry()
        // One extra entry at each reset time, so a bar flips to "reset" when its window ends
        // instead of waiting for the next refresh.
        let resets = (current.snapshot?.providers.flatMap(\.windows).compactMap(\.resetsAt) ?? [])
            .filter { $0 > .now && $0 < .now.addingTimeInterval(24 * 3600) }
        let later = Set(resets).sorted().map { UsageEntry(date: $0, snapshot: current.snapshot) }
        completion(Timeline(entries: [current] + later, policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func entry() -> UsageEntry {
        UsageEntry(date: .now, snapshot: SnapshotStore.appGroupStore()?.read())
    }
}

struct UsageWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.providers, id: \.provider) {
                    ProviderCard(snapshot: $0, problemCount: snapshot.problemCount(for: $0), showsRunOut: true)
                }
                Spacer(minLength: 0)
                Text(snapshot.generatedAt, style: .relative).font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            Text("Open tokenmeter once to publish usage.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The widget's background: the skin's panel colour, or the system's where there is no skin (ADR 0013).
struct WidgetFill: View {
    let skin: Skin
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let palette = skin.palette(for: colorScheme == .dark ? .dark : .light) {
            Color(argb: palette.panel)
        } else {
            Rectangle().fill(.background)
        }
    }
}

@main
struct TokenMeterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenMeterWidget", provider: UsageProvider()) { entry in
            UsageWidgetView(entry: entry)
                // Each entry is drawn for its own date: the bar of a window flips to reset at its entry, and the countdowns move.
                .environment(\.renderDate, entry.date)
                .skinned(entry.snapshot?.skin ?? .system)
                .containerBackground(for: .widget) { WidgetFill(skin: entry.snapshot?.skin ?? .system) }
        }
        .configurationDisplayName("AI quota")
        .description("Remaining Claude and ChatGPT quota.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
