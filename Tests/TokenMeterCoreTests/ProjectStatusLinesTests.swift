import XCTest
@testable import TokenMeterCore

final class ProjectStatusLinesTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    /// A project folder, with a transcript in `~/.claude/projects` that names it as its `cwd`.
    @discardableResult
    private func makeProject(_ name: String, shared: String? = nil, local: String? = nil, transcript: Bool = true) throws -> URL {
        let fileManager = FileManager.default
        let project = home.appendingPathComponent("work/\(name)", isDirectory: true)
        try fileManager.createDirectory(at: project.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        if let shared { try Data(shared.utf8).write(to: project.appendingPathComponent(".claude/settings.json")) }
        if let local { try Data(local.utf8).write(to: project.appendingPathComponent(".claude/settings.local.json")) }
        if transcript {
            let folder = home.appendingPathComponent(".claude/projects/\(name)")
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let lines = [#"{"type":"summary"}"#, #"{"type":"user","cwd":"\#(project.path)"}"#]
            try Data(lines.joined(separator: "\n").utf8).write(to: folder.appendingPathComponent("a.jsonl"))
        }
        return project
    }

    private func overrides() -> [ProjectStatusLines.Override] { ProjectStatusLines.overrides(home: home) }

    func testAProjectWithItsOwnStatusLineIsReported() throws {
        let project = try makeProject("a", shared: #"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        XCTAssertEqual(overrides(), [.init(project: project, command: "/bin/mine")])
    }

    func testTheLocalFileWinsOverTheSharedOne() throws {
        let theirs = #"{"statusLine":{"type":"command","command":"/bin/theirs"}}"#
        let ours = #"{"statusLine":{"type":"command","command":"/Users/x/.tokenmeter/claude-statusline.sh"}}"#
        try makeProject("a", shared: theirs, local: ours)
        XCTAssertEqual(overrides(), [])
        let project = try makeProject("b", shared: ours, local: theirs)
        XCTAssertEqual(overrides(), [.init(project: project, command: "/bin/theirs")])
    }

    func testAWrappedProjectStatusLineIsNotAnOverride() throws {
        try makeProject("a", local: #"{"statusLine":{"type":"command","command":"/Users/x/.tokenmeter/claude/statusline-wrapper.sh"}}"#)
        XCTAssertEqual(overrides(), [])
    }

    func testAProjectWithoutAStatusLineIsNotReported() throws {
        try makeProject("a", shared: #"{"model":"opus"}"#)
        try makeProject("b")
        XCTAssertEqual(overrides(), [])
    }

    func testAStatusLineThatIsNotACommandIsReportedWithAnEmptyCommand() throws {
        let project = try makeProject("a", shared: #"{"statusLine":{"type":"text","text":"hi"}}"#)
        XCTAssertEqual(overrides(), [.init(project: project, command: "")])
    }

    func testTheHomeFolderIsSkippedBecauseItsSettingsAreTheUserOnes() throws {
        let folder = home.appendingPathComponent(".claude/projects/home")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"cwd":"\#(home.path)"}"#.utf8).write(to: folder.appendingPathComponent("a.jsonl"))
        try Data(#"{"statusLine":{"type":"command","command":"/bin/mine"}}"#.utf8)
            .write(to: home.appendingPathComponent(".claude/settings.json"))
        XCTAssertEqual(overrides(), [])
    }

    func testOldTranscriptsAndMissingFoldersAreSkipped() throws {
        let theirs = #"{"statusLine":{"type":"command","command":"/bin/mine"}}"#
        let old = try makeProject("old", shared: theirs)
        let gone = try makeProject("gone", shared: theirs)
        let past = Date().addingTimeInterval(-40 * 86_400)
        try FileManager.default.setAttributes(
            [.modificationDate: past], ofItemAtPath: home.appendingPathComponent(".claude/projects/old/a.jsonl").path)
        try FileManager.default.removeItem(at: gone)
        XCTAssertEqual(overrides(), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.path))
    }

    func testNothingIsWrittenToAProject() throws {
        let project = try makeProject("a", shared: #"{"statusLine":{"type":"command","command":"/bin/mine"}}"#)
        let before = try Data(contentsOf: project.appendingPathComponent(".claude/settings.json"))
        _ = overrides()
        XCTAssertEqual(try Data(contentsOf: project.appendingPathComponent(".claude/settings.json")), before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.appendingPathComponent(".claude/settings.local.json").path))
    }

    func testWithoutClaudeThereIsNothing() {
        XCTAssertEqual(overrides(), [])
    }

    func testTheNoticeNamesThreeProjectsAndCountsTheRest() {
        func item(_ name: String) -> ProjectStatusLines.Override { .init(project: URL(fileURLWithPath: "/w/\(name)"), command: "") }
        XCTAssertNil(ProjectStatusLines.notice(for: []))
        XCTAssertEqual(ProjectStatusLines.notice(for: [item("a")]), "Claude bars freeze in a: own status line")
        XCTAssertEqual(ProjectStatusLines.notice(for: ["a", "b", "c", "d", "e"].map(item)),
                       "Claude bars freeze in a, b, c +2: own status line")
    }
}
