import XCTest
@testable import TokenMeterCore

/// The failures the app meets while it runs are problems, not only lines in a log (ADR 0005).
final class AppProblemsTests: XCTestCase {
    func testNothingWrongIsNoProblem() {
        XCTAssertEqual(AppProblems.check(hasAppGroup: true, providersFileError: nil, snapshotWriteError: nil, usageRefresh: .refreshed), [])
        XCTAssertEqual(AppProblems.check(hasAppGroup: true), [])
    }

    func testABrokenProvidersFileSaysWhy() {
        let problems = AppProblems.check(hasAppGroup: true, providersFileError: "version 2 is not known")
        XCTAssertEqual(problems.map(\.id), ["general.providersfile"])
        XCTAssertEqual(problems.first?.detail, "version 2 is not known")
        XCTAssertEqual(problems.first?.topic, Problem.general)
        XCTAssertNil(problems.first?.fix, "the file is the person's: the app does not mend it")
    }

    func testAFailedWriteOfTheSnapshotIsAProblem() {
        XCTAssertEqual(AppProblems.check(hasAppGroup: true, snapshotWriteError: "No space left on device").map(\.id),
                       ["general.snapshotwrite"])
    }

    func testAnUnansweredUsageRefreshIsAProblemButAMissingClaudeIsNot() {
        XCTAssertEqual(AppProblems.check(hasAppGroup: true, usageRefresh: .timedOut).map(\.id), ["general.usagerefresh"])
        XCTAssertEqual(AppProblems.check(hasAppGroup: true, usageRefresh: .failed("exit 3")).first?.detail, "Claude Code failed: exit 3.")
        XCTAssertEqual(AppProblems.check(hasAppGroup: true, usageRefresh: .notFound), [], "no Claude Code, nothing to refresh")
    }

    func testSeveralFailuresKeepTheirOrderAndTheirOwnIds() {
        let all = AppProblems.check(hasAppGroup: false, providersFileError: "x", snapshotWriteError: "y", usageRefresh: .timedOut)
        XCTAssertEqual(all.map(\.id), ["general.appgroup", "general.providersfile", "general.snapshotwrite", "general.usagerefresh"])
    }

    func testEveryKindIsInTheCensusWithItsTextAndAGuide() {
        for kind in [AppProblems.providersFileBroken, AppProblems.snapshotNotWritten, AppProblems.usageRefreshFailed] {
            XCTAssertTrue(AppProblems.kinds.contains(kind), kind.id)
            XCTAssertNotNil(kind.guide)
            XCTAssertFalse(kind.explanation.isEmpty)
        }
    }
}
