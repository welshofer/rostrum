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
/// behavior, not an accident — it is exact for the metrics-driven layout the
/// library performs and errs by at most a few percent for kerned Latin text.
public struct FontMetrics: Sendable {
    /// Design units per em square (`head`), 16…16384 per the spec.
    public let unitsPerEm: Int
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

    /// Family names from the `name` table (IDs 1 and 16), in table order —
    /// the names a deck's `a:latin@typeface` refers to this font by. Empty
    /// when the font has no parseable name table.
    public let familyNames: [String]

    /// Advance width per glyph id, in font units, resolved to `numGlyphs`
    /// entries (the trailing `hmtx` run repeats the last explicit advance).
    private let advances: [Int]
    private let characterMap: CharacterMap

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

        let head = try require("head", atLeast: 54)
        let upem = try reader.u16(head + 18)
        guard (16...16384).contains(upem) else {
            throw RostrumError.fontCorrupt("unitsPerEm \(upem) outside 16…16384")
        }
        unitsPerEm = upem

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
        var names: [String] = []
        if let name = tables["name"], name.length >= 6 {
            let count = (try? reader.u16(name.offset + 2)) ?? 0
            let storage = name.offset + ((try? reader.u16(name.offset + 4)) ?? 0)
            for i in 0..<count {
                let record = name.offset + 6 + 12 * i
                guard let platform = try? reader.u16(record),
                      let nameID = try? reader.u16(record + 6),
                      let length = try? reader.u16(record + 8),
                      let offset = try? reader.u16(record + 10),
                      nameID == 1 || nameID == 16,
                      storage + offset + length <= reader.count else { continue }
                let bytes = Array(reader.bytes[(storage + offset)..<(storage + offset + length)])
                let decoded: String?
                switch platform {
                case 0, 3: decoded = String(bytes: bytes, encoding: .utf16BigEndian)
                case 1: decoded = String(bytes: bytes, encoding: .isoLatin1)
                default: decoded = nil
                }
                if let decoded, !decoded.isEmpty, !names.contains(decoded) {
                    names.append(decoded)
                }
            }
        }
        familyNames = names

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

    /// Ascent above the baseline at `pointSize`, in points (positive).
    public func ascent(pointSize: Double) -> Double {
        Double(ascender) / Double(unitsPerEm) * pointSize
    }

    /// Descent below the baseline at `pointSize`, in points (positive).
    public func descent(pointSize: Double) -> Double {
        Double(-descender) / Double(unitsPerEm) * pointSize
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
struct SFNTReader {
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
