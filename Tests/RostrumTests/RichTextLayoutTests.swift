import Foundation
import Testing
@testable import Rostrum

@Suite struct RichTextLayoutTests {
    private func body(_ content: String, attributes: String = "", autofit: String = "") throws -> XML.Element {
        try XML.parse(Data("<p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\" \(attributes)>\(autofit)</a:bodyPr>\(content)</p:txBody>".utf8))
    }
    private func metrics() throws -> FontMetrics { try FontMetrics(data: TestFont.standard()) }

    @Test func colorTransformsAndOpacityApplyWithoutATheme() throws {
        let xml = try body("<a:p><a:r><a:rPr><a:solidFill><a:srgbClr val=\"808080\"><a:shade val=\"50000\"/><a:alpha val=\"80000\"/><a:alphaMod val=\"50000\"/></a:srgbClr></a:solidFill></a:rPr><a:t>A</a:t></a:r></a:p>")
        let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: try metrics())
        #expect(layout.lines.first?.spans.first?.run.color == "rgba(92,92,92,0.4)")
    }

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
        """, attributes: "anchor=\"ctr\" spcFirstLastPara=\"1\"", autofit: "<a:normAutofit fontScale=\"50000\" lnSpcReduction=\"20000\"/>")
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

    @Test func edgeParagraphSpacingDefaultsOffAndAcceptsBothBooleanSpellings() throws {
        let paragraph = """
        <a:p><a:pPr><a:spcBef><a:spcPts val="300"/></a:spcBef><a:spcAft><a:spcPts val="400"/></a:spcAft><a:defRPr sz="1000"/></a:pPr><a:r><a:t>A</a:t></a:r></a:p>
        """
        for (attribute, enabled) in [("", false), ("spcFirstLastPara=\"0\"", false),
                                     ("spcFirstLastPara=\"false\"", false), ("spcFirstLastPara=\"1\"", true),
                                     ("spcFirstLastPara=\"true\"", true)] {
            let xml = try body(paragraph, attributes: attribute)
            let layout = RichTextLayout(textBody: xml, width: 100, height: 12, fallbackMetrics: try metrics())
            #expect(layout.contentHeight == (enabled ? 17 : 10), "\(attribute)")
            #expect(layout.lines[0].baseline == (enabled ? 11 : 8), "\(attribute)")
            #expect(layout.fits == !enabled, "\(attribute)")
        }
    }

    @Test func suppressingOuterSpacingPreservesInteriorAndEmptyParagraphs() throws {
        func paragraph(_ text: String?) -> String {
            let run = text.map { "<a:r><a:t>\($0)</a:t></a:r>" } ?? ""
            return """
            <a:p><a:pPr><a:spcBef><a:spcPts val="300"/></a:spcBef><a:spcAft><a:spcPts val="400"/></a:spcAft><a:defRPr sz="1000"/></a:pPr>\(run)</a:p>
            """
        }
        for emptyEdges in [false, true] {
            let content = paragraph(emptyEdges ? nil : "First") + paragraph("Middle")
                + paragraph(emptyEdges ? nil : "Last")
            for enabled in [false, true] {
                let xml = try body(content, attributes: "spcFirstLastPara=\"\(enabled ? 1 : 0)\"")
                let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: try metrics())
                #expect(layout.lines.count == 3)
                // Two internal boundaries retain 4pt after + 3pt before.
                #expect(layout.contentHeight == (enabled ? 51 : 44))
                #expect(layout.lines.map(\.baseline) == (enabled ? [11, 28, 45] : [8, 25, 42]))
                #expect(layout.lines[0].spans.isEmpty == emptyEdges)
                #expect(layout.lines[2].spans.isEmpty == emptyEdges)
            }
        }
    }

    @Test func verticalAnchorsUseHeightWithoutSuppressedOuterSpacing() throws {
        let paragraph = """
        <a:p><a:pPr><a:spcBef><a:spcPts val="300"/></a:spcBef><a:spcAft><a:spcPts val="400"/></a:spcAft><a:defRPr sz="1000"/></a:pPr><a:r><a:t>A</a:t></a:r></a:p>
        """
        for (anchor, baseline) in [("t", 8.0), ("ctr", 53.0), ("b", 98.0)] {
            let xml = try body(paragraph, attributes: "anchor=\"\(anchor)\"")
            let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: try metrics())
            #expect(layout.lines[0].baseline == baseline)
            #expect(layout.contentHeight == 10)
        }
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

    @Test func nearestBulletFontAndSizeChoicesOverrideInheritedAlternatives() throws {
        let master = try XML.parse(Data("""
        <p:bodyStyle><a:lvl1pPr><a:buSzPts val="4000"/><a:buFont typeface="Master"/><a:buChar char="•"/></a:lvl1pPr></p:bodyStyle>
        """.utf8))
        let layoutStyle = try XML.parse(Data("""
        <a:lstStyle><a:lvl1pPr><a:buSzPct val="150000"/><a:buFontTx/></a:lvl1pPr></a:lstStyle>
        """.utf8))
        for (local, expectedFamily, expectedSize) in [
            ("", "Body", 15.0),
            ("<a:buSzTx/><a:buFontTx/>", "Body", 10.0),
            ("<a:buSzPct val=\"50000\"/><a:buFont typeface=\"Local\"/>", "Local", 5.0),
            ("<a:buSzPts val=\"2400\"/>", "Body", 12.0)
        ] {
            let xml = try body("""
            <a:p><a:pPr>\(local)</a:pPr><a:r><a:rPr sz="2000"><a:latin typeface="Body"/></a:rPr><a:t>Item</a:t></a:r></a:p>
            """, autofit: "<a:normAutofit fontScale=\"50000\"/>")
            let result = RichTextLayout(textBody: xml, width: 200, height: 100,
                fallbackMetrics: try metrics(), inheritedStyles: [layoutStyle, master])
            let spans = try #require(result.lines.first).spans
            #expect(spans.count == 2)
            #expect(spans[0].run.text == "• ")
            #expect(spans[0].run.fontFamily == expectedFamily, "\(local)")
            #expect(spans[0].run.fontSize == expectedSize, "\(local)")
            #expect(spans[1].run.fontFamily == "Body" && spans[1].run.fontSize == 10)
        }
    }

    @Test func automaticNumbersFollowTextFontWhileCharacterBulletsUseBulletFont() throws {
        // Native PowerPoint renders automatic numbers in the text face even
        // when buFont names a different explicit or theme face. Character
        // bullets honor that face. Keep schema order in the oracle fixture.
        for font in ["Arial Black", "+mj-lt"] {
            let inherited = try XML.parse(Data("""
            <a:lstStyle><a:lvl1pPr><a:buFont typeface="\(font)"/></a:lvl1pPr></a:lstStyle>
            """.utf8))
            for localFont in ["", "<a:buFont typeface=\"\(font)\"/>"] {
                let xml = try body("""
                <a:p><a:pPr>\(localFont)<a:buAutoNum type="arabicPeriod"/></a:pPr><a:r><a:rPr sz="2800"><a:latin typeface="Times New Roman"/></a:rPr><a:t>Number</a:t></a:r></a:p>
                <a:p><a:pPr>\(localFont)<a:buChar char="1."/></a:pPr><a:r><a:rPr sz="2800"><a:latin typeface="Times New Roman"/></a:rPr><a:t>Character</a:t></a:r></a:p>
                """)
                let theme = try Presentation().theme
                let layout = RichTextLayout(textBody: xml, width: 500, height: 200,
                    fallbackMetrics: try metrics(), theme: theme, inheritedStyles: [inherited])
                #expect(layout.lines[0].spans[0].run.fontFamily == "Times New Roman")
                #expect(layout.lines[1].spans[0].run.fontFamily == (font == "+mj-lt" ? theme.majorFont : font))
                #expect(layout.lines.allSatisfy { $0.spans[0].run.fontSize == 28 })
            }
        }
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
        // Native DejaVu 12pt base advance is 8.25pt after rounding; no pair
        // adjustment may survive when V moves to the next line.
        #expect(layout.lines[0].spans[0].width == 8.25)
        #expect(!layout.fits) // the unkerned A is wider than 8pt
    }

    @Test func fallbackASCIIKeepsBreaksTrackingControlsAndLiveDOMChanges() throws {
        let xml = try body("<a:p><a:pPr><a:tabLst><a:tab pos=\"228600\"/></a:tabLst></a:pPr><a:r><a:rPr sz=\"1000\" spc=\"100\"/><a:t>AB-CD EF\tGH\r\nIJ</a:t></a:r></a:p>")
        let layout = RichTextLayout(textBody: xml, width: 18, height: 200)
        #expect(layout.lines.map { $0.spans.map(\.run.text).joined() } == ["AB-", "CD ", "EF", "GH", "IJ"])
        #expect(layout.lines[0].spans[0].width == 15.600000000000001)
        #expect(layout.diagnostics == [.unsupportedLayoutFeature("Unregistered font face: unspecified")])
        let run = try #require(xml.firstChild(named: "a:p")?.firstChild(named: "a:r"))
        try #require(run.firstChild(named: "a:t")).children = [.text("é 中 X")]
        let changed = RichTextLayout(textBody: xml, width: 18, height: 200)
        #expect(changed.lines.map { $0.spans.map(\.run.text).joined() } == ["é ", "中 X"])
        let expectedHeight: Double = 2 * (10.0 * 4 / 3)
        #expect(changed.contentHeight == expectedHeight)
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
        #expect(svg.contains("<tspan") && svg.contains("#FF0000") && !svg.contains("textLength="))
        for span in layout.lines.flatMap(\.spans) {
            let positions = span.scalarPositions ?? [span.x]
            #expect(positions.count == span.run.text.unicodeScalars.count)
            let expected = positions.map(SVGNumber.decimal).joined(separator: " ")
            #expect(svg.contains(" x=\"\(expected)\""))
        }
        #expect(svg.components(separatedBy: "<text").count - 1 == layout.lines.count)
        #expect(try deck.serializedData() == before)
        #expect(svg == (try deck.renderSVG(slideAt: 0)))
    }
}
