import Foundation
import Testing
@testable import Rostrum

/// Border ownership is independently observable in PowerPoint 16.113.3's
/// border-conflicts fixture: a later cell does not win by width, dash or alpha.
@Suite struct TableBorderConflictTests {
    private func make(rows: Int, columns: Int, rtl: Bool = false) throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: rows, columns: columns,
            frame: Rect(x: EMU(100000), y: EMU(200000), width: EMU(columns * 1000000), height: EMU(rows * 1000000)))
        table.clearBuiltInStyle()
        table.rightToLeft = rtl
        for r in 0..<rows { for c in 0..<columns {
            try table.cell(r, c).setBorders(nil).setFill(Color.white)
        } }
        return (deck, table)
    }

    private func edge(_ table: Table, _ row: Int, _ column: Int, _ edge: TableCellBorder,
                      color: String, width: Int = 25400, dash: Bool = false, alpha: Int = 100000) throws {
        let cell = try table.cell(row, column)
        cell.setBorder(edge, line: Line(color: Color(color), width: EMU(width)))
        let line = try #require(cell.tcPr.firstChild(named: edge.rawValue))
        if dash { line.appendElement(XML.Element("a:prstDash", attributes: [("val", "dash")])) }
        if alpha != 100000 {
            let rgb = try #require(line.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr"))
            rgb.appendElement(XML.Element("a:alpha", attributes: [("val", String(alpha))]))
        }
    }

    @Test func earlierLogicalCellOwnsSharedEdgeIncludingEmptyDashAndAlpha() throws {
        for horizontal in [false, true] { for rtl in [false, true] {
            for variant in ["solid", "thin", "none", "absent", "dash", "alpha"] {
                let (deck, table) = try make(rows: horizontal ? 2 : 1, columns: horizontal ? 1 : 2, rtl: rtl)
                let first: TableCellBorder = horizontal ? .bottom : .right
                let second: TableCellBorder = horizontal ? .top : .left
                if variant == "absent" { try table.cell(0, 0).tcPr.removeChildren(named: first.rawValue) }
                else if variant != "none" {
                    try edge(table, 0, 0, first, color: "0000FF", width: variant == "thin" ? 12700 : 25400,
                             dash: variant == "dash", alpha: variant == "alpha" ? 30000 : 100000)
                }
                try edge(table, horizontal ? 1 : 0, horizontal ? 0 : 1, second, color: "FF0000", width: 76200)
                let before = try deck.serializedData()
                let result = try deck.renderSVGReportingProblems(slideAt: 0)
                let svg = result.svg
                #expect(!svg.contains("stroke=\"#FF0000\""), "\(horizontal), \(rtl), \(variant)")
                let expectedCount = variant == "none" || variant == "absent" ? 0 : 1
                #expect(svg.components(separatedBy: "<line ").count - 1 == expectedCount)
                if variant == "alpha" { #expect(svg.contains("stroke=\"rgba(0,0,255,0.3)\"")) }
                if variant == "dash" { #expect(svg.contains("stroke-dasharray=\"101600 76200\"")) }
                if expectedCount > 0 {
                    // Neighbor fills cannot erase the inside half of the edge.
                    let lastFill = try #require(svg.range(of: "fill=\"#FFFFFF\"", options: .backwards))
                    let border = try #require(svg.range(of: "<line "))
                    #expect(border.lowerBound > lastFill.lowerBound)
                }
                #expect(try deck.serializedData() == before)
            }
        } }
    }

    @Test func rtlMirrorsLogicalSidesAndRetainsDiagonals() throws {
        let (deck, table) = try make(rows: 1, columns: 2, rtl: true)
        try edge(table, 0, 0, .left, color: "0000FF")
        try edge(table, 0, 1, .right, color: "FF0000")
        try edge(table, 0, 0, .diagonalDown, color: "00FF00")
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("x1=\"2100000\" y1=\"200000\" x2=\"2100000\" y2=\"1200000\" stroke=\"#0000FF\""))
        #expect(svg.contains("x1=\"100000\" y1=\"200000\" x2=\"100000\" y2=\"1200000\" stroke=\"#FF0000\""))
        #expect(svg.contains("x1=\"1100000\" y1=\"200000\" x2=\"2100000\" y2=\"1200000\" stroke=\"#00FF00\""))
    }
    @Test func unmergedNeighborReplacesMergeContinuationWithoutBlending() throws {
        for horizontal in [false, true] { for variant in ["solid", "none", "alpha"] {
            let (deck, table) = try make(rows: 2, columns: 2)
            let first: TableCellBorder = horizontal ? .bottom : .right
            let second: TableCellBorder = horizontal ? .top : .left
            for index in 0..<2 {
                try edge(table, horizontal ? 0 : index, horizontal ? index : 0, first, color: "0000FF")
                if variant != "none" {
                    try edge(table, horizontal ? 1 : index, horizontal ? index : 1, second,
                             color: "FF0000", alpha: variant == "alpha" ? 30000 : 100000)
                }
            }
            try table.merge(row: 0, column: 0, rowSpan: horizontal ? 1 : 2, columnSpan: horizontal ? 2 : 1)
            let before = table.tbl.serialized()
            let svg = try deck.renderSVG(slideAt: 0)
            let donor = horizontal
                ? "x1=\"100000\" y1=\"1200000\" x2=\"1100000\" y2=\"1200000\" stroke=\"#0000FF\""
                : "x1=\"1100000\" y1=\"200000\" x2=\"1100000\" y2=\"1200000\" stroke=\"#0000FF\""
            #expect(svg.contains(donor))
            #expect(svg.components(separatedBy: "stroke=\"#0000FF\"").count == 2)
            #expect(svg.components(separatedBy: "<line ").count - 1 == (variant == "none" ? 1 : 2))
            if variant == "alpha" { #expect(svg.contains("stroke=\"rgba(255,0,0,0.3)\"")) }
            #expect(table.tbl.serialized() == before)
        } }
    }

    @Test func pairedMergesKeepFullDonorAndReusedRendererSeesBorderEdits() throws {
        let (deck, table) = try make(rows: 2, columns: 2)
        try edge(table, 0, 0, .right, color: "0000FF")
        try edge(table, 0, 1, .left, color: "FF0000", width: 76200)
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 1)
        try table.merge(row: 0, column: 1, rowSpan: 2, columnSpan: 1)
        let slide = try deck.slides[0]
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let first = try renderer.render(pixelWidth: 640)
        #expect(first.svg.contains("x1=\"1100000\" y1=\"200000\" x2=\"1100000\" y2=\"2200000\" stroke=\"#0000FF\""))
        #expect(!first.svg.contains("stroke=\"#FF0000\""))
        try table.cell(0, 0).setBorder(.right, line: nil)
        let second = try renderer.render(pixelWidth: 640)
        #expect(!second.svg.contains("<line "))
        #expect(second.problems.fidelityIssues == first.problems.fidelityIssues)
        #expect(second.svg == (try deck.renderSVG(slideAt: 0, pixelWidth: 640)))
    }

    @Test func splitRTLBorderKeepsOriginalDashPhase() throws {
        let (deck, table) = try make(rows: 2, columns: 2, rtl: true)
        try edge(table, 0, 0, .bottom, color: "0000FF", dash: true)
        try table.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2)
        try edge(table, 1, 1, .top, color: "FF0000")
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("x1=\"1100000\" y1=\"1200000\" x2=\"2100000\" y2=\"1200000\" stroke=\"#0000FF\" stroke-width=\"25400\" stroke-dasharray=\"101600 76200\" stroke-dashoffset=\"1000000\""))
    }

}
