import XCTest
@testable import TokenMeterCore

final class ClaudeStatusLineTests: XCTestCase {
    private var home: URL!
    private let script = Data("#!/bin/sh\nexit 0\n".utf8)

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private var claude: URL { home.appendingPathComponent(".claude") }
    private var settings: URL { claude.appendingPathComponent("settings.json") }
    private var command: String { home.appendingPathComponent(".tokenmeter/claude-statusline.sh").path }

    private func makeClaude(settings json: String? = nil) throws {
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        if let json { try Data(json.utf8).write(to: settings) }
    }

    private func statusLine() throws -> [String: Any]? {
        let data = try Data(contentsOf: settings)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["statusLine"] as? [String: Any]
    }

    func testWithoutClaudeNothingIsCreated() throws {
        XCTAssertEqual(try ClaudeStatusLine.setUp(script: script, home: home), .notInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: claude.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".tokenmeter").path))
    }

    func testMissingSettingsAreCreatedAndTheScriptIsExecutable() throws {
        try makeClaude()
        XCTAssertEqual(try ClaudeStatusLine.setUp(script: script, home: home), .set)
        XCTAssertEqual(try statusLine()?["command"] as? String, command)
        let attributes = try FileManager.default.attributesOfItem(atPath: command)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o755)
    }

    func testOtherKeysAreKeptAndABackupIsWritten() throws {
        try makeClaude(settings: #"{"model":"opus","theme":"dark"}"#)
        XCTAssertEqual(try ClaudeStatusLine.setUp(script: script, home: home), .set)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any]
        XCTAssertEqual(object?["model"] as? String, "opus")
        XCTAssertEqual(object?["theme"] as? String, "dark")
        let backup = try String(contentsOf: claude.appendingPathComponent("settings.json.tokenmeter.bak"), encoding: .utf8)
        XCTAssertEqual(backup, #"{"model":"opus","theme":"dark"}"#)
    }

    func testAnotherStatusLineIsLeftAlone() throws {
        let original = #"{"statusLine":{"type":"command","command":"/usr/local/bin/mine"}}"#
        try makeClaude(settings: original)
        XCTAssertEqual(try ClaudeStatusLine.setUp(script: script, home: home), .otherStatusLine("/usr/local/bin/mine"))
        XCTAssertEqual(try String(contentsOf: settings, encoding: .utf8), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: claude.appendingPathComponent("settings.json.tokenmeter.bak").path))
    }

    func testUnreadableSettingsAreNotTouched() throws {
        try makeClaude(settings: "{ not json")
        XCTAssertEqual(try ClaudeStatusLine.setUp(script: script, home: home), .unreadableSettings)
        XCTAssertEqual(try String(contentsOf: settings, encoding: .utf8), "{ not json")
    }

    func testRunningTwiceChangesNothingTheSecondTime() throws {
        try makeClaude(settings: "{}")
        XCTAssertEqual(try ClaudeStatusLine.setUp(script: script, home: home), .set)
        let first = try Data(contentsOf: settings)
        XCTAssertEqual(try ClaudeStatusLine.setUp(script: script, home: home), .alreadySet)
        XCTAssertEqual(try Data(contentsOf: settings), first)
    }

    func testAnUpdatedScriptReplacesTheCopy() throws {
        try makeClaude()
        _ = try ClaudeStatusLine.setUp(script: script, home: home)
        let newer = Data("#!/bin/sh\nexit 1\n".utf8)
        _ = try ClaudeStatusLine.setUp(script: newer, home: home)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: command)), newer)
    }
}
