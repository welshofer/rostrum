import Foundation
import Testing
@testable import Rostrum

@Suite struct TableCellFittingProjectionTests {
    @Test func generatedTextProjectionPreservesEveryCatalogRegion() throws {
        for style in BuiltInTableStyle.allCases {
            let full = try #require(style.definition())
            let projected = try #require(style.textDefinition())
            #expect(full.name == projected.name)
            #expect(XML.Element(full.name, attributes: full.attributes).serialized()
                    == XML.Element(projected.name, attributes: projected.attributes).serialized())
            #expect(full.childElements.map { $0.name } == projected.childElements.map { $0.name })
            for (original, actual) in zip(full.childElements, projected.childElements) {
                let expected = XML.Element(original.name, attributes: original.attributes,
                    children: original.children.filter {
                        if case .element(let child) = $0 { return child.name == "a:tcTxStyle" }
                        return false
                    })
                #expect(actual.serialized() == expected.serialized())
            }
        }
    }

    @Test func everyStyleAndFlagCombinationMatchesFullResolution() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 4, columns: 5,
            frame: Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4)))
        let flags = try #require(table.tbl.firstChild(named: "a:tblPr"))
        let positions = [(0, 0), (0, 4), (3, 0), (3, 4), (1, 1), (2, 2)]
        let cells = try positions.map { try table.cell($0.0, $0.1) }
        for style in BuiltInTableStyle.allCases {
            table.applyBuiltInStyle(style)
            for bits in 0..<128 {
                for (bit, name) in ["firstRow", "lastRow", "firstCol", "lastCol", "bandRow", "bandCol", "rtl"].enumerated() {
                    flags[attribute: name] = bits & (1 << bit) == 0 ? "0" : "1"
                }
                let resolver = TableStyleResolver(table: table, theme: deck.theme)
                for (index, position) in positions.enumerated() {
                    let full = resolver.effective(row: position.0, column: position.1)
                    let projected = try #require(TableStyleResolver.fittingStyle(
                        for: cells[index].tc, in: table, theme: deck.theme))
                    #expect(projected.text.serialized() == full.text.serialized())
                    #expect(projected.properties.serialized()
                        == XML.Element("a:tcPr", attributes: full.properties.attributes).serialized())
                }
            }
        }
    }

    @Test func inlineNamespacesDuplicateRegionsAndDegenerateGridsMatchFullResolution() throws {
        let deck = try Presentation()
        for (rows, columns) in [(1, 1), (1, 5), (5, 1)] {
            let table = try deck.slides[0].shapes.addTable(rows: rows, columns: columns,
                frame: Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4)))
            let inline = try XML.parse(Data("""
                <a:tableStyle xmlns:q="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <q:wholeTbl><q:tcTxStyle b="on"><q:fontRef idx="major"/><q:schemeClr val="accent2"><q:tint val="25000"/></q:schemeClr></q:tcTxStyle></q:wholeTbl>
                  <q:wholeTbl><q:tcTxStyle b="off"/></q:wholeTbl>
                  <q:firstRow><q:tcTxStyle i="on"/></q:firstRow>
                  <q:lastCol><q:tcTxStyle><q:font><q:latin typeface="Missing face"/></q:font></q:tcTxStyle></q:lastCol>
                </a:tableStyle>
                """.utf8))
            let flags = table.tbl.getOrAddChild("a:tblPr")
            flags.appendElement(inline)
            for name in ["firstRow", "lastRow", "firstCol", "lastCol", "bandRow", "bandCol"] {
                flags[attribute: name] = "1"
            }
            for row in 0..<rows { for column in 0..<columns {
                let cell = try table.cell(row, column)
                cell.tcPr.attributes += [("marL", "123"), ("marL", ""), ("anchor", "t"), ("anchor", "b")]
                let before = table.tbl.serialized()
                let full = TableStyleResolver(table: table, theme: deck.theme).effective(row: row, column: column)
                let actual = try #require(TableStyleResolver.fittingStyle(for: cell.tc, in: table, theme: deck.theme))
                #expect(actual.text.serialized() == full.text.serialized())
                #expect(actual.properties.serialized() == XML.Element("a:tcPr", attributes: full.properties.attributes).serialized())
                #expect(table.tbl.serialized() == before)
            } }
        }
    }

    @Test func retainedFramesResolveStructuralFormattingAndDirectXMLMutations() throws {
        let deck = try Presentation()
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
        try deck.fonts.register(data, aliases: ["Arial", "Aptos", "Aptos Display"])
        let metrics = try FontMetrics(data: data)
        let table = try deck.slides[0].shapes.addTable(rows: 4, columns: 5,
            frame: Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4)))
        let cell = try table.cell(1, 1)
        cell.text = "office AV café text"
        let frame = cell.textFrame
        let dimensions = Rect(x: .zero, y: .zero, width: .points(120), height: .points(50))
        func check() throws {
            let before = try deck.serializedData()
            let svgBefore = try deck.renderSVGReportingProblems(slideAt: 0)
            let resolver = TableStyleResolver(table: table, theme: deck.theme)
            var properties = cell.tc.firstChild(named: "a:tcPr") ?? XML.Element("a:tcPr")
            var styles: [XML.Element] = []
            outer: for row in resolver.grid.cells.indices {
                for column in resolver.grid.cells[row].indices where resolver.grid.cells[row][column] === cell.tc {
                    let full = resolver.effective(row: row, column: column)
                    properties = full.properties; styles = [full.text]
                    break outer
                }
            }
            func inset(_ name: String, _ fallback: Int) -> Double {
                Double(properties.coordinate(name) ?? fallback) / Double(EMU.perPoint)
            }
            let vertical = ["vert", "vert270"].contains(properties[attribute: "vert"] ?? "horz")
            for useMetrics in [false, true] {
                let layout = RichTextLayout(textBody: frame.txBody,
                    width: vertical ? 50 : 120, height: vertical ? 120 : 50,
                    fonts: useMetrics ? nil : deck.fonts, fallbackMetrics: useMetrics ? metrics : nil,
                    theme: deck.theme, inheritedStyles: styles, defaultPointSize: 18,
                    lineSpacing: 1, fontScale: 100, lineSpacingReduction: 0, maxLines: 64,
                    insets: (inset("marL", 91440), inset("marT", 45720),
                             inset("marR", 91440), inset("marB", 45720)),
                    verticalAnchor: properties[attribute: "anchor"] ?? "t", context: .tableCell)
                let expectedFits = layout.fits && !layout.diagnostics.contains(
                    .unsupportedLayoutFeature("Native table line-spacing reduction is not verified"))
                let actual = useMetrics ? frame.fitText(in: dimensions, using: metrics)
                    : frame.fitText(in: dimensions, fonts: deck.fonts)
                #expect(actual == Autofit(fontScale: 100, lineSpacingReduction: 0, fits: expectedFits))
            }
            #expect(try deck.serializedData() == before)
            let svgAfter = try deck.renderSVGReportingProblems(slideAt: 0)
            #expect(svgAfter.svg == svgBefore.svg)
            #expect(svgAfter.problems.fidelityIssues == svgBefore.problems.fidelityIssues)
        }
        try check()
        try table.insertRow(at: 0); try table.insertColumn(at: 0); try check()
        try table.moveRow(from: 2, to: 0); try table.moveColumn(from: 2, to: 0); try check()
        table.firstRowHeader = true; table.lastColumnFooter = true; table.bandedRows = true
        cell.setPadding(left: .points(51), top: .points(3), right: .points(51), bottom: .points(4))
        cell.verticalAnchor = .bottom
        cell.textDirection = .vertical270
        try check()
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2); try check()
        try table.unmerge(row: 0, column: 0); try check()
        let custom = try #require(BuiltInTableStyle.darkStyle1.definition())
        custom.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcTxStyle")?[attribute: "b"] = "on"
        try table.setStyleDefinition(custom)
        deck.theme.setAccent(1, Color("765432")); try check()
        // Last overlay value wins for an attached cell, even malformed/duplicate attributes.
        cell.tcPr.attributes += [("marL", "1234"), ("marL", "bad"), ("anchor", "t"), ("anchor", "b")]
        try check()
        // Retain the old body while replacing the cell's current body.
        cell.tc.removeChildren(named: "a:txBody")
        cell.tc.insertChild(Table.makeCell().firstChild(named: "a:txBody")!, beforeAnyOf: ["a:tcPr"])
        try check()
        // Identity aliases use the first row-major match, not a remembered coordinate.
        let row = table.tbl.children(named: "a:tr").last!
        row.insertChild(cell.tc, beforeAnyOf: ["a:tc"])
        try check()
        table.tbl.children(named: "a:tr").first!.removeChildren(named: "a:tc")
        try check()
        // Detached cells retain direct-only context, including first duplicate attribute.
        for row in table.tbl.children(named: "a:tr") {
            row.children.removeAll { if case .element(let node) = $0 { return node === cell.tc }; return false }
        }
        try check()
    }
}
