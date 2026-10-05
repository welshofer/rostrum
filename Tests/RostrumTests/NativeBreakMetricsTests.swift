import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeBreakMetricsTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeBreakMetrics")
    }
    private struct Input: Decodable {
        let name: String
        let page: Int
        let width: Double
        let height: Double
        let table: Bool?
    }
    private struct Capture: Decodable {
        struct Case: Decodable {
            struct Marker: Decodable {
                let text: String
                let x: Double
                let baseline: Double
                let sourceGlyphMatches: Bool
            }
            let name: String
            let markers: [Marker]
        }
        let cases: [Case]
    }
    private func fonts() throws -> FontLibrary {
        let result = FontLibrary()
        try result.register(Data(contentsOf: root.deletingLastPathComponent()
            .appendingPathComponent("Typography/DejaVuSans.ttf")), aliases: ["DejaVu Sans"])
        return result
    }
    @Test func independentNativeEmptyLineOwnership() throws {
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: root.appendingPathComponent("cases.json")))
        let capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: root.appendingPathComponent("native-metrics.json")))
        let deck = try Presentation(contentsOf: root.appendingPathComponent("native-break-metrics-v1.pptx"))
        let fontLibrary = try fonts()
        let before = try deck.serializedData()
        #expect(inputs.count == 18 && capture.cases.count == 18)
        #expect(Set(inputs.map(\.name)).count == 18)
        #expect(Set(capture.cases.map(\.name)).count == 18)
        let names = Set(inputs.map(\.name))
        #expect(deck.slides.flatMap(\.shapes).filter { names.contains($0.name) }.count == 18)
        for (input, native) in zip(inputs, capture.cases) {
            #expect(input.name == native.name)
            let shape = try #require(deck.slides[input.page].shapes.first { $0.name == input.name })
            let frame: TextFrame
            if input.table == true {
                frame = try (try #require((shape as? TableFrame)?.table)).cell(0, 0).textFrame
            } else { frame = try #require(shape.textFrame) }
            let layout = RichTextLayout(textBody: frame.txBody, width: input.width, height: input.height, fonts: fontLibrary)
            #expect(layout.diagnostics.isEmpty)
            let visible = layout.lines.flatMap { line in line.spans.map { ($0, line.baseline) } }
            #expect(visible.count == native.markers.count)
            for ((span, baseline), marker) in zip(visible, native.markers) {
                #expect(span.run.text == marker.text)
                #expect(marker.sourceGlyphMatches)
                #expect(abs(span.x - marker.x) < 0.121)
                // The explicit-spacing cases are independently calibrated by
                // NativeLineSpacing; their original tolerance is unchanged.
                #expect(abs(baseline - marker.baseline) < 0.121, "\(input.name): \(baseline) vs \(marker.baseline)")
            }
        }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        #expect(try reopened.serializedData() == before)
        try deck.fonts.register(Data(contentsOf: root.deletingLastPathComponent()
            .appendingPathComponent("Typography/DejaVuSans.ttf")), aliases: ["DejaVu Sans"])
        for index in 0..<3 {
            let svg = try deck.renderSVG(slideAt: index)
            #expect(try deck.renderSVG(slideAt: index) == svg)
        }
        #expect(try deck.serializedData() == before)
    }

    private func body(_ content: String, defaults: String = "") throws -> XML.Element {
        try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0"/>
        <a:p><a:pPr><a:defRPr sz="1800">\(defaults)</a:defRPr></a:pPr>\(content)</a:p></p:txBody>
        """.utf8))
    }
    private func run(_ text: String, size: Int) -> String {
        "<a:r><a:rPr sz=\"\(size * 100)\"/><a:t>\(text)</a:t></a:r>"
    }
    private func br(_ size: Int) -> String { "<a:br><a:rPr sz=\"\(size * 100)\"/></a:br>" }

    @Test func fallbackAndLiteralNewlinesKeepEmptyLineMetricOwnership() throws {
        // Synthetic fallback has 1em line height; missing-face approximation is
        // 4/3em. Neither adopts the registered font's native baseline rounding.
        let fallback = try FontMetrics(data: TestFont.standard())
        for metrics in [fallback, nil] {
            let factor = metrics == nil ? 4.0 / 3 : 1.0
            let content = run("A", size: 12) + br(36) + br(6) + run("B", size: 12)
            let xml = try body(content)
            let before = xml.serialized()
            let layout = RichTextLayout(textBody: xml, width: 290, height: 160, fallbackMetrics: metrics)
            #expect(layout.lines.map(\.height) == [12 * factor, 6 * factor, 12 * factor])
            #expect(layout.lines.map { $0.spans.map(\.run.text).joined() } == ["A", "", "B"])
            #expect(xml.serialized() == before)
            for size in [6, 36] {
                let populated = RichTextLayout(textBody: try body(run("A", size: 12) + br(size) + run("B", size: 12)),
                    width: 290, height: 160, fallbackMetrics: metrics)
                #expect(populated.lines.map(\.height) == [12 * factor, 12 * factor])
            }
            let literal = RichTextLayout(textBody: try body(run("A\n\nB", size: 12)),
                width: 290, height: 160, fallbackMetrics: metrics)
            #expect(literal.lines.map(\.height) == Array(repeating: 12 * factor, count: 3))
        }
    }

    @Test func trailingEndPropertiesInheritFaceAndSizeWithoutStaleFontContext() throws {
        let library = try fonts()
        let xml = try body(run("A", size: 12) + br(36) + "<a:endParaRPr sz=\"600\"/>",
            defaults: "<a:latin typeface=\"DejaVu Sans\"/>")
        let before = xml.serialized()
        let registered = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
        let fallback = RichTextLayout(textBody: xml, width: 290, height: 160,
            fallbackMetrics: try FontMetrics(data: TestFont.standard()))
        #expect(abs(registered.lines[1].height - 7.2) < 1e-9)
        #expect(fallback.lines[1].height == 6)
        #expect(registered.diagnostics.isEmpty && fallback.diagnostics.isEmpty)
        #expect(RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library).lines.map(\.baseline)
            == registered.lines.map(\.baseline))
        #expect(xml.serialized() == before)
        let paragraph = try #require(xml.firstChild(named: "a:p"))
        let end = try #require(paragraph.firstChild(named: "a:endParaRPr"))
        end[attribute: "sz"] = nil
        let inherited = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
        #expect(abs(inherited.lines[1].height - 21.6) < 1e-9)
        end[attribute: "sz"] = "3600"
        let changed = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
        #expect(abs(changed.lines[1].height - 43.2) < 1e-9)
        let scaled = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library, fontScale: 50)
        #expect(abs(scaled.lines[1].height - 21.6) < 1e-9)
    }
}
