import Foundation
import Testing
@testable import Rostrum

@Suite struct ImportedGeometryRegressionTests {
    @Test func explicitFallbackMeasuresAndDrawsTheSameFaceWithoutChangingSource() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(125), height: .points(200)))
        let frame = try #require(shape.textFrame)
        frame.text = "WWWW WWWW WWWW"
        frame.paragraphs[0].runs[0].fontName = "Unavailable"
        frame.paragraphs[0].runs[0].fontSize = 24
        try deck.fonts.register(TestFont.standard(familyName: "Measured Fallback"))
        let estimated = RichTextLayout(textBody: frame.txBody, width: 125, height: 200, fonts: deck.fonts)
        let bytes = try deck.serializedData()
        deck.fonts.previewFallbackFamily = "Measured Fallback"
        let measured = RichTextLayout(textBody: frame.txBody, width: 125, height: 200, fonts: deck.fonts)
        #expect(measured.lines.count > estimated.lines.count)
        #expect(measured.lines.count == 3)
        #expect(measured.lines.allSatisfy { $0.visibleWidth <= 110.6 })
        let rendered = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(rendered.svg.contains("measured fallback")) // metric-only fixture uses explicit viewer family
        #expect(rendered.svg.contains("textLength="))
        #expect(rendered.problems.fidelityIssues.contains { $0.code == .missingFont && $0.message.contains("measured fallback") })
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
        #expect(try deck.serializedData() == bytes)
        #expect(try deck.renderSVG(slideAt: 0) == rendered.svg)
        let reopened = try Presentation(data: bytes)
        #expect(reopened.fonts.previewFallbackFamily == nil)
        #expect(try reopened.slides[0].shapes.all.first?.textFrame?.paragraphs[0].runs[0].fontName == "Unavailable")
    }
    private func parse(_ xml: String) throws -> XML.Element { try XML.parse(Data(xml.utf8)) }

    @Test func missingFontEstimatesDoNotCompressViewerGlyphs() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(600), height: .points(100)))
        let frame = try #require(shape.textFrame)
        frame.text = "Wide title WWW"
        let run = frame.paragraphs[0].runs[0]
        run.fontName = "Unregistered Face"
        run.fontSize = 36
        let estimated = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(!estimated.svg.contains("textLength="))
        #expect(estimated.problems.fidelityIssues.contains { $0.code == .viewerFontDependency })
        try deck.fonts.register(TestFont.standard(), aliases: ["Unregistered Face"])
        #expect(try deck.renderSVG(slideAt: 0).contains("textLength="))
    }

    @Test func missingFontRunsFlowNaturallyUntilAnExplicitTabOrListBoundary() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let shape = try slide.shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(600), height: .points(100)))
        let frame = try #require(shape.textFrame)
        frame.txBody.removeChildren(named: "a:p")
        frame.txBody.appendElement(try parse("""
        <a:p><a:pPr marL="254000" indent="-127000"><a:buChar char="•"/><a:tabLst><a:tab pos="2540000"/></a:tabLst><a:defRPr sz="2000"><a:latin typeface="Missing"/></a:defRPr></a:pPr>
        <a:r><a:rPr b="1"/><a:t>Subjective </a:t></a:r><a:r><a:t>state </a:t></a:r><a:r><a:rPr><a:latin typeface="Known"/></a:rPr><a:t>of being</a:t></a:r><a:r><a:t>\tTabbed</a:t></a:r></a:p>
        """))
        try deck.fonts.register(TestFont.standard(), aliases: ["Known"])
        func spans(_ svg: String) throws -> [XML.Element] {
            var pending = [try parse(svg)], result: [XML.Element] = []
            while let node = pending.popLast() {
                if node.name == "tspan" { result.append(node) }
                pending.append(contentsOf: node.childElements.reversed())
            }
            return result
        }
        let bytes = try deck.serializedData()
        let fallback = try spans(deck.renderSVG(slideAt: 0))
        #expect(fallback.count == 5)
        #expect(fallback.map { $0[attribute: "x"] != nil } == [true, true, false, false, true])
        #expect(fallback[3][attribute: "textLength"] != nil) // measured run follows actual preceding advance
        #expect(try deck.serializedData() == bytes)
        try deck.fonts.register(TestFont.standard(), aliases: ["Missing"])
        let measured = try spans(deck.renderSVG(slideAt: 0))
        #expect(measured.count == 5 && measured.allSatisfy { $0[attribute: "x"] != nil })
    }

    @Test func hiddenShapesAndGroupsArePreservedWithoutPreviewOrWarnings() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let tree = try #require(Slide.existingSpTree(of: slide.part))
        for (kind, properties) in [("sp", "nvSpPr"), ("pic", "nvPicPr"),
                                    ("cxnSp", "nvCxnSpPr"), ("graphicFrame", "nvGraphicFramePr"),
                                    ("grpSp", "nvGrpSpPr")] {
            for value in ["1", "true"] {
                let node = try parse("""
                <p:\(kind)><p:\(properties)><p:cNvPr id="99" hidden="\(value)"/></p:\(properties)>
                <p:spPr><a:prstGeom prst="unsupportedHiddenGeometry"/></p:spPr>
                <p:txBody><a:bodyPr/><a:p><a:r><a:t>Hidden text</a:t></a:r></a:p></p:txBody>
                <p:sp><p:spPr><a:prstGeom prst="unsupportedHiddenChild"/></p:spPr></p:sp>
                </p:\(kind)>
                """)
                #expect(ShapeCollection.isHidden(node))
                tree.appendElement(node)
            }
        }
        slide.part.markDirty()
        let bytes = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(!result.svg.contains("Hidden text"))
        #expect(result.problems.isEmpty)
        #expect(try deck.serializedData() == bytes)
        #expect(try Presentation(data: bytes).renderSVG(slideAt: 0) == result.svg)
        let visible = try parse("<p:sp><p:nvSpPr><p:cNvPr hidden=\"false\"/></p:nvSpPr></p:sp>")
        #expect(!ShapeCollection.isHidden(visible))
    }

    @Test func customCurvesScaleCoordinatesWithoutScalingStrokeAndRoundTrip() throws {
        let deck = try Presentation()
        let shape = try parse("""
        <p:sp><p:nvSpPr><p:cNvPr id="5" name="Curved decoration"/></p:nvSpPr><p:spPr>
        <a:xfrm><a:off x="50" y="60"/><a:ext cx="400" cy="200"/></a:xfrm>
        <a:custGeom><a:pathLst><a:path w="100" h="100"><a:moveTo><a:pt x="0" y="50"/></a:moveTo><a:cubicBezTo><a:pt x="0" y="0"/><a:pt x="100" y="0"/><a:pt x="100" y="50"/></a:cubicBezTo><a:lnTo><a:pt x="50" y="100"/></a:lnTo><a:close/></a:path>
        <a:path w="100" h="100" fill="none" stroke="false"><a:moveTo><a:pt x="0" y="0"/></a:moveTo><a:quadBezTo><a:pt x="50" y="100"/><a:pt x="100" y="0"/></a:quadBezTo></a:path></a:pathLst></a:custGeom>
        <a:solidFill><a:srgbClr val="FF0000"/></a:solidFill><a:ln w="10"><a:solidFill><a:srgbClr val="000000"/></a:solidFill></a:ln></p:spPr></p:sp>
        """)
        try #require(Slide.existingSpTree(of: deck.slides[0].part)).appendElement(shape)
        try deck.slides[0].part.markDirty()
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.svg.contains("M0 100 C0 0 400 0 400 100 L200 200 Z"))
        #expect(result.svg.contains("Q200 200 400 0\" fill=\"none\"/>"))
        #expect(result.svg.contains("stroke-width=\"10\""))
        #expect(result.problems.isEmpty)
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).renderSVG(slideAt: 0) == result.svg)
    }

    @Test func guideCoordinatesResolveAndMalformedPathsFailClosed() throws {
        let geometry = try parse("""
        <a:custGeom><a:gdLst><a:gd name="mid" fmla="*/ w 1 2"/></a:gdLst><a:pathLst><a:path><a:moveTo><a:pt x="l" y="t"/></a:moveTo><a:lnTo><a:pt x="mid" y="b"/></a:lnTo></a:path></a:pathLst></a:custGeom>
        """)
        #expect(SVGCustomGeometry.paths(geometry, width: 100, height: 200)?.first?.data == "M0 0 L50 200")
        for xml in ["<a:path w=\"0\"/>", "<a:path><a:lnTo><a:pt x=\"0\" y=\"0\"/></a:lnTo></a:path>", "<a:path><a:moveTo><a:pt x=\"NaN\" y=\"0\"/></a:moveTo></a:path>", "<a:path><a:arcTo/></a:path>"] {
            let bad = try parse("<a:custGeom><a:pathLst>\(xml)</a:pathLst></a:custGeom>")
            #expect(SVGCustomGeometry.paths(bad, width: 100, height: 200) == nil)
        }
    }

    @Test func capitalizedTextIsMeasuredAndEmptyListItemsDoNotAdvance() throws {
        let body = try parse("""
        <p:txBody><a:bodyPr/><a:lstStyle><a:lvl1pPr><a:defRPr cap="all"/></a:lvl1pPr></a:lstStyle>
        <a:p><a:pPr><a:buAutoNum type="arabicPeriod"/></a:pPr><a:r><a:t>First</a:t></a:r></a:p>
        <a:p><a:pPr><a:buAutoNum type="arabicPeriod"/></a:pPr></a:p>
        <a:p><a:pPr><a:buAutoNum type="arabicPeriod"/></a:pPr><a:r><a:t/></a:r></a:p>
        <a:p><a:pPr><a:buAutoNum type="arabicPeriod"/></a:pPr><a:r><a:rPr cap="none"/><a:t>Second</a:t></a:r></a:p></p:txBody>
        """)
        let layout = RichTextLayout(textBody: body, width: 500, height: 500)
        #expect(layout.lines.count == 4)
        #expect(layout.lines[1].spans.isEmpty && layout.lines[2].spans.isEmpty)
        #expect(layout.lines.flatMap(\.spans).map(\.run.text) == ["1. ", "FIRST", "2. ", "Second"])
        #expect(body.textContent.contains("First") && !body.textContent.contains("FIRST"))
        let inherited = try parse("<a:bodyPr anchor=\"b\" lIns=\"127000\"/>")
        let bottom = RichTextLayout(textBody: body, width: 500, height: 500, inheritedStyles: [inherited])
        #expect(bottom.lines.last!.baseline > layout.lines.last!.baseline)
        #expect(bottom.lines[0].spans[0].x == 10)
    }
    @Test func savedSmartArtDrawingRendersAndMissingCacheIsHonest() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        _ = try slide.shapes.addSmartArt(items: ["Saved diagram"], frame: Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(2)))
        let missing = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(missing.svg.contains("[SmartArt]"))
        #expect(missing.problems.fidelityIssues.contains { $0.code == .graphicPlaceholder })
        let drawing = deck.package.addPart(uri: PackURI("/ppt/diagrams/drawing1.xml"),
            contentType: "application/vnd.ms-office.drawingml.diagramDrawing+xml", blob: Data("""
            <dsp:drawing xmlns:dsp="http://schemas.microsoft.com/office/drawing/2008/diagram" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><dsp:spTree><dsp:nvGrpSpPr/><dsp:grpSpPr/>
            <dsp:sp><dsp:nvSpPr><dsp:cNvPr id="1"/></dsp:nvSpPr><dsp:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="3657600" cy="1828800"/></a:xfrm><a:prstGeom prst="roundRect"/><a:solidFill><a:srgbClr val="EEAAAA"/></a:solidFill></dsp:spPr><dsp:txBody><a:bodyPr/><a:p><a:r><a:t>Saved diagram</a:t></a:r></a:p></dsp:txBody></dsp:sp>
            </dsp:spTree></dsp:drawing>
            """.utf8))
        let id = slide.part.rels.add(type: "http://schemas.microsoft.com/office/2007/relationships/diagramDrawing", target: "../diagrams/drawing1.xml")
        let data = try deck.package.part(at: PackURI("/ppt/diagrams/data1.xml"))
        try data.dom().appendElement(parse("<dgm:extLst><a:ext uri=\"drawing\"><dsp:dataModelExt xmlns:dsp=\"http://schemas.microsoft.com/office/drawing/2008/diagram\" relId=\"\(id)\"/></a:ext></dgm:extLst>"))
        data.markDirty()
        let bytes = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.svg.contains("Saved diagram") && !result.svg.contains("[SmartArt]"))
        #expect(result.svg.contains("data-rostrum-diagram=\"cached\" transform=\"translate(914400 914400)\""))
        #expect(!result.problems.fidelityIssues.contains { $0.code == .graphicPlaceholder })
        #expect(try deck.serializedData() == bytes)
        #expect(try Presentation(data: bytes).renderSVG(slideAt: 0) == result.svg)
        drawing.replaceBlob(Data("<broken/>".utf8))
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .graphicPlaceholder })
    }

    @Test func masterPlaceholderBodyAndFooterStyleReachSharedTextLayout() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let master = try #require(slide.master).part
        let layout = try #require(slide.layout).part
        func placeholder(_ type: String, index: Int, body: String) throws -> XML.Element {
            try parse("<p:sp><p:nvSpPr><p:cNvPr id=\"50\"/><p:nvPr><p:ph type=\"\(type)\" idx=\"\(index)\"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody>\(body)</p:txBody></p:sp>")
        }
        try #require(Slide.existingSpTree(of: master)).appendElement(placeholder("ftr", index: 3, body: "<a:bodyPr anchor=\"ctr\"/><a:lstStyle><a:lvl1pPr><a:defRPr sz=\"1200\"><a:latin typeface=\"Footer Face\"/></a:defRPr></a:lvl1pPr></a:lstStyle>"))
        try #require(Slide.existingSpTree(of: layout)).appendElement(placeholder("ftr", index: 11, body: "<a:bodyPr lIns=\"127000\"/><a:lstStyle/>"))
        let shape = try placeholder("ftr", index: 11, body: "<a:bodyPr/><a:p><a:r><a:t>Footer</a:t></a:r></a:p>")
        let styles = RichTextLayout.inheritedStyles(for: shape, owner: slide.part, package: deck.package)
        let measured = RichTextLayout(textBody: try #require(shape.firstChild(named: "p:txBody")), width: 200, height: 100, inheritedStyles: styles)
        let span = try #require(measured.lines.first?.spans.first)
        #expect(span.run.fontFamily == "Footer Face" && span.run.fontSize == 12)
        #expect(span.x == 10)
        #expect(measured.lines[0].baseline > 40 && measured.lines[0].baseline < 60)
    }

    @Test func alignedBulletsTravelWithTheirText() throws {
        func layout(_ alignment: String) throws -> RichTextLayout {
            RichTextLayout(textBody: try parse("<p:txBody><a:bodyPr/><a:p><a:pPr algn=\"\(alignment)\" marL=\"254000\" indent=\"-127000\"><a:buChar char=\"•\"/></a:pPr><a:r><a:t>Text</a:t></a:r></a:p></p:txBody>"), width: 400, height: 200)
        }
        let left = try layout("l").lines[0].spans
        for alignment in ["r", "ctr"] {
            let moved = try layout(alignment).lines[0].spans
            #expect(abs((moved[0].x - left[0].x) - (moved[1].x - left[1].x)) < 0.001)
            #expect(moved[0].x > left[0].x)
        }
    }

    @Test func bulletUsesTextSizeButNotItsUnderlineOrBaselineShift() throws {
        let body = try parse("""
        <p:txBody><a:bodyPr/><a:p><a:pPr><a:buChar char="•"/></a:pPr><a:r><a:rPr sz="2400" u="sng" baseline="30000"/><a:t>Label</a:t></a:r></a:p></p:txBody>
        """)
        let spans = RichTextLayout(textBody: body, width: 400, height: 200).lines[0].spans
        #expect(spans[0].run.fontSize == spans[1].run.fontSize)
        #expect(spans[0].run.decoration.isEmpty && spans[0].run.baselineShift == 0)
        #expect(spans[1].run.decoration == "underline" && spans[1].run.baselineShift != 0)
    }

    @Test func svgOnlyPicturesResolveAndUnsafeSourcesRemainPreserved() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><path fill=\"#F5CDCE\" d=\"M0 0 L100 0 L100 100 Z\"/></svg>"
        let part = deck.package.addPart(uri: PackURI("/ppt/media/vector.svg"), contentType: "image/svg+xml", blob: Data(svg.utf8))
        let id = slide.part.rels.add(type: RelType.image, target: "../media/vector.svg")
        let pic = try parse("<p:pic><p:nvPicPr><p:cNvPr id=\"3\" name=\"Vector\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip><a:extLst><a:ext uri=\"svg\"><asvg:svgBlip xmlns:asvg=\"http://schemas.microsoft.com/office/drawing/2016/SVG/main\" r:embed=\"\(id)\"/></a:ext></a:extLst></a:blip><a:stretch/></p:blipFill><p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"914400\" cy=\"914400\"/></a:xfrm></p:spPr></p:pic>")
        try #require(Slide.existingSpTree(of: slide.part)).appendElement(pic)
        slide.part.markDirty()
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.svg.contains("data:image/svg+xml;base64,"))
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).renderSVG(slideAt: 0) == result.svg)
        for content in ["<script>alert(1)</script>", "<image href=\"https://example.com/a.png\"/>", "<style>@import 'https://example.com/a.css';</style>", "<path onload=\"alert(1)\"/>"] {
            let unsafe = svg.replacingOccurrences(of: "</svg>", with: content + "</svg>")
            part.replaceBlob(Data(unsafe.utf8))
            let blocked = try deck.renderSVGReportingProblems(slideAt: 0)
            #expect(blocked.problems.fidelityIssues.contains { $0.code == .unsupportedImage })
            #expect(!blocked.svg.contains("data:image/svg+xml"))
            #expect(part.blob == Data(unsafe.utf8))
        }
    }

}
