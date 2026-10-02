import Foundation
import Testing
@testable import Rostrum

@Suite struct TableRenderSessionTests {
    @Test func templatesMatchIndependentCellResolutionAcrossNativeRegionsAndDegenerateGrids() throws {
        let deck = try Presentation()
        for (rows, columns) in [(1, 1), (1, 5), (5, 1), (6, 7)] {
            let table = try deck.slides[0].shapes.addTable(rows: rows, columns: columns,
                frame: Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4)))
            let flags = try #require(table.tbl.firstChild(named: "a:tblPr"))
            if rows > 2 && columns > 2 {
                let cell = try table.cell(2, 2)
                let properties = cell.tc.getOrAddChild("a:tcPr")
                properties[attribute: "anchor"] = "b"
                properties.appendElement(try XML.parse(Data("<a:solidFill><a:schemeClr val=\"accent2\"><a:tint val=\"50000\"/><a:alpha val=\"33333\"/></a:schemeClr></a:solidFill>".utf8)))
                properties.appendElement(try XML.parse(Data("<a:lnB w=\"25400\"><a:solidFill><a:schemeClr val=\"accent3\"><a:shade val=\"25000\"/></a:schemeClr></a:solidFill></a:lnB>".utf8)))
            }
            for style in BuiltInTableStyle.allCases {
                table.applyBuiltInStyle(style)
                for bits in [0, 31, 42, 85, 127] {
                    for (bit, name) in ["firstRow", "lastRow", "firstCol", "lastCol", "bandRow", "bandCol", "rtl"].enumerated() {
                        flags[attribute: name] = bits & (1 << bit) == 0 ? "0" : "1"
                    }
                    let resolver = TableStyleResolver(table: table, theme: deck.theme)
                    var session = TableStyleResolver.RenderSession(resolver)
                    for row in 0..<rows { for column in 0..<columns {
                        let expected = resolver.effective(row: row, column: column)
                        let actual = session.effective(row: row, column: column)
                        #expect(actual.properties.serialized() == expected.properties.serialized())
                        #expect(actual.text.serialized() == expected.text.serialized())
                        #expect(actual.fillOwner === expected.fillOwner)
                    } }
                }
            }
        }
    }

    @Test func rendererReuseSeesThemeStyleFlagsAndDirectCellEdits() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 5, columns: 5,
            frame: Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4)))
        table.applyBuiltInStyle(.mediumStyle2Accent1)
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let first = try renderer.render(pixelWidth: 640)
        deck.theme.setAccent(1, Color("123456"))
        table.firstRowHeader = true; table.lastColumnFooter = true; table.bandedRows = true
        try table.cell(2, 2).setFill(.solid(Color("FEDCBA")))
        try table.merge(row: 3, column: 1, rowSpan: 2, columnSpan: 2)
        let before = try deck.serializedData()
        let changed = try renderer.render(pixelWidth: 640)
        let fresh = try deck.renderSVGReportingProblems(slideAt: 0, pixelWidth: 640)
        #expect(changed.svg != first.svg)
        #expect(changed.svg == fresh.svg)
        #expect(changed.problems.fidelityIssues == fresh.problems.fidelityIssues)
        #expect(changed.svg.contains("#123456") && changed.svg.contains("#FEDCBA"))
        #expect(try deck.serializedData() == before)
        // Public calls deliberately have no session cache even on a reused resolver.
        let resolver = TableStyleResolver(table: table, theme: deck.theme)
        let old = try resolver.fill(row: 0, column: 0)
        deck.theme.setAccent(1, Color("654321"))
        #expect(try resolver.fill(row: 0, column: 0) != old)
    }

    @Test func customOverridesAndOversizeTemplatesRemainDetachedAndLossless() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 4, columns: 4,
            frame: Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4)))
        let style = try #require(BuiltInTableStyle.mediumStyle2Accent1.definition())
        let text = try #require(style.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcTxStyle"))
        // Exceeds the retained-template budget while preserving unknown content.
        text.firstChild(named: "a:schemeClr")?.children.append(.comment(String(repeating: "x", count: 1_100_000)))
        try table.setStyleDefinition(style)
        let cell = try table.cell(2, 2)
        try cell.setFill(.solid(Color("789ABC")))
        let before = try deck.serializedData()
        let resolver = TableStyleResolver(table: table, theme: deck.theme)
        var session = TableStyleResolver.RenderSession(resolver)
        for (row, column) in [(1, 1), (2, 2), (1, 1)] {
            let expected = resolver.effective(row: row, column: column)
            let actual = session.effective(row: row, column: column)
            #expect(actual.properties.serialized() == expected.properties.serialized())
            #expect(actual.text.serialized() == expected.text.serialized())
        }
        #expect(try deck.serializedData() == before)
    }
}
