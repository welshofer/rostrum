import Foundation

/// A fully resolved run; text and its style boundaries survive layout.
public struct ResolvedTextRun: Equatable, Sendable {
    public var text: String
    public var fontFamily: String?
    public var fontSize: Double
    public var bold: Bool
    public var italic: Bool
    public var color: String
    public var tracking: Double
}

public struct RichTextSpan: Equatable, Sendable {
    public var run: ResolvedTextRun
    public var x: Double
    public var width: Double
}

public struct RichTextLine: Equatable, Sendable {
    public var spans: [RichTextSpan]
    public var baseline: Double
    public var height: Double
    public var width: Double
}

/// Shared, read-only paragraph layout used by fitting and SVG previews.
/// Geometry is in points relative to the outer text box. Explicit fallback
/// metrics or the deterministic estimate are used when a face is unavailable.
public struct RichTextLayout: Sendable {
    public let lines: [RichTextLine]
    public let contentHeight: Double
    public let fits: Bool
    public let truncated: Bool
    public let diagnostics: [ShapingDiagnostic]

    /// Insets can override bodyPr for DrawingML table cells (left/top/right/bottom).
    public init(textBody: XML.Element, width: Double, height: Double,
                fonts: FontLibrary? = nil, fallbackMetrics: FontMetrics? = nil,
                theme: Theme? = nil, inheritedStyles: [XML.Element] = [],
                defaultPointSize: Double = 18, lineSpacing: Double = 1,
                fontScale: Double? = nil, lineSpacingReduction: Double? = nil,
                slideNumber: Int? = nil, maxLines: Int = 4096,
                insets: (left: Double, top: Double, right: Double, bottom: Double)? = nil) {
        let body = textBody.firstChild(named: "a:bodyPr")
        func inset(_ key: String, _ value: Double) -> Double {
            body?.coordinate(key).map { Double($0) / Double(EMU.perPoint) } ?? value
        }
        let margins = insets ?? (inset("lIns", 7.2), inset("tIns", 3.6), inset("rIns", 7.2), inset("bIns", 3.6))
        let availableWidth = max(0, width - margins.0 - margins.2)
        let availableHeight = max(0, height - margins.1 - margins.3)
        let autofit = body?.firstChild(named: "a:normAutofit")
        let scale = Self.bounded(fontScale ?? Self.number(autofit, "fontScale", 100_000) / 1000, 0.1...100) / 100
        let reduction = Self.bounded(lineSpacingReduction ?? Self.number(autofit, "lnSpcReduction", 0) / 1000, 0...100) / 100
        let wrap = body?[attribute: "wrap"] != "none"
        // DrawingML suppresses spacing at the text body's outer edges unless
        // explicitly requested. Interior paragraph spacing is unaffected.
        let useEdgeParagraphSpacing = ["1", "true"].contains(body?[attribute: "spcFirstLastPara"] ?? "0")
        let paragraphs = textBody.children(named: "a:p")
        let lineLimit = max(1, min(maxLines, 65536))
        var output: [RichTextLine] = [], warnings: [ShapingDiagnostic] = []
        var cursor = 0.0, didTruncate = false, overflowWidth = false
        var numberByLevel: [Int: Int] = [:]

        struct Atom {
            var text: String
            let style: ResolvedTextRun
            var width: Double
            let ascent: Double
            let height: Double
            let source: Int
            let breakAfter: Bool
            var tab = false
            var hard = false
        }
        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            if output.count >= lineLimit { didTruncate = true; break }
            let own = paragraph.firstChild(named: "a:pPr")
            let level = Int(Self.bounded(Self.number(own, "lvl", 0), 0...8))
            var properties = [own, textBody.firstChild(named: "a:lstStyle")?.firstChild(named: "a:lvl\(level + 1)pPr")].compactMap { $0 }
            for style in inheritedStyles {
                if style.name == "a:defRPr" { continue }
                if let p = style.firstChild(named: "a:lvl\(level + 1)pPr") { properties.append(p) }
            }
            func attribute(_ name: String) -> String? {
                properties.lazy.compactMap { $0[attribute: name] }.first
            }
            func child(_ name: String) -> XML.Element? {
                properties.lazy.compactMap { $0.firstChild(named: name) }.first
            }
            let defaults = properties.compactMap { $0.firstChild(named: "a:defRPr") }
                + inheritedStyles.filter { $0.name == "a:defRPr" }
            let indent = Self.bounded(attribute("indent").flatMap(Double.init) ?? 0, -1e9...1e9) / Double(EMU.perPoint)
            let left = Self.bounded(attribute("marL").flatMap(Double.init) ?? 0, -1e9...1e9) / Double(EMU.perPoint)
            let right = Self.bounded(attribute("marR").flatMap(Double.init) ?? 0, -1e9...1e9) / Double(EMU.perPoint)
            let defaultTab = max(1, Self.bounded(attribute("defTabSz").flatMap(Double.init) ?? 914400, 1...1e9) / Double(EMU.perPoint))
            let tabs = child("a:tabLst")?.children(named: "a:tab").compactMap { $0.coordinate("pos").map { Double($0) / Double(EMU.perPoint) } }.sorted() ?? []
            let baseStyle = Self.resolve(text: "", properties: defaults,
                theme: theme, defaultSize: defaultPointSize, scale: scale)
            func face(_ style: ResolvedTextRun) -> FontMetrics? {
                if let name = style.fontFamily, let font = fonts?.metrics(for: name, bold: style.bold, italic: style.italic) { return font }
                return fallbackMetrics
            }
            let baseMetrics = face(baseStyle)
            let emptyHeight = baseMetrics?.lineHeight(pointSize: baseStyle.fontSize) ?? baseStyle.fontSize * 4 / 3
            let emptyAscent = baseMetrics?.ascent(pointSize: baseStyle.fontSize) ?? baseStyle.fontSize
            func spacing(_ element: XML.Element?, relativeTo height: Double) -> Double {
                guard let element else { return 0 }
                if let pts = element.firstChild(named: "a:spcPts") { return Self.bounded(Self.number(pts, "val", 0), 0...1e8) / 100 }
                if let pct = element.firstChild(named: "a:spcPct") { return height * Self.bounded(Self.number(pct, "val", 0), 0...1e7) / 100000 }
                return 0
            }
            if paragraphIndex > 0 || useEdgeParagraphSpacing {
                cursor += spacing(child("a:spcBef"), relativeTo: emptyHeight)
            }
            var atoms: [Atom] = [], source = 0
            let pieces = paragraph.childElements.filter { ["a:r", "a:fld", "a:br"].contains($0.name) }
            for piece in pieces {
                source += 1
                let text = piece.name == "a:br" ? "\n" : (piece.name == "a:fld" && piece[attribute: "type"] == "slidenum" && slideNumber != nil
                    ? String(slideNumber!) : piece.firstChild(named: "a:t")?.textContent ?? "")
                let style = Self.resolve(text: text,
                    properties: [piece.firstChild(named: "a:rPr")].compactMap { $0 } + defaults,
                    theme: theme, defaultSize: defaultPointSize, scale: scale)
                let metrics = face(style)
                if metrics == nil {
                    warnings.append(.unsupportedLayoutFeature("Unregistered font face: " + (style.fontFamily ?? "unspecified")))
                }
                let ascent = metrics?.ascent(pointSize: style.fontSize) ?? style.fontSize
                let lineHeight = metrics?.lineHeight(pointSize: style.fontSize) ?? style.fontSize * 4 / 3
                // Segment control characters before shaping: tabs are paragraph geometry.
                var segment = ""
                func appendSegment() {
                    guard !segment.isEmpty else { return }
                    let breaks = Set(TextShaper.lineBreaks(in: segment).map(\.scalarOffset))
                    if let metrics {
                        let shaped = TextShaper(metrics).shape(segment, pointSize: style.fontSize)
                        warnings.append(contentsOf: shaped.diagnostics)
                        if shaped.glyphs.contains(where: { $0.bidiLevel > 0 }) {
                            warnings.append(.unsupportedLayoutFeature("Rich-text bidirectional span ordering requires a verified paragraph renderer"))
                        }
                        let scalars = Array(segment.unicodeScalars)
                        // Logical cluster order makes line breaking independent of bidi.
                        // SVG delegates glyph drawing to its viewer; unsupported
                        // mixed-direction paragraph ordering is diagnosed above.
                        var grouped: [Range<Int>: Double] = [:]
                        for glyph in shaped.glyphs { grouped[glyph.scalarRange, default: 0] += glyph.advance }
                        for range in grouped.keys.sorted(by: { $0.lowerBound < $1.lowerBound }) {
                            let value = String(String.UnicodeScalarView(scalars[range]))
                            atoms.append(Atom(text: value, style: style,
                                width: (grouped[range] ?? 0) + style.tracking * Double(value.count),
                                ascent: ascent, height: lineHeight, source: source, breakAfter: breaks.contains(range.upperBound)))
                        }
                    } else {
                        var scalarOffset = 0
                        for character in segment {
                            let value = String(character); scalarOffset += value.unicodeScalars.count
                            atoms.append(Atom(text: value, style: style,
                                width: style.fontSize * (character == " " ? 0.25 : 0.42) + style.tracking,
                                ascent: ascent, height: lineHeight, source: source, breakAfter: breaks.contains(scalarOffset)))
                        }
                    }
                    segment = ""
                }
                for character in text {
                    if character == "\t" || character == "\n" || character == "\r" || character == "\r\n" {
                        appendSegment()
                        atoms.append(Atom(text: character == "\t" ? "\t" : "", style: style,
                            width: 0, ascent: ascent, height: lineHeight, source: source,
                            breakAfter: false, tab: character == "\t", hard: character != "\t"))
                    } else { segment.append(character) }
                }
                appendSegment()
            }
            // A local buNone/choice suppresses inherited bullets as a group.
            let bulletProperties = properties.first { p in
                ["a:buNone", "a:buChar", "a:buAutoNum"].contains { p.firstChild(named: $0) != nil }
            }
            var bullet: ResolvedTextRun?
            if bulletProperties?.firstChild(named: "a:buNone") == nil {
                if let char = bulletProperties?.firstChild(named: "a:buChar")?[attribute: "char"] {
                    var run = baseStyle; run.text = char; bullet = run
                } else if let auto = bulletProperties?.firstChild(named: "a:buAutoNum") {
                    let start = Int(Self.bounded(Self.number(auto, "startAt", 1), 1...32767))
                    let value = auto[attribute: "startAt"] != nil ? start : (numberByLevel[level] ?? start)
                    numberByLevel[level] = value + 1
                    var run = baseStyle; run.text = Self.numberLabel(value, type: auto[attribute: "type"] ?? "arabicPeriod"); bullet = run
                }
                if bullet != nil {
                    if let font = child("a:buFont")?[attribute: "typeface"] { bullet?.fontFamily = font }
                    if let percent = child("a:buSzPct") { bullet?.fontSize *= Self.bounded(Self.number(percent, "val", 100000), 0...400000) / 100000 }
                    if let points = child("a:buSzPts") { bullet?.fontSize = Self.bounded(Self.number(points, "val", 1800), 100...400000) / 100 * scale }
                }
            }
            let bulletAdvance: Double = bullet.map { run in
                face(run)?.width(of: run.text + " ", pointSize: run.fontSize)
                    ?? Double(run.text.count + 1) * run.fontSize * 0.42
            } ?? 0
            var lineAtoms: [Atom] = [], lineWidth = 0.0, firstLine = true, index = 0
            func startX() -> Double {
                left + (bullet != nil ? max(0, indent + bulletAdvance) : (firstLine ? indent : 0))
            }
            func limit() -> Double { max(0, availableWidth - right - startX()) }
            func emit() {
                guard output.count < lineLimit else { didTruncate = true; return }
                // Re-shape complete line fragments: a kerning pair that crossed
                // an automatic break must not squeeze the final glyph of a line.
                var fragmentStart = 0
                while fragmentStart < lineAtoms.count {
                    if lineAtoms[fragmentStart].tab { fragmentStart += 1; continue }
                    var end = fragmentStart + 1
                    while end < lineAtoms.count && !lineAtoms[end].tab
                        && lineAtoms[end].source == lineAtoms[fragmentStart].source { end += 1 }
                    let fragment = lineAtoms[fragmentStart..<end]
                    if let font = face(lineAtoms[fragmentStart].style) {
                        let value = fragment.map(\.text).joined(), style = lineAtoms[fragmentStart].style
                        let exact = TextShaper(font).shape(value, pointSize: style.fontSize).width
                            + Double(value.count) * style.tracking
                        let adjustment = exact - fragment.reduce(0) { $0 + $1.width }
                        lineAtoms[end - 1].width += adjustment; lineWidth += adjustment
                    }
                    fragmentStart = end
                }
                let naturalHeight = lineAtoms.map(\.height).max() ?? emptyHeight
                let ascent = lineAtoms.map(\.ascent).max() ?? emptyAscent
                let declared = child("a:lnSpc")
                let advance = (declared == nil ? naturalHeight * Self.bounded(lineSpacing, 0...100) : spacing(declared, relativeTo: naturalHeight)) * (1 - reduction)
                let align = attribute("algn") ?? "l"
                let extra = align == "ctr" ? (limit() - lineWidth) / 2 : align == "r" ? limit() - lineWidth : 0
                var spans: [RichTextSpan] = [], x = margins.0 + startX() + max(0, extra)
                if firstLine, var run = bullet {
                    run.text += " "
                    let width = face(run)?.width(of: run.text, pointSize: run.fontSize) ?? Double(run.text.count) * run.fontSize * 0.42
                    spans.append(RichTextSpan(run: run, x: margins.0 + left + indent, width: width))
                }
                var previousSource: Int?
                for atom in lineAtoms {
                    if atom.tab { x += atom.width; previousSource = nil; continue }
                    if previousSource == atom.source, !spans.isEmpty {
                        spans[spans.count - 1].run.text += atom.text
                        spans[spans.count - 1].width += atom.width
                    } else {
                        var run = atom.style; run.text = atom.text
                        spans.append(RichTextSpan(run: run, x: x, width: atom.width))
                    }
                    previousSource = atom.source; x += atom.width
                }
                let trailingSpace = lineAtoms.reversed().prefix(while: { $0.text == " " }).reduce(0) { $0 + $1.width }
                overflowWidth = overflowWidth || lineWidth - trailingSpace > limit() + 0.01
                output.append(RichTextLine(spans: spans, baseline: cursor + ascent,
                                           height: advance, width: lineWidth))
                cursor += advance; lineAtoms = []; lineWidth = 0; firstLine = false
            }
            while index < atoms.count {
                if output.count >= lineLimit { didTruncate = true; break }
                var atom = atoms[index]
                if atom.hard { emit(); index += 1; continue }
                if atom.tab {
                    let position = startX() + lineWidth
                    let stop = tabs.first { $0 > position + 0.001 } ?? (floor(position / defaultTab) + 1) * defaultTab
                    atom.width = max(0, stop - position)
                }
                if wrap && atom.text != " " && !lineAtoms.isEmpty && lineWidth + atom.width > limit() + 0.001 {
                    if let split = lineAtoms.lastIndex(where: \.breakAfter), split + 1 < lineAtoms.count {
                        let carry = Array(lineAtoms[(split + 1)...])
                        lineAtoms.removeSubrange((split + 1)...)
                        lineWidth = lineAtoms.reduce(0) { $0 + $1.width }; emit()
                        lineAtoms = carry; lineWidth = carry.reduce(0) { $0 + $1.width }
                    } else { emit() }
                    continue
                }
                lineAtoms.append(atom); lineWidth += atom.width; index += 1
            }
            if !lineAtoms.isEmpty || atoms.isEmpty || atoms.last?.hard == true { emit() }
            if paragraphIndex < paragraphs.count - 1 || useEdgeParagraphSpacing {
                cursor += spacing(child("a:spcAft"), relativeTo: emptyHeight)
            }
        }
        if didTruncate, !output.isEmpty {
            if !output[output.count - 1].spans.isEmpty { output[output.count - 1].spans[output[output.count - 1].spans.count - 1].run.text += "…" }
        }
        let offset: Double
        switch body?[attribute: "anchor"] {
        case "ctr": offset = margins.1 + (availableHeight - cursor) / 2
        case "b": offset = margins.1 + availableHeight - cursor
        default: offset = margins.1
        }
        for i in output.indices { output[i].baseline += offset }
        lines = output; contentHeight = cursor; truncated = didTruncate
        fits = !didTruncate && !overflowWidth && cursor <= availableHeight + 0.01
        var unique: [ShapingDiagnostic] = [], seen: Set<ShapingDiagnostic> = []
        for warning in warnings where seen.insert(warning).inserted { unique.append(warning) }
        diagnostics = unique
    }

    /// Shared placeholder inheritance chain, in closest-first order.
    static func inheritedStyles(for shape: XML.Element, owner: Part, package: OPCPackage) -> [XML.Element] {
        guard let ph = Placeholders.phElement(of: shape),
              let layout = try? owner.related(by: RelType.slideLayout, in: package) else { return [] }
        let index = ph[attribute: "idx"].flatMap(Int.init) ?? 0
        var kind = ph[attribute: "type"] ?? "obj", result: [XML.Element] = []
        if let tree = Slide.existingSpTree(of: layout) {
            for element in tree.childElements {
                guard let candidate = Placeholders.phElement(of: element),
                      (candidate[attribute: "idx"].flatMap(Int.init) ?? 0) == index else { continue }
                kind = candidate[attribute: "type"] ?? kind
                if let styles = element.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle") { result.append(styles) }
                break
            }
        }
        if let master = try? layout.related(by: RelType.slideMaster, in: package),
           let styles = try? master.dom().firstChild(named: "p:txStyles") {
            let bucket: String
            switch Slide.masterTypeReduction[kind] ?? "body" {
            case "title": bucket = "p:titleStyle"
            case "body": bucket = "p:bodyStyle"
            default: bucket = "p:otherStyle"
            }
            if let style = styles.firstChild(named: bucket) { result.append(style) }
        }
        return result
    }

    private static func number(_ element: XML.Element?, _ attribute: String, _ fallback: Double) -> Double {
        element?[attribute: attribute].flatMap(Double.init).flatMap { $0.isFinite ? $0 : nil } ?? fallback
    }
    private static func bounded(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound
    }
    private static func resolve(text: String, properties: [XML.Element], theme: Theme?,
                                defaultSize: Double, scale: Double) -> ResolvedTextRun {
        func attr(_ name: String) -> String? { properties.lazy.compactMap { $0[attribute: name] }.first }
        let named = properties.lazy.compactMap { $0.firstChild(named: "a:latin")?[attribute: "typeface"] }.first
        let family: String?
        switch named {
        case "+mj-lt": family = theme?.majorFont
        case "+mn-lt": family = theme?.minorFont
        case .some(let name): family = name
        default: family = theme?.minorFont ?? theme?.majorFont
        }
        var color = "#1A1A1A"
        for element in properties {
            guard let fill = element.firstChild(named: "a:solidFill") else { continue }
            if let resolved = DrawingColor.resolve(in: fill, theme: theme) {
                color = resolved.alpha < 1 ? "rgba(\(resolved.color.red),\(resolved.color.green),\(resolved.color.blue),\(resolved.alpha))" : "#" + resolved.color.hex
                break
            }
        }
        return ResolvedTextRun(text: text, fontFamily: family,
            fontSize: bounded(attr("sz").flatMap(Double.init) ?? defaultSize * 100, 100...400000) / 100 * scale,
            bold: ["1", "true"].contains(attr("b") ?? "0"), italic: ["1", "true"].contains(attr("i") ?? "0"), color: color,
            tracking: bounded(attr("spc").flatMap(Double.init) ?? 0, -400000...400000) / 100 * scale)
    }
    private static func numberLabel(_ number: Int, type: String) -> String {
        var value = String(number)
        if type.hasPrefix("alpha") {
            var n = number, letters = ""
            while n > 0 { n -= 1; letters = String(Unicode.Scalar(65 + n % 26)!) + letters; n /= 26 }
            value = type.hasPrefix("alphaLc") ? letters.lowercased() : letters
        }
        if type.hasPrefix("roman") {
            var n = number, roman = ""
            for (amount, label) in [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")] {
                while n >= amount { roman += label; n -= amount }
            }
            value = type.hasPrefix("romanLc") ? roman.lowercased() : roman
        }
        if type.hasSuffix("ParenBoth") { return "(\(value))" }
        if type.hasSuffix("ParenR") { return value + ")" }
        if type.hasSuffix("Plain") { return value }
        return value + "."
    }
}
