import Foundation

/// How far back the stats look (ADR 0010).
public enum StatsRange: String, CaseIterable, Sendable {
    case month, quarter, year, lifetime

    /// Where the range starts; nil for the whole of what is kept.
    public func since(_ now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .month: return calendar.date(byAdding: .month, value: -1, to: now)
        case .quarter: return calendar.date(byAdding: .month, value: -3, to: now)
        case .year: return calendar.date(byAdding: .year, value: -1, to: now)
        case .lifetime: return nil
        }
    }
}

/// How one window ended, as far as the app saw it (ADR 0010).
public struct WindowOutcome: Equatable, Sendable {
    public let windowMinutes: Int
    public let resetsAt: Date
    /// The highest percentage seen. The window may have gone higher after the last reading, never lower.
    public let usedSeen: Double
    /// True when the last reading was a good while before the window ended, so it may have ended higher.
    public let approximate: Bool

    /// At most this much was left at the end.
    public var leftAtMost: Double { max(0, 100 - usedSeen) }
    /// The ceiling was reached, or near enough: at `UsageStats.ceilingUsed` the plan is already rationed, and a reading is a
    /// sample, so the window most likely went higher. Missing it is possible; inventing it is not.
    public var hit: Bool { usedSeen >= UsageStats.ceilingUsed }
}

/// One block of the strip of a window of a day or longer: when its window ends, and how it ended when the app saw it end.
public struct WindowSlot: Equatable, Sendable {
    public let endsAt: Date
    public let outcome: WindowOutcome?
}

public struct WindowStats: Equatable, Sendable {
    public let windowMinutes: Int
    /// The windows that closed, newest first, at most as many as the view has room for.
    public let outcomes: [WindowOutcome]
    /// Windows that closed in the range, all of them, not only those shown.
    public let closed: Int
    public let hits: Int
    public let lastHit: Date?
    /// The least that was left in any window of the range, at most that much (nil with no window).
    public let lowestLeft: Double?
    /// How many of those windows were seen long before their end, so they may have ended with less.
    public let approximate: Int

    /// The name the window has in the snapshot ("5h", "7d"), so a view labels it as it labels the cards.
    public var name: String { ConfiguredSource.label(minutes: windowMinutes) }
}

public struct ModelShare: Equatable, Sendable {
    public let name: String
    public let tokens: Int
    public let fraction: Double
}

public struct ModelBreakdown: Equatable, Sendable {
    /// The first few, largest first.
    public let shown: [ModelShare]
    /// The rest above the threshold, behind "N more".
    public let more: [ModelShare]
    /// What is below the threshold, added up.
    public let other: ModelShare?
    public let total: Int
    /// Tokens whose source did not say the model. They are in no share.
    public let unknownTokens: Int
}

/// The word on a provider's card, from percentages only: it never looks at tokens. Move up says the ceiling is reached often; it
/// never says which plan to take, because the size of the other plans is not known (ADR 0010).
public struct Verdict: Equatable, Sendable {
    public enum Word: Equatable, Sendable { case wait, stay, moveUp, moveDown }

    public enum Reason: Equatable, Sendable {
        /// Fewer windows than needed have ended in the range, in the window that has the most.
        case fewWindows(window: String?, seen: Int, needed: Int)
        /// The ceiling was reached often enough that the plan is tight, in the window that went there most often.
        case tightPlan(window: String, hits: Int, closed: Int)
        case hitCeiling(window: String, hits: Int, closed: Int)
        /// No ceiling reached, but a reading was seen long before the end of its window: it may have ended with less.
        case incompleteReadings(window: String)
        case littleMargin(window: String, left: Double)
        case plentyOfMargin(window: String, left: Double)
    }

    public let word: Word
    public let reason: Reason

    public init(word: Word, reason: Reason) {
        self.word = word
        self.reason = reason
    }
}

/// One provider's share of all the tokens, with its models as shares of the same total.
public struct ProviderShare: Equatable, Sendable {
    public let provider: Provider
    public let tokens: Int
    public let fraction: Double
    public let models: [ModelShare]
}

public struct ProviderStats: Equatable, Sendable {
    public let provider: Provider
    public let windows: [WindowStats]
    public let models: ModelBreakdown
    /// Since when the store has anything for this provider; nil when it has nothing.
    public let since: Date?
    /// Since when the store has a quota reading of this provider: later than `since` when the logs go back further than the quota
    /// was ever recorded, as Claude's tokens do. A window before it was never seen, and says so.
    public var quotaSince: Date? = nil
}

/// The statistics are pure functions of the facts: the same facts give the same figures (ADR 0010).
public enum UsageStats {
    /// A window shorter than this, in minutes, is looked at over the last `shortWindowDays` whatever the range, and needs more of
    /// them for a verdict: several end in one day.
    public static let shortWindow = 1_440
    /// How many days back a window shorter than a day looks.
    public static let shortWindowDays = 14

    /// A reading seen more than a tenth of the window before it ended may have ended higher.
    static let approximateAfter = 0.1

    /// Windows of one length of a day or longer that must have ended in the range before a verdict is given.
    public static let windowsNeeded = 4
    /// The same for a window shorter than a day.
    public static let shortWindowsNeeded = 12
    /// The margin, in percent left, below which no window went for a card to say it could move down.
    public static let marginForMoveDown = 60.0
    /// The percentage used from which a window counts as having reached the ceiling. A choice, not a measurement.
    public static let ceilingUsed = 95.0
    /// The ceiling must have been reached at least this many times, and in at least `moveUpShare` of the windows, for Move up.
    public static let moveUpHits = 2
    public static let moveUpShare = 0.15

    /// How many windows of this length must have ended before a verdict counts them.
    public static func windowsNeeded(for windowMinutes: Int) -> Int {
        windowMinutes < shortWindow ? shortWindowsNeeded : windowsNeeded
    }

    /// The verdict of a provider's card. Wait while no window length has ended enough times. Move up when the ceiling was reached
    /// at least `moveUpHits` times and in `moveUpShare` of the windows of a length that counts. Stay when it was reached at all.
    /// Move down only when none was reached, every reading was seen near the end of its window and the lowest margin was
    /// `marginForMoveDown` or more. Anything else is Stay, with what is missing.
    public static func verdict(_ windows: [WindowStats]) -> Verdict {
        let counting = windows.filter { $0.closed >= windowsNeeded(for: $0.windowMinutes) }
        guard !counting.isEmpty else {
            let most = windows.max {
                Double($0.closed) / Double(windowsNeeded(for: $0.windowMinutes)) < Double($1.closed) / Double(windowsNeeded(for: $1.windowMinutes))
            }
            return Verdict(word: .wait, reason: .fewWindows(window: most?.name, seen: most?.closed ?? 0,
                                                           needed: most.map { windowsNeeded(for: $0.windowMinutes) } ?? windowsNeeded))
        }
        let byShare: (WindowStats, WindowStats) -> Bool = { Double($0.hits) / Double($0.closed) < Double($1.hits) / Double($1.closed) }
        if let tight = counting.filter({ $0.hits >= moveUpHits && Double($0.hits) / Double($0.closed) >= moveUpShare }).max(by: byShare) {
            return Verdict(word: .moveUp, reason: .tightPlan(window: tight.name, hits: tight.hits, closed: tight.closed))
        }
        if let worst = counting.filter({ $0.hits > 0 }).max(by: byShare) {
            return Verdict(word: .stay, reason: .hitCeiling(window: worst.name, hits: worst.hits, closed: worst.closed))
        }
        if let partial = counting.first(where: { $0.approximate > 0 }) {
            return Verdict(word: .stay, reason: .incompleteReadings(window: partial.name))
        }
        let tightest = counting.min { ($0.lowestLeft ?? 100) < ($1.lowestLeft ?? 100) }!
        let left = tightest.lowestLeft ?? 100
        return left >= marginForMoveDown
            ? Verdict(word: .moveDown, reason: .plentyOfMargin(window: tightest.name, left: left))
            : Verdict(word: .stay, reason: .littleMargin(window: tightest.name, left: left))
    }

    /// Every provider's tokens by family, with each share taken from the grand total: what the card for all providers draws.
    public static func crossProviders(_ stats: [ProviderStats]) -> [ProviderShare] {
        let grand = stats.map(\.models.total).reduce(0, +)
        guard grand > 0 else { return [] }
        return stats.filter { $0.models.total > 0 }.map { provider in
            let models = (provider.models.shown + provider.models.more + (provider.models.other.map { [$0] } ?? [])).map {
                ModelShare(name: $0.name, tokens: $0.tokens, fraction: Double($0.tokens) / Double(grand))
            }
            return ProviderShare(provider: provider.provider, tokens: provider.models.total,
                                 fraction: Double(provider.models.total) / Double(grand), models: models)
        }
        .sorted { $0.tokens > $1.tokens }
    }

    /// The windows of one length, of the provider as a whole, that closed before `now` and inside the range, newest first.
    public static func outcomes(_ readings: [UsageStore.Reading], windowMinutes: Int, now: Date, range: StatsRange,
                                calendar: Calendar = .current) -> [WindowOutcome] {
        var start = range.since(now, calendar: calendar)
        if windowMinutes < shortWindow, let recent = calendar.date(byAdding: .day, value: -shortWindowDays, to: now),
           start == nil || recent > start! {
            start = recent
        }
        return readings
            .filter { $0.windowMinutes == windowMinutes && $0.scope == nil && $0.resetsAt <= now && (start == nil || $0.resetsAt >= start!) }
            .sorted { $0.resetsAt > $1.resetsAt }
            .map { reading in
                let gap = reading.lastObserved.map { reading.resetsAt.timeIntervalSince($0) }
                let approximate = gap.map { $0 > approximateAfter * Double(windowMinutes) * 60 } ?? true
                return WindowOutcome(windowMinutes: windowMinutes, resetsAt: reading.resetsAt, usedSeen: reading.usedPercent,
                                     approximate: approximate)
            }
    }

    /// The blocks of the strip of a window of a day or longer, oldest first: one for each window of the range and never fewer than
    /// `minimumSlots`, so the weekly lines up under the 14 days of the 5 hours; the outcome where the
    /// app saw it end and nil where it did not. The newest slot is the latest boundary of the window before `now`; a window that
    /// ended a few minutes off its boundary is still the slot's. Empty when nothing was seen to end, because with no outcome there
    /// is no boundary to count from.
    /// The fewest blocks a weekly strip has: as many as the days of the 5-hour strip, one under each.
    public static let minimumSlots = shortWindowDays

    public static func slots(_ stats: WindowStats, range: StatsRange, since: Date?, now: Date) -> [WindowSlot] {
        guard stats.windowMinutes >= shortWindow, let newest = stats.outcomes.first else { return [] }
        let length = TimeInterval(stats.windowMinutes) * 60
        let anchor = newest.resetsAt.addingTimeInterval((now.timeIntervalSince(newest.resetsAt) / length).rounded(.down) * length)
        let count: Int
        switch range {
        case .month, .quarter: count = minimumSlots
        case .year: count = 52
        case .lifetime:
            let kept = since.map { Int((now.timeIntervalSince($0) / length).rounded(.up)) } ?? stats.outcomes.count
            count = min(104, max(kept, stats.outcomes.count, minimumSlots))
        }
        var seen = [WindowOutcome?](repeating: nil, count: count)
        for outcome in stats.outcomes {
            let back = Int(((anchor.timeIntervalSince(outcome.resetsAt)) / length).rounded())
            let index = count - 1 - back
            if seen.indices.contains(index), seen[index] == nil { seen[index] = outcome }
        }
        return seen.enumerated().map { WindowSlot(endsAt: anchor.addingTimeInterval(-Double(count - 1 - $0.offset) * length), outcome: $0.element) }
    }

    /// The columns of the strip of a window shorter than a day: the last `count` days, oldest first, each with the windows that
    /// ended in it, oldest first.
    public static func days(_ outcomes: [WindowOutcome], now: Date, count: Int = shortWindowDays,
                            calendar: Calendar = .current) -> [[WindowOutcome]] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).map { offset in
            guard let day = calendar.date(byAdding: .day, value: -(count - 1 - offset), to: today) else { return [] }
            return outcomes.filter { calendar.isDate($0.resetsAt, inSameDayAs: day) }.sorted { $0.resetsAt < $1.resetsAt }
        }
    }

    /// The family a model's name is shown as: the first rule whose fragment the name contains, without case; a name no rule
    /// matches is shown as it is. `<synthetic>` and an empty name are not a model.
    public static func family(of model: String?, rules: [ProviderConfig.Usage.Family]) -> String? {
        guard let model, !model.isEmpty, model.lowercased() != "<synthetic>" else { return nil }
        let lowered = model.lowercased()
        return rules.first { lowered.contains($0.contains.lowercased()) }?.family ?? model
    }

    /// Input plus output tokens by family, largest first: `shownCount` of them, the rest behind "more", and what is under
    /// `otherBelow` of the total added into one share.
    public static func breakdown(_ totals: [UsageStore.ModelTotal], rules: [ProviderConfig.Usage.Family],
                                 shownCount: Int = 3, otherBelow: Double = 0.02) -> ModelBreakdown {
        var byFamily: [String: Int] = [:]
        var unknown = 0
        for item in totals {
            let tokens = item.input + item.output
            guard let name = family(of: item.model, rules: rules) else {
                if item.model == nil { unknown += tokens }
                continue
            }
            byFamily[name, default: 0] += tokens
        }
        let total = byFamily.values.reduce(0, +)
        guard total > 0 else {
            return ModelBreakdown(shown: [], more: [], other: nil, total: 0, unknownTokens: unknown)
        }
        let shares = byFamily.map { ModelShare(name: $0.key, tokens: $0.value, fraction: Double($0.value) / Double(total)) }
            .sorted { $0.tokens != $1.tokens ? $0.tokens > $1.tokens : $0.name < $1.name }
        let large = shares.filter { $0.fraction >= otherBelow }
        let small = shares.filter { $0.fraction < otherBelow }
        let other = small.isEmpty ? nil : ModelShare(name: "Other", tokens: small.map(\.tokens).reduce(0, +),
                                                     fraction: small.map(\.fraction).reduce(0, +))
        return ModelBreakdown(shown: Array(large.prefix(shownCount)), more: Array(large.dropFirst(shownCount)), other: other,
                              total: total, unknownTokens: unknown)
    }

    /// What one provider's card says, from the store.
    public static func stats(for provider: Provider, windows: [Int], families: [ProviderConfig.Usage.Family], store: UsageStore,
                             range: StatsRange, now: Date = Date(), calendar: Calendar = .current) -> ProviderStats {
        let start = range.since(now, calendar: calendar)
        let readings = store.readings(provider: provider, since: start)
        let windowStats = windows.map { minutes -> WindowStats in
            let all = outcomes(readings, windowMinutes: minutes, now: now, range: range, calendar: calendar)
            let hits = all.filter(\.hit)
            return WindowStats(windowMinutes: minutes, outcomes: all,
                               closed: all.count, hits: hits.count, lastHit: hits.map(\.resetsAt).max(),
                               lowestLeft: all.map(\.leftAtMost).min(), approximate: all.filter(\.approximate).count)
        }
        return ProviderStats(provider: provider, windows: windowStats,
                             models: breakdown(store.modelTotals(provider: provider, since: start), rules: families),
                             since: store.oldest(provider: provider), quotaSince: store.oldestReading(provider: provider))
    }
}
