import XCTest
@testable import TokenMeterCore

final class ProblemCensusTests: XCTestCase {
    private let integrations = Integrations([ClaudeIntegration(script: nil)])

    func testEveryKindHasATopicAnExplanationAndAUniqueId() {
        let census = integrations.census
        XCTAssertEqual(Set(census.map(\.id)).count, census.count, "ids are unique")
        for kind in census {
            XCTAssertTrue(kind.id.hasPrefix(kind.topic + "."), "\(kind.id) starts with its topic")
            XCTAssertFalse(kind.explanation.isEmpty, "\(kind.id) explains itself")
            XCTAssertFalse(kind.summary.isEmpty)
        }
    }

    func testEveryFixOfAKindIsDeclaredByItsIntegration() {
        for integration in [ClaudeIntegration(script: nil)] {
            let declared = Set(integration.fixes.map(\.id))
            for kind in integration.kinds { if let fix = kind.fix { XCTAssertTrue(declared.contains(fix), kind.id) } }
        }
    }

    func testAProblemCarriesTheTextOfItsKind() {
        let problem = AppProblems.check(hasAppGroup: false)[0]
        XCTAssertEqual(problem.explanation, AppProblems.noAppGroup.explanation)
        XCTAssertEqual(problem.guide, AppProblems.noAppGroup.guide)
    }

    func testAKindMakesIdsWithADetail() {
        XCTAssertEqual(AppProblems.integrationNotFound.problem(detailID: "x").id, "general.integration.x")
    }

    func testTheCensusHoldsTheKindsOfTheAppAndOfEveryIntegration() {
        let ids = Set(integrations.census.map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["general.appgroup", "general.integration",
                                          "claude.statusline.other", "claude.statusline.projects"]))
    }
}
