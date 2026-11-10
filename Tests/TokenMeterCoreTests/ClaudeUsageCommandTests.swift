import XCTest
@testable import TokenMeterCore

final class ClaudeUsageCommandTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func executable(_ body: String, at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    func testTheCliIsFoundInTheUsualPlacesAndNotWhenItIsAbsent() throws {
        let home = try tempDir()
        XCTAssertNil(ClaudeUsageCommand.locate(home: home, path: "", system: []))
        let claude = home.appendingPathComponent(".local/bin/claude")
        try executable("exit 0", at: claude)
        XCTAssertEqual(ClaudeUsageCommand.locate(home: home, path: "", system: [])?.path, claude.path)
    }

    func testACommandWithoutClaudeIsNotWritten() throws {
        let home = try tempDir()
        let account = ClaudeStatusLine.Account(id: "claude", configDir: home.appendingPathComponent(".claude"))
        XCTAssertThrowsError(try ClaudeUsageCommand.write(for: account, home: home, path: "", system: []))
    }

    func testTheCommandOpensUsageInTheAccountsFolderWithoutSavingPromptHistory() throws {
        let home = try tempDir()
        let claude = home.appendingPathComponent("bin's/claude")
        try executable("printf '%s\\n' \"$PWD\" \"$CLAUDE_CONFIG_DIR\" \"$CLAUDE_CODE_SKIP_PROMPT_HISTORY\" \"$@\"", at: claude)
        let account = ClaudeStatusLine.Account(id: "claude-work", configDir: home.appendingPathComponent("account's"))
        let command = try ClaudeUsageCommand.write(for: account, home: home, executable: claude)
        let permissions = try FileManager.default.attributesOfItem(atPath: command.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o700)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [command.path]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let lines = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, [home.appendingPathComponent(".tokenmeter/claude-work").path,
                               account.configDir.path, "1", "/usage", "--no-chrome"])
    }

    func testTheDefaultAccountRunsWithoutAConfigFolderSoClaudeCodeReadsItsOwnLogin() throws {
        let home = try tempDir()
        let claude = home.appendingPathComponent("bin/claude")
        try executable("printf '%s\\n' \"${CLAUDE_CONFIG_DIR-unset}\"", at: claude)
        let command = try ClaudeUsageCommand.write(for: .default(home: home), home: home, executable: claude)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [command.path]
        var environment = ProcessInfo.processInfo.environment
        environment["CLAUDE_CONFIG_DIR"] = home.appendingPathComponent(".claude").path
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(printed, "unset\n", "set to ~/.claude, Claude Code reads ~/.claude/.claude.json and starts its onboarding")
    }

    func testOnlyAnotherFolderIsGivenToClaudeCode() throws {
        let home = try tempDir()
        XCTAssertNil(ClaudeStatusLine.Account.default(home: home).environmentConfigDir(home: home))
        let work = ClaudeStatusLine.Account(id: "claude-work", configDir: home.appendingPathComponent(".claude-work"))
        XCTAssertEqual(work.environmentConfigDir(home: home), home.appendingPathComponent(".claude-work"))
    }
}
