import Foundation

extension RichTextLayout {
    /// Scratch input reuse for one body's width or autofit trials. Only body autofit
    /// values may change while this object is in use; discard it after fitting.
    /// Paragraphs, inherited styles, theme and font registration stay fixed.
    /// It retains no layout results or size-dependent glyph measurements.
    package final class Preparation {
        struct Piece {
            let text: String
            var style: ResolvedTextRun
            let metrics: FontMetrics?
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

        package init() {}

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
        let pieces = paragraph.childElements.compactMap { piece -> Preparation.Piece? in
            guard ["a:r", "a:fld", "a:br"].contains(piece.name) else { return nil }
            let text = piece.name == "a:br" ? "\n" : (piece.name == "a:fld" && piece[attribute: "type"] == "slidenum" && slideNumber != nil
                ? String(slideNumber!) : piece.firstChild(named: "a:t")?.textContent ?? "")
            let style = resolve(text: text, properties: [piece.firstChild(named: "a:rPr")].compactMap { $0 } + defaults,
                theme: theme, defaultSize: defaultSize, scale: scale)
            return Preparation.Piece(text: text, style: style, metrics: face(style))
        }
        return Preparation.Paragraph(node: paragraph, level: level, properties: properties,
            defaults: defaults, emptyDefaults: emptyDefaults, indent: indent, left: left, right: right,
            defaultTab: defaultTab, tabs: tabs, hasDeclaredSpacing: declaredSpacing != nil,
            fixedSpacing: fixedSpacing, percentageSpacing: percentageSpacing,
            baseStyle: baseStyle, baseSize: baseSize, baseMetrics: baseStyle.flatMap(face), pieces: pieces,
            nativeLeftToRight: !["1", "true"].contains(attribute("rtl") ?? "0"))
    }
}
