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
        XCTAssertNil(try integration(of: "chatgpt"))
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
}
