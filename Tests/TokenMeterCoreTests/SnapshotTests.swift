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

    func testReportedQuotaWinsAndIgnoresExpiredWindow() {
        let live = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(600))
        let stale = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(-600))
        let a = SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: [], windows: [.session],
                                                 reported: [live], now: now)
        let b = SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: [], windows: [.session],
                                                 reported: [stale], now: now)
        XCTAssertEqual(a.windows[0].remainingFraction ?? -1, 0.7, accuracy: 1e-9)
        XCTAssertEqual(a.windows[0].source, .reported)
        XCTAssertNil(a.windows[0].observedAt, "no observation time given, none invented")
        XCTAssertEqual(b.windows[0].source, .reset, "expired window with no use is full again")
        XCTAssertEqual(b.windows[0].remainingFraction, 1)
    }

    func testExpiredWindowWithUseSinceStaysUnknown() {
        let stale = ReportedQuota(usedPercent: 30, windowMinutes: 300, resetsAt: now.addingTimeInterval(-600))
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .chatgpt, events: [event(hoursAgo: 1, tokens: 5)], windows: [.session],
            reported: [stale], now: now)
        XCTAssertEqual(snap.windows[0].source, .consumptionOnly)
        XCTAssertNil(snap.windows[0].remainingFraction)
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


final class ObservedAtTests: XCTestCase {
    func testObservedAtIsCarriedToTheWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let seen = now.addingTimeInterval(-3 * 3600)
        let quota = ReportedQuota(usedPercent: 40, windowMinutes: 300, resetsAt: now.addingTimeInterval(600), observedAt: seen)
        let snap = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session],
                                                    reported: [quota], now: now)
        XCTAssertEqual(snap.windows[0].observedAt, seen)
    }
}

final class ResolvedTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func usage(resetsIn seconds: TimeInterval) -> WindowUsage {
        WindowUsage(window: .session, tokens: TokenCounts(), remainingFraction: 0.2, source: .reported,
                    resetsAt: now.addingTimeInterval(seconds), observedAt: now.addingTimeInterval(-3600))
    }

    func testPassedResetTurnsAStaleFigureIntoAFullInferredOne() {
        let r = usage(resetsIn: 60).resolved(at: now.addingTimeInterval(120))
        XCTAssertEqual(r.source, .reset)
        XCTAssertEqual(r.remainingFraction, 1)
        XCTAssertNil(r.observedAt, "the old observation no longer applies")
    }

    func testFutureResetLeavesTheFigureAlone() {
        XCTAssertEqual(usage(resetsIn: 600).resolved(at: now), usage(resetsIn: 600))
    }
}

final class PlanNameTests: XCTestCase {
    func testPrettifiedCapitalisesWhatNoRuleNames() {
        XCTAssertEqual(PlanName.prettified("team"), "Team")
        XCTAssertEqual(PlanName.prettified("team_plus"), "Team Plus")
    }

    func testPlanIsCarriedIntoTheSnapshot() {
        let snap = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session], plan: "Max 20x")
        XCTAssertEqual(snap.plan, "Max 20x")
    }

    func testProblemsRoundTripAndAnOlderSnapshotHasNone() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let base = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: [])
        XCTAssertEqual(base.problems, [])
        let problem = Problem(id: "claude.x", topic: "claude", message: "m", fix: "wrapStatusLine")
        let withProblem = base.with(problems: [problem])
        XCTAssertEqual(try decoder.decode(Snapshot.self, from: encoder.encode(withProblem)).problems, [problem])
        let older = Data(#"{"generatedAt":"1970-01-01T00:00:00Z","providers":[],"notices":["old"]}"#.utf8)
        XCTAssertEqual(try decoder.decode(Snapshot.self, from: older).problems, [])
    }

    private func shown(_ id: String, windows: [WindowSpec] = [.session, .week]) -> ProviderSnapshot {
        SnapshotBuilder.providerSnapshot(provider: Provider(rawValue: id), title: id, events: [], windows: windows)
    }

    func testApplyingOrdersTheProvidersAndFiltersTheirWindows() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: [shown("claude"), shown("chatgpt")])
        let preferences = MemoryDisplayPreferences()
        preferences.setOrder(["chatgpt", "claude"])
        preferences.setWindows([WindowSpec.week.name], for: "chatgpt")

        let result = snapshot.applying(preferences)
        XCTAssertEqual(result.providers.map(\.title), ["chatgpt", "claude"])
        XCTAssertEqual(result.providers[0].windows.map(\.window.name), ["7d"])
        XCTAssertEqual(result.providers[1].windows.map(\.window.name), ["5h", "7d"], "no choice shows every window")
    }

    func testApplyingKeepsOneWindowAlwaysAndLeavesTheProblemsAlone() {
        let problem = Problem(id: "claude.x", topic: "claude", message: "m")
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: [shown("claude")], problems: [problem])
        let preferences = MemoryDisplayPreferences()
        preferences.setWindows(["no-such-window"], for: "claude")

        let result = snapshot.applying(preferences)
        XCTAssertEqual(result.providers[0].windows.count, 2, "a choice that matches nothing shows them all")
        XCTAssertEqual(result.problems, [problem])
    }

    func testApplyingIgnoresAnOrderThatNamesAMissingProvider() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: [shown("claude")])
        let preferences = MemoryDisplayPreferences()
        preferences.setOrder(["gone", "claude"])
        XCTAssertEqual(snapshot.applying(preferences).providers.map(\.title), ["claude"])
    }

    func testApplyingLeavesOutAHiddenProviderButKeepsItsProblems() {
        let problem = Problem(id: "chatgpt.x", topic: "chatgpt", message: "m")
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0),
                                providers: [shown("claude"), shown("chatgpt")], problems: [problem])
        let preferences = MemoryDisplayPreferences()
        preferences.setHidden(true, for: "chatgpt")

        let result = snapshot.applying(preferences)
        XCTAssertEqual(result.providers.map(\.title), ["claude"])
        XCTAssertEqual(result.problems, [problem], "a hidden provider's problems still concern the person")
    }

    func testApplyingAlwaysKeepsOneProvider() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: [shown("claude"), shown("chatgpt")])
        let preferences = MemoryDisplayPreferences()
        preferences.setOrder(["chatgpt", "claude"])
        preferences.setHidden(true, for: "claude")
        preferences.setHidden(true, for: "chatgpt")
        XCTAssertEqual(snapshot.applying(preferences).providers.map(\.title), ["chatgpt"],
                       "when every provider is hidden the first in order stays")
    }

    func testAHiddenProviderKeepsItsPlaceAndItsChoiceOfWindows() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: [shown("claude"), shown("chatgpt")])
        let preferences = MemoryDisplayPreferences()
        preferences.setOrder(["chatgpt", "claude"])
        preferences.setWindows(["7d"], for: "chatgpt")
        preferences.setHidden(true, for: "chatgpt")
        XCTAssertEqual(snapshot.applying(preferences).providers.map(\.title), ["claude"])

        preferences.setHidden(false, for: "chatgpt")
        let result = snapshot.applying(preferences)
        XCTAssertEqual(result.providers.map(\.title), ["chatgpt", "claude"])
        XCTAssertEqual(result.providers[0].windows.map(\.window.name), ["7d"])
    }
}
