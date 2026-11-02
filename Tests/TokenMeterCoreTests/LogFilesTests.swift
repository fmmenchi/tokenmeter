import XCTest
@testable import TokenMeterCore

final class LogFilesTests: XCTestCase {
    private func file(_ text: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("a.jsonl")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func scan(_ url: URL, from offset: UInt64 = 0, chunk: Int = 7, markers: [String] = ["use"]) -> (lines: [String], offset: UInt64) {
        var lines: [String] = []
        let next = LogFiles.scanNewLines(in: url, from: offset, containing: markers.map { Data($0.utf8) }, chunk: chunk) {
            lines.append(String(decoding: $0, as: UTF8.self))
        }
        return (lines, next)
    }

    func testLinesLongerThanAChunkAreWholeAndOnlyThoseWithAMarkerComeOut() throws {
        let long = "use " + String(repeating: "x", count: 100)
        let url = try file("skip me\n\(long)\nuse two\nnothing\n")
        let result = scan(url)
        XCTAssertEqual(result.lines, [long, "use two"])
        XCTAssertEqual(result.offset, UInt64("skip me\n\(long)\nuse two\nnothing\n".utf8.count))
    }

    func testAPartialLastLineIsLeftForTheNextCall() throws {
        let url = try file("use one\nuse tw")
        let first = scan(url)
        XCTAssertEqual(first.lines, ["use one"])
        XCTAssertEqual(first.offset, 8)

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("o\nuse three\n".utf8))
        try handle.close()
        let second = scan(url, from: first.offset)
        XCTAssertEqual(second.lines, ["use two", "use three"])
        XCTAssertEqual(second.offset, UInt64("use one\nuse two\nuse three\n".utf8.count))
    }

    func testAnyOfTheMarkersIsEnough() throws {
        let url = try file("alpha\nbeta\ngamma\n")
        XCTAssertEqual(scan(url, markers: ["alp", "gam"]).lines, ["alpha", "gamma"])
    }

    func testAFileThatShrankIsReadFromTheStart() throws {
        let url = try file("use a\n")
        let result = scan(url, from: 500)
        XCTAssertEqual(result.lines, ["use a"])
        XCTAssertEqual(result.offset, 6)
    }

    func testAFileWithNoNewlineGivesNothingAndKeepsItsOffset() throws {
        let url = try file("use never ends")
        let result = scan(url, from: 0)
        XCTAssertEqual(result.lines, [])
        XCTAssertEqual(result.offset, 0)
    }

    func testAMissingFileKeepsTheOffset() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString).jsonl")
        let result = scan(missing, from: 42)
        XCTAssertEqual(result.lines, [])
        XCTAssertEqual(result.offset, 42)
    }
}
