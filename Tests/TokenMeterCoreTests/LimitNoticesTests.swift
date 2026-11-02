import XCTest
@testable import TokenMeterCore

/// ADR 0012: which notices are due, and that each is told once.
final class LimitNoticesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_534_400)
    private let none = TokenCounts(input: 0, output: 0, cacheRead: 0, cacheWrite: 0)
    private let all = Set(NoticeKind.allCases)

    /// A weekly window with `left` of it remaining, reported a minute ago, resetting in two days.
    private func weekly(left: Double?, scope: String? = nil, source: WindowUsage.Source = .reported, observedAgo: TimeInterval = 60,
                        resetsIn: TimeInterval? = 2 * 86_400) -> WindowUsage {
        WindowUsage(window: WindowSpec(name: "7d", duration: 7 * 86_400, scope: scope), tokens: none, remainingFraction: left,
                    source: source, resetsAt: resetsIn.map { now.addingTimeInterval($0) }, observedAt: now.addingTimeInterval(-observedAgo))
    }

    private func snapshot(_ windows: [WindowUsage], provider: String = "claude", title: String = "Claude") -> Snapshot {
        Snapshot(generatedAt: now, providers: [ProviderSnapshot(provider: Provider(rawValue: provider), title: title, windows: windows)])
    }

    private func evaluate(_ windows: [WindowUsage], enabled: Set<NoticeKind>? = nil, ledger: NoticeLedger = NoticeLedger(),
                          at moment: Date? = nil) -> LimitNotices.Outcome {
        LimitNotices.evaluate(snapshot: snapshot(windows), enabled: enabled ?? all, ledger: ledger, now: moment ?? now)
    }

    func testAWindowWithPlentyLeftNotifiesNothing() {
        XCTAssertTrue(evaluate([weekly(left: 0.31)]).notices.isEmpty)
    }

    func testUnderThirtyPercentIsRunningLow() {
        let notices = evaluate([weekly(left: 0.29)]).notices
        XCTAssertEqual(notices.map(\.kind), [.runningLow])
        XCTAssertEqual(notices.first?.providerTitle, "Claude")
    }

    func testUnderTenPercentIsAlmostOut() {
        XCTAssertEqual(evaluate([weekly(left: 0.09)]).notices.map(\.kind), [.almostOut])
    }

    func testTheThresholdsAreStrictlyUnder() {
        // Only the two thresholds are on: at this much used the pace would say it runs out as well, which is not what is tested here.
        let thresholds: Set<NoticeKind> = [.almostOut, .runningLow]
        XCTAssertEqual(evaluate([weekly(left: 0.10)], enabled: thresholds).notices.map(\.kind), [.runningLow], "exactly 10% is not almost out")
        XCTAssertTrue(evaluate([weekly(left: 0.30)], enabled: thresholds).notices.isEmpty, "exactly 30% is not running low")
    }

    func testAKindThatIsOffIsSilentAndWritesNothing() {
        let outcome = evaluate([weekly(left: 0.05)], enabled: [])
        XCTAssertTrue(outcome.notices.isEmpty)
        XCTAssertTrue(outcome.ledger.told.isEmpty)
        let onlyLow = evaluate([weekly(left: 0.20)], enabled: [.almostOut])
        XCTAssertTrue(onlyLow.notices.isEmpty, "running low is off")
        XCTAssertTrue(onlyLow.ledger.told.isEmpty)
    }

    func testEachNoticeIsToldOnceForAWindow() {
        let first = evaluate([weekly(left: 0.25)])
        XCTAssertEqual(first.notices.count, 1)
        let second = evaluate([weekly(left: 0.24)], ledger: first.ledger)
        XCTAssertTrue(second.notices.isEmpty, "the next reading of the same window says nothing more")
    }

    func testAWindowThatResetsArmsAgain() {
        let first = evaluate([weekly(left: 0.25)])
        // The next window has its own reset moment.
        let next = evaluate([weekly(left: 0.25, resetsIn: 9 * 86_400)], ledger: first.ledger)
        XCTAssertEqual(next.notices.map(\.kind), [.runningLow])
    }

    func testOnlyTheMostUrgentIsPostedAndTheOthersAreWrittenAsTold() {
        // At 8% left with five days of seven gone, all three kinds are due.
        let outcome = evaluate([weekly(left: 0.08)])
        XCTAssertEqual(outcome.notices.map(\.kind), [.almostOut], "a jump to 8% says almost out once, not the other two as well")
        XCTAssertEqual(outcome.ledger.told.count, 3, "almost out, will run out and running low are all written")
        XCTAssertTrue(evaluate([weekly(left: 0.07)], ledger: outcome.ledger).notices.isEmpty)
    }

    func testAKindSwitchedOnLaterTellsWhatIsStillDue() {
        let first = evaluate([weekly(left: 0.08)], enabled: [.almostOut])
        XCTAssertEqual(first.notices.map(\.kind), [.almostOut])
        XCTAssertEqual(first.ledger.told.count, 1, "running low was off, so it was not written")
        let later = evaluate([weekly(left: 0.08)], enabled: [.almostOut, .runningLow], ledger: first.ledger)
        XCTAssertEqual(later.notices.map(\.kind), [.runningLow])
    }

    func testAnOldReadingNotifiesNothing() {
        XCTAssertTrue(evaluate([weekly(left: 0.05, observedAgo: WindowUsage.staleAfter + 1)]).notices.isEmpty)
        XCTAssertEqual(evaluate([weekly(left: 0.05, observedAgo: WindowUsage.staleAfter - 1)]).notices.count, 1)
    }

    func testAFigureThatIsNotReportedNotifiesNothing() {
        XCTAssertTrue(evaluate([weekly(left: 0.05, source: .reset)]).notices.isEmpty, "a window inferred as reset")
        XCTAssertTrue(evaluate([weekly(left: nil, source: .consumptionOnly)]).notices.isEmpty, "no quota")
        XCTAssertTrue(evaluate([weekly(left: 0.05, resetsIn: nil)]).notices.isEmpty, "no reset moment")
    }

    func testAReportedFigureWhoseResetHasPassedReadsAsResetAndNotifiesNothing() {
        XCTAssertTrue(evaluate([weekly(left: 0.05, resetsIn: -60)]).notices.isEmpty)
    }

    func testAModelLimitAndItsWindowAreToldApart() {
        let outcome = evaluate([weekly(left: 0.08), weekly(left: 0.08, scope: "Fable")])
        XCTAssertEqual(outcome.notices.count, 2)
        XCTAssertEqual(Set(outcome.notices.map(\.id)).count, 2)
        XCTAssertTrue(outcome.notices.contains { $0.window.window.scope == "Fable" })
    }

    /// A 5-hour window that began at `start`, observed 2 hours in with `left` remaining: 40% left means 60% used in 2 hours, so
    /// all of it is gone at 3 h 20 min, before the reset.
    private func session(left: Double, observedAgo: TimeInterval = 60) -> WindowUsage {
        let start = now.addingTimeInterval(-2 * 3600)
        return WindowUsage(window: WindowSpec(name: "5h", duration: 5 * 3600), tokens: none, remainingFraction: left, source: .reported,
                           resetsAt: start.addingTimeInterval(5 * 3600), observedAt: now.addingTimeInterval(-observedAgo))
    }

    func testWillRunOutNeedsAPaceThatRunsOutBeforeTheReset() {
        XCTAssertEqual(evaluate([session(left: 0.4)]).notices.map(\.kind), [.willRunOut])
        XCTAssertTrue(evaluate([session(left: 0.9)]).notices.isEmpty, "at this pace it lasts")
    }

    func testWillRunOutIsNotToldFromAnOldReading() {
        XCTAssertTrue(evaluate([session(left: 0.4, observedAgo: WindowUsage.staleAfter + 60)]).notices.isEmpty)
    }

    func testWillRunOutComesBeforeRunningLowAndWritesBoth() {
        let outcome = evaluate([session(left: 0.25)])
        XCTAssertEqual(outcome.notices.map(\.kind), [.willRunOut])
        XCTAssertEqual(outcome.ledger.told.count, 2)
    }

    func testTheLedgerForgetsAnEntryADayAfterItsReset() {
        var ledger = NoticeLedger()
        ledger.record("old", resetsAt: now.addingTimeInterval(-NoticeLedger.keepAfterReset - 1))
        ledger.record("recent", resetsAt: now.addingTimeInterval(-NoticeLedger.keepAfterReset + 60))
        let outcome = evaluate([weekly(left: 0.9)], ledger: ledger)
        XCTAssertFalse(outcome.ledger.contains("old"))
        XCTAssertTrue(outcome.ledger.contains("recent"))
    }

    func testTheIdentifierNamesTheProviderTheWindowTheResetAndTheKind() {
        let notice = evaluate([weekly(left: 0.08, scope: "Fable")], enabled: [.almostOut]).notices.first
        let reset = Int(now.addingTimeInterval(2 * 86_400).timeIntervalSince1970)
        XCTAssertEqual(notice?.id, "claude|7d:Fable|\(reset)|almostOut")
    }

    func testTheLedgerSurvivesBeingEncodedAndDecoded() throws {
        let outcome = evaluate([weekly(left: 0.08)])
        let data = try JSONEncoder().encode(outcome.ledger)
        XCTAssertEqual(try JSONDecoder().decode(NoticeLedger.self, from: data), outcome.ledger)
    }
}
