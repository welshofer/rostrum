import Foundation

public enum ProviderID: String, Sendable, CaseIterable, Codable {
    case anthropic, openAI, gemini, custom
}

public struct Usage: Sendable, Equatable, Codable {
    public var inputTokens: Int
    public var outputTokens: Int
    public init(inputTokens: Int = 0, outputTokens: Int = 0) {
        self.inputTokens = inputTokens; self.outputTokens = outputTokens
    }
}

/// Everything a provider needs to produce a deck (§7.1). The model never sees
/// `design.md`; `styleSlug` is echoed into the IR meta / rendering only.
public struct DeckRequest: Sendable {
    public var prompt: String
    public var audience: String
    public var goal: String
    public var slideCount: Int
    public var notes: Bool
    public var groundingText: String?
    public var styleSlug: String

    public init(prompt: String, audience: String = "General", goal: String = "inform",
                slideCount: Int = 12, notes: Bool = true, groundingText: String? = nil,
                styleSlug: String = "default") {
        self.prompt = prompt; self.audience = audience; self.goal = goal
        self.slideCount = slideCount; self.notes = notes
        self.groundingText = groundingText; self.styleSlug = styleSlug
    }
}

/// The outline from Stage A (§7.3), surfaced as soon as it lands.
public struct DeckOutline: Sendable, Codable, Equatable {
    public var title: String
    public var sections: [String]
    public var slideStubs: [String]
    public init(title: String, sections: [String] = [], slideStubs: [String] = []) {
        self.title = title; self.sections = sections; self.slideStubs = slideStubs
    }
}

/// A raw deck draft — the model's JSON plus token usage. The pipeline decodes +
/// validates it (invariant I3).
public struct RawDraft: Sendable {
    public var json: String
    public var usage: Usage
    public init(json: String, usage: Usage) { self.json = json; self.usage = usage }
}

/// Passed to `draft` on the one repair attempt (§8.7).
public struct RepairContext: Sendable {
    public var invalidJSON: String
    public var errors: [String]
}

/// UI-facing pipeline stages (§7.5).
public enum GenerationEvent: Sendable {
    case preparingSource
    case outlining
    case outlineReady(DeckOutline)
    case drafting(completed: Int, total: Int)
    case validating
    case repairing              // at most once per run
    case illustrating(completed: Int, total: Int)   // optional image generation
    case rendering
    case finished(DeckResult)
}

public protocol LLMProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    /// Produce the deck JSON (Stage A outline + Stage B draft), emitting progress
    /// events. When `repairing` is set, this is the single repair attempt.
    func draft(_ request: DeckRequest, repairing: RepairContext?,
               emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft
}

/// The user-facing error taxonomy (§12).
public enum LecternError: Error, Equatable {
    case noKey
    case authFailed(provider: String)
    case rateLimited(afterSeconds: Int)
    case requestTooLarge
    case networkOffline
    case schemaInvalid(errors: [String])
    case providerError(status: Int, message: String)
    case renderFailed(message: String)
    case cancelled
}
