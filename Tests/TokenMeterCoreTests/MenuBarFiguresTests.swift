import XCTest
@testable import TokenMeterCore

/// The quota in the menu bar: one figure per card, in the panel's order, each its tightest window, said in words to VoiceOver.
final class MenuBarFiguresTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func window(_ name: String, left: Double?, scope: String? = nil, seenAgo: TimeInterval = 60,
                        source: WindowUsage.Source = .reported) -> WindowUsage {
        WindowUsage(window: WindowSpec(name: name, duration: name == "5h" ? 18000 : 604_800, scope: scope), tokens: TokenCounts(),
                    remainingFraction: left, source: source, resetsAt: now.addingTimeInterval(3600),
                    observedAt: source == .reported ? now.addingTimeInterval(-seenAgo) : nil)
    }

    private func card(_ id: String, _ title: String, _ windows: [WindowUsage]) -> ProviderSnapshot {
        ProviderSnapshot(provider: Provider(rawValue: id), title: title, windows: windows)
    }

    private func figures(_ cards: [ProviderSnapshot], _ display: BarsDisplay = .left) -> [MenuBarFigure] {
        MenuBarFigures.figures(of: Snapshot(generatedAt: now, providers: cards), display: display, at: now)
    }

    func testTheTightestWindowIsTheOneWithTheLeastLeft() {
        let figures = figures([card("claude", "Claude", [window("5h", left: 0.8), window("Weekly", left: 0.31)])])
        XCTAssertEqual(figures.map(\.text), ["31%"])
        XCTAssertEqual(figures.map(\.spoken), ["Claude 31% left"])
    }

    func testAModelLimitAndAWindowWithNoFigureDoNotCount() {
        let figures = figures([card("claude", "Claude", [window("Weekly", left: 0.6), window("Weekly", left: 0.05, scope: "opus"),
                                                         window("5h", left: nil)])])
        XCTAssertEqual(figures.map(\.text), ["60%"])
    }

    func testACardWithNoFigureKeepsItsPlaceWithADash() {
        let figures = figures([card("claude", "Claude", [window("5h", left: nil)]), card("chatgpt", "ChatGPT", [window("5h", left: 0.99)])])
        XCTAssertEqual(figures.map(\.text), ["—", "99%"])
        XCTAssertEqual(figures.first?.spoken, "Claude no figure yet")
    }

    func testUsedReadsAsTheBarsDo() {
        let figures = figures([card("claude", "Claude", [window("Weekly", left: 0.31)])], .used)
        XCTAssertEqual(figures.map(\.text), ["69%"])
        XCTAssertEqual(figures.map(\.spoken), ["Claude 69% used"])
    }

    func testAnOldReadingHasATildeAndSaysItsAge() {
        let figures = figures([card("claude", "Claude", [window("Weekly", left: 0.31, seenAgo: 25 * 60)])])
        XCTAssertEqual(figures.map(\.text), ["~31%"])
        XCTAssertEqual(figures.map(\.spoken), ["Claude about 31% left, 25m ago"])
    }

    func testAResetWindowIsAboutWithNoAge() {
        let figures = figures([card("claude", "Claude", [window("5h", left: 1, source: .reset)])])
        XCTAssertEqual(figures.map(\.text), ["~100%"])
        XCTAssertEqual(figures.map(\.spoken), ["Claude about 100% left"])
    }

    func testTheFiguresFollowThePanelsOrderAndHiddenCards() {
        let cards = [card("claude", "Claude", [window("5h", left: 0.31)]), card("chatgpt", "ChatGPT", [window("5h", left: 0.99)]),
                     card("work", "Claude work", [window("5h", left: 0.64)])]
        let prefs = MemoryDisplayPreferences()
        prefs.setOrder(["chatgpt", "claude", "work"])
        prefs.setHidden(true, for: "work")
        let shown = MenuBarFigures.figures(of: Snapshot(generatedAt: now, providers: cards).applying(prefs), display: .left, at: now)
        XCTAssertEqual(shown.map(\.title), ["ChatGPT", "Claude"])
        XCTAssertEqual(shown.map(\.text), ["99%", "31%"])
    }

    func testACrowdedBarShowsTheTightestOfAllAndTheWordsNameIt() {
        let all = figures([card("a", "Claude", [window("5h", left: 0.5)]), card("b", "Claude work", [window("5h", left: 0.2)]),
                           card("c", "ChatGPT", [window("5h", left: 0.9)]), card("d", "Codex work", [window("5h", left: nil)])])
        XCTAssertEqual(MenuBarFigures.shown(all).map(\.text), ["20%"])
        XCTAssertEqual(MenuBarFigures.names(all, needsAttention: false),
                       "Claude 50% left · Claude work 20% left, the tightest · ChatGPT 90% left · Codex work no figure yet")
    }

    func testThreeCardsAreNotCrowded() {
        let all = figures([card("a", "A", [window("5h", left: 0.5)]), card("b", "B", [window("5h", left: 0.2)]),
                           card("c", "C", [window("5h", left: 0.9)])])
        XCTAssertEqual(MenuBarFigures.shown(all).count, 3)
    }

    func testTheTextNamesEveryCardAndPutsAttentionFirst() {
        let all = figures([card("claude", "Claude", [window("5h", left: 0.31)]), card("chatgpt", "ChatGPT", [window("5h", left: 0.99)])])
        XCTAssertEqual(MenuBarFigures.names(all, needsAttention: false), "Claude 31% left · ChatGPT 99% left")
        XCTAssertEqual(MenuBarFigures.accessibilityLabel(all, needsAttention: true),
                       "tokenmeter, needs attention, Claude 31% left, ChatGPT 99% left")
    }
}
