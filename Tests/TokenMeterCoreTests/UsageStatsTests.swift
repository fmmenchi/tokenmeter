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

    func testTheViewHasRoomForFewerWindowsThanTheRangeHas() {
        XCTAssertEqual(UsageStats.rows(for: week, range: .month), 4)
        XCTAssertEqual(UsageStats.rows(for: week, range: .quarter), 6)
        XCTAssertEqual(UsageStats.rows(for: week, range: .lifetime), 6)
        XCTAssertEqual(UsageStats.rows(for: 300, range: .month), 8)
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
        XCTAssertEqual(five.outcomes.count, 8, "the view has room for eight")
        XCTAssertEqual(five.hits, 3, "hits are counted over every window in the range, not only those shown")
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
}
