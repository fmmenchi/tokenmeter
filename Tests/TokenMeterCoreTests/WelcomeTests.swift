import XCTest
@testable import TokenMeterCore

final class WelcomeTests: XCTestCase {
    func testItOpensAtTheFirstPageWhenItWasNeverSeen() {
        XCTAssertEqual(WelcomeState.atLaunch(seen: false), .showing(.whereItLives))
        XCTAssertEqual(WelcomeState.atLaunch(seen: true), .idle)
    }

    func testAFreshInstallAndTheFirstUpdateBothOpenIt() {
        // The same rule for both: nothing in the defaults says it was seen.
        let fresh = MemoryWelcomeSeenStore()
        let updated = MemoryWelcomeSeenStore()
        XCTAssertEqual(WelcomeState.atLaunch(seen: fresh.seen), WelcomeState.atLaunch(seen: updated.seen))
        XCTAssertTrue(WelcomeState.atLaunch(seen: fresh.seen).isShowing)
    }

    func testThereAreEightPagesInTheOrderOfTheDesign() {
        XCTAssertEqual(WelcomeState.Page.allCases,
                       [.whereItLives, .bars, .tick, .buttons, .stats, .suggestion, .accounts, .settings])
        XCTAssertEqual(WelcomeState.showing(.suggestion).applying(.next), .showing(.accounts), "the accounts come seventh")
        XCTAssertEqual(WelcomeState.showing(.accounts).applying(.next), .showing(.settings), "and Settings is last")
        XCTAssertTrue(WelcomeState.showing(.settings).endedBy(.next), "Done is on the eighth page")
    }

    func testNextGoesThroughEveryPageAndThenEnds() {
        var state = WelcomeState.atLaunch(seen: false)
        var visited: [WelcomeState.Page] = []
        while let page = state.page {
            visited.append(page)
            state = state.applying(.next)
        }
        XCTAssertEqual(visited, WelcomeState.Page.allCases)
        XCTAssertEqual(state, .idle)
    }

    func testBackGoesToThePreviousPageAndStopsAtTheFirst() {
        XCTAssertEqual(WelcomeState.showing(.tick).applying(.back), .showing(.bars))
        XCTAssertEqual(WelcomeState.showing(.whereItLives).applying(.back), .showing(.whereItLives))
    }

    func testOnlyDoneSkipAndCloseCountAsSeen() {
        for page in WelcomeState.Page.allCases {
            XCTAssertEqual(WelcomeState.showing(page).endedBy(.next), page.isLast, "next at \(page)")
            XCTAssertFalse(WelcomeState.showing(page).endedBy(.back), "back at \(page)")
            XCTAssertTrue(WelcomeState.showing(page).endedBy(.skip), "skip at \(page)")
            XCTAssertTrue(WelcomeState.showing(page).endedBy(.close), "close at \(page)")
        }
    }

    func testSkipAndCloseEndItAtEveryPage() {
        for page in WelcomeState.Page.allCases {
            XCTAssertEqual(WelcomeState.showing(page).applying(.skip), .idle)
            XCTAssertEqual(WelcomeState.showing(page).applying(.close), .idle)
        }
    }

    func testQuittingInTheMiddleLeavesItUnseen() {
        // Quitting runs no action: the flag is only set when `endedBy` says so.
        let store = MemoryWelcomeSeenStore()
        var state = WelcomeState.atLaunch(seen: store.seen)
        for _ in 0..<3 {
            if state.endedBy(.next) { store.markSeen() }
            state = state.applying(.next)
        }
        XCTAssertFalse(store.seen)
        XCTAssertEqual(WelcomeState.atLaunch(seen: store.seen), .showing(.whereItLives))
    }

    func testFinishingMarksItSeenAndItDoesNotOpenAgain() {
        let store = MemoryWelcomeSeenStore()
        var state = WelcomeState.atLaunch(seen: store.seen)
        while state.isShowing {
            if state.endedBy(.next) { store.markSeen() }
            state = state.applying(.next)
        }
        XCTAssertTrue(store.seen)
        XCTAssertEqual(WelcomeState.atLaunch(seen: store.seen), .idle)
    }

    func testShowAgainStartsAtTheFirstPageWhateverWasSeen() {
        XCTAssertEqual(WelcomeState.again, .showing(.whereItLives))
    }

    func testIdleStaysIdleAndEndsNothing() {
        for action in [WelcomeState.Action.back, .next, .skip, .close] {
            XCTAssertEqual(WelcomeState.idle.applying(action), .idle)
            XCTAssertFalse(WelcomeState.idle.endedBy(action))
        }
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
