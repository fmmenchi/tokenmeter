import XCTest
@testable import TokenMeterCore

/// What a window says about time depends on the moment it is asked at, not on the clock of the machine (ADR 0002).
final class WindowUsageTimeTests: XCTestCase {
    private let seen = Date(timeIntervalSince1970: 1_000_000)

    private func window(source: WindowUsage.Source = .reported, resets: TimeInterval? = nil) -> WindowUsage {
        WindowUsage(window: WindowSpec(name: "5h", duration: 18000), tokens: TokenCounts(), remainingFraction: 0.5, source: source,
                    resetsAt: resets.map { seen.addingTimeInterval($0) }, observedAt: seen)
    }

    func testAFigureIsStaleOnlyAfterTenMinutesAtTheMomentAsked() {
        let usage = window()
        XCTAssertFalse(usage.isStale(at: seen.addingTimeInterval(9 * 60)))
        XCTAssertTrue(usage.isStale(at: seen.addingTimeInterval(11 * 60)))
        XCTAssertTrue(usage.isApproximate(at: seen.addingTimeInterval(11 * 60)))
    }

    func testAResetWindowIsApproximateAtAnyMoment() {
        XCTAssertTrue(window(source: .reset).isApproximate(at: seen))
    }

    func testTheResetCountsDownWithTheMomentAskedAndEndsWhenItPasses() {
        let usage = window(resets: 3 * 3600 + 600)
        XCTAssertEqual(usage.resetText(at: seen), "in 3h 10m")
        XCTAssertEqual(usage.resetText(at: seen.addingTimeInterval(2 * 3600)), "in 1h 10m")
        XCTAssertNil(usage.resetText(at: seen.addingTimeInterval(3 * 3600 + 590)), "under a minute left says nothing")
        XCTAssertNil(usage.resetText(at: seen.addingTimeInterval(4 * 3600)))
        XCTAssertEqual(window(resets: 3 * 86400 + 5 * 3600).resetText(at: seen), "in 3d 5h")
    }

    func testHowLongAgoFollowsTheMomentAsked() {
        let usage = window()
        XCTAssertEqual(usage.observedAgoText(at: seen.addingTimeInterval(30)), "1m ago")
        XCTAssertEqual(usage.observedAgoText(at: seen.addingTimeInterval(3 * 3600)), "3h ago")
        XCTAssertEqual(usage.observedAgoText(at: seen.addingTimeInterval(2 * 86400)), "2d ago")
    }
}
