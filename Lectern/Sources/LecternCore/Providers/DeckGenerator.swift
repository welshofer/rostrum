import Foundation
import Rostrum

/// The generation pipeline: draft → decode + validate → (one repair) → render.
/// Ties a provider to the validator (I3) and the renderer (I2). Emits UI events
/// and returns a `DeckResult`.
public actor DeckGenerator {
    private let provider: LLMProvider
    private let validator = DeckValidator()
    private let normalizer = DeckNormalizer()
    private let renderer = DeckRenderer()

    private let imageProvider: (any ImageProvider)?
    private let imageStyle: String?
    private let quality: Bool
    private let useSmartArt: Bool

    public init(provider: LLMProvider, imageProvider: (any ImageProvider)? = nil,
                imageStyle: String? = nil, quality: Bool = true, useSmartArt: Bool = false) {
        self.provider = provider
        self.imageProvider = imageProvider
        self.imageStyle = imageStyle
        self.quality = quality
        self.useSmartArt = useSmartArt
    }

    public func generate(_ request: DeckRequest, designURL: URL?, template: DeckTemplate,
                         into directory: URL, diagnostics: URL,
                         emit: @Sendable @escaping (GenerationEvent) -> Void) async throws -> DeckResult {
        try await generate(request, designURL: designURL, into: directory, diagnostics: diagnostics,
                           template: template.nativeTemplate(), emit: emit)
    }

    private struct DraftErrors: Error { var errors: [String] }

    /// `diagnostics` is required and must not be `directory`: rejected drafts
    /// and render snapshots carry the user's prompt and pasted source text, so
    /// they belong in an app-owned folder, never among the user's decks.
    public func generate(_ request: DeckRequest, designURL: URL?, into directory: URL,
                         diagnostics: URL, template: PowerPointTemplate? = nil,
                         emit: @Sendable @escaping (GenerationEvent) -> Void) async throws -> DeckResult {
        var request = request
        if template != nil {
            request.templateConstraints = "Use concise titles and short paragraphs: this deck will fill the placeholders of a supplied PowerPoint template. Preserve all requested facts. Prefer title, bullets, twoColumn, chart, table and closing layouts. Template artwork and formatting are fixed; do not rely on a generated background image or invent template branding."
        }
        let first = try await provider.draft(request, repairing: nil, emit: emit)
        emit(.validating)
        do {
            let result = try decodeAndValidate(first.json, request)
            return try await qaThenFinish(result, draftJSON: first.json, request, designURL, directory, diagnostics: diagnostics, template: template, usage: first.usage, emit: emit)
        } catch let failure as DraftErrors {
            // §8.7 — exactly one repair attempt.
            emit(.repairing)
            let repaired = try await provider.draft(
                request, repairing: RepairContext(invalidJSON: first.json, errors: failure.errors), emit: emit)
            emit(.validating)
            do {
                let result = try decodeAndValidate(repaired.json, request)
                return try await qaThenFinish(result, draftJSON: repaired.json, request, designURL, directory, diagnostics: diagnostics, template: template, usage: repaired.usage, emit: emit)
            } catch let second as DraftErrors {
                // Keep the draft that failed. Without it the only record of
                // what the model actually sent is an error string, which is not
                // enough to tell a prompt problem from a schema one.
                var errors = second.errors
                if let kept = Self.keepRejectedDraft(repaired.json, in: diagnostics, decks: directory) {
                    errors.append("the rejected draft is at \(kept.path)")
                }
                throw LecternError.schemaInvalid(errors: errors)
            }
        }
    }

    /// Write a rejected draft where it can be inspected. Best effort: a deck
    /// already failed, and failing to save the evidence must not replace that
    /// error with a different one.
    ///
    /// The caller passes a diagnostics directory rather than the decks folder.
    /// This file is the app's, not the user's — and it is the model's rendering
    /// of their prompt plus up to 40,000 characters lifted from whatever PDF
    /// they attached, so it has no business sitting among their documents
    /// (on iOS the decks folder is published to Files and USB file sharing).
    /// There is no fallback: when `directory` is the decks folder itself the
    /// draft is not written at all and this returns `nil`.
    static func keepRejectedDraft(_ json: String, in directory: URL, decks: URL) -> URL? {
        guard !isSameDirectory(directory, decks) else { return nil }
        // A per-run name, not a fixed one. `rejected-draft.json` meant the next
        // failure silently replaced the evidence for the last, which is exactly
        // when someone is comparing two of them.
        let stamp = DeckStorage.timestamp(Date())
        let url = directory.appendingPathComponent("rejected-draft-\(stamp).json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #if os(iOS)
            // On iOS this file sits in the app container alongside a Documents
            // folder published over USB file sharing; encrypt it at rest.
            try Data(json.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            #else
            // macOS/Linux have no data-protection-at-rest, so the desktop
            // equivalent is to keep the draft — the model's rendering of the
            // user's prompt plus pasted grounding text — unreadable by other
            // processes running as the user: create it owner-only (0o600).
            //
            // The mode has to be applied when the inode is created, not after
            // the bytes land. Neither `Data.write(options: .atomic)` nor
            // `FileManager.createFile(atPath:contents:attributes:)` guarantees
            // that ordering — both can put the content on disk under the
            // default mode and narrow it afterwards, leaving a window in which
            // the draft is world-readable. `open` with an explicit mode has no
            // such window: POSIX applies it at creation, and O_EXCL means we
            // never write into a file we did not just make ourselves.
            //
            // The tradeoff is that this is not a temp-file-then-rename atomic
            // write, so a crash mid-write could truncate this best-effort
            // diagnostic. That is the right trade: never exposing the content
            // matters more than crash-atomicity for a file that exists only to
            // be read back by a developer.
            let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
            guard descriptor >= 0 else { return nil }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            try handle.write(contentsOf: Data(json.utf8))
            try handle.close()
            #endif
            return url
        } catch {
            return nil
        }
    }

    /// Whether two directory URLs name the same folder once `.`/`..` segments
    /// and symlinks are resolved, so `decks/./` cannot slip past the guard.
    static func isSameDirectory(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.resolvingSymlinksInPath().path
            == b.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// The QA editor pass: hand the valid draft to the reviewer and use its
    /// revision when it also validates. A failed or invalid revision is ignored
    /// (never worse than the draft).
    private func qaThenFinish(_ result: ValidationResult, draftJSON: String, _ request: DeckRequest,
                              _ designURL: URL?, _ directory: URL, diagnostics: URL, template: PowerPointTemplate?, usage: Usage,
                              emit: @Sendable @escaping (GenerationEvent) -> Void) async throws -> DeckResult {
        var final = result
        if quality {
            emit(.auditing)
            do {
                let revised = try await provider.revise(request, deckJSON: draftJSON, emit: emit)
                if revised.json != draftJSON,
                   let improved = try? decodeAndValidate(revised.json, request) {
                    final = improved
                }
            } catch is CancellationError {
                // A cancel is not a failed QA pass to shrug off: swallowed
                // here, the pipeline would go on to illustrate (more paid
                // calls) and write a deck for a run the user stopped.
                throw CancellationError()
            } catch {
                // A failed or invalid revision is ignored — never worse than
                // the draft.
            }
        }
        try Task.checkCancellation()
        return try await finish(final, request, designURL, directory, diagnostics: diagnostics, template: template, usage: usage, emit: emit)
    }

    /// Generate an image for each slide that carries an `ImageBrief`, concurrently.
    /// Images are an enhancement: a failed one is skipped (not fatal), but the
    /// failure is reported as a warning so "0 images" is never silent.
    /// Cancellation is not a failure: it propagates as `CancellationError`.
    private func illustrate(_ deck: DeckIR, requestedSlideCount: Int, template: PowerPointTemplate?,
                            emit: @Sendable @escaping (GenerationEvent) -> Void) async throws -> (images: [String: Data], warnings: [String]) {
        guard let imageProvider else { return ([:], []) }
        if let template {
            let source = try? Presentation.fromTemplate(data: template.data)
            let supportsPictures = source?.allLayouts.contains { layout in
                (template.selectedMasterID == nil || layout.master?.part.uri.value == template.selectedMasterID)
                    && layout.placeholders.contains { $0.type == "pic" }
            } ?? false
            if !supportsPictures { return ([:], ["Images were not generated: the selected template has no picture placeholders."]) }
        }
        // Only slides whose layout can actually show an image (skip text-dense ones,
        // so we never waste an API call or clip text). Full-bleed layouts get a wide
        // image so the background barely stretches.
        var briefed = deck.slides.compactMap { slide -> (String, ImageBrief, ImageAspect, ImageRole)? in
            let placement = slide.kind.imagePlacement
            guard placement != .none, let brief = slide.image else { return nil }
            let aspect = placement == .fullBleed ? ImageAspect.wide : ImageAspect(brief: brief.aspect)
            return (slide.id, brief, aspect, ImageRole(placement: placement))
        }
        // Every brief is a paid, user-billed call, and how many there are is
        // the model's choice (one a source document can steer). Keep the first
        // `budget` in slide order and say which slides went without.
        var limitWarnings: [String] = []
        let budget = PriceTable.imageCallBudget(slideCount: requestedSlideCount)
        if briefed.count > budget {
            let dropped = briefed[budget...].map { "\"\($0.0)\"" }.joined(separator: ", ")
            limitWarnings.append("Image briefs for the slides with ids \(dropped) were not generated: "
                + "\(briefed.count) exceeds the budget of \(budget) for a \(requestedSlideCount)-slide request")
            briefed.removeSubrange(budget...)
        }
        // Bound what each call carries too: a runaway subject is cut on a word
        // boundary before `ImageStyleDirective.compose` sees it.
        var shortened: [String] = []
        briefed = briefed.map { id, brief, aspect, role in
            let (subject, truncated) = ImageStyleDirective.clampSubject(brief.prompt)
            guard truncated else { return (id, brief, aspect, role) }
            shortened.append("\"\(id)\"")
            var clamped = brief
            clamped.prompt = subject
            return (id, clamped, aspect, role)
        }
        if !shortened.isEmpty {
            limitWarnings.append("Image briefs for the slides with ids \(shortened.joined(separator: ", ")) were shortened to "
                + "\(ImageStyleDirective.maximumSubjectScalars) characters (Unicode scalars)")
        }
        // A brief the model wrote for a layout that cannot render one is thrown
        // away here. That used to be silent, which is why "why aren't we making
        // images?" had no answer on the screen: the model may well have asked
        // for several and every one landed on a chart or bullets slide.
        let unusable = deck.slides.filter { $0.image != nil && $0.kind.imagePlacement == .none }
        let discarded = unusable.map {
            "slide \"\($0.title ?? $0.id)\": an image was requested but a \"\($0.layout)\" "
                + "slide cannot show one"
        }
        guard !briefed.isEmpty else { return ([:], discarded + limitWarnings) }

        emit(.illustrating(completed: 0, total: briefed.count))
        let style = imageStyle
        // Honour the provider's own burst policy instead of starting everything
        // at once. Every briefed slide used to get a task immediately, so a
        // 40-slide deck fired 40 simultaneous requests — at Gemini, the default,
        // which declares a ceiling of one precisely because its quotas are
        // sensitive to bursts. The 429s that came back were self-inflicted: the
        // provider's own retry budget was being spent on congestion this code
        // created, and the user read the result as "N of M image(s) couldn't be
        // generated". `maximumConcurrentRequests` existed and said all of this;
        // nothing had ever read it.
        let inFlightLimit = max(1, imageProvider.id.maximumConcurrentRequests)
        var images: [String: Data] = [:]
        var failures: [String] = []
        var done = 0
        // A throwing group so a cancel surfaces from `illustrate` instead of
        // being folded into per-slide failures: leaving the group by throwing
        // also cancels the requests still in flight.
        try await withThrowingTaskGroup(of: (String, Result<Data, Error>).self) { group in
            func record(_ outcome: (String, Result<Data, Error>)) {
                let (id, result) = outcome
                done += 1
                emit(.illustrating(completed: done, total: briefed.count))
                switch result {
                case .success(let data): images[id] = data
                case .failure(let error): failures.append(DeckGenerator.imageFailure(error))
                }
            }
            var next = 0
            while next < briefed.count {
                // At the ceiling, wait for one to land before starting another,
                // so the number in flight never exceeds it.
                if next >= inFlightLimit, let finished = try await group.next() {
                    record(finished)
                }
                let (id, brief, aspect, role) = briefed[next]
                next += 1
                group.addTask {
                    do {
                        let data = try await imageProvider.image(prompt: brief.prompt, style: style,
                                                                 aspect: aspect, role: role)
                        return (id, .success(data))
                    } catch is CancellationError where Task.isCancelled {
                        // The user stopped the run; recording this as an image
                        // failure would let rendering go ahead and save a deck
                        // with N "couldn't be generated" warnings. A provider
                        // that throws CancellationError on its own, with the
                        // run still live, is an ordinary image failure below.
                        throw CancellationError()
                    } catch {
                        return (id, .failure(error))
                    }
                }
            }
            while let finished = try await group.next() { record(finished) }
        }
        var warnings: [String] = discarded + limitWarnings
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

    /// Layer-1 deterministic shaping (see `DeckNormalizer`). Applied to the final,
    /// already-valid deck. The result is re-fed through the unchanged validator: if
    /// any transform ever produced an invalid deck we discard it and render the
    /// un-normalized one, so the quality floor can never corrupt a valid deck.
    private func normalizeIfValid(_ result: ValidationResult, _ request: DeckRequest) -> ValidationResult {
        let (deck, report) = normalizer.normalize(result.deck)
        guard report.changed else { return result }
        guard let revalidated = try? validator.validate(
            deck, requestedSlideCount: request.slideCount, notesRequired: request.notes)
        else { return result }
        // Keep the original soft warnings; the normalizer's notes are improvements,
        // not problems, so they aren't surfaced to the user.
        return ValidationResult(deck: revalidated.deck, warnings: result.warnings)
    }

    /// A decode failure the model can act on.
    ///
    /// `localizedDescription` on a `DecodingError` is "The data couldn't be
    /// read because it isn't in the correct format" — true, and useless as the
    /// only thing a repair attempt is told. One draft came back with a slide
    /// object missing its closing brace; the repair was handed that sentence
    /// and made the same mistake again, losing a 29-slide deck to a defect its
    /// author could have found in seconds if told where to look.
    ///
    /// So: which field, what was expected, what arrived, and — for a syntax
    /// error — the line and column, which Foundation puts in the underlying
    /// error's debug description rather than anywhere `localizedDescription`
    /// will show.
    static func describeDecodingFailure(_ error: Error) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }
            return keys.isEmpty ? "the top level" : keys.joined(separator: ".")
        }
        func syntax(_ error: Error?) -> String {
            guard let detail = (error as NSError?)?.userInfo["NSDebugDescription"] as? String
            else { return "" }
            return " (\(detail))"
        }
        switch error {
        case let DecodingError.typeMismatch(type, context):
            return "\(path(context)) should be \(type) — \(context.debugDescription)"
        case let DecodingError.valueNotFound(type, context):
            return "\(path(context)) is missing its \(type) value"
        case let DecodingError.keyNotFound(key, context):
            return "\(path(context)) is missing the required key \"\(key.stringValue)\""
        case let DecodingError.dataCorrupted(context):
            return "\(path(context)): \(context.debugDescription)"
                + syntax(context.underlyingError)
        default:
            return error.localizedDescription + syntax(error)
        }
    }

    private func decodeAndValidate(_ json: String, _ request: DeckRequest) throws -> ValidationResult {
        let deck: DeckIR
        do {
            deck = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        } catch {
            throw DraftErrors(errors: ["JSON did not decode as \(DeckIR.currentVersion): "
                                       + Self.describeDecodingFailure(error)])
        }
        do {
            return try validator.validate(deck, requestedSlideCount: request.slideCount, notesRequired: request.notes)
        } catch let ValidationError.structural(errors) {
            throw DraftErrors(errors: errors)
        }
    }

    private func finish(_ result: ValidationResult, _ request: DeckRequest, _ designURL: URL?,
                        _ directory: URL, diagnostics: URL, template: PowerPointTemplate?, usage: Usage,
                        emit: @Sendable @escaping (GenerationEvent) -> Void) async throws -> DeckResult {
        // A cancel must land before `illustrate` starts spending: image calls
        // are the priciest thing this pipeline does after the draft itself.
        try Task.checkCancellation()
        let shaped = normalizeIfValid(result, request)
        let (images, imageWarnings) = try await illustrate(
            shaped.deck, requestedSlideCount: request.slideCount, template: template, emit: emit)   // no-op without an image provider
        // A cancel that arrived while images were in flight (including one a
        // provider reported as its own error) must not render or save a deck.
        try Task.checkCancellation()
        emit(.rendering)
        let snapshot = RenderSnapshot(deck: shaped.deck, images: images,
            design: try (template == nil ? designURL : nil).map { try String(contentsOf: $0, encoding: .utf8) },
            template: template, notesEnabled: request.notes, useSmartArt: useSmartArt)
        // Same rule as rejected drafts: the snapshot holds the user's content,
        // so it is never written into the decks folder.
        let recoveryURL = Self.isSameDirectory(diagnostics, directory) ? nil : try? snapshot.save(in: diagnostics)
        if let recoveryURL { emit(.recoveryAvailable(recoveryURL)) }
        var deckResult: DeckResult
        do {
            deckResult = try await renderer.render(
                shaped.deck, designURL: designURL, notesEnabled: request.notes,
                into: directory, warnings: shaped.warnings + imageWarnings, images: images,
                useSmartArt: useSmartArt, template: template)
        } catch let RenderError.renderFailed(underlying) {
            var message = underlying
            // Keep the final normalized deck, including accepted QA edits, so
            // layout failures can be replayed without another model request.
            if let data = try? JSONEncoder().encode(shaped.deck),
               let json = String(data: data, encoding: .utf8),
               let kept = Self.keepRejectedDraft(json, in: diagnostics, decks: directory) {
                message += " The draft was saved for recovery at \(kept.path)."
            }
            throw LecternError.renderFailed(message: message)
        }
        deckResult.recoveryURL = recoveryURL
        emit(.finished(deckResult))
        return deckResult
    }
}
