import Foundation
import Testing
@testable import Rostrum

@Suite struct LayoutAtomStyleTests {
    private func body(_ content: String) throws -> XML.Element {
        try XML.parse(Data("<p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\"/>\(content)</p:txBody>".utf8))
    }

    private func fonts() throws -> FontLibrary {
        let fonts = FontLibrary()
        try fonts.register(FontFaceTests.font(400, bold: false, italic: false), aliases: ["First"])
        try fonts.register(FontFaceTests.font(700, bold: true, italic: false), aliases: ["Second"])
        return fonts
    }

    @Test(arguments: [false, true])
    func emptyRunsTabsFieldsAndParagraphsKeepTheirOwnStyles(registered: Bool) throws {
        let xml = try body("""
        <a:p><a:pPr><a:tabLst><a:tab pos="508000"/></a:tabLst></a:pPr>
        <a:r><a:rPr sz="8000"/><a:t/></a:r>
        <a:r><a:rPr sz="1000"><a:latin typeface="First"/><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:rPr><a:t>A\tB</a:t></a:r>
        <a:r><a:rPr sz="7000" b="1"/><a:t/></a:r><a:br/>
        <a:fld type="slidenum"><a:rPr sz="2200" b="1"><a:latin typeface="Second"/><a:solidFill><a:srgbClr val="0000FF"/></a:solidFill></a:rPr><a:t>99</a:t></a:fld>
        <a:r><a:rPr sz="1400" i="1"><a:latin typeface="First"/></a:rPr><a:t>C</a:t></a:r></a:p>
        <a:p><a:r><a:rPr sz="900"><a:latin typeface="First"/><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill></a:rPr><a:t>D</a:t></a:r></a:p>
        """)
        let before = xml.serialized()
        let layout = RichTextLayout(textBody: xml, width: 200, height: 300,
            fonts: registered ? try fonts() : nil, slideNumber: 7)
        let spans = layout.lines.flatMap(\.spans)
        #expect(spans.map(\.run.text) == ["A", "B", "7", "C", "D"])
        #expect(spans.map(\.run.fontSize) == [10, 10, 22, 14, 9])
        #expect(spans.map(\.run.color) == ["#FF0000", "#FF0000", "#0000FF", "#1A1A1A", "#00FF00"])
        #expect(spans.map(\.run.fontFamily) == ["First", "First", "Second", "First", "First"])
        #expect(spans.map(\.run.bold) == [false, false, true, false, false])
        #expect(spans.map(\.run.italic) == [false, false, false, true, false])
        #expect(layout.lines.first?.spans.map(\.x) == [0, 40])
        #expect(xml.serialized() == before)
    }

    @Test(arguments: [false, true])
    func paragraphStyleStorageDoesNotOutliveDOMOrInheritanceEdits(registered: Bool) throws {
        let inherited = try XML.parse(Data("<a:lstStyle><a:lvl1pPr><a:defRPr sz=\"1200\"><a:latin typeface=\"First\"/></a:defRPr></a:lvl1pPr></a:lstStyle>".utf8))
        let xml = try body("""
        <a:p><a:r><a:rPr><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:rPr><a:t>AB CD EF GH IJ</a:t></a:r></a:p>
        <a:p><a:r><a:t>K</a:t></a:r></a:p>
        """)
        let registry = registered ? try fonts() : nil
        let before = xml.serialized(), inheritedBefore = inherited.serialized()
        let first = RichTextLayout(textBody: xml, width: 30, height: 500,
            fonts: registry, inheritedStyles: [inherited])
        #expect(first.lines.count > 2)
        #expect(first.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 12 })
        #expect(xml.serialized() == before && inherited.serialized() == inheritedBefore)

        let run = try #require(xml.firstChild(named: "a:p")?.firstChild(named: "a:r"))
        let properties = try #require(run.firstChild(named: "a:rPr"))
        properties[attribute: "sz"] = "900"
        properties[attribute: "b"] = "1"
        properties.children.append(.element(XML.Element("a:latin", attributes: [("typeface", "Second")])))
        try #require(properties.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr"))[attribute: "val"] = "00FF00"
        try #require(run.firstChild(named: "a:t")).children = [.text("LM NO PQ RS")]
        try #require(inherited.firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr"))[attribute: "sz"] = "1800"
        let edited = xml.serialized(), inheritedEdited = inherited.serialized()
        let second = RichTextLayout(textBody: xml, width: 30, height: 500,
            fonts: registry, inheritedStyles: [inherited])
        let spans = second.lines.flatMap(\.spans)
        #expect(spans.dropLast().map(\.run.text).joined() == "LM NO PQ RS")
        #expect(spans.dropLast().allSatisfy {
            $0.run.fontSize == 9 && $0.run.fontFamily == "Second" && $0.run.bold && $0.run.color == "#00FF00"
        })
        #expect(spans.last?.run.text == "K" && spans.last?.run.fontSize == 18)
        #expect(first.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 12 })
        #expect(xml.serialized() == edited && inherited.serialized() == inheritedEdited)
    }
}
