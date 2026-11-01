import XCTest
@testable import TokenMeterCore

/// ADR 0038: when a window runs out at the pace it has had since it began.
final class RunOutTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// A window that began at 12:00 on Sun 2026-11-01 UTC.
    private let start = Date(timeIntervalSince1970: 1_793_534_400)

    private func usage(left: Double, observed: TimeInterval, duration: TimeInterval = 5 * 3600,
                       source: WindowUsage.Source = .reported, resets: Bool = true) -> WindowUsage {
        WindowUsage(window: WindowSpec(name: "w", duration: duration), tokens: TokenCounts(input: 0, output: 0, cacheRead: 0, cacheWrite: 0),
                    remainingFraction: left, source: source,
                    resetsAt: resets ? start.addingTimeInterval(duration) : nil, observedAt: start.addingTimeInterval(observed))
    }

    func testItRunsOutWhenThePaceWouldPassTheWholeQuotaBeforeTheReset() {
        // 2h gone, 60% used: at that pace all of it is used at 3h20m.
        let window = usage(left: 0.4, observed: 2 * 3600)
        let now = start.addingTimeInterval(2 * 3600)
        XCTAssertEqual(window.runsOut(at: now), start.addingTimeInterval(2 * 3600 / 0.6))
    }

    func testItSaysNothingWhenTheQuotaLastsUntilTheReset() {
        let window = usage(left: 0.8, observed: 2 * 3600)
        XCTAssertNil(window.runsOut(at: start.addingTimeInterval(2 * 3600)))
    }

    func testItSaysNothingTooEarlyInTheWindow() {
        let window = usage(left: 0.5, observed: 20 * 60)
        XCTAssertNil(window.runsOut(at: start.addingTimeInterval(20 * 60)), "a burst in the first 20 minutes says too little")
    }

    func testItSaysNothingWithoutAFreshReportedFigure() {
        let now = start.addingTimeInterval(3 * 3600)
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600 - 11 * 60).runsOut(at: now), "stale after ten minutes")
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600, source: .reset).runsOut(at: now))
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600, source: .consumptionOnly).runsOut(at: now))
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600, resets: false).runsOut(at: now), "no reset time, no start")
    }

    func testItSaysNothingWhenNothingWasUsed() {
        XCTAssertNil(usage(left: 1, observed: 3 * 3600).runsOut(at: start.addingTimeInterval(3 * 3600)))
    }

    func testTheTextIsRoundedToTheHourAndNamesTheDay() {
        // 7-day window; 3 days gone (Wed 12:00), 60% used: all of it at 5 days, Fri 12:00.
        let week = 7 * 24 * 3600.0
        let window = usage(left: 0.4, observed: 3 * 24 * 3600, duration: week)
        let now = start.addingTimeInterval(3 * 24 * 3600)
        XCTAssertEqual(window.runsOutText(at: now, calendar: calendar), "at this pace you run out Friday at 12 pm")
    }

    // MARK: the mark and the hover (ADR 0039)

    func testTheMarkIsTheShareOfTheWindowStillAheadWhenTheFigureWasObserved() throws {
        // 2h of 5h gone: 3/5 ahead, whether it runs out (40% left) or lasts (80% left).
        let runsOut = usage(left: 0.4, observed: 2 * 3600).pace(at: start.addingTimeInterval(2 * 3600))
        XCTAssertEqual(try XCTUnwrap(runsOut).aheadFraction, 0.6, accuracy: 1e-9)
        XCTAssertTrue(try XCTUnwrap(runsOut).runsOut)
        let lasts = usage(left: 0.8, observed: 2 * 3600).pace(at: start.addingTimeInterval(2 * 3600))
        XCTAssertEqual(try XCTUnwrap(lasts).aheadFraction, 0.6, accuracy: 1e-9)
        XCTAssertFalse(try XCTUnwrap(lasts).runsOut, "a window that lasts still has a mark")
    }

    func testTheMarkDoesNotMoveWhileTheFigureIsFresh() throws {
        // The figure is five minutes old: the mark is where it was when the figure was observed, not at `now`.
        let window = usage(left: 0.4, observed: 2 * 3600)
        let pace = window.pace(at: start.addingTimeInterval(2 * 3600 + 5 * 60))
        XCTAssertEqual(try XCTUnwrap(pace).aheadFraction, 0.6, accuracy: 1e-9)
    }

    func testTheBarEndsBeforeTheMarkExactlyWhenTheQuotaRunsOut() throws {
        for hundredths in stride(from: 5, through: 95, by: 5) {
            let left = Double(hundredths) / 100
            let now = start.addingTimeInterval(3 * 3600)
            let pace = try XCTUnwrap(usage(left: left, observed: 3 * 3600).pace(at: now))
            XCTAssertEqual(left < pace.aheadFraction, pace.runsOut, "\(hundredths)% left, \(pace.aheadFraction) ahead")
        }
    }

    func testThereIsNoMarkWhereNothingCanBeEstimated() {
        let now = start.addingTimeInterval(3 * 3600)
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600 - 11 * 60).pace(at: now), "stale")
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600, source: .reset).pace(at: now))
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600, source: .consumptionOnly).pace(at: now))
        XCTAssertNil(usage(left: 0.2, observed: 3 * 3600, resets: false).pace(at: now))
        XCTAssertNil(usage(left: 1, observed: 3 * 3600).pace(at: now), "nothing used")
        XCTAssertNil(usage(left: 0.5, observed: 20 * 60).pace(at: start.addingTimeInterval(20 * 60)), "too early")
    }

    func testTheHoverSaysWhenItRunsOutOrThatItLasts() {
        let now = start.addingTimeInterval(2 * 3600)
        XCTAssertEqual(usage(left: 0.4, observed: 2 * 3600).paceHoverText(at: now, calendar: calendar),
                       "At this pace you run out today at 3 pm")
        XCTAssertEqual(usage(left: 0.8, observed: 2 * 3600).paceHoverText(at: now, calendar: calendar),
                       "At this pace it lasts until the reset")
        XCTAssertNil(usage(left: 0.8, observed: 2 * 3600, source: .reset).paceHoverText(at: now, calendar: calendar))
    }

    func testTheShortPhraseIsRoundedAndNamesTheDayInThreeLetters() {
        let week = 7 * 24 * 3600.0
        let friday = usage(left: 0.4, observed: 3 * 24 * 3600, duration: week)
        XCTAssertEqual(friday.runsOutShortText(at: start.addingTimeInterval(3 * 24 * 3600), calendar: calendar), "out Fri 12 pm")
        let today = usage(left: 0.4, observed: 2 * 3600)
        XCTAssertEqual(today.runsOutShortText(at: start.addingTimeInterval(2 * 3600), calendar: calendar), "out today 3 pm")
        let tomorrow = usage(left: 0.3, observed: 66 * 3600, duration: week)
        XCTAssertEqual(tomorrow.runsOutShortText(at: start.addingTimeInterval(66 * 3600), calendar: calendar), "out tomorrow 10 am")
    }

    func testTheShortPhraseIsAbsentWhenItLastsOrCannotBeEstimated() {
        let now = start.addingTimeInterval(2 * 3600)
        XCTAssertNil(usage(left: 0.8, observed: 2 * 3600).runsOutShortText(at: now, calendar: calendar))
        XCTAssertNil(usage(left: 0.4, observed: 2 * 3600, source: .consumptionOnly).runsOutShortText(at: now, calendar: calendar))
    }

    func testTheTextSaysTodayAndTomorrow() {
        let now = start.addingTimeInterval(2 * 3600)
        let window = usage(left: 0.4, observed: 2 * 3600)
        XCTAssertEqual(window.runsOutText(at: now, calendar: calendar), "at this pace you run out today at 3 pm")

        let week = 7 * 24 * 3600.0
        // 66 hours gone (Wed 06:00), 70% used: all of it at 94.3 hours, Thu 10:20.
        let tomorrow = usage(left: 0.3, observed: 66 * 3600, duration: week)
        XCTAssertEqual(tomorrow.runsOutText(at: start.addingTimeInterval(66 * 3600), calendar: calendar),
                       "at this pace you run out tomorrow at 10 am")
    }
}
