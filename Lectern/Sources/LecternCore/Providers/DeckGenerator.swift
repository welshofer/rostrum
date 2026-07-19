import Foundation

/// The generation pipeline: draft → decode + validate → (one repair) → render.
/// Ties a provider to the validator (I3) and the renderer (I2). Emits UI events
/// and returns a `DeckResult`.
public actor DeckGenerator {
    private let provider: LLMProvider
    private let validator = DeckValidator()
    private let renderer = DeckRenderer()

    private let imageProvider: (any ImageProvider)?
    private let imageStyle: String?

    public init(provider: LLMProvider, imageProvider: (any ImageProvider)? = nil, imageStyle: String? = nil) {
        self.provider = provider
        self.imageProvider = imageProvider
        self.imageStyle = imageStyle
    }

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

    /// Generate an image for each slide that carries an `ImageBrief`, concurrently.
    /// Images are an enhancement: a failed one is skipped (not fatal), but the
    /// failure is reported as a warning so "0 images" is never silent.
    private func illustrate(_ deck: DeckIR,
                            emit: @Sendable @escaping (GenerationEvent) -> Void) async -> (images: [String: Data], warnings: [String]) {
        guard let imageProvider else { return ([:], []) }
        let briefed = deck.slides.compactMap { slide in slide.image.map { (slide.id, $0) } }
        guard !briefed.isEmpty else { return ([:], []) }

        emit(.illustrating(completed: 0, total: briefed.count))
        let style = imageStyle
        var images: [String: Data] = [:]
        var failures: [String] = []
        var done = 0
        await withTaskGroup(of: (String, Result<Data, Error>).self) { group in
            for (id, brief) in briefed {
                group.addTask {
                    do {
                        let data = try await imageProvider.image(
                            prompt: brief.prompt, style: style, aspect: ImageAspect(brief: brief.aspect))
                        return (id, .success(data))
                    } catch {
                        return (id, .failure(error))
                    }
                }
            }
            for await (id, result) in group {
                done += 1
                emit(.illustrating(completed: done, total: briefed.count))
                switch result {
                case .success(let data): images[id] = data
                case .failure(let error): failures.append(DeckGenerator.imageFailure(error))
                }
            }
        }
        var warnings: [String] = []
        if !failures.isEmpty {
            let reason = failures.first ?? "unknown error"
            warnings.append("\(failures.count) of \(briefed.count) image(s) couldn't be generated: \(reason)")
        }
        return (images, warnings)
    }

    private static func imageFailure(_ error: Error) -> String {
        guard let lectern = error as? LecternError else { return "\(error.localizedDescription)" }
        switch lectern {
        case .authFailed(let p): return "\(p) rejected the image key"
        case .rateLimited: return "image provider rate-limited"
        case .networkOffline: return "no connection"
        case .providerError(_, let m): return m
        default: return "\(lectern)"
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
        let (images, imageWarnings) = await illustrate(result.deck, emit: emit)   // no-op without an image provider
        emit(.rendering)
        let deckResult: DeckResult
        do {
            deckResult = try await renderer.render(
                result.deck, designURL: designURL, notesEnabled: request.notes,
                into: directory, warnings: result.warnings + imageWarnings, images: images)
        } catch let RenderError.renderFailed(underlying) {
            throw LecternError.renderFailed(message: underlying)
        }
        emit(.finished(deckResult))
        return deckResult
    }
}
