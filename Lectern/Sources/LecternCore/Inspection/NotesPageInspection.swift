import Foundation
import Rostrum

/// An independently loaded, immutable notes preview. Large decks pay for a
/// notes render only when the reader opens that page.
public struct NotesPageInspection: Sendable {
    public let fileURL: URL
    /// One-based slide position, matching the inspector and exported filenames.
    public let slideNumber: Int
    public let svg: String
    public let diagnostics: SlidePreviewDiagnostics
}

extension DeckInspector {
    /// Synchronous, CPU-bound work: call off the main actor. The source is
    /// reopened with the same decompression limit as normal inspection and is
    /// never saved or edited. Cancellation is checked around the render.
    public static func inspectNotesPage(
        deckAt url: URL, slideNumber: Int,
        limits: ZipReader.Limits = .init(totalUncompressedBytes: DeckInspector.defaultReadLimit)
    ) throws -> NotesPageInspection {
        try Task.checkCancellation()
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw DeckInspectionError.emptyFile }
        let deck: Presentation
        do {
            deck = try Presentation(data: data, limits: limits)
        } catch {
            throw DeckInspectionError.cannotOpen(String(describing: error))
        }
        guard slideNumber > 0, slideNumber <= deck.slides.count else {
            throw DeckInspectionError.cannotOpen("Slide \(slideNumber) does not exist.")
        }
        try Task.checkCancellation()
        let slide = try deck.slides.slide(at: slideNumber - 1)
        _ = deck.registerEmbeddedFonts()
        let explicit = DeckDetailExtractor.declaredFonts(in: try slide.part.dom())
        let families = try InspectionFonts.families(in: deck, explicit: explicit, includeNotes: true)
        _ = InstalledFonts.register(in: deck, families: families + ["Arial"])
        deck.fonts.previewFallbackFamily = "Arial"
        try Task.checkCancellation()
        let result = try deck.renderNotesSVGReportingProblems(slideAt: slideNumber - 1, pixelWidth: 960)
        try Task.checkCancellation()
        return NotesPageInspection(fileURL: url, slideNumber: slideNumber, svg: result.svg,
            diagnostics: SlidePreviewDiagnostics(slideNumber: slideNumber, problems: result.problems))
    }
}
