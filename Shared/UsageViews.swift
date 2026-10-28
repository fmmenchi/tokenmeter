import SwiftUI
import TokenMeterCore

extension Provider {
    var title: String { self == .claude ? "Claude" : "ChatGPT" }
}

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
        .frame(height: 10)
    }
}

struct WindowRow: View {
    let usage: WindowUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.window.name == "7d" ? "Weekly" : "5 hours").font(.caption.weight(.medium))
                Spacer()
                Text(usage.remainingFraction == nil ? "unknown" : "\(usage.remainingText) left")
                    .font(.caption.bold().monospacedDigit())
            }
            QuotaBar(fraction: usage.remainingFraction, tint: tint)
                .opacity(usage.isApproximate ? 0.5 : 1)
            Text(usage.detailText).font(.caption2).foregroundStyle(.secondary)
        }
    }

    var tint: Color {
        guard let fraction = usage.remainingFraction else { return .gray }
        return fraction < 0.15 ? .red : fraction < 0.4 ? .orange : .green
    }
}

struct ProviderBlock: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.provider.title).font(.subheadline.weight(.semibold))
            ForEach(snapshot.windows, id: \.window.name) { WindowRow(usage: $0.resolved(at: Date())) }
        }
    }
}
