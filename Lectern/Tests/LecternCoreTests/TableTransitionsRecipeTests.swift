import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TableTransitionsRecipeTests {
    @Test(arguments: [false, true])
    func nativeTransitionsAndExcludedFallbackSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.tableTransitions, options: .init(alternative: alternative))
        let reference = try PlatformLabRecipes.tableTransitionsReferences()
        try #require(draft.deck.slides.count == 5)
        #expect(reference.cases.count == 14 && reference.cases.reduce(0) { $0 + $1.glyphs.count } == 240)
        let pages = try (0..<4).map { try TableTransitionsSVGPage(svg: draft.deck.renderSVG(slideAt: $0), fonts: draft.deck.fonts) }
        for sample in reference.cases {
            #expect(pages[sample.slide].vectorsMatch(sample), "Paint \(sample.id)")
            #expect(pages[sample.slide].glyphsMatch(sample), "Glyphs \(sample.id)")
            let original = try Presentation(data: PlatformLabRecipes.resource(String(sample.source.dropLast(5)), "pptx"))
            original.registerEmbeddedFonts()
            #expect(try PlatformLabRecipes.tableDefaultsSpecimen(draft.deck, sample: sample).serialized()
                == PlatformLabRecipes.tableDefaultsSpecimen(original, sample: sample, slideIndex: sample.slide % 2).serialized())
            #expect(draft.deck.fonts.data(for: .init(family: "DejaVu Sans")) == original.fonts.data(for: .init(family: "DejaVu Sans")))
        }
        let bytes = try draft.deck.serializedData(), reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-table-transitions-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_TABLE_TRANSITIONS_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("tableTransitions.pptx"))
            for page in 0..<5 { try Data(draft.deck.renderSVG(slideAt: page).utf8).write(to: directory.appendingPathComponent("slide-\(page + 1).svg")) }
        }
    }
    @Test(arguments: [false, true])
    func actualInspectorPreviewsMatchSavedFiles(alternative: Bool) throws {
        let retained = ProcessInfo.processInfo.environment["LECTERN_TABLE_TRANSITIONS_PIPELINE_ARTIFACTS"]
        let parent = retained.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("TableTransitions-" + UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: parent) } }
        let result = try LibraryLab.run(.tableTransitions, options: .init(alternative: alternative), in: parent)
        #expect(result.passed && result.findings.isEmpty && result.slideCount == 5)
        let inspection = try DeckInspector.inspect(deckAt: result.afterURL)
        let deck = try Presentation(contentsOf: result.afterURL)
        deck.registerEmbeddedFonts()
        for page in 0..<5 {
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page + 1)), encoding: .utf8)
            #expect(inspection.previews[page] == saved)
            #expect(try deck.renderSVG(slideAt: page, pixelWidth: 640) == saved)
        }
    }
    @Test func publicNoFillChangesOnlyAuthoredPage() throws {
        let a = try PlatformLabRecipes.make(.tableTransitions, options: .init())
        let b = try PlatformLabRecipes.make(.tableTransitions, options: .init(alternative: true))
        for page in 0..<4 { #expect(try a.deck.renderSVG(slideAt: page) == b.deck.renderSVG(slideAt: page)) }
        #expect(try a.deck.renderSVG(slideAt: 4) != b.deck.renderSVG(slideAt: 4))
        #expect(try PlatformLabRecipes.tableTransitionsControlMatches(a.deck, alternative: false))
        #expect(try PlatformLabRecipes.tableTransitionsControlMatches(b.deck, alternative: true))
    }
    @Test func auditRejectsPaintAndGlyphChanges() throws {
        let draft = try PlatformLabRecipes.make(.tableTransitions, options: .init())
        let reference = try PlatformLabRecipes.tableTransitionsReferences()
        let sample = try #require(reference.cases.first { $0.id == "constant-grid-line-control" })
        #expect(TableTransitionsSVGPage.orderedPaintMatches(actual: sample.lines, expected: sample.lines))
        #expect(!TableTransitionsSVGPage.orderedPaintMatches(actual: sample.lines.reversed(), expected: sample.lines))
        let parsed = try XML.parse(Data(draft.deck.renderSVG(slideAt: 0).utf8))
        let line = try #require(DrawingLabFixtures.nodes(parsed, "line").first {
            let x = ($0[attribute: "x1"].flatMap(Double.init) ?? .infinity) / Double(EMU.perPoint)
            let y = ($0[attribute: "y1"].flatMap(Double.init) ?? .infinity) / Double(EMU.perPoint)
            return x < 275 && y < 280
        })
        for (key, value) in [("x2", "1"), ("stroke-width", "1"), ("stroke", "#FF00FF"), ("transform", "translate(12700,0)"), ("stroke-dasharray", "1 2"), ("stroke-linecap", "round"), ("stroke-opacity", "0.5")] {
            let old = line[attribute: key]; line[attribute: key] = value
            #expect(try !TableTransitionsSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).vectorsMatch(sample), "Reject \(key)")
            line[attribute: key] = old
        }
        let body = try #require(DrawingLabFixtures.nodes(parsed, "text").first {
            guard $0.textContent == "Agjp", let t = $0[attribute: "transform"] else { return false }
            let v = t.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            return v.count == 3 && v[0] < 275 * Double(EMU.perPoint) && v[1] < 280 * Double(EMU.perPoint)
        })
        let span = try #require(body.firstChild(named: "tspan"))
        for node in [body, span] { for (key, value) in [("dy", "1"), ("y", "1"), ("dx", "1"), ("rotate", "5"), ("baseline-shift", "1"), ("text-anchor", "middle")] {
            node[attribute: key] = value
            #expect(try !TableTransitionsSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).glyphsMatch(sample), "Reject \(key)")
            node[attribute: key] = nil
        } }
        for (key, value) in [("textLength", "1"), ("font-family", "sans-serif"), ("font-size", "15"), ("font-weight", "700"), ("font-style", "italic")] {
            let old = span[attribute: key]; span[attribute: key] = value
            #expect(try !TableTransitionsSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).glyphsMatch(sample), "Reject \(key)")
            span[attribute: key] = old
        }
    }
}
