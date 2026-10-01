import Foundation

/// The deliberately bounded OpenType subset used by TextShaper. Each reader is
/// sliced to one table, so offsets cannot escape into unrelated font data.
struct FontLayoutTables: Sendable {
    /// Bound parsing work, including records expanded through aliased offsets.
    /// Ordinary tables get sixteen work units per input byte; the floor permits
    /// small valid tables and the hard ceiling bounds one font's layout table.
    /// Unsupported tables are diagnosed instead of allocating partial graphs.
    private struct Budget {
        static let maximumWork = 262_144
        private var remaining: Int
        init(bytes: Int) {
            remaining = max(4096, min(bytes, Self.maximumWork / 16) * 16)
        }
        mutating func consume(_ count: Int) throws {
            guard count >= 0, count <= remaining else { throw BudgetExceeded() }
            remaining -= count
        }
    }
    private struct BudgetExceeded: Error {}
    struct Ligature: Sendable { let components: [Int]; let replacement: Int }
    struct Adjustment: Sendable {
        var x = 0, y = 0, advance = 0
    }
    struct Pair: Sendable { var first = Adjustment(); var second = Adjustment() }
    struct PairTable: Sendable {
        let reader: SFNTReader
        let offset: Int
        let coverage: [Int: Int]
        let format: Int
        let value1: Int
        let value2: Int
        let classes1: [Int: Int]
        let classes2: [Int: Int]
        let classCount2: Int

        func pair(_ left: Int, _ right: Int) throws -> Pair? {
            guard let index = coverage[left] else { return nil }
            let size1 = value1.nonzeroBitCount * 2, size2 = value2.nonzeroBitCount * 2
            let record: Int
            if format == 1 {
                let set = offset + (try reader.u16(offset + 10 + 2 * index))
                let count = try reader.u16(set)
                var found: Int?
                for i in 0..<count {
                    let p = set + 2 + i * (2 + size1 + size2)
                    if try reader.u16(p) == right { found = p + 2; break }
                }
                guard let found else { return nil }
                record = found
            } else {
                let c1 = classes1[left] ?? 0, c2 = classes2[right] ?? 0
                record = offset + 16 + (c1 * classCount2 + c2) * (size1 + size2)
            }
            return try Pair(first: Self.value(reader, record, value1),
                            second: Self.value(reader, record + size1, value2))
        }

        static func value(_ r: SFNTReader, _ offset: Int, _ format: Int) throws -> Adjustment {
            var result = Adjustment(), p = offset
            for bit in 0..<8 where format & (1 << bit) != 0 {
                let v = try r.s16(p); p += 2
                switch bit {
                case 0: result.x = v
                case 1: result.y = v
                case 2: result.advance = v
                default: break
                }
            }
            return result
        }
    }
    struct GlyphDefinitions: Sendable {
        var classes: [Int: Int]?
        var markClasses: [Int: Int]?
        var markSets: [Set<Int>]?
    }
    struct Filter: Sendable {
        let flags: Int
        let definitions: GlyphDefinitions
        let markSet: Int?

        func ignores(_ glyph: Int) -> Bool {
            switch definitions.classes?[glyph] ?? 0 {
            case 1: return flags & 2 != 0
            case 2: return flags & 4 != 0
            case 3:
                if flags & 8 != 0 { return true }
                if let markSet { return !(definitions.markSets?[markSet].contains(glyph) ?? false) }
                let attachmentClass = flags >> 8
                return attachmentClass != 0 && definitions.markClasses?[glyph] != attachmentClass
            default: return false // Class 0 and component glyphs are never filtered.
            }
        }
    }
    struct Lookup<Content: Sendable>: Sendable {
        let filter: Filter
        let content: Content
    }
    var ligatureLookups: [Lookup<[Int: [Ligature]]>] = []
    var pairLookups: [Lookup<[PairTable]>] = []
    private var definitions = GlyphDefinitions()
    func isNonspacingMark(_ glyph: Int) -> Bool { definitions.classes?[glyph] == 3 }

    var legacyPairs: [Int: Int] = [:]
    var diagnostics: [String] = []

    init(tables: [String: [UInt8]]) {
        if let bytes = tables["GDEF"] {
            var budget = Budget(bytes: bytes.count)
            do { definitions = try Self.readDefinitions(SFNTReader(bytes: bytes), budget: &budget) }
            catch is BudgetExceeded { diagnostics.append("GDEF layout expansion exceeds the parsing budget") }
            catch { diagnostics.append("Malformed or unsupported GDEF table") }
        }
        if let bytes = tables["kern"] {
            var budget = Budget(bytes: bytes.count)
            do { try readKern(SFNTReader(bytes: bytes), budget: &budget) }
            catch is BudgetExceeded {
                legacyPairs = [:]
                diagnostics.append("kern layout expansion exceeds the parsing budget")
            }
            catch { diagnostics.append("Malformed or unsupported kern table") }
        }
        for tag in ["GSUB", "GPOS"] {
            guard let bytes = tables[tag] else { continue }
            var budget = Budget(bytes: bytes.count)
            do { try readLayout(SFNTReader(bytes: bytes), substitution: tag == "GSUB", budget: &budget) }
            catch is BudgetExceeded {
                if tag == "GSUB" { ligatureLookups = [] } else { pairLookups = [] }
                diagnostics.append("\(tag) layout expansion exceeds the parsing budget")
            }
            catch { diagnostics.append("Malformed or unsupported \(tag) Latin layout table") }
        }
        if tables["fvar"] != nil { diagnostics.append("Variable-font shaping is unsupported") }
    }

    /// GDEF 1.0, 1.2 and 1.3 share class definitions; 1.2 adds mark sets.
    /// Attachment points, carets and variation stores are not needed by the
    /// supported lookup types and are not interpreted here.
    private static func readDefinitions(_ r: SFNTReader, budget: inout Budget) throws -> GlyphDefinitions {
        let minor = try r.u16(2)
        guard try r.u16(0) == 1, [0, 2, 3].contains(minor) else { throw corrupt() }
        let headerSize = minor == 0 ? 12 : (minor == 2 ? 14 : 18)
        guard r.count >= headerSize else { throw corrupt() }
        var result = GlyphDefinitions()
        for field in [4, 10] {
            let offset = try r.u16(field)
            if offset != 0 {
                guard offset >= headerSize else { throw corrupt() }
                let values = try classes(r, offset, budget: &budget, ordered: true)
                guard values.values.allSatisfy({ $0 <= (field == 4 ? 4 : 255) }) else { throw corrupt() }
                if field == 4 { result.classes = values } else { result.markClasses = values }
            }
        }
        if minor >= 2 {
            let offset = try r.u16(12)
            if offset != 0 {
                guard offset >= headerSize, try r.u16(offset) == 1 else { throw corrupt() }
                let count = try r.u16(offset + 2)
                try budget.consume(count)
                guard offset + 4 + 4 * count <= r.count else { throw corrupt() }
                var sets: [Set<Int>] = []
                for i in 0..<count {
                    let relative = try r.u32(offset + 4 + 4 * i)
                    guard relative >= 4 + 4 * count, relative <= r.count - offset else { throw corrupt() }
                    sets.append(Set(try coverage(r, offset + relative, budget: &budget, ordered: true).keys))
                }
                result.markSets = sets
            }
        }
        return result
    }

    private mutating func readKern(_ r: SFNTReader, budget: inout Budget) throws {
        guard try r.u16(0) == 0 else { throw corrupt() }
        var p = 4
        let subtableCount = try r.u16(2)
        try budget.consume(subtableCount)
        for _ in 0..<subtableCount {
            let length = try r.u16(p + 2), flags = try r.u16(p + 4)
            guard length >= 6, p + length <= r.count else { throw corrupt() }
            if flags == 1 || flags == 9 { // format 0, horizontal, optional override
                let count = try r.u16(p + 6)
                try budget.consume(count)
                guard 14 + 6 * count <= length else { throw corrupt() }
                for i in 0..<count {
                    let q = p + 14 + 6 * i
                    let key = try r.u16(q) * 65536 + r.u16(q + 2)
                    let value = try r.s16(q + 4)
                    legacyPairs[key] = flags & 8 != 0 ? value : (legacyPairs[key] ?? 0) + value
                }
            } else { diagnostics.append("Unsupported kern subtable flags \(flags)") }
            p += length
        }
    }

    private mutating func readLayout(_ r: SFNTReader, substitution: Bool, budget: inout Budget) throws {
        guard try r.u16(0) == 1 else { throw corrupt() }
        if try r.u16(2) > 0, try r.u32(10) != 0 {
            diagnostics.append("OpenType feature variations are unsupported")
        }
        let scripts = try r.u16(4), features = try r.u16(6), lookups = try r.u16(8)
        var script: Int?, fallback: Int?
        let scriptCount = try r.u16(scripts)
        try budget.consume(scriptCount)
        for i in 0..<scriptCount {
            let p = scripts + 2 + i * 6, tag = try r.tag(p)
            if tag == "latn" { script = scripts + (try r.u16(p + 4)) }
            if tag == "DFLT" { fallback = scripts + (try r.u16(p + 4)) }
        }
        guard let selected = script ?? fallback else { return }
        let languageOffset = try r.u16(selected)
        guard languageOffset != 0 else { return }
        let language = selected + languageOffset
        let required = try r.u16(language + 2)
        let featureIndexCount = try r.u16(language + 4)
        try budget.consume(featureIndexCount + 1)
        var indices = try (0..<featureIndexCount).map { try r.u16(language + 6 + 2 * $0) }
        if required != 0xFFFF { indices.append(required) }
        let featureCount = try r.u16(features)
        var lookupIndices: Set<Int> = []
        for index in indices {
            guard index < featureCount else { throw corrupt() }
            let p = features + 2 + index * 6, tag = try r.tag(p)
            guard tag == (substitution ? "liga" : "kern") else {
                if index == required { diagnostics.append("Unsupported required feature \(tag)") }
                continue
            }
            let feature = features + (try r.u16(p + 4))
            let count = try r.u16(feature + 2)
            try budget.consume(count)
            for i in 0..<count {
                lookupIndices.insert(try r.u16(feature + 4 + i * 2))
            }
        }
        let lookupCount = try r.u16(lookups)
        for index in lookupIndices.sorted() {
            guard index < lookupCount else { throw corrupt() }
            let lookup = lookups + (try r.u16(lookups + 2 + 2 * index))
            let type = try r.u16(lookup), flags = try r.u16(lookup + 2)
            var ligatures: [Int: [Ligature]] = [:], pairs: [PairTable] = []
            let subtableCount = try r.u16(lookup + 4)
            try budget.consume(subtableCount)
            guard flags & 0xE0 == 0 else { diagnostics.append("Unsupported lookup flags \(flags)"); continue }
            let markSet = flags & 0x10 != 0 ? try r.u16(lookup + 6 + 2 * subtableCount) : nil
            // Do not guess Unicode properties when required font classifications
            // are absent. A partial/malformed GDEF never enables filtering.
            guard flags & 0xFF1E == 0 || definitions.classes != nil,
                  flags & 0xFF00 == 0 || flags & 0x18 != 0 || definitions.markClasses != nil,
                  markSet == nil || (definitions.markSets != nil && markSet! < definitions.markSets!.count)
            else { diagnostics.append("Lookup flags \(flags) require valid GDEF classification/filtering data"); continue }
            let filter = Filter(flags: flags, definitions: definitions, markSet: markSet)
            for i in 0..<subtableCount {
                var sub = lookup + (try r.u16(lookup + 6 + 2 * i)), kind = type
                if kind == (substitution ? 7 : 9) {
                    guard try r.u16(sub) == 1 else { throw corrupt() }
                    kind = try r.u16(sub + 2)
                    sub += try r.u32(sub + 4)
                }
                if substitution, kind == 4 {
                    guard try r.u16(sub) == 1 else { throw corrupt() }
                    let coverage = try Self.coverage(r, sub + r.u16(sub + 2), budget: &budget)
                    let setCount = try r.u16(sub + 4)
                    for (glyph, coverageIndex) in coverage.sorted(by: { $0.value < $1.value }) {
                        guard coverageIndex < setCount else { throw corrupt() }
                        let set = sub + (try r.u16(sub + 6 + 2 * coverageIndex))
                        let ligatureCount = try r.u16(set)
                        try budget.consume(ligatureCount)
                        for j in 0..<ligatureCount {
                            let lig = set + (try r.u16(set + 2 + 2 * j))
                            let replacement = try r.u16(lig), count = try r.u16(lig + 2)
                            guard count >= 2 else { throw corrupt() }
                            try budget.consume(count - 1)
                            let components = try (0..<(count - 1)).map { try r.u16(lig + 4 + 2 * $0) }
                            ligatures[glyph, default: []].append(Ligature(components: components, replacement: replacement))
                        }
                    }
                } else if !substitution, kind == 2 {
                    let format = try r.u16(sub), v1 = try r.u16(sub + 4), v2 = try r.u16(sub + 6)
                    // Device/variation offsets and vertical advances need a richer contract.
                    guard (format == 1 || format == 2), (v1 | v2) & ~7 == 0 else { throw corrupt() }
                    let coverage = try Self.coverage(r, sub + r.u16(sub + 2), budget: &budget)
                    var c1: [Int: Int] = [:], c2: [Int: Int] = [:], count2 = 0
                    if format == 2 {
                        c1 = try Self.classes(r, sub + r.u16(sub + 8), budget: &budget)
                        c2 = try Self.classes(r, sub + r.u16(sub + 10), budget: &budget)
                        let count1 = try r.u16(sub + 12); count2 = try r.u16(sub + 14)
                        guard count1 > 0, count2 > 0,
                              c1.values.allSatisfy({ $0 < count1 }), c2.values.allSatisfy({ $0 < count2 }),
                              sub + 16 + count1 * count2 * (v1.nonzeroBitCount + v2.nonzeroBitCount) * 2 <= r.count
                        else { throw corrupt() }
                    } else {
                        let count = try r.u16(sub + 8)
                        try budget.consume(count)
                        guard coverage.values.allSatisfy({ $0 < count }) else { throw corrupt() }
                        for j in 0..<count {
                            let set = sub + (try r.u16(sub + 10 + 2 * j))
                            let pairs = try r.u16(set)
                            try budget.consume(pairs)
                            guard set + 2 + pairs * (2 + 2 * (v1.nonzeroBitCount + v2.nonzeroBitCount)) <= r.count
                            else { throw corrupt() }
                        }
                    }
                    pairs.append(PairTable(reader: r, offset: sub, coverage: coverage, format: format,
                                           value1: v1, value2: v2, classes1: c1, classes2: c2, classCount2: count2))
                } else { diagnostics.append("Unsupported \(substitution ? "GSUB" : "GPOS") lookup \(kind)") }
            }
            if !ligatures.isEmpty { ligatureLookups.append(Lookup(filter: filter, content: ligatures)) }
            if !pairs.isEmpty { pairLookups.append(Lookup(filter: filter, content: pairs)) }
        }
    }

    private static func coverage(_ r: SFNTReader, _ p: Int, budget: inout Budget, ordered: Bool = false) throws -> [Int: Int] {
        let format = try r.u16(p), count = try r.u16(p + 2)
        try budget.consume(count)
        var result: [Int: Int] = [:]
        if format == 1 {
            var previous = -1
            for i in 0..<count {
                let glyph = try r.u16(p + 4 + 2 * i)
                guard !ordered || glyph > previous else { throw corrupt() }
                result[glyph] = i; previous = glyph
            }
        } else if format == 2 {
            var previous = -1
            for i in 0..<count {
                let q = p + 4 + 6 * i, start = try r.u16(q), end = try r.u16(q + 2), index = try r.u16(q + 4)
                guard start <= end, result.count + end - start + 1 <= 65536 else { throw corrupt() }
                try budget.consume(end - start + 1)
                guard !ordered || (start > previous && index == result.count) else { throw corrupt() }
                previous = end
                for glyph in start...end { result[glyph] = index + glyph - start }
            }
        } else { throw corrupt() }
        return result
    }

    private static func classes(_ r: SFNTReader, _ p: Int, budget: inout Budget, ordered: Bool = false) throws -> [Int: Int] {
        let format = try r.u16(p)
        var result: [Int: Int] = [:]
        if format == 1 {
            let start = try r.u16(p + 2), count = try r.u16(p + 4)
            try budget.consume(count)
            guard start + count <= 65536 else { throw corrupt() }
            for i in 0..<count { result[start + i] = try r.u16(p + 6 + 2 * i) }
        } else if format == 2 {
            let count = try r.u16(p + 2)
            try budget.consume(count)
            var previous = -1
            for i in 0..<count {
                let q = p + 4 + 6 * i, start = try r.u16(q), end = try r.u16(q + 2), value = try r.u16(q + 4)
                guard start <= end, result.count + end - start + 1 <= 65536 else { throw corrupt() }
                try budget.consume(end - start + 1)
                guard !ordered || start > previous else { throw corrupt() }
                previous = end
                for glyph in start...end { result[glyph] = value }
            }
        } else { throw corrupt() }
        return result
    }

    private static func corrupt() -> RostrumError { .fontCorrupt("invalid OpenType layout table") }
    private func corrupt() -> RostrumError { Self.corrupt() }
}
