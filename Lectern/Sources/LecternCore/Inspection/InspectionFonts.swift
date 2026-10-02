import Foundation
import Rostrum

enum InspectionFonts {
    /// Slide declarations alone miss fonts inherited from layouts, masters and
    /// theme overrides. Read these once per inspection; registration is bounded
    /// and leaves already registered embedded faces in place.
    static func families(in deck: Presentation, explicit: Set<String>, includeNotes: Bool = false) throws -> [String] {
        var families = explicit
        var types: Set<String> = [ContentType.slideLayout, ContentType.slideMaster, ContentType.theme,
                                 "application/vnd.openxmlformats-officedocument.themeOverride+xml"]
        if includeNotes { types.formUnion([ContentType.notesSlide, ContentType.notesMaster]) }
        for part in deck.package.parts.values.sorted(by: { $0.uri.value < $1.uri.value }) {
            try Task.checkCancellation()
            guard types.contains(part.contentType), let root = try? part.dom() else { continue }
            families.formUnion(DeckDetailExtractor.declaredFonts(in: root))
        }
        return families.sorted()
    }
}
