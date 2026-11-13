import Foundation
import Testing
@testable import Rostrum

/// Bar widths and authored plot rectangles follow the chart XML rather than
/// fixed preview proportions.
@Suite struct ChartBarGeometryTests {
    private func make(_ kind: ChartKind = .barClustered, series: Int = 1) throws -> (Presentation, XML.Element) {
        let deck = try Presentation()
        let data = ChartData(categories: ["A", "B", "C", "D"],
                             series: (0..<series).map { ChartData.Series(name: "S\($0)", values: [10, 20, 30, 40]) })
        try deck.slides[0].shapes.addChart(kind, data: data,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4)))
        return (deck, try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom())
    }

    private func descendants(_ root: XML.Element, _ name: String) -> [XML.Element] {
        (root.name == name ? [root] : []) + root.childElements.flatMap { descendants($0, name) }
    }

    private func set(_ name: String, _ value: Int?, on plot: XML.Element) {
        plot.children.removeAll { if case .element(let child) = $0 { return child.name == name } else { return false } }
        guard let value else { return }
        let element = XML.Element(name, attributes: [("val", String(value))])
        // CT_BarChart orders gapWidth and overlap just before the axis ids.
        let index = plot.children.firstIndex { if case .element(let child) = $0 { return ["c:overlap", "c:serLines", "c:axId"].contains(child.name) } else { return false } }
        plot.children.insert(.element(element), at: index ?? plot.children.count)
    }

    /// Series-colored bars: the rects the plot draws, grouped by x position.
    private func bars(_ deck: Presentation) throws -> [(x: Double, width: Double)] {
        let svg = try XML.parse(Data(try deck.renderSVG(slideAt: 0).utf8))
        return descendants(svg, "rect").compactMap { rect in
            guard let fill = rect[attribute: "fill"], fill != "#FFFFFF", fill != "none",
                  let x = rect[attribute: "x"].flatMap(Double.init), let width = rect[attribute: "width"].flatMap(Double.init),
                  let height = rect[attribute: "height"].flatMap(Double.init), width < 3_000_000, height > 0 else { return nil }
            return (x, width)
        }.sorted { $0.x < $1.x }
    }

    @Test func gapWidthSetsBarWidthRelativeToTheCategorySlot() throws {
        let (deck, chart) = try make()
        let plot = try #require(descendants(chart, "c:barChart").first)
        var widths: [Int: Double] = [:]
        for gap in [0, 100, 150, 300] {
            set("c:gapWidth", gap, on: plot)
            deck.package.parts[PackURI("/ppt/charts/chart1.xml")]?.markDirty()
            let drawn = try bars(deck)
            #expect(drawn.count == 4)
            let slot = drawn[1].x - drawn[0].x
            // One series: bar = slot / (1 + gap/100), centered in its slot.
            #expect(abs(drawn[0].width - slot / (1 + Double(gap) / 100)) < slot * 0.002, "gapWidth \(gap)")
            widths[gap] = drawn[0].width
        }
        // No gapWidth element means the schema default of 150.
        set("c:gapWidth", nil, on: plot)
        deck.package.parts[PackURI("/ppt/charts/chart1.xml")]?.markDirty()
        #expect(abs(try bars(deck)[0].width - widths[150]!) <= 2)
    }

    @Test func overlapSlidesSeriesAcrossEachOther() throws {
        let (deck, chart) = try make(series: 2)
        let plot = try #require(descendants(chart, "c:barChart").first)
        set("c:gapWidth", 100, on: plot)
        func layout(_ overlap: Int?) throws -> (bar: Double, step: Double, slot: Double) {
            set("c:overlap", overlap, on: plot)
            deck.package.parts[PackURI("/ppt/charts/chart1.xml")]?.markDirty()
            let drawn = try bars(deck)
            #expect(drawn.count == 8)
            return (drawn[0].width, drawn[1].x - drawn[0].x, drawn[2].x - drawn[0].x)
        }
        let apart = try layout(nil)        // side by side
        #expect(abs(apart.step - apart.bar) <= 2)
        #expect(abs(apart.bar - apart.slot / 3) < apart.slot * 0.002)      // 2 bars + 1 bar of gap
        let half = try layout(50)
        #expect(abs(half.step - half.bar / 2) <= 2)
        #expect(abs(half.bar - half.slot / 2.5) < half.slot * 0.002)
        let spaced = try layout(-100)      // a full bar width between the series
        #expect(abs(spaced.step - spaced.bar * 2) <= 2)
        #expect(abs(spaced.bar - spaced.slot / 4) < spaced.slot * 0.002)
    }

    @Test func stackedSeriesShareOneColumnWhateverTheOverlapSays() throws {
        let (deck, chart) = try make(.barStacked, series: 3)
        let plot = try #require(descendants(chart, "c:barChart").first)
        set("c:gapWidth", 50, on: plot)
        set("c:overlap", 0, on: plot)
        deck.package.parts[PackURI("/ppt/charts/chart1.xml")]?.markDirty()
        let drawn = try bars(deck)
        #expect(drawn.count == 12)
        #expect(Set(drawn.map { Int($0.x.rounded()) }).count == 4)
        let slot = drawn[3].x - drawn[0].x
        #expect(abs(drawn[0].width - slot / 1.5) < slot * 0.002)
    }

    @Test func innerManualLayoutPinsThePlotRectangle() throws {
        let (deck, chart) = try make()
        let plotArea = try #require(descendants(chart, "c:plotArea").first)
        func layout(_ body: String) throws -> XML.Element {
            try XML.parse(Data("<c:layout xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">\(body)</c:layout>".utf8))
        }
        func plotBox() throws -> (x: Double, y: Double, width: Double, height: Double)? {
            deck.package.parts[PackURI("/ppt/charts/chart1.xml")]?.markDirty()
            // Category slots tile the plot's width, so the outer bars and
            // their half gaps give its left edge and extent.
            let drawn = try bars(deck)
            guard let first = drawn.first, let last = drawn.last else { return nil }
            let slot = drawn[1].x - drawn[0].x
            let left = first.x - (slot - first.width) / 2
            return (left, 0, last.x + last.width + (slot - last.width) / 2 - left, 0)
        }
        plotArea.children.removeAll { if case .element(let child) = $0 { return child.name == "c:layout" } else { return false } }
        let automatic = try #require(try plotBox())

        let manual = try layout("<c:manualLayout><c:layoutTarget val=\"inner\"/><c:xMode val=\"edge\"/><c:yMode val=\"edge\"/><c:x val=\"0.25\"/><c:y val=\"0.2\"/><c:w val=\"0.5\"/><c:h val=\"0.6\"/></c:manualLayout>")
        plotArea.children.insert(.element(manual), at: 0)
        let pinned = try #require(try plotBox())
        let frameX = Double(EMU.inches(1).rawValue), frameWidth = Double(EMU.inches(8).rawValue)
        #expect(abs(pinned.x - (frameX + frameWidth * 0.25)) < 2)
        #expect(abs(pinned.width - frameWidth * 0.5) < 2)
        #expect(abs(pinned.width - automatic.width) > 100_000)

        // Outer targets include tick labels, so they keep the measured layout.
        plotArea.children[0] = .element(try layout("<c:manualLayout><c:layoutTarget val=\"outer\"/><c:xMode val=\"edge\"/><c:yMode val=\"edge\"/><c:x val=\"0.25\"/><c:y val=\"0.2\"/><c:w val=\"0.5\"/><c:h val=\"0.6\"/></c:manualLayout>"))
        let outer = try #require(try plotBox())
        #expect(abs(outer.x - automatic.x) < 1 && abs(outer.width - automatic.width) <= 2)
    }
}
