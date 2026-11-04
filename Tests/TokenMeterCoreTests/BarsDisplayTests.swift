import XCTest
@testable import TokenMeterCore

/// ADR 0006: how the bars read, left or used. The data keeps what is left; only the figure, the fill and the mark follow the choice.
final class BarsDisplayTests: XCTestCase {
    private func encoded(_ snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func decoded(_ data: Data) throws -> Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Snapshot.self, from: data)
    }

    func testLeftFillsABarToWhatIsLeft() {
        XCTAssertEqual(BarsDisplay.left.fraction(remaining: 0.25), 0.25)
        XCTAssertEqual(BarsDisplay.left.fraction(remaining: 0), 0)
        XCTAssertEqual(BarsDisplay.left.fraction(remaining: 1), 1)
    }

    func testUsedFillsABarToWhatIsUsed() {
        XCTAssertEqual(BarsDisplay.used.fraction(remaining: 0.25), 0.75, accuracy: 1e-12)
        XCTAssertEqual(BarsDisplay.used.fraction(remaining: 1), 0)
        XCTAssertEqual(BarsDisplay.used.fraction(remaining: 0), 1)
    }

    func testUsedStaysInsideTheBarWhateverTheReading() {
        XCTAssertEqual(BarsDisplay.used.fraction(remaining: 1.2), 0)
        XCTAssertEqual(BarsDisplay.used.fraction(remaining: -0.1), 1)
    }

    func testTheFiguresOfOneWindowAddUpToAHundred() {
        for step in 0...1000 {
            let remaining = Double(step) / 1000
            XCTAssertEqual(BarsDisplay.left.percent(remaining: remaining) + BarsDisplay.used.percent(remaining: remaining), 100, "\(remaining)")
        }
    }

    func testTheFigureOfLeftIsWhatItAlwaysWas() {
        XCTAssertEqual(BarsDisplay.left.percent(remaining: 0.125), 13)
        XCTAssertEqual(BarsDisplay.used.percent(remaining: 0.125), 87)
        XCTAssertEqual(BarsDisplay.used.percent(remaining: 1), 0)
        XCTAssertEqual(BarsDisplay.used.percent(remaining: 0), 100)
    }

    func testTheWordIsWhatTheFigureSays() {
        XCTAssertEqual(BarsDisplay.left.word, "left")
        XCTAssertEqual(BarsDisplay.used.word, "used")
    }

    func testLeftDrawsTheMarkWhereItIs() {
        let pace = Pace(aheadFraction: 0.43, runsOutAt: nil, isStale: false, runsOut: true)
        XCTAssertEqual(BarsDisplay.left.shown(pace), pace)
    }

    func testUsedMirrorsTheMarkAndKeepsWhatItSays() {
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        let pace = Pace(aheadFraction: 0.43, runsOutAt: when, isStale: true, runsOut: true)
        let shown = BarsDisplay.used.shown(pace)
        XCTAssertEqual(shown.aheadFraction, 0.57, accuracy: 1e-12)
        XCTAssertEqual(shown.runsOutAt, when)
        XCTAssertTrue(shown.isStale)
        XCTAssertTrue(shown.runsOut)
    }

    func testABarThatPassesTheMarkMeansTheSameInBothReadings() {
        // 25% left with the mark at 43% runs out; in `used` the fill, 75%, ends past the mark, at 57%.
        let pace = Pace(aheadFraction: 0.43, runsOutAt: nil, isStale: false, runsOut: true)
        XCTAssertLessThan(BarsDisplay.left.fraction(remaining: 0.25), BarsDisplay.left.shown(pace).aheadFraction)
        XCTAssertGreaterThan(BarsDisplay.used.fraction(remaining: 0.25), BarsDisplay.used.shown(pace).aheadFraction)
    }

    func testASnapshotCarriesTheChoice() throws {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 1_000_000), providers: []).with(barsDisplay: .used)
        XCTAssertEqual(try decoded(try encoded(snapshot)).barsDisplay, .used)
    }

    func testASnapshotFromBeforeTheChoiceIsLeft() throws {
        let json = #"{"generatedAt":"2026-11-02T10:00:00Z","providers":[]}"#
        XCTAssertEqual(try decoded(Data(json.utf8)).barsDisplay, .left)
    }

    func testAChoiceThisVersionDoesNotKnowIsLeft() throws {
        let json = #"{"generatedAt":"2026-11-02T10:00:00Z","providers":[],"barsDisplay":"remaining-ish"}"#
        XCTAssertEqual(try decoded(Data(json.utf8)).barsDisplay, .left)
    }

    func testTheChoiceSurvivesTheProblemsTheSkinAndThePreferences() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: []).with(barsDisplay: .used)
        XCTAssertEqual(snapshot.with(problems: []).barsDisplay, .used)
        XCTAssertEqual(snapshot.with(skin: .nord).barsDisplay, .used)
        XCTAssertEqual(snapshot.applying(MemoryDisplayPreferences()).barsDisplay, .used)
    }

    func testTheSkinSurvivesTheChoice() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: []).with(skin: .dracula)
        XCTAssertEqual(snapshot.with(barsDisplay: .used).skin, .dracula)
    }
}
