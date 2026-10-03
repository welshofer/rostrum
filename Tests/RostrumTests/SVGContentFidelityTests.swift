import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGContentFidelityTests {
    private func xml(_ s: String) throws -> XML.Element { try XML.parse(Data(s.utf8)) }
    private func rich(_ paragraphs: String, width: Int = 3_000_000, properties: String = "") throws -> String {
        let deck = try Presentation()
        return SVGRichText(theme: deck.theme, fonts: FontLibrary(), slideNumber: 4).render(
            try xml("<p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\" \(properties)/><a:lstStyle/>\(paragraphs)</p:txBody>"),
            frame: (0, 0, width, 3_000_000), inherited: [], reference: nil)
    }
    @Test func mixedRunTypographySurvivesWrappingAndHardBreaks() throws {
        let svg = try rich("""
        <a:p><a:r><a:rPr sz="1800"/><a:t>Normal </a:t></a:r><a:r><a:rPr sz="2400" b="1" i="1" u="sng"><a:solidFill><a:srgbClr val="CC2200"/></a:solidFill></a:rPr><a:t>Emphasis wraps across lines</a:t></a:r><a:br/><a:r><a:rPr baseline="30000"/><a:t>Raised</a:t></a:r></a:p>
        """, width: 1_600_000)
        #expect(svg.contains("font-style=\"italic\""))
        #expect(svg.contains("text-decoration=\"underline\""))
        #expect(svg.contains("baseline-shift=\"30.0%\""))
        #expect(svg.contains("fill=\"#CC2200\""))
        #expect(svg.components(separatedBy: "<text ").count > 3)
        #expect(svg.contains(">Raised</tspan>"))
        _ = try xml("<svg>\(svg)</svg>")
    }
    @Test func numberedParagraphsRetainIndentAndSpacing() throws {
        let svg = try rich("""
        <a:p><a:pPr marL="254000" indent="-127000"><a:buAutoNum type="arabicPeriod" startAt="3"/><a:spcAft><a:spcPts val="1200"/></a:spcAft></a:pPr><a:r><a:t>First</a:t></a:r></a:p>
        <a:p><a:pPr marL="254000" indent="-127000"><a:buAutoNum type="arabicPeriod"/></a:pPr><a:r><a:t>Second</a:t></a:r></a:p>
        """)
        #expect(svg.contains(">3.</text>")); #expect(svg.contains(">4.</text>"))
        #expect(svg.contains("x=\"10.0\"")); #expect(svg.contains("x=\"20.0\""))
        #expect(svg.contains("y=\"51.599999999999994\"") || svg.contains("y=\"51.6\""))
    }
    @Test func cropUsesSavedAsymmetricSourceAndDestination() throws {
        let svg = try #require(SVGImagePlacement.render(xml("<p:blipFill><a:srcRect l=\"25000\" r=\"0\"/><a:stretch><a:fillRect l=\"10000\" r=\"15000\"/></a:stretch></p:blipFill>"), data: "data:image/png;base64,AA==", width: 400, height: 200))
        #expect(svg.contains("x=\"-60.0\""))
        #expect(svg.contains("width=\"400.0\" height=\"200.0\" preserveAspectRatio=\"none\""))
        #expect(svg.contains("overflow=\"hidden\""))
    }
    @Test func impossibleCropIsRejectedAndNegativeMarginsAreSupported() throws {
        #expect(try SVGImagePlacement.render(xml("<p:blipFill><a:srcRect l=\"50000\" r=\"50000\"/></p:blipFill>"), data: "x", width: 400, height: 200) == nil)
        let svg = try #require(SVGImagePlacement.render(xml("<p:blipFill><a:srcRect l=\"-50000\" r=\"-50000\"/></p:blipFill>"), data: "x", width: 400, height: 200))
        #expect(svg.contains("x=\"100.0\"")); #expect(svg.contains("width=\"200.0\""))
    }
    @Test func mergedCellsDoNotPaintOverOriginAndDirectBordersSurvive() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(2)))
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        try table.cell(0, 0).text = "Merged"
        let tc = try table.cell(0, 0).tc
        tc.removeChildren(named: "a:tcPr")
        tc.appendElement(try xml("<a:tcPr marL=\"254000\" anchor=\"ctr\"><a:solidFill><a:srgbClr val=\"126789\"/></a:solidFill><a:lnB w=\"38100\"><a:solidFill><a:srgbClr val=\"ABCDEF\"/></a:solidFill><a:prstDash val=\"dash\"/></a:lnB></a:tcPr>"))
        try deck.slides[0].part.markDirty()
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("width=\"5486400\" height=\"1828800\" fill=\"#126789\""))
        #expect(svg.components(separatedBy: "fill=\"#126789\"").count == 2)
        #expect(svg.contains("stroke=\"#ABCDEF\" stroke-width=\"38100\" stroke-dasharray=\"152400 114300\""))
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).renderSVG(slideAt: 0) == svg)
    }
    @Test func chartSeriesPointOverridesAndHiddenLegendSurvive() throws {
        let deck = try Presentation()
        try deck.chartSlide("Chart", .barClustered, ChartData(categories: ["A", "B"], series: [.init(name: "HiddenOne", values: [1, 2]), .init(name: "HiddenTwo", values: [3, 4])]))
        let chart = try #require(deck.slides[1].charts.first)
        let root = try #require(chart.root?.firstChild(named: "c:chart"))
        root.removeChildren(named: "c:legend")
        let ser = try #require(chart.seriesElements.first)
        ser.removeChildren(named: "c:spPr")
        ser.appendElement(try xml("<c:spPr><a:solidFill><a:srgbClr val=\"12AB34\"/></a:solidFill></c:spPr>"))
        ser.appendElement(try xml("<c:dPt><c:idx val=\"1\"/><c:spPr><a:solidFill><a:srgbClr val=\"FE3210\"/></a:solidFill></c:spPr></c:dPt>"))
        chart.part.markDirty()
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 1)
        #expect(svg.contains("fill=\"#12AB34\"")); #expect(svg.contains("fill=\"#FE3210\""))
        #expect(!svg.contains("HiddenOne")); #expect(!svg.contains("HiddenTwo"))
        #expect(try deck.serializedData() == before)
    }
    @Test func lineChartUsesSavedStrokeWidthAndDash() throws {
        let deck = try Presentation()
        try deck.chartSlide("Line", .line, ChartData(categories: ["A", "B"], name: "s", values: [2, 3]))
        let chart = try #require(deck.slides[1].charts.first)
        try #require(chart.seriesElements.first).removeChildren(named: "c:spPr")
        try #require(chart.seriesElements.first).appendElement(xml("<c:spPr><a:ln w=\"63500\"><a:solidFill><a:srgbClr val=\"BE1200\"/></a:solidFill><a:prstDash val=\"dot\"/></a:ln></c:spPr>"))
        chart.part.markDirty()
        let svg = try deck.renderSVG(slideAt: 1)
        #expect(svg.contains("stroke=\"#BE1200\" stroke-width=\"63500\" stroke-dasharray=\"63500 190500\""))
    }
    @Test func explicitTableStyleBoldAndItalicFlagsAreApplied() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(2)))
        try table.cell(0, 0).text = "Styled header"
        let pr = try #require(table.tbl.firstChild(named: "a:tblPr"))
        pr.removeChildren(named: "a:tableStyleId")
        pr.appendElement(try xml("<a:tableStyleId>test-style</a:tableStyleId>"))
        let styleXML = "<a:tblStyleLst><a:tblStyle styleId=\"test-style\"><a:wholeTbl><a:tcTxStyle b=\"on\" i=\"on\"><a:srgbClr val=\"CC1200\"/></a:tcTxStyle></a:wholeTbl><a:firstRow><a:tcTxStyle b=\"def\"/></a:firstRow></a:tblStyle></a:tblStyleLst>"
        deck.package.addPart(uri: PackURI("/ppt/testStyles.xml"), contentType: ContentType.tableStyles, blob: Data(styleXML.utf8))
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("font-weight=\"bold\"")); #expect(svg.contains("font-style=\"italic\""))
        #expect(svg.contains("fill=\"#CC1200\""))
    }
    @Test func borderOnlyPointKeepsSeriesFill() throws {
        let deck = try Presentation()
        try deck.chartSlide("Chart", .barClustered, ChartData(categories: ["A"], name: "s", values: [3]))
        let chart = try #require(deck.slides[1].charts.first)
        let ser = try #require(chart.seriesElements.first)
        ser.removeChildren(named: "c:spPr")
        ser.appendElement(try xml("<c:spPr><a:solidFill><a:srgbClr val=\"15AB35\"/></a:solidFill></c:spPr>"))
        ser.appendElement(try xml("<c:dPt><c:idx val=\"0\"/><c:spPr><a:ln w=\"12700\"/></c:spPr></c:dPt>"))
        chart.part.markDirty()
        #expect(try deck.renderSVG(slideAt: 1).contains("fill=\"#15AB35\""))
    }
    @Test func fixedAxisLineIsClippedAndLegendMatchesStroke() throws {
        let deck = try Presentation()
        try deck.chartSlide("Chart", .line, ChartData(categories: ["A", "B"], name: "Series", values: [2, 30]))
        let chart = try #require(deck.slides[1].charts.first)
        let ser = try #require(chart.seriesElements.first)
        ser.removeChildren(named: "c:spPr")
        ser.appendElement(try xml("<c:spPr><a:ln><a:solidFill><a:srgbClr val=\"FA1200\"/></a:solidFill></a:ln></c:spPr>"))
        let chartNode = try #require(chart.root?.firstChild(named: "c:chart"))
        chartNode.appendElement(try xml("<c:legend><c:legendPos val=\"r\"/></c:legend>"))
        let axis = try #require(chartNode.firstChild(named: "c:plotArea")?.firstChild(named: "c:valAx"))
        let scaling = try #require(axis.firstChild(named: "c:scaling"))
        scaling.appendElement(try xml("<c:max val=\"10\"/>"))
        chart.part.markDirty()
        let svg = try deck.renderSVG(slideAt: 1)
        #expect(svg.contains("overflow=\"hidden\"><polyline"))
        #expect(svg.contains("fill=\"#FA1200\""))
        #expect(svg.contains(">10</text>"))
    }
    @Test func continuationUsesFullWidthAfterIndentedFirstLine() throws {
        let svg = try rich("<a:p><a:pPr indent=\"889000\"><a:defRPr sz=\"1000\"/></a:pPr><a:r><a:t>Hi longerword</a:t></a:r></a:p>", width: 1_270_000)
        #expect(svg.contains(">longerword</tspan>"))
    }

    @Test func oversizedFirstWordUsesWiderContinuationLines() throws {
        let svg = try rich("<a:p><a:pPr indent=\"889000\"><a:defRPr sz=\"1000\"/></a:pPr><a:r><a:t>abcdefghijklmnop</a:t></a:r></a:p>", width: 1_270_000)
        #expect(svg.components(separatedBy: "<text ").count == 3)
    }

    @Test func explicitNoWrapRetainsSingleRichTextLine() throws {
        let svg = try rich("<a:p><a:r><a:t>A much longer sentence than the frame</a:t></a:r></a:p>", width: 254_000, properties: "wrap=\"none\"")
        #expect(svg.components(separatedBy: "<text ").count == 2)
    }
    @Test func overflowingNoWrapRetainsCenterAndRightAnchors() throws {
        var offsets: [Double] = []
        for alignment in ["ctr", "r"] {
            let svg = try rich("<a:p><a:pPr algn=\"\(alignment)\"/><a:r><a:t>A much longer sentence than the frame</a:t></a:r></a:p>", width: 254_000, properties: "wrap=\"none\"")
            let text = try #require(xml("<svg>\(svg)</svg>").firstChild(named: "g")?.firstChild(named: "text"))
            offsets.append(try #require(Double(text[attribute: "x"] ?? "")))
        }
        #expect(offsets[0] < 0)
        #expect(abs(offsets[1] - offsets[0] * 2) < 0.001)
    }
    @Test func horizontalChartCategoriesUseTheLeftEdge() throws {
        let deck = try Presentation()
        try deck.chartSlide("Chart", .barClustered, ChartData(categories: ["CategoryA", "CategoryB"], name: "s", values: [2, 4]))
        let chart = try #require(deck.slides[1].charts.first)
        try #require(chart.plots.first?.firstChild(named: "c:barDir"))[attribute: "val"] = "bar"
        let svg = try deck.renderSVG(slideAt: 1)
        let texts = try xml(svg).children(named: "text")
        let labels = texts.filter { $0.textContent == "CategoryA" || $0.textContent == "CategoryB" }
        #expect(labels.count == 2)
        #expect(labels.allSatisfy { $0[attribute: "text-anchor"] == "end" })
        #expect(labels[0][attribute: "transform"] != labels[1][attribute: "transform"])
    }
    @Test func effectOnlyGridStyleRetainsVisibleDefault() throws {
        let deck = try Presentation()
        try deck.chartSlide("Chart", .line, ChartData(categories: ["A", "B"], name: "s", values: [2, 4]))
        let chart = try #require(deck.slides[1].charts.first)
        let axis = try #require(chart.root?.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea")?.firstChild(named: "c:valAx"))
        axis.removeChildren(named: "c:majorGridlines")
        axis.appendElement(try xml("<c:majorGridlines><c:spPr><a:effectLst/></c:spPr></c:majorGridlines>"))
        #expect(try deck.renderSVG(slideAt: 1).contains("stroke=\"#D9D9D9\" stroke-width=\"6350\""))
    }

}
