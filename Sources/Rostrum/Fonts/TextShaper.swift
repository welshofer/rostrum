import Foundation

/// Foundation-only horizontal shaping for a bounded profile: Latin default
/// `liga` and `kern` (GSUB ligature substitution, GPOS pair adjustment, or legacy
/// kern); NFC-composable graphemes; unpointed Hebrew letters mixed with Latin,
/// spaces and ASCII digits; and basic horizontal CJK break opportunities.
///
/// Arabic joining, Indic reordering, residual combining marks, emoji sequences,
/// bidi controls/bracket mirroring and language-specific features are diagnosed.
/// Neither a platform font fallback nor an implicit font substitution is used.
/// Shape each physical line separately: line breaks are reported, not wrapped.
public struct TextShaper: Sendable {
    public let metrics: FontMetrics
    public init(_ metrics: FontMetrics) { self.metrics = metrics }

    public func shape(_ text: String, pointSize: Double,
                      direction: TextDirection = .automatic) -> ShapedGlyphRun {
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
        for character in text {
            let original = String(character), count = original.unicodeScalars.count
            let range = offset..<(offset + count); offset += count
            let normalized = Array(original.precomposedStringWithCanonicalMapping.unicodeScalars)
            var kind = -1
            for scalar in normalized {
                let value = scalar.value
                if (0x05D0...0x05EA).contains(value) { kind = 1 }
                else if (0x30...0x39).contains(value) { if kind == -1 { kind = 2 } }
                else if Self.isLatin(value) || Self.isCJK(value) { kind = 0 }
                else if value == 0x200E || value == 0x200F || (0x202A...0x202E).contains(value)
                            || (0x2066...0x2069).contains(value) {
                    diagnostics.append(.unsupportedBidirectionalControl(scalar: value))
                } else if !Self.isCommon(value) {
                    diagnostics.append(.unsupportedScript(scalar: value))
                }
            }
            if normalized.count > 1 && original != "\r\n" {
                diagnostics.append(.unsupportedCombiningSequence(scalarRange: range))
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
        for cluster in clusters {
            for scalar in cluster.scalars {
                if [0xA, 0xD, 0x200B].contains(scalar.value) { continue }
                let glyph = metrics.glyphID(for: scalar)
                if glyph == 0 { diagnostics.append(.missingGlyph(scalar: scalar.value)) }
                glyphs.append(ShapedGlyph(glyphID: glyph, scalarRange: cluster.range,
                    advance: Double(metrics.advance(ofGlyph: glyph)) * scale,
                    xOffset: 0, yOffset: 0, bidiLevel: cluster.level))
            }
        }
        for lookup in tables.ligatureLookups {
            var next: [ShapedGlyph] = [], i = 0
            while i < glyphs.count {
                let first = glyphs[i]
                var matched = false
                for ligature in lookup[first.glyphID] ?? [] {
                    let count = ligature.components.count + 1
                    guard i + count <= glyphs.count else { continue }
                    let rest = glyphs[(i + 1)..<(i + count)]
                    guard Array(rest.map(\.glyphID)) == ligature.components,
                          rest.allSatisfy({ $0.bidiLevel == first.bidiLevel }),
                          zip(glyphs[i..<(i + count - 1)], rest).allSatisfy({ $0.scalarRange.upperBound == $1.scalarRange.lowerBound })
                    else { continue }
                    next.append(ShapedGlyph(glyphID: ligature.replacement,
                        scalarRange: first.scalarRange.lowerBound..<glyphs[i + count - 1].scalarRange.upperBound,
                        advance: Double(metrics.advance(ofGlyph: ligature.replacement)) * scale,
                        xOffset: 0, yOffset: 0, bidiLevel: first.bidiLevel))
                    i += count; matched = true; break
                }
                if !matched { next.append(first); i += 1 }
            }
            glyphs = next
        }
        if glyphs.count > 1 {
            for i in 0..<(glyphs.count - 1) {
                guard glyphs[i].bidiLevel == glyphs[i + 1].bidiLevel,
                      glyphs[i].scalarRange.upperBound == glyphs[i + 1].scalarRange.lowerBound else { continue }
                let left = glyphs[i].glyphID, right = glyphs[i + 1].glyphID
                if tables.pairLookups.isEmpty {
                    glyphs[i].advance += Double(tables.legacyPairs[left * 65536 + right] ?? 0) * scale
                } else {
                    for lookup in tables.pairLookups {
                        for subtable in lookup {
                            guard let pair = try? subtable.pair(left, right) else { continue }
                            glyphs[i].advance += Double(pair.first.advance) * scale
                            glyphs[i].xOffset += Double(pair.first.x) * scale
                            glyphs[i].yOffset += Double(pair.first.y) * scale
                            glyphs[i + 1].advance += Double(pair.second.advance) * scale
                            glyphs[i + 1].xOffset += Double(pair.second.x) * scale
                            glyphs[i + 1].yOffset += Double(pair.second.y) * scale
                            break
                        }
                    }
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
        var unique: [ShapingDiagnostic] = []
        for diagnostic in diagnostics where !unique.contains(diagnostic) { unique.append(diagnostic) }
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
