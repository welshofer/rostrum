import Foundation
import Rostrum
#if canImport(CoreText)
import CoreText
#endif

/// Uses the host's font substitution and glyph advances for preview wrapping.
/// Each render owns its cache; no shared mutable state or font-file disk reads.
enum PreviewFontMeasurement {
    static func install(on library: FontLibrary) {
        #if canImport(CoreText)
        var cache: [String: CTFont] = [:]
        library.previewAdvance = { text, face, size, bold, italic in
            let key = "\(face)|\(size)|\(bold)|\(italic)"
            let font: CTFont
            if let cached = cache[key] { font = cached }
            else {
                let base = CTFontCreateWithName(face as CFString, size, nil)
                var traits: CTFontSymbolicTraits = []
                if bold { traits.insert(.traitBold) }
                if italic { traits.insert(.traitItalic) }
                font = CTFontCreateCopyWithSymbolicTraits(base, size, nil, traits, [.traitBold, .traitItalic]) ?? base
                if cache.count < 512 { cache[key] = font }
            }
            let string = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(string), nil, nil, nil)
        }
        #endif
    }
}
