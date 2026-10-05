import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeLigatureLayoutTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeLigatureLayout")
    }
    private struct Input: Decodable {
        struct Run: Decodable { let text: String; let size: Double }
        let name: String
        let page: Int
        let width: Double
        let height: Double
        let table: Bool?
        let fontScale: Double?
        let runs: [Run]
    }
    private struct Capture: Decodable {
        struct Case: Decodable {
            struct Line: Decodable {
                struct Character: Decodable {
                    struct Identity: Decodable { let matchesSourceGlyph: Bool }
                    struct Authored: Decodable { let text: String; let pointSize: Double; let tracking: Double }
                    let authored: Authored
                    let text: String
                    let x: Double
                    let identity: Identity?
                }
                let text: String
                let characters: [Character]
            }
            let name: String
            let lines: [Line]
        }
        let source: String
        let cases: [Case]
    }

    @Test func nativeWordsRunBoundariesAndWrapsUseIndividualLatinGlyphs() throws {
        let input = try JSONDecoder().decode([Input].self, from: Data(contentsOf: root.appendingPathComponent("cases.json")))
        let capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: root.appendingPathComponent("native-geometry.json")))
        let fonts = FontLibrary()
        try fonts.register(Data(contentsOf: root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf")), aliases: ["DejaVu Sans"])
        let metrics = try #require(fonts.metrics(for: "DejaVu Sans"))
        let deck = try Presentation(contentsOf: root.appendingPathComponent(capture.source))
        let before = try deck.serializedData()
        #expect(input.count == capture.cases.count)
        #expect(Set(input.map(\.name)).count == input.count)
        #expect(Set(capture.cases.map(\.name)).count == capture.cases.count)
        let probeShapes = deck.slides.flatMap(\.shapes).filter { Set(input.map(\.name)).contains($0.name) }
        #expect(probeShapes.count == input.count)
        for (source, native) in zip(input, capture.cases) {
            #expect(source.name == native.name)
            let shape = try #require(deck.slides[source.page].shapes.first { $0.name == source.name })
            let frame: TextFrame
            if source.table == true {
                let table = try #require((shape as? TableFrame)?.table)
                frame = try table.cell(0, 0).textFrame
            } else {
                frame = try #require(shape.textFrame)
            }
            let layout = RichTextLayout(textBody: frame.txBody, width: source.width, height: source.height, fonts: fonts)
            if ["office-edge-below", "office-edge-above", "mixed-size-edge"].contains(source.name) {
                let omittedBody = try XML.parse(Data(frame.txBody.serialized().utf8))
                for paragraph in omittedBody.children(named: "a:p") {
                    for run in paragraph.children(named: "a:r") {
                        run.firstChild(named: "a:rPr")?[attribute: "kern"] = nil
                    }
                }
                let omitted = RichTextLayout(textBody: omittedBody, width: source.width, height: source.height, fonts: fonts)
                #expect(omitted.lines.map(\.width) == layout.lines.map(\.width))
                #expect(omitted.lines.map { $0.spans.map(\.x) } == layout.lines.map { $0.spans.map(\.x) })
                #expect(omitted.lines.map { $0.spans.map(\.run.text).joined() } == native.lines.map(\.text))
            }
            if source.name == "hard-break" {
                // Unstyled a:br still needs unresolved face metrics for vertical
                // line boxes; this probe calibrates horizontal glyph geometry.
                #expect(layout.diagnostics == [.unsupportedLayoutFeature("Unregistered font face: unspecified")])
            } else {
                #expect(layout.diagnostics.isEmpty, "\(source.name): supported native Latin case")
            }
            #expect(layout.lines.count == native.lines.count, "\(source.name): line count")
            for (line, expected) in zip(layout.lines, native.lines) {
                let text = line.spans.map(\.run.text).joined()
                #expect(text == expected.text, "\(source.name): native line content")
                #expect(expected.characters.allSatisfy { $0.identity?.matchesSourceGlyph == true }, "\(source.name): native individual source glyph identity")
                let visibleCharacters = expected.characters.filter { $0.authored.text != "\t" }
                var consumed = 0
                for span in line.spans {
                    let count = span.run.text.unicodeScalars.count
                    guard consumed + count <= visibleCharacters.count else {
                        Issue.record("\(source.name): extra layout glyphs")
                        break
                    }
                    let glyphs = Array(visibleCharacters[consumed..<(consumed + count)])
                    consumed += count
                    #expect(span.run.text == glyphs.map(\.text).joined(), "\(source.name): span content")
                    let start = try #require(glyphs.first)
                    let end = try #require(glyphs.last)
                    let scalar = try #require(end.text.unicodeScalars.first)
                    let rawAdvance = Double(metrics.advance(of: scalar)) * end.authored.pointSize / Double(metrics.unitsPerEm)
                    let finalAdvance = (rawAdvance * 8).rounded() / 8 + end.authored.tracking
                    let expectedWidth = end.x - start.x + finalAdvance
                    #expect(abs(span.x - start.x) < 0.025, "\(source.name): native span origin")
                    #expect(abs(span.width - expectedWidth) < 0.06, "\(source.name): native span width")
                }
                #expect(consumed == visibleCharacters.count, "\(source.name): complete native glyph consumption")
                let first = try #require(line.spans.first)
                let last = try #require(line.spans.last)
                let nativeFirst = try #require(expected.characters.first)
                let nativeLast = try #require(expected.characters.last)
                #expect(abs(first.x - nativeFirst.x) < 0.025, "\(source.name): native start")
                let scalar = try #require(nativeLast.text.unicodeScalars.first)
                let sourceSize = nativeLast.authored.pointSize
                #expect(last.run.fontSize == sourceSize, "\(source.name): authored effective size")
                let raw = Double(metrics.advance(of: scalar)) * sourceSize / Double(metrics.unitsPerEm)
                let lastAdvance = (raw * 8).rounded() / 8 + nativeLast.authored.tracking
                let width = nativeLast.x - nativeFirst.x + lastAdvance
                #expect(abs(line.width - width) < 0.06, "\(source.name): native width")
            }
        }
        #expect(try deck.serializedData() == before)
    }
}

extension NativeLigatureLayoutTests {
    @Test func standaloneLigaturesKeepIndependentHarfBuzzDefaults() throws {
        struct Oracle: Decodable {
            struct Case: Decodable {
                struct Glyph: Decodable { let g: Int; let cl: Int; let ax: Double }
                let text: String
                let liga1: [Glyph]
                let liga0: [Glyph]
            }
            let cases: [Case]
        }
        let oracle = try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: root.appendingPathComponent("harfbuzz-controls.json")))
        let metrics = try FontMetrics(contentsOf: root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf"))
        for sample in oracle.cases {
            let shaped = TextShaper(metrics).shape(sample.text, pointSize: 2048)
            #expect(shaped.glyphs.map(\.glyphID) == sample.liga1.map(\.g))
            #expect(shaped.glyphs.map(\.advance) == sample.liga1.map(\.ax))
            #expect(shaped.glyphs.map(\.scalarRange.lowerBound) == sample.liga1.map(\.cl))
            #expect(shaped.isSupported)
            let native = TextShaper(metrics).shape(sample.text, pointSize: 2048, kerning: true, standardLigatures: false)
            #expect(native.glyphs.map(\.glyphID) == sample.liga0.map(\.g))
            #expect(native.glyphs.map(\.advance) == sample.liga0.map(\.ax))
            #expect(native.glyphs.map(\.scalarRange.lowerBound) == sample.liga0.map(\.cl))
            #expect(native.isSupported)
        }
    }
}


extension NativeLigatureLayoutTests {
    @Test func optionalLatinPolicyPreservesRequiredArabicShaping() throws {
        let metrics = try FontMetrics(contentsOf: root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf"))
        let shaper = TextShaper(metrics)
        for text in ["سلام", "لا", "بَ", "لَا", "سلام abc"] {
            let ordinary = shaper.shape(text, pointSize: 18)
            let policy = shaper.shape(text, pointSize: 18, kerning: true, standardLigatures: false)
            #expect(policy == ordinary)
        }
    }
}

extension NativeLigatureLayoutTests {
    @Test func nativePolicyRemainsBoundedToLTRASCIIParagraphs() throws {
        let metrics = try FontMetrics(contentsOf: root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf"))
        for (extra, direction, expectedPolicy) in [("", "0", false), ("x́", "0", true), ("ß", "0", true), ("", "1", true)] {
            let body = try XML.parse(Data("""
            <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:p><a:pPr rtl="\(direction)"/>
            <a:r><a:rPr sz="1800"/><a:t>ffi</a:t></a:r><a:r><a:rPr sz="1800" cap="all"/><a:t>\(extra)</a:t></a:r>
            </a:p></p:txBody>
            """.utf8))
            let layout = RichTextLayout(textBody: body, width: 200, height: 100, fallbackMetrics: metrics)
            let first = try #require(layout.lines.first?.spans.first)
            #expect(first.run.usesStandardLigatures == expectedPolicy)
            if expectedPolicy {
                #expect(!layout.diagnostics.isEmpty)
                #expect(first.width == TextShaper(metrics).shape("ffi", pointSize: 18).width)
            } else {
                #expect(layout.diagnostics.isEmpty)
                #expect(first.width == 17.75)
            }
        }
    }

    @Test func cachedSVGAttributesKeepOptionalLigaturesIndependentFromKerning() throws {
        let cache = RenderTextAttributes()
        var run = ResolvedTextRun(text: "office", fontFamily: "Alias", fontSize: 18,
            bold: false, italic: false, color: "#000000", tracking: 0)
        let defaultAttributes = cache.attributes(for: run, family: "Alias")
        run.usesStandardLigatures = false
        let nativeAttributes = cache.attributes(for: run, family: "Alias")
        #expect(nativeAttributes.contains("style=\"font-feature-settings: 'liga' 0\""))
        #expect(!defaultAttributes.contains("font-feature-settings"))
        #expect(cache.count == 2)
        run.explicitlyDisablesKerning = true
        let unkerned = cache.attributes(for: run, family: "Alias")
        #expect(unkerned.contains("kerning=\"0\""))
        #expect(unkerned.contains("font-feature-settings: 'liga' 0"))
        #expect(cache.count == 3)
        run.usesStandardLigatures = true
        #expect(!cache.attributes(for: run, family: "Alias").contains("font-feature-settings"))
        #expect(cache.count == 4)
    }

    @Test func aliasedRenderingReopensWithoutMutationAndRetainsViewerPolicy() throws {
        let deck = try Presentation()
        let bytes = try Data(contentsOf: root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf"))
        try deck.fonts.register(bytes, aliases: ["Native Alias"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .points(20), y: .points(20), width: .points(500), height: .points(180)))
        let frame = try #require(shape.textFrame)
        frame.text = "office"
        frame.paragraphs[0].runs[0].fontName = "Native Alias"
        frame.paragraphs[0].runs[0].fontSize = 144
        let before = try deck.serializedData()
        let first = try deck.renderSVG(slideAt: 0, strictRendering: true)
        #expect(first.contains("style=\"font-feature-settings: 'liga' 0\""))
        #expect(first == (try deck.renderSVG(slideAt: 0, strictRendering: true)))
        #expect(try deck.serializedData() == before)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pptx")
        defer { try? FileManager.default.removeItem(at: url) }
        try deck.save(to: url)
        let reopened = try Presentation(contentsOf: url)
        try reopened.fonts.register(bytes, aliases: ["Native Alias"])
        #expect(try reopened.renderSVG(slideAt: 0, strictRendering: true) == first)
        if let directory = ProcessInfo.processInfo.environment["ROSTRUM_LIGATURE_ARTIFACT_DIR"] {
            let output = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try first.write(to: output.appendingPathComponent("native-policy.svg"), atomically: true, encoding: .utf8)
            try deck.save(to: output.appendingPathComponent("rostrum-native-policy.pptx"))
        }
    }
}
