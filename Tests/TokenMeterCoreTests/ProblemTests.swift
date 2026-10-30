import XCTest
@testable import TokenMeterCore

final class ProblemTests: XCTestCase {
    func testAProblemSurvivesEncodingAndDecoding() throws {
        let problem = Problem(id: "claude.statusline.other", topic: "claude", message: "Another status line is in use",
                              detail: "It was left alone.", fix: "wrapStatusLine", guide: "use/enable-claude-quota")
        let data = try JSONEncoder().encode(problem)
        XCTAssertEqual(try JSONDecoder().decode(Problem.self, from: data), problem)
    }

    func testAProblemWithoutAFixOrAGuideDecodes() throws {
        let json = #"{"id":"general.appgroup","topic":"general","message":"The widget cannot read the data"}"#
        let problem = try JSONDecoder().decode(Problem.self, from: Data(json.utf8))
        XCTAssertNil(problem.fix)
        XCTAssertNil(problem.detail)
        XCTAssertNil(problem.guide)
    }

    func testATopicTheAppDoesNotKnowStillDecodes() throws {
        let json = #"{"id":"mistral.x","topic":"mistral","message":"m"}"#
        XCTAssertEqual(try JSONDecoder().decode(Problem.self, from: Data(json.utf8)).topic, "mistral")
    }

    func testTheIdentityOfAProblemIsItsId() {
        XCTAssertEqual(Problem(id: "a.b", topic: "a", message: "m").id, "a.b")
    }
}
