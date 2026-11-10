import Foundation
import Testing
@testable import Rostrum

@Suite struct GroupFillRenderTests {
    private func member(_ id: Int) -> String {
        """
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="Member"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="100" y="200"/><a:ext cx="400" cy="200"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:grpFill/></p:spPr></p:sp>
        """
    }

    private func group(_ fill: String, _ children: String) -> String {
        """
        <p:grpSp><p:nvGrpSpPr><p:cNvPr id="2" name="Group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1000" cy="1000"/>
        <a:chOff x="0" y="0"/><a:chExt cx="1000" cy="1000"/></a:xfrm>\(fill)</p:grpSpPr>\(children)</p:grpSp>
        """
    }

    private func append(_ xml: String, to part: Part) throws {
        let tree = try #require(Slide.existingSpTree(of: part))
        tree.appendElement(try XML.parse(Data(xml.utf8)))
        part.markDirty()
    }

    @Test func membersPaintWithTheNearestGroupFill() throws {
        let deck = try Presentation()
        let solid = "<a:solidFill><a:srgbClr val=\"336699\"/></a:solidFill>"
        // The inner group defers to the outer group; its member uses the outer fill.
        try append(group(solid, member(10) + group("<a:grpFill/>", member(11))), to: deck.slides[0].part)
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(result.svg.components(separatedBy: "fill=\"#336699\"").count - 1 == 2)
        #expect(try deck.serializedData() == before)
    }

    @Test func groupFillWithoutAGroupPaintsNothing() throws {
        let deck = try Presentation()
        try append(member(12).replacingOccurrences(of: "<a:grpFill/>", with: "<a:grpFill/><a:ln><a:solidFill><a:srgbClr val=\"112233\"/></a:solidFill></a:ln>"),
                   to: deck.slides[0].part)
        try append(group("", member(13)), to: deck.slides[0].part)
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("stroke=\"#112233\""))
        #expect(!svg.contains("fill=\"#000000\""))
    }

    @Test func groupGradientIsDiagnosedAsPaintedPerShape() throws {
        let deck = try Presentation()
        let gradient = "<a:gradFill><a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"FF0000\"/></a:gs><a:gs pos=\"100000\"><a:srgbClr val=\"0000FF\"/></a:gs></a:gsLst><a:lin ang=\"0\"/></a:gradFill>"
        try append(group(gradient, member(14)), to: deck.slides[0].part)
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.svg.contains("<linearGradient"))
        #expect(result.problems.fidelityIssues.contains { $0.code == .unsupportedFill && $0.location.shapeID == "14" })
    }
}
