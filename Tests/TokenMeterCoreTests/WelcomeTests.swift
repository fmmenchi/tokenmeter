import XCTest
@testable import TokenMeterCore

final class WelcomeTests: XCTestCase {
    func testTheTourStartsAtTheIconWhenItWasNeverSeen() {
        XCTAssertEqual(WelcomeState.atLaunch(seen: false), .running(.icon))
        XCTAssertEqual(WelcomeState.atLaunch(seen: true), .idle)
    }

    func testAFreshInstallAndTheFirstUpdateBothStartIt() {
        // The same rule for both: nothing in the defaults says the tour was seen.
        let fresh = MemoryWelcomeSeenStore()
        let updated = MemoryWelcomeSeenStore()
        XCTAssertEqual(WelcomeState.atLaunch(seen: fresh.seen), WelcomeState.atLaunch(seen: updated.seen))
        XCTAssertTrue(WelcomeState.atLaunch(seen: fresh.seen).isRunning)
    }

    func testNextGoesThroughEveryStopInOrderAndThenEnds() {
        var state = WelcomeState.running(.icon)
        var seen: [WelcomeState.Stop] = []
        while let stop = state.stop {
            seen.append(stop)
            state = state.applying(.next)
        }
        XCTAssertEqual(seen, [.icon, .bars, .tick, .buttons, .stats, .suggestion, .settings, .summary])
        XCTAssertEqual(state, .idle)
    }

    func testOnlyTheLastNextCountsAsSeen() {
        for stop in WelcomeState.Stop.allCases {
            let ends = WelcomeState.running(stop).endedBy(.next)
            XCTAssertEqual(ends, stop == .summary, "next at \(stop)")
        }
    }

    func testSkipEndsTheTourAtEveryStopAndCountsAsSeen() {
        for stop in WelcomeState.Stop.allCases {
            XCTAssertEqual(WelcomeState.running(stop).applying(.skip), .idle)
            XCTAssertTrue(WelcomeState.running(stop).endedBy(.skip))
        }
    }

    func testNotNowOnlyCountsAtTheIcon() {
        XCTAssertEqual(WelcomeState.running(.icon).applying(.notNow), .idle)
        XCTAssertTrue(WelcomeState.running(.icon).endedBy(.notNow))
        XCTAssertFalse(WelcomeState.running(.bars).endedBy(.notNow))
    }

    func testAnInterruptedTourIsNotSeen() {
        // Closing the panel or quitting in the middle ends nothing: the flag is only set when `endedBy` says so.
        let store = MemoryWelcomeSeenStore()
        var state = WelcomeState.atLaunch(seen: store.seen)
        for _ in 0..<3 {
            if state.endedBy(.next) { store.markSeen() }
            state = state.applying(.next)
        }
        XCTAssertFalse(store.seen)
        XCTAssertEqual(WelcomeState.atLaunch(seen: store.seen), .running(.icon))
    }

    func testFinishingMarksItSeenAndItDoesNotStartAgain() {
        let store = MemoryWelcomeSeenStore()
        var state = WelcomeState.atLaunch(seen: store.seen)
        while state.isRunning {
            if state.endedBy(.next) { store.markSeen() }
            state = state.applying(.next)
        }
        XCTAssertTrue(store.seen)
        XCTAssertEqual(WelcomeState.atLaunch(seen: store.seen), .idle)
    }

    func testShowAgainStartsAtTheIconWhateverWasSeen() {
        XCTAssertEqual(WelcomeState.again, .running(.icon))
    }

    func testIdleStaysIdle() {
        XCTAssertEqual(WelcomeState.idle.applying(.next), .idle)
        XCTAssertFalse(WelcomeState.idle.endedBy(.skip))
    }

    func testTheCaptionsAreNumberedFromOneToSix() {
        XCTAssertNil(WelcomeState.Stop.icon.captionNumber)
        XCTAssertNil(WelcomeState.Stop.summary.captionNumber)
        let numbers = WelcomeState.Stop.allCases.compactMap(\.captionNumber)
        XCTAssertEqual(numbers, [1, 2, 3, 4, 5, 6])
    }

    func testTheDefaultsRememberIt() {
        let suite = UserDefaults(suiteName: "tokenmeter-welcome-tests")!
        suite.removePersistentDomain(forName: "tokenmeter-welcome-tests")
        let store = DefaultsWelcomeSeenStore(defaults: suite)
        XCTAssertFalse(store.seen)
        store.markSeen()
        XCTAssertTrue(DefaultsWelcomeSeenStore(defaults: suite).seen)
        suite.removePersistentDomain(forName: "tokenmeter-welcome-tests")
    }
}
