import XCTest
@testable import TokenMeterCore

/// ADR 0016: the cost of the counted tokens at API list prices, and nothing guessed.
final class PricingTests: XCTestCase {
    private func total(_ model: String?, input: Int = 0, output: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0) -> UsageStore.ModelTotal {
        UsageStore.ModelTotal(model: model, input: input, output: output, messages: 1, cacheRead: cacheRead, cacheWrite: cacheWrite)
    }

    func testTheLongestListedNameWinsSoOpusFiveFiveIsNotOpusFive() {
        XCTAssertEqual(Pricing.price(of: "claude-opus-5-5")?.input, 4)
        XCTAssertEqual(Pricing.price(of: "claude-opus-5")?.input, 5)
        XCTAssertEqual(Pricing.price(of: "claude-opus-5-5[1m]")?.output, 20, "a suffix of the log is ignored")
    }

    func testAModelTheListDoesNotNameHasNoPrice() {
        XCTAssertNil(Pricing.price(of: "gpt-5.3-codex"))
        XCTAssertNil(Pricing.price(of: nil))
        XCTAssertNil(Pricing.cost(of: total("gpt-5.3-codex", input: 1_000_000)))
    }

    func testTheCostCountsInputOutputAndBothCaches() throws {
        // Opus 5.5: 4 in, 20 out, cache write 5 (1.25 × 4), cache read 0.20 as listed.
        let cost = try XCTUnwrap(Pricing.cost(of: total("claude-opus-5-5", input: 1_000_000, output: 1_000_000,
                                                        cacheRead: 10_000_000, cacheWrite: 1_000_000)))
        XCTAssertEqual(cost, 4 + 20 + 5 + 2, accuracy: 1e-9)
    }

    func testACacheReadNotListedIsATenthOfTheInput() {
        XCTAssertEqual(Pricing.price(of: "claude-sonnet-4-6")?.cacheRead ?? 0, 0.3, accuracy: 1e-9)
    }

    func testAFamilyWithAModelWithoutPriceHasNoCostAndTheTotalSaysItIsPartial() {
        let rules = [ProviderConfig.Usage.Family(contains: "opus", family: "Opus"), ProviderConfig.Usage.Family(contains: "gpt", family: "GPT")]
        let breakdown = UsageStats.breakdown([total("claude-opus-5-5", output: 1_000_000), total("gpt-5", output: 1_000_000)],
                                             rules: rules)
        XCTAssertEqual(breakdown.shown.first { $0.name == "Opus" }?.cost ?? 0, 20, accuracy: 1e-9)
        XCTAssertNil(breakdown.shown.first { $0.name == "GPT" }?.cost)
        XCTAssertEqual(breakdown.cost ?? 0, 20, accuracy: 1e-9)
        XCTAssertTrue(breakdown.costIsPartial)
    }

    func testNoPricedModelMeansNoCost() {
        let breakdown = UsageStats.breakdown([total("gpt-5", output: 1_000)], rules: [ProviderConfig.Usage.Family(contains: "gpt", family: "GPT")])
        XCTAssertNil(breakdown.cost)
        XCTAssertFalse(breakdown.costIsPartial)
    }
}
