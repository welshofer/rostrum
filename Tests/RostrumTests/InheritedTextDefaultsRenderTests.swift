import Foundation
import Testing
@testable import Rostrum

@Suite struct InheritedTextDefaultsRenderTests {
    private func textBox(_ id: Int, text: String, runProperties: String = "") -> String {
        """
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="Text"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="3657600" cy="914400"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US">\(runProperties)</a:rPr><a:t>\(text)</a:t></a:r></a:p></p:txBody></p:sp>
        """
    }

    private func append(_ xml: String, to part: Part) throws {
        let tree = try #require(Slide.existingSpTree(of: part))
        tree.appendElement(try XML.parse(Data(xml.utf8)))
        part.markDirty()
    }

    @Test func masterArtworkTextUsesTheMasterOtherStyle() throws {
        let deck = try Presentation()
        let layout = try #require(try deck.slides[0].layout).part
        let master = try layout.related(by: RelType.slideMaster, in: deck.package)
        let level = try #require(master.dom().firstChild(named: "p:txStyles")?.firstChild(named: "p:otherStyle")?
            .firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr"))
        level[attribute: "sz"] = "3600"
        master.markDirty()
        try append(textBox(70, text: "Furniture"), to: master)
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        // Before, master and layout text fell back to the renderer's own size.
        #expect(svg.contains("font-size=\"36\""))
        #expect(try deck.serializedData() == before)
    }

    @Test func presentationDefaultTextStyleIsTheBaseOfTheSlideChain() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let defaults = try XML.parse(Data("""
        <p:defaultTextStyle><a:lvl1pPr><a:defRPr><a:solidFill><a:srgbClr val="C04000"/></a:solidFill></a:defRPr></a:lvl1pPr></p:defaultTextStyle>
        """.utf8))
        try deck.presentationPart.dom().insertChild(defaults, beforeAnyOf: ["p:modifyVerifier", "p:extLst"])
        deck.presentationPart.markDirty()
        try append(textBox(71, text: "Inherited"), to: slide.part)
        try append(textBox(72, text: "Own", runProperties: "<a:solidFill><a:srgbClr val=\"0070C0\"/></a:solidFill>"), to: slide.part)
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("fill=\"#C04000\""))
        #expect(svg.contains("fill=\"#0070C0\""))
        // The master's own size still wins over the presentation default.
        #expect(svg.contains("font-size=\"18\""))
        #expect(try deck.serializedData() == before)
    }
}
