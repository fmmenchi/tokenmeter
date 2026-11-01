import SwiftUI
import TokenMeterCore

extension WindowUsage {
    var isStale: Bool {
        guard source == .reported, let observedAt else { return false }
        return Date().timeIntervalSince(observedAt) > Self.staleAfter
    }

    /// True when the figure is old, inferred  rather than a fresh provider reading.
    var isApproximate: Bool { isStale || source == .reset }

    var remainingText: String {
        guard let remainingFraction else { return "—" }
        return "\(isApproximate ? "~" : "")\(Int((remainingFraction * 100).rounded()))%"
    }

    var observedAgoText: String? {
        guard let observedAt else { return nil }
        let minutes = Int(Date().timeIntervalSince(observedAt) / 60)
        return minutes >= 1440 ? "\(minutes / 1440)d ago" : minutes >= 60 ? "\(minutes / 60)h ago" : "\(max(minutes, 1))m ago"
    }

    /// Input + output tokens seen in the window. Cache reads are left out: they are ~98% of the
    /// raw total and say nothing about plan use.
    var tokensText: String { "\((tokens.input + tokens.output).compactTokens) tokens" }

    var detailText: String {
        switch source {
        case .reported where isStale:
            "\(tokensText) · seen \(observedAgoText ?? "a while ago") · may be lower"
        case .reported: [tokensText, resetText.map { "resets \($0)" }].compactMap { $0 }.joined(separator: " · ")
        case .reset: "window reset · not used since"
        case .consumptionOnly: "no quota · \(tokensText)"
        }
    }

    /// "in 2h 10m" style; nil when the provider gave no reset time.
    var resetText: String? {
        guard let resetsAt else { return nil }
        let minutes = Int(resetsAt.timeIntervalSinceNow / 60)
        guard minutes > 0 else { return nil }
        return minutes >= 60 * 24 ? "in \(minutes / 1440)d \(minutes % 1440 / 60)h"
            : minutes >= 60 ? "in \(minutes / 60)h \(minutes % 60)m" : "in \(minutes)m"
    }
}

extension WindowSpec {
    /// How a window is named for a person: the two the providers declare today, and any other by its own name.
    var label: String {
        switch name {
        case "5h": "5 hours"
        case "7d": "Weekly"
        default: name
        }
    }
}

extension Int {
    var compactTokens: String {
        switch self {
        case 1_000_000...: String(format: "%.1fM", Double(self) / 1_000_000)
        case 1_000...: String(format: "%.0fk", Double(self) / 1_000)
        default: String(self)
        }
    }
}

/// A thick, filled bar. SwiftUI's `ProgressView` collapses to a hairline in menus and widgets.
/// A `mark` is where the bar would end at a steady use (ADR 0039): the quota runs out before the reset when the bar ends
/// before it, and the mark is orange then.
struct QuotaBar: View {
    let fraction: Double?
    let tint: Color
    var height: CGFloat = 10
    var mark: Pace?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.15))
                if let fraction {
                    Capsule().fill(tint)
                        .frame(width: max(proxy.size.height, proxy.size.width * min(max(fraction, 0), 1)))
                }
                if let mark {
                    Capsule().fill(mark.runsOut ? Color.orange : Color.primary)
                        .frame(width: 2, height: proxy.size.height + 4)
                        .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)).padding(-1))
                        .offset(x: proxy.size.width * min(max(mark.aheadFraction, 0), 1) - 1)
                        .accessibilityLabel("Where a steady use would put the bar")
                }
            }
        }
        .frame(height: height)
    }
}

private extension View {
    /// The tooltip when there is text for it; no tooltip at all, not an empty one, when there is none.
    @ViewBuilder func help(ifAny text: String?) -> some View {
        if let text { help(text) } else { self }
    }
}

struct WindowRow: View {
    let usage: WindowUsage
    /// The limits of models that are part of this window, drawn right under its bar (ADR 0034).
    var models: [WindowUsage] = []
    /// Draw the mark on the bar and the hover that says when the quota runs out (ADR 0039). The widget does not.
    var showsPace = false
    /// Say in the detail line, in short, when the quota runs out (ADR 0039). It is the widget's answer: it has no hover.
    var showsRunOut = false

    var body: some View {
        // The mark sticks out 2 points above and below its bar, so the panel leaves 2 more between the lines than the widget.
        VStack(alignment: .leading, spacing: showsPace ? 5 : 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.window.label).font(.caption.weight(.medium))
                Spacer()
                Text(usage.remainingFraction == nil ? "unknown" : "\(usage.remainingText) left")
                    .font(.caption.bold().monospacedDigit())
            }
            QuotaBar(fraction: usage.remainingFraction, tint: tint, mark: showsPace ? usage.pace(at: Date()) : nil)
                .opacity(usage.isApproximate ? 0.5 : 1)
                .help(ifAny: showsPace ? usage.paceHoverText(at: Date()) : nil)
            ForEach(models, id: \.window.id) { ScopedWindowRow(usage: $0, showsPace: showsPace) }
            detail
        }
    }

    var tint: Color { usage.tint }

    /// The detail line. Where the quota would run out before the reset and the widget asks, the moment is in it, in short
    /// and in the notice colour: "3.4B tokens · out Thu 6 pm · resets in 3d 14h".
    @ViewBuilder private var detail: some View {
        if showsRunOut, let phrase = usage.runsOutShortText(at: Date()) {
            (Text("\(usage.tokensText) · ") + Text(phrase).fontWeight(.semibold).foregroundColor(.orange)
                + Text(usage.resetText.map { " · resets \($0)" } ?? ""))
                .font(.caption2).foregroundStyle(.secondary)
        } else {
            Text(usage.detailText).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

extension WindowUsage {
    var tint: Color {
        guard let remainingFraction else { return .gray }
        return remainingFraction < 0.15 ? .red : remainingFraction < 0.4 ? .orange : .green
    }
}

/// The corner that joins a model's line to the bar of the window it is part of.
private struct Bracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 3
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// A model's limit, a part of the window above it: a bracket, the name, a thin bar and the figure on one line, right
/// under that window's bar (ADR 0034). The share of the week and the reset are in the help text.
struct ScopedWindowRow: View {
    let usage: WindowUsage
    /// Draw the mark on the thin bar and say in the hover when it runs out (ADR 0039). The widget does not.
    var showsPace = false

    var body: some View {
        HStack(spacing: 6) {
            Bracket().stroke(Color.secondary.opacity(0.6), lineWidth: 1).frame(width: 8, height: 8).offset(y: -3)
            Text(usage.window.scope ?? "").font(.caption.weight(.medium)).lineLimit(1)
                .frame(minWidth: 30, alignment: .leading)
            QuotaBar(fraction: usage.remainingFraction, tint: usage.tint, height: 4,
                     mark: showsPace ? usage.pace(at: Date()) : nil)
            Text(usage.remainingFraction == nil ? "unknown" : "\(usage.remainingText) left")
                .font(.caption.bold().monospacedDigit()).frame(minWidth: 54, alignment: .trailing)
        }
        .opacity(usage.isApproximate ? 0.5 : 1)
        .padding(.leading, 6)
        .help(helpText)
    }

    /// The row's hover: when the model's quota runs out, if the panel asks, then what the row is part of. It is the row's
    /// whole hover rather than the bar's alone, so there is one tooltip and no tooltip inside another.
    private var helpText: String {
        let part = [ "Part of \(WindowSpec(name: usage.window.name, duration: 0).label)",
                     usage.resetText.map { "resets \($0)" }, usage.isApproximate ? usage.observedAgoText.map { "seen \($0)" } : nil ]
            .compactMap { $0 }.joined(separator: " · ")
        return [showsPace ? usage.paceHoverText(at: Date()) : nil, part].compactMap { $0 }.joined(separator: "\n")
    }
}

struct ProviderBlock: View {
    let snapshot: ProviderSnapshot
    /// How many problems have this provider as their topic; the widget only counts, the panel lists them.
    var problemCount = 0
    var showsPace = false
    var showsRunOut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(snapshot.title).font(.subheadline.weight(.semibold))
                if let plan = snapshot.plan {
                    Text(plan).font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.12)))
                }
                if problemCount > 0 { NoticeChip(count: problemCount) }
                // Only where there is a mark to explain: a provider whose windows cannot be estimated has none.
                if showsPace, snapshot.windows.contains(where: { $0.pace(at: Date()) != nil }) {
                    Spacer(minLength: 0)
                    PaceInfo()
                }
            }
            ForEach(snapshot.windows.filter { $0.window.scope == nil }, id: \.window.id) { window in
                WindowRow(usage: window.resolved(at: Date()),
                          models: snapshot.windows.filter { $0.window.scope != nil && $0.window.name == window.window.name }
                              .map { $0.resolved(at: Date()) },
                          showsPace: showsPace, showsRunOut: showsRunOut)
            }
        }
    }
}

extension Snapshot {
    func problemCount(for provider: ProviderSnapshot) -> Int {
        problems.filter { $0.topic == provider.provider.rawValue }.count
    }
}
