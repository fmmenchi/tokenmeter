import XCTest
@testable import TokenMeterCore

final class ClaudeUsageRefreshTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func script(_ body: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("claude")
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    func testItRunsTheCommandWithItsArgumentsInTheFolderGiven() async throws {
        let dir = try tempDir()
        let marker = dir.appendingPathComponent("marker")
        let claude = try script("echo \"$@\" > '\(marker.path)'; pwd >> '\(marker.path)'", in: dir)
        let folder = dir.appendingPathComponent("run")

        let outcome = await ClaudeUsageRefresh.run(executable: claude, in: folder)
        XCTAssertEqual(outcome, .refreshed)
        let lines = try String(contentsOf: marker).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines[0], "-p /usage --no-session-persistence --no-chrome")
        XCTAssertEqual(URL(fileURLWithPath: lines[1]).resolvingSymlinksInPath().path, folder.resolvingSymlinksInPath().path)
    }

    func testAFailureCarriesTheExitStatus() async throws {
        let claude = try script("exit 3", in: try tempDir())
        let outcome = await ClaudeUsageRefresh.run(executable: claude, in: try tempDir())
        XCTAssertEqual(outcome, .failed("exit 3"))
    }

    func testARunThatTakesTooLongIsStopped() async throws {
        let claude = try script("sleep 10", in: try tempDir())
        let started = Date()
        let outcome = await ClaudeUsageRefresh.run(executable: claude, in: try tempDir(), timeout: 0.3)
        XCTAssertEqual(outcome, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testManyHungRunsAtOnceDoNotStarveTheOthers() async throws {
        // Each run used to hold a thread of the pool for its whole timeout; with more of them than cores nothing else could run.
        let hung = try script("sleep 10", in: try tempDir())
        let quick = try script("exit 0", in: try tempDir())
        let runs = ProcessInfo.processInfo.activeProcessorCount * 3
        let started = Date()
        let outcomes = await withTaskGroup(of: ClaudeUsageRefresh.Outcome.self) { group in
            for _ in 0 ..< runs { group.addTask { await ClaudeUsageRefresh.run(executable: hung, in: URL(fileURLWithPath: NSTemporaryDirectory()), timeout: 1.5) } }
            try? await Task.sleep(nanoseconds: 200_000_000)
            group.addTask { await ClaudeUsageRefresh.run(executable: quick, in: URL(fileURLWithPath: NSTemporaryDirectory()), timeout: 1.5) }
            var all: [ClaudeUsageRefresh.Outcome] = []
            for await outcome in group { all.append(outcome) }
            return all
        }
        XCTAssertEqual(outcomes.filter { $0 == .timedOut }.count, runs)
        XCTAssertTrue(outcomes.contains(.refreshed), "the quick one was not kept waiting behind the hung ones")
        XCTAssertLessThan(Date().timeIntervalSince(started), 6)
    }

    func testTheCliIsFoundInTheUsualPlacesAndNotWhenItIsAbsent() throws {
        let home = try tempDir()
        XCTAssertNil(ClaudeUsageRefresh.locate(home: home, path: "", system: []))
        let bin = home.appendingPathComponent(".local/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let claude = try script("exit 0", in: bin)
        XCTAssertEqual(ClaudeUsageRefresh.locate(home: home, path: "", system: [])?.path, claude.path)
    }

    func testWithoutTheCliItSaysSo() async throws {
        let outcome = await ClaudeUsageRefresh.refresh(home: try tempDir(), path: "", system: [])
        XCTAssertEqual(outcome, .notFound)
    }
}
