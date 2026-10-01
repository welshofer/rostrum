import Foundation
import Testing
@testable import Rostrum

@Suite struct RichTextLayoutTests {
    private func body(_ content: String, attributes: String = "", autofit: String = "") throws -> XML.Element {
        try XML.parse(Data("<p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\" \(attributes)>\(autofit)</a:bodyPr>\(content)</p:txBody>".utf8))
    }
    private func metrics() throws -> FontMetrics { try FontMetrics(data: TestFont.standard()) }

    @Test func mixedFacesSizesStylesAndTrackingKeepTheirOwnMeasurements() throws {
        let fonts = FontLibrary()
        try fonts.register(FontFaceTests.font(400, bold: false, italic: false), aliases: ["First"])
        try fonts.register(FontFaceTests.font(700, bold: true, italic: true), aliases: ["Second"])
        let xml = try body("""
        <a:p><a:r><a:rPr sz="1000" spc="100"><a:latin typeface="First"/><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:rPr><a:t>A</a:t></a:r>
        <a:r><a:rPr sz="2000" b="1" i="1"><a:latin typeface="Second"/><a:solidFill><a:srgbClr val="0000FF"/></a:solidFill></a:rPr><a:t>B</a:t></a:r></a:p>
        """)
        let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fonts: fonts)
        let spans = try #require(layout.lines.first).spans
        #expect(spans.count == 2)
        #expect(spans.map(\.width) == [5, 14])
        #expect(spans.map(\.run.fontSize) == [10, 20])
        #expect(spans.map(\.run.color) == ["#FF0000", "#0000FF"])
        #expect(spans[1].run.bold && spans[1].run.italic)
        #expect(layout.lines[0].height == 20)
        #expect(RichTextLayout(textBody: xml, width: 15, height: 100, fonts: fonts).lines.count == 2)
    }

    @Test func fieldsManualBreaksTabsAndRepeatedSpacesSurvive() throws {
        let xml = try body("""
        <a:p><a:pPr><a:tabLst><a:tab pos="254000"/></a:tabLst><a:defRPr sz="1000"/></a:pPr>
        <a:r><a:t>A  \tB</a:t></a:r><a:br/><a:fld type="slidenum"><a:t>99</a:t></a:fld><a:r><a:t> end</a:t></a:r></a:p>
        """)
        let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: try metrics(), slideNumber: 7)
        #expect(layout.lines.count == 2)
        #expect(layout.lines[0].spans.map(\.run.text) == ["A  ", "B"])
        #expect(layout.lines[0].spans.map(\.x) == [0, 20])
        #expect(layout.lines[1].spans.map(\.run.text) == ["7", " end"])
    }

    @Test func spacingInsetsVerticalAnchorAndAutofitShareGeometry() throws {
        let xml = try body("""
        <a:p><a:pPr><a:spcBef><a:spcPts val="300"/></a:spcBef><a:spcAft><a:spcPts val="400"/></a:spcAft><a:defRPr sz="2000"/></a:pPr><a:r><a:t>AA</a:t></a:r></a:p>
        """, attributes: "anchor=\"ctr\"", autofit: "<a:normAutofit fontScale=\"50000\" lnSpcReduction=\"20000\"/>")
        let bodyPr = try #require(xml.firstChild(named: "a:bodyPr"))
        for (key, value) in [("lIns", 10), ("tIns", 2), ("rIns", 20), ("bIns", 8)] {
            bodyPr[attribute: key] = String(value * EMU.perPoint)
        }
        let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: try metrics())
        #expect(layout.contentHeight == 15) // 3 before + 10 * .8 line + 4 after
        #expect(layout.lines[0].spans[0].x == 10)
        #expect(layout.lines[0].spans[0].run.fontSize == 10)
        #expect(layout.lines[0].baseline == 50.5) // 2 + (90-15)/2 + 3 + 8
    }

    @Test func localParagraphAndRunOverridesMergeWithEveryInheritedLevel() throws {
        let master = try XML.parse(Data("<p:bodyStyle><a:lvl2pPr marL=\"254000\"><a:defRPr sz=\"2400\" b=\"1\"><a:latin typeface=\"Master\"/></a:defRPr></a:lvl2pPr></p:bodyStyle>".utf8))
        let inherited = try XML.parse(Data("<a:lstStyle><a:lvl2pPr><a:defRPr i=\"1\"/></a:lvl2pPr></a:lstStyle>".utf8))
        let xml = try body("<a:p><a:pPr lvl=\"1\"><a:defRPr sz=\"1400\"/></a:pPr><a:r><a:rPr b=\"0\"/><a:t>A</a:t></a:r></a:p>")
        let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: try metrics(), inheritedStyles: [inherited, master])
        let span = try #require(layout.lines.first?.spans.first)
        #expect(span.run.fontSize == 14 && span.run.italic && !span.run.bold)
        #expect(span.run.fontFamily == "Master")
        #expect(span.x == 20)
    }

    @Test func bulletsHangAndNumberingContinuesOrRestartsExplicitly() throws {
        let xml = try body("""
        <a:p><a:pPr marL="254000" indent="-127000"><a:buChar char="•"/><a:defRPr sz="1000"/></a:pPr><a:r><a:t>one</a:t></a:r></a:p>
        <a:p><a:pPr><a:buAutoNum type="romanLcPeriod" startAt="4"/></a:pPr><a:r><a:t>four</a:t></a:r></a:p>
        <a:p><a:pPr><a:buAutoNum type="romanLcPeriod"/></a:pPr><a:r><a:t>five</a:t></a:r></a:p>
        <a:p><a:pPr><a:buAutoNum type="romanLcPeriod" startAt="2"/></a:pPr><a:r><a:t>two</a:t></a:r></a:p>
        """)
        let layout = RichTextLayout(textBody: xml, width: 200, height: 200, fallbackMetrics: try metrics())
        #expect(layout.lines[0].spans.map(\.x) == [10, 20])
        #expect(layout.lines.map { $0.spans[0].run.text } == ["• ", "iv. ", "v. ", "ii. "])
    }

    @Test func wrappingOffIsMeasuredAsOverflowAndNeverSplits() throws {
        let xml = try body("<a:p><a:r><a:rPr sz=\"1000\"/><a:t>AAAA AAAA</a:t></a:r></a:p>", attributes: "wrap=\"none\"")
        let layout = RichTextLayout(textBody: xml, width: 20, height: 100, fallbackMetrics: try metrics())
        #expect(layout.lines.count == 1 && !layout.fits)
        #expect(layout.lines[0].spans[0].run.text == "AAAA AAAA")
    }

    @Test func kerningAcrossAnAutomaticBreakIsRemeasuredAtTheLineBoundary() throws {
        let font = try FontMetrics(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
        let xml = try body("<a:p><a:r><a:rPr sz=\"1200\"/><a:t>AV</a:t></a:r></a:p>")
        let layout = RichTextLayout(textBody: xml, width: 8, height: 100, fallbackMetrics: font)
        #expect(layout.lines.count == 2)
        #expect(layout.lines[0].spans[0].width == TextShaper(font).shape("A", pointSize: 12).width)
        #expect(!layout.fits) // the unkerned A is wider than 8pt
    }

    @Test func fittingAndSVGUseTheStoredRichLayoutAndRenderingIsPure() throws {
        let deck = try Presentation()
        try deck.fonts.register(TestFont.standard(), aliases: ["First"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(45), height: .points(25)))
        let frame = try #require(shape.textFrame)
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.text = "AAA "
        let first = frame.paragraphs[0].runs[0]; first.fontName = "First"; first.fontSize = 20
        let second = frame.paragraphs[0].addRun("BBB"); second.fontName = "First"; second.fontSize = 10; second.color = Color("FF0000")
        let result = frame.fitText(in: shape.frame, fonts: deck.fonts, theme: deck.theme)
        #expect(result.fits && result.fontScale < 100)
        let layout = RichTextLayout(textBody: frame.txBody, width: 45, height: 25, fonts: deck.fonts, theme: deck.theme)
        #expect(layout.fits)
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("<tspan") && svg.contains("#FF0000") && svg.contains("textLength="))
        #expect(svg.components(separatedBy: "<text").count - 1 == layout.lines.count)
        #expect(try deck.serializedData() == before)
        #expect(svg == (try deck.renderSVG(slideAt: 0)))
    }
}
