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
        var fixes: [FixDescriptor] { [] }
        func problems(in context: ProblemContext) -> [Problem] { found }
        func run(fix: String, in context: ProblemContext) -> FixResult { .done }
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

    func testAnUnknownIntegrationIsAGeneralProblem() throws {
        let providers = try config([("a", "nope")])
        let problems = ProblemDetector.detect(general: [], providers: providers, integrations: Integrations([]),
                                              context: ProblemContext())
        XCTAssertEqual(problems.map(\.id), ["general.integration.a"])
        XCTAssertEqual(problems.first?.topic, Problem.general)
    }
}
