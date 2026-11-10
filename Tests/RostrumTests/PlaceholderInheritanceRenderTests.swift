import Foundation
import Testing
@testable import Rostrum

@Suite struct PlaceholderInheritanceRenderTests {
    private let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

    private func append(_ xml: String, to part: Part) throws {
        let tree = try #require(Slide.existingSpTree(of: part))
        tree.appendElement(try XML.parse(Data(xml.utf8)))
        part.markDirty()
    }

    private func layoutPlaceholder(idx: Int, type: String, properties: String) -> String {
        """
        <p:sp><p:nvSpPr><p:cNvPr id="\(idx)" name="Slot"/><p:cNvSpPr/><p:nvPr><p:ph type="\(type)" idx="\(idx)"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="1828800" cy="1828800"/></a:xfrm>\(properties)</p:spPr></p:sp>
        """
    }

    @Test func pictureInPlaceholderTakesLayoutFrameGeometryAndLine() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let layout = try #require(slide.layout).part
        try append(layoutPlaceholder(idx: 913, type: "pic", properties:
            "<a:prstGeom prst=\"ellipse\"><a:avLst/></a:prstGeom><a:ln w=\"25400\"><a:solidFill><a:srgbClr val=\"123456\"/></a:solidFill></a:ln>"),
            to: layout)
        let picture = try slide.shapes.addPicture(png, frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)))
        let nvPr = try #require(picture.element.firstChild(named: "p:nvPicPr")?.firstChild(named: "p:nvPr"))
        nvPr.appendElement(XML.Element("p:ph", attributes: [("type", "pic"), ("idx", "913")]))
        let spPr = try #require(picture.element.firstChild(named: "p:spPr"))
        spPr.children.removeAll { node in
            if case .element(let element) = node { return ["a:xfrm", "a:prstGeom"].contains(element.name) }
            return false
        }
        slide.part.markDirty()
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(result.svg.contains("<ellipse"))
        #expect(result.svg.contains("stroke=\"#123456\""))
        #expect(result.svg.contains("url(#"))
        #expect(try deck.serializedData() == before)
    }

    @Test func shapePlaceholderTakesLayoutFillAndDiagnosesItsGeometryAtTheLayout() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let layout = try #require(slide.layout).part
        try append(layoutPlaceholder(idx: 921, type: "body", properties:
            "<a:prstGeom prst=\"star5\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"ABCDEF\"/></a:solidFill>"),
            to: layout)
        try append("""
        <p:sp><p:nvSpPr><p:cNvPr id="50" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="921"/></p:nvPr></p:nvSpPr>
        <p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>
        """, to: slide.part)
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.svg.contains("fill=\"#ABCDEF\""))
        let geometry = result.problems.fidelityIssues.filter { $0.code == .unsupportedGeometry }
        #expect(geometry.count == 1)
        #expect(geometry.first?.location.partURI == layout.uri.description)
        #expect(geometry.first?.location.path.hasSuffix("/p:spPr[1]/a:prstGeom[1]") == true)
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func ownPropertiesStillWinOverTheLayout() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let layout = try #require(slide.layout).part
        try append(layoutPlaceholder(idx: 922, type: "body", properties:
            "<a:prstGeom prst=\"ellipse\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"ABCDEF\"/></a:solidFill>"),
            to: layout)
        try append("""
        <p:sp><p:nvSpPr><p:cNvPr id="51" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="922"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="FEDCBA"/></a:solidFill></p:spPr></p:sp>
        """, to: slide.part)
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("fill=\"#FEDCBA\""))
        #expect(!svg.contains("#ABCDEF"))
        #expect(!svg.contains("<ellipse"))
    }

    @Test func effectiveFrameStillFallsBackThroughLayoutAndMaster() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let layout = try #require(slide.layout).part
        try append(layoutPlaceholder(idx: 923, type: "body", properties: ""), to: layout)
        try append("""
        <p:sp><p:nvSpPr><p:cNvPr id="52" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="923"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>
        """, to: slide.part)
        let shape = try #require(slide.shapes.all.last)
        #expect(slide.effectiveFrame(of: shape) == Rect(x: EMU(914400), y: EMU(914400), width: EMU(1828800), height: EMU(1828800)))
        #expect(slide.inheritedPlaceholders(of: shape).first?.part === layout)
    }
}
