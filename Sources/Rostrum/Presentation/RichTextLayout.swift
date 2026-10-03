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
    /// Minimum rendered point size at which DrawingML enables kerning.
    /// Zero preserves the default of kerning at every size.
    public var kerningThreshold: Double = 0
    public var usesKerning: Bool { fontSize >= kerningThreshold }
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

    /// Insets and verticalAnchor can override bodyPr for DrawingML table cells.
    /// Insets are ordered left/top/right/bottom; nil preserves the body value.
    public init(textBody: XML.Element, width: Double, height: Double,
                fonts: FontLibrary? = nil, fallbackMetrics: FontMetrics? = nil,
                theme: Theme? = nil, inheritedStyles: [XML.Element] = [],
                defaultPointSize: Double = 18, lineSpacing: Double = 1,
                fontScale: Double? = nil, lineSpacingReduction: Double? = nil,
                slideNumber: Int? = nil, maxLines: Int = 4096,
                insets: (left: Double, top: Double, right: Double, bottom: Double)? = nil,
                verticalAnchor: String? = nil) {
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
        let hasRegisteredFonts = fonts?.isEmpty == false
        var output: [RichTextLine] = [], warnings: [ShapingDiagnostic] = []
        var cursor = 0.0, didTruncate = false, overflowWidth = false
        var measuredBottom = 0.0
        var numberByLevel: [Int: Int] = [:]

        struct Atom {
            var text: String
            let style: ResolvedTextRun
            var width: Double
            let ascent: Double
            let height: Double
            let drawingML: Bool
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
                if hasRegisteredFonts, let name = style.fontFamily,
                   let font = fonts?.metrics(for: name, bold: style.bold, italic: style.italic) { return font }
                return fallbackMetrics
            }
            let baseMetrics = face(baseStyle)
            func lineMetrics(_ metrics: FontMetrics?, size: Double) -> (ascent: Double, height: Double, drawingML: Bool) {
                if let share = metrics?.drawingMLAscentShare {
                    let height = size * 1.2
                    return (height * share, height, true)
                }
                return (metrics?.ascent(pointSize: size) ?? size,
                        metrics?.lineHeight(pointSize: size) ?? size * 4 / 3, false)
            }
            let empty = lineMetrics(baseMetrics, size: baseStyle.fontSize)
            let emptyHeight = empty.height, emptyAscent = empty.ascent
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
                let vertical = lineMetrics(metrics, size: style.fontSize)
                let ascent = vertical.ascent, lineHeight = vertical.height
                // Segment control characters before shaping: tabs are paragraph geometry.
                var segment = ""
                func appendSegment() {
                    guard !segment.isEmpty else { return }
                    // ASCII fallback text has one scalar per grapheme and only
                    // space/hyphen break opportunities after control splitting.
                    // Keep the same atom arithmetic without rescanning it through
                    // the Unicode breaker and materializing an offset set.
                    if metrics == nil, segment.utf8.allSatisfy({ $0 < 128 }) {
                        for byte in segment.utf8 {
                            let value = String(Unicode.Scalar(byte))
                            atoms.append(Atom(text: value, style: style,
                                width: style.fontSize * (byte == 32 ? 0.25 : 0.42) + style.tracking,
                                ascent: ascent, height: lineHeight, drawingML: vertical.drawingML,
                                source: source, breakAfter: byte == 32 || byte == 45))
                        }
                        segment = ""
                        return
                    }
                    let breaks = Set(TextShaper.lineBreaks(in: segment).map(\.scalarOffset))
                    if let metrics {
                        let shaped = TextShaper(metrics).shape(segment, pointSize: style.fontSize, kerning: style.usesKerning)
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
                                ascent: ascent, height: lineHeight, drawingML: vertical.drawingML,
                                source: source, breakAfter: breaks.contains(range.upperBound)))
                        }
                    } else {
                        var scalarOffset = 0
                        for character in segment {
                            let value = String(character); scalarOffset += value.unicodeScalars.count
                            atoms.append(Atom(text: value, style: style,
                                width: style.fontSize * (character == " " ? 0.25 : 0.42) + style.tracking,
                                ascent: ascent, height: lineHeight, drawingML: vertical.drawingML,
                                source: source, breakAfter: breaks.contains(scalarOffset)))
                        }
                    }
                    segment = ""
                }
                for character in text {
                    if character == "\t" || character == "\n" || character == "\r" || character == "\r\n" {
                        appendSegment()
                        atoms.append(Atom(text: character == "\t" ? "\t" : "", style: style,
                            width: 0, ascent: ascent, height: lineHeight, drawingML: vertical.drawingML, source: source,
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
            // These properties belong to the paragraph, not each wrapped line.
            // Preserve the arithmetic order for percentage spacing so repeated
            // lines remain byte-identical when their coordinates are serialized.
            let declaredSpacing = child("a:lnSpc")
            let fixedSpacing = declaredSpacing?.firstChild(named: "a:spcPts").map {
                Self.bounded(Self.number($0, "val", 0), 0...1e8) / 100
            }
            let percentageSpacing = declaredSpacing?.firstChild(named: "a:spcPct").map {
                Self.bounded(Self.number($0, "val", 0), 0...1e7)
            }
            let defaultSpacing = Self.bounded(lineSpacing, 0...100)
            let align = attribute("algn") ?? "l"
            var lineAtoms: [Atom] = [], lineWidth = 0.0, firstLine = true, index = 0
            func startX() -> Double {
                left + (bullet != nil ? max(0, indent + bulletAdvance) : (firstLine ? indent : 0))
            }
            func limit() -> Double { max(0, availableWidth - right - startX()) }
            // Word-space justification is verified for left-to-right Latin text.
            // Other scripts may require inter-character spacing or kashidas.
            var canJustify = align == "just"
            if !["l", "ctr", "r", "just"].contains(align) {
                warnings.append(.unsupportedLayoutFeature("Paragraph alignment '\(align)' is not implemented; using left alignment"))
            }
            if canJustify {
                if ["1", "true"].contains(attribute("rtl") ?? "0") {
                    warnings.append(.unsupportedLayoutFeature("Justification of RTL paragraphs is not verified; using left alignment"))
                    canJustify = false
                }
                if atoms.contains(where: \.tab) {
                    warnings.append(.unsupportedLayoutFeature("Justification with tabs is not verified; using left alignment"))
                    canJustify = false
                }
                if atoms.contains(where: { atom in
                    atom.text.unicodeScalars.contains { scalar in
                        let value = scalar.value
                        return !(value <= 0x024F || (0x0300...0x036F).contains(value)
                            || ((0x2000...0x206F).contains(value)
                                && !(0x202A...0x202E).contains(value)
                                && !(0x2066...0x2069).contains(value)
                                && value != 0x200F))
                    }
                }) {
                    warnings.append(.unsupportedLayoutFeature("Justification outside left-to-right Latin text is not verified; using left alignment"))
                    canJustify = false
                }
            }
            func emit(justify: Bool = false) {
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
                        let exact = TextShaper(font).shape(value, pointSize: style.fontSize, kerning: style.usesKerning).width
                            + Double(value.count) * style.tracking
                        let adjustment = exact - fragment.reduce(0) { $0 + $1.width }
                        lineAtoms[end - 1].width += adjustment; lineWidth += adjustment
                    }
                    fragmentStart = end
                }
                // Only interior word spaces receive the remaining width. Keep
                // edge spaces in the text, but exclude trailing whitespace from
                // the visible right edge, just as the overflow test does.
                var expandedSpaces: Set<Int> = []
                if canJustify && justify,
                   let first = lineAtoms.firstIndex(where: { $0.text != " " }),
                   let last = lineAtoms.lastIndex(where: { $0.text != " " }), first < last {
                    let trailing = lineAtoms[(last + 1)...].reduce(0) { $0 + $1.width }
                    let remaining = max(0, limit() - (lineWidth - trailing))
                    if remaining > 0 {
                        for i in first..<last where lineAtoms[i].text == " " { expandedSpaces.insert(i) }
                        if !expandedSpaces.isEmpty {
                            let added = remaining / Double(expandedSpaces.count)
                            for i in expandedSpaces { lineAtoms[i].width += added }
                            lineWidth += remaining
                        }
                    }
                }
                let naturalHeight = lineAtoms.lazy.map(\.height).max() ?? emptyHeight
                let drawingML = lineAtoms.isEmpty ? empty.drawingML : lineAtoms.allSatisfy(\.drawingML)
                let ascent: Double
                if drawingML, !lineAtoms.isEmpty {
                    // Share the line box between the participating faces. Sizes
                    // determine the box height; each face supplies its normalized
                    // ascent/descent, rather than bringing its hhea line gap.
                    let above = lineAtoms.lazy.map { $0.ascent / $0.height }.max() ?? 0
                    let below = lineAtoms.lazy.map { 1 - $0.ascent / $0.height }.max() ?? 0
                    ascent = naturalHeight * above / (above + below)
                } else {
                    ascent = lineAtoms.lazy.map(\.ascent).max() ?? emptyAscent
                }
                let spacingAdvance: Double
                if let fixedSpacing { spacingAdvance = fixedSpacing }
                else if let percentageSpacing { spacingAdvance = naturalHeight * percentageSpacing / 100000 }
                else { spacingAdvance = declaredSpacing == nil ? naturalHeight * defaultSpacing : 0 }
                let advance = spacingAdvance * (1 - reduction)
                let extra = align == "ctr" ? (limit() - lineWidth) / 2 : align == "r" ? limit() - lineWidth : 0
                var spans: [RichTextSpan] = [], x = margins.0 + startX() + max(0, extra)
                if firstLine, var run = bullet {
                    run.text += " "
                    let width = face(run)?.width(of: run.text, pointSize: run.fontSize) ?? Double(run.text.count) * run.fontSize * 0.42
                    spans.append(RichTextSpan(run: run, x: margins.0 + left + indent, width: width))
                }
                var previousSource: Int?
                for (atomIndex, atom) in lineAtoms.enumerated() {
                    if atom.tab { x += atom.width; previousSource = nil; continue }
                    // Isolate expanded spaces so SVG's textLength never scales
                    // the letters of a justified word along with its whitespace.
                    let expanded = expandedSpaces.contains(atomIndex)
                    if previousSource == atom.source, !spans.isEmpty, !expanded {
                        spans[spans.count - 1].run.text += atom.text
                        spans[spans.count - 1].width += atom.width
                    } else {
                        var run = atom.style; run.text = atom.text
                        spans.append(RichTextSpan(run: run, x: x, width: atom.width))
                    }
                    previousSource = expanded ? nil : atom.source; x += atom.width
                }
                let trailingSpace = lineAtoms.reversed().prefix(while: { $0.text == " " }).reduce(0) { $0 + $1.width }
                overflowWidth = overflowWidth || lineWidth - trailingSpace > limit() + 0.01
                // PowerPoint's content-relative baseline is rounded after the
                // unrounded line advances accumulate. Rounding the ascent first
                // gives incorrect mixed-size and repeated-line spacing. This is
                // point geometry, independent of SVG pixel size or rasterizer.
                let baseline = drawingML ? (cursor + ascent).rounded() : cursor + ascent
                if drawingML {
                    // Rounding and reduced/exact line spacing can place the last
                    // descent beyond the flow advance. Fitting must include that
                    // extent, without feeding it back into subsequent line pitch.
                    measuredBottom = max(measuredBottom, baseline + naturalHeight - ascent)
                }
                output.append(RichTextLine(spans: spans, baseline: baseline,
                                           height: advance, width: lineWidth))
                cursor += advance; lineAtoms = []; lineWidth = 0; firstLine = false
            }
            while index < atoms.count {
                if output.count >= lineLimit { didTruncate = true; break }
                var atom = atoms[index]
                if atom.hard {
                    // a:br ends a line, not the paragraph. PowerPoint also
                    // justifies this line; only the final paragraph line is exempt.
                    emit(justify: true); index += 1; continue
                }
                if atom.tab {
                    let position = startX() + lineWidth
                    let stop = tabs.first { $0 > position + 0.001 } ?? (floor(position / defaultTab) + 1) * defaultTab
                    atom.width = max(0, stop - position)
                }
                if wrap && atom.text != " " && !lineAtoms.isEmpty && lineWidth + atom.width > limit() + 0.001 {
                    if let split = lineAtoms.lastIndex(where: \.breakAfter), split + 1 < lineAtoms.count {
                        let carry = Array(lineAtoms[(split + 1)...])
                        lineAtoms.removeSubrange((split + 1)...)
                        lineWidth = lineAtoms.reduce(0) { $0 + $1.width }; emit(justify: true)
                        lineAtoms = carry; lineWidth = carry.reduce(0) { $0 + $1.width }
                    } else { emit(justify: true) }
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
        cursor = max(cursor, measuredBottom)
        let offset: Double
        switch verticalAnchor ?? body?[attribute: "anchor"] {
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
            tracking: bounded(attr("spc").flatMap(Double.init) ?? 0, -400000...400000) / 100 * scale,
            kerningThreshold: bounded(attr("kern").flatMap(Double.init) ?? 0, 0...400000) / 100)
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
