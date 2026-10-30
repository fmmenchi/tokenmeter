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

    private func writeSettings(_ json: String) throws {
        try Data(json.utf8).write(to: home.appendingPathComponent(".claude/settings.json"))
    }

    func testNoStatusLineAndNoProjectsIsNoProblem() throws {
        try writeSettings(#"{"model":"opus"}"#)
        XCTAssertEqual(integration.problems(in: context), [])
    }

    func testAnotherStatusLineIsAProblemWithAFix() throws {
        try writeSettings(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        let problems = integration.problems(in: context)
        XCTAssertEqual(problems.map(\.id), ["claude.statusline.other"])
        XCTAssertEqual(problems.first?.fix, ClaudeIntegration.wrapStatusLine)
        XCTAssertEqual(problems.first?.topic, "claude")
        XCTAssertEqual(integration.fixes.map(\.id), [ClaudeIntegration.wrapStatusLine])
    }

    func testAStatusLineThatIsNotACommandHasNoFix() throws {
        try writeSettings(#"{"statusLine":{"type":"static","text":"hi"}}"#)
        XCTAssertNil(integration.problems(in: context).first?.fix)
    }

    func testTokenmetersOwnStatusLineIsNotAProblem() throws {
        let own = home.appendingPathComponent(".tokenmeter/claude-statusline.sh").path
        try writeSettings(#"{"statusLine":{"type":"command","command":"\#(own)"}}"#)
        XCTAssertEqual(integration.problems(in: context), [])
    }

    func testTheFixLeavesTheProblemGone() throws {
        try writeSettings(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        XCTAssertEqual(integration.run(fix: ClaudeIntegration.wrapStatusLine, in: context), .done)
        XCTAssertEqual(integration.problems(in: context), [])
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
        let problems = integration.problems(in: context)
        XCTAssertEqual(problems.map(\.id), ["claude.statusline.projects"])
        XCTAssertEqual(problems.first?.message, "2 projects set their own status line")
        XCTAssertEqual(problems.first?.detail, "Claude bars freeze there: app-a, app-b.")
        XCTAssertNil(problems.first?.fix)
    }

    func testWithoutAScriptTheFixFailsAndChangesNothing() throws {
        let json = #"{"statusLine":{"type":"command","command":"/bin/mine"}}"#
        try writeSettings(json)
        let result = ClaudeIntegration(script: nil).run(fix: ClaudeIntegration.wrapStatusLine, in: context)
        guard case .failed = result else { return XCTFail("expected a failure, got \(result)") }
        XCTAssertEqual(try String(contentsOf: home.appendingPathComponent(".claude/settings.json")), json)
    }

    func testAnUnknownFixFails() {
        guard case .failed = integration.run(fix: "nope", in: context) else { return XCTFail("expected a failure") }
    }
}
