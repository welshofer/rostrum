import Foundation
import Testing
@testable import Rostrum

@Suite struct LineBreakBoundaryTests {
    @Test func nativePowerPointBoundaryLineContents() throws {
        struct Capture: Decodable {
            struct Face: Decodable { let name: String; let unitsPerEm: Int; let advances: [Int]; let kern: [[Int]] }
            struct Case: Decodable {
                struct Line: Decodable {
                    struct Character: Decodable { let text: String; let x: Double; let size: Double }
                    let text: String; let characters: [Character]
                }
                let name: String; let lines: [Line]
            }
            let source: String; let faces: [Face]; let cases: [Case]
        }
        struct Input: Decodable {
            struct Run: Decodable { let text: String; let face: String; let size: Double; let fontScale: Double? }
            let name: String; let page: Int; let width: Double; let height: Double; let runs: [Run]
        }
        struct Observation: Encodable { let name: String; let native: [String]; let actual: [String]; let widths: [Double] }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/LineBreakBoundaries")
        var observations: [Observation] = []
        for suffix in ["", "-followup", "-final", "-scale", "-coordinates"] {
        let capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: root.appendingPathComponent("native-geometry\(suffix).json")))
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: root.appendingPathComponent("cases\(suffix).json")))
        let fonts = FontLibrary()
        for face in capture.faces where face.name != "DejaVu Sans" {
            let advances = [face.unitsPerEm / 2] + face.advances
            var os2 = TestFont.os2(useTypoMetrics: false)
            os2.replaceSubrange(62..<64, with: TestFont.be16(face.name == "Arial Bold" ? 0x20 : 0x40))
            let header: [Int] = [0, 1, 0, 14 + face.kern.count * 6, 1, face.kern.count, 0, 0, 0]
            var kern = header.flatMap { TestFont.be16($0) }
            kern += face.kern.flatMap { $0.flatMap { TestFont.be16($0) } }
            let data = Data(TestFont.assemble(tables: [
                ("head", TestFont.head(upem: face.unitsPerEm)),
                ("hhea", TestFont.hhea(ascender: 1600, descender: -400, lineGap: 0, numberOfHMetrics: advances.count)),
                ("maxp", TestFont.maxp(numGlyphs: advances.count)), ("hmtx", TestFont.hmtx(advances: advances)),
                ("cmap", TestFont.cmapFormat4()), ("OS/2", os2), ("kern", kern)
            ]))
            try fonts.register(data, aliases: ["Arial"])
        }
        let bundled = root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf")
        try fonts.register(Data(contentsOf: bundled), aliases: ["DejaVu Sans"])
        let deck = try Presentation(contentsOf: root.appendingPathComponent(capture.source))
        let originalData = try deck.serializedData()
        #expect(inputs.count == capture.cases.count)
        for (input, native) in zip(inputs, capture.cases) {
            #expect(input.name == native.name)
            let shape = try #require(deck.slides[input.page].shapes.first { $0.name == input.name })
            let frame = try #require(shape.textFrame)
            let layout = RichTextLayout(textBody: frame.txBody, width: input.width, height: input.height, fonts: fonts)
            let actual = layout.lines.map { $0.spans.map(\.run.text).joined() }
            let expected = native.lines.map(\.text)
            observations.append(Observation(name: input.name, native: expected, actual: actual, widths: layout.lines.map(\.width)))
            #expect(actual == expected, "\(input.name): native \(expected), actual \(actual)")
            // NativeLigatureLayout directly establishes individual office glyphs,
            // so this earlier control now receives the same geometry assertions.
            do {
                var characterOffset = 0
                for (line, expectedLine) in zip(layout.lines, native.lines) {
                    let first = try #require(line.spans.first)
                    let last = try #require(line.spans.last)
                    let nativeFirst = try #require(expectedLine.characters.first)
                    let nativeLast = try #require(expectedLine.characters.last)
                    #expect(abs(first.x - nativeFirst.x) < 0.025, "\(input.name): native line start")
                    let lastOffset = characterOffset + expectedLine.characters.count - 1
                    var runOffset = 0
                    let source = try #require(input.runs.first { run in
                        defer { runOffset += run.text.count }
                        return lastOffset < runOffset + run.text.count
                    })
                    characterOffset += expectedLine.characters.count
                    let family = source.face == "Arial Bold" ? "Arial" : source.face
                    let font = try #require(fonts.metrics(for: family, bold: source.face == "Arial Bold", italic: false))
                    let sourceSize = source.size * (input.runs.first?.fontScale ?? 100_000) / 100_000
                    #expect(last.run.fontSize == sourceSize)
                    // PDF's font resource may say 24 pt for authored 23.5 pt, while
                    // positioned advances retain the source size. Use that size
                    // only for the final glyph, whose next origin is unavailable.
                    let scalar = try #require(nativeLast.text.unicodeScalars.first)
                    let rawLast = Double(font.advance(of: scalar)) * sourceSize / Double(font.unitsPerEm)
                    let lastAdvance = (rawLast * 8).rounded() / 8 + last.run.tracking
                    let expectedWidth = nativeLast.x - nativeFirst.x + lastAdvance
                    // PDF text matrices retain fewer digits than the source advances.
                    #expect(abs(line.width - expectedWidth) < 0.06, "\(input.name): native line width")
                }
            }
        }
        #expect(try deck.serializedData() == originalData)
        if suffix.isEmpty, let path = ProcessInfo.processInfo.environment["ROSTRUM_BOUNDARY_SAVED"] {
            let url = URL(fileURLWithPath: path)
            try originalData.write(to: url)
            #expect(try Presentation(contentsOf: url).slides.count == deck.slides.count)
        }
        }
        if let path = ProcessInfo.processInfo.environment["ROSTRUM_BOUNDARY_OBSERVATIONS"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(observations).write(to: URL(fileURLWithPath: path))
        }
    }
}

extension LineBreakBoundaryTests {
    @Test func visibleAdvanceExcludesOnlyTrailingOrdinarySpaces() throws {
        let font = try FontMetrics(data: TestFont.standard())
        let xml = try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:p><a:pPr><a:defRPr sz="1000"/></a:pPr></a:p>
        <a:p><a:pPr><a:defRPr sz="1000"/></a:pPr><a:r><a:t>   </a:t></a:r></a:p>
        <a:p><a:pPr><a:defRPr sz="1000"/></a:pPr><a:r><a:t>A </a:t></a:r><a:r><a:rPr spc="25"/><a:t>B  </a:t></a:r></a:p>
        <a:p><a:pPr marL="127000" indent="-63500"><a:buChar char="*"/><a:tabLst><a:tab pos="381000"/></a:tabLst><a:defRPr sz="1000"/></a:pPr><a:r><a:t>A\tB  </a:t></a:r></a:p>
        </p:txBody>
        """.utf8))
        let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: font)
        #expect(layout.lines.map(\.width) == [0, 7.5, 18.25, 27.5])
        #expect(layout.lines.map(\.visibleWidth) == [0, 0, 12.75, 22.5])
        #expect(layout.lines[3].spans.first?.run.text == "* ")
    }

    @Test func mixedClusterParagraphKeepsDiagnosedSegmentMeasurements() throws {
        let fontURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        let font = try FontMetrics(contentsOf: fontURL)
        let xml = try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:p>
        <a:r><a:rPr sz="1800"/><a:t>m</a:t></a:r><a:r><a:rPr sz="1800"/><a:t>ffi</a:t></a:r><a:r><a:rPr sz="1800"/><a:t>x́</a:t></a:r>
        </a:p></p:txBody>
        """.utf8))
        let before = xml.serialized()
        let layout = RichTextLayout(textBody: xml, width: 100, height: 100, fallbackMetrics: font)
        let spans = try #require(layout.lines.first).spans
        #expect(spans[0].width == 17.5)
        #expect(spans[1].width == TextShaper(font).shape("ffi", pointSize: 18).width)
        #expect(layout.diagnostics.contains(.unsupportedLayoutFeature("Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified")))
        #expect(xml.serialized() == before)
    }
}

extension LineBreakBoundaryTests {
    @Test func emptyUnresolvedRunsDoNotChangeGridEligibilityAndRTLStaysApproximate() throws {
        let fontURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        let fonts = FontLibrary()
        try fonts.register(Data(contentsOf: fontURL), aliases: ["Boundary"])
        func body(empty: Bool, rtl: Bool) throws -> XML.Element {
            let invisible = empty ? "<a:r><a:rPr><a:latin typeface=\"Unavailable\"/></a:rPr><a:t/></a:r>" : ""
            return try XML.parse(Data("""
            <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:p><a:pPr rtl="\(rtl ? 1 : 0)" marL="381"/>
            \(invisible)<a:r><a:rPr sz="1800"><a:latin typeface="Boundary"/></a:rPr><a:t>mmmmmmmmmmmmZ</a:t></a:r>
            </a:p></p:txBody>
            """.utf8))
        }
        let original = RichTextLayout(textBody: try body(empty: false, rtl: false), width: 210.1, height: 100, fonts: fonts)
        let inserted = RichTextLayout(textBody: try body(empty: true, rtl: false), width: 210.1, height: 100, fonts: fonts)
        #expect(original.lines == inserted.lines)
        let rtl = RichTextLayout(textBody: try body(empty: false, rtl: true), width: 300, height: 100, fonts: fonts)
        let font = try #require(fonts.metrics(for: "Boundary"))
        let first = try #require(rtl.lines.first?.spans.first)
        #expect(first.width == TextShaper(font).shape(first.run.text, pointSize: 18).width)
        #expect(first.x == 0.03)
        #expect(rtl.diagnostics.contains(.unsupportedLayoutFeature("Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified")))
    }
}
