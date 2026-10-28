import SwiftUI
import TokenMeterCore

extension Provider {
    var title: String { self == .claude ? "Claude" : "ChatGPT" }
}

extension WindowUsage {
    var remainingText: String {
        guard let remainingFraction else { return "—" }
        return "\(Int((remainingFraction * 100).rounded()))%"
    }

    var detailText: String {
        switch source {
        case .reported: resetText.map { "resets \($0)" } ?? "reported"
        case .estimated: "estimate"
        case .consumptionOnly: "no quota · \(tokens.output.compactTokens) out"
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

struct WindowRow: View {
    let usage: WindowUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(usage.window.name == "7d" ? "Week" : "5h")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
                // Always drawn: an empty bar means "quota unknown", not "nothing left".
                ProgressView(value: usage.remainingFraction ?? 0)
                    .tint(tint)
                    .opacity(usage.remainingFraction == nil ? 0.35 : 1)
                Text(usage.remainingText).font(.caption.bold().monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            }
            Text(usage.detailText).font(.caption2).foregroundStyle(.secondary).padding(.leading, 44)
        }
    }
}

extension WindowRow {
    var tint: Color {
        guard let fraction = usage.remainingFraction else { return .gray }
        return fraction < 0.15 ? .red : fraction < 0.4 ? .orange : .green
    }
}

struct ProviderBlock: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.provider.title).font(.caption.weight(.semibold))
            ForEach(snapshot.windows, id: \.window.name) { WindowRow(usage: $0) }
        }
    }
}
