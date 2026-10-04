import Foundation

extension FontLayoutTables {
    /// GPOS 4/6 format 1. Store bounded, validated anchor matrices rather than
    /// retaining unchecked font offsets for the shaping loop.
    struct MarkTable: Sendable {
        struct Anchor: Sendable { let x: Int; let y: Int }
        struct Mark: Sendable { let klass: Int; let anchor: Anchor }
        struct UnsupportedAnchor: Error {}
        let kind: Int
        let marks: [Int: Mark]
        let targets: [Int: [Anchor?]]

        static func read(_ r: SFNTReader, _ p: Int, kind: Int,
                         budget: inout Budget) throws -> MarkTable {
            func corrupt() -> RostrumError { .fontCorrupt("invalid GPOS mark attachment") }
            func offset(_ parent: Int, _ field: Int, minimum: Int) throws -> Int {
                let value = try r.u16(field)
                guard value >= minimum, value <= r.count - parent else { throw corrupt() }
                return parent + value
            }
            func anchor(_ p: Int) throws -> Anchor {
                let format = try r.u16(p)
                // Design-unit shaping is unhinted: format 2 uses its explicit
                // coordinates, not its optional hinted contour point. Format 3
                // is usable only when both optional device offsets are absent.
                if format == 2 { _ = try r.u16(p + 6) }
                let plainDevice = format == 3 ? (try r.u16(p + 6) == 0 && r.u16(p + 8) == 0) : false
                guard format == 1 || format == 2 || plainDevice
                else { throw UnsupportedAnchor() }
                return try Anchor(x: r.s16(p + 2), y: r.s16(p + 4))
            }
            guard try r.u16(p) == 1 else { throw corrupt() }
            let markCoverage = try FontLayoutTables.coverage(r, offset(p, p + 2, minimum: 12), budget: &budget, ordered: true)
            let baseCoverage = try FontLayoutTables.coverage(r, offset(p, p + 4, minimum: 12), budget: &budget, ordered: true)
            let classes = try r.u16(p + 6)
            guard classes > 0 else { throw corrupt() }
            let markArray = try offset(p, p + 8, minimum: 12)
            let baseArray = try offset(p, p + 10, minimum: 12)
            let markCount = try r.u16(markArray), baseCount = try r.u16(baseArray)
            guard markCount == markCoverage.count, baseCount == baseCoverage.count else { throw corrupt() }
            try budget.consume(markCount + baseCount * classes)
            guard markArray + 2 + 4 * markCount <= r.count,
                  baseArray + 2 + 2 * baseCount * classes <= r.count else { throw corrupt() }
            var marks: [Int: Mark] = [:], targets: [Int: [Anchor?]] = [:]
            for (glyph, index) in markCoverage.sorted(by: { $0.value < $1.value }) {
                let record = markArray + 2 + 4 * index, klass = try r.u16(record)
                guard klass < classes else { throw corrupt() }
                marks[glyph] = try Mark(klass: klass,
                    anchor: anchor(offset(markArray, record + 2, minimum: 2 + 4 * markCount)))
            }
            for (glyph, index) in baseCoverage.sorted(by: { $0.value < $1.value }) {
                var anchors: [Anchor?] = []
                for klass in 0..<classes {
                    let field = baseArray + 2 + 2 * (index * classes + klass)
                    if try r.u16(field) == 0 { anchors.append(nil) }
                    else { anchors.append(try anchor(offset(baseArray, field, minimum: 2 + 2 * baseCount * classes))) }
                }
                targets[glyph] = anchors
            }
            return MarkTable(kind: kind, marks: marks, targets: targets)
        }
    }
}

/// Attach in logical order and resolve the parent graph only after all lookups.
/// This matters when a font places mkmk before mark in LookupList order.
enum MarkPositioning {
    struct Result { let attached: Set<Int>; let exhausted: Bool }
    static func apply(_ glyphs: inout [ShapedGlyph],
                      lookups: [FontLayoutTables.Lookup<[FontLayoutTables.MarkTable]>],
                      tables: FontLayoutTables, ligatures: Set<Int>, barriers: Set<Int>,
                      rtl: Bool, scale: Double) -> Result {
        var parents = Array<Int?>(repeating: nil, count: glyphs.count)
        var delta = Array(repeating: (x: 0.0, y: 0.0), count: glyphs.count)
        var remaining = max(4096, min(glyphs.count, 512) * 512), exhausted = false
        func spend() -> Bool { remaining -= 1; return remaining >= 0 }
        lookupLoop: for lookup in lookups {
            for i in glyphs.indices {
                guard spend() else { exhausted = true; break lookupLoop }
                let id = glyphs[i].glyphID
                guard tables.isNonspacingMark(id), !barriers.contains(i), !lookup.filter.ignores(id) else { continue }
                for sub in lookup.content {
                    guard spend() else { exhausted = true; break lookupLoop }
                    guard let mark = sub.marks[id] else { continue }
                    var j = i - 1, applied = false
                    while j >= 0 {
                        guard spend() else { exhausted = true; break lookupLoop }
                        // Removed line breaks, bidi runs and join controls are
                        // hard barriers. Mark-to-mark stays in one cluster.
                        guard !barriers.contains(j), glyphs[j].bidiLevel == glyphs[i].bidiLevel,
                              glyphs[j].scalarRange.upperBound >= glyphs[j + 1].scalarRange.lowerBound else { break }
                        let candidate = glyphs[j].glyphID
                        if sub.kind == 4 && tables.isNonspacingMark(candidate) { j -= 1; continue }
                        // A filtered ligature must not make its component mark
                        // attach to an unrelated earlier base in this subset.
                        if ligatures.contains(j) || tables.isLigature(candidate) { break }
                        if lookup.filter.ignores(candidate) { j -= 1; continue }
                        guard !ligatures.contains(j), !tables.isLigature(candidate),
                              sub.kind == 4 || (tables.isNonspacingMark(candidate) && glyphs[j].scalarRange == glyphs[i].scalarRange),
                              let anchors = sub.targets[candidate], let target = anchors[mark.klass] else { break }
                        parents[i] = j; applied = true
                        delta[i] = (Double(target.x - mark.anchor.x) * scale, Double(target.y - mark.anchor.y) * scale)
                        break
                    }
                    if applied { break }
                }
            }
        }
        // Prefix pens avoid repeated scans and account for intervening zero
        // advances in either direction. Parents always precede their children.
        var pens = [0.0]
        for glyph in glyphs { pens.append(pens.last! + glyph.advance) }
        var attached: Set<Int> = []
        for i in glyphs.indices {
            guard let j = parents[i] else { continue }
            glyphs[i].xOffset = glyphs[j].xOffset + delta[i].x
                + (rtl ? pens[i + 1] - pens[j + 1] : pens[j] - pens[i])
            glyphs[i].yOffset = glyphs[j].yOffset + delta[i].y
            if !tables.isNonspacingMark(glyphs[j].glyphID) || attached.contains(j) { attached.insert(i) }
        }
        return Result(attached: attached, exhausted: exhausted)
    }
}
