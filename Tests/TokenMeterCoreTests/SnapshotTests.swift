import XCTest
@testable import TokenMeterCore

final class SnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func event(hoursAgo: Double, tokens: Int) -> UsageEvent {
        UsageEvent(provider: .claude, date: now.addingTimeInterval(-hoursAgo * 3600),
                   tokens: TokenCounts(output: tokens))
    }

    func testWindowOnlyCountsEventsInsideIt() {
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .claude, events: [event(hoursAgo: 1, tokens: 10), event(hoursAgo: 6, tokens: 90)],
            windows: [.session, .week], now: now)
        XCTAssertEqual(snap.windows[0].tokens.total, 10)
        XCTAssertEqual(snap.windows[1].tokens.total, 100)
    }

    func testWithoutLimitOrReportNoRemainingQuotaIsInvented() {
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .claude, events: [event(hoursAgo: 1, tokens: 10)], windows: [.session], now: now)
        XCTAssertNil(snap.windows[0].remainingFraction)
        XCTAssertEqual(snap.windows[0].source, .consumptionOnly)
    }

    func testConfiguredLimitGivesEstimate() {
        let spec = WindowSpec(name: "5h", duration: 5 * 3600, tokenLimit: 100)
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .claude, events: [event(hoursAgo: 1, tokens: 25)], windows: [spec], now: now)
        XCTAssertEqual(snap.windows[0].remainingFraction, 0.75)
        XCTAssertEqual(snap.windows[0].source, .estimated)
    }

    func testReportedQuotaWinsAndIgnoresExpiredWindow() {
        let live = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(600))
        let stale = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(-600))
        let a = SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: [], windows: [.session],
                                                 reported: [live], now: now)
        let b = SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: [], windows: [.session],
                                                 reported: [stale], now: now)
        XCTAssertEqual(a.windows[0].remainingFraction ?? -1, 0.7, accuracy: 1e-9)
        XCTAssertEqual(a.windows[0].source, .reported)
        XCTAssertEqual(b.windows[0].source, .consumptionOnly)
    }
}

final class SnapshotStoreTests: XCTestCase {
    func testRoundTripAndMissingFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let store = SnapshotStore(url: url)
        XCTAssertNil(store.read())

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = Snapshot(generatedAt: now, providers: [
            SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session], now: now),
        ])
        try store.write(snapshot)
        XCTAssertEqual(store.read(), snapshot)
    }
}

final class LimitSettingsTests: XCTestCase {
    func testWindowsCarryTheProviderSpecificLimit() {
        let limits = LimitSettings(claudeSession: 10, claudeWeek: 70, chatgptSession: nil, chatgptWeek: 5)
        XCTAssertEqual(limits.windows(for: .claude).map(\.tokenLimit), [10, 70])
        XCTAssertEqual(limits.windows(for: .chatgpt).map(\.tokenLimit), [nil, 5])
        XCTAssertEqual(limits.windows(for: .claude).map(\.name), ["5h", "7d"])
    }
}
