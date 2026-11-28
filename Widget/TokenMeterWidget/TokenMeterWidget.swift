import SwiftUI
import TokenMeterCore
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    /// The account chosen with Edit; nil when none was, and the widget shows the first card (ADR 0018).
    let accountID: String?
}

struct UsageProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsageEntry { UsageEntry(date: .now, snapshot: nil, accountID: nil) }

    func snapshot(for configuration: ChooseAccountIntent, in context: Context) async -> UsageEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: ChooseAccountIntent, in context: Context) async -> Timeline<UsageEntry> {
        let current = entry(for: configuration)
        // One extra entry at each reset time, so a gauge flips to "reset" when its window ends
        // instead of waiting for the next refresh.
        let resets = (current.snapshot?.providers.flatMap(\.windows).compactMap(\.resetsAt) ?? [])
            .filter { $0 > .now && $0 < .now.addingTimeInterval(24 * 3600) }
        let later = Set(resets).sorted().map { UsageEntry(date: $0, snapshot: current.snapshot, accountID: current.accountID) }
        return Timeline(entries: [current] + later, policy: .after(.now.addingTimeInterval(15 * 60)))
    }

    private func entry(for configuration: ChooseAccountIntent) -> UsageEntry {
        UsageEntry(date: .now, snapshot: SnapshotStore.appGroupStore()?.read(), accountID: configuration.account?.id)
    }
}

struct UsageWidgetView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            if let card = WidgetGauges.card(withID: entry.accountID, in: snapshot) {
                GaugeWidgetView(card: card, size: family == .systemSmall ? .small : .medium,
                                problemCount: snapshot.problemCount(for: card))
            } else {
                // The account was removed or hidden: say so rather than show another one (ADR 0018).
                Text("This account is no longer in the panel. Right-click the widget and choose Edit to pick another.")
                    .font(.system(size: 11)).captionColour()
            }
        } else {
            Text("Open tokenmeter once to publish usage.").font(.system(size: 11)).captionColour()
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
        // The kind keeps its name, so a widget already on the desktop stays there after the update (ADR 0018).
        AppIntentConfiguration(kind: "TokenMeterWidget", intent: ChooseAccountIntent.self, provider: UsageProvider()) { entry in
            UsageWidgetView(entry: entry)
                // Each entry is drawn for its own date: the gauge of a window flips to reset at its entry, and the countdowns move.
                .environment(\.renderDate, entry.date)
                .skinned(entry.snapshot?.skin ?? .system)
                .environment(\.barsDisplay, entry.snapshot?.barsDisplay ?? .left)
                .containerBackground(for: .widget) { WidgetFill(skin: entry.snapshot?.skin ?? .system) }
        }
        .configurationDisplayName("AI quota")
        .description("How much is left of one account's plan. Edit the widget to choose the account.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
