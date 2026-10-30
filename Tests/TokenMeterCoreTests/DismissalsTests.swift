import XCTest
@testable import TokenMeterCore

final class DismissalsTests: XCTestCase {
    private let problem = Problem(id: "a.b", topic: "a", message: "one")

    private func check(_ dismissals: any Dismissals) {
        XCTAssertFalse(dismissals.isHidden(problem))
        dismissals.hide(problem)
        XCTAssertTrue(dismissals.isHidden(problem))
        XCTAssertEqual(dismissals.visible([problem]), [])
        let changed = Problem(id: "a.b", topic: "a", message: "two")
        XCTAssertFalse(dismissals.isHidden(changed), "a new message brings the problem back")
        XCTAssertEqual(dismissals.visible([changed]), [changed])
    }

    func testAProblemStaysHiddenUntilItsMessageChanges() { check(MemoryDismissals()) }

    func testTheDefaultsKeepWhatWasHidden() {
        let name = "tokenmeter.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        check(DefaultsDismissals(defaults: defaults))
        XCTAssertTrue(DefaultsDismissals(defaults: defaults).isHidden(Problem(id: "a.b", topic: "a", message: "one")),
                      "a new instance reads the same defaults")
    }
}
