import XCTest
@testable import TokenMeterCore

final class ProviderConfigWriteTests: XCTestCase {
    private var url: URL!

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("providers.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private let two = #"{"version":1,"providers":[{"id":"claude","title":"Claude","windows":[300],"log":{"root":"~/.claude/projects","timestamp":"t"}},{"id":"chatgpt","title":"ChatGPT","windows":[300]}]}"#
    private var backup: URL { url.appendingPathExtension("tokenmeter.bak") }

    private func write(_ json: String) throws { try Data(json.utf8).write(to: url) }
    private func entries() throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return object?["providers"] as? [[String: Any]] ?? []
    }

    func testAddAppendsAndKeepsTheOthersAndTheOriginalAsBackup() throws {
        try write(two)
        let entry = ProviderConfigFile.entry(for: .claudeCode, id: "claude-work", title: "Claude · work", home: "~/.claude-work")
        try ProviderConfigFile.add(entry, to: url)
        let all = try entries()
        XCTAssertEqual(all.map { $0["id"] as? String }, ["claude", "chatgpt", "claude-work"])
        XCTAssertEqual(NSDictionary(dictionary: all[0]),
                       NSDictionary(dictionary: ["id": "claude", "title": "Claude", "windows": [300],
                                                 "log": ["root": "~/.claude/projects", "timestamp": "t"]]))
        XCTAssertEqual(all[2]["home"] as? String, "~/.claude-work")
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), two, "the backup is the file as it was")
        XCTAssertEqual(try ProviderConfigFile.load(from: url)?.providers.count, 3, "the file still loads")
    }

    func testAFileThatCannotBeUsedIsNeverWritten() throws {
        try write("{ not json")
        XCTAssertThrowsError(try ProviderConfigFile.add(["id": "x", "title": "X", "windows": [300]], to: url))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "{ not json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
        XCTAssertThrowsError(try ProviderConfigFile.remove("x", from: url.appendingPathExtension("missing")))
    }

    func testARepeatedOrBadIdIsRefusedAndNothingChanges() throws {
        try write(two)
        XCTAssertThrowsError(try ProviderConfigFile.add(["id": "claude", "title": "Again", "windows": [300]], to: url)) {
            XCTAssertTrue("\($0)".contains("\"claude\""))
        }
        XCTAssertThrowsError(try ProviderConfigFile.add(["id": "no spaces", "title": "X", "windows": [300]], to: url))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), two)
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
    }

    func testRemoveTakesOnlyThatEntryOut() throws {
        try write(two)
        try ProviderConfigFile.remove("claude", from: url)
        XCTAssertEqual(try entries().map { $0["id"] as? String }, ["chatgpt"])
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), two)
        XCTAssertThrowsError(try ProviderConfigFile.remove("claude", from: url), "gone already")
    }

    func testReplacePutsTheEntryInItsPlace() throws {
        try write(two)
        try ProviderConfigFile.replace("claude", with: ["id": "claude", "title": "Claude · personal", "windows": [300]], in: url)
        let all = try entries()
        XCTAssertEqual(all.map { $0["title"] as? String }, ["Claude · personal", "ChatGPT"])
        XCTAssertThrowsError(try ProviderConfigFile.replace("gemini", with: ["id": "gemini"], in: url))
    }

    func testAnIdIsMadeFromTheTitleAndNeverRepeated() {
        XCTAssertEqual(ProviderConfigFile.id(for: "Claude · work", taken: []), "claude-work")
        XCTAssertEqual(ProviderConfigFile.id(for: "mario.rossi@example.com", taken: []), "mario.rossi-example.com")
        XCTAssertEqual(ProviderConfigFile.id(for: "  Codex (personal)  ", taken: []), "codex-personal")
        XCTAssertEqual(ProviderConfigFile.id(for: "···", taken: []), "account")
        XCTAssertEqual(ProviderConfigFile.id(for: "Claude", taken: ["claude", "claude-2"]), "claude-3")
        for title in ["Claude · work", "mario.rossi@example.com", "ünïcode", ""] {
            let id = ProviderConfigFile.id(for: title, taken: [])
            XCTAssertTrue(id.unicodeScalars.allSatisfy(ProviderConfig.idCharacters.contains), "\(title) gives \(id)")
            XCTAssertFalse(id.isEmpty)
        }
    }

    func testEditedMovesThePathsTheTemplateGaveAndLeavesAHandWrittenOne() {
        var entry = ProviderConfigFile.entry(for: .claudeCode, id: "claude-work", title: "Claude · work", home: "~/.claude-work")
        var plan = entry["plan"] as! [String: Any]
        plan["file"] = "~/Documents/claude-plan.json"
        entry["plan"] = plan
        let moved = ProviderConfigFile.edited(entry, tool: .claudeCode, title: "Work", home: "~/.claude-acme")
        XCTAssertEqual(moved["title"] as? String, "Work")
        XCTAssertEqual(moved["home"] as? String, "~/.claude-acme")
        XCTAssertEqual((moved["log"] as? [String: Any])?["root"] as? String, "~/.claude-acme/projects")
        let windows = (moved["quota"] as? [String: Any])?["windows"] as? [[String: Any]]
        XCTAssertEqual(windows?[2]["file"] as? String, "~/.claude-acme/.claude.json")
        XCTAssertEqual((moved["plan"] as? [String: Any])?["file"] as? String, "~/Documents/claude-plan.json",
                       "a path the person wrote is left alone")
        XCTAssertEqual((moved["quota"] as? [String: Any])?["file"] as? String, "~/.tokenmeter/claude-work-statusline.json",
                       "the id does not change, so neither does its file")

        let home = ProviderConfigFile.edited(moved, tool: .claudeCode, title: "Work", home: "~/.claude")
        XCTAssertNil(home["home"], "back in the default folder the entry has no home")
        XCTAssertEqual((home["log"] as? [String: Any])?["root"] as? String, "~/.claude/projects")

        let same = ProviderConfigFile.edited(entry, tool: .claudeCode, title: "Renamed", home: "~/.claude-work")
        XCTAssertEqual(same["title"] as? String, "Renamed")
        XCTAssertEqual(NSDictionary(dictionary: same["log"] as! [String: Any]),
                       NSDictionary(dictionary: entry["log"] as! [String: Any]), "a rename touches no path")
    }
}
