import SwiftUI
import TokenMeterCore

extension StatsRange {
    var title: String {
        switch self {
        case .month: "1 month"
        case .quarter: "3 months"
        case .year: "1 year"
        case .lifetime: "Lifetime"
        }
    }
}

/// The stats of the panel: a card for each provider that is shown, from what the app has seen and kept (ADR 0010). It says
/// only what was measured or counted: how each window ended, whether its ceiling was reached, and the tokens by model.
struct StatsView: View {
    @Bindable var meter: Meter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Range", selection: $meter.statsRange) {
                ForEach(StatsRange.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            if !meter.storeAvailable {
                Text("The history could not be opened, so there are no stats. The quota in the other view is not affected.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if meter.isIngesting && meter.stats.isEmpty {
                // The first pass reads every log the CLIs still keep, which takes a minute or two once: say so instead of
                // drawing cards that claim nothing is kept.
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading what the logs still hold. It takes a minute or two, once.").font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let snapshot = meter.snapshot {
                ForEach(snapshot.providers, id: \.provider) { provider in
                    StatsCard(snapshot: provider, stats: meter.stats.first { $0.provider == provider.provider })
                }
                Text("Seen on this Mac. The quota is for the whole account; the tokens are only those this Mac counted.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ProgressView()
            }
        }
    }
}

/// A provider's card in the stats view.
private struct StatsCard: View {
    let snapshot: ProviderSnapshot
    let stats: ProviderStats?

    /// The windows the provider has now: a plan without the 5 hours does not list them.
    private var windowNames: Set<String> { Set(snapshot.windows.map(\.window).filter { $0.scope == nil }.map(\.name)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(snapshot.title).font(.subheadline.weight(.semibold))
                if let plan = snapshot.plan {
                    Text(plan).font(.caption.weight(.medium)).padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.12)))
                }
            }
            if let stats, stats.since != nil || stats.windows.contains(where: { $0.closed > 0 }) {
                ForEach(stats.windows.filter { windowNames.contains($0.name) }, id: \.windowMinutes) { WindowHistory(stats: $0) }
                ModelList(models: stats.models)
                if let since = stats.since {
                    Text("Kept since \(since, format: .dateTime.month(.abbreviated).day().year())")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("Nothing is kept for \(snapshot.title) yet.").font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
    }
}

/// How the last windows of one length ended, newest first, and whether the ceiling was reached.
private struct WindowHistory: View {
    let stats: WindowStats

    private var label: String { WindowSpec(name: stats.name, duration: 0).label }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption.weight(.medium))
                Spacer()
                summary
            }
            ForEach(stats.outcomes, id: \.resetsAt) { OutcomeRow(outcome: $0) }
        }
    }

    @ViewBuilder private var summary: some View {
        if stats.closed == 0 {
            Text("not observed").font(.caption2).foregroundStyle(.secondary)
        } else if stats.hits > 0 {
            let last = stats.lastHit.map { " · last \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? ""
            Text("hit the ceiling \(stats.hits) of \(stats.closed)\(last)").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
        } else {
            Text("never reached the ceiling in \(stats.closed)").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct OutcomeRow: View {
    let outcome: WindowOutcome

    private var left: Double { outcome.leftAtMost }
    private var tint: Color { left >= 40 ? .green : left >= 15 ? .orange : .red }

    var body: some View {
        HStack(spacing: 8) {
            Text(outcome.resetsAt, format: .dateTime.month(.abbreviated).day())
                .font(.caption2).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
            QuotaBar(fraction: left / 100, tint: tint, height: 8).opacity(outcome.approximate ? 0.5 : 1)
            Text("\(outcome.approximate ? "~" : "")\(Int(left.rounded()))% left")
                .font(.caption2.bold().monospacedDigit()).frame(width: 64, alignment: .trailing)
        }
        .help(outcome.approximate
              ? "The last reading was a good while before the window ended, so it may have ended with less."
              : "The highest use seen in this window.")
    }
}

/// The tokens by model of one provider: the first three, the rest behind a button and what is small as "Other".
private struct ModelList: View {
    let models: ModelBreakdown
    @State private var expanded = false

    var body: some View {
        if models.total > 0 {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tokens by model").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                ForEach(models.shown, id: \.name) { row($0) }
                if !models.more.isEmpty {
                    if expanded { ForEach(models.more, id: \.name) { row($0) } }
                    Button(expanded ? "Show fewer" : "\(models.more.count) more model\(models.more.count == 1 ? "" : "s")…") {
                        expanded.toggle()
                    }
                    .buttonStyle(.link).font(.caption2)
                }
                if let other = models.other { row(other) }
            }
        } else if models.unknownTokens > 0 {
            Text("This provider does not say which model the tokens are for.").font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// A share that is not nothing never reads as 0%.
    private static func percent(_ fraction: Double) -> String {
        let rounded = Int((fraction * 100).rounded())
        return rounded == 0 && fraction > 0 ? "<1%" : "\(rounded)%"
    }

    private func row(_ share: ModelShare) -> some View {
        HStack(spacing: 8) {
            Text(share.name).font(.caption2.weight(.medium)).frame(width: 72, alignment: .leading).lineLimit(1)
                .truncationMode(.middle)
            QuotaBar(fraction: share.fraction, tint: .accentColor, height: 4)
            Text(Self.percent(share.fraction)).font(.caption2.bold().monospacedDigit()).frame(width: 34, alignment: .trailing)
        }
        .help("\(share.name): \(share.tokens.compactTokens) tokens, input plus output")
    }
}
