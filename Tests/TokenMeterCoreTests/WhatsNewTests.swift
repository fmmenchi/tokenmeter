import XCTest
@testable import TokenMeterCore

/// Feature "what's new": which features are new since the version a person last saw.
final class WhatsNewTests: XCTestCase {
    private let entries = [
        WhatsNewEntry(version: "0.10.0", title: "Ten", detail: ""),
        WhatsNewEntry(version: "0.9.2", title: "Nine two", detail: ""),
        WhatsNewEntry(version: "0.9.0", title: "Nine", detail: ""),
        WhatsNewEntry(version: "0.11.0", title: "Eleven, not installed yet", detail: ""),
    ]

    func testVersionsCompareByNumber() {
        XCTAssertTrue(WhatsNew.isBefore("0.9.2", "0.10.0"))
        XCTAssertFalse(WhatsNew.isBefore("0.10.0", "0.9.2"))
        XCTAssertFalse(WhatsNew.isBefore("0.15.1", "0.15.1"))
        XCTAssertTrue(WhatsNew.isBefore("0.15", "0.15.1"))
    }

    func testTheFeaturesAfterTheLastSeenUpToTheInstalledNewestFirst() {
        let new = WhatsNew.new(since: "0.9.0", installed: "0.10.0", firstLaunch: false, entries: entries)
        XCTAssertEqual(new.map(\.title), ["Ten", "Nine two"])
    }

    func testNothingWhenNothingNewOrOnAFirstLaunch() {
        XCTAssertTrue(WhatsNew.new(since: "0.10.0", installed: "0.10.0", firstLaunch: false, entries: entries).isEmpty)
        XCTAssertTrue(WhatsNew.new(since: "0.10.0", installed: "0.10.1", firstLaunch: false, entries: entries).isEmpty, "fixes only")
        XCTAssertTrue(WhatsNew.new(since: nil, installed: "0.10.0", firstLaunch: true, entries: entries).isEmpty)
    }

    func testWithNoVersionSeenOnlyTheInstalledVersionsOwn() {
        XCTAssertEqual(WhatsNew.new(since: nil, installed: "0.10.0", firstLaunch: false, entries: entries).map(\.title), ["Ten"])
    }

    func testEveryEntryHasAVersionTitleAndDetail() {
        for entry in WhatsNew.entries {
            XCTAssertFalse(entry.title.isEmpty)
            XCTAssertFalse(entry.detail.isEmpty)
            XCTAssertEqual(entry.version.split(separator: ".").count, 3, entry.version)
        }
    }
}
