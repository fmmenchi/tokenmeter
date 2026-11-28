import XCTest
@testable import TokenMeterCore

/// A widget per account (ADR 0018): the card it shows and its gauges, at most two, each with the limits of its models.
final class WidgetGaugesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func window(_ name: String, left: Double?, scope: String? = nil) -> WindowUsage {
        WindowUsage(window: WindowSpec(name: name, duration: name == "5h" ? 18000 : 604_800, scope: scope), tokens: TokenCounts(),
                    remainingFraction: left, source: .reported, resetsAt: now.addingTimeInterval(3600),
                    observedAt: now.addingTimeInterval(-60))
    }

    private func card(_ id: String, _ windows: [WindowUsage]) -> ProviderSnapshot {
        ProviderSnapshot(provider: Provider(rawValue: id), title: id, windows: windows)
    }

    func testTheGaugesAreTheFirstTwoWindowsThatAreNotAModelsLimit() {
        let claude = card("claude", [window("5h", left: 0.62), window("7d", left: 0.4, scope: "Fable"), window("7d", left: 0.4),
                                     window("30d", left: 0.9)])
        let gauges = WidgetGauges.gauges(of: claude, at: now)
        XCTAssertEqual(gauges.map(\.window.window.name), ["5h", "7d"], "the card's order, two at most")
    }

    func testACardWithOneWindowHasOneGauge() {
        XCTAssertEqual(WidgetGauges.gauges(of: card("chatgpt", [window("7d", left: 0.45)]), at: now).count, 1)
    }

    func testTheModelsOfAWindowGoWithItsGaugeAndTheLowestIsNamed() {
        let claude = card("claude", [window("5h", left: 0.62), window("7d", left: 0.4), window("7d", left: 0.55, scope: "Opus"),
                                     window("7d", left: 0.06, scope: "Fable"), window("7d", left: nil, scope: "Sonnet")])
        let gauges = WidgetGauges.gauges(of: claude, at: now)
        XCTAssertEqual(gauges[0].models, [], "the 5 hours have no model")
        XCTAssertEqual(gauges[1].models.compactMap(\.window.scope), ["Opus", "Fable", "Sonnet"])
        XCTAssertEqual(gauges[1].lowestModel?.window.scope, "Fable", "a model with no figure is not the lowest")
    }

    func testAModelOfAWindowNotDrawnIsLeftOut() {
        let claude = card("claude", [window("5h", left: 0.6), window("7d", left: 0.4), window("30d", left: 0.9),
                                     window("30d", left: 0.1, scope: "Fable")])
        XCTAssertEqual(WidgetGauges.gauges(of: claude, at: now).flatMap(\.models), [])
    }

    func testTheCardIsTheChosenOneOrTheFirst() {
        let snapshot = Snapshot(generatedAt: now, providers: [card("claude-work", []), card("chatgpt", [])])
        XCTAssertEqual(WidgetGauges.card(withID: "chatgpt", in: snapshot)?.provider.rawValue, "chatgpt")
        XCTAssertEqual(WidgetGauges.card(withID: nil, in: snapshot)?.provider.rawValue, "claude-work", "no account chosen: the first")
        XCTAssertNil(WidgetGauges.card(withID: "claude-home", in: snapshot), "a removed or hidden account is not replaced")
    }
}
