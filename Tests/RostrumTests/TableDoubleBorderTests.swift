import Foundation
import Testing
@testable import Rostrum

@Suite struct TableDoubleBorderTests {
    private func lines(_ svg: String) throws -> [XML.Element] {
        var result: [XML.Element] = [], pending = [try XML.parse(Data(svg.utf8))]
        while let node = pending.popLast() {
            if node.name == "line" { result.append(node) }
            pending.append(contentsOf: node.childElements.reversed())
        }
        return result
    }

    private func doubleEdge(_ cell: TableCell, _ edge: TableCellBorder, width: Int = 90000) throws -> XML.Element {
        cell.setBorder(edge, line: Line(color: Color("0000FF"), width: EMU(width)))
        let line = try #require(cell.tcPr.firstChild(named: edge.rawValue))
        line[attribute: "cmpd"] = "dbl"
        return line
    }

    @Test(arguments: [false, true]) func sharedEdgeKeepsDoubleOwnerAndTransparentGap(_ rtl: Bool) throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 2,
            frame: Rect(x: .zero, y: .zero, width: EMU(1800000), height: EMU(900000)))
        table.clearBuiltInStyle(); table.rightToLeft = rtl
        for column in 0..<2 { try table.cell(0, column).setBorders(nil) }
        _ = try doubleEdge(table.cell(0, 0), .right)
        try table.cell(0, 1).setBorder(.left, line: Line(color: Color("FF0000"), width: EMU(180000)))
        let before = try deck.serializedData()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        let strokes = try lines(report.svg)
        #expect(strokes.count == 2)
        #expect(Set(strokes.compactMap { $0[attribute: "x1"] }) == ["870000", "930000"])
        #expect(strokes.allSatisfy { $0[attribute: "stroke"] == "#0000FF" && $0[attribute: "stroke-width"] == "30000" })
        #expect(!report.problems.fidelityIssues.contains { $0.code == .unsupportedBorder })
        #expect(try deck.serializedData() == before)
    }

    @Test func diagonalSeparationIsPerpendicularAndMutationIsObserved() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: EMU(1200000), height: EMU(900000)))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0); cell.setBorders(nil)
        let line = try doubleEdge(cell, .diagonalDown)
        let strokes = try lines(deck.renderSVG(slideAt: 0))
        #expect(strokes.count == 2)
        #expect(strokes[0][attribute: "x1"] == "18000")
        #expect(strokes[0][attribute: "y1"] == "-24000")
        #expect(strokes[1][attribute: "x1"] == "-18000")
        #expect(strokes[1][attribute: "y1"] == "24000")
        line[attribute: "cmpd"] = "sng"
        #expect(try lines(deck.renderSVG(slideAt: 0)).count == 1)
    }

    @Test(arguments: ["tri", "thickThin", "thinThick", "dash", "round-cap", "inset", "custom-dash"])
    func unsupportedCombinationsRemainDiagnosed(_ variant: String) throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0); cell.setBorders(nil)
        let line = try doubleEdge(cell, .top)
        switch variant {
        case "dash": line.appendElement(XML.Element("a:prstDash", attributes: [("val", "dash")]))
        case "round-cap": line[attribute: "cap"] = "rnd"
        case "inset": line[attribute: "algn"] = "in"
        case "custom-dash": line.appendElement(XML.Element("a:custDash"))
        default: line[attribute: "cmpd"] = variant
        }
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.contains { $0.code == .unsupportedBorder })
        #expect(try lines(report.svg).count == 1)
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }
    @Test func nativeFooterSeparatorsPrecedeTheDonorCellDirectOverlay() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/DoubleTableBorders/style-precedence.pptx")
        let deck = try Presentation(contentsOf: url)
        // The 36-slide independent Office control varies only the two direct
        // edges at each shared boundary. Later-cell formatting never replaces
        // the earlier logical donor's style or direct noFill.
        for index in 0..<12 {
            let strokes = try lines(deck.renderSVG(slideAt: index))
            let variant = index % 6
            let boundary = 4_297_680.0
            let selected = strokes.filter {
                guard let y1 = $0[attribute: "y1"].flatMap(Double.init),
                      let y2 = $0[attribute: "y2"].flatMap(Double.init) else { return false }
                return y1 == y2 && abs(y1 - boundary) < 30_000
            }
            if variant == 2 { #expect(selected.isEmpty) }
            else if variant == 1 || variant == 5 {
                #expect(selected.count == 4)
                #expect(selected.allSatisfy { $0[attribute: "stroke"] == "#0000FF" })
            } else {
                #expect(selected.count == 8)
                #expect(selected.allSatisfy { $0[attribute: "stroke"] == "#4F81BD" })
                #expect(Set(selected.compactMap { $0[attribute: "y1"] }) == ["4280746.6667", "4314613.3333"])
            }
        }
    }

    @Test(arguments: [false, true]) func columnRegionInteriorBordersDoNotEraseItsBoundary(_ rtl: Bool) throws {
        let name = rtl ? "style-precedence-rtl" : "style-precedence"
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/DoubleTableBorders/\(name).pptx")
        let deck = try Presentation(contentsOf: url)
        let before = try deck.serializedData()
        for index in 24..<36 {
            let logicalBoundary = index < 30 ? 1 : 3
            let physicalBoundary = rtl ? 4 - logicalBoundary : logicalBoundary
            let x = Double(914400 + physicalBoundary * 2286000)
            let selected = try lines(deck.renderSVG(slideAt: index)).filter {
                $0[attribute: "x1"].flatMap(Double.init) == x
                    && $0[attribute: "x2"].flatMap(Double.init) == x
            }
            if index % 6 == 2 { #expect(selected.isEmpty) }
            else {
                #expect(selected.count == 5)
                let direct = index % 6 == 1 || index % 6 == 5
                #expect(selected.allSatisfy {
                    $0[attribute: "stroke"] == (direct ? "#0000FF" : "#4F81BD")
                        && $0[attribute: "stroke-width"] == (direct ? "114300" : "25400")
                })
            }
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func nativeFooterMeetsThePerpendicularBorderAtItsOutsideEdge() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/DoubleTableBorders/double-borders.pptx")
        let deck = try Presentation(contentsOf: url)
        for (index, extensionWidth) in [(24, 4762.5), (26, 6350.0), (27, 0.0)] {
            let footer = try lines(deck.renderSVG(slideAt: index)).filter {
                guard let y = $0[attribute: "y1"].flatMap(Double.init) else { return false }
                return $0[attribute: "y1"] == $0[attribute: "y2"] && abs(y - 4297680) < 30000
            }
            #expect(footer.compactMap { $0[attribute: "x1"].flatMap(Double.init) }.min() == 914400 - extensionWidth)
            #expect(footer.compactMap { $0[attribute: "x2"].flatMap(Double.init) }.max() == 10058400 + extensionWidth)
        }
    }

    @Test(arguments: [false, true]) func unverifiedDoubleJunctionRemainsVisibleInStrictMode(_ diagonal: Bool) throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0); cell.setBorders(nil)
        _ = try doubleEdge(cell, diagonal ? .diagonalDown : .top)
        _ = try doubleEdge(cell, .right)
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.filter { $0.code == .unsupportedBorder }.count == 1)
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test(arguments: ["double", "dash", "alpha", "unequal", "plain"])
    func interiorCrossingWithoutOuterBordersIsInspected(_ variant: String) throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(2)))
        table.clearBuiltInStyle()
        for row in 0..<2 { for column in 0..<2 { try table.cell(row, column).setBorders(nil) } }
        for column in 0..<2 { _ = try doubleEdge(table.cell(0, column), .bottom) }
        for row in 0..<2 {
            let cell = try table.cell(row, 0)
            let line = try doubleEdge(cell, .right, width: variant == "unequal" && row == 1 ? 180000 : 90000)
            if variant != "double" { line[attribute: "cmpd"] = "sng" }
            if variant == "dash" {
                line.appendElement(XML.Element("a:prstDash", attributes: [("val", "dash")]))
            } else if variant == "alpha" {
                line.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?
                    .appendElement(XML.Element("a:alpha", attributes: [("val", "50000")]))
            }
        }
        let before = try deck.serializedData()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.filter { $0.code == .unsupportedBorder }.count == (variant == "plain" ? 0 : 1))
        if variant != "plain" {
            #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
        }
        #expect(try deck.serializedData() == before)
    }

}
