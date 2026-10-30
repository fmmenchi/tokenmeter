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
