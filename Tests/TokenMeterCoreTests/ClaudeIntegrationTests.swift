import XCTest
@testable import TokenMeterCore

final class ClaudeIntegrationTests: XCTestCase {
    private var home: URL!
    private let script = Data("#!/bin/sh\nexit 0\n".utf8)

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".claude"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private var context: ProblemContext { ProblemContext(home: home) }
    private var integration: ClaudeIntegration { ClaudeIntegration(script: script) }
    /// The seed entry in the default folder: what every check before accounts was about.
    private var seed: ProviderConfig { ProviderConfigFile.seed().providers.first { $0.id == "claude" }! }

    private func writeSettings(_ json: String) throws {
        try Data(json.utf8).write(to: home.appendingPathComponent(".claude/settings.json"))
    }

    func testNoStatusLineAndNoProjectsIsNoProblem() throws {
        try writeSettings(#"{"model":"opus"}"#)
        XCTAssertEqual(integration.problems(for: seed, in: context), [])
    }

    func testAnotherStatusLineIsAProblemWithAFix() throws {
        try writeSettings(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        let problems = integration.problems(for: seed, in: context)
        XCTAssertEqual(problems.map(\.id), ["claude.statusline.other"])
        XCTAssertEqual(problems.first?.fix, ClaudeIntegration.wrapStatusLine)
        XCTAssertEqual(problems.first?.topic, "claude")
        XCTAssertEqual(integration.fixes.map(\.id), [ClaudeIntegration.wrapStatusLine])
    }

    func testNothingIsReportedWhileTheSetupIsOff() throws {
        try writeSettings(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        XCTAssertEqual(ClaudeIntegration(script: script, enabled: false).problems(for: seed, in: context), [])
    }

    func testAStatusLineThatIsNotACommandHasNoFix() throws {
        try writeSettings(#"{"statusLine":{"type":"static","text":"hi"}}"#)
        XCTAssertNil(integration.problems(for: seed, in: context).first?.fix)
    }

    func testTokenmetersOwnStatusLineIsNotAProblem() throws {
        let own = home.appendingPathComponent(".tokenmeter/claude-statusline.sh").path
        try writeSettings(#"{"statusLine":{"type":"command","command":"\#(own)"}}"#)
        XCTAssertEqual(integration.problems(for: seed, in: context), [])
    }

    func testTheFixLeavesTheProblemGone() throws {
        try writeSettings(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        XCTAssertEqual(integration.run(fix: ClaudeIntegration.wrapStatusLine, for: seed, in: context), .done)
        XCTAssertEqual(integration.problems(for: seed, in: context), [])
    }

    // MARK: one entry at a time (ADR 0014)

    private func entry(_ json: String) throws -> ProviderConfig {
        try ProviderConfigFile.decode(Data(#"{"version":1,"providers":[\#(json)]}"#.utf8), origin: "test").providers[0]
    }

    func testAnAccountsProblemsNameItAndAreFoundInItsFolder() throws {
        let work = try entry(#"{"id":"claude-work","title":"Claude · work","windows":[300],"home":"~/.claude-work"}"#)
        let folder = home.appendingPathComponent(".claude-work")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#.utf8)
            .write(to: folder.appendingPathComponent("settings.json"))
        try writeSettings(#"{"model":"opus"}"#)

        let problems = integration.problems(for: work, in: context)
        XCTAssertEqual(problems.map(\.id), ["claude-work.statusline.other"])
        XCTAssertEqual(problems.first?.topic, "claude-work")
        XCTAssertEqual(problems.first?.detail, "In ~/.claude-work it was left alone, so the Claude · work bars do not update.")
        XCTAssertEqual(problems.first?.fix, ClaudeIntegration.wrapStatusLine)
        let seed = try entry(#"{"id":"claude","title":"Claude","windows":[300]}"#)
        XCTAssertEqual(integration.problems(for: seed, in: context), [], "the default folder has no other status line")

        XCTAssertEqual(integration.run(fix: ClaudeIntegration.wrapStatusLine, for: work, in: context), .done)
        XCTAssertEqual(integration.problems(for: work, in: context), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent(".tokenmeter/claude-work/statusline-wrapper.sh").path),
                      "the wrapper is the account's")
        XCTAssertEqual(try String(contentsOf: home.appendingPathComponent(".claude/settings.json"), encoding: .utf8),
                       #"{"model":"opus"}"#, "the default folder was not touched")
    }

    func testAnEntryWithoutAHomeIsTheDefaultFolder() throws {
        try writeSettings(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        let seed = try entry(#"{"id":"claude","title":"Claude","windows":[300]}"#)
        let problems = integration.problems(for: seed, in: context)
        XCTAssertEqual(problems.map(\.id), ["claude.statusline.other"], "the seed entry keeps the ids of before")
        XCTAssertEqual(problems.first?.detail, "In ~/.claude it was left alone, so the Claude bars do not update.")
    }

    func testProjectsThatOverrideAreOneProblemWithoutAFix() throws {
        try writeSettings(#"{}"#)
        for name in ["app-a", "app-b"] {
            let project = home.appendingPathComponent("work/\(name)")
            try FileManager.default.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
            try Data(#"{"statusLine":{"type":"command","command":"/bin/x"}}"#.utf8)
                .write(to: project.appendingPathComponent(".claude/settings.json"))
            let folder = home.appendingPathComponent(".claude/projects/\(name)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(#"{"cwd":"\#(project.path)"}"#.utf8).write(to: folder.appendingPathComponent("a.jsonl"))
        }
        let problems = integration.problems(for: seed, in: context)
        XCTAssertEqual(problems.map(\.id), ["claude.statusline.projects"])
        XCTAssertEqual(problems.first?.message, "2 projects set their own status line")
        XCTAssertEqual(problems.first?.detail, "Claude bars freeze there: app-a, app-b.")
        XCTAssertNil(problems.first?.fix)
    }

    func testWithoutAScriptTheFixFailsAndChangesNothing() throws {
        let json = #"{"statusLine":{"type":"command","command":"/bin/mine"}}"#
        try writeSettings(json)
        let result = ClaudeIntegration(script: nil).run(fix: ClaudeIntegration.wrapStatusLine, for: seed, in: context)
        guard case .failed = result else { return XCTFail("expected a failure, got \(result)") }
        XCTAssertEqual(try String(contentsOf: home.appendingPathComponent(".claude/settings.json")), json)
    }

    func testAnUnknownFixFails() {
        guard case .failed = integration.run(fix: "nope", in: context) else { return XCTFail("expected a failure") }
    }
}
