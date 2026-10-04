import Foundation
import Testing
@testable import Rostrum

@Suite struct TextShaperLTRBookkeepingTests {
    private func shaper() throws -> TextShaper {
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        return TextShaper(try FontMetrics(contentsOf: font))
    }

    // Pinned from the pre-optimization shaper at 2048 points / 2048 units per em.
    // These record glyph identity, logical ranges, advances, placement and bidi
    // levels rather than rebuilding the level-resolution algorithm in the test.
    private func expected(_ ids: [Int], _ ranges: [Range<Int>], _ advances: [Double],
                          levels: [Int]? = nil, direction: TextDirection = .leftToRight,
                          breaks: [Int] = [], diagnostics: [ShapingDiagnostic] = []) -> ShapedGlyphRun {
        ShapedGlyphRun(glyphs: ids.indices.map {
            ShapedGlyph(glyphID: ids[$0], scalarRange: ranges[$0], advance: advances[$0],
                xOffset: 0, yOffset: 0, bidiLevel: levels?[$0] ?? 0)
        }, breaks: breaks.map { TextBreakOpportunity(scalarOffset: $0, mandatory: false) },
           diagnostics: diagnostics, direction: direction)
    }

    @Test func leftToRightLigaturesAndNormalizedClustersKeepCompleteRecords() throws {
        let shaper = try shaper()
        #expect(shaper.shape("office ffi AV", pointSize: 2048) == expected(
            [82, 5044, 70, 72, 3, 5044, 3, 36, 57],
            [0..<1, 1..<4, 4..<5, 5..<6, 6..<7, 7..<10, 10..<11, 11..<12, 12..<13],
            [1253, 1980, 1126, 1260, 651, 1980, 651, 1270, 1401], breaks: [7, 11]))
        #expect(shaper.shape("cafe\u{301}", pointSize: 2048) == expected(
            [70, 68, 73, 171], [0..<1, 1..<2, 2..<3, 3..<5], [1126, 1255, 721, 1260]))
        #expect(shaper.shape("A\u{303}\u{300}", pointSize: 2048) == expected(
            [133, 689], [0..<3, 0..<3], [1401, 0], diagnostics: [
                .unsupportedLayoutFeature("Latin ccmp changes this residual combining sequence; composition shaping is unsupported"),
                .unsupportedCombiningSequence(scalarRange: 0..<3),
            ]))
    }

    @Test func explicitRightToLeftAndMixedHebrewRetainLevelsAndVisualOrder() throws {
        let shaper = try shaper()
        #expect(shaper.shape("123 - (456) ", pointSize: 2048, direction: .rightToLeft) == expected(
            [3, 12, 23, 24, 25, 11, 3, 16, 3, 20, 21, 22],
            [11..<12, 10..<11, 7..<8, 8..<9, 9..<10, 6..<7, 5..<6, 4..<5, 3..<4, 0..<1, 1..<2, 2..<3],
            [651, 799, 1303, 1303, 1303, 799, 651, 739, 651, 1303, 1303, 1303],
            levels: [1, 1, 2, 2, 2, 1, 1, 1, 1, 2, 2, 2], direction: .rightToLeft,
            breaks: [4, 5, 6, 12], diagnostics: [
                .unsupportedBidirectionalControl(scalar: 45), .unsupportedBidirectionalControl(scalar: 40),
                .unsupportedBidirectionalControl(scalar: 41),
            ]))
        #expect(shaper.shape("abc אבג 123", pointSize: 2048, direction: .leftToRight) == expected(
            [68, 69, 70, 3, 20, 21, 22, 3, 1321, 1320, 1319],
            [0..<1, 1..<2, 2..<3, 3..<4, 8..<9, 9..<10, 10..<11, 7..<8, 6..<7, 5..<6, 4..<5],
            [1255, 1300, 1126, 651, 1303, 1303, 1303, 651, 844, 1184, 1369],
            levels: [0, 0, 0, 0, 2, 2, 2, 1, 1, 1, 1], breaks: [4, 8]))
    }

    @Test func diagnosedControlsAndEmptyRunsKeepTheirMetadata() throws {
        let shaper = try shaper()
        #expect(shaper.shape("a\u{200E}b\u{200F}c", pointSize: 2048) == expected(
            [68, 2801, 69, 2802, 70], [0..<1, 1..<2, 2..<3, 3..<4, 4..<5], [1255, 0, 1300, 0, 1126],
            diagnostics: [.unsupportedBidirectionalControl(scalar: 8206), .unsupportedBidirectionalControl(scalar: 8207)]))
        for direction in [TextDirection.automatic, .leftToRight, .rightToLeft] {
            let resolved: TextDirection = direction == .rightToLeft ? .rightToLeft : .leftToRight
            #expect(shaper.shape("", pointSize: 12, direction: direction) ==
                expected([], [], [], direction: resolved))
            #expect(shaper.shape("abc", pointSize: .nan, direction: direction) ==
                expected([], [], [], direction: direction, diagnostics: [.invalidPointSize]))
        }
    }

    @Test func nativeLigaturePolicyStillKeepsSeparateScalarClusters() throws {
        let shaper = try shaper()
        #expect(shaper.shape("office", pointSize: 2048, kerning: false, standardLigatures: false) == expected(
            [82, 73, 73, 76, 70, 72], [0..<1, 1..<2, 2..<3, 3..<4, 4..<5, 5..<6],
            [1253, 721, 721, 569, 1126, 1260]))
        #expect(shaper.shape("office", pointSize: 2048, kerning: false, standardLigatures: true) == expected(
            [82, 5044, 70, 72], [0..<1, 1..<4, 4..<5, 5..<6], [1253, 1980, 1126, 1260]))
    }
}
