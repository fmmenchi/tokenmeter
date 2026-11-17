import Foundation

/// What the counted tokens of a model would cost at the provider's API list prices (ADR 0016). An estimate, not a bill: a plan is not
/// charged by the token. The list ships with the app and is dated; a model it does not name has no price, and nothing is guessed.
public enum Pricing {
    /// US dollars per million tokens.
    public struct Price: Equatable, Sendable {
        public let input: Double
        public let output: Double
        public let cacheWrite: Double
        public let cacheRead: Double

        /// A cache write at 1.25 times the input (the five-minute write) and a read at a tenth of it, unless the provider lists its own.
        init(input: Double, output: Double, cacheRead: Double? = nil) {
            self.input = input
            self.output = output
            cacheWrite = input * 1.25
            self.cacheRead = cacheRead ?? input * 0.1
        }
    }

    /// When the list was taken from Anthropic's price table.
    public static let listedOn = "2026-11-03"

    /// Anthropic's first-party API prices. OpenAI's are not listed: their models show no cost until they are.
    static let list: [(model: String, price: Price)] = [
        ("claude-fable-5-2", Price(input: 8, output: 40, cacheRead: 0.20)),
        ("claude-mythos-5-2", Price(input: 8, output: 40, cacheRead: 0.20)),
        ("claude-fable-5-1", Price(input: 10, output: 50)),
        ("claude-mythos-5-1", Price(input: 10, output: 50)),
        ("claude-fable-5", Price(input: 10, output: 50)),
        ("claude-opus-5-5", Price(input: 4, output: 20, cacheRead: 0.20)),
        ("claude-opus-5", Price(input: 5, output: 25)),
        ("claude-opus-4-8", Price(input: 5, output: 25)),
        ("claude-opus-4-7", Price(input: 5, output: 25)),
        ("claude-opus-4-6", Price(input: 5, output: 25)),
        ("claude-sonnet-5-5", Price(input: 2, output: 10, cacheRead: 0.10)),
        ("claude-sonnet-5", Price(input: 2, output: 10)),
        ("claude-sonnet-4-6", Price(input: 3, output: 15)),
        ("claude-haiku-5-5", Price(input: 0.10, output: 0.50)),
        ("claude-haiku-4-5", Price(input: 1, output: 5)),
    ]

    /// The price of a model as its log names it ("claude-opus-5-5", "claude-opus-5-5[1m]"): the longest listed name it contains, so
    /// Opus 5.5 is never read as Opus 5. Nil for a model the list does not name.
    public static func price(of model: String?) -> Price? {
        guard let model = model?.lowercased() else { return nil }
        return list.filter { model.contains($0.model) }.max { $0.model.count < $1.model.count }?.price
    }

    /// The cost of a model's tokens, cache included, or nil when the model has no price.
    public static func cost(of total: UsageStore.ModelTotal) -> Double? {
        guard let price = price(of: total.model) else { return nil }
        let millions = { (tokens: Int) in Double(tokens) / 1_000_000 }
        return millions(total.input) * price.input + millions(total.output) * price.output
            + millions(total.cacheWrite) * price.cacheWrite + millions(total.cacheRead) * price.cacheRead
    }
}
