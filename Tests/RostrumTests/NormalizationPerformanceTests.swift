import Foundation
import Testing
@testable import Rostrum

@Suite struct NormalizationPerformanceTests {
    private var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography")
    }

    // Frozen output from release baseline 57dfe353, generated before the ASCII
    // normalization bypass using the repository's pinned DejaVu Sans fixture.
    // This is a preservation oracle; HarfBuzz tests establish shaping fidelity.
    @Test func shapingMatchesPreOptimizationReference() throws {
        struct Case: Decodable {
            struct Break: Decodable { let offset: Int; let mandatory: Bool }
            let text: String; let direction: String; let kerning: Bool
            let resolvedDirection: String; let glyphs: [[Double]]
            let breaks: [Break]; let diagnostics: [String]
        }
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf:
            fixture.appendingPathComponent("normalization-baseline.json")))
        let shaper = TextShaper(try FontMetrics(contentsOf: fixture.appendingPathComponent("DejaVuSans.ttf")))
        #expect(cases.count == 48)
        for reference in cases {
            let run = shaper.shape(reference.text, pointSize: 12.5,
                direction: try #require(TextDirection(rawValue: reference.direction)), kerning: reference.kerning)
            #expect(run.direction.rawValue == reference.resolvedDirection)
            #expect(run.glyphs.map { [Double($0.glyphID), Double($0.scalarRange.lowerBound),
                Double($0.scalarRange.upperBound), $0.advance, $0.xOffset, $0.yOffset,
                Double($0.bidiLevel)] } == reference.glyphs, "\(reference.text)")
            #expect(run.breaks.map(\.scalarOffset) == reference.breaks.map(\.offset))
            #expect(run.breaks.map(\.mandatory) == reference.breaks.map(\.mandatory))
            #expect(run.diagnostics.map { String(describing: $0) } == reference.diagnostics)
        }
    }

    @Test func asciiClustersHaveScalarOffsetsAndCRLFRemainsOneBreak() throws {
        let metrics = try FontMetrics(data: TestFont.standard())
        let text = String(String.UnicodeScalarView((0..<128).compactMap(Unicode.Scalar.init)))
        let run = TextShaper(metrics).shape(text, pointSize: 10)
        let scalars = Array(text.unicodeScalars).filter { $0 != "\r" && $0 != "\n" }
        #expect(run.glyphs.map(\.glyphID) == scalars.map { metrics.glyphID(for: $0) })
        #expect(run.glyphs.map(\.scalarRange) == scalars.map { Int($0.value)..<(Int($0.value) + 1) })
        let crlf = TextShaper(metrics).shape("A\r\nB", pointSize: 10)
        #expect(crlf.glyphs.map(\.scalarRange) == [0..<1, 3..<4])
        #expect(crlf.breaks.map(\.scalarOffset) == [3])
        #expect(crlf.breaks.map(\.mandatory) == [true])
    }

    @Test func registeredLayoutReadsFreshDOMWithoutChangingIt() throws {
        let metrics = try FontMetrics(contentsOf: fixture.appendingPathComponent("DejaVuSans.ttf"))
        let body = try XML.parse(Data("<p:txBody><a:bodyPr/><a:p><a:r><a:t>office AV</a:t></a:r></a:p></p:txBody>".utf8))
        let initial = body.serialized()
        let first = RichTextLayout(textBody: body, width: 300, height: 100, fallbackMetrics: metrics)
        #expect(body.serialized() == initial)
        let text = try #require(body.firstChild(named: "a:p")?.firstChild(named: "a:r")?.firstChild(named: "a:t"))
        text.children = [.text("cafe\u{301} 中文")]
        let edited = body.serialized()
        let second = RichTextLayout(textBody: body, width: 300, height: 100, fallbackMetrics: metrics)
        #expect(body.serialized() == edited)
        #expect(first.lines.flatMap(\.spans).map(\.run.text) != second.lines.flatMap(\.spans).map(\.run.text))
        #expect(second.lines.flatMap(\.spans).map(\.run.text).joined() == "cafe\u{301} 中文")
    }
}
