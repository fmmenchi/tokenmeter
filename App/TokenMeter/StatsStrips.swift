import SwiftUI
import TokenMeterCore

/// A window as a strip of blocks, time running left to right (the stats). Closed, a card shows only the line above it; open, the
/// strip: one block for each window that ended, stacked by day for a window shorter than a day and one for each week of the range
/// for a longer one. The figure of a block is in its tooltip, in the reading chosen for the bars, and every block has a label for
/// VoiceOver. A block of a window the app did not see is dashed: nothing is made up for the gap.
struct WindowStrip: View {
    let stats: WindowStats
    let range: StatsRange
    let since: Date?
    /// Since when the quota of this provider is kept: a block that ends before it is a window nobody could have seen.
    let quotaSince: Date?
    let now: Date
    let showsStrip: Bool

    @Environment(\.skinStyle) private var skin
    @Environment(\.barsDisplay) private var display

    private var label: String { WindowSpec(name: stats.name, duration: 0).label }
    private var ceiling: String { "\(Int(UsageStats.ceilingUsed))%" }
    private var isShort: Bool { stats.windowMinutes < UsageStats.shortWindow }
    private let dayFormat = Date.FormatStyle().month(.abbreviated).day()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption.weight(.medium))
                Spacer()
                summary
            }
            if showsStrip { strip }
        }
    }

    @ViewBuilder private var summary: some View {
        if stats.closed == 0 {
            Text("not observed").font(.caption2).captionColour()
        } else if stats.hits > 0 {
            let last = stats.lastHit.map { " · last \($0.formatted(dayFormat))" } ?? ""
            Text("reached \(ceiling) \(stats.hits) of \(stats.closed)\(last)").font(.caption2.weight(.semibold))
                .foregroundStyle(skin?.middle ?? Color.orange)
        } else {
            Text("never reached \(ceiling) in \(stats.closed)").font(.caption2).captionColour()
        }
    }

    @ViewBuilder private var strip: some View {
        if isShort {
            let days = UsageStats.days(stats.outcomes, now: now)
            if days.contains(where: { !$0.isEmpty }) {
                VStack(alignment: .leading, spacing: 2) {
                    dayColumns(days)
                    ends(Calendar.current.date(byAdding: .day, value: -(days.count - 1), to: now) ?? now, now)
                }
                .accessibilityElement(children: .contain)
            }
        } else {
            let slots = UsageStats.slots(stats, range: range, since: since, now: now)
            if let first = slots.first, let last = slots.last {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                            block(slot).frame(maxWidth: .infinity).frame(height: 28)
                        }
                    }
                    ends(first.endsAt, last.endsAt)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func ends(_ first: Date, _ last: Date) -> some View {
        HStack {
            Text(first, format: dayFormat)
            Spacer()
            Text(last, format: dayFormat)
        }
        .font(.caption2).captionColour()
    }

    /// The colour a window ended in: the one a bar of what was left would have.
    private func tint(_ outcome: WindowOutcome) -> Color {
        let left = outcome.leftAtMost
        return skin?.tint(for: left / 100) ?? (left >= 40 ? .green : left >= 15 ? .orange : .red)
    }

    private func tip(_ outcome: WindowOutcome) -> String {
        let when = isShort ? outcome.resetsAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
            : outcome.resetsAt.formatted(dayFormat)
        let figure = display.figure(remaining: outcome.leftAtMost / 100)
        return outcome.approximate ? "\(when) · ~\(figure), seen long before its end" : "\(when) · \(figure)"
    }

    private func dayColumns(_ days: [[WindowOutcome]]) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 2) {
                    if day.isEmpty {
                        Capsule().fill(Color.secondary.opacity(0.25)).frame(height: 2)
                    } else {
                        // Newest on top, so the oldest window of the day is the one at the bottom.
                        ForEach(day.reversed(), id: \.resetsAt) { outcome in
                            RoundedRectangle(cornerRadius: 2).fill(tint(outcome)).opacity(outcome.approximate ? 0.55 : 1)
                                .frame(height: 8)
                                .help(tip(outcome))
                                .accessibilityElement().accessibilityLabel(tip(outcome))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 48, alignment: .bottom)
    }

    @ViewBuilder private func block(_ slot: WindowSlot) -> some View {
        if let outcome = slot.outcome {
            // Filled as a bar is, in the reading chosen; a window that reached the ceiling keeps a sliver when a bar of what is
            // left would be empty, so the most important case is never an empty block.
            let fraction = max(display.fraction(remaining: outcome.leftAtMost / 100), outcome.hit ? 0.1 : 0)
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Rectangle().fill(Color.primary.opacity(0.15))
                    Rectangle().fill(tint(outcome)).frame(height: proxy.size.height * fraction)
                        .opacity(outcome.approximate ? 0.55 : 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .help(tip(outcome))
            .accessibilityElement().accessibilityLabel(tip(outcome))
        } else {
            let text = quotaSince.map { slot.endsAt < $0 } == true
                ? "\(slot.endsAt.formatted(dayFormat)) · before the quota was kept, since \(quotaSince!.formatted(dayFormat))"
                : "\(slot.endsAt.formatted(dayFormat)) · the app did not see this window"
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .help(text)
                .accessibilityElement().accessibilityLabel(text)
        }
    }
}

/// Says what is missing when the weekly window is in the snapshot with no figure yet: the verdict is then drawn from the other
/// windows alone, and may change.
struct WeeklyUnknownNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("The weekly limit is not known yet.").font(.caption.weight(.semibold))
            Text("It arrives with the first reading of a session. Until then this verdict is drawn from the 5 hours alone and may change.")
                .font(.caption2).captionColour()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.15)))
        .accessibilityElement(children: .combine)
    }
}
