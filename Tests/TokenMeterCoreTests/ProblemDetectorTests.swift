import XCTest
@testable import TokenMeterCore

final class ProblemDetectorTests: XCTestCase {
    private func problem(_ id: String, topic: String = "claude") -> Problem {
        Problem(id: id, topic: topic, message: id)
    }

    func testGeneralProblemsComeFirstThenProvidersInOrder() {
        let merged = ProblemDetector.merge(
            general: [problem("general.a", topic: "general")],
            providers: [[problem("claude.a"), problem("claude.b")], [problem("chatgpt.a", topic: "chatgpt")]])
        XCTAssertEqual(merged.map(\.id), ["general.a", "claude.a", "claude.b", "chatgpt.a"])
    }

    func testARepeatedIdKeepsTheFirstOne() {
        let first = Problem(id: "claude.a", topic: "claude", message: "first")
        let second = Problem(id: "claude.a", topic: "claude", message: "second")
        XCTAssertEqual(ProblemDetector.merge(general: [], providers: [[first], [second]]), [first])
    }

    func testNothingFoundIsAnEmptyList() {
        XCTAssertEqual(ProblemDetector.merge(general: [], providers: []), [])
    }

    func testAMissingAppGroupIsAGeneralProblem() {
        let problems = AppProblems.check(hasAppGroup: false)
        XCTAssertEqual(problems.map(\.id), ["general.appgroup"])
        XCTAssertEqual(problems.first?.topic, Problem.general)
        XCTAssertNil(problems.first?.fix)
    }

    func testAnAppGroupMeansNoProblem() {
        XCTAssertEqual(AppProblems.check(hasAppGroup: true), [])
    }
}

final class ProblemDetectionTests: XCTestCase {
    private struct Stub: ProviderIntegration {
        let id: String
        let found: [Problem]
        var kinds: [ProblemKind] { [] }
        var fixes: [FixDescriptor] { [] }
        func problems(for provider: ProviderConfig, in context: ProblemContext) -> [Problem] { found }
        func run(fix: String, for provider: ProviderConfig, in context: ProblemContext) -> FixResult { .done }
    }

    private func config(_ ids: [(String, String?)]) throws -> [ProviderConfig] {
        let items = ids.map { id, integration in
            #"{"id":"\#(id)","title":"\#(id.capitalized)","windows":[60]\#(integration.map { #","integration":"\#($0)""# } ?? "")}"#
        }
        let json = #"{"version":1,"providers":[\#(items.joined(separator: ","))]}"#
        return try ProviderConfigFile.decode(Data(json.utf8), origin: "test").providers
    }

    func testEachProviderWithAnIntegrationContributesItsProblems() throws {
        let a = Problem(id: "a.x", topic: "a", message: "a")
        let integrations = Integrations([Stub(id: "a-int", found: [a])])
        let providers = try config([("a", "a-int"), ("b", nil)])
        XCTAssertEqual(ProblemDetector.detect(general: [], providers: providers, integrations: integrations,
                                              context: ProblemContext()), [a])
    }

    private struct Tooled: ProviderIntegration {
        let id: String
        let tool: AccountTool?
        var kinds: [ProblemKind] { [] }
        var fixes: [FixDescriptor] { [] }
        func problems(for provider: ProviderConfig, in context: ProblemContext) -> [Problem] { [] }
        func run(fix: String, for provider: ProviderConfig, in context: ProblemContext) -> FixResult { .done }
    }

    func testAFolderNoEntryNamesIsAGeneralProblemNamedByTheFolder() throws {
        let home = URL(fileURLWithPath: "/Users/sample", isDirectory: true)
        let context = ProblemContext(home: home)
        let integrations = Integrations([Tooled(id: "claude-status-line", tool: .claudeCode), Tooled(id: "codex", tool: .codexCLI)])
        let json = """
        {"version":1,"providers":[
          {"id":"claude","title":"Claude","windows":[300],"integration":"claude-status-line"},
          {"id":"claude-work","title":"Claude · work","windows":[300],"integration":"claude-status-line","home":"~/.claude-work"},
          {"id":"chatgpt","title":"ChatGPT","windows":[300],"integration":"codex"}]}
        """
        let providers = try ProviderConfigFile.decode(Data(json.utf8), origin: "test").providers
        let folders = [
            AccountFolders.Found(tool: .claudeCode, folder: home.appendingPathComponent(".claude"), email: "a@example.com"),
            AccountFolders.Found(tool: .claudeCode, folder: home.appendingPathComponent(".claude-work"), email: nil),
            AccountFolders.Found(tool: .codexCLI, folder: home.appendingPathComponent(".codex"), email: nil),
            AccountFolders.Found(tool: .codexCLI, folder: home.appendingPathComponent(".codex-personal"), email: "mario.rossi@example.com"),
            AccountFolders.Found(tool: .claudeCode, folder: home.appendingPathComponent(".claude-old"), email: nil),
        ]
        let problems = ProblemDetector.detect(general: [], providers: providers, integrations: integrations, context: context,
                                              folders: folders)
        XCTAssertEqual(problems.map(\.id), ["general.folder.codex-personal", "general.folder.claude-old"])
        XCTAssertEqual(problems[0].topic, Problem.general)
        XCTAssertEqual(problems[0].message, "A Codex CLI folder is not in providers.json")
        XCTAssertEqual(problems[0].detail, "~/.codex-personal is signed in as mario.rossi@example.com, and no entry names it. "
                       + "Add it writes an entry, and the card appears.")
        XCTAssertEqual(problems[1].detail, "~/.claude-old has no login yet, and no entry names it. Add it writes an entry, and the card appears.")
        XCTAssertNil(problems[0].fix, "the detector offers no fix: Add it is the app's")
        XCTAssertEqual(problems[0].guide, "use/accounts")
    }

    func testAFolderOfAToolWhoseIntegrationIsUnknownIsStillReportedAndAnEntryWithAnUnknownOneNamesNothing() throws {
        let home = URL(fileURLWithPath: "/Users/sample", isDirectory: true)
        let providers = try config([("claude", "nope")])
        let folders = [AccountFolders.Found(tool: .claudeCode, folder: home.appendingPathComponent(".claude"), email: nil)]
        let problems = ProblemDetector.detect(general: [], providers: providers, integrations: Integrations([]),
                                              context: ProblemContext(home: home), folders: folders)
        XCTAssertEqual(problems.map(\.id), ["general.folder.claude", "general.integration.claude"])
    }

    func testAnUnknownIntegrationIsAGeneralProblem() throws {
        let providers = try config([("a", "nope")])
        let problems = ProblemDetector.detect(general: [], providers: providers, integrations: Integrations([]),
                                              context: ProblemContext())
        XCTAssertEqual(problems.map(\.id), ["general.integration.a"])
        XCTAssertEqual(problems.first?.topic, Problem.general)
    }
}
