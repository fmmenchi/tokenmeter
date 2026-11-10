import XCTest
@testable import TokenMeterCore

final class UsageStatsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let now = LogDate.parse("2026-11-02T12:00:00.000Z")!
    private let day: TimeInterval = 86_400
    private let week = 10_080
    private let rules: [ProviderConfig.Usage.Family] = [
        .init(contains: "fable", family: "Fable"), .init(contains: "sonnet", family: "Sonnet"),
        .init(contains: "opus", family: "Opus"), .init(contains: "haiku", family: "Haiku"),
    ]

    private func reading(minutes: Int = 10_080, resetsDaysAgo: Double, percent: Double, seenHoursBeforeEnd: Double? = 1,
                         scope: String? = nil, provider: Provider = .claude) -> UsageStore.Reading {
        let resets = now.addingTimeInterval(-resetsDaysAgo * day)
        return UsageStore.Reading(provider: provider, windowMinutes: minutes, scope: scope, resetsAt: resets, usedPercent: percent,
                                  firstObserved: resets.addingTimeInterval(-3 * day),
                                  lastObserved: seenHoursBeforeEnd.map { resets.addingTimeInterval(-$0 * 3_600) }, source: "live")
    }

    private func store() throws -> UsageStore {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return try UsageStore(url: folder.appendingPathComponent("usage.sqlite"))
    }

    // MARK: Windows

    func testOnlyClosedWindowsOfTheProviderAsAWholeAreCountedNewestFirst() {
        let readings = [
            reading(resetsDaysAgo: 14, percent: 30), reading(resetsDaysAgo: 7, percent: 60), reading(resetsDaysAgo: 0.5, percent: 80),
            reading(resetsDaysAgo: -2, percent: 10),
            reading(resetsDaysAgo: 7, percent: 99, scope: "Fable"),
            reading(minutes: 300, resetsDaysAgo: 1, percent: 50),
        ]
        let outcomes = UsageStats.outcomes(readings, windowMinutes: week, now: now, range: .lifetime, calendar: calendar)
        XCTAssertEqual(outcomes.map(\.usedSeen), [80, 60, 30], "open, scoped and other-length windows are left out")
        XCTAssertEqual(outcomes.map(\.leftAtMost), [20, 40, 70])
    }

    func testTheRangeCutsWhatClosedBeforeItsStart() {
        let readings = (1...14).map { reading(resetsDaysAgo: Double($0) * 7, percent: Double($0)) }
        func count(_ range: StatsRange) -> Int {
            UsageStats.outcomes(readings, windowMinutes: week, now: now, range: range, calendar: calendar).count
        }
        XCTAssertEqual(count(.month), 4, "28 to 31 days: windows that closed 7, 14, 21 and 28 days ago")
        XCTAssertEqual(count(.quarter), 13)
        XCTAssertEqual(count(.year), 14)
        XCTAssertEqual(count(.lifetime), 14)
    }

    func testTheCeilingIsHitAtAHundredAndNotBefore() {
        let readings = [reading(resetsDaysAgo: 1, percent: 100), reading(resetsDaysAgo: 8, percent: 97)]
        let outcomes = UsageStats.outcomes(readings, windowMinutes: week, now: now, range: .lifetime, calendar: calendar)
        XCTAssertEqual(outcomes.map(\.hit), [true, false])
    }

    func testAReadingSeenLongBeforeTheEndMayHaveEndedHigher() {
        let readings = [
            reading(resetsDaysAgo: 1, percent: 40, seenHoursBeforeEnd: 2),
            reading(resetsDaysAgo: 8, percent: 40, seenHoursBeforeEnd: 30),
            reading(resetsDaysAgo: 15, percent: 40, seenHoursBeforeEnd: nil),
        ]
        let outcomes = UsageStats.outcomes(readings, windowMinutes: week, now: now, range: .lifetime, calendar: calendar)
        XCTAssertEqual(outcomes.map(\.approximate), [false, true, true], "more than a tenth of the window before it ended, or never")
    }

    func testAWindowShorterThanADayLooksAtTheLastFourteenDaysWhateverTheRange() {
        let readings = (0..<40).map { reading(minutes: 300, resetsDaysAgo: Double($0) * 0.5 + 0.1, percent: 50) }
        func count(_ range: StatsRange) -> Int {
            UsageStats.outcomes(readings, windowMinutes: 300, now: now, range: range, calendar: calendar).count
        }
        XCTAssertEqual(count(.year), 28, "the windows that ended 0.1 to 13.6 days ago, not the 20 days the store holds")
        XCTAssertEqual(count(.lifetime), 28)
        XCTAssertEqual(count(.month), 28)
    }

    // MARK: Strips

    func testTheSlotsOfAWeeklyStripHaveAPlaceForEveryWindowOfTheRange() {
        let readings = [3.0, 10, 17.0035, 31].map { reading(resetsDaysAgo: $0, percent: 50) }
        let outcomes = UsageStats.outcomes(readings, windowMinutes: week, now: now, range: .lifetime, calendar: calendar)
        let stats = WindowStats(windowMinutes: week, outcomes: outcomes, closed: 4, hits: 0, lastHit: nil, lowestLeft: 50, approximate: 0)
        let slots = UsageStats.slots(stats, range: .quarter, since: nil, now: now)
        XCTAssertEqual(slots.count, 13)
        XCTAssertEqual(slots.indices.filter { slots[$0] != nil }, [8, 10, 11, 12],
                       "the newest is the latest boundary; 17 days and 5 minutes ago is still the slot of 17 days ago")
        XCTAssertEqual(UsageStats.slots(stats, range: .month, since: nil, now: now).count, 4)
        XCTAssertEqual(UsageStats.slots(stats, range: .year, since: nil, now: now).count, 52)
        XCTAssertEqual(UsageStats.slots(stats, range: .lifetime, since: now.addingTimeInterval(-30 * day), now: now).count, 5,
                       "as many as fit between the first thing kept and now")
    }

    func testAStripHasNoSlotsUntilAWindowHasBeenSeenToEnd() {
        let stats = WindowStats(windowMinutes: week, outcomes: [], closed: 0, hits: 0, lastHit: nil, lowestLeft: nil, approximate: 0)
        XCTAssertEqual(UsageStats.slots(stats, range: .quarter, since: nil, now: now), [])
        let short = WindowStats(windowMinutes: 300, outcomes: [WindowOutcome(windowMinutes: 300, resetsAt: now.addingTimeInterval(-3_600),
                                                                             usedSeen: 10, approximate: false)],
                                closed: 1, hits: 0, lastHit: nil, lowestLeft: 90, approximate: 0)
        XCTAssertEqual(UsageStats.slots(short, range: .quarter, since: nil, now: now), [], "a short window is drawn by days")
    }

    func testTheDaysOfAShortWindowAreFourteenColumnsOldestFirst() {
        let readings = [reading(minutes: 300, resetsDaysAgo: 0.3, percent: 10), reading(minutes: 300, resetsDaysAgo: 0.1, percent: 20),
                        reading(minutes: 300, resetsDaysAgo: 1.2, percent: 30)]
        let outcomes = UsageStats.outcomes(readings, windowMinutes: 300, now: now, range: .month, calendar: calendar)
        let days = UsageStats.days(outcomes, now: now, calendar: calendar)
        XCTAssertEqual(days.count, 14)
        XCTAssertEqual(days[13].map(\.usedSeen), [10, 20], "today, the earlier window first")
        XCTAssertEqual(days[12].map(\.usedSeen), [30], "yesterday")
        XCTAssertEqual(days[11], [], "a day with no window is a column with nothing in it")
    }

    // MARK: Models

    func testAModelIsShownByFamilyAndASyntheticOneIsNotAModel() {
        XCTAssertEqual(UsageStats.family(of: "claude-fable-5-1", rules: rules), "Fable")
        XCTAssertEqual(UsageStats.family(of: "CLAUDE-Fable-5", rules: rules), "Fable", "without case")
        XCTAssertEqual(UsageStats.family(of: "gpt-6-astra", rules: rules), "gpt-6-astra", "no rule: as it is")
        XCTAssertNil(UsageStats.family(of: "<synthetic>", rules: rules))
        XCTAssertNil(UsageStats.family(of: nil, rules: rules))
        XCTAssertNil(UsageStats.family(of: "", rules: rules))
    }

    private func total(_ model: String?, _ output: Int, input: Int = 0) -> UsageStore.ModelTotal {
        UsageStore.ModelTotal(model: model, input: input, output: output, messages: 1)
    }

    func testVersionsOfAFamilyAddUpAndTheLargestComesFirst() {
        let result = UsageStats.breakdown([
            total("claude-fable-5", 30, input: 10), total("claude-fable-5-1", 50), total("claude-sonnet-5-5", 100),
            total("<synthetic>", 999), total(nil, 40),
        ], rules: rules)
        XCTAssertEqual(result.shown.map(\.name), ["Sonnet", "Fable"])
        XCTAssertEqual(result.shown.map(\.tokens), [100, 90])
        XCTAssertEqual(result.total, 190, "synthetic is dropped and the unknown model is in no share")
        XCTAssertEqual(result.unknownTokens, 40)
        XCTAssertEqual(result.shown.map(\.fraction).reduce(0, +), 1, accuracy: 0.0001)
    }

    func testTheFirstThreeAreShownThenMoreAndWhatIsSmallIsOther() {
        let result = UsageStats.breakdown([
            total("claude-fable-5", 400), total("claude-sonnet-5", 300), total("claude-opus-5", 200), total("claude-haiku-5", 90),
            total("other-a", 7), total("other-b", 3),
        ], rules: rules)
        XCTAssertEqual(result.shown.map(\.name), ["Fable", "Sonnet", "Opus"])
        XCTAssertEqual(result.more.map(\.name), ["Haiku"], "behind 'more'")
        XCTAssertEqual(result.other?.name, "Other")
        XCTAssertEqual(result.other?.tokens, 10, "under 2% of the total, added up")
        XCTAssertEqual(result.total, 1000)
    }

    func testNothingCountedGivesAnEmptyBreakdown() {
        let result = UsageStats.breakdown([total(nil, 5), total("<synthetic>", 5)], rules: rules)
        XCTAssertEqual(result.shown, [])
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.unknownTokens, 5)
    }

    // MARK: A provider

    func testAProviderCardIsDrawnFromTheStoreAndNeverFromAGuess() throws {
        let store = try store()
        // Ten closed 5-hour windows, three of which reached 100%, and a weekly window with a gap before it.
        store.upsert((1...10).map { reading(minutes: 300, resetsDaysAgo: Double($0) * 0.4, percent: $0 % 3 == 0 ? 100 : 50) })
        store.upsert([reading(resetsDaysAgo: 3, percent: 70), reading(resetsDaysAgo: 24, percent: 20)])
        store.insert([
            UsageStore.Message(provider: .claude, key: "a", at: now.addingTimeInterval(-2 * day), model: "claude-fable-5",
                               tokens: TokenCounts(input: 1, output: 9)),
            UsageStore.Message(provider: .claude, key: "b", at: now.addingTimeInterval(-60 * day), model: "claude-opus-5",
                               tokens: TokenCounts(input: 1, output: 9)),
        ])

        let stats = UsageStats.stats(for: .claude, windows: [300, week], families: rules, store: store, range: .month, now: now,
                                     calendar: calendar)

        let five = stats.windows[0]
        XCTAssertEqual(five.name, "5h")
        XCTAssertEqual(five.closed, 10)
        XCTAssertEqual(five.outcomes.count, 10, "the strip draws every window of the last fourteen days, not a few rows")
        XCTAssertEqual(five.hits, 3)
        XCTAssertEqual(five.lastHit, now.addingTimeInterval(-3 * 0.4 * day))
        let weekly = stats.windows[1]
        XCTAssertEqual(weekly.name, "7d")
        XCTAssertEqual(weekly.closed, 2, "the two windows are in the month, and the gap between them is not made up")
        XCTAssertEqual(weekly.outcomes.map(\.usedSeen), [70, 20])
        XCTAssertEqual(stats.models.shown.map(\.name), ["Fable"], "the Opus message is older than the month")
        XCTAssertEqual(stats.since, now.addingTimeInterval(-60 * day))
    }

    func testAProviderWithNothingKeptSaysSo() throws {
        let stats = UsageStats.stats(for: .chatgpt, windows: [300, week], families: rules, store: try store(), range: .lifetime,
                                     now: now, calendar: calendar)
        XCTAssertNil(stats.since)
        XCTAssertEqual(stats.windows.map(\.closed), [0, 0])
        XCTAssertEqual(stats.models.total, 0)
    }

    // MARK: Verdict

    private func window(_ minutes: Int = 10_080, closed: Int, hits: Int = 0, lowest: Double? = 80, approximate: Int = 0) -> WindowStats {
        WindowStats(windowMinutes: minutes, outcomes: [], closed: closed, hits: hits, lastHit: nil, lowestLeft: lowest,
                    approximate: approximate)
    }

    func testThereIsNoVerdictUntilAWindowLengthHasEndedFourTimes() {
        XCTAssertEqual(UsageStats.verdict([window(closed: 3), window(300, closed: 2)]),
                       Verdict(word: .wait, reason: .fewWindows(window: "7d", seen: 3, needed: 4)))
        XCTAssertEqual(UsageStats.verdict([]), Verdict(word: .wait, reason: .fewWindows(window: nil, seen: 0, needed: 4)))
    }

    func testReachingTheCeilingIsStayAndNamesTheWindowThatWentThereMostOften() {
        XCTAssertEqual(UsageStats.verdict([window(closed: 5, hits: 1)]),
                       Verdict(word: .stay, reason: .hitCeiling(window: "7d", hits: 1, closed: 5)))
        XCTAssertEqual(UsageStats.verdict([window(closed: 4, hits: 1), window(300, closed: 30, hits: 2)]),
                       Verdict(word: .stay, reason: .hitCeiling(window: "7d", hits: 1, closed: 4)), "1 of 4 is more often than 2 of 30")
    }

    func testReachingTheCeilingOftenIsMoveUp() {
        XCTAssertEqual(UsageStats.verdict([window(300, closed: 33, hits: 6)]),
                       Verdict(word: .moveUp, reason: .tightPlan(window: "5h", hits: 6, closed: 33)))
        XCTAssertEqual(UsageStats.verdict([window(closed: 4, hits: 2)]).word, .moveUp, "2 of 4 weekly windows")
        XCTAssertEqual(UsageStats.verdict([window(closed: 4, hits: 1)]).word, .stay, "once is not often")
        XCTAssertEqual(UsageStats.verdict([window(300, closed: 20, hits: 2)]).word, .stay, "2 of 20 is 10%")
        XCTAssertEqual(UsageStats.verdict([window(300, closed: 20, hits: 3)]).word, .moveUp, "3 of 20 is exactly 15%")
    }

    func testTheWindowThatWentToTheCeilingMostOftenIsTheOneNamedForMoveUp() {
        XCTAssertEqual(UsageStats.verdict([window(closed: 4, hits: 2), window(300, closed: 12, hits: 8)]),
                       Verdict(word: .moveUp, reason: .tightPlan(window: "5h", hits: 8, closed: 12)))
    }

    func testAWindowShorterThanADayNeedsTwelveToCount() {
        XCTAssertEqual(UsageStats.verdict([window(300, closed: 11, hits: 11)]),
                       Verdict(word: .wait, reason: .fewWindows(window: "5h", seen: 11, needed: 12)))
        XCTAssertEqual(UsageStats.verdict([window(300, closed: 12, hits: 12)]).word, .moveUp)
    }

    func testAWindowLengthThatHasNotEndedEnoughTimesDoesNotCount() {
        let verdict = UsageStats.verdict([window(closed: 3, hits: 3), window(300, closed: 12, hits: 0, lowest: 90)])
        XCTAssertEqual(verdict, Verdict(word: .moveDown, reason: .plentyOfMargin(window: "5h", left: 90)),
                       "the three weekly windows that reached the ceiling are too few to say anything")
    }

    func testMoveDownNeedsAHundredMinusSixtyOfMarginAndReadingsSeenNearTheEnd() {
        XCTAssertEqual(UsageStats.verdict([window(closed: 4, lowest: 60)]).word, .moveDown, "exactly 60% left is enough")
        XCTAssertEqual(UsageStats.verdict([window(closed: 4, lowest: 59.9)]),
                       Verdict(word: .stay, reason: .littleMargin(window: "7d", left: 59.9)))
        XCTAssertEqual(UsageStats.verdict([window(closed: 4, lowest: 95, approximate: 1)]),
                       Verdict(word: .stay, reason: .incompleteReadings(window: "7d")),
                       "a window seen long before its end may have ended with less: it cannot say move down")
    }

    func testTheTightestWindowDecides() {
        let verdict = UsageStats.verdict([window(closed: 4, lowest: 90), window(300, closed: 12, lowest: 70)])
        XCTAssertEqual(verdict, Verdict(word: .moveDown, reason: .plentyOfMargin(window: "5h", left: 70)))
    }

    // MARK: All providers

    private func providerStats(_ provider: Provider, _ totals: [(String, Int)]) -> ProviderStats {
        ProviderStats(provider: provider, windows: [], models: UsageStats.breakdown(
            totals.map { UsageStore.ModelTotal(model: $0.0, input: 0, output: $0.1, messages: 1) }, rules: rules), since: nil)
    }

    func testAllProvidersShareOneTotalAndTheLargestComesFirst() {
        let shares = UsageStats.crossProviders([
            providerStats(.chatgpt, [("gpt-6", 200)]),
            providerStats(.claude, [("claude-opus-5", 600), ("claude-sonnet-5", 200)]),
            providerStats(Provider(rawValue: "empty"), []),
        ])
        XCTAssertEqual(shares.map(\.provider), [.claude, .chatgpt], "an empty provider is left out")
        XCTAssertEqual(shares.map(\.fraction), [0.8, 0.2])
        XCTAssertEqual(shares[0].models.map(\.name), ["Opus", "Sonnet"])
        XCTAssertEqual(shares[0].models.map(\.fraction), [0.6, 0.2], "a model's share is of all the tokens, not of its provider")
        XCTAssertEqual(shares[1].models.map(\.tokens), [200])
    }

    func testNothingCountedGivesNoShares() {
        XCTAssertEqual(UsageStats.crossProviders([providerStats(.claude, [])]), [])
        XCTAssertEqual(UsageStats.crossProviders([]), [])
    }
}
