import Foundation

/// Published per-model rates in USD per **1M tokens** (§10.3). These are
/// *approximate defaults* for showing the user a ballpark cost — providers change
/// pricing, so they're kept in one obvious place and the UI always labels the
/// figure "estimated". `Decimal` (not `Double`) so cents don't drift.
public struct ModelPrice: Sendable, Equatable {
    public var inputPerMTok: Decimal
    public var outputPerMTok: Decimal
    public init(inputPerMTok: Decimal, outputPerMTok: Decimal) {
        self.inputPerMTok = inputPerMTok; self.outputPerMTok = outputPerMTok
    }
}

/// Turns token usage into a cost estimate. Pure and UI-free, so it's unit-tested
/// without a network or a keychain.
public enum PriceTable {
    /// Approximate list rates (USD / 1M tokens). Edit here when pricing changes;
    /// unknown models simply yield no estimate rather than a wrong one.
    public static let defaults: [String: ModelPrice] = [
        "claude-opus-4-8":  ModelPrice(inputPerMTok: 15, outputPerMTok: 75),
        "claude-sonnet-5":  ModelPrice(inputPerMTok: 3,  outputPerMTok: 15),
        "claude-haiku-4-5": ModelPrice(inputPerMTok: 1,  outputPerMTok: 5),
    ]

    public static func price(for model: String) -> ModelPrice? { defaults[model] }

    /// Exact cost of a completed run from its reported `Usage`. `nil` for an
    /// unpriced model — the caller shows nothing rather than a fabricated number.
    public static func cost(model: String, usage: Usage) -> Decimal? {
        guard let p = price(for: model) else { return nil }
        let input = Decimal(usage.inputTokens) * p.inputPerMTok
        let output = Decimal(usage.outputTokens) * p.outputPerMTok
        return (input + output) / 1_000_000
    }

    /// A rough *pre-flight* estimate from deck size, before any real usage exists.
    /// Deliberately simple: a fixed system/prompt overhead, ~180 output tokens per
    /// slide, and grounding text counted at ~4 chars/token on the input side.
    public static func estimate(model: String, slideCount: Int, groundingChars: Int = 0) -> Decimal? {
        guard let p = price(for: model) else { return nil }
        let inputTokens = 700 + groundingChars / 4
        let outputTokens = max(1, slideCount) * 180
        let input = Decimal(inputTokens) * p.inputPerMTok
        let output = Decimal(outputTokens) * p.outputPerMTok
        return (input + output) / 1_000_000
    }

    /// Format a cost as USD for display, e.g. `$0.04` — or `<$0.01` for a tiny but
    /// non-zero amount so it never reads as free.
    public static func formatted(_ cost: Decimal) -> String {
        if cost > 0 && cost < 0.01 { return "<$0.01" }
        let rounded = (cost as NSDecimalNumber).doubleValue
        return String(format: "$%.2f", rounded)
    }
}
