import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGShapeTreeTests {
    private func shape(_ id: Int = 10, x: Int = 100, y: Int = 200) -> String {
        """
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="Box"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="400" cy="200"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></p:spPr></p:sp>
        """
    }

    private func group(_ children: String, attrs: String = "", childWidth: Int = 1000) -> String {
        """
        <p:grpSp><p:nvGrpSpPr><p:cNvPr id="2" name="Group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr><a:xfrm \(attrs)><a:off x="1000" y="2000"/><a:ext cx="2000" cy="3000"/>
        <a:chOff x="100" y="200"/><a:chExt cx="\(childWidth)" cy="1000"/></a:xfrm></p:grpSpPr>\(children)</p:grpSp>
        """
    }

    private func connector(_ geometry: String = "line") -> String {
        """
        <p:cxnSp><p:nvCxnSpPr><p:cNvPr id="12" name="Connector"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>
        <p:spPr><a:xfrm flipV="1"><a:off x="100" y="100"/><a:ext cx="500" cy="300"/></a:xfrm>
        <a:prstGeom prst="\(geometry)"><a:avLst/></a:prstGeom><a:ln w="10"><a:solidFill><a:srgbClr val="0055AA"/></a:solidFill>
        <a:prstDash val="dash"/><a:headEnd type="oval"/><a:tailEnd type="triangle"/></a:ln></p:spPr></p:cxnSp>
        """
    }

    private func append(_ xml: String, to part: Part) throws {
        let tree = try #require(Slide.existingSpTree(of: part))
        tree.appendElement(try XML.parse(Data(xml.utf8)))
        part.markDirty()
    }

    @Test func nestedGroupsMapChildSpaceAndKeepPaintOrderWithoutEditingDeck() throws {
        let deck = try Presentation()
        try append(group(shape() + group(shape(11))), to: deck.slides[0].part)
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.svg.components(separatedBy: "translate(1000 2000) scale(2.0 3.0) translate(-100 -200)").count == 3)
        #expect(result.svg.components(separatedBy: "fill=\"#FF0000\"").count == 3)
        #expect(result.problems.isEmpty)
        #expect(try deck.serializedData() == before)
        _ = try XML.parse(Data(result.svg.utf8))
        #expect(try deck.renderSVG(slideAt: 0) == result.svg)
    }

    @Test func groupRotationAndBooleanFlipsAreComposedAboutOuterCenter() throws {
        let deck = try Presentation()
        try append(group(shape(), attrs: "rot=\"5400000\" flipH=\"true\" flipV=\"1\""), to: deck.slides[0].part)
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("translate(2000.0 3500.0) rotate(90.0) scale(-1 -1) translate(-2000.0 -3500.0)"))
        #expect(svg.contains("scale(2.0 3.0) translate(-100 -200)"))
    }

    @Test func groupedArtworkOnLayoutAndMasterIsVisible() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        try append(group(shape()), to: #require(slide.layout).part)
        try append(group(shape(20)), to: #require(slide.master).part)
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.svg.components(separatedBy: "fill=\"#FF0000\"").count == 3)
        #expect(result.problems.isEmpty)
    }

    @Test func flippedGroupsKeepTextReadableAsPowerPointDoes() throws {
        let deck = try Presentation()
        let text = "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Readable</a:t></a:r></a:p></p:txBody>"
        let withText = shape().replacingOccurrences(of: "</p:sp>", with: text + "</p:sp>")
        try append(group(withText, attrs: "flipH=\"1\""), to: deck.slides[0].part)
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("data-text-unflip=\"true\" transform=\"translate(300.0 300.0) scale(-1 1) translate(-300.0 -300.0)"))
        #expect(svg.contains("<text"))
    }

    @Test func connectorsKeepDirectionStrokeAndBothArrowheads() throws {
        let deck = try Presentation()
        try append(connector(), to: deck.slides[0].part)
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.svg.contains("x1=\"100\" y1=\"100\" x2=\"600\" y2=\"400\""))
        #expect(result.svg.contains("stroke=\"#0055AA\" stroke-width=\"10\""))
        #expect(result.svg.contains("stroke-dasharray=\"40 30\""))
        #expect(result.svg.contains("marker-start=") && result.svg.contains("marker-end="))
        #expect(result.svg.contains("scale(1 -1)"))
        #expect(result.problems.isEmpty)
        _ = try XML.parse(Data(result.svg.utf8))
    }

    @Test func approximatedAndOmittedContentIsReportedOnce() throws {
        let deck = try Presentation()
        try append(group(connector("curvedConnector3") + shape().replacingOccurrences(of: "prst=\"rect\"", with: "prst=\"star5\"")), to: deck.slides[0].part)
        try append(connector("bentConnector3"), to: deck.slides[0].part)
        try append("<p:contentPart/>", to: deck.slides[0].part)
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.unsupportedContent.count == 3)
        #expect(!result.problems.isEmpty)
        #expect(result.problems.messages.contains { $0.contains("curved connectors") })
    }

    @Test func malformedAndDeepGroupsStayBoundedAndExplainMissingContent() throws {
        let deck = try Presentation()
        try append(group(shape(), childWidth: 0), to: deck.slides[0].part)
        var nested = shape()
        for _ in 0..<70 { nested = group(nested) }
        try append(nested, to: deck.slides[0].part)
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.messages.contains { $0.contains("coordinate space") })
        #expect(result.problems.messages.contains { $0.contains("64 levels") })
        #expect(!result.svg.contains("inf") && !result.svg.contains("nan"))
        _ = try XML.parse(Data(result.svg.utf8))
    }
}
