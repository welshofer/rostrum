import Foundation

/// Default-language Arabic joining and bounded GSUB 1/4/6/7, in logical order
/// until the final RTL reversal. Cursive/ligature attachment and mixed bidi remain
/// diagnosed rather than being implied by contextual-form support.
struct ArabicTextShaper {
    struct Glyph {
        var id: Int
        var range: Range<Int>
        let scalar: UInt32
        var form: String?
        var origins: [Int]
        var x = 0, y = 0, advance = 0
        var ligature = false
        var mark: Bool { Unicode.Scalar(scalar).map { [.nonspacingMark, .spacingMark, .enclosingMark].contains($0.properties.generalCategory) } ?? false }
        var control: Bool { scalar == 0x200C || scalar == 0x200D }
        var boundary: Bool { scalar == 10 || scalar == 13 }
    }
    let metrics: FontMetrics

    func shape(_ text: String, pointSize: Double, direction: TextDirection, kerning: Bool = true) -> ShapedGlyphRun {
        guard pointSize.isFinite, pointSize >= 0 else {
            return ShapedGlyphRun(glyphs: [], breaks: [], diagnostics: [.invalidPointSize], direction: direction)
        }
        let tables = metrics.layoutTables
        var diagnostics = tables.diagnostics.map(ShapingDiagnostic.unsupportedLayoutFeature)
        diagnostics += tables.arabicPositioningDiagnostics.map(ShapingDiagnostic.unsupportedLayoutFeature)
        var glyphs: [Glyph] = [], offset = 0, hasMarks = false, mixed = false
        for character in text {
            let original = String(character), count = original.unicodeScalars.count
            let originalScalars = Array(original.unicodeScalars)
            // OpenType's default Arabic clustering treats ZWNJ as a new
            // cluster even when Swift's extended grapheme also includes the
            // preceding base. Following ZWJ/marks belong to that new cluster.
            let starts = [0] + originalScalars.indices.filter { $0 > 0 && originalScalars[$0].value == 0x200C }
            for segment in starts.indices {
                let first = starts[segment], end = segment + 1 < starts.count ? starts[segment + 1] : count
                let source = (offset + first)..<(offset + end)
                let segmentText = String(String.UnicodeScalarView(originalScalars[first..<end]))
                for scalar in segmentText.precomposedStringWithCanonicalMapping.unicodeScalars {
                    let value = scalar.value, control = value == 0x200C || value == 0x200D
                    let mark = [.nonspacingMark, .spacingMark, .enclosingMark].contains(scalar.properties.generalCategory)
                    if value == 0x200E || value == 0x200F || (0x202A...0x202E).contains(value) || (0x2066...0x2069).contains(value) {
                        diagnostics.append(.unsupportedBidirectionalControl(scalar: value))
                    }
                    if mark { hasMarks = true }
                    if !ArabicJoining.isArabic(value), value != 32, !control, !mark { mixed = true }
                    if ArabicJoining.isArabic(value), scalar.properties.generalCategory != .otherLetter,
                       scalar.properties.generalCategory != .modifierLetter, !mark { mixed = true }
                    let id = metrics.glyphID(for: scalar)
                    if id == 0, !control { diagnostics.append(.missingGlyph(scalar: value)) }
                    glyphs.append(Glyph(id: id, range: source, scalar: value, origins: [glyphs.count]))
                }
            }
            offset += count
        }
        if mixed || direction == .leftToRight {
            diagnostics.append(.unsupportedLayoutFeature("Mixed Arabic paragraph bidi and explicit LTR Arabic shaping are unsupported"))
        }
        let rtl = direction != .leftToRight
        assignForms(&glyphs)
        if let program = tables.arabic, program.hasScript {
            diagnostics += program.diagnostics.map(ShapingDiagnostic.unsupportedLayoutFeature)
            var executor = Executor(program: program, glyphs: glyphs)
            do { try executor.run() }
            catch { diagnostics.append(.unsupportedLayoutFeature("Arabic contextual lookup execution exceeds the bounded profile")) }
            glyphs = executor.glyphs
        } else {
            diagnostics.append(.unsupportedLayoutFeature("Font has no supported Arabic default-language GSUB program"))
        }
        for i in glyphs.indices {
            if glyphs[i].id >= metrics.glyphCount {
                diagnostics.append(.unsupportedLayoutFeature("Arabic substitution references an out-of-range glyph"))
                glyphs[i].id = 0
            }
            glyphs[i].advance = metrics.advance(ofGlyph: glyphs[i].id)
        }
        // Pair positioning uses Arabic's selected kern lookups, not Latin's.
        for lookup in tables.arabicPairs where kerning {
            var i = 0
            while i < glyphs.count {
                if glyphs[i].control || lookup.filter.ignores(glyphs[i].id) { i += 1; continue }
                var j = i + 1
                while j < glyphs.count && lookup.filter.ignores(glyphs[j].id) && !glyphs[j].control { j += 1 }
                guard j < glyphs.count, !glyphs[j].control, !glyphs[j].boundary else { i += 1; continue }
                var next = i + 1
                for table in lookup.content {
                    if let pair = try? table.pair(glyphs[i].id, glyphs[j].id) {
                        glyphs[i].x += pair.first.x; glyphs[i].y += pair.first.y; glyphs[i].advance += pair.first.advance
                        glyphs[j].x += pair.second.x; glyphs[j].y += pair.second.y; glyphs[j].advance += pair.second.advance
                        next = table.value2 == 0 ? j : j + 1
                        break
                    }
                }
                i = next
            }
        }
        let space = metrics.glyphID(for: " ".unicodeScalars.first!)
        for i in glyphs.indices {
            if glyphs[i].control { glyphs[i].id = space; glyphs[i].advance = 0 }
            if tables.isNonspacingMark(glyphs[i].id) { glyphs[i].advance = 0 }
        }
        let scale = pointSize / Double(metrics.unitsPerEm)
        var positioned = glyphs.map {
            ShapedGlyph(glyphID: $0.id, scalarRange: $0.range, advance: Double($0.advance) * scale,
                        xOffset: Double($0.x) * scale, yOffset: Double($0.y) * scale, bidiLevel: rtl ? 1 : 0)
        }
        if hasMarks {
            diagnostics += tables.arabicMarkDiagnostics.map(ShapingDiagnostic.unsupportedLayoutFeature)
            let result = MarkPositioning.apply(&positioned, lookups: tables.arabicMarks, tables: tables,
                ligatures: Set(glyphs.indices.filter { glyphs[$0].ligature }),
                barriers: Set(glyphs.indices.filter { glyphs[$0].control || glyphs[$0].boundary }), rtl: rtl, scale: scale)
            if result.exhausted { diagnostics.append(.unsupportedLayoutFeature("Mark attachment execution exceeds the bounded profile")) }
            if glyphs.indices.contains(where: { glyphs[$0].mark && !result.attached.contains($0) }) {
                diagnostics.append(.unsupportedLayoutFeature("Arabic mark attachment positioning is unsupported for unattached marks or ligature components"))
            }
        }
        positioned = positioned.enumerated().filter { !glyphs[$0.offset].boundary }.map(\.element)
        if rtl { positioned.reverse() }
        var seen: Set<ShapingDiagnostic> = []
        let unique = diagnostics.filter { seen.insert($0).inserted }
        return ShapedGlyphRun(glyphs: positioned, breaks: TextShaper.lineBreaks(in: text), diagnostics: unique, direction: rtl ? .rightToLeft : .leftToRight)
    }

    private func assignForms(_ glyphs: inout [Glyph]) {
        let kinds = glyphs.map { ArabicJoining.kind($0.scalar) }
        var previous: Int?
        for i in glyphs.indices {
            guard kinds[i] != .T else { continue }
            glyphs[i].form = "isol"
            if let previous,
               [.D, .L, .C].contains(kinds[previous]), [.D, .R, .C].contains(kinds[i]) {
                glyphs[previous].form = glyphs[previous].form == "fina" ? "medi" : "init"
                glyphs[i].form = "fina"
            }
            previous = i
        }
    }

    struct Executor {
        let program: ArabicLayoutTables
        var glyphs: [Glyph]
        var remaining: Int
        init(program: ArabicLayoutTables, glyphs: [Glyph]) {
            self.program = program; self.glyphs = glyphs
            remaining = max(4096, min(glyphs.count, 512) * 512)
        }
        struct Limit: Error {}
        mutating func spend(_ count: Int = 1) throws {
            guard count >= 0, count <= remaining else { throw Limit() }
            remaining -= count
        }
        mutating func run() throws {
            for stage in program.stages {
                for lookup in stage.lookups {
                    var i = 0
                    while i < glyphs.count {
                        try spend()
                        if ["isol", "fina", "medi", "init"].contains(stage.feature), glyphs[i].form != stage.feature { i += 1; continue }
                        let next = try apply(lookup, at: i, depth: 0)
                        i = next ?? (i + 1)
                    }
                }
            }
        }
        mutating func next(from index: Int, direction: Int, filter: FontLayoutTables.Filter) throws -> Int? {
            var p = index + direction
            while glyphs.indices.contains(p) {
                try spend()
                if glyphs[p].boundary { return nil }
                // Join controls affect joining forms but deliberately separate
                // ligature/context matching; they are hidden only after GSUB.
                if glyphs[p].control || !filter.ignores(glyphs[p].id) { return p }
                p += direction
            }
            return nil
        }
        mutating func locate(_ origin: Int) throws -> Int? {
            for i in glyphs.indices {
                try spend(glyphs[i].origins.count)
                if glyphs[i].origins.first == origin { return i }
            }
            return nil
        }
        mutating func apply(_ index: Int, at position: Int, depth: Int) throws -> Int? {
            try spend()
            guard depth < 16 else { throw Limit() }
            guard glyphs.indices.contains(position), let lookup = program.lookups[index],
                  !glyphs[position].control, !lookup.filter.ignores(glyphs[position].id) else { return nil }
            for subtable in lookup.subtables {
                try spend()
                switch subtable {
                case .single(let replacements):
                    if let replacement = replacements[glyphs[position].id] {
                        glyphs[position].id = replacement; return position + 1
                    }
                case .ligatures(let sets):
                    for ligature in sets[glyphs[position].id] ?? [] {
                        var positions = [position], cursor = position
                        for component in ligature.components {
                            guard let p = try next(from: cursor, direction: 1, filter: lookup.filter),
                                  !glyphs[p].control, glyphs[p].id == component else { break }
                            positions.append(p); cursor = p
                        }
                        guard positions.count == ligature.components.count + 1 else { continue }
                        let last = positions.last!, first = glyphs[position]
                        let range = first.range.lowerBound..<glyphs[last].range.upperBound
                        try spend(last - position + 1)
                        let origins = positions.flatMap { glyphs[$0].origins }
                        var replacement = first
                        replacement.id = ligature.replacement; replacement.range = range; replacement.origins = origins
                        replacement.ligature = positions.count > 1 && positions.contains { !glyphs[$0].mark }
                        let consumed = Set(positions)
                        var output = [replacement]
                        if last > position {
                            for p in (position + 1)...last where !consumed.contains(p) {
                                var skipped = glyphs[p]; skipped.range = range; output.append(skipped)
                            }
                        }
                        glyphs.replaceSubrange(position...last, with: output)
                        return position + output.count
                    }
                case .context(let context):
                    guard let covered = context.coverage[glyphs[position].id] else { continue }
                    let key = context.coverages != nil ? 0 : context.inputClasses.map { $0[glyphs[position].id] ?? 0 } ?? covered
                    for rule in context.sets[key] ?? [] {
                        var positions = [position], cursor = position, matches = true
                        let inputCount = context.coverages.map { $0.input.count - 1 } ?? rule.input.count
                        for i in 0..<inputCount {
                            guard let p = try next(from: cursor, direction: 1, filter: lookup.filter), !glyphs[p].control else { matches = false; break }
                            let value = context.inputClasses.map { $0[glyphs[p].id] ?? 0 } ?? glyphs[p].id
                            if !(context.coverages.map { $0.input[i + 1].contains(glyphs[p].id) } ?? (value == rule.input[i])) { matches = false; break }
                            positions.append(p); cursor = p
                        }
                        guard matches else { continue }
                        for back in [true, false] {
                            cursor = back ? position : positions.last!
                            let count = context.coverages.map { back ? $0.back.count : $0.look.count } ?? (back ? rule.backtrack.count : rule.lookahead.count)
                            for i in 0..<count {
                                guard let p = try next(from: cursor, direction: back ? -1 : 1, filter: lookup.filter), !glyphs[p].control else { matches = false; break }
                                let classes = back ? context.backClasses : context.lookClasses
                                let value = classes.map { $0[glyphs[p].id] ?? 0 } ?? glyphs[p].id
                                let accepted = context.coverages.map { (back ? $0.back[i] : $0.look[i]).contains(glyphs[p].id) }
                                    ?? (value == (back ? rule.backtrack[i] : rule.lookahead[i]))
                                if !accepted { matches = false; break }
                                cursor = p
                            }
                            if !matches { break }
                        }
                        guard matches else { continue }
                        var origins = positions.map { glyphs[$0].origins[0] }
                        for record in rule.records {
                            // Sequence indices address the current input sequence:
                            // earlier ligatures remove consumed component slots.
                            guard record.sequence < origins.count,
                                  let target = try locate(origins[record.sequence]) else { continue }
                            _ = try apply(record.lookup, at: target, depth: depth + 1)
                            var surviving: [Int] = []
                            for origin in origins where try locate(origin) != nil { surviving.append(origin) }
                            origins = surviving
                        }
                        if let last = origins.last, let end = try locate(last) { return end + 1 }
                        return position + 1
                    }
                }
            }
            return nil
        }
    }
}
