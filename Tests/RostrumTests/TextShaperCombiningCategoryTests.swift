import Foundation
import Testing
@testable import Rostrum

@Suite struct TextShaperCombiningCategoryTests {
    private func shaper() throws -> TextShaper {
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        return TextShaper(try FontMetrics(contentsOf: font))
    }

    @Test func asciiIncludingControlsNeverBecomesACombiningSequence() throws {
        let shaper = try shaper()
        for value in UInt32(0)...127 {
            let scalar = Unicode.Scalar(value)!
            for direction in [TextDirection.automatic, .leftToRight, .rightToLeft] {
                let run = shaper.shape(String(scalar), pointSize: 12, direction: direction)
                #expect(!run.diagnostics.contains {
                    if case .unsupportedCombiningSequence = $0 { return true }
                    return false
                })
                #expect(run.glyphs.allSatisfy { $0.scalarRange == 0..<1 })
            }
        }
    }

    @Test func crlfPreservesMandatoryBreakAndFollowingScalarRanges() throws {
        let run = try shaper().shape("A\r\nB", pointSize: 2048)
        #expect(run == ShapedGlyphRun(glyphs: [
            ShapedGlyph(glyphID: 36, scalarRange: 0..<1, advance: 1401, xOffset: 0, yOffset: 0, bidiLevel: 0),
            ShapedGlyph(glyphID: 37, scalarRange: 3..<4, advance: 1405, xOffset: 0, yOffset: 0, bidiLevel: 0),
        ], breaks: [TextBreakOpportunity(scalarOffset: 3, mandatory: true)], diagnostics: [], direction: .leftToRight))
    }

    @Test func nonAsciiMarksRetainCombiningDiagnostics() throws {
        let shaper = try shaper()
        // Standalone nonspacing, spacing and enclosing marks all remain on the
        // general path, including marks without a registered glyph.
        for text in ["\u{301}", "\u{93E}", "\u{20DD}"] {
            let run = shaper.shape(text, pointSize: 12)
            #expect(run.diagnostics.contains(.unsupportedCombiningSequence(scalarRange: 0..<1)))
        }
        let residual = shaper.shape("A\u{303}\u{300}", pointSize: 2048)
        #expect(residual.glyphs.map(\.scalarRange) == [0..<3, 0..<3])
        #expect(residual.diagnostics == [
            .unsupportedLayoutFeature("Latin ccmp changes this residual combining sequence; composition shaping is unsupported"),
            .unsupportedCombiningSequence(scalarRange: 0..<3),
        ])
    }
}
