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
        case .reported: "reported"
        case .estimated: "estimate"
        case .consumptionOnly: "\(tokens.output.compactTokens) out"
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

struct WindowRow: View {
    let usage: WindowUsage

    var body: some View {
        HStack(spacing: 8) {
            Text(usage.window.name).font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 24, alignment: .leading)
            if let fraction = usage.remainingFraction {
                ProgressView(value: fraction)
                    .tint(fraction < 0.15 ? .red : fraction < 0.4 ? .orange : .green)
            } else {
                Spacer(minLength: 0)
            }
            Text(usage.remainingText).font(.caption.bold().monospacedDigit())
            Text(usage.detailText).font(.caption2).foregroundStyle(.secondary)
        }
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
