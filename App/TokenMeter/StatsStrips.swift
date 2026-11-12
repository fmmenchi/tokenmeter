import SwiftUI
import TokenMeterCore

/// A window as a strip of blocks, time running left to right (the stats). Closed, a card shows only the line above it; open, the
/// strip: one block for each window that ended, stacked by day for a window shorter than a day and one for each week of the range
/// for a longer one. The figure of a block is in the reading chosen for the bars: written under each weekly block while there is
/// room (up to 14, one under each day of the 5 hours), otherwise in a label of the app's own that shows as soon as the pointer is on the block, because the system's
/// tooltip comes too late. Every block has a label for VoiceOver. A block of a window the app did not see is dashed: nothing is made
/// up for the gap.
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
    /// The block under the pointer, with its text and where it is across the strip (0 to 1).
    @State private var hovered: Hovered?

    private struct Hovered: Equatable {
        let id: String
        let text: String
        let position: Double
        /// How far the top of the block is from the bottom of the strip, in points: the label sits just above it.
        let rise: Double?
    }

    /// Up to this many weekly blocks, each has its figure written under it, the number alone; past it, the label on pointing.
    static let figuresUpTo = UsageStats.minimumSlots

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
                    dayColumns(days).overlay { hoverLabel }
                    ends(Calendar.current.date(byAdding: .day, value: -(days.count - 1), to: now) ?? now, now)
                }
                .accessibilityElement(children: .contain)
            }
        } else {
            let slots = UsageStats.slots(stats, range: range, since: since, now: now)
            if let first = slots.first, let last = slots.last {
                let written = slots.count <= Self.figuresUpTo
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                            block(slot, position: (Double(index) + 0.5) / Double(slots.count), hovers: !written)
                                .frame(maxWidth: .infinity).frame(height: 48)
                        }
                    }
                    .overlay { hoverLabel }
                    if written { figures(slots) }
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
        return outcome.approximate ? "\(when) · \(figure) (approx)" : "\(when) · \(figure)"
    }

    /// The figure of each weekly block, under it: the number in the reading chosen, `–` for a week the app did not see.
    private func figures(_ slots: [WindowSlot]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                Group {
                    if let outcome = slot.outcome {
                        let percent = display.percent(remaining: outcome.leftAtMost / 100)
                        Text("\(outcome.approximate ? "~" : "")\(percent)").font(.caption2.weight(.bold)).monospacedDigit()
                    } else {
                        Text("–").font(.caption2).captionColour()
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// The label of the block under the pointer, over the strip and kept inside its width.
    @ViewBuilder private var hoverLabel: some View {
        if let hovered {
            GeometryReader { proxy in
                let width = proxy.size.width
                let position = hovered.position
                let height = proxy.size.height
                let rise = hovered.rise ?? height
                // As wide as its text, at most the strip: a long text wraps instead of leaving the panel.
                StripLabel(text: hovered.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .alignmentGuide(.leading) { size in
                        -min(max(position * width - size.width / 2, 0), max(width - size.width, 0))
                    }
                    .alignmentGuide(.top) { size in size.height + 4 + rise - height }
                    .frame(width: width, height: proxy.size.height, alignment: .topLeading)
            }
            .allowsHitTesting(false)
        }
    }

    /// Shows the label while the pointer is on the block, and rings it.
    private func pointing<Shape: InsettableShape>(_ id: String, _ text: String, at position: Double, rise: Double? = nil,
                                                  in shape: Shape, enabled: Bool = true) -> some ViewModifier {
        PointingModifier(isOn: hovered?.id == id, shape: shape, enabled: enabled) { inside in
            if inside {
                hovered = Hovered(id: id, text: text, position: position, rise: rise)
            } else if hovered?.id == id {
                hovered = nil
            }
        }
    }

    private func dayColumns(_ days: [[WindowOutcome]]) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 2) {
                    if day.isEmpty {
                        Capsule().fill(Color.secondary.opacity(0.25)).frame(height: 2)
                    } else {
                        // Newest on top, so the oldest window of the day is the one at the bottom.
                        ForEach(Array(day.reversed().enumerated()), id: \.element.resetsAt) { row, outcome in
                            // Blocks are 8 tall with 2 between them; the first of the day is at the bottom.
                            let level = day.count - 1 - row
                            RoundedRectangle(cornerRadius: 2).fill(tint(outcome)).opacity(outcome.approximate ? 0.55 : 1)
                                .frame(height: 8)
                                .modifier(pointing("5h-\(outcome.resetsAt.timeIntervalSince1970)", tip(outcome),
                                                   at: (Double(index) + 0.5) / Double(days.count), rise: Double(level * 10 + 8),
                                                   in: RoundedRectangle(cornerRadius: 2)))
                                .accessibilityElement().accessibilityLabel(tip(outcome))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 48, alignment: .bottom)
    }

    @ViewBuilder private func block(_ slot: WindowSlot, position: Double, hovers: Bool) -> some View {
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
            .modifier(pointing("w-\(slot.endsAt.timeIntervalSince1970)", tip(outcome), at: position,
                               in: RoundedRectangle(cornerRadius: 3), enabled: hovers))
            .accessibilityElement().accessibilityLabel(tip(outcome))
        } else {
            let text = quotaSince.map { slot.endsAt < $0 } == true
                ? "\(slot.endsAt.formatted(dayFormat)) · before the quota was kept, since \(quotaSince!.formatted(dayFormat))"
                : "\(slot.endsAt.formatted(dayFormat)) · the app did not see this window"
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .modifier(pointing("w-\(slot.endsAt.timeIntervalSince1970)", text, at: position,
                                   in: RoundedRectangle(cornerRadius: 3), enabled: hovers))
                .accessibilityElement().accessibilityLabel(text)
        }
    }
}

/// Rings a block while the pointer is on it and reports when it enters and leaves. Off, it does nothing: the block's figure is
/// written under it.
private struct PointingModifier<Ring: InsettableShape>: ViewModifier {
    let isOn: Bool
    let shape: Ring
    let enabled: Bool
    let onHover: (Bool) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .overlay(shape.strokeBorder(Color.primary, lineWidth: 1.5).opacity(isOn ? 1 : 0))
                .onHover(perform: onHover)
        } else {
            content
        }
    }
}

/// The figure of the block under the pointer, drawn by the app so it shows at once: the system's tooltip waits a second or more.
private struct StripLabel: View {
    let text: String
    @Environment(\.skinStyle) private var skin

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(skin?.text ?? Color.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(skin?.panel ?? Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(skin?.border ?? Color.primary.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
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
