import Foundation

extension RichTextLayout {
    /// Scratch input reuse for one body's width or autofit trials. Only body autofit
    /// values may change while this object is in use; discard it after fitting.
    /// Paragraphs, inherited styles, theme and font registration stay fixed.
    /// It retains no layout results. Table searches may supply a shared, bounded
    /// cache of complete fragment advances, keyed by effective size and features.
    package final class Preparation {
        struct Piece {
            let text: String
            var style: ResolvedTextRun
            let metrics: FontMetrics?
            var previewSubstitution: String? = nil
        }
        struct Paragraph {
            let node: XML.Element
            let level: Int
            let properties: [XML.Element]
            let defaults: [XML.Element]
            let emptyDefaults: [XML.Element]
            let indent: Double
            let left: Double
            let right: Double
            let defaultTab: Double
            let tabs: [(position: Double, alignment: String)]
            let hasDeclaredSpacing: Bool
            let fixedSpacing: Double?
            let percentageSpacing: Double?
            let baseStyle: ResolvedTextRun?
            let baseSize: Double
            let baseMetrics: FontMetrics?
            let pieces: [Piece]
            let nativeLeftToRight: Bool
        }
        struct Segment {
            let input: TextShaper.PreparedText
            let scalars: [Unicode.Scalar]
            let breaks: Set<Int>
        }
        private struct SegmentKey: Hashable {
            let text: String
            // Swift String equality is canonical. A cached source range must
            // instead belong to the identical original scalar sequence.
            static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.text.utf8.elementsEqual(rhs.text.utf8)
            }
            func hash(into hasher: inout Hasher) { hasher.combine(text) }
        }
        // Strong paragraph references prevent identity reuse. Bound retained
        // entries, pieces and input bytes; oversized input takes the usual path.
        private var paragraphs: [ObjectIdentifier: Paragraph] = [:]
        private var segments: [SegmentKey: Segment] = [:]
        private var paragraphBytes = 0
        private var pieceCount = 0
        private var segmentBytes = 0

        let fragments: FragmentMeasurements?

        package init(fragments: FragmentMeasurements? = nil) { self.fragments = fragments }

        func paragraph(for node: XML.Element, create: () -> Paragraph) -> Paragraph {
            let key = ObjectIdentifier(node)
            if let cached = paragraphs[key] { return cached }
            let value = create()
            let bytes = value.pieces.reduce(0) { $0 + $1.text.utf8.count + $1.style.text.utf8.count }
            if paragraphs.count < 64, value.pieces.count <= 512 - pieceCount,
               bytes <= 65536 - paragraphBytes {
                paragraphs[key] = value
                paragraphBytes += bytes
                pieceCount += value.pieces.count
            }
            return value
        }

        func segment(_ text: String) -> Segment? {
            let key = SegmentKey(text: text)
            if let cached = segments[key] { return cached }
            let bytes = text.utf8.count
            guard segments.count < 64, bytes <= 65536 - segmentBytes,
                  !text.unicodeScalars.contains(where: { ArabicJoining.isArabic($0.value) }) else { return nil }
            let input = TextShaper.PreparedText(text, direction: .automatic)
            let value = Segment(input: input, scalars: Array(text.unicodeScalars),
                                breaks: Set(input.breaks.map(\.scalarOffset)))
            segments[key] = value
            segmentBytes += bytes
            return value
        }
    }

    /// Complete line-fragment advances for one immutable font environment.
    /// Requested face/style identifies metrics only while registered fonts and
    /// fallback metrics stay fixed. Discard this cache when those inputs change.
    /// Width, tracking and paragraph positioning are applied outside the cache.
    package final class FragmentMeasurements {
        private struct Key: Hashable {
            let text: String
            let family: String?
            let size: UInt64
            let bold: Bool, italic: Bool, kerning: Bool, ligatures: Bool, nativeLTR: Bool

            static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.size == rhs.size && lhs.family == rhs.family && lhs.bold == rhs.bold
                    && lhs.italic == rhs.italic && lhs.kerning == rhs.kerning
                    && lhs.ligatures == rhs.ligatures && lhs.nativeLTR == rhs.nativeLTR
                    && lhs.text.utf8.elementsEqual(rhs.text.utf8)
            }
            func hash(into hasher: inout Hasher) {
                hasher.combine(text); hasher.combine(family); hasher.combine(size)
                hasher.combine(bold); hasher.combine(italic); hasher.combine(kerning)
                hasher.combine(ligatures); hasher.combine(nativeLTR)
            }
        }
        private var advances: [Key: Double] = [:]
        private(set) var retainedBytes = 0
        var count: Int { advances.count }

        package init() {}

        func advance(_ text: String, style: ResolvedTextRun, nativeLTR: Bool,
                     create: () -> Double) -> Double {
            let key = Key(text: text, family: style.fontFamily, size: style.measurementPointSize.bitPattern,
                bold: style.bold, italic: style.italic, kerning: style.usesKerning,
                ligatures: style.usesStandardLigatures, nativeLTR: nativeLTR)
            if let cached = advances[key] { return cached }
            let value = create()
            let bytes = text.utf8.count + (style.fontFamily?.utf8.count ?? 0)
            if advances.count < 2048, bytes <= 262_144 - retainedBytes {
                advances[key] = value; retainedBytes += bytes
            }
            return value
        }
    }

    /// Read paragraph XML once. A scratch entry uses scale 1; ordinary layout
    /// resolves at its requested scale without retaining a prepared paragraph.
    static func prepareParagraph(_ paragraph: XML.Element, textBody: XML.Element,
                                 fonts: FontLibrary?, fallbackMetrics: FontMetrics?,
                                 theme: Theme?, inheritedStyles: [XML.Element],
                                 defaultSize: Double, scale: Double, slideNumber: Int?) -> Preparation.Paragraph {
        let own = paragraph.firstChild(named: "a:pPr")
        let level = Int(bounded(number(own, "lvl", 0), 0...8))
        var properties = [own, textBody.firstChild(named: "a:lstStyle")?.firstChild(named: "a:lvl\(level + 1)pPr"),
                          textBody.firstChild(named: "a:lstStyle")?.firstChild(named: "a:defPPr")].compactMap { $0 }
        for style in inheritedStyles {
            if style.name == "a:defRPr" { continue }
            if let p = style.firstChild(named: "a:lvl\(level + 1)pPr") { properties.append(p) }
            if let p = style.firstChild(named: "a:defPPr") { properties.append(p) }
        }
        func attribute(_ name: String) -> String? { properties.lazy.compactMap { $0[attribute: name] }.first }
        func child(_ name: String) -> XML.Element? { properties.lazy.compactMap { $0.firstChild(named: name) }.first }
        func face(_ style: ResolvedTextRun) -> FontMetrics? {
            if let fonts, !fonts.isEmpty, let name = style.fontFamily,
               let key = fonts.previewFace(for: FontFaceKey(family: name, bold: style.bold, italic: style.italic)) {
                return fonts.metrics(for: key)
            }
            return fallbackMetrics
        }
        let defaults = properties.compactMap { $0.firstChild(named: "a:defRPr") }
            + inheritedStyles.filter { $0.name == "a:defRPr" }
        let indent = bounded(attribute("indent").flatMap(Double.init) ?? 0, -1e9...1e9) / Double(EMU.perPoint)
        let left = bounded(attribute("marL").flatMap(Double.init) ?? 0, -1e9...1e9) / Double(EMU.perPoint)
        let right = bounded(attribute("marR").flatMap(Double.init) ?? 0, -1e9...1e9) / Double(EMU.perPoint)
        let defaultTab = bounded(attribute("defTabSz").flatMap(Double.init) ?? 914400, 1...Double(Int32.max)) / Double(EMU.perPoint)
        let tabs = child("a:tabLst")?.children(named: "a:tab").compactMap { tab -> (position: Double, alignment: String)? in
            guard let position = tab.coordinate("pos") else { return nil }
            return (Double(position) / Double(EMU.perPoint), tab[attribute: "algn"] ?? "l")
        }.sorted { $0.position < $1.position } ?? []
        let declaredSpacing = child("a:lnSpc")
        let fixedSpacing = declaredSpacing?.firstChild(named: "a:spcPts").map { bounded(number($0, "val", 0), 0...1e8) / 100 }
        let percentageSpacing = declaredSpacing?.firstChild(named: "a:spcPct").map { bounded(number($0, "val", 0), 0...1e7) }
        let hasText = paragraph.childElements.contains { ["a:r", "a:fld"].contains($0.name) && !($0.firstChild(named: "a:t")?.textContent ?? "").isEmpty }
        let emptyDefaults = hasText ? defaults : [paragraph.firstChild(named: "a:endParaRPr")].compactMap { $0 } + defaults
        // Without metrics, only the inherited size affects an empty line.
        let baseStyle = fonts?.isEmpty == false || fallbackMetrics != nil
            ? resolve(text: "", properties: emptyDefaults, theme: theme, defaultSize: defaultSize, scale: scale) : nil
        let baseSize = baseStyle?.fontSize ?? bounded(emptyDefaults.lazy.compactMap { $0[attribute: "sz"] }.first.flatMap(Double.init)
            ?? defaultSize * 100, 100...400000) / 100 * scale
        let children = paragraph.childElements
        var pieces: [Preparation.Piece] = []
        pieces.reserveCapacity(children.count)
        for piece in children {
            guard ["a:r", "a:fld", "a:br"].contains(piece.name) else { continue }
            let text = piece.name == "a:br" ? "\n" : (piece.name == "a:fld" && piece[attribute: "type"] == "slidenum" && slideNumber != nil
                ? String(slideNumber!) : piece.firstChild(named: "a:t")?.textContent ?? "")
            let style = resolve(text: text, properties: [piece.firstChild(named: "a:rPr")].compactMap { $0 } + defaults,
                theme: theme, defaultSize: defaultSize, scale: scale)
            let metrics = face(style)
            let original = Preparation.Piece(text: text, style: style, metrics: metrics)
            guard let fonts, !fonts.previewSymbolFallbackFamilies.isEmpty, let metrics,
                  let family = style.fontFamily, text.utf8.contains(where: { $0 >= 0x80 }),
                  text.unicodeScalars.contains(where: { TextShaper.isStandaloneSymbol($0.value) && metrics.glyphID(for: $0) == 0 }) else {
                pieces.append(original)
                continue
            }
            var pending = ""
            func flush() {
                guard !pending.isEmpty else { return }
                var run = style; run.text = pending
                pieces.append(Preparation.Piece(text: pending, style: run, metrics: metrics)); pending = ""
            }
            for character in text {
                // Never split a grapheme/emoji sequence into unrelated faces.
                let scalars = character.unicodeScalars
                if scalars.count == 1, let scalar = scalars.first, metrics.glyphID(for: scalar) == 0,
                   let selected = fonts.previewSymbolFace(for: scalar, requested: FontFaceKey(family: family, bold: style.bold, italic: style.italic)) {
                    flush()
                    // Face keys are case-folded; show and paint the font's own family name.
                    let selectedMetrics = fonts.metrics(for: selected)
                    let name = selectedMetrics?.familyNames.first { $0.lowercased() == selected.family } ?? selected.family
                    var run = style; run.text = String(character); run.fontFamily = name
                    run.bold = selected.bold; run.italic = selected.italic
                    pieces.append(Preparation.Piece(text: run.text, style: run, metrics: selectedMetrics,
                        previewSubstitution: "Preview symbol U+\(String(scalar.value, radix: 16, uppercase: true)) uses registered \(name) because \(family) has no glyph. The document font is unchanged."))
                } else { pending.append(character) }
            }
            flush()
        }
        return Preparation.Paragraph(node: paragraph, level: level, properties: properties,
            defaults: defaults, emptyDefaults: emptyDefaults, indent: indent, left: left, right: right,
            defaultTab: defaultTab, tabs: tabs, hasDeclaredSpacing: declaredSpacing != nil,
            fixedSpacing: fixedSpacing, percentageSpacing: percentageSpacing,
            baseStyle: baseStyle, baseSize: baseSize, baseMetrics: baseStyle.flatMap(face), pieces: pieces,
            nativeLeftToRight: !["1", "true"].contains(attribute("rtl") ?? "0"))
    }
}
