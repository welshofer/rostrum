import Foundation
import Testing
@testable import Rostrum

@Suite struct TextShaperScalarStorageTests {
    private func shaper() throws -> TextShaper {
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        return TextShaper(try FontMetrics(contentsOf: font))
    }

    @Test func normalizedSingletonsSurviveLaterClusterCreation() throws {
        let shaper = try shaper()
        let count = 256
        let run = shaper.shape(String(repeating: "cafe\u{301} ", count: count), pointSize: 2048, kerning: false)
        let ids = [70, 68, 73, 171, 3]
        let advances: [Double] = [1126, 1255, 721, 1260, 651]
        let ranges = [0..<1, 1..<2, 2..<3, 3..<5, 5..<6]
        let expected = (0..<count).flatMap { repetition in
            ids.indices.map { index in
                ShapedGlyph(glyphID: ids[index],
                    scalarRange: (ranges[index].lowerBound + repetition * 6)..<(ranges[index].upperBound + repetition * 6),
                    advance: advances[index], xOffset: 0, yOffset: 0, bidiLevel: 0)
            }
        }
        #expect(run.glyphs == expected)
        #expect(run.diagnostics.isEmpty)
        #expect(run.breaks == (1...count).map { TextBreakOpportunity(scalarOffset: $0 * 6, mandatory: false) })
    }

    @Test func composedSingletonUsesNormalizedCountAndOriginalRange() throws {
        let run = try shaper().shape("e\u{301}", pointSize: 2048)
        #expect(run == ShapedGlyphRun(glyphs: [
            ShapedGlyph(glyphID: 171, scalarRange: 0..<2, advance: 1260, xOffset: 0, yOffset: 0, bidiLevel: 0),
        ], breaks: [], diagnostics: [], direction: .leftToRight))
    }

    @Test func longOwnedClustersKeepTheirFullSourceRanges() throws {
        // NFC composes the first acute with A; the remaining 63 marks remain
        // in an owned decoded array until glyph emission later.
        let cluster = "A" + String(repeating: "\u{301}", count: 64)
        let run = try shaper().shape(cluster + "\r\n" + cluster, pointSize: 12, kerning: false)
        #expect(run.glyphs.count == 128)
        #expect(run.glyphs.prefix(64).allSatisfy { $0.scalarRange == 0..<65 })
        #expect(run.glyphs.suffix(64).allSatisfy { $0.scalarRange == 67..<132 })
        #expect(run.breaks == [TextBreakOpportunity(scalarOffset: 67, mandatory: true)])
        #expect(run.diagnostics.contains(.unsupportedCombiningSequence(scalarRange: 0..<65)))
        #expect(run.diagnostics.contains(.unsupportedCombiningSequence(scalarRange: 67..<132)))
    }
}
