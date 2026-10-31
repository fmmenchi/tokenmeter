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
