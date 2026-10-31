import SwiftUI
import TokenMeterCore

extension WindowUsage {
    /// A reported figure older than this no longer counts as live (ADR 0008).
    static let staleAfter: TimeInterval = 10 * 60

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

    /// The window as a limit is named in a sentence: "5-hour", "weekly", or the name as it is.
    var limitName: String {
        switch name {
        case "5h": "5-hour"
        case "7d": "weekly"
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
struct QuotaBar: View {
    let fraction: Double?
    let tint: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.15))
                if let fraction {
                    Capsule().fill(tint)
                        .frame(width: max(proxy.size.height, proxy.size.width * min(max(fraction, 0), 1)))
                }
            }
        }
        .frame(height: height)
    }
}

struct WindowRow: View {
    let usage: WindowUsage
    /// The limits of models that are part of this window, drawn right under its bar (ADR 0034).
    var models: [WindowUsage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.window.label).font(.caption.weight(.medium))
                Spacer()
                Text(usage.remainingFraction == nil ? "unknown" : "\(usage.remainingText) left")
                    .font(.caption.bold().monospacedDigit())
            }
            QuotaBar(fraction: usage.remainingFraction, tint: tint)
                .opacity(usage.isApproximate ? 0.5 : 1)
            ForEach(models, id: \.window.id) { ScopedWindowRow(usage: $0) }
            Text(usage.detailText).font(.caption2).foregroundStyle(.secondary)
        }
    }

    var tint: Color { usage.tint }
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

    var body: some View {
        HStack(spacing: 6) {
            Bracket().stroke(Color.secondary.opacity(0.6), lineWidth: 1).frame(width: 8, height: 8).offset(y: -3)
            Text(usage.window.scope ?? "").font(.caption.weight(.medium)).lineLimit(1)
                .frame(minWidth: 30, alignment: .leading)
            QuotaBar(fraction: usage.remainingFraction, tint: usage.tint, height: 4)
            Text(usage.remainingFraction == nil ? "unknown" : "\(usage.remainingText) left")
                .font(.caption.bold().monospacedDigit()).frame(minWidth: 54, alignment: .trailing)
        }
        .opacity(usage.isApproximate ? 0.5 : 1)
        .padding(.leading, 6)
        .help([ "Part of \(WindowSpec(name: usage.window.name, duration: 0).label)",
                usage.resetText.map { "resets \($0)" }, usage.isApproximate ? usage.observedAgoText.map { "seen \($0)" } : nil ]
            .compactMap { $0 }.joined(separator: " · "))
    }
}

struct ProviderBlock: View {
    let snapshot: ProviderSnapshot
    /// How many problems have this provider as their topic; the widget only counts, the panel lists them.
    var problemCount = 0

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
            }
            ForEach(snapshot.windows.filter { $0.window.scope == nil }, id: \.window.id) { window in
                WindowRow(usage: window.resolved(at: Date()),
                          models: snapshot.windows.filter { $0.window.scope != nil && $0.window.name == window.window.name }
                              .map { $0.resolved(at: Date()) })
            }
        }
    }
}

extension Snapshot {
    func problemCount(for provider: ProviderSnapshot) -> Int {
        problems.filter { $0.topic == provider.provider.rawValue }.count
    }
}
