import Foundation
import Testing
@testable import Rostrum

@Suite struct LayoutShapedBreakReuseTests {
    // 0: registered face, 1: explicit fallback metrics, 2: unregistered estimate.
    private func layout(_ text: String, mode: Int, width: Double = 45, caps: Bool = false,
                        size: String? = "1200", defaultSize: Double = 18,
                        scale: Double? = nil) throws -> RichTextLayout {
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        let data = try Data(contentsOf: font)
        let fonts = FontLibrary()
        if mode == 0 { try fonts.register(data, aliases: ["BreakProof"]) }
        let body = try XML.parse(Data("<p:txBody><a:bodyPr lIns=\"0\" rIns=\"0\" tIns=\"0\" bIns=\"0\"/><a:p><a:r><a:rPr><a:latin typeface=\"BreakProof\"/></a:rPr></a:r></a:p></p:txBody>".utf8))
        let run = try #require(body.firstChild(named: "a:p")?.firstChild(named: "a:r"))
        let properties = try #require(run.firstChild(named: "a:rPr"))
        properties[attribute: "sz"] = size
        properties[attribute: "cap"] = caps ? "all" : "none"
        run.appendElement(XML.Element("a:t", children: [.text(text)]))
        let before = body.serialized()
        let result = RichTextLayout(textBody: body, width: width, height: 1000,
            fonts: mode == 0 ? fonts : nil, fallbackMetrics: mode == 1 ? try FontMetrics(data: data) : nil,
            defaultPointSize: defaultSize, fontScale: scale)
        #expect(body.serialized() == before)
        return result
    }

    @Test(arguments: [0, 1, 2])
    func arabicJoiningControlsKeepSourceBreaksAndDiagnosticOrder(mode: Int) throws {
        let result = try layout("س\u{200C}لام\u{200B}عالم", mode: mode)
        #expect(result.lines.map { $0.spans.map(\.run.text).joined() } == ["س\u{200C}لام\u{200B}", "عالم"])
        #expect(result.lines.map(\.width) == (mode == 2 ? [25.2, 20.16] : [28.921875, 22.458984375]))
        let messages = mode == 2 ? ["Unregistered font face: BreakProof"] : [
            "Mixed Arabic paragraph bidi and explicit LTR Arabic shaping are unsupported",
            "Rich-text bidirectional span ordering requires a verified paragraph renderer",
            "Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified",
        ]
        #expect(result.diagnostics == messages.map(ShapingDiagnostic.unsupportedLayoutFeature))
    }

    @Test(arguments: [0, 1, 2])
    func cjkAndCapitalizedCombiningTextKeepTheirWrapBoundaries(mode: Int) throws {
        let cjk = try layout("中文（测试）文本", mode: mode)
        #expect(cjk.lines.map { $0.spans.map(\.run.text).joined() }
            == (mode == 2 ? ["中文（测试）文本"] : ["中文（测试）", "文本"]))
        let caps = try layout("cafe\u{301} ß \u{344} x", mode: mode, caps: true)
        #expect(caps.lines.map { $0.spans.map(\.run.text).joined() }
            == (mode == 2 ? ["CAFE\u{301} SS \u{344} ", "X"] : ["CAFE\u{301} ", "SS \u{344} X"]))
    }

    @Test(arguments: [0, 1, 2])
    func crlfTabsAndSingleBreaksRemainSeparateFromSegmentWrapping(mode: Int) throws {
        let result = try layout("A\r\nB\tC\nD\rE", mode: mode, width: 300)
        #expect(result.lines.map { $0.spans.map(\.run.text).joined() } == ["A", "BC", "D", "E"])
        #expect(result.lines[1].spans.map(\.x) == [0, 72])
        #expect(!result.diagnostics.contains(.invalidPointSize))
    }

    @Test(arguments: [0, 1, 2])
    func malformedSizesAndScalesStillReachFinitePositiveShaping(mode: Int) throws {
        let cases: [(String?, Double, Double?, Double)] = [
            ("nan", 18, nil, 1), ("inf", 18, 100, 1), ("-1", 18, -1, 0.001),
            ("0", 18, .nan, 0.001), ("400001", 18, .infinity, 4),
            (nil, .nan, nil, 1), (nil, .infinity, 50, 0.5),
        ]
        for (size, defaultSize, scale, expected) in cases {
            let result = try layout("س\u{200D}لام\u{200B}عالم", mode: mode, width: 300,
                                    size: size, defaultSize: defaultSize, scale: scale)
            let spans = result.lines.flatMap(\.spans)
            #expect(!spans.isEmpty)
            #expect(spans.allSatisfy { $0.run.fontSize == expected })
            #expect(!result.diagnostics.contains(.invalidPointSize))
        }
    }
}
