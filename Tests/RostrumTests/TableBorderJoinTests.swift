import Foundation
import Testing
@testable import Rostrum

@Suite struct TableBorderJoinTests {
    private struct Stroke: Equatable {
        var x1: Double, y1: Double, x2: Double, y2: Double
        let color: String
        var vertical: Bool { x1 == x2 }
        var key: String { "\(vertical):\(vertical ? x1 : y1):\(color)" }
    }

    private func strokes(_ svg: String) throws -> [Stroke] {
        var result: [Stroke] = [], stack = [try XML.parse(Data(svg.utf8))]
        while let node = stack.popLast() {
            if node.name == "line" {
                let coordinates = try ["x1", "y1", "x2", "y2"].map {
                    try #require(Double(node[attribute: $0] ?? ""))
                }
                result.append(Stroke(x1: coordinates[0], y1: coordinates[1],
                                     x2: coordinates[2], y2: coordinates[3],
                                     color: try #require(node[attribute: "stroke"])))
            }
            stack.append(contentsOf: node.childElements.reversed())
        }
        return result
    }

    @Test func solidFixtureMatchesOfficeVectorJoinsAndPaintOrder() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Conformance/python-tables-v3.pptx")
        let deck = try Presentation(contentsOf: url)
        let before = try deck.serializedData()
        let lines = try strokes(deck.renderSVG(slideAt: 0))
        func group(_ line: Stroke) -> Int {
            let outer = line.vertical ? [914400.0, 10058400].contains(line.x1) : [914400.0, 5486400].contains(line.y1)
            return (outer ? 2 : 0) + (line.vertical ? 0 : 1)
        }
        #expect(lines.map(group) == lines.map(group).sorted())
        // Office coalesces same-paint neighbors. Compare intervals, not its
        // choice of SVG/PDF primitive count. Values below are raw Office PDF
        // drawing coordinates translated back to slide EMUs, not pixel fits.
        var coalesced: [Stroke] = []
        for key in Set(lines.map(\.key)).sorted() {
            let matching = lines.filter { $0.key == key }.sorted {
                $0.vertical ? $0.y1 < $1.y1 : $0.x1 < $1.x1
            }
            for line in matching {
                if let last = coalesced.last, last.key == line.key,
                   last.x2 == line.x1, last.y2 == line.y1 {
                    coalesced[coalesced.count - 1].x2 = line.x2
                    coalesced[coalesced.count - 1].y2 = line.y2
                } else { coalesced.append(line) }
            }
        }
        let green = "#18A999", navy = "#1B365D", red = "#CC3300", gray = "#333333"
        let expected: [Stroke] = [
            .init(x1: 3657600, y1: 3187700, x2: 3657600, y2: 5499100, color: green),
            .init(x1: 5486400, y1: 901700, x2: 5486400, y2: 2057400, color: green),
            .init(x1: 5486400, y1: 2057400, x2: 5486400, y2: 3200400, color: navy),
            .init(x1: 5486400, y1: 3200400, x2: 5486400, y2: 5499100, color: green),
            .init(x1: 7772400, y1: 901700, x2: 7772400, y2: 5499100, color: green),
            .init(x1: 5473700, y1: 2057400, x2: 10071100, y2: 2057400, color: gray),
            .init(x1: 901700, y1: 3200400, x2: 3657600, y2: 3200400, color: gray),
            .init(x1: 3657600, y1: 3200400, x2: 5486400, y2: 3200400, color: red),
            .init(x1: 5486400, y1: 3200400, x2: 10071100, y2: 3200400, color: gray),
            .init(x1: 901700, y1: 4343400, x2: 10071100, y2: 4343400, color: gray),
            .init(x1: 914400, y1: 901700, x2: 914400, y2: 5499100, color: navy),
            .init(x1: 10058400, y1: 901700, x2: 10058400, y2: 5499100, color: green),
            .init(x1: 901700, y1: 914400, x2: 10071100, y2: 914400, color: red),
            .init(x1: 901700, y1: 5486400, x2: 10071100, y2: 5486400, color: gray),
        ]
        #expect(coalesced.count == expected.count)
        for line in expected { #expect(coalesced.contains(line)) }
        #expect(try deck.serializedData() == before)
    }

    @Test func mirroredJunctionExtendsPhysicalTerminalButNotFreeEnd() throws {
        for rtl in [false, true] {
            let deck = try Presentation()
            let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 2,
                frame: Rect(x: EMU(100000), y: EMU(200000), width: EMU(2000000), height: EMU(1000000)))
            table.clearBuiltInStyle(); table.rightToLeft = rtl
            for column in 0..<2 { try table.cell(0, column).setBorders(nil) }
            // An L junction at the physical right end in LTR and left in RTL.
            let cell = try table.cell(0, 0)
            cell.setBorder(.top, line: Line(color: .black, width: EMU(25401)))
            cell.setBorder(.right, line: Line(color: .black, width: EMU(25401)))
            let lines = try strokes(deck.renderSVG(slideAt: 0))
            let horizontal = try #require(lines.first { !$0.vertical })
            #expect(horizontal.x1 == (rtl ? 1087299.5 : 100000))
            #expect(horizontal.x2 == (rtl ? 2100000 : 1112700.5))
            let vertical = try #require(lines.first { $0.vertical })
            #expect(vertical.y1 == 187299.5 && vertical.y2 == 1200000)
        }
    }

    @Test func unverifiedJunctionStylesKeepPreviousGeometry() throws {
        for variant in ["mixed-width", "alpha", "unsupported-dash", "custom-dash", "compound", "round-cap"] {
            let deck = try Presentation()
            let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
                frame: Rect(x: EMU(100000), y: EMU(200000), width: EMU(1000000), height: EMU(1000000)))
            table.clearBuiltInStyle()
            let cell = try table.cell(0, 0)
            cell.setBorders(nil).setBorder(.top, line: Line(color: .black, width: EMU(25400)))
            cell.setBorder(.right, line: Line(color: .black, width: EMU(variant == "mixed-width" ? 12700 : 25400)))
            let right = try #require(cell.tcPr.firstChild(named: "a:lnR"))
            if variant == "alpha" {
                let color = try #require(cell.tcPr.firstChild(named: "a:lnR")?
                    .firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr"))
                color.appendElement(XML.Element("a:alpha", attributes: [("val", "50000")]))
            } else if variant == "unsupported-dash" {
                right.appendElement(XML.Element("a:prstDash", attributes: [("val", "lgDashDot")]))
            } else if variant == "custom-dash" {
                right.appendElement(XML.Element("a:custDash"))
            } else if variant == "compound" {
                right[attribute: "cmpd"] = "tri"
            } else if variant == "round-cap" {
                right[attribute: "cap"] = "rnd"
            }
            let lines = try strokes(deck.renderSVG(slideAt: 0))
            #expect(lines.count == 2)
            #expect(lines.allSatisfy { $0.y1 == 200000 })
            #expect(lines.first { !$0.vertical }?.x2 == 1100000)
        }
    }
}
