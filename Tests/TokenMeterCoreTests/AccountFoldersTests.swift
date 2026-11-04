import XCTest
@testable import TokenMeterCore

final class AccountFoldersTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func makeClaude(_ name: String, email: String? = "mario.rossi@example.com") throws -> URL {
        let folder = home.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("projects"), withIntermediateDirectories: true)
        let object: [String: Any] = email.map { ["oauthAccount": ["emailAddress": $0, "organizationName": "Acme"]] } ?? [:]
        try JSONSerialization.data(withJSONObject: object).write(to: folder.appendingPathComponent(".claude.json"))
        return folder
    }

    private func token(claims: [String: Any]) throws -> String {
        func part(_ object: [String: Any]) throws -> String {
            try JSONSerialization.data(withJSONObject: object).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return try "\(part(["alg": "RS256"])).\(part(claims)).c2lnbmF0dXJl"
    }

    private func makeCodex(_ name: String, auth: [String: Any]) throws -> URL {
        let folder = home.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: auth).write(to: folder.appendingPathComponent("auth.json"))
        try Data("model = \"gpt\"\n".utf8).write(to: folder.appendingPathComponent("config.toml"))
        return folder
    }

    func testAFolderIsRecognisedByWhatTheToolLeavesInIt() throws {
        let claude = try makeClaude(".claude-work")
        let codex = try makeCodex(".codex-personal", auth: ["OPENAI_API_KEY": "sk-test"])
        let neither = home.appendingPathComponent(".config")
        try FileManager.default.createDirectory(at: neither.appendingPathComponent("projects"), withIntermediateDirectories: true)
        XCTAssertEqual(AccountFolders.tool(of: claude), .claudeCode)
        XCTAssertEqual(AccountFolders.tool(of: codex), .codexCLI)
        XCTAssertNil(AccountFolders.tool(of: neither), "projects/ alone is not a Claude folder")
        XCTAssertNil(AccountFolders.tool(of: home.appendingPathComponent("missing")))
    }

    func testTheEmailComesFromTheClaudeFileAndFromTheTokensPayload() throws {
        let claude = try makeClaude(".claude")
        XCTAssertEqual(AccountFolders.email(in: claude, tool: .claudeCode), "mario.rossi@example.com")
        let silent = try makeClaude(".claude-new", email: nil)
        XCTAssertNil(AccountFolders.email(in: silent, tool: .claudeCode))

        let codex = try makeCodex(".codex", auth: [
            "auth_mode": "chatgpt",
            "tokens": ["id_token": try token(claims: ["email": "mario.rossi@example.com", "sub": "u1"]),
                       "access_token": "secret", "refresh_token": "secret"],
        ])
        XCTAssertEqual(AccountFolders.email(in: codex, tool: .codexCLI), "mario.rossi@example.com")
        let key = try makeCodex(".codex-key", auth: ["OPENAI_API_KEY": "sk-test", "auth_mode": "apikey"])
        XCTAssertNil(AccountFolders.email(in: key, tool: .codexCLI), "an API key has no email")
        let broken = try makeCodex(".codex-broken", auth: ["tokens": ["id_token": "not.a.jwt"]])
        XCTAssertNil(AccountFolders.email(in: broken, tool: .codexCLI))
        XCTAssertNil(AccountFolders.claim("email", of: try token(claims: ["sub": "u1"])), "a token without the claim")
    }

    func testScanLooksAtTheTopOfTheHomeOnlyAndNamesTheDefaultsFirst() throws {
        let claude = try makeClaude(".claude")
        let work = try makeClaude(".claude-work", email: "m.rossi@acme.example")
        let codex = try makeCodex(".codex", auth: ["OPENAI_API_KEY": "sk-test"])
        _ = try makeClaude("Documents/deeper")
        _ = try makeClaude("visible")
        let found = AccountFolders.scan(userHome: home)
        XCTAssertEqual(found.map(\.folder.lastPathComponent), [".claude", ".codex", ".claude-work"],
                       "the defaults first, then the hidden folders in name order; nothing deeper, nothing visible")
        XCTAssertEqual(found.map(\.tool), [.claudeCode, .codexCLI, .claudeCode])
        XCTAssertEqual(found.map(\.email), ["mario.rossi@example.com", nil, "m.rossi@acme.example"])
        XCTAssertEqual(found[0].folder.standardizedFileURL.path, claude.standardizedFileURL.path)
        XCTAssertEqual(found[2].folder.standardizedFileURL.path, work.standardizedFileURL.path)
        XCTAssertEqual(found[1].folder.standardizedFileURL.path, codex.standardizedFileURL.path)
    }

    func testTheFolderOfAnEntryExpandsTheTildeAndFallsBackToTheDefault() {
        XCTAssertEqual(AccountFolders.folder(of: "~/.claude-work", tool: .claudeCode, userHome: home).path,
                       home.appendingPathComponent(".claude-work").path)
        XCTAssertEqual(AccountFolders.folder(of: nil, tool: .codexCLI, userHome: home).path,
                       home.appendingPathComponent(".codex").path)
        XCTAssertEqual(AccountFolders.folder(of: "/opt/claude", tool: .claudeCode, userHome: home).path, "/opt/claude")
    }
}
