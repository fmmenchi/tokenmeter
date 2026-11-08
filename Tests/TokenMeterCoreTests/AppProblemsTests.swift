import XCTest
@testable import TokenMeterCore

/// The failures the app meets while it runs are problems, not only lines in a log (ADR 0005).
final class AppProblemsTests: XCTestCase {
    func testNothingWrongIsNoProblem() {
        XCTAssertEqual(AppProblems.check(hasAppGroup: true, providersFileError: nil, snapshotWriteError: nil), [])
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

    func testSeveralFailuresKeepTheirOrderAndTheirOwnIds() {
        let all = AppProblems.check(hasAppGroup: false, providersFileError: "x", snapshotWriteError: "y")
        XCTAssertEqual(all.map(\.id), ["general.appgroup", "general.providersfile", "general.snapshotwrite"])
    }

    func testEveryKindIsInTheCensusWithItsTextAndAGuide() {
        for kind in [AppProblems.providersFileBroken, AppProblems.snapshotNotWritten] {
            XCTAssertTrue(AppProblems.kinds.contains(kind), kind.id)
            XCTAssertNotNil(kind.guide)
            XCTAssertFalse(kind.explanation.isEmpty)
        }
    }
}
