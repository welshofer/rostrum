import Foundation

/// Replays a fixture draft with simulated stages and injectable failure modes
/// (§13) — the whole app (and the acceptance suite) works end-to-end against
/// this before any real network call exists.
public struct MockProvider: LLMProvider {
    public enum Failure: Sendable, Equatable {
        case none
        case invalidJSONOnce      // first draft is bad → exercises the repair loop
        case invalidJSONAlways    // both drafts bad → .schemaInvalid
        case rateLimited
        case slowDrafting
    }

    public let id: ProviderID = .custom
    public let displayName = "Mock"
    public var validJSON: String
    public var outline: DeckOutline
    public var failure: Failure
    public var usage: Usage

    public init(validJSON: String, outline: DeckOutline = DeckOutline(title: "Mock deck"),
                failure: Failure = .none, usage: Usage = Usage(inputTokens: 1200, outputTokens: 800)) {
        self.validJSON = validJSON; self.outline = outline
        self.failure = failure; self.usage = usage
    }

    public func draft(_ request: DeckRequest, repairing: RepairContext?,
                      emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        if failure == .rateLimited { throw LecternError.rateLimited(afterSeconds: 3) }

        emit(.preparingSource)
        emit(.outlining)
        emit(.outlineReady(outline))

        let total = max(1, request.slideCount)
        for i in 1...total {
            try Task.checkCancellation()                       // invariant I4
            if failure == .slowDrafting { try? await Task.sleep(nanoseconds: 3_000_000) }
            emit(.drafting(completed: i, total: total))
        }

        switch failure {
        case .invalidJSONAlways:
            return RawDraft(json: "{ this is not valid json", usage: usage)
        case .invalidJSONOnce:
            return RawDraft(json: repairing == nil ? "{ broken on the first try" : validJSON, usage: usage)
        default:
            return RawDraft(json: validJSON, usage: usage)
        }
    }
}
