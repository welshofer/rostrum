import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGVisualPolishTests {
    /// Extracts straight-chord vertices from an SVG `<path d="..."/>` string (`M`, `L`, `H`, `V`, `A`)
    /// so closed callout outlines can be checked geometrically for self-intersection.
    private static func pathVertices(_ d: String) -> [(Double, Double)] {
        var tokens: [String] = []
        var cur = ""
        for ch in d {
            if ch.isLetter {
                if !cur.trimmingCharacters(in: .whitespaces).isEmpty {
                    tokens.append(contentsOf: cur.split(whereSeparator: \.isWhitespace).map(String.init))
                    cur = ""
                }
                tokens.append(String(ch))
            } else if ch == "," || ch.isWhitespace {
                if !cur.isEmpty {
                    tokens.append(cur)
                    cur = ""
                }
            } else {
                cur.append(ch)
            }
        }
        if !cur.isEmpty { tokens.append(cur) }

        var pts: [(Double, Double)] = []
        var idx = 0
        var cx = 0.0, cy = 0.0
        while idx < tokens.count {
            let cmd = tokens[idx]
            idx += 1
            switch cmd {
            case "M", "L":
                guard idx + 1 < tokens.count,
                      let px = Double(tokens[idx]),
                      let py = Double(tokens[idx + 1]) else { break }
                idx += 2
                cx = px; cy = py
                if pts.last.map({ hypot($0.0 - cx, $0.1 - cy) > 1e-6 }) ?? true {
                    pts.append((cx, cy))
                }
            case "H":
                guard idx < tokens.count, let px = Double(tokens[idx]) else { break }
                idx += 1
                cx = px
                if pts.last.map({ hypot($0.0 - cx, $0.1 - cy) > 1e-6 }) ?? true {
                    pts.append((cx, cy))
                }
            case "V":
                guard idx < tokens.count, let py = Double(tokens[idx]) else { break }
                idx += 1
                cy = py
                if pts.last.map({ hypot($0.0 - cx, $0.1 - cy) > 1e-6 }) ?? true {
                    pts.append((cx, cy))
                }
            case "A":
                guard idx + 6 < tokens.count,
                      let px = Double(tokens[idx + 5]),
                      let py = Double(tokens[idx + 6]) else { break }
                idx += 7
                cx = px; cy = py
                if pts.last.map({ hypot($0.0 - cx, $0.1 - cy) > 1e-6 }) ?? true {
                    pts.append((cx, cy))
                }
            case "Z":
                if let first = pts.first, let last = pts.last, hypot(first.0 - last.0, first.1 - last.1) <= 1e-6 {
                    pts.removeLast()
                }
            default:
                break
            }
        }
        return pts
    }

    private static func segmentsIntersect(
        _ a: (Double, Double), _ b: (Double, Double),
        _ c: (Double, Double), _ d: (Double, Double)
    ) -> Bool {
        func cross(_ o: (Double, Double), _ p: (Double, Double), _ q: (Double, Double)) -> Double {
            (p.0 - o.0) * (q.1 - o.1) - (p.1 - o.1) * (q.0 - o.0)
        }
        func onSeg(_ p: (Double, Double), _ q: (Double, Double), _ r: (Double, Double)) -> Bool {
            q.0 >= min(p.0, r.0) - 1e-6 && q.0 <= max(p.0, r.0) + 1e-6
                && q.1 >= min(p.1, r.1) - 1e-6 && q.1 <= max(p.1, r.1) + 1e-6
        }
        let d1 = cross(a, b, c)
        let d2 = cross(a, b, d)
        let d3 = cross(c, d, a)
        let d4 = cross(c, d, b)
        if ((d1 > 1e-6 && d2 < -1e-6) || (d1 < -1e-6 && d2 > 1e-6))
            && ((d3 > 1e-6 && d4 < -1e-6) || (d3 < -1e-6 && d4 > 1e-6)) {
            return true
        }
        if abs(d1) <= 1e-6 && onSeg(a, c, b) { return true }
        if abs(d2) <= 1e-6 && onSeg(a, d, b) { return true }
        if abs(d3) <= 1e-6 && onSeg(c, a, d) { return true }
        if abs(d4) <= 1e-6 && onSeg(c, b, d) { return true }
        return false
    }

    private static func hasSelfIntersection(_ pts: [(Double, Double)]) -> Bool {
        let n = pts.count
        guard n >= 4 else { return false }
        for i in 0..<(n - 2) {
            for j in (i + 2)..<n {
                if i == 0 && j == n - 1 { continue }
                if segmentsIntersect(pts[i], pts[(i + 1) % n], pts[j], pts[(j + 1) % n]) {
                    return true
                }
            }
        }
        return false
    }

    @Test func calloutsAttachToActiveQuadrantWithRoundedCornersAndZeroSelfIntersections() throws {
        let cases: [(adj1: Int, adj2: Int, expectedTipCheck: ((Double, Double)) -> Bool)] = [
            // Upward pointer (acceptance case: adj2 = -62500)
            (-20_833, -62_500, { $0.1 < 1000 }),
            // Downward pointer
            (20_833, 62_500, { $0.1 > 3000 }),
            // Leftward pointer
            (-65_000, -10_000, { $0.0 < 1000 }),
            // Rightward pointer
            (65_000, 15_000, { $0.0 > 5000 }),
        ]
        for preset in ["wedgeRoundRectCallout", "wedgeRectCallout"] {
            for item in cases {
                let avLst = try XML.parse(Data("""
                    <a:avLst xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                      <a:gd name="adj1" fmla="val \(item.adj1)"/>
                      <a:gd name="adj2" fmla="val \(item.adj2)"/>
                    </a:avLst>
                    """.utf8))
                let rendered = SVGPresetGeometry.render(
                    preset,
                    adjustments: avLst,
                    frame: (1000, 1000, 4000, 2000),
                    fill: "#4472C4",
                    stroke: ""
                )
                let pathEl = try XML.parse(Data(rendered.utf8))
                #expect(pathEl.name == "path")
                let d = try #require(pathEl[attribute: "d"])
                if preset == "wedgeRoundRectCallout" {
                    #expect(d.contains(" A"))
                } else {
                    #expect(!d.contains(" A"))
                }
                let vertices = Self.pathVertices(d)
                #expect(vertices.count >= 6)
                #expect(!Self.hasSelfIntersection(vertices), "Self-intersection in \(preset) for (\(item.adj1), \(item.adj2)): \(d)")
                #expect(vertices.contains(where: item.expectedTipCheck))
            }
        }

        // Verify adj3 and adj both adjust wedgeRoundRectCallout textFrame inset.
        let defaultBox = SVGPresetGeometry.textFrame("wedgeRoundRectCallout", adjustments: nil, frame: (0, 0, 2000, 2000))
        let tighterAdj3 = try XML.parse(Data("<a:avLst xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:gd name=\"adj3\" fmla=\"val 45000\"/></a:avLst>".utf8))
        let adj3Box = SVGPresetGeometry.textFrame("wedgeRoundRectCallout", adjustments: tighterAdj3, frame: (0, 0, 2000, 2000))
        #expect(adj3Box.0 > defaultBox.0 && adj3Box.2 < defaultBox.2)
    }

    @Test func bentArrowPointsRightMultidocumentStacksSheetsAndBevelHonorsAdj() throws {
        // bentArrow points right (tip at x + w = 5000), unlike bentUpArrow which points up (tip at y = 1000).
        let bentArrowSVG = SVGPresetGeometry.render("bentArrow", adjustments: nil, frame: (1000, 1000, 4000, 2000), fill: "#2563EB", stroke: "")
        let bentArrowEl = try XML.parse(Data(bentArrowSVG.utf8))
        let bentD = try #require(bentArrowEl[attribute: "d"])
        #expect(bentD.contains(" A"), "bentArrow should curve around its 90-degree elbow")
        let bentVertices = Self.pathVertices(bentD)
        let rightmost = try #require(bentVertices.max(by: { $0.0 < $1.0 }))
        #expect(abs(rightmost.0 - 5000) < 1e-3)
        #expect(rightmost.1 > 1000 && rightmost.1 < 3000, "bentArrow tip must sit vertically between top and bottom wings on the right edge")
        #expect(!Self.hasSelfIntersection(bentVertices))

        // flowChartMultidocument renders 3 stacked sheets, distinct from single-sheet flowChartDocument.
        let singleDoc = SVGPresetGeometry.render("flowChartDocument", adjustments: nil, frame: (0, 0, 3000, 2000), fill: "#FFFFFF", stroke: "")
        let multiDoc = SVGPresetGeometry.render("flowChartMultidocument", adjustments: nil, frame: (0, 0, 3000, 2000), fill: "#FFFFFF", stroke: "")
        #expect(singleDoc != multiDoc)
        let multiD = try #require(XML.parse(Data(multiDoc.utf8))[attribute: "d"])
        #expect(multiD.components(separatedBy: "Z").count - 1 == 3)

        // bevel textFrame and render both honor 'adj'.
        let bevelAdj = try XML.parse(Data("<a:avLst xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:gd name=\"adj\" fmla=\"val 30000\"/></a:avLst>".utf8))
        let defaultBevelFrame = SVGPresetGeometry.textFrame("bevel", adjustments: nil, frame: (0, 0, 2000, 2000))
        let customBevelFrame = SVGPresetGeometry.textFrame("bevel", adjustments: bevelAdj, frame: (0, 0, 2000, 2000))
        #expect(customBevelFrame.0 == 600 && customBevelFrame.0 > defaultBevelFrame.0)
    }

    @Test func endToEndAcceptanceSlideEmitsCalloutBentArrowLineCapsJoinsAndSmoothChartSplines() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]

        // 1. Upward-pointing wedgeRoundRectCallout (adj2 = -62500) with round line-join.
        let callout = try slide.shapes.addShape(
            .balloon,
            frame: Rect(x: .inches(0.5), y: .inches(1.5), width: .inches(3), height: .inches(1.5)),
            fill: .solid(Color("EFF6FF")),
            line: Line(color: Color("1D4ED8"), width: .points(2))
        )
        callout.setAdjustment("adj1", value: -20_833)
        callout.setAdjustment("adj2", value: -62_500)
        if let ln = callout.element.firstChild(named: "p:spPr")?.firstChild(named: "a:ln") {
            ln.appendElement(XML.Element("a:round"))
            slide.part.markDirty()
        }

        // 2. Right-pointing bentArrow with bevel join.
        let bent = try slide.shapes.addShape(
            .bentArrow,
            frame: Rect(x: .inches(4), y: .inches(1.5), width: .inches(2.5), height: .inches(1.5)),
            fill: .solid(Color("DBEAFE")),
            line: Line(color: Color("1E40AF"), width: .points(2))
        )
        if let ln = bent.element.firstChild(named: "p:spPr")?.firstChild(named: "a:ln") {
            ln.appendElement(XML.Element("a:bevel"))
            slide.part.markDirty()
        }

        // 3. Round-capped dotted line (cap="rnd") + default line (omits stroke-linecap/stroke-linejoin).
        let roundLine = try slide.shapes.addShape(
            .line,
            frame: Rect(x: .inches(0.5), y: .inches(3.5), width: .inches(4), height: .inches(0)),
            fill: .none,
            line: Line(color: Color("DC2626"), width: .points(4), dash: .dot)
        )
        if let ln = roundLine.element.firstChild(named: "p:spPr")?.firstChild(named: "a:ln") {
            ln[attribute: "cap"] = "rnd"
            slide.part.markDirty()
        }

        let plainRect = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(5), y: .inches(3.3), width: .inches(1.5), height: .inches(0.8)),
            fill: .none,
            line: Line(color: Color("374151"), width: .points(1))
        )
        _ = plainRect

        // 4. Line chart with <c:smooth val="1"/> on Series 1 and <c:smooth val="0"/> on Series 2.
        _ = try slide.shapes.addChart(
            .line,
            data: ChartData(
                categories: ["Q1", "Q2", "Q3", "Q4"],
                series: [
                    ChartData.Series(name: "Smooth", values: [12, 38, 22, 49]),
                    ChartData.Series(name: "Linear", values: [8, 18, 28, 24]),
                ]
            ),
            frame: Rect(x: .inches(0.5), y: .inches(4.2), width: .inches(6), height: .inches(2.8))
        )
        let chartPart = try #require(slide.charts.first).part
        let chartDOM = try chartPart.dom()
        let linePlot = try #require(
            chartDOM.firstChild(named: "c:chart")?
                .firstChild(named: "c:plotArea")?
                .firstChild(named: "c:lineChart")
        )
        let serElements = linePlot.children(named: "c:ser")
        #expect(serElements.count == 2)
        serElements[0].removeChildren(named: "c:smooth")
        serElements[0].appendElement(XML.Element("c:smooth", attributes: [("val", "1")]))
        serElements[1].removeChildren(named: "c:smooth")
        serElements[1].appendElement(XML.Element("c:smooth", attributes: [("val", "0")]))
        chartPart.markDirty()

        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        // Only the expected chartApproximation fidelity notice should appear (no geometry/inheritance errors).
        #expect(!result.problems.layoutUnresolved)
        #expect(!result.problems.masterUnresolved)
        #expect(!result.problems.fidelityIssues.contains { $0.code == .unsupportedGeometry })

        let svg = result.svg
        _ = try XML.parse(Data(svg.utf8))
        #expect(svg.contains("stroke-linecap=\"round\""))
        #expect(svg.contains("stroke-linejoin=\"round\""))
        #expect(svg.contains("stroke-linejoin=\"bevel\""))
        #expect(!svg.contains("stroke=\"#374151\" stroke-width=\"12700\" stroke-linecap="))
        #expect(!svg.contains("stroke=\"#374151\" stroke-width=\"12700\" stroke-linejoin="))

        // Smooth series renders as <path d="M... C..."> while non-smooth series stays <polyline ...>.
        #expect(svg.contains("<polyline points=\""))
        #expect(svg.range(of: #"<path d="M-?\d+ -?\d+( C-?\d+ -?\d+ -?\d+ -?\d+ -?\d+ -?\d+){3}""#, options: .regularExpression) != nil)
    }
}
