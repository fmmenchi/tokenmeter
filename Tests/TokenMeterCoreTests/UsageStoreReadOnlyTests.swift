import XCTest
@testable import TokenMeterCore

/// ADR 0017: the command reads the store and never makes, moves or changes it.
final class UsageStoreReadOnlyTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: folder) }

    func testItReadsWhatTheAppWrote() throws {
        let url = folder.appendingPathComponent("usage.sqlite")
        let writer = try UsageStore(url: url)
        writer.insert([UsageStore.Message(provider: Provider(rawValue: "claude"), key: "a", at: Date(), model: "claude-opus-5-5",
                                          tokens: TokenCounts(input: 1, output: 2, cacheRead: 3, cacheWrite: 4))])
        let reader = try UsageStore.readOnly(url: url)
        XCTAssertEqual(reader.costTotals(provider: Provider(rawValue: "claude")).first?.cacheWrite, 4)
    }

    func testAMissingFileIsThrownAndNotMade() {
        let url = folder.appendingPathComponent("none.sqlite")
        XCTAssertThrowsError(try UsageStore.readOnly(url: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testAFileThatIsNotADatabaseIsLeftWhereItIs() throws {
        let url = folder.appendingPathComponent("usage.sqlite")
        try Data("not a database".utf8).write(to: url)
        XCTAssertThrowsError(try UsageStore.readOnly(url: url))
        XCTAssertEqual(try Data(contentsOf: url), Data("not a database".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path + ".damaged"))
    }
}
