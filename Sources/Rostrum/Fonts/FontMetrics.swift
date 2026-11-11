import Foundation

/// Horizontal metrics of a TrueType/OpenType font, parsed from the raw sfnt
/// bytes with no platform text stack — the same zero-dependency posture as the
/// zip and XML layers.
///
/// Reads `head` (units per em), `hhea` (line metrics, metric count), `maxp`
/// (glyph count), `hmtx` (advance widths), `cmap` (character → glyph; formats
/// 4 and 12), and `OS/2` when present (typographic line metrics). Glyph
/// outlines are never touched: this type answers "how wide is this string" and
/// "how tall is a line", which is what honest text layout in a `.pptx` needs.
///
/// Measurement is per-scalar advance summation: kerning, ligatures and
/// complex-script shaping are not applied. That approximation is documented
/// behavior. Use `TextShaper` for supported kerning and ligature layout, and
/// inspect its diagnostics before treating a result as typographically complete.
public struct FontMetrics: Sendable {
    /// Design units per em square (`head`), 16…16384 per the spec.
    public let unitsPerEm: Int
    public let isBold: Bool
    public let isItalic: Bool
    /// `hhea` ascender in font units (positive, above the baseline).
    public let ascender: Int
    /// `hhea` descender in font units (negative, below the baseline).
    public let descender: Int
    /// `hhea` line gap in font units.
    public let lineGap: Int

    /// `OS/2` typographic metrics, present when the font has an OS/2 table.
    /// Used for line height when the font sets USE_TYPO_METRICS (fsSelection
    /// bit 7), matching modern rasterizers.
    let typoMetrics: (ascender: Int, descender: Int, lineGap: Int, useTypo: Bool)?

    /// DrawingML uses the Windows ascent/descent share of a 1.2 em line box.
    /// Keep this separate from the general-purpose hhea/typographic metrics.
    let drawingMLAscentShare: Double?
    /// Windows ascent plus descent in ems, independent of hhea/typo selection.
    let drawingMLWindowsHeight: Double?

    /// Family names from the `name` table (IDs 1 and 16), in table order —
    /// the names a deck's `a:latin@typeface` refers to this font by. Empty
    /// when the font has no parseable name table.
    public let familyNames: [String]

    /// Advance width per glyph id, in font units, resolved to `numGlyphs`
    /// entries (the trailing `hmtx` run repeats the last explicit advance).
    private let advances: [Int]
    var glyphCount: Int { advances.count }
    private let characterMap: CharacterMap
    let layoutTables: FontLayoutTables
    let hasOutlines: Bool

    // MARK: - Loading

    /// Parse metrics from raw font bytes: TrueType (`.ttf`), CFF OpenType
    /// (`.otf` — the metrics tables are identical), or a TrueType collection
    /// (`.ttc`, pick a face with `fontIndex`).
    public init(data: Data, fontIndex: Int = 0) throws {
        try self.init(reader: SFNTReader(bytes: [UInt8](data)), fontIndex: fontIndex)
    }

    /// Parse metrics from a font file on disk.
    public init(contentsOf url: URL, fontIndex: Int = 0) throws {
        try self.init(data: try Data(contentsOf: url), fontIndex: fontIndex)
    }

    /// Extracts a standalone TrueType/OpenType (`sfnt`) font binary for `fontIndex`
    /// when `data` is a TrueType Collection (`ttcf`), or returns `data` unchanged
    /// for standalone `sfnt` binaries at `fontIndex == 0`.
    static func extractStandaloneSFNT(from data: Data, fontIndex: Int) throws -> Data {
        let reader = SFNTReader(bytes: [UInt8](data))
        let signature = try reader.u32(0)
        switch signature {
        case 0x0001_0000, 0x4F54_544F, 0x7472_7565:
            guard fontIndex == 0 else {
                throw RostrumError.fontCorrupt("not a collection; fontIndex must be 0")
            }
            return data
        case 0x7474_6366:
            break
        default:
            throw RostrumError.fontCorrupt("unrecognized sfnt version 0x\(String(signature, radix: 16))")
        }

        let count = try reader.u32(8)
        guard (0..<count).contains(fontIndex) else {
            throw RostrumError.fontCorrupt("collection has \(count) fonts; index \(fontIndex) out of range")
        }
        let directoryOffset = try reader.u32(12 + 4 * fontIndex)
        let sfntVersion = try reader.u32(directoryOffset)
        guard sfntVersion == 0x0001_0000 || sfntVersion == 0x4F54_544F || sfntVersion == 0x7472_7565 else {
            throw RostrumError.fontCorrupt("collection entry is not an sfnt font")
        }
        let numTables = try reader.u16(directoryOffset + 4)
        guard numTables > 0, numTables <= 1024 else {
            throw RostrumError.fontCorrupt("invalid sfnt table count \(numTables)")
        }

        struct TableEntry {
            let tagU32: UInt32
            let offset: Int
            let length: Int
        }
        var entries: [TableEntry] = []
        entries.reserveCapacity(numTables)
        var seenTags: Set<UInt32> = []
        let maxOutputBytes = 64 << 20
        var totalSize = 12 + 16 * numTables

        for i in 0..<numTables {
            let record = directoryOffset + 12 + 16 * i
            let tagU32 = UInt32(try reader.u32(record))
            guard seenTags.insert(tagU32).inserted else {
                throw RostrumError.fontCorrupt("duplicate table tag in collection entry")
            }
            let offset = try reader.u32(record + 8)
            let length = try reader.u32(record + 12)
            guard offset >= 0, length >= 0, offset + length <= reader.count else {
                throw RostrumError.fontCorrupt("collection table extends past end of file")
            }
            let padded = (length + 3) & ~3
            totalSize += padded
            guard totalSize <= maxOutputBytes else {
                throw RostrumError.fontCorrupt("extracted collection font exceeds size budget")
            }
            entries.append(TableEntry(tagU32: tagU32, offset: offset, length: length))
        }

        entries.sort { $0.tagU32 < $1.tagU32 }

        var maxPow2 = 1
        var entrySelector = 0
        while maxPow2 * 2 <= numTables {
            maxPow2 *= 2
            entrySelector += 1
        }
        let searchRange = maxPow2 * 16
        let rangeShift = numTables * 16 - searchRange

        func appendU16(_ out: inout [UInt8], _ value: Int) {
            out.append(UInt8((value >> 8) & 0xFF))
            out.append(UInt8(value & 0xFF))
        }
        func appendU32(_ out: inout [UInt8], _ value: UInt32) {
            out.append(UInt8((value >> 24) & 0xFF))
            out.append(UInt8((value >> 16) & 0xFF))
            out.append(UInt8((value >> 8) & 0xFF))
            out.append(UInt8(value & 0xFF))
        }
        func checksum(_ bytes: ArraySlice<UInt8>) -> UInt32 {
            var sum: UInt32 = 0
            var idx = bytes.startIndex
            while idx < bytes.endIndex {
                let b0 = UInt32(bytes[idx])
                let b1 = idx + 1 < bytes.endIndex ? UInt32(bytes[idx + 1]) : 0
                let b2 = idx + 2 < bytes.endIndex ? UInt32(bytes[idx + 2]) : 0
                let b3 = idx + 3 < bytes.endIndex ? UInt32(bytes[idx + 3]) : 0
                sum &+= (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
                idx += 4
            }
            return sum
        }

        var out: [UInt8] = []
        out.reserveCapacity(totalSize)
        appendU32(&out, UInt32(sfntVersion))
        appendU16(&out, numTables)
        appendU16(&out, searchRange)
        appendU16(&out, entrySelector)
        appendU16(&out, rangeShift)

        // Reserve table directory; fill records as we copy padded table payloads.
        let directoryStart = out.count
        out.append(contentsOf: repeatElement(0, count: 16 * numTables))

        var headOffsetInOut: Int?
        for (i, entry) in entries.enumerated() {
            let tableOutOffset = out.count
            out.append(contentsOf: reader.bytes[entry.offset..<(entry.offset + entry.length)])
            let pad = ((entry.length + 3) & ~3) - entry.length
            if pad > 0 {
                out.append(contentsOf: repeatElement(0, count: pad))
            }
            if entry.tagU32 == 0x6865_6164, entry.length >= 12 { // 'head'
                headOffsetInOut = tableOutOffset
                out[tableOutOffset + 8] = 0
                out[tableOutOffset + 9] = 0
                out[tableOutOffset + 10] = 0
                out[tableOutOffset + 11] = 0
            }
            let sum = checksum(out[tableOutOffset..<out.count])
            let rec = directoryStart + 16 * i
            out[rec] = UInt8((entry.tagU32 >> 24) & 0xFF)
            out[rec + 1] = UInt8((entry.tagU32 >> 16) & 0xFF)
            out[rec + 2] = UInt8((entry.tagU32 >> 8) & 0xFF)
            out[rec + 3] = UInt8(entry.tagU32 & 0xFF)
            out[rec + 4] = UInt8((sum >> 24) & 0xFF)
            out[rec + 5] = UInt8((sum >> 16) & 0xFF)
            out[rec + 6] = UInt8((sum >> 8) & 0xFF)
            out[rec + 7] = UInt8(sum & 0xFF)
            let off32 = UInt32(tableOutOffset)
            out[rec + 8] = UInt8((off32 >> 24) & 0xFF)
            out[rec + 9] = UInt8((off32 >> 16) & 0xFF)
            out[rec + 10] = UInt8((off32 >> 8) & 0xFF)
            out[rec + 11] = UInt8(off32 & 0xFF)
            let len32 = UInt32(entry.length)
            out[rec + 12] = UInt8((len32 >> 24) & 0xFF)
            out[rec + 13] = UInt8((len32 >> 16) & 0xFF)
            out[rec + 14] = UInt8((len32 >> 8) & 0xFF)
            out[rec + 15] = UInt8(len32 & 0xFF)
        }

        if let headPos = headOffsetInOut {
            let adjustment = 0xB1B0_AFBA &- checksum(out[0..<out.count])
            out[headPos + 8] = UInt8((adjustment >> 24) & 0xFF)
            out[headPos + 9] = UInt8((adjustment >> 16) & 0xFF)
            out[headPos + 10] = UInt8((adjustment >> 8) & 0xFF)
            out[headPos + 11] = UInt8(adjustment & 0xFF)
        }

        return Data(out)
    }

    private init(reader: SFNTReader, fontIndex: Int) throws {
        let directoryOffset: Int
        let tag = try reader.u32(0)
        switch tag {
        case 0x7474_6366: // 'ttcf'
            let count = try reader.u32(8)
            guard (0..<count).contains(fontIndex) else {
                throw RostrumError.fontCorrupt(
                    "collection has \(count) fonts; index \(fontIndex) out of range")
            }
            directoryOffset = try reader.u32(12 + 4 * fontIndex)
        case 0x0001_0000, 0x4F54_544F, 0x7472_7565: // TrueType, 'OTTO', 'true'
            guard fontIndex == 0 else {
                throw RostrumError.fontCorrupt("not a collection; fontIndex must be 0")
            }
            directoryOffset = 0
        default:
            throw RostrumError.fontCorrupt(
                "unrecognized sfnt version 0x\(String(tag, radix: 16))")
        }
        if directoryOffset != 0 {
            let version = try reader.u32(directoryOffset)
            guard version == 0x0001_0000 || version == 0x4F54_544F || version == 0x7472_7565 else {
                throw RostrumError.fontCorrupt("collection entry is not an sfnt font")
            }
        }

        // Table directory: tag / checksum / offset / length records. Offsets
        // are from the start of the file (also inside collections).
        let numTables = try reader.u16(directoryOffset + 4)
        var tables: [String: (offset: Int, length: Int)] = [:]
        for i in 0..<numTables {
            let record = directoryOffset + 12 + 16 * i
            let tag = try reader.tag(record)
            let offset = try reader.u32(record + 8)
            let length = try reader.u32(record + 12)
            guard offset >= 0, length >= 0, offset + length <= reader.count else {
                throw RostrumError.fontCorrupt("table \(tag) extends past end of file")
            }
            tables[tag] = (offset, length)
        }
        func require(_ tag: String, atLeast bytes: Int) throws -> Int {
            guard let table = tables[tag] else {
                throw RostrumError.fontCorrupt("required table \(tag) is missing")
            }
            guard table.length >= bytes else {
                throw RostrumError.fontCorrupt("table \(tag) is truncated (\(table.length) bytes)")
            }
            return table.offset
        }

        hasOutlines = (tables["glyf"] != nil && tables["loca"] != nil) || tables["CFF "] != nil || tables["CFF2"] != nil
        let layoutTags: Set<String> = ["kern", "GSUB", "GPOS", "GDEF", "fvar"]
        layoutTables = FontLayoutTables(tables: tables.filter { layoutTags.contains($0.key) }
            .mapValues { Array(reader.bytes[$0.offset..<($0.offset + $0.length)]) })

        let head = try require("head", atLeast: 54)
        let upem = try reader.u16(head + 18)
        guard (16...16384).contains(upem) else {
            throw RostrumError.fontCorrupt("unitsPerEm \(upem) outside 16…16384")
        }
        unitsPerEm = upem
        if let os2 = tables["OS/2"], os2.length >= 64 {
            let selection = try reader.u16(os2.offset + 62)
            isBold = selection & 0x20 != 0
            isItalic = selection & 0x201 != 0 // italic or oblique
        } else {
            let style = try reader.u16(head + 44)
            isBold = style & 1 != 0
            isItalic = style & 2 != 0
        }

        let hhea = try require("hhea", atLeast: 36)
        ascender = try reader.s16(hhea + 4)
        descender = try reader.s16(hhea + 6)
        lineGap = try reader.s16(hhea + 8)
        let numberOfHMetrics = try reader.u16(hhea + 34)
        guard numberOfHMetrics >= 1 else {
            throw RostrumError.fontCorrupt("hhea declares zero horizontal metrics")
        }

        let maxp = try require("maxp", atLeast: 6)
        let numGlyphs = try reader.u16(maxp + 4)
        guard numberOfHMetrics <= numGlyphs else {
            throw RostrumError.fontCorrupt(
                "hhea declares \(numberOfHMetrics) metrics for \(numGlyphs) glyphs")
        }

        let hmtx = try require("hmtx", atLeast: 4 * numberOfHMetrics)
        var advances = [Int]()
        advances.reserveCapacity(numGlyphs)
        for glyph in 0..<numberOfHMetrics {
            advances.append(try reader.u16(hmtx + 4 * glyph))
        }
        if numGlyphs > numberOfHMetrics, let last = advances.last {
            advances.append(contentsOf: repeatElement(last, count: numGlyphs - numberOfHMetrics))
        }
        self.advances = advances

        let cmap = try require("cmap", atLeast: 4)
        characterMap = try CharacterMap(reader: reader, cmapOffset: cmap)

        // Family names — lenient: a malformed name record is skipped, never
        // fatal, because names are a convenience while metrics are the point.
        // Unicode/Windows (UTF-16BE) names come first, and Macintosh records
        // (MacRoman) are decoded only when pure ASCII — where the encodings
        // agree — so `familyNames.first` is always a faithful name, never a
        // mojibake decode of a non-ASCII Mac record.
        var unicodeLegacyNames: [String] = []
        var macLegacyNames: [String] = []
        var unicodeTypographicNames: [String] = []
        var macTypographicNames: [String] = []
        var typographicSubfamilies: [String] = []
        if let name = tables["name"], name.length >= 6 {
            let count = (try? reader.u16(name.offset + 2)) ?? 0
            let storage = name.offset + ((try? reader.u16(name.offset + 4)) ?? 0)
            for i in 0..<count {
                let record = name.offset + 6 + 12 * i
                guard let platform = try? reader.u16(record),
                      let nameID = try? reader.u16(record + 6),
                      let length = try? reader.u16(record + 8),
                      let offset = try? reader.u16(record + 10),
                      nameID == 1 || nameID == 16 || nameID == 17,
                      storage + offset + length <= reader.count else { continue }
                let bytes = Array(reader.bytes[(storage + offset)..<(storage + offset + length)])
                let decoded: String?
                let isUnicode: Bool
                switch platform {
                case 0, 3:
                    decoded = String(bytes: bytes, encoding: .utf16BigEndian)
                    isUnicode = true
                case 1 where bytes.allSatisfy({ $0 <= 0x7F }):
                    decoded = String(bytes: bytes, encoding: .ascii)
                    isUnicode = false
                default:
                    decoded = nil
                    isUnicode = false
                }
                guard let decoded, !decoded.isEmpty else { continue }
                switch (nameID, isUnicode) {
                case (1, true) where !unicodeLegacyNames.contains(decoded):
                    unicodeLegacyNames.append(decoded)
                case (1, false) where !macLegacyNames.contains(decoded):
                    macLegacyNames.append(decoded)
                case (16, true) where !unicodeTypographicNames.contains(decoded):
                    unicodeTypographicNames.append(decoded)
                case (16, false) where !macTypographicNames.contains(decoded):
                    macTypographicNames.append(decoded)
                case (17, _) where !typographicSubfamilies.contains(decoded):
                    typographicSubfamilies.append(decoded)
                default:
                    break
                }
            }
        }
        // A split legacy family (e.g. nameID 1 "Calibri Light", nameID 2 "Regular",
        // nameID 16 "Calibri", nameID 17 "Light") shares the broader typographic
        // family in nameID 16, but its Regular/Italic legacy slots are not the base
        // family's RIBBI Regular/Italic faces. Include nameID 16 only when nameID 17
        // is absent or names a standard 4-face RIBBI subfamily (or when nameID 1 is absent).
        let standardSubfamilies: Set<String> = [
            "regular", "normal", "roman", "book", "plain", "standard",
            "bold", "italic", "oblique", "slanted",
            "bolditalic", "boldoblique", "boldslanted"
        ]
        let includeTypographicFamily = (unicodeLegacyNames.isEmpty && macLegacyNames.isEmpty)
            || typographicSubfamilies.allSatisfy { subfamily in
                let normalized = subfamily.lowercased().filter { !$0.isWhitespace && $0 != "-" }
                return standardSubfamilies.contains(normalized)
            }
        var unicodeNames = unicodeLegacyNames
        var macNames = macLegacyNames
        if includeTypographicFamily {
            for name in unicodeTypographicNames where !unicodeNames.contains(name) {
                unicodeNames.append(name)
            }
            for name in macTypographicNames where !macNames.contains(name) {
                macNames.append(name)
            }
        }
        familyNames = unicodeNames + macNames.filter { !unicodeNames.contains($0) }

        if let os2 = tables["OS/2"], os2.length >= 74 {
            let fsSelection = try reader.u16(os2.offset + 62)
            typoMetrics = (
                ascender: try reader.s16(os2.offset + 68),
                descender: try reader.s16(os2.offset + 70),
                lineGap: try reader.s16(os2.offset + 72),
                useTypo: fsSelection & 0x80 != 0)
        } else {
            typoMetrics = nil
        }
        if let os2 = tables["OS/2"], os2.length >= 78 {
            let ascent = try reader.u16(os2.offset + 74)
            let descent = try reader.u16(os2.offset + 76)
            drawingMLAscentShare = ascent > 0
                ? Double(ascent) / Double(ascent + descent) : nil
            drawingMLWindowsHeight = ascent > 0
                ? Double(ascent + descent) / Double(unitsPerEm) : nil
        } else {
            drawingMLAscentShare = nil
            drawingMLWindowsHeight = nil
        }
    }

    /// Glyph lookup for the explicit registered face; zero means missing.
    public func glyphID(for scalar: Unicode.Scalar) -> Int {
        let glyph = characterMap.glyph(for: Int(scalar.value))
        return advances.indices.contains(glyph) ? glyph : 0
    }

    public func advance(ofGlyph glyphID: Int) -> Int {
        advances.indices.contains(glyphID) ? advances[glyphID] : (advances.first ?? 0)
    }

    // MARK: - Measurement

    /// The advance width of one character in font units. Unmapped characters
    /// measure as `.notdef` (glyph 0), which is what a renderer would draw.
    public func advance(of scalar: Unicode.Scalar) -> Int {
        let glyph = characterMap.glyph(for: Int(scalar.value))
        guard advances.indices.contains(glyph) else { return advances.first ?? 0 }
        return advances[glyph]
    }

    /// The width of `text` at `pointSize`, in points. Per-scalar advance
    /// summation; newlines measure as zero-width (wrap first, then measure).
    public func width(of text: String, pointSize: Double) -> Double {
        var units = 0
        for scalar in text.unicodeScalars where scalar != "\n" {
            units += advance(of: scalar)
        }
        return Double(units) / Double(unitsPerEm) * pointSize
    }

    /// The height of one line at `pointSize`, in points: ascent + descent +
    /// line gap. Uses `OS/2` typographic metrics when the font asks for them
    /// (USE_TYPO_METRICS), else `hhea`.
    public func lineHeight(pointSize: Double) -> Double {
        let (asc, desc, gap): (Int, Int, Int)
        if let typo = typoMetrics, typo.useTypo {
            (asc, desc, gap) = (typo.ascender, typo.descender, typo.lineGap)
        } else {
            (asc, desc, gap) = (ascender, descender, lineGap)
        }
        return Double(asc - desc + gap) / Double(unitsPerEm) * pointSize
    }

    /// Ascent above the baseline at `pointSize`, in points (positive). Uses
    /// the same metric source as `lineHeight` (OS/2 typographic metrics when
    /// the font selects them, else `hhea`), so baseline placement and line
    /// advance always agree.
    public func ascent(pointSize: Double) -> Double {
        let units: Int
        if let typo = typoMetrics, typo.useTypo { units = typo.ascender } else { units = ascender }
        return Double(units) / Double(unitsPerEm) * pointSize
    }

    /// Descent below the baseline at `pointSize`, in points (positive). Same
    /// metric-source rule as `ascent`/`lineHeight`.
    public func descent(pointSize: Double) -> Double {
        let units: Int
        if let typo = typoMetrics, typo.useTypo { units = typo.descender } else { units = descender }
        return Double(-units) / Double(unitsPerEm) * pointSize
    }
}

// MARK: - Character map

/// Character → glyph mapping from the best available `cmap` subtable.
/// Format 12 (full Unicode range) is preferred over format 4 (BMP); Windows
/// platform subtables are preferred over Macintosh/Unicode duplicates.
private enum CharacterMap: Sendable {
    /// Format 4 keeps the raw subtable bytes because the `idRangeOffset`
    /// mechanism addresses glyph ids relative to the offset array itself.
    case format4(sub: [UInt8], segCount: Int,
                 ends: [Int], starts: [Int], deltas: [Int], rangeOffsets: [Int])
    case format12(groups: [(start: Int, end: Int, glyph: Int)])

    init(reader: SFNTReader, cmapOffset: Int) throws {
        let numTables = try reader.u16(cmapOffset + 2)
        var best: (score: Int, offset: Int, format: Int)?
        for i in 0..<numTables {
            let record = cmapOffset + 4 + 8 * i
            let platform = try reader.u16(record)
            let subOffset = cmapOffset + (try reader.u32(record + 4))
            guard subOffset + 2 <= reader.count else { continue }
            let format = try reader.u16(subOffset)
            guard format == 4 || format == 12 else { continue }
            var score = format == 12 ? 4 : 2
            if platform == 3 || platform == 0 { score += 1 }
            if best == nil || score > best!.score {
                best = (score, subOffset, format)
            }
        }
        guard let chosen = best else {
            throw RostrumError.fontCorrupt("no usable cmap subtable (need format 4 or 12)")
        }

        if chosen.format == 12 {
            let numGroups = try reader.u32(chosen.offset + 12)
            // 12 bytes per group; cap sanity-checks the count against the file
            // size before reserving anything.
            guard chosen.offset + 16 + 12 * numGroups <= reader.count else {
                throw RostrumError.fontCorrupt("cmap format 12 group array extends past end of file")
            }
            var groups: [(start: Int, end: Int, glyph: Int)] = []
            groups.reserveCapacity(numGroups)
            for g in 0..<numGroups {
                let base = chosen.offset + 16 + 12 * g
                groups.append((
                    start: try reader.u32(base),
                    end: try reader.u32(base + 4),
                    glyph: try reader.u32(base + 8)))
            }
            self = .format12(groups: groups)
        } else {
            let length = try reader.u16(chosen.offset + 2)
            guard chosen.offset + length <= reader.count else {
                throw RostrumError.fontCorrupt("cmap format 4 subtable extends past end of file")
            }
            let segCount = (try reader.u16(chosen.offset + 6)) / 2
            guard segCount >= 1, 16 + 8 * segCount <= length else {
                throw RostrumError.fontCorrupt("cmap format 4 segment arrays exceed subtable length")
            }
            var ends = [Int](), starts = [Int](), deltas = [Int](), rangeOffsets = [Int]()
            for s in 0..<segCount {
                ends.append(try reader.u16(chosen.offset + 14 + 2 * s))
                starts.append(try reader.u16(chosen.offset + 16 + 2 * segCount + 2 * s))
                deltas.append(try reader.u16(chosen.offset + 16 + 4 * segCount + 2 * s))
                rangeOffsets.append(try reader.u16(chosen.offset + 16 + 6 * segCount + 2 * s))
            }
            let sub = Array(reader.bytes[chosen.offset..<chosen.offset + length])
            self = .format4(sub: sub, segCount: segCount,
                            ends: ends, starts: starts, deltas: deltas, rangeOffsets: rangeOffsets)
        }
    }

    /// The glyph id for a Unicode code point; 0 (`.notdef`) when unmapped.
    func glyph(for codePoint: Int) -> Int {
        switch self {
        case .format12(let groups):
            var lo = 0, hi = groups.count - 1
            while lo <= hi {
                let mid = (lo + hi) / 2
                if codePoint < groups[mid].start {
                    hi = mid - 1
                } else if codePoint > groups[mid].end {
                    lo = mid + 1
                } else {
                    return groups[mid].glyph + (codePoint - groups[mid].start)
                }
            }
            return 0

        case .format4(let sub, let segCount, let ends, let starts, let deltas, let rangeOffsets):
            guard codePoint <= 0xFFFF else { return 0 }
            // First segment whose end >= codePoint (ends are sorted ascending).
            var lo = 0, hi = segCount - 1
            while lo < hi {
                let mid = (lo + hi) / 2
                if ends[mid] < codePoint { lo = mid + 1 } else { hi = mid }
            }
            let seg = lo
            guard ends[seg] >= codePoint, starts[seg] <= codePoint else { return 0 }
            if rangeOffsets[seg] == 0 {
                return (codePoint + deltas[seg]) & 0xFFFF
            }
            // idRangeOffset addresses the glyph id array relative to the
            // offset entry's own position within the subtable.
            let entry = 16 + 6 * segCount + 2 * seg
            let index = entry + rangeOffsets[seg] + 2 * (codePoint - starts[seg])
            guard index + 1 < sub.count else { return 0 }
            let glyph = Int(sub[index]) << 8 | Int(sub[index + 1])
            guard glyph != 0 else { return 0 }
            return (glyph + deltas[seg]) & 0xFFFF
        }
    }
}

// MARK: - Bounds-checked big-endian reads

/// All reads throw on out-of-bounds rather than trapping: font files given to
/// the library are untrusted input, exactly like zip containers.
struct SFNTReader: Sendable {
    let bytes: [UInt8]
    var count: Int { bytes.count }

    func u8(_ offset: Int) throws -> Int {
        guard offset >= 0, offset < bytes.count else {
            throw RostrumError.fontCorrupt("read past end of file at offset \(offset)")
        }
        return Int(bytes[offset])
    }

    func u16(_ offset: Int) throws -> Int {
        (try u8(offset)) << 8 | (try u8(offset + 1))
    }

    /// Signed 16-bit (two's complement).
    func s16(_ offset: Int) throws -> Int {
        let value = try u16(offset)
        return value >= 0x8000 ? value - 0x10000 : value
    }

    func u32(_ offset: Int) throws -> Int {
        (try u16(offset)) << 16 | (try u16(offset + 2))
    }

    /// A 4-byte table tag as ASCII.
    func tag(_ offset: Int) throws -> String {
        let scalars = try (0..<4).map { Unicode.Scalar(UInt8(try u8(offset + $0))) }
        return String(String.UnicodeScalarView(scalars))
    }
}
