import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TableDefaultsRecipeTests {
    @Test(arguments: [false, true])
    func nativePaintAndPublicStyleImportSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.tableDefaults, options: .init(alternative: alternative))
        let reference = try PlatformLabRecipes.tableDefaultsReferences()
        #expect(draft.deck.slides.count == 4 && reference.cases.count == 12)
        #expect(reference.cases.reduce(0) { $0 + $1.glyphs.count } == 72)
        #expect(Set(reference.cases.map(\.id)).count == 12)
        let pages = try (0..<3).map { try TableDefaultsSVGPage(svg: draft.deck.renderSVG(slideAt: $0), fonts: draft.deck.fonts) }
        for sample in reference.cases {
            #expect(pages[sample.slide].vectorsMatch(sample), "Native vectors \(sample.id)")
            #expect(pages[sample.slide].glyphsMatch(sample), "Native glyph trace \(sample.id)")
        }
        for source in reference.sources {
            let original = try Presentation(data: PlatformLabRecipes.resource(String(source.source.dropLast(5)), "pptx"))
            original.registerEmbeddedFonts()
            #expect(draft.deck.fonts.data(for: .init(family: "DejaVu Sans")) == original.fonts.data(for: .init(family: "DejaVu Sans")))
            for sample in reference.cases where sample.sourceGroup == source.group {
                #expect(try PlatformLabRecipes.tableDefaultsSpecimen(draft.deck, sample: sample).serialized()
                    == PlatformLabRecipes.tableDefaultsSpecimen(original, sample: sample, slideIndex: 0).serialized())
            }
        }
        let custom = try #require((draft.deck.slides[1].shapes.first { $0.name == "custom-absent" } as? TableFrame)?.table)
        #expect(custom.styleID == nil)
        let control = try #require((draft.deck.slides[3].shapes.first { $0.name == "Public style control" } as? TableFrame)?.table)
        #expect((control.styleID == nil) == alternative)
        #expect(try PlatformLabRecipes.tableDefaultsControlMatches(draft.deck, alternative: alternative))
        let bytes = try draft.deck.serializedData(), reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-table-defaults-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_TABLE_DEFAULTS_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("tableDefaults.pptx"))
            for page in 0..<4 { try Data(draft.deck.renderSVG(slideAt: page).utf8).write(to: directory.appendingPathComponent("slide-\(page + 1).svg")) }
        }
    }

    @Test(arguments: [false, true])
    func actualInspectorPreviewsMatchSavedFiles(alternative: Bool) throws {
        let retained = ProcessInfo.processInfo.environment["LECTERN_TABLE_DEFAULTS_PIPELINE_ARTIFACTS"]
        let parent = retained.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("TableDefaults-" + UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: parent) } }
        let result = try LibraryLab.run(.tableDefaults, options: .init(alternative: alternative), in: parent)
        #expect(result.passed && result.findings.isEmpty && result.slideCount == 4)
        let inspection = try DeckInspector.inspect(deckAt: result.afterURL)
        let deck = try Presentation(contentsOf: result.afterURL)
        deck.registerEmbeddedFonts()
        for page in 0..<4 {
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page + 1)), encoding: .utf8)
            #expect(inspection.previews[page] == saved)
            #expect(try deck.renderSVG(slideAt: page, pixelWidth: 640) == saved)
        }
    }

    @Test func vectorAuditRejectsWrongPaintAndMissingGeometry() throws {
        let draft = try PlatformLabRecipes.make(.tableDefaults, options: .init())
        let reference = try PlatformLabRecipes.tableDefaultsReferences()
        let sample = try #require(reference.cases.first { $0.id == "unequal-four-edges" })
        let svg = try draft.deck.renderSVG(slideAt: 2)
        let parsed = try XML.parse(Data(svg.utf8))
        let line = try #require(DrawingLabFixtures.nodes(parsed, "line").first {
            $0[attribute: "x1"] == String(30 * EMU.perPoint)
        })
        let originalWidth = line[attribute: "stroke-width"]
        line[attribute: "stroke-width"] = String(9 * EMU.perPoint)
        #expect(try !TableDefaultsSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).vectorsMatch(sample))
        line[attribute: "stroke-width"] = originalWidth
        line[attribute: "stroke"] = "#FF0000"
        #expect(try !TableDefaultsSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).vectorsMatch(sample))
        line[attribute: "stroke"] = "#000000"
        line[attribute: "transform"] = "translate(12700,0)"
        #expect(try !TableDefaultsSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).vectorsMatch(sample))
        #expect(try !TableDefaultsSVGPage(svg: svg.replacingOccurrences(of: "<tspan ", with: "<tspan textLength=\"1\" "), fonts: draft.deck.fonts).glyphsMatch(sample))
        let positioned = try XML.parse(Data(svg.utf8))
        let body = try #require(DrawingLabFixtures.nodes(positioned, "text").first { $0.textContent == "Agjp" })
        let span = try #require(body.firstChild(named: "tspan"))
        span[attribute: "dy"] = "1"
        #expect(try !TableDefaultsSVGPage(svg: positioned.serialized(), fonts: draft.deck.fonts).glyphsMatch(sample))
        span[attribute: "dy"] = nil
        body[attribute: "dy"] = "1"
        #expect(try !TableDefaultsSVGPage(svg: positioned.serialized(), fonts: draft.deck.fonts).glyphsMatch(sample))
        typealias S = TableDefaultsReferences.Stroke
        let first = S(points: [0, 0, 10, 0], color: [0, 0, 0], opacity: 1, width: 1)
        let adjacent = S(points: [10, 0, 20, 0], color: [0, 0, 0], opacity: 1, width: 1)
        #expect(TableDefaultsSVGPage.canonical([first, adjacent])?.count == 1)
        for next in [S(points: [11, 0, 20, 0], color: [0, 0, 0], opacity: 1, width: 1),
                     S(points: [10, 0, 20, 0], color: [1, 0, 0], opacity: 1, width: 1),
                     S(points: [10, 0, 20, 0], color: [0, 0, 0], opacity: 1, width: 2),
                     S(points: [10, 0, 20, 0], color: [0, 0, 0], opacity: 0.5, width: 1)] {
            #expect(TableDefaultsSVGPage.canonical([first, next])?.count == 2)
        }
    }
}
