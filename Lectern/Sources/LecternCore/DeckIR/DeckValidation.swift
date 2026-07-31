import Foundation
import Rostrum

/// The result of validating a deck: the (possibly downgraded) deck plus soft
/// warnings. Hard failures throw `ValidationError`.
public struct ValidationResult: Sendable, Equatable {
    public var deck: DeckIR
    public var warnings: [String]
}

public enum ValidationError: Error, Equatable {
    /// Ordered list of hard structural errors (fed to the repair prompt).
    case structural([String])
}

/// Structural + content validation (§8.3–8.5). Nothing reaches the renderer
/// without passing this (invariant I3).
public struct DeckValidator: Sendable {
    public init() {}

    public func validate(_ input: DeckIR, requestedSlideCount: Int? = nil,
                         notesRequired: Bool = false) throws -> ValidationResult {
        var deck = input
        var errors: [String] = []
        var warnings: [String] = []

        if deck.irVersion != DeckIR.currentVersion {
            errors.append("irVersion must be \"\(DeckIR.currentVersion)\", got \"\(deck.irVersion)\"")
        }

        let slideIds = deck.slides.map(\.id)
        if Set(slideIds).count != slideIds.count { errors.append("slide ids are not unique") }
        let sectionIds = (deck.sections ?? []).map(\.id)
        if Set(sectionIds).count != sectionIds.count { errors.append("section ids are not unique") }

        let slideIdSet = Set(slideIds), sectionIdSet = Set(sectionIds)
        for section in deck.sections ?? [] {
            for sid in section.slideIds where !slideIdSet.contains(sid) {
                errors.append("section \"\(section.id)\" references unknown slide \"\(sid)\"")
            }
        }
        for slide in deck.slides {
            if let sid = slide.sectionId, !sectionIdSet.contains(sid) {
                errors.append("slide \"\(slide.id)\" references unknown section \"\(sid)\"")
            }
        }

        // §8.5 — downgrade unknown layouts with a bullets-compatible body.
        deck.slides = deck.slides.map { slide in
            var s = slide
            if case .unknown(let raw) = s.kind {
                if s.body?.bullets != nil {
                    warnings.append("slide \"\(s.id)\": unknown layout \"\(raw)\" downgraded to bullets")
                    s.layout = "bullets"
                } else {
                    errors.append("slide \"\(s.id)\": unknown layout \"\(raw)\" with no bullets-compatible body")
                }
            }
            return s
        }

        // §8.5b — salvage a structured layout the model shaped wrong.
        //
        // These layouts carry a shape requirement the others do not: a 2x2 is
        // exactly four cells, a timeline needs its milestones. Failing the deck
        // over one of them costs twelve good slides and two model round trips,
        // so a slide whose content can still be told another way is re-laid-out
        // with a warning — the same bargain the unknown-layout downgrade makes.
        deck.slides = deck.slides.map { slide in
            var s = slide
            switch s.kind {
            case .quadrant:
                let cells = s.body?.quadrants ?? []
                guard cells.count != 4 else { break }
                if (2...SlideCapacity.bands).contains(cells.count) {
                    warnings.append("slide \"\(s.id)\": \(cells.count) quadrants is not a 2x2 — laid out as bands")
                    s.body?.items = cells.map { "\($0.heading) — \($0.detail)" }
                    s.layout = "bands"
                } else if s.body?.bullets != nil {
                    warnings.append("slide \"\(s.id)\": quadrant without four cells downgraded to bullets")
                    s.layout = "bullets"
                }
            case .timeline where (s.body?.milestones ?? []).isEmpty:
                if s.body?.bullets != nil {
                    warnings.append("slide \"\(s.id)\": timeline without milestones downgraded to bullets")
                    s.layout = "bullets"
                }
            case .table where (s.body?.table?.rows ?? []).isEmpty:
                if s.body?.bullets != nil {
                    warnings.append("slide \"\(s.id)\": table without rows downgraded to bullets")
                    s.layout = "bullets"
                }
            default:
                break
            }
            return s
        }

        for slide in deck.slides {
            if let problem = bodyProblem(for: slide) { errors.append("slide \"\(slide.id)\": \(problem)") }
        }

        // §8.3 — exactly one title first; ≤1 agenda; ≤1 closing, last.
        let titleIndices = deck.slides.indices.filter { deck.slides[$0].kind == .title }
        if titleIndices != [0] { errors.append("there must be exactly one \"title\" slide, and it must be first") }
        if deck.slides.filter({ $0.kind == .agenda }).count > 1 { errors.append("at most one \"agenda\" slide") }
        let closingIndices = deck.slides.indices.filter { deck.slides[$0].kind == .closing }
        if closingIndices.count > 1 { errors.append("at most one \"closing\" slide") }
        if closingIndices.count == 1, closingIndices[0] != deck.slides.count - 1 {
            errors.append("the \"closing\" slide must be last")
        }

        guard errors.isEmpty else { throw ValidationError.structural(errors) }

        // §8.4 — soft rules → warnings, proceed.
        for slide in deck.slides {
            if let bullets = slide.body?.bullets {
                if bullets.count > 6 { warnings.append("slide \"\(slide.id)\": \(bullets.count) top-level bullets (> 6)") }
                for bullet in bullets where bullet.text.split(separator: " ").count > 12 {
                    warnings.append("slide \"\(slide.id)\": a bullet exceeds 12 words")
                }
            }
            if notesRequired, slide.kind != .sectionHeader, (slide.notes ?? "").isEmpty {
                warnings.append("slide \"\(slide.id)\": missing speaker notes")
            }
        }
        if let requested = requestedSlideCount {
            let delivered = deck.slides.count
            if Double(delivered) < Double(requested) * 0.8 || Double(delivered) > Double(requested) * 1.2 {
                warnings.append("delivered \(delivered) slides, requested \(requested) (outside ±20%)")
            }
        }

        return ValidationResult(deck: deck, warnings: warnings)
    }

    /// The required-field problem for a slide's body given its layout, or nil.
    private func bodyProblem(for slide: IRSlide) -> String? {
        let body = slide.body
        switch slide.kind {
        case .agenda:
            if (body?.items ?? []).isEmpty { return "agenda requires non-empty body.items" }
        case .bullets:
            if (body?.bullets ?? []).isEmpty { return "bullets requires non-empty body.bullets" }
        case .twoColumn, .comparison:
            if body?.left == nil || body?.right == nil { return "\(slide.layout) requires body.left and body.right" }
        case .quote:
            if (body?.quote ?? "").isEmpty { return "quote requires body.quote" }
        case .bigNumber:
            if (body?.value ?? "").isEmpty || (body?.label ?? "").isEmpty { return "bigNumber requires body.value and body.label" }
        case .chart:
            if (body?.chart?.series ?? []).isEmpty { return "chart requires body.chart with at least one series" }
        case .metrics:
            if (body?.stats ?? []).isEmpty { return "metrics requires body.stats" }
        case .bands:
            if (body?.items ?? []).isEmpty && (body?.bullets ?? []).isEmpty { return "bands requires body.items" }
        case .diagram:
            if (body?.diagram?.items ?? []).isEmpty { return "diagram requires body.diagram with items" }
        case .imageLeft, .imageRight:
            // Same body as bullets; the picture is optional and the slide
            // simply uses the full width when none arrives.
            if (body?.bullets ?? []).isEmpty { return "\(slide.layout) requires body.bullets" }
        case .timeline:
            if (body?.milestones ?? []).isEmpty { return "timeline requires body.milestones" }
        case .quadrant:
            // A 2x2 with a hole in it is a different diagram.
            if (body?.quadrants ?? []).count != 4 { return "quadrant requires exactly four quadrants" }
        case .table:
            guard let table = body?.table else { return "table requires body.table" }
            if table.headers.isEmpty { return "table requires body.table.headers" }
            if table.rows.isEmpty { return "table requires at least one body row" }
        case .title, .sectionHeader, .closing:
            break                                   // all payload fields optional
        case .unknown:
            return "unknown layout"                 // shouldn't reach here (downgraded above)
        }
        return nil
    }
}

/// Builds the one-shot repair instruction (§8.7): the invalid JSON plus a
/// numbered list of errors, asking the model to return corrected JSON only.
public enum RepairPrompt {
    public static func make(invalidJSON: String, errors: [String]) -> String {
        let numbered = errors.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return """
        The deck JSON you returned failed validation. Fix ONLY these problems and \
        return the corrected JSON object with no prose, no code fences, and the same \
        \(DeckIR.currentVersion) shape:

        \(numbered)

        --- invalid JSON ---
        \(invalidJSON)
        """
    }
}
