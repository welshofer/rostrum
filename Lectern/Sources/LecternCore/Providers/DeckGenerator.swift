import Foundation

/// The generation pipeline: draft → decode + validate → (one repair) → render.
/// Ties a provider to the validator (I3) and the renderer (I2). Emits UI events
/// and returns a `DeckResult`.
public actor DeckGenerator {
    private let provider: LLMProvider
    private let validator = DeckValidator()
    private let renderer = DeckRenderer()

    public init(provider: LLMProvider) { self.provider = provider }

    private struct DraftErrors: Error { var errors: [String] }

    public func generate(_ request: DeckRequest, designURL: URL?, into directory: URL,
                         emit: @Sendable @escaping (GenerationEvent) -> Void) async throws -> DeckResult {
        let first = try await provider.draft(request, repairing: nil, emit: emit)
        emit(.validating)
        do {
            let result = try decodeAndValidate(first.json, request)
            return try await finish(result, request, designURL, directory, usage: first.usage, emit: emit)
        } catch let failure as DraftErrors {
            // §8.7 — exactly one repair attempt.
            emit(.repairing)
            let repaired = try await provider.draft(
                request, repairing: RepairContext(invalidJSON: first.json, errors: failure.errors), emit: emit)
            emit(.validating)
            do {
                let result = try decodeAndValidate(repaired.json, request)
                return try await finish(result, request, designURL, directory, usage: repaired.usage, emit: emit)
            } catch let second as DraftErrors {
                throw LecternError.schemaInvalid(errors: second.errors)
            }
        }
    }

    private func decodeAndValidate(_ json: String, _ request: DeckRequest) throws -> ValidationResult {
        let deck: DeckIR
        do {
            deck = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        } catch {
            throw DraftErrors(errors: ["JSON did not decode as \(DeckIR.currentVersion): \(error.localizedDescription)"])
        }
        do {
            return try validator.validate(deck, requestedSlideCount: request.slideCount, notesRequired: request.notes)
        } catch let ValidationError.structural(errors) {
            throw DraftErrors(errors: errors)
        }
    }

    private func finish(_ result: ValidationResult, _ request: DeckRequest, _ designURL: URL?,
                        _ directory: URL, usage: Usage,
                        emit: @Sendable @escaping (GenerationEvent) -> Void) async throws -> DeckResult {
        emit(.rendering)
        let deckResult: DeckResult
        do {
            deckResult = try await renderer.render(
                result.deck, designURL: designURL, notesEnabled: request.notes,
                into: directory, warnings: result.warnings)
        } catch let RenderError.renderFailed(underlying) {
            throw LecternError.renderFailed(message: underlying)
        }
        emit(.finished(deckResult))
        return deckResult
    }
}
