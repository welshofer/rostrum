import Foundation
@testable import LecternCore

/// Test-only provider that replays a fixture draft with injectable failure modes.
/// It lives in the **test target only** — the shipping product never contains a
/// mock/fake provider (a deck is always produced by a real one).
struct FixtureProvider: LLMProvider {
    enum Failure: Sendable, Equatable {
        case none
        case invalidJSONOnce      // first draft bad → exercises the repair loop
        case invalidJSONAlways    // both drafts bad → .schemaInvalid
        case rateLimited
        case slowDrafting
    }

    let id: ProviderID = .custom
    let displayName = "Fixture"
    var validJSON: String
    var revisedJSON: String?          // what the QA pass returns, if set
    var outline: DeckOutline = DeckOutline(title: "Fixture deck")
    var failure: Failure = .none
    var usage: Usage = Usage(inputTokens: 1200, outputTokens: 800)

    init(validJSON: String, revisedJSON: String? = nil, failure: Failure = .none) {
        self.validJSON = validJSON; self.revisedJSON = revisedJSON; self.failure = failure
    }

    func revise(_ request: DeckRequest, deckJSON: String,
                emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        RawDraft(json: revisedJSON ?? deckJSON, usage: usage)
    }

    func draft(_ request: DeckRequest, repairing: RepairContext?,
               emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        if failure == .rateLimited { throw LecternError.rateLimited(afterSeconds: 3) }

        emit(.preparingSource)
        emit(.outlining)
        emit(.outlineReady(outline))

        let total = max(1, request.slideCount)
        for i in 1...total {
            try Task.checkCancellation()
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
