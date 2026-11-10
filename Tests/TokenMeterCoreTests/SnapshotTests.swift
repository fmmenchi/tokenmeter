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

    // MARK: ADR 0002: a window's tokens are counted in its own period

    func testAReportedWindowCountsItsTokensFromTheStartOfItsOwnPeriod() {
        // A 5-hour window that began 1h ago: 10 tokens 30 min ago are in it, 90 tokens 3h ago are in the last 5 hours but
        // belong to the window before.
        let quota = ReportedQuota(usedPercent: 0, windowMinutes: 300, resetsAt: now.addingTimeInterval(4 * 3600))
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .chatgpt, events: [event(hoursAgo: 0.5, tokens: 10), event(hoursAgo: 3, tokens: 90)],
            windows: [.session], reported: [quota], now: now)
        XCTAssertEqual(snap.windows[0].tokens.total, 10)
    }

    func testAMovedBoundaryChangesWhatAWeeklyWindowCounts() {
        // The same use, 4 days ago and today. A week that began 3 days ago counts today only; one that began 6 days ago,
        // both.
        let events = [event(hoursAgo: 96, tokens: 900), event(hoursAgo: 2, tokens: 25)]
        func weekly(beganDaysAgo: Double) -> Int {
            let quota = ReportedQuota(usedPercent: 0, windowMinutes: 10080,
                                      resetsAt: now.addingTimeInterval((7 - beganDaysAgo) * 86400))
            return SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: events, windows: [.week],
                                                    reported: [quota], now: now).windows[0].tokens.total
        }
        XCTAssertEqual(weekly(beganDaysAgo: 3), 25)
        XCTAssertEqual(weekly(beganDaysAgo: 6), 925)
    }

    func testAReportedWindowWithoutAResetTimeStaysRolling() {
        let quota = ReportedQuota(usedPercent: 10, windowMinutes: 300, resetsAt: nil)
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .chatgpt, events: [event(hoursAgo: 0.5, tokens: 10), event(hoursAgo: 3, tokens: 90)],
            windows: [.session], reported: [quota], now: now)
        XCTAssertEqual(snap.windows[0].tokens.total, 100)
    }

    func testAWindowWithNoReportCountsTheLastDurationAsBefore() {
        let snap = SnapshotBuilder.providerSnapshot(
            provider: .claude, events: [event(hoursAgo: 0.5, tokens: 10), event(hoursAgo: 3, tokens: 90)],
            windows: [.session], now: now)
        XCTAssertEqual(snap.windows[0].tokens.total, 100)
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

    func testPassedResetKeepsAnExhaustedReadingAndItsResetTime() {
        let exhausted = WindowUsage(window: .session, tokens: TokenCounts(), remainingFraction: 0, source: .reported,
                                    resetsAt: now.addingTimeInterval(-60), observedAt: now.addingTimeInterval(-3600))
        XCTAssertEqual(exhausted.resolved(at: now), exhausted)
        XCTAssertTrue(exhausted.isApproximate(at: now))
    }

    // MARK: A limit for one model ends with its window

    private func week(_ fraction: Double, resetsIn seconds: TimeInterval, scope: String? = nil,
                      source: WindowUsage.Source = .reported) -> WindowUsage {
        WindowUsage(window: WindowSpec(name: "7d", duration: 7 * 24 * 3600, scope: scope), tokens: TokenCounts(),
                    remainingFraction: fraction, source: source, resetsAt: now.addingTimeInterval(seconds),
                    observedAt: now.addingTimeInterval(-3600))
    }

    func testAnExhaustedModelLimitEndsWhenItsWindowHasMovedOnToALaterReset() {
        let model = week(0, resetsIn: -3600, scope: "Fable")
        let provider = ProviderSnapshot(provider: .claude, windows: [week(0.98, resetsIn: 6 * 86_400), model])
        let resolved = provider.resolved(model, at: now)
        XCTAssertEqual(resolved.source, .reset)
        XCTAssertEqual(resolved.remainingFraction, 1)
        XCTAssertEqual(model.resolved(at: now), model, "on its own an exhausted figure stays until a reading replaces it")
    }

    func testAModelLimitStaysExhaustedWhileItsWindowHasNotMovedOn() {
        let model = week(0, resetsIn: -3600, scope: "Fable")
        let parentResets: [TimeInterval] = [-3_600, -3_600 + 30, -3_600 + 2 * 86_400]
        for parentResetsIn in parentResets {
            let provider = ProviderSnapshot(provider: .claude, windows: [week(0.5, resetsIn: parentResetsIn), model])
            XCTAssertEqual(provider.resolved(model, at: now), model,
                           "a reset that is the same, a few seconds later or less than half a window later is not a renewal")
        }
    }

    func testOnlyAWindowThatWasReportedMovesTheModelLimit() {
        let model = week(0, resetsIn: -3600, scope: "Fable")
        let inferred = ProviderSnapshot(provider: .claude, windows: [week(1, resetsIn: 6 * 86_400, source: .reset), model])
        XCTAssertEqual(inferred.resolved(model, at: now), model)
        let alone = ProviderSnapshot(provider: .claude, windows: [model])
        XCTAssertEqual(alone.resolved(model, at: now), model)
    }

    func testTheMainWindowReadsAsItAlwaysDid() {
        let main = week(0, resetsIn: -3600)
        let provider = ProviderSnapshot(provider: .claude, windows: [main, week(0, resetsIn: -7_200, scope: "Fable")])
        XCTAssertEqual(provider.resolved(main, at: now), main.resolved(at: now))
    }

    func testCollectionKeepsExhaustedQuotaUntilAReplacementIsReported() {
        let past = now.addingTimeInterval(-60)
        let exhausted = ReportedQuota(usedPercent: 100, windowMinutes: 300, resetsAt: past,
                                      observedAt: now.addingTimeInterval(-3600))
        let retained = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session],
                                                        reported: [exhausted], now: now).windows[0]
        XCTAssertEqual(retained.source, .reported)
        XCTAssertEqual(retained.remainingFraction, 0)
        XCTAssertEqual(retained.resetsAt, past)

        let fresh = ReportedQuota(usedPercent: 10, windowMinutes: 300, resetsAt: now.addingTimeInterval(5 * 3600),
                                  observedAt: now)
        let replaced = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session],
                                                        reported: [fresh], now: now).windows[0]
        XCTAssertEqual(replaced.remainingFraction, 0.9)
        XCTAssertEqual(replaced.resetsAt, fresh.resetsAt)
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

final class ModelLimitTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func snapshot(_ reported: [ReportedQuota]) -> ProviderSnapshot {
        SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session, .week], reported: reported, now: now)
    }

    func testAModelLimitIsAWindowOfItsOwnUnderTheOneOfTheSameLength() {
        let week = ReportedQuota(usedPercent: 48, windowMinutes: 10080, resetsAt: now.addingTimeInterval(86_400), observedAt: now)
        let model = ReportedQuota(usedPercent: 13, windowMinutes: 10080, resetsAt: now.addingTimeInterval(86_400),
                                  observedAt: now, scope: "Fable")
        let result = snapshot([week, model])
        XCTAssertEqual(result.windows.map { $0.window.id }, ["5h", "7d", "7d:Fable"])
        XCTAssertEqual(result.windows[1].remainingFraction ?? 0, 0.52, accuracy: 0.001, "a model's figure never becomes the week's")
        XCTAssertEqual(result.windows[2].remainingFraction ?? 0, 0.87, accuracy: 0.001)
        XCTAssertEqual(result.windows[2].window.scope, "Fable")
    }

    func testAModelLimitWithNoParentWindowIsLeftOut() {
        let model = ReportedQuota(usedPercent: 13, windowMinutes: 1440, resetsAt: nil, scope: "Fable")
        XCTAssertEqual(snapshot([model]).windows.map { $0.window.id }, ["5h", "7d"])
    }

    func testAScopedWindowRoundTripsAndAnOlderWindowHasNoScope() throws {
        let spec = WindowSpec(name: "7d", duration: 604_800, scope: "Fable")
        let data = try JSONEncoder().encode(spec)
        XCTAssertEqual(try JSONDecoder().decode(WindowSpec.self, from: data), spec)
        let older = Data(#"{"name":"7d","duration":604800}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(WindowSpec.self, from: older).scope)
    }

    func testAModelWindowNeverShowsWithoutItsParent() {
        let week = ReportedQuota(usedPercent: 48, windowMinutes: 10080, resetsAt: now.addingTimeInterval(86_400), observedAt: now)
        let model = ReportedQuota(usedPercent: 13, windowMinutes: 10080, resetsAt: now.addingTimeInterval(86_400),
                                  observedAt: now, scope: "Fable")
        let provider = snapshot([week, model])
        let all = Snapshot(generatedAt: now, providers: [provider])
        let preferences = MemoryDisplayPreferences()

        preferences.setWindows(["5h", "7d:Fable"], for: "claude")
        XCTAssertEqual(all.applying(preferences).providers[0].windows.map { $0.window.id }, ["5h"],
                       "the model was chosen but its week was not: it does not show")

        preferences.setWindows(["5h", "7d"], for: "claude")
        XCTAssertEqual(all.applying(preferences).providers[0].windows.map { $0.window.id }, ["5h", "7d", "7d:Fable"],
                       "a model is on unless the person turned it off (ADR 0002)")

        preferences.setModel("7d:Fable", shown: false, for: "claude")
        XCTAssertEqual(all.applying(preferences).providers[0].windows.map { $0.window.id }, ["5h", "7d"], "the model is off")
    }

    // ADR 0002: a model is on unless the person turned it off, and shows only with its window.
    private let weeklyAndFable: [WindowSpec] = [.week, WindowSpec(name: "7d", duration: 604_800, scope: "Fable")]

    func testAModelShowsByDefaultAndWithoutItsWindowDoesNot() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: [SnapshotBuilder.providerSnapshot(
            provider: Provider(rawValue: "claude"), title: "claude", events: [], windows: [.session] + weeklyAndFable)])
        let preferences = MemoryDisplayPreferences()
        XCTAssertEqual(snapshot.applying(preferences).providers[0].windows.map { $0.window.id }, ["5h", "7d", "7d:Fable"])

        preferences.setWindows(["5h"], for: "claude")
        XCTAssertEqual(snapshot.applying(preferences).providers[0].windows.map { $0.window.id }, ["5h"],
                       "Fable is part of Weekly: it does not show without it")

        preferences.setWindows(["5h", "7d"], for: "claude")
        preferences.setModel("7d:Fable", shown: false, for: "claude")
        XCTAssertEqual(snapshot.applying(preferences).providers[0].windows.map { $0.window.id }, ["5h", "7d"])
    }

    func testTurningAWindowOffNeverHidesTheProviderAndTheLastOneStaysOn() {
        let choice = WindowChoice(windows: ["5h", "7d"], models: ["7d:Fable": "7d"])
        let preferences = MemoryDisplayPreferences()
        XCTAssertTrue(preferences.select(["7d"], among: choice, for: "claude"))
        XCTAssertEqual(preferences.windows(for: "claude"), ["7d"])
        XCTAssertFalse(preferences.hidden.contains("claude"))

        XCTAssertFalse(preferences.select([], among: choice, for: "claude"), "the last window is refused")
        XCTAssertEqual(preferences.windows(for: "claude"), ["7d"], "and nothing changed")
        XCTAssertFalse(preferences.hidden.contains("claude"))
    }

    func testAChoiceThatNamesNoWindowOfTheProviderIsRefused() {
        let choice = WindowChoice(windows: ["7d"], models: [:])
        let preferences = MemoryDisplayPreferences()
        XCTAssertFalse(preferences.select(["5h"], among: choice, for: "claude"))
        XCTAssertNil(preferences.windows(for: "claude"))
    }

    func testChoosingWhileTheProviderIsOffDoesNotShowIt() {
        let choice = WindowChoice(windows: ["5h", "7d"], models: [:])
        let preferences = MemoryDisplayPreferences()
        preferences.setShown(false, for: "claude")
        XCTAssertTrue(preferences.select(["5h"], among: choice, for: "claude"))
        XCTAssertTrue(preferences.hidden.contains("claude"))
        XCTAssertEqual(preferences.windows(for: "claude"), ["5h"])
    }

    func testSelectingAWindowTurnsItsModelsOnByDefault() {
        let choice = WindowChoice(windows: ["5h", "7d"], models: ["7d:Fable": "7d"])
        let preferences = MemoryDisplayPreferences()
        preferences.setModel("7d:Fable", shown: false, for: "claude")
        preferences.select(["5h"], among: choice, for: "claude")
        XCTAssertEqual(preferences.hiddenModels(for: "claude"), ["7d:Fable"], "Weekly was not added: Fable stays as it was")
        preferences.select(["5h", "7d"], among: choice, for: "claude")
        XCTAssertEqual(preferences.hiddenModels(for: "claude"), [], "selecting Weekly turns Fable on")
    }

    func testHidingAProviderKeepsItsWindowsAndModelsAndShowingItGivesThemBack() {
        let choice = WindowChoice(windows: ["5h", "7d"], models: ["7d:Fable": "7d"])
        let preferences = MemoryDisplayPreferences()
        preferences.select(["7d"], among: choice, for: "claude")
        preferences.setModel("7d:Fable", shown: false, for: "claude")

        preferences.setShown(false, for: "claude")
        XCTAssertTrue(preferences.hidden.contains("claude"))
        XCTAssertEqual(preferences.windows(for: "claude"), ["7d"])
        XCTAssertEqual(preferences.hiddenModels(for: "claude"), ["7d:Fable"])

        preferences.setShown(true, for: "claude")
        XCTAssertFalse(preferences.hidden.contains("claude"))
        XCTAssertEqual(preferences.windows(for: "claude"), ["7d"])
        XCTAssertEqual(preferences.hiddenModels(for: "claude"), ["7d:Fable"])
    }

    func testAProviderHiddenBeforeWithNoWindowsSavedComesBackWithEveryWindow() {
        let preferences = MemoryDisplayPreferences()
        preferences.setHidden(true, for: "claude")
        preferences.setShown(true, for: "claude")
        XCTAssertNil(preferences.windows(for: "claude"), "no choice saved means every window")
        XCTAssertFalse(preferences.hidden.contains("claude"))
    }
}
