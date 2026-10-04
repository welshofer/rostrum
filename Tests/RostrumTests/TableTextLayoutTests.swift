import Foundation
import Testing
@testable import Rostrum

@Suite struct TableTextLayoutTests {
    @Test func cellGeometryOverridesPreserveAutofitWrappingAndRotation() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .points(10), y: .points(20), width: .points(80), height: .points(60)))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        let content = String(repeating: "A", count: 30)
        let body = try XML.parse(Data("""
        <a:txBody><a:bodyPr lIns="635000" tIns="635000" rIns="635000" bIns="635000" anchor="ctr" wrap="none" spcFirstLastPara="1">
          <a:normAutofit fontScale="50000" lnSpcReduction="25000"/>
        </a:bodyPr><a:lstStyle/><a:p><a:pPr>
          <a:lnSpc><a:spcPts val="1200"/></a:lnSpc>
          <a:spcBef><a:spcPts val="300"/></a:spcBef><a:spcAft><a:spcPts val="400"/></a:spcAft>
          <a:defRPr sz="2000"><a:latin typeface="CellTestMissing"/></a:defRPr>
        </a:pPr><a:r><a:t>\(content)</a:t></a:r></a:p></a:txBody>
        """.utf8))
        cell.tc.removeChildren(named: "a:txBody")
        cell.tc.insertChild(body, beforeAnyOf: ["a:tcPr"])
        cell.setPadding(left: .points(3), top: .points(2), right: .points(5), bottom: .points(4))
        let properties = cell.tcPr
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)

        let anchors: [String?] = [nil, "t", "ctr", "b"]
        for direction in ["horz", "vert", "vert270"] {
            for anchor in anchors {
                properties[attribute: "vert"] = direction
                properties[attribute: "anchor"] = anchor
                let before = try deck.serializedData()
                let result = try renderer.render(pixelWidth: 640)
                let root = try XML.parse(Data(result.svg.utf8))
                let container: XML.Element
                if direction == "horz" {
                    container = root
                    #expect(root.firstChild(named: "g") == nil)
                } else {
                    container = try #require(root.firstChild(named: "g"))
                    #expect(container[attribute: "transform"] == (direction == "vert"
                        ? "translate(1143000 254000) rotate(90)"
                        : "translate(127000 1016000) rotate(-90)"))
                }
                let texts = container.children(named: "text")
                // The 126pt run exceeds both horizontal and rotated widths;
                // wrap="none" must survive the cell geometry override.
                #expect(texts.count == 1)
                let text = try #require(texts.first)
                let span = try #require(text.firstChild(named: "tspan"))
                #expect(span.textContent == content)
                #expect(span[attribute: "font-size"] == "10")
                #expect(span[attribute: "x"].flatMap(Double.init) == 3)
                // Approximate layout advances must not distort the viewer's
                // actual fallback font by forcing its glyphs into 126 points.
                #expect(span[attribute: "textLength"] == nil)
                // 3pt before + 12pt * .75 advance + 4pt after = 16pt.
                // The 10pt fallback ascent puts the unanchored baseline at 13pt.
                let localBaseline: Int
                switch anchor {
                case "ctr": localBaseline = direction == "horz" ? 34 : 44
                case "b": localBaseline = direction == "horz" ? 53 : 73
                default: localBaseline = 15
                }
                let x = direction == "horz" ? 10 * EMU.perPoint : 0
                let y = (localBaseline + (direction == "horz" ? 20 : 0)) * EMU.perPoint
                #expect(text[attribute: "transform"] == "translate(\(x),\(y)) scale(12700)")
                #expect(result.problems.fidelityIssues.map(\.code) == [.missingFont, .viewerFontDependency])
                #expect(try deck.serializedData() == before)
            }
        }
    }

    @Test func missingBodyPropertiesAndInvalidCellMarginsUseCellDefaultsWithoutMutation() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .points(80), height: .points(60)))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        cell.text = "A"
        let body = try #require(cell.tc.firstChild(named: "a:txBody"))
        body.removeChildren(named: "a:bodyPr")
        let properties = cell.tcPr
        properties[attribute: "marL"] = "9223372036854775807"
        properties[attribute: "marT"] = "invalid"
        properties[attribute: "marR"] = "-9223372036854775808"
        properties[attribute: "marB"] = nil
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let before = try deck.serializedData()
        let missing = try renderer.render(pixelWidth: 640)
        #expect(body.firstChild(named: "a:bodyPr") == nil)
        #expect(try deck.serializedData() == before)

        // Explicit cell defaults must produce exactly the same result. A
        // conflicting body anchor/margin remains subordinate to cell geometry.
        cell.setPadding(left: EMU(91440), top: EMU(45720), right: EMU(91440), bottom: EMU(45720))
        body.insertChild(XML.Element("a:bodyPr", attributes: [("anchor", "b"), ("lIns", "0")]),
            beforeAnyOf: ["a:lstStyle", "a:p"])
        let explicitBefore = try deck.serializedData()
        let explicit = try renderer.render(pixelWidth: 640)
        #expect(explicit.svg == missing.svg)
        #expect(explicit.problems.fidelityIssues == missing.problems.fidelityIssues)
        #expect(try deck.serializedData() == explicitBefore)
    }
}
