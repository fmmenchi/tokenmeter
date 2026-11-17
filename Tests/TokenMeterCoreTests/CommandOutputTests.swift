import XCTest
@testable import TokenMeterCore

/// ADR 0017: what the command prints, and how it exits.
final class CommandOutputTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_534_400)
    private let none = TokenCounts(input: 1_000, output: 200, cacheRead: 0, cacheWrite: 0)

    private func window(_ name: String, left: Double?, scope: String? = nil, resetsIn: TimeInterval = 7_740) -> WindowUsage {
        WindowUsage(window: WindowSpec(name: name, duration: name == "5h" ? 5 * 3600 : 7 * 86_400, scope: scope), tokens: none,
                    remainingFraction: left, source: .reported, resetsAt: now.addingTimeInterval(resetsIn),
                    observedAt: now.addingTimeInterval(-60))
    }

    private func snapshot(age: TimeInterval = 120, display: BarsDisplay = .left) -> Snapshot {
        Snapshot(generatedAt: now.addingTimeInterval(-age), providers: [
            ProviderSnapshot(provider: Provider(rawValue: "claude"), title: "Claude",
                             windows: [window("5h", left: 0.72), window("7d", left: 0.58), window("7d", left: nil, scope: "Fable")],
                             plan: "Max 20x"),
        ], barsDisplay: display)
    }

    func testTheExitSaysFreshStaleOrMissing() {
        XCTAssertEqual(CommandOutput.exit(for: snapshot(age: 9 * 60), now: now), .fresh)
        XCTAssertEqual(CommandOutput.exit(for: snapshot(age: 11 * 60), now: now), .stale)
        XCTAssertEqual(CommandOutput.exit(for: nil, now: now), .missing)
    }

    func testTheTextHasALineForEachWindowAndTheAge() {
        let text = CommandOutput.quotaText(snapshot(), display: .left, now: now)
        XCTAssertTrue(text.hasPrefix("Claude (Max 20x)\n"))
        XCTAssertTrue(text.contains("5 hours"))
        XCTAssertTrue(text.contains("72% left"))
        XCTAssertTrue(text.contains("resets in 2h 9m"))
        XCTAssertTrue(text.contains("Weekly · Fable"))
        XCTAssertTrue(text.contains("unknown"))
        XCTAssertTrue(text.hasSuffix("Read 2m ago."))
    }

    func testTheTextFollowsTheReading() {
        XCTAssertTrue(CommandOutput.quotaText(snapshot(), display: .used, now: now).contains("28% used"))
    }

    func testTheJsonHasItsVersionAndBothFractions() throws {
        let data = try CommandOutput.quotaJSON(snapshot(), display: .left, now: now)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertEqual(object["stale"] as? Bool, false)
        XCTAssertEqual(object["ageSeconds"] as? Int, 120)
        let providers = try XCTUnwrap(object["providers"] as? [[String: Any]])
        let windows = try XCTUnwrap(providers.first?["windows"] as? [[String: Any]])
        XCTAssertEqual(windows.first?["label"] as? String, "5 hours")
        XCTAssertEqual(windows.first?["left"] as? Double ?? 0, 0.72, accuracy: 1e-9)
        XCTAssertEqual(windows.first?["used"] as? Double ?? 0, 0.28, accuracy: 1e-9)
        XCTAssertEqual(windows.first?["tokens"] as? Int, 1_200)
        XCTAssertEqual(windows.last?["model"] as? String, "Fable")
    }

    func testTheStatsJsonCarriesTheCostAndWhetherItIsPartial() throws {
        let rules = [ProviderConfig.Usage.Family(contains: "opus", family: "Opus"),
                     ProviderConfig.Usage.Family(contains: "codex", family: "Codex")]
        let models = UsageStats.breakdown([UsageStore.ModelTotal(model: "claude-opus-5-5", input: 0, output: 1_000_000, messages: 1),
                                           UsageStore.ModelTotal(model: "codex-auto-review", input: 0, output: 1_000_000, messages: 1)],
                                          rules: rules)
        let stats = [ProviderStats(provider: Provider(rawValue: "claude"), windows: [], models: models, since: nil)]
        let data = try CommandOutput.statsJSON(stats, titles: [Provider(rawValue: "claude"): "Claude"], range: .month)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let provider = try XCTUnwrap((object["providers"] as? [[String: Any]])?.first)
        XCTAssertEqual(provider["costUSD"] as? Double ?? 0, 20, accuracy: 1e-9)
        XCTAssertEqual(provider["costIsPartial"] as? Bool, true)
        XCTAssertEqual(object["range"] as? String, "month")
        let text = CommandOutput.statsText(stats, titles: [Provider(rawValue: "claude"): "Claude"], range: .month)
        XCTAssertTrue(text.contains("the models with a price: ≈ $20.00"))
    }
}
