import Foundation
import Testing
@testable import Rostrum

/// Actual per-run native face evidence for the bounded exact-spacing extension.
@Suite struct NativeMixedFaceSpacingTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeMixedFaceSpacing")
    }
    private struct Input: Decodable {
        let name: String
        let page: Int
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let table: Bool?
    }
    private struct Capture: Decodable {
        struct Case: Decodable {
            struct Glyph: Decodable {
                let text: String
                let sourceFace: String
                let x: Double
                let baseline: Double
                let rawPDFPaintScale: [Double]
                let sourceGlyphBounds: [Double]
                let geometricInkBounds: [Double]
                let sourceGlyphMatches: Bool
            }
            struct Line: Decodable {
                let visibleText: String
                let baseline: Double
                let characters: [Glyph]
            }
            let name: String
            let selectedFace: String
            let expectedVisibleScalars: Int
            let consumedVisibleScalars: Int
            let lines: [Line]
        }
        let cases: [Case]
    }
    private func descendants(_ element: XML.Element) -> [XML.Element] {
        [element] + element.childElements.flatMap(descendants)
    }
    private func translation(_ element: XML.Element) -> (x: Double, y: Double)? {
        guard let value = element[attribute: "transform"], value.hasPrefix("translate("),
              let end = value.firstIndex(of: ")"), value.contains("scale(12700)") else { return nil }
        let parts = value[value.index(value.startIndex, offsetBy: 10)..<end]
            .split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0] / 12700, parts[1] / 12700)
    }
    private func embeddedFonts(_ svg: XML.Element) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for style in descendants(svg).filter({ $0.name == "style" }) {
            for rule in style.textContent.components(separatedBy: "@font-face{").dropFirst() {
                let familyStart = try #require(rule.range(of: "font-family:'")?.upperBound)
                let familyEnd = try #require(rule[familyStart...].firstIndex(of: "'"))
                let dataStart = try #require(rule.range(of: "base64,")?.upperBound)
                let dataEnd = try #require(rule[dataStart...].firstIndex(of: ")"))
                let decoded: Data? = Data(base64Encoded: String(rule[dataStart..<dataEnd]))
                let font = try #require(decoded)
                result[String(rule[familyStart..<familyEnd])] = font
            }
        }
        return result
    }
    private struct Manifest: Decodable { let source: String }
    @Test(arguments: ["base", "anchors"])
    func nativeMixedFacesKeepExactSpacing(folder: String) throws {
        let directory = root.appendingPathComponent(folder)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: directory.appendingPathComponent("cases.json")))
        let native = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: directory.appendingPathComponent("native-mixed-face-metrics.json")))
        let deck = try Presentation(contentsOf: directory.appendingPathComponent(manifest.source))
        #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
        let before = try deck.serializedData()
        let count = folder == "base" ? 4 : 8
        #expect(inputs.count == count && native.cases.count == count && deck.slides.count == 1)
        let names = Set(inputs.map(\.name))
        #expect(names.count == count && Set(native.cases.map(\.name)) == names)
        #expect(deck.slides.flatMap(\.shapes).filter { names.contains($0.name) }.count == count)
        let faces: [String: FontFaceKey] = ["regular": .init(family: "DejaVu Sans"),
            "bold": .init(family: "DejaVu Sans", bold: true), "serif": .init(family: "DejaVu Serif")]
        var pages: [XML.Element] = []
        var resources: [[String: Data]] = []
        for page in 0..<deck.slides.count {
            let svg = try deck.renderSVG(slideAt: page)
            #expect(try deck.renderSVG(slideAt: page) == svg)
            let parsed = try XML.parse(Data(svg.utf8))
            // These unrotated specimens render in slide coordinates. Refuse a
            // future transformed container instead of silently ignoring it.
            #expect(descendants(parsed).filter { $0.name == "g" && $0[attribute: "transform"] != nil }.isEmpty)
            pages.append(parsed)
            resources.append(try embeddedFonts(parsed))
        }
        var allConsumed = 0
        for (input, expected) in zip(inputs, native.cases) {
            #expect(input.name == expected.name)
            #expect(expected.expectedVisibleScalars == expected.consumedVisibleScalars)
            let shape = try #require(deck.slides[input.page].shapes.first { $0.name == input.name })
            let body: XML.Element
            if input.table == true {
                body = try #require(descendants(shape.element).first { $0.name == "a:txBody" })
            } else { body = try #require(shape.textFrame).txBody }
            let inherited = RichTextLayout.inheritedStyles(for: shape.element, owner: shape.part, package: deck.package)
            let layout = RichTextLayout(textBody: body, width: input.width, height: input.height,
                fonts: deck.fonts, theme: try deck.slides[input.page].resolvedTheme, inheritedStyles: inherited,
                insets: input.table == true ? (0, 0, 0, 0) : nil,
                verticalAnchor: input.table == true ? "t" : nil, context: input.table == true ? .tableCell : .shape)
            let expectedLines = expected.lines.map(\.visibleText)
            let actualLines = layout.lines.map { $0.spans.map(\.run.text).joined().filter { !$0.isWhitespace } }
            #expect(actualLines == expectedLines, "\(input.name): native wrapping")
            #expect(layout.diagnostics.isEmpty, "\(input.name): admitted actual faces")
            #expect(layout.fits)
            let lines = descendants(pages[input.page]).filter { element in
                guard element.name == "text", let t = translation(element) else { return false }
                return abs(t.x - input.x) < 0.001 && t.y >= input.y && t.y < input.y + input.height
            }
            #expect(lines.count == expected.lines.count)
            var consumed = 0
            for (line, reference) in zip(lines, expected.lines) {
                let origin = try #require(translation(line))
                #expect(abs(origin.y - input.y - reference.baseline) < 0.121, "\(input.name): baseline")
                let spans = line.children(named: "tspan")
                #expect(spans.map(\.textContent).joined().filter { !$0.isWhitespace } == reference.visibleText)
                var offset = 0
                for span in spans {
                    #expect(span[attribute: "textLength"] == nil && span[attribute: "lengthAdjust"] == nil)
                    let alias = try #require(span[attribute: "font-family"]?.components(separatedBy: ",").first)
                    let positions = (span[attribute: "x"] ?? "").split(separator: " ").compactMap { Double($0) }
                    let scalars = Array(span.textContent.unicodeScalars)
                    #expect(positions.count == scalars.count)
                    guard positions.count == scalars.count else { continue }
                    let paint = try #require(span[attribute: "font-size"].flatMap(Double.init))
                    for (scalar, x) in zip(scalars, positions) where scalar != " " {
                        guard offset < reference.characters.count else { Issue.record("Extra native alignment scalar"); continue }
                        let glyph = reference.characters[offset]; offset += 1; consumed += 1
                        #expect(String(scalar) == glyph.text && glyph.sourceGlyphMatches)
                        let expectedFace = try #require(faces[glyph.sourceFace])
                        let sourceBytes = try #require(deck.fonts.data(for: expectedFace))
                        #expect(resources[input.page][alias] == sourceBytes, "\(input.name): exact per-run embedded face")
                        // Existing finite captured-style bound; not a universal
                        // long-run guarantee against accumulating PDF TJ rounding.
                        #expect(abs(x - glyph.x) < 0.06, "\(input.name): scalar origin")
                        if offset == 1 {
                            // Preserve the earlier regular span-start bound.
                            #expect(abs(x - glyph.x) < 0.025, "\(input.name): line start")
                        }
                        #expect(glyph.rawPDFPaintScale.allSatisfy { abs($0 - paint) < 0.002 })
                        let bounds = glyph.sourceGlyphBounds, ink = glyph.geometricInkBounds
                        let width = (bounds[2] - bounds[0]) * paint / 2048
                        let height = (bounds[3] - bounds[1]) * paint / 2048
                        #expect(abs(width - (ink[2] - ink[0])) < 0.002)
                        #expect(abs(height - (ink[3] - ink[1])) < 0.002)
                    }
                }
                #expect(offset == reference.characters.count)
            }
            #expect(consumed == expected.consumedVisibleScalars)
            allConsumed += consumed
        }
        #expect(allConsumed == (folder == "base" ? 32 : 64))
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).serializedData() == before)
    }
    private let mixedWarning = ShapingDiagnostic.unsupportedLayoutFeature(
        "Native explicit line spacing with multiple font faces on one line is not verified")
    private func fontLibrary() throws -> FontLibrary {
        let fonts = FontLibrary()
        let directory = root.deletingLastPathComponent().appendingPathComponent("NativeListMarkers/fonts")
        for filename in ["DejaVuSans.ttf", "DejaVuSerif.ttf"] {
            try fonts.register(Data(contentsOf: directory.appendingPathComponent(filename)))
        }
        return fonts
    }
    private func body(first: String = "DejaVu Sans", second: String = "DejaVu Serif",
                      bodyAttributes: String = "", autofit: String = "", spacing: String = "<a:spcPts val=\"1800\"/>",
                      secondStyle: String = "", text: String = "jp") throws -> XML.Element {
        let runs = """
        <a:r><a:rPr sz="1200" kern="0"><a:latin typeface="\(first)"/></a:rPr><a:t>Ag</a:t></a:r>
        <a:r><a:rPr sz="2400" kern="0" \(secondStyle)><a:latin typeface="\(second)"/></a:rPr><a:t>\(text)</a:t></a:r>
        """
        return try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0" \(bodyAttributes)>\(autofit)</a:bodyPr>
        <a:p><a:pPr><a:lnSpc>\(spacing)</a:lnSpc><a:defRPr sz="2400" kern="0"><a:latin typeface="\(first)"/></a:defRPr></a:pPr>
        \(runs)<a:br><a:rPr sz="2400" kern="0"><a:latin typeface="\(first)"/></a:rPr></a:br>\(runs)</a:p></p:txBody>
        """.utf8))
    }
    @Test func uncapturedCombinationsAndRejectedPaintKeepTheirDiagnostics() throws {
        let fonts = try fontLibrary()
        let refused: [XML.Element] = [
            try body(spacing: "<a:spcPct val=\"150000\"/>"),
            try body(bodyAttributes: "compatLnSpc=\"0\""),
            try body(bodyAttributes: "compatLnSpc=\"false\""),
            try body(autofit: "<a:normAutofit fontScale=\"100000\" lnSpcReduction=\"10000\"/>"),
            try body(autofit: "<a:normAutofit fontScale=\"NaN\"/>"),
            try body(autofit: "<a:normAutofit fontScale=\"200000\"/>"),
            try body(autofit: "<a:normAutofit fontScale=\"100\"/>"),
            try body(secondStyle: "i=\"1\""),
            try body(secondStyle: "baseline=\"1000\""),
            try body(text: "j&#127;")
        ]
        for xml in refused {
            let layout = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: fonts)
            #expect(!layout.diagnostics.isEmpty)
            #expect(layout.contentHeight.isFinite)
            #expect(layout.lines.allSatisfy { $0.baseline.isFinite && $0.height.isFinite })
        }
        let cell = RichTextLayout(textBody: try body(), width: 290, height: 160, fonts: fonts, context: .tableCell)
        #expect(cell.diagnostics.contains(mixedWarning))
        let fallback = try #require(fonts.metrics(for: "DejaVu Sans"))
        let missing = try body(second: "Unregistered Face")
        let mixedFallback = RichTextLayout(textBody: missing, width: 290, height: 160,
            fonts: fonts, fallbackMetrics: fallback)
        #expect(mixedFallback.diagnostics.contains(mixedWarning))
        #expect(!RichTextLayout(textBody: missing, width: 290, height: 160, fonts: fonts).diagnostics.isEmpty)
        for invalidScale in [Double.nan, Double.infinity, 200] {
            let layout = RichTextLayout(textBody: try body(), width: 290, height: 160, fonts: fonts, fontScale: invalidScale)
            #expect(!layout.diagnostics.isEmpty && layout.contentHeight.isFinite)
        }
    }
    @Test func aliasesUseActualMetricsAndLiveReplacementRejectsUnequalSignatures() throws {
        let fonts = try fontLibrary()
        let data = try #require(fonts.data(for: .init(family: "DejaVu Serif")))
        try fonts.register(data, aliases: ["Spacing Alias"])
        let xml = try body(second: "Spacing Alias")
        let accepted = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: fonts)
        #expect(accepted.diagnostics.isEmpty && accepted.lines.map(\.baseline) == [14, 32])
        // Change only real OS/2 Windows fields: glyph mapping/outlines and
        // family metadata remain identical, so these isolate both signature axes.
        let bytes = [UInt8](data)
        func u16(_ offset: Int) -> Int { Int(bytes[offset]) * 256 + Int(bytes[offset + 1]) }
        func u32(_ offset: Int) -> Int { u16(offset) * 65536 + u16(offset + 2) }
        let record = try #require((0..<u16(4)).map { 12 + $0 * 16 }.first {
            Array(bytes[$0..<($0 + 4)]) == Array("OS/2".utf8)
        })
        let os2Offset = u32(record + 8)
        for (ascent, descent) in [(3802, 966), (1801, 583)] {
            var replacement = data
            replacement.replaceSubrange((os2Offset + 74)..<(os2Offset + 76), with: TestFont.be16(ascent))
            replacement.replaceSubrange((os2Offset + 76)..<(os2Offset + 78), with: TestFont.be16(descent))
            try fonts.register(replacement, face: .init(family: "Spacing Alias"))
            let rejected = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: fonts)
            #expect(rejected.diagnostics.contains(mixedWarning))
        }
        var missingWindows = data
        missingWindows.replaceSubrange((record + 12)..<(record + 16), with: TestFont.be32(74))
        try fonts.register(missingWindows, face: .init(family: "Spacing Alias"))
        let missingMetrics = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: fonts)
        #expect(missingMetrics.contentHeight.isFinite)
        #expect(missingMetrics.lines.first?.baseline != 14)
        try fonts.register(data, aliases: ["Spacing Alias"])
        #expect(RichTextLayout(textBody: xml, width: 290, height: 160, fonts: fonts).lines == accepted.lines)
    }
    @Test func computedPublicFitsUseTheNativeConstrainedExtent() throws {
        let source = root.appendingPathComponent("base/native-mixed-face-spacing-v1.pptx")
        for useShape in [false, true] {
            let deck = try Presentation(contentsOf: source)
            deck.registerEmbeddedFonts()
            let shape = try #require(deck.slides[0].shapes.first { $0.name == "exact18-sans12-serif24" })
            let frame = shape.frame
            shape.frame = Rect(x: frame.x, y: frame.y, width: frame.width, height: .points(40))
            let text = try #require(shape.textFrame)
            let paragraphs = text.txBody.children(named: "a:p").map { $0.serialized() }
            let fit = useShape ? try #require(shape.fitText(fonts: deck.fonts))
                : text.fitText(in: shape.frame, fonts: deck.fonts)
            // Computed first search step; no native-chosen autofit claim.
            #expect(fit.fits && fit.fontScale == 100 && fit.lineSpacingReduction == 0)
            let layout = RichTextLayout(textBody: text.txBody, width: 290, height: 40, fonts: deck.fonts)
            #expect(layout.fits && layout.diagnostics.isEmpty)
            #expect(layout.lines.map(\.baseline) == [14, 32])
            #expect(abs(layout.contentHeight - 37.33489932885906) < 1e-9)
            #expect(text.txBody.children(named: "a:p").map { $0.serialized() } == paragraphs)
            let saved = try deck.serializedData()
            #expect(try Presentation(data: saved).serializedData() == saved)
        }
    }
}
