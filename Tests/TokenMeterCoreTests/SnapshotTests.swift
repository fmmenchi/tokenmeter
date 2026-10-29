import XCTest
@testable import TokenMeterCore

final class SnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func event(hoursAgo: Double, tokens: Int) -> UsageEvent {
        UsageEvent(provider: .claude, date: now.addingTimeInterval(-hoursAgo * 3600),
                   tokens: TokenCounts(output: tokens))
    }

    func testWindowOnlyCountsEventsInsideIt() {
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .claude, events: [event(hoursAgo: 1, tokens: 10), event(hoursAgo: 6, tokens: 90)],
            windows: [.session, .week], now: now)
        XCTAssertEqual(snap.windows[0].tokens.total, 10)
        XCTAssertEqual(snap.windows[1].tokens.total, 100)
    }

    func testWithoutLimitOrReportNoRemainingQuotaIsInvented() {
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .claude, events: [event(hoursAgo: 1, tokens: 10)], windows: [.session], now: now)
        XCTAssertNil(snap.windows[0].remainingFraction)
        XCTAssertEqual(snap.windows[0].source, .consumptionOnly)
    }

    func testReportedQuotaWinsAndIgnoresExpiredWindow() {
        let live = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(600))
        let stale = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(-600))
        let a = SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: [], windows: [.session],
                                                 reported: [live], now: now)
        let b = SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: [], windows: [.session],
                                                 reported: [stale], now: now)
        XCTAssertEqual(a.windows[0].remainingFraction ?? -1, 0.7, accuracy: 1e-9)
        XCTAssertEqual(a.windows[0].source, .reported)
        XCTAssertNil(a.windows[0].observedAt, "no observation time given, none invented")
        XCTAssertEqual(b.windows[0].source, .reset, "expired window with no use is full again")
        XCTAssertEqual(b.windows[0].remainingFraction, 1)
    }

    func testExpiredWindowWithUseSinceStaysUnknown() {
        let stale = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(-600))
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .chatgpt, events: [event(hoursAgo: 1, tokens: 5)], windows: [.session],
            reported: [stale], now: now)
        XCTAssertEqual(snap.windows[0].source, .consumptionOnly)
        XCTAssertNil(snap.windows[0].remainingFraction)
    }
}

final class SnapshotStoreTests: XCTestCase {
    func testRoundTripAndMissingFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let store = SnapshotStore(url: url)
        XCTAssertNil(store.read())

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = Snapshot(generatedAt: now, providers: [
            SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session], now: now),
        ])
        try store.write(snapshot)
        XCTAssertEqual(store.read(), snapshot)
    }
}


final class ObservedAtTests: XCTestCase {
    func testObservedAtIsCarriedToTheWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let seen = now.addingTimeInterval(-3 * 3600)
        let quota = ReportedQuota(usedPercent: 40, windowMinutes: 300, resetsAt: now.addingTimeInterval(600), observedAt: seen)
        let snap = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session],
                                                    reported: [quota], now: now)
        XCTAssertEqual(snap.windows[0].observedAt, seen)
    }
}

final class ResolvedTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func usage(resetsIn seconds: TimeInterval) -> WindowUsage {
        WindowUsage(window: .session, tokens: TokenCounts(), remainingFraction: 0.2, source: .reported,
                    resetsAt: now.addingTimeInterval(seconds), observedAt: now.addingTimeInterval(-3600))
    }

    func testPassedResetTurnsAStaleFigureIntoAFullInferredOne() {
        let r = usage(resetsIn: 60).resolved(at: now.addingTimeInterval(120))
        XCTAssertEqual(r.source, .reset)
        XCTAssertEqual(r.remainingFraction, 1)
        XCTAssertNil(r.observedAt, "the old observation no longer applies")
    }

    func testFutureResetLeavesTheFigureAlone() {
        XCTAssertEqual(usage(resetsIn: 600).resolved(at: now), usage(resetsIn: 600))
    }
}

final class PlanNameTests: XCTestCase {
    func testPrettifiedCapitalisesWhatNoRuleNames() {
        XCTAssertEqual(PlanName.prettified("team"), "Team")
        XCTAssertEqual(PlanName.prettified("team_plus"), "Team Plus")
    }

    func testPlanIsCarriedIntoTheSnapshot() {
        let snap = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session], plan: "Max 20x")
        XCTAssertEqual(snap.plan, "Max 20x")
    }
}
