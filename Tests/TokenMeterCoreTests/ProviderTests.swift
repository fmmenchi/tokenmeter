import XCTest
@testable import TokenMeterCore

private struct FakeSource: ProviderSource {
    let info: ProviderInfo
    let reading: ProviderReading
    func read(since: Date) -> ProviderReading { reading }
}

final class ProviderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testProviderEncodesAsTheBareStringTheEnumUsed() throws {
        let data = try JSONEncoder().encode([Provider.claude, Provider(rawValue: "gemini")])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["claude","gemini"]"#)
        XCTAssertEqual(try JSONDecoder().decode([Provider].self, from: data).last?.rawValue, "gemini")
    }

    func testSnapshotWrittenBeforeTheContractStillDecodes() throws {
        let json = """
        {"generatedAt":"2026-10-28T10:00:00Z","claudeQuotaUpdatedAt":"2026-10-28T09:00:00Z",
         "providers":[{"provider":"claude","windows":[],"plan":"Max 20x"}]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(Snapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snapshot.providers.first?.title, "claude")
        XCTAssertEqual(snapshot.providers.first?.plan, "Max 20x")
        XCTAssertNil(snapshot.providers.first?.quotaUpdatedAt)
    }

    func testCollectorTreatsEverySourceTheSameWayAndKeepsItsOrder() {
        let quota = ReportedQuota(usedPercent: 40, windowMinutes: 300, resetsAt: now.addingTimeInterval(3600),
                                  observedAt: now)
        let sources: [any ProviderSource] = [
            FakeSource(info: ProviderInfo(provider: Provider(rawValue: "alpha"), title: "Alpha", windows: [.session],
                                          setupHint: "turn it on"),
                       reading: ProviderReading(quotas: [quota], plan: "Pro", quotaUpdatedAt: now)),
            FakeSource(info: ProviderInfo(provider: Provider(rawValue: "beta"), title: "Beta",
                                          windows: [.session, .week]),
                       reading: ProviderReading()),
        ]
        let snapshot = Collector(sources: sources).snapshot(now: now)

        XCTAssertEqual(snapshot.providers.map(\.title), ["Alpha", "Beta"])
        XCTAssertEqual(snapshot.providers[0].windows.count, 1)
        XCTAssertEqual(snapshot.providers[0].windows[0].remainingFraction ?? 0, 0.6, accuracy: 0.0001)
        XCTAssertEqual(snapshot.providers[0].plan, "Pro")
        XCTAssertEqual(snapshot.providers[0].quotaUpdatedAt, now)
        XCTAssertEqual(snapshot.providers[0].setupHint, "turn it on")
        XCTAssertEqual(snapshot.providers[1].windows.count, 2)
        XCTAssertNil(snapshot.providers[1].quotaUpdatedAt)
    }

    func testAnEntryMayNameTheFolderOfItsTool() throws {
        let json = """
        {"version":1,"providers":[
          {"id":"claude-work","title":"Claude · work","windows":[300],"home":"~/.claude-work"},
          {"id":"chatgpt","title":"ChatGPT","windows":[300]}]}
        """
        let file = try ProviderConfigFile.decode(Data(json.utf8), origin: "test")
        XCTAssertEqual(file.providers[0].home, "~/.claude-work")
        XCTAssertNil(file.providers[1].home, "an entry without a home reads the tool's default folder")
    }

    func testAnIdThatCannotNameAFileIsRefusedByName() {
        func file(id: String) -> Data {
            Data(#"{"version":1,"providers":[{"id":"\#(id)","title":"T","windows":[300]}]}"#.utf8)
        }
        for good in ["claude", "claude-work", "me.work_1"] {
            XCTAssertNoThrow(try ProviderConfigFile.decode(file(id: good), origin: "test"), good)
        }
        for bad in ["work account", "claude/work", "a:b", "ünicode"] {
            XCTAssertThrowsError(try ProviderConfigFile.decode(file(id: bad), origin: "test"), bad) { error in
                XCTAssertTrue("\(error)".contains("\"\(bad)\""), "the message names the id: \(error)")
            }
        }
    }

    func testTheTemplateMovesEveryPathOfTheDefaultFolderToTheAccounts() throws {
        let entry = ProviderConfigFile.entry(for: .claudeCode, id: "claude-work", title: "Claude · work", home: "~/.claude-work")
        XCTAssertEqual(entry["id"] as? String, "claude-work")
        XCTAssertEqual(entry["title"] as? String, "Claude · work")
        XCTAssertEqual(entry["home"] as? String, "~/.claude-work")
        XCTAssertEqual((entry["log"] as? [String: Any])?["root"] as? String, "~/.claude-work/projects")
        let quota = entry["quota"] as? [String: Any]
        XCTAssertEqual(quota?["file"] as? String, "~/.tokenmeter/claude-work-statusline.json")
        let windows = quota?["windows"] as? [[String: Any]]
        XCTAssertEqual((windows?[0]["existsIf"] as? [String: Any])?["file"] as? String, "~/.claude-work/.claude.json")
        XCTAssertEqual(windows?[2]["file"] as? String, "~/.claude-work/.claude.json")
        XCTAssertEqual((entry["plan"] as? [String: Any])?["file"] as? String, "~/.claude-work/.claude.json")
        XCTAssertEqual(entry["integration"] as? String, "claude-status-line")
        let decoded = try ProviderConfigFile.decode(
            JSONSerialization.data(withJSONObject: ["version": 1, "providers": [entry]]), origin: "template")
        XCTAssertEqual(decoded.providers.first?.home, "~/.claude-work", "what the template gives is an entry the file accepts")

        let codex = ProviderConfigFile.entry(for: .codexCLI, id: "codex-personal", title: "mario.rossi@example.com",
                                             home: "~/.codex-personal")
        XCTAssertEqual((codex["log"] as? [String: Any])?["root"] as? String, "~/.codex-personal/sessions")
        XCTAssertEqual(codex["home"] as? String, "~/.codex-personal")
    }

    func testTheTemplateForTheSeedIdInTheDefaultFolderIsTheSeedEntry() throws {
        for tool in AccountTool.allCases {
            let entry = ProviderConfigFile.entry(for: tool, id: tool.seedID, title: "X", home: tool.defaultHome)
            XCTAssertNil(entry["home"], "\(tool): the seed entry has no home")
            var seed = DefaultProviders.seedEntry(tool.seedID)
            seed["title"] = "X"
            XCTAssertEqual(NSDictionary(dictionary: entry), NSDictionary(dictionary: seed), "\(tool)")
        }
    }

    func testStandardListHoldsClaudeThenChatGPT() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let sources = Providers.standard(config: dir.appendingPathComponent("providers.json"), home: dir)
        XCTAssertEqual(sources.map(\.info.provider), [.claude, .chatgpt])
    }
}
