import Foundation
import Testing
@testable import Rostrum

@Suite struct TextShaperTests {
    private var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography")
    }
    private func shaper() throws -> TextShaper {
        TextShaper(try FontMetrics(contentsOf: fixture.appendingPathComponent("DejaVuSans.ttf")))
    }

    struct OracleCase: Decodable {
        struct Glyph: Decodable { let g: Int; let cl: Int; let dx: Int; let dy: Int; let ax: Int }
        let text: String; let direction: String; let supported: Bool; let glyphs: [Glyph]
    }

    @Test func pinnedHarfBuzzGlyphsAndPositioning() throws {
        let cases = try JSONDecoder().decode([OracleCase].self,
            from: Data(contentsOf: fixture.appendingPathComponent("harfbuzz-14.4.0.json")))
        let shaper = try shaper()
        for oracle in cases {
            let run = shaper.shape(oracle.text, pointSize: 2048,
                direction: oracle.direction == "rtl" ? .rightToLeft : .leftToRight)
            #expect(run.isSupported == oracle.supported, "\(oracle.text): \(run.diagnostics)")
            if oracle.supported {
                #expect(run.glyphs.map(\.glyphID) == oracle.glyphs.map(\.g))
                #expect(run.glyphs.map(\.scalarRange.lowerBound) == oracle.glyphs.map(\.cl))
                #expect(run.glyphs.map(\.advance) == oracle.glyphs.map { Double($0.ax) })
                #expect(run.glyphs.map(\.xOffset) == oracle.glyphs.map { Double($0.dx) })
                #expect(run.glyphs.map(\.yOffset) == oracle.glyphs.map { Double($0.dy) })
            } else {
                #expect(run.glyphs.map(\.glyphID) != oracle.glyphs.map(\.g)
                    || run.glyphs.map(\.xOffset) != oracle.glyphs.map { Double($0.dx) }
                    || run.glyphs.map(\.yOffset) != oracle.glyphs.map { Double($0.dy) })
            }
            #expect(run == shaper.shape(oracle.text, pointSize: 2048,
                direction: oracle.direction == "rtl" ? .rightToLeft : .leftToRight))
        }
    }

    @Test func ligaturesRetainOriginalClustersAndScale() throws {
        let shaper = try shaper()
        let run = shaper.shape("office cafe\u{301}", pointSize: 12)
        #expect(run.glyphs[1].scalarRange == 1..<4)
        #expect(run.glyphs.last?.scalarRange == 10..<12)
        #expect(abs(run.width * 2 - shaper.shape("office cafe\u{301}", pointSize: 24).width) < 0.000001)
        #expect(shaper.shape("AV", pointSize: 12).width < shaper.metrics.width(of: "AV", pointSize: 12))
    }

    @Test func restrictedBidiReordersGlyphsAndPreservesLogicalClusters() throws {
        let shaper = try shaper()
        let mixed = shaper.shape("abc אבג 123", pointSize: 12)
        #expect(mixed.isSupported)
        // UAX #9: L L L WS EN EN EN WS R R R.
        #expect(mixed.glyphs.map(\.scalarRange.lowerBound) == [0, 1, 2, 3, 8, 9, 10, 7, 6, 5, 4])
        let rtl = shaper.shape("אבג abc", pointSize: 12)
        #expect(rtl.isSupported)
        #expect(rtl.glyphs.map(\.scalarRange.lowerBound) == [4, 5, 6, 3, 2, 1, 0])
        #expect(!shaper.shape("אבג (abc)", pointSize: 12).isSupported)
        #expect(!shaper.shape("a\u{2067}b\u{2069}", pointSize: 12).isSupported)
    }

    @Test func unsupportedScriptsAndMarksNeverSilentlyClaimAccuracy() throws {
        let shaper = try shaper()
        for text in ["سلام", "क्षि", "x\u{301}", "👩‍👧", "שָׁ"] {
            #expect(!shaper.shape(text, pointSize: 12).diagnostics.isEmpty)
        }
        #expect(shaper.shape("a", pointSize: .nan).diagnostics == [.invalidPointSize])
        #expect(shaper.shape("a", pointSize: -.infinity).glyphs.isEmpty)
        #expect(shaper.shape("", pointSize: 12).width == 0)
    }

    @Test func breaksRespectGraphemesNonbreakSpacesAndCJKPunctuation() {
        #expect(TextShaper.lineBreaks(in: "a\u{301} b\r\nc").map(\.scalarOffset) == [3, 6])
        #expect(TextShaper.lineBreaks(in: "a\u{301} b\r\nc").map(\.mandatory) == [false, true])
        #expect(TextShaper.lineBreaks(in: "中文（测试）文本").map(\.scalarOffset) == [1, 2, 4, 6, 7, 8])
        #expect(TextShaper.lineBreaks(in: "中\u{A0}文").map(\.scalarOffset) == [3])
        #expect(TextShaper.lineBreaks(in: "a\u{200B}b").map(\.scalarOffset) == [2])
    }

    @Test func malformedLayoutTablesAreBoundedAndDiagnosed() {
        for tag in ["GSUB", "GPOS", "kern"] {
            for count in 0..<40 {
                let layout = FontLayoutTables(tables: [tag: [UInt8](repeating: 255, count: count)])
                #expect(!layout.diagnostics.isEmpty)
            }
        }
    }

    @Test func legacyKerningChangesActualAdvance() throws {
        let advances = [600] + (0x20...0x7E).map(TestFont.advance(forChar:))
        let pair = TestFont.be16(34) + TestFont.be16(55) + TestFont.be16(-80) // A V
        let sub = TestFont.be16(0) + TestFont.be16(20) + TestFont.be16(1)
            + TestFont.be16(1) + TestFont.be16(0) + TestFont.be16(0) + TestFont.be16(0) + pair
        let font = Data(TestFont.assemble(tables: [
            ("head", TestFont.head(upem: 1000)),
            ("hhea", TestFont.hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: 96)),
            ("maxp", TestFont.maxp(numGlyphs: 96)), ("hmtx", TestFont.hmtx(advances: advances)),
            ("cmap", TestFont.cmapFormat4()), ("kern", TestFont.be16(0) + TestFont.be16(1) + sub)
        ]))
        let run = TextShaper(try FontMetrics(data: font)).shape("AV", pointSize: 10)
        #expect(run.isSupported)
        #expect(run.width == 9.2)
    }
}
