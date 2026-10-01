import Foundation
import Testing
@testable import Rostrum

@Suite struct FontLayoutBudgetTests {
    /// Many coverage glyphs alias one LigatureSet, whose entries alias a single
    /// Ligature. Its byte size is linear while naive expansion is multiplicative.
    private func aliasedLigatures(sets: Int, copies: Int, repeatedRanges: Int = 0) -> [UInt8] {
        let u16 = TestFont.be16
        var bytes = u16(1) + u16(0) + u16(10) + u16(30) + u16(44)
        bytes += u16(1) + Array("latn".utf8) + u16(8)
        bytes += u16(4) + u16(0) + u16(0) + u16(65535) + u16(1) + u16(0)
        bytes += u16(1) + Array("liga".utf8) + u16(8) + u16(0) + u16(1) + u16(0)
        bytes += u16(1) + u16(4) + u16(4) + u16(0) + u16(1) + u16(8)
        let coverage = 6 + 2 * sets
        let coverageSize = repeatedRanges == 0 ? 4 + 2 * sets : 4 + 6 * repeatedRanges
        let set = coverage + coverageSize
        bytes += u16(1) + u16(coverage) + u16(sets)
        for _ in 0..<sets { bytes += u16(set) }
        if repeatedRanges == 0 {
            bytes += u16(1) + u16(sets)
            for glyph in 1...sets { bytes += u16(glyph) }
        } else {
            bytes += u16(2) + u16(repeatedRanges)
            for _ in 0..<repeatedRanges { bytes += u16(1) + u16(sets) + u16(0) }
        }
        bytes += u16(copies)
        for _ in 0..<copies { bytes += u16(2 + 2 * copies) }
        bytes += u16(300) + u16(2) + u16(301)
        return bytes
    }

    @Test func aliasedOffsetsAreRefusedBeforeUnboundedExpansion() {
        let bytes = aliasedLigatures(sets: 256, copies: 256)
        #expect(bytes.count == 1610)
        let parsed = FontLayoutTables(tables: ["GSUB": bytes])
        #expect(parsed.ligatureLookups.isEmpty)
        #expect(parsed.diagnostics.contains("GSUB layout expansion exceeds the parsing budget"))
        #expect(parsed.diagnostics == FontLayoutTables(tables: ["GSUB": bytes]).diagnostics)
    }

    @Test func repeatedCoverageRangesShareTheSameWorkBudget() {
        let bytes = aliasedLigatures(sets: 256, copies: 1, repeatedRanges: 4096)
        let parsed = FontLayoutTables(tables: ["GSUB": bytes])
        #expect(parsed.ligatureLookups.isEmpty)
        #expect(parsed.diagnostics.contains("GSUB layout expansion exceeds the parsing budget"))
    }

    @Test func smallSharedOffsetsRemainSupported() {
        let parsed = FontLayoutTables(tables: ["GSUB": aliasedLigatures(sets: 2, copies: 2)])
        #expect(parsed.diagnostics.isEmpty)
        #expect(parsed.ligatureLookups.flatMap { $0.values }.reduce(0) { $0 + $1.count } == 4)
    }

    @Test func registrationWithOverBudgetLayoutUsesDiagnosedFallback() throws {
        let advances = [600] + (0x20...0x7E).map(TestFont.advance(forChar:))
        let font = Data(TestFont.assemble(tables: [
            ("head", TestFont.head(upem: 1000)),
            ("hhea", TestFont.hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: 96)),
            ("maxp", TestFont.maxp(numGlyphs: 96)), ("hmtx", TestFont.hmtx(advances: advances)),
            ("cmap", TestFont.cmapFormat4()), ("GSUB", aliasedLigatures(sets: 256, copies: 256)),
        ]))
        let fonts = FontLibrary()
        try fonts.register(font, aliases: ["Bounded"])
        let metrics = try #require(fonts.metrics(for: "Bounded"))
        let shaped = TextShaper(metrics).shape("AB", pointSize: 10)
        #expect(shaped.width == metrics.width(of: "AB", pointSize: 10))
        #expect(shaped.diagnostics.contains(.unsupportedLayoutFeature("GSUB layout expansion exceeds the parsing budget")))
        #expect(!shaped.isSupported)
    }
}
