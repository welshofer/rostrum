import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ParagraphPaintRecipeTests {
    @Test(arguments: [false, true])
    func nativeGlyphPaintAndComputedFitsSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.paragraphLayout,
            options: .init(text: "Native glyph painting", sampleSize: 2, alternative: alternative))
        #expect(draft.deck.slides.count == 7)
        let samples = try PlatformLabRecipes.paragraphPaintReferences().cases.filter { $0.alternative == alternative }
        #expect(samples.count == 6)
        let svg = try draft.deck.renderSVG(slideAt: 6)
        for sample in samples {
            let original = try #require(draft.deck.slides[6].shapes.all.first { $0.name == sample.id + " paint original" })
            #expect(PlatformLabRecipes.paintGlyphsMatch(svg: svg, frame: original.frame, sample: sample), "\(sample.id)")
            #expect(try PlatformLabRecipes.paintPropertiesMatch(draft.deck, sample: sample, role: "original", fit: nil))
            let source = try XML.parse(Data(sample.textBodyXML.utf8))
            let rawSizes = source.children(named: "a:p").flatMap { $0.children(named: "a:r") }.compactMap {
                $0.firstChild(named: "a:rPr")?[attribute: "sz"].flatMap(Double.init).map { $0 / 100 }
            }
            #expect(original.textFrame?.paragraphs.flatMap(\.runs).compactMap(\.fontSize) == rawSizes)
            let shapeFit = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " paint shape fit", slideAt: 6)
            let frameFit = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " paint frame fit", slideAt: 6)
            #expect(shapeFit.lines == frameFit.lines && shapeFit.fits && frameFit.fits)
            #expect(shapeFit.contentHeight <= 20 && shapeFit.lines.allSatisfy { $0.visibleWidth <= 100 })
        }
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        // Retain even a failing baseline so the engine gap remains reviewable.
        if let parent = ProcessInfo.processInfo.environment["LECTERN_PAINT_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("paragraphLayout.pptx"))
            try Data(svg.utf8).write(to: directory.appendingPathComponent("slide-07.svg"))
        }
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-glyph-reference.json"] != nil)
    }

    @Test func glyphReferencesRetainMatricesOutlinesAndSourceBodies() throws {
        let reference = try PlatformLabRecipes.paragraphPaintReferences()
        #expect(reference.cases.count == 12)
        #expect(reference.cases.map(\.id) == ["wide-authored-13p49", "wide-authored-13p50", "wide-authored-14p50",
            "wrap-authored-13p51-w110.99", "wrap-authored-13p51-w111.01", "wide-integer-14",
            "wide-scaled-13p49", "wide-scaled-13p50", "wide-29-scale50-exact-tie",
            "wrap-scaled-13p50-w110.99", "wrap-scaled-13p50-w111.01", "wide-14p50-scale99p99"])
        let nativePaintSizes = [13.0, 14, 14, 14, 14, 14, 13, 14, 15, 14, 14, 14]
        for (sample, size) in zip(reference.cases, nativePaintSizes) {
            #expect(sample.heightPoints == 160 && sample.unitsPerEm == 2048)
            #expect(sample.source.hasPrefix("Tests/RostrumTests/Fixtures/NativeGlyphPlacement/"))
            #expect(sample.sourceSHA256.count == 64 && sample.nativePDFSHA256.count == 64)
            #expect(sample.fontSHA256 == "7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954")
            let glyphs = sample.nativeLines.flatMap(\.characters)
            #expect(glyphs.map(\.text).joined() == sample.nativeLines.map(\.visibleText).joined())
            #expect(glyphs.allSatisfy { $0.rawPDFPaintScale.count == 2 && $0.rawPDFPaintScale.allSatisfy { abs($0 - size) <= 0.002 }
                && $0.sourceGlyphBounds.count == 4 && $0.geometricInkBounds.count == 4 })
        }
        #expect(reference.cases[3].nativeLines.map(\.visibleText) == [String(repeating: "B", count: 11), "BZ"])
        #expect(reference.cases[4].nativeLines.map(\.visibleText) == [String(repeating: "B", count: 12), "Z"])
        #expect(reference.cases[9].nativeLines.map(\.visibleText) == reference.cases[10].nativeLines.map(\.visibleText))
    }

    @Test func paintComparisonRejectsGlyphStretchingAndMissingScalarOrigins() {
        let frame = Rect(x: .zero, y: .zero, width: .points(100), height: .points(20))
        let prefix = "<svg><text transform=\"translate(0,127000) scale(12700)\"><tspan font-size=\"14\" "
        #expect(PlatformLabRecipes.paintGlyphs(svg: prefix + "x=\"0 9\">AB</tspan></text></svg>", frame: frame)?.count == 2)
        #expect(PlatformLabRecipes.paintGlyphs(svg: prefix + "x=\"0\">AB</tspan></text></svg>", frame: frame) == nil)
        #expect(PlatformLabRecipes.paintGlyphs(svg: prefix + "x=\"0 9\" textLength=\"18\" lengthAdjust=\"spacingAndGlyphs\">AB</tspan></text></svg>", frame: frame) == nil)
    }
}
