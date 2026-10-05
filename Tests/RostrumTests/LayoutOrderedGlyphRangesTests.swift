import Foundation
import Testing
@testable import Rostrum

@Suite struct LayoutOrderedGlyphRangesTests {
    // Captured from accepted native-placement source before this optimization.
    // These wrap boundaries exercise atom widths before final-line reshaping.
    private struct Example {
        let text: String
        let lines: [String]
        let widthBits: [UInt64]
        let diagnostics: [String]
    }

    private func check(_ example: Example, explicitMetrics: Bool) throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        let data = try Data(contentsOf: url)
        let fonts = FontLibrary()
        try fonts.register(data, aliases: ["OrderedProof"])
        let body = try XML.parse(Data("""
            <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/>
            <a:p><a:r><a:rPr sz="1225" spc="37" kern="0">
            <a:latin typeface="OrderedProof"/></a:rPr></a:r></a:p></p:txBody>
            """.utf8))
        let run = try #require(body.firstChild(named: "a:p")?.firstChild(named: "a:r"))
        run.appendElement(XML.Element("a:t", children: [.text(example.text)]))
        let before = body.serialized()
        let result = RichTextLayout(textBody: body, width: 70, height: 1000,
            fonts: explicitMetrics ? nil : fonts,
            fallbackMetrics: explicitMetrics ? try FontMetrics(data: data) : nil)
        #expect(result.lines.map { $0.spans.map(\.run.text).joined() } == example.lines)
        #expect(result.lines.map { $0.width.bitPattern } == example.widthBits)
        #expect(result.diagnostics.map { String(describing: $0) } == example.diagnostics)
        #expect(body.serialized() == before)
    }

    @Test(arguments: [false, true])
    func orderedNFCAndLigatureRangesKeepSourceTextAndWidths(explicitMetrics: Bool) throws {
        try check(Example(text: "café naïve 中文 office ffi",
            lines: ["café naïve ", "中文 office ", "ffi"],
            widthBits: [4634725386423873044, 4633612915677174170, 4623481656135982776],
            diagnostics: ["missingGlyph(scalar: 20013)", "missingGlyph(scalar: 25991)", "unsupportedLayoutFeature(\"Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified\")"]), explicitMetrics: explicitMetrics)
        try check(Example(text: "café Å office ffi",
            lines: ["café Å ", "office ffi"],
            widthBits: [4631508740417802732, 4632662508134046106],
            diagnostics: ["unsupportedLayoutFeature(\"Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified\")"]), explicitMetrics: explicitMetrics)
    }

    @Test(arguments: [false, true])
    func expandedRepeatedAndReorderedRangesKeepFallbackWidths(explicitMetrics: Bool) throws {
        try check(Example(text: "Ä́ café ffi",
            lines: ["Ä́ café ffi"],
            widthBits: [4633331749938108826],
            diagnostics: ["unsupportedLayoutFeature(\"Latin ccmp changes this residual combining sequence; composition shaping is unsupported\")", "unsupportedCombiningSequence(scalarRange: Range(0..<2))", "unsupportedLayoutFeature(\"Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified\")"]), explicitMetrics: explicitMetrics)
        try check(Example(text: "é abcdefghijk Á́́́́́́́ z",
            lines: ["é ", "abcdefghij", "k Á́́́́́́́ z"],
            widthBits: [4623041024102372475, 4634455584824675533, 4629571471710722458],
            diagnostics: ["unsupportedLayoutFeature(\"Latin ccmp changes this residual combining sequence; composition shaping is unsupported\")", "unsupportedCombiningSequence(scalarRange: Range(14..<23))", "unsupportedLayoutFeature(\"Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified\")"]), explicitMetrics: explicitMetrics)
        try check(Example(text: "abc אבג 123 café",
            lines: ["abc אבג ", "123 café"],
            widthBits: [4632667798159365243, 4633124061125153915],
            diagnostics: ["unsupportedLayoutFeature(\"Rich-text bidirectional span ordering requires a verified paragraph renderer\")", "unsupportedLayoutFeature(\"Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified\")"]), explicitMetrics: explicitMetrics)
        try check(Example(text: "سَلَام café",
            lines: ["سَلَام café"],
            widthBits: [4633426152632080138],
            diagnostics: ["unsupportedLayoutFeature(\"Mixed Arabic paragraph bidi and explicit LTR Arabic shaping are unsupported\")", "unsupportedLayoutFeature(\"Arabic mark attachment positioning is unsupported for unattached marks or ligature components\")", "unsupportedLayoutFeature(\"Rich-text bidirectional span ordering requires a verified paragraph renderer\")", "unsupportedLayoutFeature(\"Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified\")"]), explicitMetrics: explicitMetrics)
    }

    @Test(arguments: [false, true])
    func controlSegmentsKeepTheirWrapsAndDiagnostics(explicitMetrics: Bool) throws {
        try check(Example(text: "café\r\nnaïve\tffi\nÄ́",
            lines: ["café", "naïve", "", "ffi", "Ä́"],
            widthBits: [4628453782406960251, 4630166286885506253, 4634766966517661696, 4623481656135982776, 4621115432895973949],
            diagnostics: ["unsupportedLayoutFeature(\"Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified\")", "unsupportedLayoutFeature(\"Latin ccmp changes this residual combining sequence; composition shaping is unsupported\")", "unsupportedCombiningSequence(scalarRange: Range(0..<2))"]), explicitMetrics: explicitMetrics)
    }
}
