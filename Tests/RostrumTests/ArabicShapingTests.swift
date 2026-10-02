import Foundation
import Testing
@testable import Rostrum

@Suite struct ArabicShapingTests {
    private var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Typography")
    }
    struct Oracle: Decodable { let cases: [TextShaperTests.OracleCase] }
    private func compare(font: URL, oracle: URL) throws {
        let metrics = try FontMetrics(contentsOf: font), shaper = TextShaper(metrics)
        let cases = try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: oracle)).cases
        for expected in cases {
            let run = shaper.shape(expected.text, pointSize: Double(metrics.unitsPerEm), direction: .rightToLeft)
            #expect(run.isSupported == expected.supported, "\(expected.text): \(run.diagnostics)")
            if expected.supported {
                #expect(run.glyphs.map(\.glyphID) == expected.glyphs.map(\.g), "glyphs: \(expected.text)")
                #expect(run.glyphs.map(\.scalarRange.lowerBound) == expected.glyphs.map(\.cl), "clusters: \(expected.text)")
                #expect(run.glyphs.map(\.advance) == expected.glyphs.map { Double($0.ax) }, "advances: \(expected.text)")
                #expect(run.glyphs.map(\.xOffset) == expected.glyphs.map { Double($0.dx) }, "x: \(expected.text)")
                #expect(run.glyphs.map(\.yOffset) == expected.glyphs.map { Double($0.dy) }, "y: \(expected.text)")
            }
            #expect(run == shaper.shape(expected.text, pointSize: Double(metrics.unitsPerEm), direction: .rightToLeft))
        }
    }
    @Test func pinnedArabicFormsLigaturesControlsAndClusters() throws {
        try compare(font: fixture.appendingPathComponent("DejaVuSans.ttf"), oracle: fixture.appendingPathComponent("arabic-harfbuzz-14.4.0.json"))
    }
    @Test func chainedContextFormatsAndNestedExtensionMatchHarfBuzz() throws {
        try compare(font: fixture.appendingPathComponent("ArabicContexts.ttf"), oracle: fixture.appendingPathComponent("arabic-contexts-harfbuzz-14.4.0.json"))
    }
    @Test func suppliedLocalArabicOracle() throws {
        guard let path = ProcessInfo.processInfo.environment["ROSTRUM_ARABIC_ORACLE"],
              let font = ProcessInfo.processInfo.environment["ROSTRUM_ARABIC_FONT"] else { return }
        try compare(font: URL(fileURLWithPath: font), oracle: URL(fileURLWithPath: path))
    }
    @Test func unsupportedGeometryRemainsVisibleToStrictRendering() throws {
        let deck = try Presentation()
        try deck.fonts.register(Data(contentsOf: fixture.appendingPathComponent("DejaVuSans.ttf")), aliases: ["Arabic Oracle"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(1)))
        shape.textFrame!.text = "بَ"
        shape.textFrame!.paragraphs[0].runs[0].fontName = "Arabic Oracle"
        #expect(throws: StrictRenderingError.self) { _ = try deck.renderSVG(slideAt: 0, strictRendering: true) }
        shape.textFrame!.text = "سلام"
        shape.textFrame!.paragraphs[0].runs[0].fontName = "Arabic Oracle"
        #expect(throws: StrictRenderingError.self) { _ = try deck.renderSVG(slideAt: 0, strictRendering: true) }
        let run = TextShaper(try FontMetrics(contentsOf: fixture.appendingPathComponent("DejaVuSans.ttf"))).shape("بَ", pointSize: 2048)
        #expect(run.diagnostics.contains(.unsupportedLayoutFeature("Arabic mark attachment positioning is unsupported")))
        let oracle = try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: fixture.appendingPathComponent("arabic-harfbuzz-14.4.0.json")))
        let reference = try #require(oracle.cases.first { $0.text == "بَ" })
        #expect(run.glyphs.map(\.xOffset) != reference.glyphs.map { Double($0.dx) })
        #expect(run.glyphs.map(\.yOffset) != reference.glyphs.map { Double($0.dy) })
    }
    private func contextTables() throws -> [String: [UInt8]] {
        let r = SFNTReader(bytes: Array(try Data(contentsOf: fixture.appendingPathComponent("ArabicContexts.ttf"))))
        var tables: [String: [UInt8]] = [:]
        for i in 0..<(try r.u16(4)) {
            let p = 12 + 16 * i, offset = try r.u32(p + 8), count = try r.u32(p + 12)
            tables[try r.tag(p)] = Array(r.bytes[offset..<(offset + count)])
        }
        return tables
    }
    private func contextFont(_ tables: [String: [UInt8]]) throws -> TextShaper {
        TextShaper(try FontMetrics(data: Data(TestFont.assemble(tables: tables.keys.sorted().map { ($0, tables[$0]!) }))))
    }
    private func firstContextRecord(_ bytes: [UInt8]) throws -> Int {
        let r = SFNTReader(bytes: bytes), list = try r.u16(8)
        let lookup = list + (try r.u16(list + 2)), sub = lookup + (try r.u16(lookup + 6))
        let set = sub + (try r.u16(sub + 6))
        var p = set + (try r.u16(set + 2))
        p += 2 + 2 * (try r.u16(p))
        p += 2 * (try r.u16(p)) // input count includes the first glyph
        p += 2 + 2 * (try r.u16(p))
        return p + 2 // first SequenceLookupRecord
    }
    @Test func truncatedContextProgramsAndInvalidReferencesRefuseBoundedly() throws {
        let tables = try contextTables(), gsub = try #require(tables["GSUB"])
        for cut in 0..<gsub.count {
            let parsed = ArabicLayoutTables(bytes: Array(gsub.prefix(cut)), definitions: .init())
            #expect(!parsed.diagnostics.isEmpty, "cut \(cut)")
        }
        let record = try firstContextRecord(gsub)
        for position in [record, record + 2] {
            var copy = tables, modified = gsub
            modified.replaceSubrange(position..<(position + 2), with: TestFont.be16(65535))
            copy["GSUB"] = modified
            let shaper = try contextFont(copy)
            #expect(!shaper.shape("ابتث", pointSize: 1000).isSupported)
            #expect(shaper.metrics.layoutTables.arabic?.lookups.isEmpty == true)
        }
    }
    @Test func cyclicNestedLookupsHitExecutionBudgetWithoutRecursingUnboundedly() throws {
        var tables = try contextTables(), gsub = try #require(tables["GSUB"])
        let record = try firstContextRecord(gsub)
        gsub.replaceSubrange((record + 2)..<(record + 4), with: TestFont.be16(0))
        tables["GSUB"] = gsub
        let shaper = try contextFont(tables), run = shaper.shape("ابتث", pointSize: 1000)
        #expect(run.diagnostics.contains(.unsupportedLayoutFeature("Arabic contextual lookup execution exceeds the bounded profile")))
        #expect(run == shaper.shape("ابتث", pointSize: 1000))
    }
    @Test func invalidReplacementAndCursivePositioningAreDiagnosed() throws {
        var tables = try contextTables(), gsub = try #require(tables["GSUB"])
        let r = SFNTReader(bytes: gsub), list = try r.u16(8)
        let lookup = list + (try r.u16(list + 2 + 2 * 3))
        let sub = lookup + (try r.u16(lookup + 6))
        gsub.replaceSubrange((sub + 6)..<(sub + 8), with: TestFont.be16(65535))
        tables["GSUB"] = gsub
        let run = try contextFont(tables).shape("ابتث", pointSize: 1000)
        #expect(run.diagnostics.contains(.unsupportedLayoutFeature("Arabic substitution references an out-of-range glyph")))
        #expect(run.glyphs.allSatisfy { $0.glyphID < 97 })
        tables = try contextTables()
        var gpos = try #require(tables["GPOS"])
        let features = try SFNTReader(bytes: gpos).u16(6)
        gpos.replaceSubrange((features + 2)..<(features + 6), with: Array("curs".utf8))
        tables["GPOS"] = gpos
        #expect(try contextFont(tables).shape("ابتث", pointSize: 1000).diagnostics.contains(.unsupportedLayoutFeature("Arabic cursive positioning is unsupported")))
    }

    @Test func aliasedContextRulesShareParsingBudget() {
        let u = TestFont.be16
        var bytes = u(1) + u(0) + u(10) + u(30) + u(44)
        bytes += u(1) + Array("arab".utf8) + u(8) + u(4) + u(0) + u(0) + u(65535) + u(1) + u(0)
        bytes += u(1) + Array("ccmp".utf8) + u(8) + u(0) + u(1) + u(0)
        bytes += u(1) + u(4) + u(6) + u(0) + u(1) + u(8)
        bytes += u(1) + u(8) + u(1) + u(14) + u(1) + u(1) + u(2)
        let copies = 1024, backtrack = 1024
        bytes += u(copies)
        for _ in 0..<copies { bytes += u(2 + 2 * copies) }
        bytes += u(backtrack)
        for _ in 0..<backtrack { bytes += u(1) }
        bytes += u(1) + u(0) + u(0)
        let parsed = ArabicLayoutTables(bytes: bytes, definitions: .init())
        #expect(parsed.lookups.isEmpty)
        #expect(parsed.diagnostics == ["Arabic GSUB expansion exceeds the parsing budget"])
    }

    @Test func unsupportedBidiAndMissingArabicProgramAreDiagnosed() throws {
        let shaper = TextShaper(try FontMetrics(contentsOf: fixture.appendingPathComponent("DejaVuSans.ttf")))
        #expect(!shaper.shape("سلام", pointSize: 12, direction: .leftToRight).isSupported)
        #expect(!shaper.shape("سلام abc", pointSize: 12).isSupported)
        #expect(shaper.shape("سلام", pointSize: .nan).diagnostics == [.invalidPointSize])
        #expect(!TextShaper(try FontMetrics(data: TestFont.standard())).shape("سلام", pointSize: 12).isSupported)
    }
}
