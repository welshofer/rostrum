import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeTableTransitionTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeTableTransitions")
    }
    private struct Line: Decodable, Equatable {
        let points: [Double], color: [Double], opacity: Double, width: Double
    }
    private struct Glyph: Decodable {
        let text: String, origin: [Double], size: Double
    }
    private struct Reference: Decodable {
        let id: String, page: Int, x: Double, y: Double, width: Double, height: Double
        let lines: [Line], glyphs: [Glyph]
    }
    private struct Baseline: Decodable { let id: String, lines: [Line] }
    private func nodes(_ node: XML.Element, _ name: String) -> [XML.Element] {
        (node.name == name ? [node] : []) + node.childElements.flatMap { nodes($0, name) }
    }
    private func close(_ a: [Double], _ b: [Double], tolerance: Double) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < tolerance }
    }
    private func rgb(_ value: String?) throws -> [Double] {
        let string = try #require(value)
        let bits = try #require(UInt32(string.dropFirst(), radix: 16))
        return [Double(bits >> 16), Double((bits >> 8) & 255), Double(bits & 255)].map { $0 / 255 }
    }
    private func point(_ node: XML.Element, _ key: String) throws -> Double {
        try #require(node[attribute: key].flatMap(Double.init)) / Double(EMU.perPoint)
    }
    private func inside(_ x: Double, _ y: Double, _ reference: Reference) -> Bool {
        x >= reference.x - 6 && x <= reference.x + reference.width + 6
            && y >= reference.y - 6 && y <= reference.y + reference.height + 6
    }
    private func lines(_ svg: XML.Element, _ reference: Reference) throws -> [Line] {
        try nodes(svg, "line").compactMap { node in
            let points = try ["x1", "y1", "x2", "y2"].map { try point(node, $0) }
            guard inside(points[0], points[1], reference) else { return nil }
            return Line(points: points, color: try rgb(node[attribute: "stroke"]),
                        opacity: node[attribute: "stroke-opacity"].flatMap(Double.init) ?? 1,
                        width: try point(node, "stroke-width"))
        }
    }
    // Coalesce only adjacent identical paint. Native PDF coalesces some outer
    // strokes; preserve every distinct color, width, opacity and interval.
    private func intervals(_ lines: [Line]) -> [[Double]] {
        let values = lines.map { line -> [Double] in
            let p = line.points, vertical = p[0] == p[2]
            return [vertical ? 1 : 0, vertical ? p[0] : p[1], line.width, line.opacity]
                + line.color.map { ($0 * 255).rounded() }
                + [vertical ? p[1] : p[0], vertical ? p[3] : p[2]]
        }.sorted { $0.lexicographicallyPrecedes($1) }
        var result: [[Double]] = []
        for value in values {
            if let last = result.last, close(Array(last.prefix(7)), Array(value.prefix(7)), tolerance: 0.001),
               abs(last[8] - value[7]) < 0.001 {
                result[result.count - 1][8] = value[8]
            } else { result.append(value) }
        }
        return result
    }
    private func bounds(_ line: Line) -> [Double] {
        let p = line.points, half = line.width / 2
        return p[0] == p[2] ? [p[0] - half, p[1], p[2] + half, p[3]]
            : [p[0], p[1] - half, p[2], p[3] + half]
    }
    private func paintedColor(_ lines: [Line], x: Double, y: Double) -> [Double]? {
        lines.last { line in
            let b = bounds(line)
            return x >= b[0] && y >= b[1] && x <= b[2] && y <= b[3]
        }?.color
    }
    private func check(_ svg: XML.Element, _ reference: Reference, expectedLines: [Line]) throws {
        #expect(nodes(svg, "g").allSatisfy { $0[attribute: "transform"] == nil })
        let cellFills = try nodes(svg, "rect").filter {
            try inside(point($0, "x"), point($0, "y"), reference)
                && point($0, "width") <= reference.width && point($0, "height") <= reference.height
        }
        #expect(cellFills.isEmpty, "\(reference.id): explicit noFill cells")
        let actual = try lines(svg, reference)
        // Validate raw colors before byte-channel grouping, independently of
        // the finite PDF channel quantization used by the interval projection.
        for line in actual {
            #expect(expectedLines.contains { $0.width == line.width && $0.opacity == line.opacity
                && close($0.color, line.color, tolerance: 0.0001) })
        }
        let a = intervals(actual), b = intervals(expectedLines)
        #expect(a.count == b.count, "\(reference.id): complete painted intervals")
        for (first, second) in zip(a, b) {
            #expect(close(first, second, tolerance: 0.001), "\(reference.id): native interval \(first) versus \(second)")
        }
        // No cell fills are authored. Preserve full ordered opaque paint, not
        // just its union: every open subdivision rectangle has constant color.
        let paint = actual + expectedLines
        #expect(paint.allSatisfy { $0.opacity == 1 })
        let boxes = paint.map(bounds)
        let xs = Set(boxes.flatMap { [$0[0], $0[2]] }).sorted()
        let ys = Set(boxes.flatMap { [$0[1], $0[3]] }).sorted()
        var matches = true
        for (left, right) in zip(xs, xs.dropFirst()) {
            for (top, bottom) in zip(ys, ys.dropFirst()) {
                let x = (left + right) / 2, y = (top + bottom) / 2
                let observed = paintedColor(actual, x: x, y: y)
                let native = paintedColor(expectedLines, x: x, y: y)
                if let observed, let native {
                    if !close(observed, native, tolerance: 0.0001) { matches = false }
                } else if (observed == nil) != (native == nil) { matches = false }
            }
        }
        #expect(matches, "\(reference.id): complete ordered opaque paint")
        var glyphs: [Glyph] = []
        for text in nodes(svg, "text") {
            guard let transform = text[attribute: "transform"] else { continue }
            let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            guard values.count == 3, inside(values[0] / Double(EMU.perPoint), values[1] / Double(EMU.perPoint), reference) else { continue }
            #expect(values[2] == Double(EMU.perPoint))
            for span in text.childElements {
                let xs = try #require(span[attribute: "x"]).split(separator: " ").compactMap { Double($0) }
                let scalars = Array(span.textContent.unicodeScalars)
                #expect(xs.count == scalars.count && span[attribute: "textLength"] == nil)
                let size = try #require(span[attribute: "font-size"].flatMap(Double.init))
                for (scalar, x) in zip(scalars, xs) {
                    glyphs.append(Glyph(text: String(scalar), origin: [values[0] / Double(EMU.perPoint) + x, values[1] / Double(EMU.perPoint)], size: size))
                }
            }
        }
        #expect(glyphs.count == reference.glyphs.count)
        for (actual, native) in zip(glyphs, reference.glyphs) {
            #expect(actual.text == native.text)
            #expect(abs(actual.origin[0] - native.origin[0]) < 0.025)
            // New frame positions expose the already calibrated native print
            // placement residual, up to 0.080078 pt here. No text formula changes.
            #expect(abs(actual.origin[1] - native.origin[1]) < 0.121)
            #expect(abs(actual.size - native.size) < 0.002)
        }
    }
    @Test func nativeTransitionsPreserveAllPaintAndGlyphs() throws {
        var caseCount = 0, glyphCount = 0, intervalCount = 0
        for folder in ["vertical", "horizontal"] {
            let directory = root.appendingPathComponent(folder)
            let name = folder == "vertical" ? "native-table-transitions21-v1.pptx" : "native-table-transitions21-horizontal-v1.pptx"
            let deck = try Presentation(contentsOf: directory.appendingPathComponent(name))
            #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
            let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: directory.appendingPathComponent("paint-reference.json")))
            let baseline = try JSONDecoder().decode([Baseline].self, from: Data(contentsOf: directory.appendingPathComponent("baseline-paint.json")))
            let texts = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: directory.appendingPathComponent("baseline-text.json")))
            #expect(references.count == (folder == "vertical" ? 8 : 6))
            #expect(Set(references.map(\.id)).count == references.count)
            #expect(Set(texts.keys) == Set(references.map(\.id)))
            let font = root.deletingLastPathComponent().appendingPathComponent("NativeListMarkers/fonts/DejaVuSans.ttf")
            #expect(deck.fonts.data(for: FontFaceKey(family: "DejaVu Sans")) == (try Data(contentsOf: font)))
            let saved = try deck.serializedData()
            for page in 0..<2 {
                let result = try deck.renderSVGReportingProblems(slideAt: page)
                #expect(result.problems.fidelityIssues.isEmpty && result.problems.unsupportedContent.isEmpty)
                let parsed = try XML.parse(Data(result.svg.utf8))
                for reference in references where reference.page == page {
                    // Colored merges remain excluded even though the offline
                    // hypothesis matches this one native control. Assert exact
                    // frozen pre-fix border geometry, while checking native text.
                    let excluded = reference.id == "merged-colored-rejection"
                    let prior = try #require(baseline.first { $0.id == reference.id })
                    try check(parsed, reference, expectedLines: excluded ? prior.lines : reference.lines)
                    if excluded {
                        #expect(try lines(parsed, reference) == prior.lines, "exact rejected merged paint and order")
                    }
                    if !excluded { intervalCount += intervals(reference.lines).count }
                    let body = nodes(parsed, "text").filter { text in
                        guard let transform = text[attribute: "transform"] else { return false }
                        let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
                        return values.count == 3 && inside(values[0] / Double(EMU.perPoint), values[1] / Double(EMU.perPoint), reference)
                    }
                    let expected = try #require(texts[reference.id]).map { try XML.parse(Data($0.utf8)).serialized() }
                    let unchanged = body.map { $0.serialized() } == expected
                    #expect(unchanged, "\(reference.id): exact baseline text attributes and scalar positions")
                    caseCount += 1; glyphCount += reference.glyphs.count
                }
                #expect(try deck.renderSVG(slideAt: page) == result.svg)
            }
            #expect(try deck.serializedData() == saved)
            let reopened = try Presentation(data: saved); reopened.registerEmbeddedFonts()
            for page in 0..<2 { #expect(try reopened.renderSVG(slideAt: page) == deck.renderSVG(slideAt: page)) }
            #expect(try reopened.serializedData() == saved)
        }
        #expect(caseCount == 14 && glyphCount == 240 && intervalCount == 107)
    }
    @Test func reusedRendererSeesLiveColorWidthAndNoFillDonors() throws {
        let directory = root.appendingPathComponent("horizontal")
        let deck = try Presentation(contentsOf: directory.appendingPathComponent("native-table-transitions21-horizontal-v1.pptx"))
        deck.registerEmbeddedFonts()
        let slide = try deck.slides[1]
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 2)
        let original = try renderer.render(pixelWidth: 640)
        let frame = try #require(slide.shapes.first { $0.name == "horizontal-noFill-donor" } as? TableFrame)
        let table = try #require(frame.table), alias = try #require(frame.table)
        let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: directory.appendingPathComponent("paint-reference.json")))
        let native = try #require(references.first { $0.id == "horizontal-outer-narrow-wide" })
        // The native source pair has identical frames and all other properties.
        // Restoring both agreeing direct donor declarations reproduces its paint.
        let left = try #require(try alias.cell(0, 0).tc.firstChild(named: "a:tcPr")?.firstChild(named: "a:lnR"))
        let right = try #require(try alias.cell(0, 1).tc.firstChild(named: "a:tcPr")?.firstChild(named: "a:lnL"))
        let leftChildren = left.children, rightChildren = right.children
        for line in [left, right] {
            line.children = [XML.Node.element(try XML.parse(Data("<a:solidFill><a:srgbClr val=\"0044CC\"/></a:solidFill>".utf8)))]
        }
        table.part.markDirty()
        let changed = try renderer.render(pixelWidth: 640)
        #expect(changed.svg != original.svg)
        try check(XML.parse(Data(changed.svg.utf8)), native, expectedLines: native.lines)
        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved); reopened.registerEmbeddedFonts()
        #expect(try reopened.renderSVG(slideAt: 1, pixelWidth: 640) == changed.svg)
        // A reused renderer must also resolve subsequent direct width/color edits.
        let color = try #require(left.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr"))
        color[attribute: "val"] = "987654"; left[attribute: "w"] = "63500"
        let rightColor = try #require(right.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr"))
        rightColor[attribute: "val"] = "987654"; right[attribute: "w"] = "63500"; table.part.markDirty()
        let edited = try renderer.render(pixelWidth: 640)
        let fresh = try deck.renderSVGReportingProblems(slideAt: 1, pixelWidth: 640)
        #expect(edited.svg == fresh.svg && edited.svg != changed.svg)
        #expect(edited.problems.fidelityIssues == fresh.problems.fidelityIssues)
        left.children = leftChildren; right.children = rightChildren
        left[attribute: "w"] = "38100"; right[attribute: "w"] = "38100"; table.part.markDirty()
        #expect(try renderer.render(pixelWidth: 640).svg == original.svg)
    }

}
