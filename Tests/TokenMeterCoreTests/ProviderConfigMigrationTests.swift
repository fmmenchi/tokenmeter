import XCTest
@testable import TokenMeterCore

final class ProviderConfigMigrationTests: XCTestCase {
    private var url: URL!

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("providers.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func write(_ json: String) throws { try Data(json.utf8).write(to: url) }
    private func integration(of id: String) throws -> String? {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return (object?["providers"] as? [[String: Any]])?.first { $0["id"] as? String == id }?["integration"] as? String
    }

    private let old = #"{"version":1,"providers":[{"id":"chatgpt","title":"ChatGPT","windows":[300]},{"id":"claude","title":"Claude","windows":[300]}]}"#

    func testTheClaudeEntryGainsTheFieldAndTheOriginalIsKept() throws {
        try write(old)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .migrated)
        XCTAssertEqual(try integration(of: "claude"), "claude-status-line")
        XCTAssertEqual(try integration(of: "chatgpt"), "codex", "the Codex CLI gets its integration too (ADR 0014)")
        XCTAssertEqual(try String(contentsOf: url.appendingPathExtension("tokenmeter.bak")), old)
        let file = try ProviderConfigFile.load(from: url)
        XCTAssertEqual(file?.providers.map(\.id), ["chatgpt", "claude"], "the order is kept and the file still loads")
    }

    func testItRunsOnceAndThenLeavesTheFileAlone() throws {
        try write(old)
        ProviderConfigFile.addClaudeIntegration(to: url)
        let after = try Data(contentsOf: url)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        XCTAssertEqual(try Data(contentsOf: url), after)
    }

    func testTheCodexEntryGainsItsIntegrationEvenWithoutAClaudeOne() throws {
        try write(#"{"version":1,"providers":[{"id":"chatgpt","title":"ChatGPT","windows":[300]}]}"#)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .migrated)
        XCTAssertEqual(try integration(of: "chatgpt"), "codex")
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        try write(#"{"version":1,"providers":[{"id":"chatgpt","title":"ChatGPT","windows":[300],"integration":"mine"}]}"#)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        XCTAssertEqual(try integration(of: "chatgpt"), "mine", "a chosen value is never overwritten")
    }

    func testAChosenValueIsNeverOverwritten() throws {
        try write(#"{"version":1,"providers":[{"id":"claude","title":"C","windows":[60],"integration":""}]}"#)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        XCTAssertEqual(try integration(of: "claude"), "")
    }

    func testAFileThatIsNotUsableIsNotTouched() throws {
        try write("{ not json")
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        XCTAssertEqual(try String(contentsOf: url), "{ not json")
        try write(#"{"version":2,"providers":[{"id":"claude"}]}"#)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
    }

    func testAMissingFileStaysMissing() {
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testTheSeedCarriesTheField() {
        XCTAssertEqual(ProviderConfigFile.seed().providers.first { $0.id == "claude" }?.integration, "claude-status-line")
    }

    // MARK: Usage facts (ADR 0010)

    private let withUsage = #"{"version":1,"providers":[{"id":"claude","title":"Claude","windows":[300],"usage":{"mode":"perEvent","tokens":{}}},{"id":"chatgpt","title":"ChatGPT","windows":[300],"usage":{"mode":"cumulative","tokens":{},"families":[{"contains":"mine","family":"Mine"}]}}]}"#

    private func usage(of id: String) throws -> ProviderConfig.Usage? {
        try ProviderConfigFile.load(from: url)?.providers.first { $0.id == id }?.usage
    }

    func testUsageFactsAreAddedOnceAndWhatThePersonWroteStays() throws {
        try write(withUsage)
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .migrated)
        XCTAssertEqual(try usage(of: "claude")?.model, "message.model")
        XCTAssertEqual(try usage(of: "claude")?.families?.map(\.family), ["Fable", "Sonnet", "Opus", "Haiku"])
        XCTAssertEqual(try usage(of: "chatgpt")?.families, [.init(contains: "mine", family: "Mine")], "the person's rules stay")
        XCTAssertNil(try usage(of: "chatgpt")?.model)
        XCTAssertEqual(try String(contentsOf: url.appendingPathExtension("tokenmeter.bak")), withUsage)

        let after = try Data(contentsOf: url)
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .untouched)
        XCTAssertEqual(try Data(contentsOf: url), after, "the second run changes nothing")
    }

    func testTheBackupIsTheFileAsItWasBeforeThisMigration() throws {
        try write(withUsage)
        try Data("a backup of an earlier migration".utf8).write(to: url.appendingPathExtension("tokenmeter.bak"))
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .migrated)
        XCTAssertEqual(try String(contentsOf: url.appendingPathExtension("tokenmeter.bak")), withUsage)
    }

    func testAFileThatNeedsBothMigrationsKeepsAsItsBackupTheFileAsThePersonWroteIt() throws {
        try write(withUsage)
        _ = Providers.standard(config: url, home: url.deletingLastPathComponent())
        XCTAssertEqual(try integration(of: "claude"), "claude-status-line", "the first migration ran")
        XCTAssertEqual(try usage(of: "claude")?.model, "message.model", "and the second")
        XCTAssertEqual(try String(contentsOf: url.appendingPathExtension("tokenmeter.bak")), withUsage)
    }

    func testUsageFactsLeaveAnotherFileAlone() throws {
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .untouched, "no file")
        try write(#"{"version":2,"providers":[{"id":"claude","usage":{}}]}"#)
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .untouched, "another version")
        try write(#"{"version":1,"providers":[{"id":"claude","title":"Claude","windows":[300]},{"id":"other","title":"O","windows":[60],"usage":{"mode":"perEvent","tokens":{}}}]}"#)
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .untouched, "no usage to add to, and a provider it does not know")
    }

    func testTheLogOfCodexGainsTheLineThatNamesTheModelOnce() throws {
        try write(#"{"version":1,"providers":[{"id":"chatgpt","title":"ChatGPT","windows":[300],"log":{"root":"r","timestamp":"timestamp"},"usage":{"mode":"cumulative","tokens":{}}}]}"#)
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .migrated)
        let log = try ProviderConfigFile.load(from: url)?.providers.first?.log
        XCTAssertEqual(log?.context?.model, "payload.model")
        XCTAssertEqual(log?.context?.where, ["type": "turn_context"])
        XCTAssertEqual(ProviderConfigFile.addUsageFacts(to: url), .untouched)
        XCTAssertEqual(log?.context?.contains, ProviderConfigFile.seed().providers.first { $0.id == "chatgpt" }?.log?.context?.contains,
                       "the same as the seed")
    }

    func testTheSeedAndTheMigrationSayTheSame() throws {
        let seed = ProviderConfigFile.seed().providers
        for id in ["claude", "chatgpt"] {
            try write(#"{"version":1,"providers":[{"id":"\#(id)","title":"T","windows":[300],"usage":{"mode":"perEvent","tokens":{}}}]}"#)
            ProviderConfigFile.addUsageFacts(to: url)
            let migrated = try usage(of: id)
            let seeded = seed.first { $0.id == id }?.usage
            XCTAssertEqual(migrated?.families, seeded?.families, id)
            if id == "claude" { XCTAssertEqual(migrated?.model, seeded?.model) }
        }
    }
}

final class ModelLimitMigrationTests: XCTestCase {
    private var url: URL!

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("providers.json")
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    private let old = #"{"version":1,"providers":[{"id":"claude","title":"Claude","windows":[300,10080],"integration":"claude-status-line","quota":{"file":"~/.tokenmeter/claude-statusline.json","windows":[{"at":"rate_limits.five_hour","minutes":300,"usedPercent":"used_percentage"}]}}]}"#

    private func windowCount() throws -> Int {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let quota = ((object?["providers"] as? [[String: Any]])?.first?["quota"] as? [String: Any])
        return (quota?["windows"] as? [[String: Any]])?.count ?? 0
    }

    func testAnExistingClaudeEntryGainsTheModelLimitWindowOnce() throws {
        try Data(old.utf8).write(to: url)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .migrated)
        XCTAssertEqual(try windowCount(), 2)
        XCTAssertEqual(try String(contentsOf: url.appendingPathExtension("tokenmeter.bak")), old)

        let file = try ProviderConfigFile.load(from: url)
        XCTAssertEqual(file?.providers.first?.quota?.windows.last?.each, "cachedUsageUtilization.utilization.limits")
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        XCTAssertEqual(try windowCount(), 2, "added once")
    }

    func testAFileThatAlreadyHasAListWindowDoesNotGetAnotherOne() throws {
        let json = old.replacingOccurrences(of: #"{"at":"rate_limits.five_hour""#, with: #"{"each":"x.y","usedPercent":"percent"},{"at":"rate_limits.five_hour""#)
        try Data(json.utf8).write(to: url)
        ProviderConfigFile.addClaudeIntegration(to: url)
        let windows = try ProviderConfigFile.load(from: url)?.providers.first?.quota?.windows ?? []
        XCTAssertEqual(windows.filter { $0.each != nil }.count, 1, "the model window is not added twice")
        XCTAssertEqual(windows.first { $0.each == nil }?.existsIf?.where?["kind"], "session", "the 5 hours still get their rule")
    }

    func testTheSeedCarriesTheModelLimitWindow() {
        let claude = ProviderConfigFile.seed().providers.first { $0.id == "claude" }
        XCTAssertEqual(claude?.quota?.windows.filter { $0.each != nil }.count, 1)
    }
}

final class UltraPlanMigrationTests: XCTestCase {
    private var url: URL!

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("providers.json")
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    private func json(label: String) -> String {
        #"{"version":1,"providers":[{"id":"claude","title":"Claude","windows":[300,10080],"integration":"claude-status-line","quota":{"file":"f","windows":[{"each":"x","usedPercent":"p"}]},"plan":{"path":"a","labels":[{"path":"b","contains":"max_20x","label":"\#(label)"}]}}]}"#
    }

    private func label() throws -> String? {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let plan = (object?["providers"] as? [[String: Any]])?.first?["plan"] as? [String: Any]
        return (plan?["labels"] as? [[String: Any]])?.first?["label"] as? String
    }

    func testTheOldDefaultNameOfTheTwentyTimesPlanBecomesUltra() throws {
        try Data(json(label: "Max 20x").utf8).write(to: url)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .migrated)
        XCTAssertEqual(try label(), "Ultra")
    }

    func testANameThePersonWroteIsLeftAlone() throws {
        try Data(json(label: "My big plan").utf8).write(to: url)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
        XCTAssertEqual(try label(), "My big plan")
    }
}

final class FiveHourRuleMigrationTests: XCTestCase {
    func testTheSeedAndAnOldFileGetTheRuleOnce() throws {
        let seed = ProviderConfigFile.seed().providers.first { $0.id == "claude" }
        XCTAssertNotNil(seed?.quota?.windows.first { $0.minutes == 300 }?.existsIf)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("providers.json")
        let old = #"{"version":1,"providers":[{"id":"claude","title":"C","windows":[300,10080],"integration":"claude-status-line","quota":{"file":"f","windows":[{"at":"rate_limits.five_hour","minutes":300,"usedPercent":"u"},{"each":"x","usedPercent":"p"}]}}]}"#
        try Data(old.utf8).write(to: url)
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .migrated)
        let file = try ProviderConfigFile.load(from: url)
        XCTAssertEqual(file?.providers.first?.quota?.windows.first?.existsIf?.where?["kind"], "session")
        XCTAssertEqual(ProviderConfigFile.addClaudeIntegration(to: url), .untouched)
    }
}
