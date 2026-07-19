import Foundation
import Rostrum

public struct DeckResult: Sendable, Equatable {
    public let url: URL
    public let slideCount: Int
    public let warnings: [String]
}

public enum RenderError: Error {
    case renderFailed(underlying: String)
}

/// Turns a validated `DeckIR` into a native `.pptx` via Rostrum's builders. An
/// actor per invariant I2: the (non-`Sendable`) Rostrum presentation is created,
/// mutated, and saved entirely inside here — only a `DeckResult` (URLs + value
/// types) leaves.
public actor DeckRenderer {
    public init() {}

    /// Render `deck` (styled by the `design.md` at `designURL`, if any) into
    /// `directory`. `warnings` from validation are passed through to the result.
    public func render(_ deck: DeckIR, designURL: URL?, notesEnabled: Bool,
                       into directory: URL, warnings: [String] = []) throws -> DeckResult {
        do {
            let presentation = try Presentation()
            if let designURL { _ = try presentation.applyDesign(contentsOf: designURL) }

            for slide in deck.slides {
                let built = try build(slide, in: presentation)
                if notesEnabled, let notes = slide.notes, !notes.isEmpty {
                    try built.setNotes(notes)
                }
            }
            // Presentation() starts with one blank slide; the builders appended
            // after it. Drop the leading blank so the deck is exactly the IR.
            if presentation.slides.count > deck.slides.count {
                try presentation.slides.remove(at: 0)
            }
            applySections(deck, to: presentation)

            let url = try outputURL(title: deck.meta.title, in: directory)
            try presentation.save(to: url)
            return DeckResult(url: url, slideCount: presentation.slides.count, warnings: warnings)
        } catch let error as RenderError {
            throw error
        } catch {
            throw RenderError.renderFailed(underlying: "\(error)")
        }
    }

    // MARK: - IR layout → Rostrum builder

    private func build(_ slide: IRSlide, in deck: Presentation) throws -> Slide {
        let title = slide.title ?? ""
        let body = slide.body
        switch slide.kind {
        case .title:
            return try deck.titleSlide(title, subtitle: body?.subtitle)
        case .sectionHeader:
            return try deck.sectionSlide(title, subtitle: body?.kicker)
        case .agenda:
            return try deck.bulletSlide(title.isEmpty ? "Agenda" : title, body?.items ?? [])
        case .bullets:
            return try deck.bulletSlide(title, flatten(body?.bullets ?? []))
        case .twoColumn, .comparison:
            let left = body?.left ?? Column(heading: "", bullets: [])
            let right = body?.right ?? Column(heading: "", bullets: [])
            return try deck.comparisonSlide(title, leftHeader: left.heading, left: left.bullets,
                                            rightHeader: right.heading, right: right.bullets)
        case .quote:
            return try deck.quoteSlide(body?.quote ?? title, attribution: body?.attribution)
        case .bigNumber:
            return try deck.calloutSlide(stat: body?.value ?? "", caption: body?.label ?? "", kicker: title.isEmpty ? nil : title)
        case .closing:
            let subtitle = [body?.callToAction, body?.contact].compactMap { $0 }.joined(separator: "\n")
            return try deck.sectionSlide(title.isEmpty ? "Thank you" : title, subtitle: subtitle.isEmpty ? nil : subtitle)
        case .unknown:
            // Validation downgrades unknown → bullets, so this is unreachable for
            // a validated deck; render an empty bulleted slide defensively.
            return try deck.bulletSlide(title, [])
        }
    }

    /// Flatten a bullet tree to strings, sub-bullets prefixed with an en dash.
    private func flatten(_ bullets: [Bullet]) -> [String] {
        bullets.flatMap { [$0.text] + ($0.subBullets ?? []).map { "– \($0)" } }
    }

    // MARK: - Sections

    private func applySections(_ deck: DeckIR, to presentation: Presentation) {
        guard let sections = deck.sections, !sections.isEmpty else { return }
        let indexOfSlideId = Dictionary(uniqueKeysWithValues: deck.slides.enumerated().map { ($1.id, $0) })
        var boundaries: [(name: String, startSlide: Int)] = []
        for section in sections {
            guard let first = section.slideIds.compactMap({ indexOfSlideId[$0] }).min() else { continue }
            boundaries.append((section.title ?? "Section", first))
        }
        boundaries.sort { $0.startSlide < $1.startSlide }
        guard let firstBoundary = boundaries.first, firstBoundary.startSlide == 0 else { return }
        try? presentation.setSections(boundaries)
    }

    // MARK: - Output path

    private func outputURL(title: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = slugify(title.isEmpty ? "deck" : title)
        var candidate = directory.appendingPathComponent("\(base).pptx")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base)-\(n).pptx")
            n += 1
        }
        return candidate
    }

    private func slugify(_ s: String) -> String {
        let lowered = s.lowercased()
        var out = ""
        var lastDash = false
        for scalar in lowered.unicodeScalars {
            if scalar.properties.isAlphabetic || ("0"..."9").contains(Character(scalar)) {
                out.unicodeScalars.append(scalar); lastDash = false
            } else if !lastDash {
                out.append("-"); lastDash = true
            }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "deck" : String(trimmed.prefix(60))
    }
}
