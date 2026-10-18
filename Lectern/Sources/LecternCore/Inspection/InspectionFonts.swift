import Foundation
import Rostrum

enum InspectionFonts {
    /// Slide declarations alone miss fonts inherited from layouts, masters and
    /// theme overrides. Read these once per inspection; registration is bounded
    /// and leaves already registered embedded faces in place.
    static func families(in deck: Presentation, explicit: Set<String>? = nil, includeNotes: Bool = false) throws -> [String] {
        var families = explicit ?? []
        var types: Set<String> = [ContentType.slideLayout, ContentType.slideMaster, ContentType.theme,
                                 ContentType.chart, "application/vnd.openxmlformats-officedocument.themeOverride+xml"]
        // Inspection has already walked the slides. Other saved-deck callers
        // discover the same declarations without extracting the entire outline.
        if explicit == nil {
            for index in 0..<deck.slides.count {
                try Task.checkCancellation()
                guard let slide = try? deck.slides.slide(at: index), let root = try? slide.part.dom() else { continue }
                families.formUnion(DeckDetailExtractor.declaredFonts(in: root))
            }
        }
        if includeNotes { types.formUnion([ContentType.notesSlide, ContentType.notesMaster]) }
        for part in deck.package.parts.values.sorted(by: { $0.uri.value < $1.uri.value }) {
            try Task.checkCancellation()
            guard types.contains(part.contentType), let root = try? part.dom() else { continue }
            families.formUnion(DeckDetailExtractor.declaredFonts(in: root))
        }
        return families.sorted()
    }
}
