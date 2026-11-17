import Foundation

/// What the counted tokens of a model would cost at the provider's API list prices (ADR 0016). An estimate, not a bill: a plan is not
/// charged by the token. The list ships with the app and is dated; a model it does not name has no price, and nothing is guessed.
public enum Pricing {
    /// US dollars per million tokens, for one size of prompt.
    public struct Rates: Equatable, Sendable {
        public let input: Double
        public let output: Double
        public let cacheWrite: Double
        public let cacheRead: Double
    }

    /// A model's rates, and the higher ones of a long prompt where the provider has them.
    public struct Price: Equatable, Sendable {
        public let standard: Rates
        /// Over this many prompt tokens (input and both caches) a request pays `long`.
        public let longAbove: Int?
        public let long: Rates?

        public func rates(promptOver: Int) -> Rates {
            if let longAbove, let long, promptOver >= longAbove { long } else { standard }
        }

        /// Anthropic: a cache write at twice the input, the one-hour write that Claude Code uses (99.6% of its writes in the logs of
        /// the author's Mac on 2026-11-16; the five-minute write is 1.25 times), and a read at the listed price.
        static func anthropic(_ input: Double, _ output: Double, read: Double, longAbove: Int? = nil,
                              long: (input: Double, output: Double, read: Double)? = nil) -> Price {
            let rates = { (i: Double, o: Double, r: Double) in Rates(input: i, output: o, cacheWrite: i * 2, cacheRead: r) }
            return Price(standard: rates(input, output, read), longAbove: longAbove, long: long.map { rates($0.input, $0.output, $0.read) })
        }

        /// OpenAI: input, cached input and output, with the long-context prices above 272K prompt tokens. Codex writes no cache, so
        /// a cache write costs the input.
        static func openAI(_ input: Double, _ cached: Double, _ output: Double,
                           long: (input: Double, cached: Double, output: Double)? = nil) -> Price {
            let rates = { (i: Double, c: Double, o: Double) in Rates(input: i, output: o, cacheWrite: i, cacheRead: c) }
            return Price(standard: rates(input, cached, output), longAbove: long == nil ? nil : 272_000,
                         long: long.map { rates($0.input, $0.cached, $0.output) })
        }
    }

    /// When the list was read from the providers' price pages.
    public static let listedOn = "2026-11-16"

    /// platform.claude.com/docs/en/about-claude/pricing and developers.openai.com/api/docs/pricing, standard tier, read on
    /// 2026-11-16. Not listed there, so without a price: `codex-auto-review`.
    static let list: [(model: String, price: Price)] = [
        ("claude-fable-5-2", .anthropic(8, 40, read: 0.20)),
        ("claude-mythos-5-2", .anthropic(8, 40, read: 0.20)),
        ("claude-fable-5-1", .anthropic(10, 50, read: 0.25)),
        ("claude-mythos-5-1", .anthropic(10, 50, read: 0.25)),
        ("claude-fable-5", .anthropic(10, 50, read: 1)),
        ("claude-opus-5-5", .anthropic(4, 20, read: 0.20)),
        ("claude-opus-5", .anthropic(5, 25, read: 0.50)),
        ("claude-opus-4-8", .anthropic(5, 25, read: 0.50)),
        ("claude-opus-4-7", .anthropic(5, 25, read: 0.50)),
        ("claude-opus-4-6", .anthropic(5, 25, read: 0.50)),
        ("claude-sonnet-5-5", .anthropic(2, 10, read: 0.10)),
        ("claude-sonnet-5", .anthropic(2, 10, read: 0.20)),
        ("claude-sonnet-4-6", .anthropic(3, 15, read: 0.30)),
        ("claude-haiku-5-5", .anthropic(0.10, 0.50, read: 0.01, longAbove: 100_000, long: (0.50, 2.50, 0.05))),
        ("claude-haiku-4-5", .anthropic(1, 5, read: 0.10)),
        ("gpt-6.1-terra", .openAI(1, 0.05, 5, long: (2, 0.10, 7.50))),
        ("gpt-6.1-sol", .openAI(2, 0.10, 10, long: (4, 0.20, 15))),
        ("gpt-6-sol", .openAI(2, 0.20, 10, long: (4, 0.40, 15))),
        ("gpt-6-luna", .openAI(0.10, 0.01, 0.50, long: (0.20, 0.02, 0.75))),
        ("gpt-6-astra", .openAI(10, 1, 50, long: (20, 2, 75))),
        ("gpt-5.6-luna", .openAI(0.20, 0.02, 1.20, long: (0.40, 0.04, 1.80))),
        // A promotional price until 2026-11-30, the page says.
        ("gpt-5.6-sol", .openAI(4, 0.40, 20)),
        ("gpt-5.6-terra", .openAI(2, 0.20, 12)),
        ("gpt-5.3-codex", .openAI(1.75, 0.175, 14)),
    ]

    /// The price of a model as its log names it ("claude-opus-5-5", "claude-opus-5-5[1m]"): the longest listed name it contains, so
    /// Opus 5.5 is never read as Opus 5. Nil for a model the list does not name.
    public static func price(of model: String?) -> Price? {
        guard let model = model?.lowercased() else { return nil }
        return list.filter { model.contains($0.model) }.max { $0.model.count < $1.model.count }?.price
    }

    /// The cost of a model's tokens, cache included, at the rates of the size of prompt they came with; nil when the model has no price.
    public static func cost(of total: UsageStore.ModelTotal) -> Double? {
        guard let rates = price(of: total.model)?.rates(promptOver: total.promptOver) else { return nil }
        let millions = { (tokens: Int) in Double(tokens) / 1_000_000 }
        return millions(total.input) * rates.input + millions(total.output) * rates.output
            + millions(total.cacheWrite) * rates.cacheWrite + millions(total.cacheRead) * rates.cacheRead
    }
}
