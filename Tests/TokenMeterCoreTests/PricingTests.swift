import XCTest
@testable import TokenMeterCore

/// ADR 0016: the cost of the counted tokens at API list prices, and nothing guessed.
final class PricingTests: XCTestCase {
    private func total(_ model: String?, input: Int = 0, output: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0,
                       promptOver: Int = 0) -> UsageStore.ModelTotal {
        UsageStore.ModelTotal(model: model, input: input, output: output, messages: 1, cacheRead: cacheRead, cacheWrite: cacheWrite,
                              promptOver: promptOver)
    }

    func testTheLongestListedNameWinsSoOpusFiveFiveIsNotOpusFive() {
        XCTAssertEqual(Pricing.price(of: "claude-opus-5-5")?.standard.input, 4)
        XCTAssertEqual(Pricing.price(of: "claude-opus-5")?.standard.input, 5)
        XCTAssertEqual(Pricing.price(of: "claude-opus-5-5[1m]")?.standard.output, 20, "a suffix of the log is ignored")
    }

    func testAModelTheListDoesNotNameHasNoPrice() {
        XCTAssertNil(Pricing.price(of: "codex-auto-review"))
        XCTAssertNil(Pricing.price(of: nil))
        XCTAssertNil(Pricing.cost(of: total("codex-auto-review", input: 1_000_000)))
    }

    func testTheCostCountsInputOutputAndBothCaches() throws {
        // Opus 5.5: 4 in, 20 out, cache write 8 (the one-hour write, 2 × 4), cache read 0.20 as listed.
        let cost = try XCTUnwrap(Pricing.cost(of: total("claude-opus-5-5", input: 1_000_000, output: 1_000_000,
                                                        cacheRead: 10_000_000, cacheWrite: 1_000_000)))
        XCTAssertEqual(cost, 4 + 20 + 8 + 2, accuracy: 1e-9)
    }

    func testTheCacheReadIsTheListedOneNotATenth() {
        XCTAssertEqual(Pricing.price(of: "claude-fable-5-1")?.standard.cacheRead ?? 0, 0.25, accuracy: 1e-9)
        XCTAssertEqual(Pricing.price(of: "claude-opus-5")?.standard.cacheRead ?? 0, 0.50, accuracy: 1e-9)
    }

    func testALongPromptPaysTheLongRatesAboveTheModelsOwnSize() {
        let haiku = Pricing.price(of: "claude-haiku-5-5")
        XCTAssertEqual(haiku?.rates(promptOver: 0).input, 0.10)
        XCTAssertEqual(haiku?.rates(promptOver: 100_000).input, 0.50, "over 100K prompt tokens")
        let terra = Pricing.price(of: "gpt-6.1-terra")
        XCTAssertEqual(terra?.rates(promptOver: 100_000).input, 1, "100K is not long for OpenAI")
        XCTAssertEqual(terra?.rates(promptOver: 272_000).input, 2, "over 272K is")
        XCTAssertEqual(Pricing.price(of: "claude-opus-5-5")?.rates(promptOver: 272_000).input, 4, "no long rates: one price")
    }

    func testGptSixPointOneSolIsNotGptSixSol() {
        XCTAssertEqual(Pricing.price(of: "gpt-6.1-sol")?.standard.cacheRead, 0.10)
        XCTAssertEqual(Pricing.price(of: "gpt-6-sol")?.standard.cacheRead, 0.20)
    }

    func testTheCostOfAModelAddsItsSizesOfPrompt() throws {
        let rules = [ProviderConfig.Usage.Family(contains: "haiku", family: "Haiku")]
        let short = total("claude-haiku-5-5", output: 1_000_000)
        let long = total("claude-haiku-5-5", output: 1_000_000, promptOver: 100_000)
        let merged = total("claude-haiku-5-5", output: 2_000_000)
        let breakdown = UsageStats.breakdown([merged], rules: rules, costs: [short, long])
        XCTAssertEqual(breakdown.shown.first?.tokens, 2_000_000, "the tokens come from the totals")
        XCTAssertEqual(try XCTUnwrap(breakdown.cost), 0.50 + 2.50, accuracy: 1e-9)
    }

    func testAFamilyWithAModelWithoutPriceHasNoCostAndTheTotalSaysItIsPartial() {
        let rules = [ProviderConfig.Usage.Family(contains: "opus", family: "Opus"), ProviderConfig.Usage.Family(contains: "codex", family: "GPT")]
        let breakdown = UsageStats.breakdown([total("claude-opus-5-5", output: 1_000_000), total("codex-auto-review", output: 1_000_000)],
                                             rules: rules)
        XCTAssertEqual(breakdown.shown.first { $0.name == "Opus" }?.cost ?? 0, 20, accuracy: 1e-9)
        XCTAssertNil(breakdown.shown.first { $0.name == "GPT" }?.cost)
        XCTAssertEqual(breakdown.cost ?? 0, 20, accuracy: 1e-9)
        XCTAssertTrue(breakdown.costIsPartial)
    }

    func testNoPricedModelMeansNoCost() {
        let breakdown = UsageStats.breakdown([total("codex-auto-review", output: 1_000)], rules: [ProviderConfig.Usage.Family(contains: "codex", family: "GPT")])
        XCTAssertNil(breakdown.cost)
        XCTAssertFalse(breakdown.costIsPartial)
    }
}
