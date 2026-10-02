import Foundation
import Testing
@testable import Rostrum

@Suite struct KerningThresholdTests {
    private var fontURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
    }
    private func metrics() throws -> FontMetrics { try FontMetrics(contentsOf: fontURL) }
    private func body(run: String = "", paragraph: String = "", list: String = "",
                      text: String = "AV", autofit: String = "") throws -> XML.Element {
        try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0">\(autofit)</a:bodyPr>
        <a:lstStyle>\(list)</a:lstStyle><a:p><a:pPr><a:defRPr sz="1200" \(paragraph)/></a:pPr>
        <a:r><a:rPr \(run)/><a:t>\(text)</a:t></a:r></a:p></p:txBody>
        """.utf8))
    }

    @Test func disabledPairPositioningKeepsHarfBuzzLigaturesAndClusters() throws {
        let shaper = TextShaper(try metrics())
        let originalSignature: (String, Double, TextDirection) -> ShapedGlyphRun = shaper.shape
        #expect(originalSignature("AV", 12, .automatic) == shaper.shape("AV", pointSize: 12))
        // Independent hb-shape 14.4.0, pinned DejaVuSans.ttf, kern=0,
        // pointSize=unitsPerEm=2048. The ffi ligature stays enabled.
        let run = shaper.shape("AV office", pointSize: 2048, kerning: false)
        #expect(run.glyphs.map(\.glyphID) == [36, 57, 3, 82, 5044, 70, 72])
        #expect(run.glyphs.map(\.advance) == [1401, 1401, 651, 1253, 1980, 1126, 1260])
        #expect(run.glyphs.map(\.scalarRange.lowerBound) == [0, 1, 2, 3, 4, 7, 8])
        #expect(run.glyphs[4].scalarRange == 4..<7)
        #expect(run.isSupported)
        let enabled = shaper.shape("AV office", pointSize: 2048)
        #expect(enabled.glyphs.map(\.glyphID) == run.glyphs.map(\.glyphID))
        #expect(enabled.width < run.width)
    }

    @Test func kerningSelectionPreservesJoiningAndUnsupportedDiagnostics() throws {
        let shaper = TextShaper(try metrics())
        for text in ["سلام", "سَلَام", "x\u{301}", "क्षि"] {
            let enabled = shaper.shape(text, pointSize: 12)
            let disabled = shaper.shape(text, pointSize: 12, kerning: false)
            #expect(enabled.glyphs.map(\.glyphID) == disabled.glyphs.map(\.glyphID))
            #expect(enabled.glyphs.map(\.scalarRange) == disabled.glyphs.map(\.scalarRange))
            #expect(enabled.diagnostics == disabled.diagnostics)
        }
    }

    @Test func explicitThresholdIsInclusiveAndZeroEnablesAllSizes() throws {
        let font = try metrics()
        for (threshold, enabled) in [("0", true), ("1199", true), ("1200", true), ("1201", false), ("400000", false)] {
            let layout = RichTextLayout(textBody: try body(run: "kern=\"\(threshold)\""),
                width: 100, height: 100, fallbackMetrics: font)
            let span = try #require(layout.lines.first?.spans.first)
            #expect(span.run.usesKerning == enabled)
            #expect(span.width == TextShaper(font).shape("AV", pointSize: 12, kerning: enabled).width)
        }
    }

    @Test func runOverridesParagraphListAndInheritedThresholds() throws {
        let font = try metrics()
        let inherited = try XML.parse(Data("<a:lstStyle><a:lvl1pPr><a:defRPr kern=\"2400\"/></a:lvl1pPr></a:lstStyle>".utf8))
        for (run, paragraph, list, expected) in [
            ("", "", "", 24.0),
            ("", "", "<a:lvl1pPr><a:defRPr kern=\"1800\"/></a:lvl1pPr>", 18.0),
            ("", "kern=\"1201\"", "", 12.01),
            ("kern=\"0\"", "kern=\"2400\"", "", 0.0)
        ] {
            let layout = RichTextLayout(textBody: try body(run: run, paragraph: paragraph, list: list),
                width: 100, height: 100, fallbackMetrics: font, inheritedStyles: [inherited])
            let span = try #require(layout.lines.first?.spans.first)
            #expect(span.run.kerningThreshold == expected)
            #expect(span.run.usesKerning == (expected <= 12))
        }
    }

    @Test func disabledKerningChangesWrappingAndFitAtTheMeasuredBoundary() throws {
        let font = try metrics(), shaper = TextShaper(font)
        let width = (shaper.shape("AV", pointSize: 12).width + shaper.shape("AV", pointSize: 12, kerning: false).width) / 2
        let enabled = RichTextLayout(textBody: try body(run: "kern=\"0\""), width: width, height: 16, fallbackMetrics: font)
        let disabled = RichTextLayout(textBody: try body(run: "kern=\"2400\""), width: width, height: 16, fallbackMetrics: font)
        #expect(enabled.lines.count == 1 && enabled.fits)
        #expect(disabled.lines.count == 2 && !disabled.fits)
        #expect(disabled.lines.map { $0.spans.map(\.run.text).joined() } == ["A", "V"])
        #expect(disabled.lines[0].width == shaper.shape("A", pointSize: 12, kerning: false).width)
    }

    @Test func autofitComparesTheRenderedSizeWithTheUnscaledThreshold() throws {
        let layout = RichTextLayout(textBody: try body(run: "kern=\"1200\"", autofit: "<a:normAutofit fontScale=\"50000\"/>"),
            width: 100, height: 100, fallbackMetrics: try metrics())
        let span = try #require(layout.lines.first?.spans.first)
        #expect(span.run.fontSize == 6 && span.run.kerningThreshold == 12 && !span.run.usesKerning)
        #expect(span.width == 2 * 1401.0 * 6 / 2048)
    }

    @Test func cachedSVGAttributesDistinguishKerningWithoutDisablingLigatures() throws {
        let cache = RenderTextAttributes()
        var run = ResolvedTextRun(text: "AV office", fontFamily: "DejaVu Sans", fontSize: 12,
            bold: false, italic: false, color: "#000000", tracking: 0)
        let enabled = cache.attributes(for: run, family: run.fontFamily)
        run.kerningThreshold = 24
        let disabled = cache.attributes(for: run, family: run.fontFamily)
        let xml = try XML.parse(Data(("<tspan" + disabled + "/>").utf8))
        #expect(xml[attribute: "kerning"] == "0")
        #expect(!disabled.contains("font-variant") && !disabled.contains("letter-spacing"))
        #expect(enabled != disabled && cache.count == 2)
        run.kerningThreshold = 12
        #expect(cache.attributes(for: run, family: run.fontFamily) == enabled)
    }

    @Test func renderingUsesTheResolvedKerningPolicyWithoutMutatingTheDeck() throws {
        let deck = try Presentation()
        try deck.fonts.register(Data(contentsOf: fontURL), aliases: ["Kerning Fixture"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(200), height: .points(100)))
        let frame = try #require(shape.textFrame)
        frame.text = "AV office"
        let run = frame.paragraphs[0].runs[0]
        run.fontName = "Kerning Fixture"; run.fontSize = 12
        let rPr = try #require(frame.txBody.firstChild(named: "a:p")?.firstChild(named: "a:r")?.firstChild(named: "a:rPr"))
        rPr[attribute: "kern"] = "2400"
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains(" kerning=\"0\""))
        #expect(try deck.serializedData() == before)
    }
}
