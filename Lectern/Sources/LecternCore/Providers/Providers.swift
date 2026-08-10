import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The session provider traffic runs on. `.ephemeral`, not `.shared`: the
/// shared session's disk-backed `URLCache`, cookie storage and credential
/// store would put response bodies — the generated deck, derived from the
/// user's own prompt and PDF — at rest on disk. The key is kept out of
/// persistent storage everywhere (I1); the payload gets the same posture.
public enum ProviderNetworking {
    public static let session = URLSession(configuration: .ephemeral)
}

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
    case auditing               // the QA editor pass
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

    /// The QA pass: take a valid draft deck and return a stronger revision in the
    /// same schema (§quality). Default is a no-op so providers can opt in.
    func revise(_ request: DeckRequest, deckJSON: String,
                emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft
}

public extension LLMProvider {
    /// Default: no QA pass — return the draft unchanged.
    func revise(_ request: DeckRequest, deckJSON: String,
                emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        RawDraft(json: deckJSON, usage: Usage())
    }
}

/// How much room a deck of a given size needs to come back whole.
///
/// A property of the deck, not of whoever writes it, so both providers ask the
/// same question the same way.
enum DeckOutputBudget {
    /// Every current model accepts at least this much, so it is what a provider
    /// falls back to when one refuses a larger budget.
    static let floor = 8_192
    static let ceiling = 32_000

    static func tokens(for request: DeckRequest) -> Int {
        let perSlide = 180 + (request.notes ? 120 : 0)
        let estimate = 800 + max(1, request.slideCount) * perSlide
        return min(ceiling, max(floor, estimate * 3 / 2))
    }
}

/// The user-facing error taxonomy (§12).
public enum LecternError: Error, Equatable {
    case noKey
    case authFailed(provider: String)
    case rateLimited(afterSeconds: Int)
    case requestTooLarge
    /// The model stopped at its output ceiling before finishing the deck.
    case responseTruncated(slideCount: Int)
    case networkOffline
    case schemaInvalid(errors: [String])
    case providerError(status: Int, message: String)
    case renderFailed(message: String)
    case cancelled
}
