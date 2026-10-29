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

    func testStandardListHoldsClaudeThenChatGPT() {
        XCTAssertEqual(Providers.standard().map(\.info.provider), [.claude, .chatgpt])
    }
}
