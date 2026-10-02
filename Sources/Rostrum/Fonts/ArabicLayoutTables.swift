import Foundation

/// Owned, bounded Arabic GSUB program. Parsing and lookup execution have separate
/// budgets; referenced contextual lookups are parsed by a worklist, not recursion.
struct ArabicLayoutTables: Sendable {
    typealias Budget = FontLayoutTables.Budget
    struct Record: Sendable { let sequence: Int; let lookup: Int }
    struct Rule: Sendable {
        let backtrack: [Int]
        let input: [Int] // after the first covered glyph
        let lookahead: [Int]
        let records: [Record]
    }
    struct Context: Sendable {
        let coverage: [Int: Int]
        let backClasses: [Int: Int]?
        let inputClasses: [Int: Int]?
        let lookClasses: [Int: Int]?
        let sets: [Int: [Rule]]
        // Format 3 uses coverage sets instead of glyph/class arrays.
        let coverages: (back: [Set<Int>], input: [Set<Int>], look: [Set<Int>])?
    }
    enum Subtable: Sendable {
        case single([Int: Int])
        case ligatures([Int: [FontLayoutTables.Ligature]])
        case context(Context)
    }
    struct Lookup: Sendable { let filter: FontLayoutTables.Filter; let subtables: [Subtable] }
    struct Stage: Sendable { let feature: String; let lookups: [Int] }
    var stages: [Stage] = []
    var lookups: [Int: Lookup] = [:]
    var diagnostics: [String] = []
    var hasScript = false
    private static let order = ["ccmp", "locl", "isol", "fina", "medi", "init", "rlig", "rclt", "calt", "liga", "mset"]

    init(bytes: [UInt8], definitions: FontLayoutTables.GlyphDefinitions) {
        var budget = Budget(bytes: bytes.count)
        do { try parse(SFNTReader(bytes: bytes), definitions: definitions, budget: &budget) }
        catch is FontLayoutTables.BudgetExceeded {
            stages = []; lookups = [:]; diagnostics.append("Arabic GSUB expansion exceeds the parsing budget")
        } catch {
            stages = []; lookups = [:]; diagnostics.append("Malformed or unsupported Arabic GSUB table")
        }
    }
    private static func invalid() -> RostrumError { .fontCorrupt("invalid Arabic OpenType layout") }

    private mutating func parse(_ r: SFNTReader, definitions: FontLayoutTables.GlyphDefinitions, budget: inout Budget) throws {
        guard try r.u16(0) == 1 else { throw Self.invalid() }
        let scripts = try r.u16(4), features = try r.u16(6), list = try r.u16(8)
        let scriptCount = try r.u16(scripts)
        try budget.consume(scriptCount)
        var selected: Int?
        for i in 0..<scriptCount {
            let p = scripts + 2 + 6 * i
            if try r.tag(p) == "arab" { selected = scripts + (try r.u16(p + 4)) }
        }
        guard let selected else { return }
        hasScript = true
        let languageOffset = try r.u16(selected)
        guard languageOffset != 0 else { diagnostics.append("Arabic default language system is missing"); return }
        let language = selected + languageOffset
        let required = try r.u16(language + 2), count = try r.u16(language + 4)
        try budget.consume(count + 1)
        var featureIndices = try (0..<count).map { try r.u16(language + 6 + 2 * $0) }
        if required != 65535 { featureIndices.append(required) }
        var featureLookups: [String: Set<Int>] = [:]
        let featureCount = try r.u16(features), lookupCount = try r.u16(list)
        for index in featureIndices {
            guard index < featureCount else { throw Self.invalid() }
            let p = features + 2 + 6 * index, tag = try r.tag(p)
            guard Self.order.contains(tag) else {
                if index == required { diagnostics.append("Unsupported required Arabic feature \(tag)") }
                continue
            }
            let feature = features + (try r.u16(p + 4)), n = try r.u16(feature + 2)
            try budget.consume(n)
            for i in 0..<n { featureLookups[tag, default: []].insert(try r.u16(feature + 4 + 2 * i)) }
        }
        stages = Self.order.compactMap { tag in
            featureLookups[tag].map { Stage(feature: tag, lookups: $0.sorted()) }
        }
        var pending = Array(Set(stages.flatMap(\.lookups))).sorted(), seen: Set<Int> = []
        while let index = pending.popLast() {
            guard seen.insert(index).inserted else { continue }
            try budget.consume(1)
            guard index < lookupCount else { throw Self.invalid() }
            let p = list + (try r.u16(list + 2 + 2 * index))
            let kind = try r.u16(p), flags = try r.u16(p + 2), n = try r.u16(p + 4)
            try budget.consume(n)
            guard flags & 0xE0 == 0 else { diagnostics.append("Unsupported Arabic lookup flags \(flags)"); continue }
            let markSet = flags & 16 != 0 ? try r.u16(p + 6 + 2 * n) : nil
            guard flags & 0xFF1E == 0 || definitions.classes != nil,
                  flags & 0xFF00 == 0 || flags & 0x18 != 0 || definitions.markClasses != nil,
                  markSet == nil || (definitions.markSets != nil && markSet! < definitions.markSets!.count)
            else { diagnostics.append("Arabic lookup flags require valid GDEF data"); continue }
            var subtables: [Subtable] = []
            for j in 0..<n {
                var sub = p + (try r.u16(p + 6 + 2 * j)), type = kind
                if type == 7 {
                    guard try r.u16(sub) == 1 else { throw Self.invalid() }
                    type = try r.u16(sub + 2)
                    sub += try r.u32(sub + 4)
                }
                switch type {
                case 1:
                    let format = try r.u16(sub)
                    let covered = try FontLayoutTables.coverage(r, sub + r.u16(sub + 2), budget: &budget, ordered: true)
                    try budget.consume(covered.count)
                    var replacements: [Int: Int] = [:]
                    if format == 1 {
                        let delta = try r.s16(sub + 4)
                        for glyph in covered.keys { replacements[glyph] = (glyph + delta) & 65535 }
                    } else if format == 2 {
                        let count = try r.u16(sub + 4)
                        guard count == covered.count else { throw Self.invalid() }
                        for (glyph, offset) in covered { replacements[glyph] = try r.u16(sub + 6 + 2 * offset) }
                    } else { throw Self.invalid() }
                    subtables.append(.single(replacements))
                case 4:
                    guard try r.u16(sub) == 1 else { throw Self.invalid() }
                    let covered = try FontLayoutTables.coverage(r, sub + r.u16(sub + 2), budget: &budget, ordered: true)
                    guard try r.u16(sub + 4) == covered.count else { throw Self.invalid() }
                    var ligatures: [Int: [FontLayoutTables.Ligature]] = [:]
                    for (glyph, offset) in covered.sorted(by: { $0.value < $1.value }) {
                        let set = sub + (try r.u16(sub + 6 + 2 * offset)), count = try r.u16(set)
                        try budget.consume(count)
                        for k in 0..<count {
                            let ligature = set + (try r.u16(set + 2 + 2 * k)), n = try r.u16(ligature + 2)
                            guard n >= 1 else { throw Self.invalid() }
                            try budget.consume(n - 1)
                            let components = try (0..<(n - 1)).map { try r.u16(ligature + 4 + 2 * $0) }
                            ligatures[glyph, default: []].append(.init(components: components, replacement: try r.u16(ligature)))
                        }
                    }
                    subtables.append(.ligatures(ligatures))
                case 6:
                    let context = try Self.context(r, sub, budget: &budget)
                    for key in context.sets.keys.sorted() {
                        for rule in context.sets[key] ?? [] { pending.append(contentsOf: rule.records.map(\.lookup)) }
                    }
                    subtables.append(.context(context))
                default: diagnostics.append("Unsupported Arabic GSUB lookup \(type)")
                }
            }
            lookups[index] = Lookup(filter: .init(flags: flags, definitions: definitions, markSet: markSet), subtables: subtables)
        }
    }

    private static func context(_ r: SFNTReader, _ sub: Int, budget: inout Budget) throws -> Context {
        let format = try r.u16(sub)
        func array(_ p: inout Int, budget: inout Budget) throws -> [Int] {
            let count = try r.u16(p); p += 2
            try budget.consume(count)
            let result = try (0..<count).map { try r.u16(p + 2 * $0) }; p += 2 * count
            return result
        }
        func records(_ p: inout Int, inputCount: Int, budget: inout Budget) throws -> [Record] {
            let count = try r.u16(p); p += 2
            try budget.consume(count)
            return try (0..<count).map { i in
                let sequence = try r.u16(p + 4 * i), lookup = try r.u16(p + 4 * i + 2)
                guard sequence < inputCount else { throw invalid() }
                return Record(sequence: sequence, lookup: lookup)
            }
        }
        if format == 3 {
            var p = sub + 2
            func coverages(_ p: inout Int, budget: inout Budget) throws -> [Set<Int>] {
                try array(&p, budget: &budget).map { offset in
                    guard offset != 0 else { throw invalid() }
                    return Set(try FontLayoutTables.coverage(r, sub + offset, budget: &budget, ordered: true).keys)
                }
            }
            let back = try coverages(&p, budget: &budget), input = try coverages(&p, budget: &budget), look = try coverages(&p, budget: &budget)
            guard let first = input.first else { throw invalid() }
            let record = try records(&p, inputCount: input.count, budget: &budget)
            let coverage = Dictionary(uniqueKeysWithValues: first.sorted().enumerated().map { ($0.element, $0.offset) })
            let rule = Rule(backtrack: [], input: [], lookahead: [], records: record)
            return Context(coverage: coverage, backClasses: nil, inputClasses: nil, lookClasses: nil,
                           sets: [0: [rule]], coverages: (back, input, look))
        }
        guard format == 1 || format == 2 else { throw invalid() }
        let coverage = try FontLayoutTables.coverage(r, sub + r.u16(sub + 2), budget: &budget, ordered: true)
        let backClasses = format == 2 ? try FontLayoutTables.classes(r, sub + r.u16(sub + 4), budget: &budget, ordered: true) : nil
        let inputClasses = format == 2 ? try FontLayoutTables.classes(r, sub + r.u16(sub + 6), budget: &budget, ordered: true) : nil
        let lookClasses = format == 2 ? try FontLayoutTables.classes(r, sub + r.u16(sub + 8), budget: &budget, ordered: true) : nil
        let countOffset = sub + (format == 1 ? 4 : 10), count = try r.u16(countOffset)
        try budget.consume(count)
        if format == 1, count != coverage.count { throw invalid() }
        var sets: [Int: [Rule]] = [:]
        for i in 0..<count {
            let relative = try r.u16(countOffset + 2 + 2 * i)
            if relative == 0 { continue }
            let set = sub + relative, ruleCount = try r.u16(set)
            try budget.consume(ruleCount)
            var rules: [Rule] = []
            for j in 0..<ruleCount {
                var p = set + (try r.u16(set + 2 + 2 * j))
                let back = try array(&p, budget: &budget)
                let inputCount = try r.u16(p); p += 2
                guard inputCount > 0 else { throw invalid() }
                try budget.consume(inputCount - 1)
                let input = try (0..<(inputCount - 1)).map { try r.u16(p + 2 * $0) }; p += 2 * input.count
                let look = try array(&p, budget: &budget)
                let record = try records(&p, inputCount: inputCount, budget: &budget)
                rules.append(Rule(backtrack: back, input: input, lookahead: look, records: record))
            }
            sets[i] = rules
        }
        return Context(coverage: coverage, backClasses: backClasses, inputClasses: inputClasses, lookClasses: lookClasses, sets: sets, coverages: nil)
    }
}
