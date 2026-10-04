import Foundation
import Testing
@testable import Rostrum

@Suite struct InheritedMarkerProjectionTests {
    private func fixture(_ styleXML: String, text: String = "A B C") throws -> (Presentation, Shape, XML.Element) {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let box = try slide.shapes.addTextBox(.init(x: .points(0), y: .points(0), width: .points(180), height: .points(120)))
        box.textFrame?.text = text
        let master = try #require(slide.master).part
        let style = try master.dom().getOrAddChild("p:txStyles").getOrAddChild("p:otherStyle")
        let source = try XML.parse(Data(styleXML.utf8))
        style.attributes = source.attributes; style.children = source.children
        master.markDirty()
        return (deck, box, style)
    }

    @Test func noneOnlyMasterDoesNotCopyAnySubtree() throws {
        let (deck, box, style) = try fixture("<p:otherStyle><a:lvl1pPr><a:buNone/><a:defRPr sz=\"1400\"/></a:lvl1pPr></p:otherStyle>")
        let level = try #require(style.firstChild(named: "a:lvl1pPr"))
        let unknown = XML.Element("future:payload", attributes: [("xmlns:future", "urn:marker-test")])
        for index in 0..<576 { unknown.appendElement(XML.Element("future:value", attributes: [("n", String(index))], children: [.text("preserve")])) }
        level.appendElement(unknown)
        let before = try deck.serializedData()
        let projected = RichTextLayout.inheritedStyles(for: box.element, owner: box.part, package: deck.package)
        #expect(projected.last === style)
        #expect(projected.last?.firstChild(named: "a:lvl1pPr")?.firstChild(named: "future:payload") === unknown)
        let measured = RichTextLayout(textBody: try #require(box.textFrame?.txBody), width: 180, height: 120, inheritedStyles: projected)
        #expect(measured.lines.flatMap(\.spans).map(\.run.text).joined() == "A B C")
        #expect(try deck.serializedData() == before)
    }

    @Test(arguments: [false, true])
    func noneOnlyMasterIsEquivalentAcrossLocalPrecedence(registered: Bool) throws {
        let (deck, box, style) = try fixture("""
        <p:otherStyle><a:defPPr><a:buNone/><a:defRPr sz="1800"/></a:defPPr>
        <a:lvl1pPr><a:buNone/><a:buNone/><a:defRPr sz="1400"/></a:lvl1pPr>
        <a:lvl2pPr marL="254000"><a:buNone/><a:defRPr sz="1600"/></a:lvl2pPr>
        <a:lvl9pPr><a:buNone/><a:defRPr sz="2000"/></a:lvl9pPr></p:otherStyle>
        """)
        if registered { try deck.fonts.register(FontFaceTests.font(400, bold: false, italic: false)) }
        // Frozen old behavior removed every buNone from a private deep copy.
        // Compare that result against retaining this final-tier no-op for all
        // competing local activation/suppression choices, including duplicates.
        let withoutNone = style.deepCopy()
        for level in withoutNone.childElements { level.removeChildren(named: "a:buNone") }
        let choices = ["", "<a:buChar char=\"•\"/>", "<a:buAutoNum type=\"arabicPeriod\" startAt=\"12\"/>", "<a:buNone/>",
                       "<a:buChar char=\"•\"/><a:buNone/>", "<a:buNone/><a:buChar char=\"•\"/>",
                       "<a:buAutoNum type=\"arabicPeriod\"/><a:buChar char=\"•\"/>"]
        for level in [0, 1, 8] {
            for ownChoice in choices {
                for listChoice in ["", "<a:buChar char=\"•\"/>", "<a:buNone/>"] {
                    let body = try XML.parse(Data("""
                    <p:txBody><a:bodyPr/><a:lstStyle><a:lvl\(level + 1)pPr>\(listChoice)</a:lvl\(level + 1)pPr></a:lstStyle>
                    <a:p><a:pPr lvl="\(level)">\(ownChoice)</a:pPr><a:r><a:t>A B C</a:t></a:r></a:p></p:txBody>
                    """.utf8))
                    let selected = RichTextLayout.inheritedStyles(for: box.element, owner: box.part, package: deck.package)
                    let current = RichTextLayout(textBody: body, width: 180, height: 120, fonts: registered ? deck.fonts : nil, inheritedStyles: selected)
                    let previous = RichTextLayout(textBody: body, width: 180, height: 120, fonts: registered ? deck.fonts : nil, inheritedStyles: [withoutNone])
                    #expect(current.lines == previous.lines && current.diagnostics == previous.diagnostics && current.contentHeight == previous.contentHeight)
                }
            }
        }
    }

    @Test(arguments: [false, true], ["A B C", "α β γ"])
    func projectionPreservesPropertiesUnknownPayloadAndLiveEdits(registered: Bool, text: String) throws {
        let (deck, box, style) = try fixture("""
        <p:otherStyle xmlns:future="urn:marker-test" future:flag="keep">
          <a:lvl1pPr marL="254000" indent="-127000" algn="r">
            <a:lnSpc><a:spcPct val="100000"/></a:lnSpc><a:spcAft><a:spcPts val="300"/></a:spcAft>
            <a:buSzPct val="75000"/><a:buFont typeface="DejaVu Serif"/><a:buChar char="•"/>
            <a:tabLst><a:tab pos="508000" algn="l"/></a:tabLst>
            <a:defRPr sz="1400" kern="0"><a:solidFill><a:srgbClr val="123456"/></a:solidFill><a:latin typeface="LiveAlias"/></a:defRPr>
            <a:extLst><a:ext uri="owned"><future:payload><future:value>unchanged</future:value></future:payload></a:ext></a:extLst>
          </a:lvl1pPr>
          <a:lvl2pPr marL="508000"><a:buNone/><a:defRPr sz="2200"/></a:lvl2pPr>
          <future:root><a:buChar char="unknown must survive"/></future:root>
        </p:otherStyle>
        """, text: text)
        if registered { try deck.fonts.register(FontFaceTests.font(400, bold: false, italic: false), aliases: ["LiveAlias"]) }
        let level = try #require(style.firstChild(named: "a:lvl1pPr"))
        let defaults = try #require(level.firstChild(named: "a:defRPr"))
        let unknown = try #require(level.firstChild(named: "a:extLst"))
        let untouched = try #require(style.firstChild(named: "a:lvl2pPr"))
        style.attributes.append(("future:flag", "duplicate-preserved"))
        level.attributes.append(("future:attribute", "first"))
        level.attributes.append(("future:attribute", "second"))
        level.children.insert(.comment("keep marker-adjacent comment"), at: 0)
        level.children.append(.processingInstruction(target: "owned", data: "preserve"))
        level.children.append(.text("trailing text"))
        let before = try deck.serializedData()
        func measure() throws -> RichTextLayout {
            RichTextLayout(textBody: try #require(box.textFrame?.txBody), width: 180, height: 120,
                fonts: registered ? deck.fonts : nil,
                inheritedStyles: RichTextLayout.inheritedStyles(for: box.element, owner: box.part, package: deck.package))
        }
        let first = try measure()
        do {
            let projected = try #require(RichTextLayout.inheritedStyles(for: box.element, owner: box.part, package: deck.package).last)
            let resultLevel = try #require(projected.firstChild(named: "a:lvl1pPr"))
            #expect(projected !== style && resultLevel !== level)
            #expect(resultLevel.firstChild(named: "a:buChar") == nil && resultLevel.firstChild(named: "a:buSzPct") == nil && resultLevel.firstChild(named: "a:buFont") == nil)
            #expect(resultLevel.firstChild(named: "a:defRPr") === defaults)
            #expect(resultLevel.firstChild(named: "a:extLst") === unknown)
            #expect(projected.firstChild(named: "a:lvl2pPr") === untouched)
            #expect(projected.firstChild(named: "future:root") === style.firstChild(named: "future:root"))
            #expect(resultLevel[attribute: "marL"] == "254000" && resultLevel[attribute: "algn"] == "r")
            #expect(projected[attribute: "future:flag"] == "keep")
            #expect(projected.attributes.map { $0.name + "=" + $0.value } == style.attributes.map { $0.name + "=" + $0.value })
            #expect(resultLevel.attributes.map { $0.name + "=" + $0.value } == level.attributes.map { $0.name + "=" + $0.value })
            #expect(resultLevel.serialized().contains("<!--keep marker-adjacent comment-->"))
            #expect(resultLevel.serialized().contains("<?owned preserve?>"))
            #expect(resultLevel.serialized().contains("trailing text"))
        }
        #expect(first.lines.flatMap(\.spans).map(\.run.text).joined() == text)
        #expect(first.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 14 && $0.run.fontFamily == "LiveAlias" && $0.run.color == "#123456" })
        #expect(try deck.serializedData() == before)
        // A separate raw style with only the chosen ordinary properties is an
        // independent equality control for positions, metrics and diagnostics.
        let expected = try XML.parse(Data("""
        <p:otherStyle><a:lvl1pPr marL="254000" indent="-127000" algn="r"><a:lnSpc><a:spcPct val="100000"/></a:lnSpc><a:spcAft><a:spcPts val="300"/></a:spcAft><a:tabLst><a:tab pos="508000" algn="l"/></a:tabLst><a:defRPr sz="1400" kern="0"><a:solidFill><a:srgbClr val="123456"/></a:solidFill><a:latin typeface="LiveAlias"/></a:defRPr></a:lvl1pPr></p:otherStyle>
        """.utf8))
        let control = RichTextLayout(textBody: try #require(box.textFrame?.txBody), width: 180, height: 120,
            fonts: registered ? deck.fonts : nil, inheritedStyles: [expected])
        #expect(first.lines == control.lines && first.diagnostics == control.diagnostics && first.contentHeight == control.contentHeight)
        defaults[attribute: "sz"] = "2000"
        level[attribute: "algn"] = "l"
        let second = try measure()
        #expect(second.lines != first.lines)
        #expect(second.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 20 })
        if registered && text == "A B C" {
            try deck.fonts.register(FontFaceTests.font(700, bold: false, italic: false), aliases: ["LiveAlias"])
            let rebound = try measure()
            #expect(rebound.lines[0].width > second.lines[0].width)
            #expect(rebound.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 20 && $0.run.fontFamily == "LiveAlias" })
        }
        #expect(level.firstChild(named: "a:buChar")?[attribute: "char"] == "•")
        #expect(unknown.serialized().contains("unchanged"))
        #expect(first.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 14 })
    }
}
