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

    func testItRunsTheCommandWithItsArgumentsInTheFolderGiven() throws {
        let dir = try tempDir()
        let marker = dir.appendingPathComponent("marker")
        let claude = try script("echo \"$@\" > '\(marker.path)'; pwd >> '\(marker.path)'", in: dir)
        let folder = dir.appendingPathComponent("run")

        XCTAssertEqual(ClaudeUsageRefresh.run(executable: claude, in: folder), .refreshed)
        let lines = try String(contentsOf: marker).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines[0], "-p /usage --no-session-persistence --no-chrome")
        XCTAssertEqual(URL(fileURLWithPath: lines[1]).resolvingSymlinksInPath().path, folder.resolvingSymlinksInPath().path)
    }

    func testAFailureCarriesTheExitStatus() throws {
        let claude = try script("exit 3", in: try tempDir())
        XCTAssertEqual(ClaudeUsageRefresh.run(executable: claude, in: try tempDir()), .failed("exit 3"))
    }

    func testARunThatTakesTooLongIsStopped() throws {
        let claude = try script("sleep 10", in: try tempDir())
        let started = Date()
        XCTAssertEqual(ClaudeUsageRefresh.run(executable: claude, in: try tempDir(), timeout: 0.3), .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testTheCliIsFoundInTheUsualPlacesAndNotWhenItIsAbsent() throws {
        let home = try tempDir()
        XCTAssertNil(ClaudeUsageRefresh.locate(home: home, path: "", system: []))
        let bin = home.appendingPathComponent(".local/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let claude = try script("exit 0", in: bin)
        XCTAssertEqual(ClaudeUsageRefresh.locate(home: home, path: "", system: [])?.path, claude.path)
    }

    func testWithoutTheCliItSaysSo() throws {
        XCTAssertEqual(ClaudeUsageRefresh.refresh(home: try tempDir(), path: "", system: []), .notFound)
    }
}
