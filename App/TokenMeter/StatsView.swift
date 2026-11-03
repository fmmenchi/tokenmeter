import Charts
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

            if meter.storeIsOpening {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Opening the history.").font(.caption).foregroundStyle(.secondary)
                }
            } else if !meter.storeAvailable {
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
                // One card is open at a time; until the person chooses, the first.
                let first = snapshot.providers.first?.provider.rawValue
                let open = meter.openStatsCard ?? first
                ForEach(snapshot.providers, id: \.provider) { provider in
                    StatsCard(snapshot: provider, stats: meter.stats.first { $0.provider == provider.provider },
                              isExpanded: open == provider.provider.rawValue,
                              onToggle: { meter.toggleStatsDetail(provider.provider.rawValue, defaultOpen: first) })
                }
                let shown = Set(snapshot.providers.map(\.provider))
                let shares = UsageStats.crossProviders(meter.stats.filter { shown.contains($0.provider) })
                if shares.count > 0 {
                    AllProvidersCard(shares: shares, titles: Dictionary(uniqueKeysWithValues: snapshot.providers.map { ($0.provider, $0.title) }),
                                     isExpanded: open == Meter.allProvidersCard,
                                     onToggle: { meter.toggleStatsDetail(Meter.allProvidersCard, defaultOpen: first) })
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
    let isExpanded: Bool
    let onToggle: () -> Void

    /// The windows the provider has now: a plan without the 5 hours does not list them.
    private var windowNames: Set<String> { Set(snapshot.windows.map(\.window).filter { $0.scope == nil }.map(\.name)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The title row is the button for the keyboard and for screen readers; a click anywhere on the card does the same.
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Text(snapshot.title).font(.subheadline.weight(.semibold))
                    if let plan = snapshot.plan {
                        Text(plan).font(.caption.weight(.medium)).padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.12)))
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Hide the detail" : "Show the detail")
            .accessibilityLabel("\(snapshot.title): \(isExpanded ? "hide" : "show") the detail")
            if let stats, stats.since != nil || stats.windows.contains(where: { $0.closed > 0 }) {
                let windows = stats.windows.filter { windowNames.contains($0.name) }
                if isExpanded { VerdictBox(verdict: UsageStats.verdict(windows)) }
                ForEach(windows, id: \.windowMinutes) {
                    WindowHistory(stats: $0, showsRows: isExpanded)
                }
                if isExpanded {
                    ModelList(models: stats.models)
                    if let since = stats.since {
                        Text("Kept since \(since, format: .dateTime.month(.abbreviated).day().year())")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } else if let line = modelLine(stats.models) {
                    Text(line).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
        // The whole card opens and closes, not only its title row; a button inside it (the models' "more") keeps its own click.
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onToggle)
    }
}

/// How the last windows of one length ended, newest first, and whether the ceiling was reached. Closed, it is the one line.
private struct WindowHistory: View {
    let stats: WindowStats
    let showsRows: Bool

    private var label: String { WindowSpec(name: stats.name, duration: 0).label }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption.weight(.medium))
                Spacer()
                summary
            }
            if showsRows { ForEach(stats.outcomes, id: \.resetsAt) { OutcomeRow(outcome: $0) } }
        }
    }

    @Environment(\.skinStyle) private var skin

    @ViewBuilder private var summary: some View {
        if stats.closed == 0 {
            Text("not observed").font(.caption2).foregroundStyle(.secondary)
        } else if stats.hits > 0 {
            let last = stats.lastHit.map { " · last \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? ""
            Text("hit the ceiling \(stats.hits) of \(stats.closed)\(last)").font(.caption2.weight(.semibold))
                .foregroundStyle(skin?.middle ?? Color.orange)
        } else {
            Text("never reached the ceiling in \(stats.closed)").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct OutcomeRow: View {
    let outcome: WindowOutcome

    @Environment(\.skinStyle) private var skin

    private var left: Double { outcome.leftAtMost }
    private var tint: Color { skin?.tint(for: left / 100) ?? (left >= 40 ? .green : left >= 15 ? .orange : .red) }

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

extension StatsCard {
    /// The closed card's line for the models: the first three and what is behind them, "Opus 77% · Sonnet 14% · Fable 9% · 2 more".
    fileprivate func modelLine(_ models: ModelBreakdown) -> String? {
        guard models.total > 0 else { return nil }
        let shown = models.shown.map { "\($0.name) \(Int(($0.fraction * 100).rounded()))%" }
        let rest = models.more.count + (models.other == nil ? 0 : 1)
        return (shown + (rest > 0 ? ["\(rest) more"] : [])).joined(separator: " · ")
    }
}

/// The colour of the nth slice of a ring or a bar: the accent in a lighter shade for each, and grey for "the rest".
private func shade(_ index: Int, base: Color = .accentColor) -> Color { base.opacity([1, 0.6, 0.3, 0.15][min(index, 3)]) }

/// A share that is not nothing never reads as 0%.
private func percent(_ fraction: Double) -> String {
    let rounded = Int((fraction * 100).rounded())
    return rounded == 0 && fraction > 0 ? "<1%" : "\(rounded)%"
}

/// The tokens by model of one provider as a ring with its legend: the first three, and what is behind them as one slice that a
/// button opens. Under 2% is "Other".
private struct ModelList: View {
    let models: ModelBreakdown
    @State private var expanded = false

    private var rest: [ModelShare] { models.more + (models.other.map { [$0] } ?? []) }

    var body: some View {
        if models.total > 0 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tokens by model").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                HStack(spacing: 12) {
                    ring
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(models.shown.enumerated()), id: \.element.name) { legend($1, color: shade($0)) }
                        if !rest.isEmpty { restRow }
                    }
                }
                if expanded { ForEach(rest, id: \.name) { legend($0, color: .secondary.opacity(0.5)) } }
            }
        } else if models.unknownTokens > 0 {
            Text("This provider does not say which model the tokens are for.").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var ring: some View {
        let slices = models.shown.enumerated().map { ($0, $1.tokens, shade($0)) }
            + (rest.isEmpty ? [] : [(models.shown.count, rest.map(\.tokens).reduce(0, +), Color.secondary.opacity(0.5))])
        return Chart(slices, id: \.0) { slice in
            SectorMark(angle: .value("Tokens", slice.1), innerRadius: .ratio(0.62), angularInset: 1).foregroundStyle(slice.2)
        }
        .chartLegend(.hidden)
        .frame(width: 64, height: 64)
        .accessibilityLabel("Tokens by model")
    }

    @ViewBuilder private var restRow: some View {
        Button(expanded ? "Show fewer" : "\(rest.count) more model\(rest.count == 1 ? "" : "s")…") { expanded.toggle() }
            .buttonStyle(.link).font(.caption2)
    }

    private func legend(_ share: ModelShare, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(share.name).font(.caption2.weight(.medium)).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            Text(share.tokens.compactTokens).font(.caption2).foregroundStyle(.secondary)
            Text(percent(share.fraction)).font(.caption2.bold().monospacedDigit()).frame(width: 32, alignment: .trailing)
        }
        .help("\(share.name): \(share.tokens.compactTokens) tokens, input plus output")
    }
}

/// The word of a provider's card and what it rests on, in a sentence (ADR 0010).
private struct VerdictBox: View {
    let verdict: Verdict

    private func label(_ name: String) -> String { name == "5h" ? "5-hour" : name == "7d" ? "weekly" : name }

    private var word: String {
        switch verdict.word {
        case .wait: "Wait"
        case .stay: "Stay"
        case .moveDown: "Move down"
        }
    }

    private var headline: String {
        switch verdict.reason {
        case .fewWindows(let window, let seen, let needed):
            window.map { "\(seen) of \(needed) \(label($0)) windows seen, so there is no verdict yet." }
                ?? "No window has been seen to end, so there is no verdict yet."
        case .hitCeiling(let window, let hits, let closed): "You hit the ceiling in \(hits) of \(closed) of the \(label(window)) windows."
        case .incompleteReadings(let window): "The ceiling was not reached, but some \(label(window)) windows were seen long before their end."
        case .littleMargin(let window, let left): "The \(label(window)) window went down to \(Int(left.rounded()))% left or less."
        case .plentyOfMargin(let window, let left): "You never went below \(Int(left.rounded()))% left in the \(label(window)) windows."
        }
    }

    private var detail: String {
        switch verdict.reason {
        case .fewWindows: "A window counts when the app has seen it end."
        case .hitCeiling: "A smaller plan would have stopped you."
        case .incompleteReadings: "The readings are not complete enough to say you could move down."
        case .littleMargin: "Moving down would leave little room."
        case .plentyOfMargin: "A smaller plan may be enough. This is the quota seen on this Mac's readings, not a promise."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(word).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(verdict.word == .moveDown ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
    }
}

/// Every provider's tokens against one total: a bar closed, and the models under their provider, indented, open.
private struct AllProvidersCard: View {
    let shares: [ProviderShare]
    let titles: [Provider: String]
    let isExpanded: Bool
    let onToggle: () -> Void

    private let palette: [Color] = [.accentColor, .gray, .orange, .purple, .teal]
    private func color(_ provider: Int) -> Color { palette[provider % palette.count] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack {
                    Text("All providers").font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Hide the detail" : "Show the detail")
            .accessibilityLabel("All providers: \(isExpanded ? "hide" : "show") the detail")
            bar
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(shares.enumerated()), id: \.element.provider) { index, share in
                        providerRow(share, color: color(index))
                        ForEach(Array(share.models.enumerated()), id: \.element.name) { rank, model in
                            modelRow(model, color: shade(rank, base: color(index)))
                        }
                    }
                }
            } else {
                Text(shares.map { "\(titles[$0.provider] ?? $0.provider.rawValue) \(percent($0.fraction))" }.joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onToggle)
    }

    /// One segment for each model, in its provider's colour and a lighter shade for each after the first. The segments and the 2 points
    /// between them are laid out to the width of the bar, and one under half a percent is left out: it would be a hairline.
    private var bar: some View {
        let segments = shares.enumerated().flatMap { index, share in
            share.models.enumerated().filter { $0.element.fraction >= 0.005 }.map { (provider: index, rank: $0.offset, share: $0.element) }
        }
        let total = segments.map(\.share.fraction).reduce(0, +)
        return GeometryReader { proxy in
            let spacing: CGFloat = 2
            let room = proxy.size.width - spacing * CGFloat(max(segments.count - 1, 0))
            HStack(spacing: spacing) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle().fill(shade(segment.rank, base: color(segment.provider)))
                        .frame(width: total > 0 ? room * segment.share.fraction / total : 0)
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .clipShape(Capsule())
        }
        .frame(height: 10)
        .accessibilityLabel("Tokens by provider and model")
    }

    private func providerRow(_ share: ProviderShare, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(titles[share.provider] ?? share.provider.rawValue).font(.caption2.weight(.semibold))
            Spacer()
            Text("\(share.tokens.compactTokens) · \(percent(share.fraction))").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.top, 3)
    }

    private func modelRow(_ share: ModelShare, color: Color) -> some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0)); path.addLine(to: CGPoint(x: 0, y: 5))
                path.addQuadCurve(to: CGPoint(x: 3, y: 8), control: CGPoint(x: 0, y: 8)); path.addLine(to: CGPoint(x: 8, y: 8))
            }
            .stroke(Color.secondary.opacity(0.6), lineWidth: 1).frame(width: 8, height: 8).offset(y: -4)
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(share.name).font(.caption2.weight(.medium)).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            Text(share.tokens.compactTokens).font(.caption2).foregroundStyle(.secondary)
            Text(percent(share.fraction)).font(.caption2.bold().monospacedDigit()).frame(width: 32, alignment: .trailing)
        }
        .padding(.leading, 12)
    }
}
