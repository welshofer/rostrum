import Foundation
import Rostrum

/// What rebranding a deck produced.
public struct RebrandResult: Sendable, Equatable {
    public let url: URL
    public let slideCount: Int

    /// Slides re-laid onto one of the template's layouts.
    public let relaid: Int
    /// Slides whose layout the template had no counterpart for, left on their
    /// own — as slide numbers, one-based, because that is how a user counts.
    public let kept: [Int]
    /// Hard-coded colours and fonts turned back into theme references.
    public let reboundColors: Int
    public let reboundFonts: Int

    /// One SVG per slide, before and after, rendered by Rostrum from the decks
    /// themselves. The comparison *is* the product here: a rebrand is only
    /// worth anything if you can see what it did.
    public let before: [String]
    public let after: [String]

    /// Rostrum's own lint on the deck written out.
    public let schemaIssues: [String]
}

public enum RebrandError: Error, Equatable {
    case notAPresentation(String)
    case failed(String)
}

/// Opens a deck, puts a template's brand on it, and writes it out.
///
/// This is the demo that exercises the half of Rostrum a generator never
/// touches — opening someone else's file, keeping everything it does not
/// model, and handing it back changed only where asked. An actor for the same
/// reason `DeckRenderer` is one: `Presentation` is not `Sendable` and must not
/// leave.
public actor DeckRebrander {
    public init() {}

    public func rebrand(deck deckURL: URL, template templateURL: URL,
                        into directory: URL,
                        rebindingDirectFormatting: Bool = true) async throws -> RebrandResult {
        let deck: Presentation
        do {
            deck = try Presentation(contentsOf: deckURL)
        } catch {
            throw RebrandError.notAPresentation(
                "\(deckURL.lastPathComponent) isn't a PowerPoint file Rostrum can open: \(error)")
        }
        let template: Presentation
        do {
            template = try Presentation(contentsOf: templateURL)
        } catch {
            throw RebrandError.notAPresentation(
                "\(templateURL.lastPathComponent) isn't a template Rostrum can open: \(error)")
        }

        // The output is always written as `.pptx`, so a deck opened from a
        // `.potx` or `.ppsx` has to be re-kinded to match. PowerPoint reads the
        // main part's content type, not the extension: leave it saying
        // "template" and double-clicking the result spawns a new untitled deck
        // instead of opening the one just rebranded.
        deck.documentKind = .presentation

        try Task.checkCancellation()
        let before = Self.previews(of: deck)

        let report: TemplateReport
        do {
            report = try deck.applyTemplate(
                from: template, rebindingDirectFormatting: rebindingDirectFormatting)
        } catch {
            throw RebrandError.failed("\(error)")
        }

        try Task.checkCancellation()
        let after = Self.previews(of: deck)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = Self.outputURL(for: deckURL, in: directory)
        do {
            try deck.save(to: url)
        } catch {
            throw RebrandError.failed("couldn't write the rebranded deck: \(error)")
        }

        return RebrandResult(
            url: url,
            slideCount: deck.slides.count,
            relaid: report.relaid.count,
            kept: report.kept.map { $0.slide + 1 },
            reboundColors: report.rebind.colors,
            reboundFonts: report.rebind.fonts,
            before: before,
            after: after,
            schemaIssues: ((try? deck.validate()) ?? []).map(\.description))
    }

    /// Render every slide to SVG. Best effort per slide: a preview is a
    /// convenience and one that fails is not a reason to fail a rebrand.
    private static func previews(of presentation: Presentation) -> [String] {
        (0..<presentation.slides.count).compactMap {
            try? presentation.renderSVG(slideAt: $0, pixelWidth: 640)
        }
    }

    /// `report.pptx` → `report-rebranded.pptx`, and never over the original:
    /// the input is the user's file and this is not entitled to replace it.
    static func outputURL(for source: URL, in directory: URL) -> URL {
        let stem = source.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(stem)-rebranded.pptx")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)-rebranded-\(n).pptx")
            n += 1
        }
        return candidate
    }
}
