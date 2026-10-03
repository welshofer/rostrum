import Foundation

/// Foundation-only horizontal shaping for a bounded profile: Latin default
/// `liga` and `kern` (GSUB ligature substitution, GPOS pair adjustment, or legacy
/// kern); NFC-composable graphemes; unpointed Hebrew letters mixed with Latin,
/// spaces and ASCII digits; and basic horizontal CJK break opportunities.
///
/// Default-language Arabic joining forms and GSUB single/ligature/chained-context
/// substitutions are also supported in isolated RTL runs. Bounded GPOS base/mark
/// attachment supports residual Latin and Arabic marks. Cursive/ligature attachment,
/// mixed Arabic bidi, Indic reordering, unattached combining marks,
/// emoji sequences and language-specific features remain diagnosed.
/// Neither a platform font fallback nor an implicit font substitution is used.
/// Shape each physical line separately: line breaks are reported, not wrapped.
public struct TextShaper: Sendable {
    public let metrics: FontMetrics
    public init(_ metrics: FontMetrics) { self.metrics = metrics }

    public func shape(_ text: String, pointSize: Double,
                      direction: TextDirection = .automatic) -> ShapedGlyphRun {
        shape(text, pointSize: pointSize, direction: direction, kerning: true)
    }

    /// Disabling kerning suppresses only pair adjustments; substitutions,
    /// joining, bidi and unsupported-feature diagnostics remain unchanged.
    public func shape(_ text: String, pointSize: Double,
                      direction: TextDirection = .automatic, kerning: Bool) -> ShapedGlyphRun {
        if text.unicodeScalars.contains(where: { ArabicJoining.isArabic($0.value) }) {
            return ArabicTextShaper(metrics: metrics).shape(text, pointSize: pointSize, direction: direction, kerning: kerning)
        }
        let tables = metrics.layoutTables
        var diagnostics = tables.diagnostics.map { ShapingDiagnostic.unsupportedLayoutFeature($0) }
        guard pointSize.isFinite, pointSize >= 0 else {
            return ShapedGlyphRun(glyphs: [], breaks: [], diagnostics: [.invalidPointSize], direction: direction)
        }
        let scale = pointSize / Double(metrics.unitsPerEm)
        struct Cluster {
            let range: Range<Int>
            let scalars: [Unicode.Scalar]
            var kind: Int // 0 Latin/CJK, 1 Hebrew, 2 digit, -1 neutral
            var level = 0
        }
        var clusters: [Cluster] = [], offset = 0
        var combining: [Range<Int>] = []
        for character in text {
            let original = String(character), count = original.unicodeScalars.count
            let range = offset..<(offset + count); offset += count
            // ASCII is already NFC, including the CR/LF grapheme. Avoid a
            // Foundation normalization/bridging round trip for these clusters;
            // any non-ASCII scalar still takes the full normalization path.
            let normalized = original.utf8.allSatisfy { $0 < 0x80 }
                ? Array(original.unicodeScalars)
                : Array(original.precomposedStringWithCanonicalMapping.unicodeScalars)
            var kind = -1
            for scalar in normalized {
                let value = scalar.value
                if (0x05D0...0x05EA).contains(value) { kind = 1 }
                else if (0x30...0x39).contains(value) { if kind == -1 { kind = 2 } }
                else if Self.isLatin(value) || Self.isCJK(value) { kind = 0 }
                else if value == 0x200E || value == 0x200F || (0x202A...0x202E).contains(value)
                            || (0x2066...0x2069).contains(value) {
                    diagnostics.append(.unsupportedBidirectionalControl(scalar: value))
                } else if !Self.isCommon(value) && ![.nonspacingMark, .spacingMark, .enclosingMark].contains(scalar.properties.generalCategory) {
                    diagnostics.append(.unsupportedScript(scalar: value))
                }
            }
            if (normalized.count > 1 || normalized.first.map { [.nonspacingMark, .spacingMark, .enclosingMark].contains($0.properties.generalCategory) } == true) && original != "\r\n" {
                combining.append(range)
            }
            clusters.append(Cluster(range: range, scalars: normalized, kind: kind))
        }
        let base: Int
        switch direction {
        case .leftToRight: base = 0
        case .rightToLeft: base = 1
        case .automatic: base = clusters.first(where: { $0.kind == 0 || $0.kind == 1 })?.kind ?? 0
        }
        let resolvedDirection: TextDirection = base == 1 ? .rightToLeft : .leftToRight
        let hasRTL = base == 1 || clusters.contains { $0.kind == 1 }
        if hasRTL {
            for scalar in text.unicodeScalars where !Self.isLatin(scalar.value)
                && !(0x05D0...0x05EA).contains(scalar.value) && !(0x30...0x39).contains(scalar.value)
                && scalar.value != 0x20 {
                diagnostics.append(.unsupportedBidirectionalControl(scalar: scalar.value))
            }
        }
        // Restricted UAX #9 profile: no embeddings, isolates, marks or brackets.
        // Digits inherit the preceding strong context (EN after L resolves L).
        var precedingStrong = base
        var effective = clusters.map(\.kind)
        for i in clusters.indices {
            if effective[i] == 0 || effective[i] == 1 { precedingStrong = effective[i] }
            else if effective[i] == 2 { effective[i] = precedingStrong == 0 ? 0 : 2 }
        }
        var preceding = Array(repeating: base, count: clusters.count)
        var following = preceding, strong = base
        for i in clusters.indices {
            preceding[i] = strong
            if effective[i] != -1 { strong = effective[i] == 2 ? 1 : effective[i] }
        }
        strong = base
        for i in clusters.indices.reversed() {
            following[i] = strong
            if effective[i] != -1 { strong = effective[i] == 2 ? 1 : effective[i] }
        }
        for i in clusters.indices {
            var kind = effective[i]
            if kind == -1 {
                kind = preceding[i] == following[i] ? preceding[i] : base
            }
            clusters[i].level = kind == 1 ? 1 : (kind == 2 || base == 1 ? 2 : 0)
        }
        // Trailing whitespace has the paragraph embedding level (UAX #9 L1).
        for i in clusters.indices.reversed() {
            guard clusters[i].scalars.allSatisfy({ $0.value == 0x20 }) else { break }
            clusters[i].level = base
        }
        var glyphs: [ShapedGlyph] = []
        var compositionInput: [ArabicTextShaper.Glyph] = []
        for cluster in clusters {
            for scalar in cluster.scalars {
                if [0xA, 0xD, 0x200B].contains(scalar.value) {
                    if !combining.isEmpty {
                        compositionInput.append(.init(id: 0, range: cluster.range, scalar: 10, origins: [compositionInput.count]))
                    }
                    continue
                }
                let glyph = metrics.glyphID(for: scalar)
                if glyph == 0 { diagnostics.append(.missingGlyph(scalar: scalar.value)) }
                if !combining.isEmpty {
                    compositionInput.append(.init(id: glyph, range: cluster.range, scalar: scalar.value, origins: [compositionInput.count]))
                }
                glyphs.append(ShapedGlyph(glyphID: glyph, scalarRange: cluster.range,
                    advance: Double(metrics.advance(ofGlyph: glyph)) * scale,
                    xOffset: 0, yOffset: 0, bidiLevel: cluster.level))
            }
        }
        if !combining.isEmpty, let program = tables.latinComposition {
            diagnostics += program.diagnostics.map(ShapingDiagnostic.unsupportedLayoutFeature)
            // Probe the actual pre-liga sequence. Optional ccmp may compose a
            // non-NFC base/mark, decompose glyphs or select contextual forms;
            // successful attachment alone cannot establish complete shaping.
            var probe = ArabicTextShaper.Executor(program: program, glyphs: compositionInput)
            do {
                try probe.run()
                if probe.glyphs.count != compositionInput.count || zip(probe.glyphs, compositionInput).contains(where: {
                    $0.id != $1.id || $0.range != $1.range || $0.origins != $1.origins || $0.ligature != $1.ligature
                }) {
                    diagnostics.append(.unsupportedLayoutFeature("Latin ccmp changes this residual combining sequence; composition shaping is unsupported"))
                }
            } catch {
                diagnostics.append(.unsupportedLayoutFeature("Latin ccmp checking exceeds the bounded execution profile"))
            }
        }
        // Build successor links once per lookup. Long ignored-mark runs stay
        // linear to scan, and filters never cross line breaks or bidi runs.
        func successors(_ filter: FontLayoutTables.Filter) -> [Int] {
            var links = Array(repeating: glyphs.count, count: glyphs.count)
            guard glyphs.count > 1 else { return links }
            for i in stride(from: glyphs.count - 2, through: 0, by: -1) {
                guard glyphs[i].bidiLevel == glyphs[i + 1].bidiLevel,
                      glyphs[i].scalarRange.upperBound >= glyphs[i + 1].scalarRange.lowerBound else { continue }
                links[i] = filter.ignores(glyphs[i + 1].glyphID) ? links[i + 1] : i + 1
            }
            return links
        }
        for lookup in tables.ligatureLookups {
            let links = successors(lookup.filter)
            var next: [ShapedGlyph] = [], i = 0
            while i < glyphs.count {
                let first = glyphs[i]
                var matched: [Int] = [], replacement: Int?
                if !lookup.filter.ignores(first.glyphID) {
                    for ligature in lookup.content[first.glyphID] ?? [] {
                        var positions = [i], cursor = i
                        for component in ligature.components {
                            cursor = links[cursor]
                            guard cursor < glyphs.count, glyphs[cursor].glyphID == component else { break }
                            positions.append(cursor)
                        }
                        if positions.count == ligature.components.count + 1 {
                            matched = positions; replacement = ligature.replacement; break
                        }
                    }
                }
                if let replacement, let last = matched.last {
                    let range = first.scalarRange.lowerBound..<glyphs[last].scalarRange.upperBound
                    next.append(ShapedGlyph(glyphID: replacement, scalarRange: range,
                        advance: Double(metrics.advance(ofGlyph: replacement)) * scale,
                        xOffset: 0, yOffset: 0, bidiLevel: first.bidiLevel))
                    // Preserve skipped glyphs; their source belongs to the merged
                    // ligature cluster even though they were not substituted.
                    var componentIndex = 1
                    if last > i {
                        for j in (i + 1)...last {
                            if componentIndex < matched.count && matched[componentIndex] == j {
                                componentIndex += 1
                            } else {
                                let skipped = glyphs[j]
                                next.append(ShapedGlyph(glyphID: skipped.glyphID, scalarRange: range,
                                    advance: skipped.advance, xOffset: skipped.xOffset,
                                    yOffset: skipped.yOffset, bidiLevel: skipped.bidiLevel))
                            }
                        }
                    }
                    i = last + 1
                } else { next.append(first); i += 1 }
            }
            glyphs = next
        }
        if kerning && glyphs.count > 1 {
            if tables.pairLookups.isEmpty {
                for i in 0..<(glyphs.count - 1) {
                    guard glyphs[i].bidiLevel == glyphs[i + 1].bidiLevel,
                          glyphs[i].scalarRange.upperBound == glyphs[i + 1].scalarRange.lowerBound else { continue }
                    let key = glyphs[i].glyphID * 65536 + glyphs[i + 1].glyphID
                    glyphs[i].advance += Double(tables.legacyPairs[key] ?? 0) * scale
                }
            } else {
                for lookup in tables.pairLookups {
                    let links = successors(lookup.filter)
                    var i = 0
                    while i < glyphs.count {
                        let j = links[i]
                        guard !lookup.filter.ignores(glyphs[i].glyphID), j < glyphs.count else { i += 1; continue }
                        var nextIndex = i + 1
                        for subtable in lookup.content {
                            guard let pair = try? subtable.pair(glyphs[i].glyphID, glyphs[j].glyphID) else { continue }
                            glyphs[i].advance += Double(pair.first.advance) * scale
                            glyphs[i].xOffset += Double(pair.first.x) * scale
                            glyphs[i].yOffset += Double(pair.first.y) * scale
                            glyphs[j].advance += Double(pair.second.advance) * scale
                            glyphs[j].xOffset += Double(pair.second.x) * scale
                            glyphs[j].yOffset += Double(pair.second.y) * scale
                            // A nonempty second ValueRecord consumes both glyphs;
                            // with valueFormat2 == 0 the second can start a pair.
                            nextIndex = subtable.value2 == 0 ? j : j + 1
                            break
                        }
                        i = nextIndex
                    }
                }
            }
        }
        // GDEF nonspacing marks retain placement adjustments but do not advance
        // the pen, including when a pair ValueRecord supplied an advance.
        for i in glyphs.indices where tables.isNonspacingMark(glyphs[i].glyphID) {
            glyphs[i].advance = 0
        }
        if !combining.isEmpty {
            diagnostics += tables.markDiagnostics.map(ShapingDiagnostic.unsupportedLayoutFeature)
            let originalRanges = Set(clusters.map(\.range))
            let result = MarkPositioning.apply(&glyphs, lookups: tables.markLookups, tables: tables,
                ligatures: Set(glyphs.indices.filter { !originalRanges.contains(glyphs[$0].scalarRange) }),
                barriers: [], rtl: false, scale: scale)
            if result.exhausted { diagnostics.append(.unsupportedLayoutFeature("Mark attachment execution exceeds the bounded profile")) }
            var attachedCounts: [Range<Int>: Int] = [:]
            for index in result.attached { attachedCounts[glyphs[index].scalarRange, default: 0] += 1 }
            let combiningRanges = Set(combining)
            for cluster in clusters where combiningRanges.contains(cluster.range) {
                let safeScalars = cluster.scalars.dropFirst().allSatisfy {
                    [.nonspacingMark, .spacingMark, .enclosingMark].contains($0.properties.generalCategory)
                }
                // Soft-dotted and non-ASCII bases can need Latin ccmp/reordering
                // stages beyond this residual ASCII attachment contract.
                let baseScalar = cluster.scalars.first?.value ?? 0
                let safeBase = ((0x41...0x5A).contains(baseScalar) || (0x61...0x7A).contains(baseScalar))
                    && baseScalar != 0x69 && baseScalar != 0x6A
                if hasRTL || !safeBase || cluster.kind != 0 || !safeScalars || cluster.scalars.count < 2
                    || attachedCounts[cluster.range, default: 0] != cluster.scalars.count - 1 {
                    diagnostics.append(.unsupportedCombiningSequence(scalarRange: cluster.range))
                }
            }
        }
        // Reverse maximal runs at each embedding level, retaining source clusters.
        let maximum = glyphs.map(\.bidiLevel).max() ?? 0
        if maximum > 0 {
            for level in stride(from: maximum, through: 1, by: -1) {
                var i = 0
                while i < glyphs.count {
                    guard glyphs[i].bidiLevel >= level else { i += 1; continue }
                    let start = i
                    while i < glyphs.count && glyphs[i].bidiLevel >= level { i += 1 }
                    glyphs.replaceSubrange(start..<i, with: glyphs[start..<i].reversed())
                }
            }
        }
        var unique: [ShapingDiagnostic] = [], seen: Set<ShapingDiagnostic> = []
        for diagnostic in diagnostics where seen.insert(diagnostic).inserted { unique.append(diagnostic) }
        return ShapedGlyphRun(glyphs: glyphs, breaks: Self.lineBreaks(in: text),
                              diagnostics: unique, direction: resolvedDirection)
    }

    /// Grapheme-safe break opportunities for spaces, hyphens, CR/LF, zero-width
    /// spaces and ideographs with common CJK opening/closing punctuation.
    /// This is a basic horizontal profile, not the complete UAX #14 algorithm.
    public static func lineBreaks(in text: String) -> [TextBreakOpportunity] {
        let characters = Array(text)
        var result: [TextBreakOpportunity] = [], offset = 0
        let opening = "（［｛〈《「『【〔〖〘〚"
        let closing = "）］｝〉》」』】〕〗〙〛、。，．！？：；"
        for i in characters.indices {
            let string = String(characters[i]); offset += string.unicodeScalars.count
            let mandatory = string == "\n" || string == "\r" || string == "\r\n"
            let next = i + 1 < characters.count ? String(characters[i + 1]) : ""
            let cjk = string.unicodeScalars.contains { isCJK($0.value) }
                || next.unicodeScalars.contains { isCJK($0.value) }
            if mandatory || string == " " || string == "-" || string == "\u{200B}"
                || (cjk && !opening.contains(string) && (next.isEmpty || !closing.contains(next))
                    && string != "\u{00A0}" && next != "\u{00A0}" && string != "\u{2060}" && next != "\u{2060}") {
                result.append(TextBreakOpportunity(scalarOffset: offset, mandatory: mandatory))
            }
        }
        return result
    }

    private static func isLatin(_ v: UInt32) -> Bool {
        (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v)
            || (0xC0...0x2AF).contains(v) || (0x1E00...0x1EFF).contains(v)
    }
    private static func isCJK(_ v: UInt32) -> Bool {
        (0x3040...0x30FF).contains(v) || (0x3400...0x4DBF).contains(v)
            || (0x4E00...0x9FFF).contains(v) || (0x20000...0x3134F).contains(v)
    }
    private static func isCommon(_ v: UInt32) -> Bool {
        v < 0x41 || (0x5B...0x60).contains(v) || (0x7B...0xBF).contains(v)
            || (0x2000...0x206F).contains(v) || (0x3000...0x303F).contains(v)
            || (0xFF01...0xFF65).contains(v)
    }
}
