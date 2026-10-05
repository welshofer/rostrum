import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PartialTableStylesRecipeTests {
    @Test(arguments: [false, true])
    func nativeProfilesAndPublicControlsSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.partialTableStyles, options: .init(alternative: alternative))
        let reference = try PlatformLabRecipes.partialTableStylesReferences()
        #expect(draft.deck.slides.count == 3 && reference.cases.count == 12)
        #expect(reference.cases.reduce(0) { $0 + $1.glyphs.count } == 72)
        #expect(Set(reference.cases.map(\.id)).count == 12)
        let pages = try (0..<2).map { try PartialTableStylesSVGPage(svg: draft.deck.renderSVG(slideAt: $0), fonts: draft.deck.fonts) }
        for sample in reference.cases {
            #expect(pages[sample.slide].vectorsMatch(sample), "Native vectors \(sample.id)")
            #expect(pages[sample.slide].glyphsMatch(sample), "Native glyph trace \(sample.id)")
        }
        for source in reference.sources {
            let original = try Presentation(data: PlatformLabRecipes.resource(String(source.source.dropLast(5)), "pptx"))
            original.registerEmbeddedFonts()
            #expect(try PlatformLabRecipes.partialTableStyleDefinitions(original).count == 12)
            #expect(try PlatformLabRecipes.partialTableStyleDefinitions(draft.deck).count == 16)
            #expect(draft.deck.fonts.data(for: .init(family: "DejaVu Sans")) == original.fonts.data(for: .init(family: "DejaVu Sans")))
            for sample in reference.cases where sample.sourceGroup == source.group {
                #expect(try PlatformLabRecipes.tableDefaultsSpecimen(draft.deck, sample: sample).serialized()
                    == PlatformLabRecipes.tableDefaultsSpecimen(original, sample: sample, slideIndex: sample.slide).serialized())
            }
        }
        #expect(try PlatformLabRecipes.partialTableStyleControlsMatch(draft.deck, alternative: alternative))
        let bytes = try draft.deck.serializedData(), reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-partial-table-styles-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_PARTIAL_TABLE_STYLES_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("partialTableStyles.pptx"))
            for page in 0..<3 { try Data(draft.deck.renderSVG(slideAt: page).utf8).write(to: directory.appendingPathComponent("slide-\(page + 1).svg")) }
        }
    }

    @Test(arguments: [false, true])
    func actualInspectorPreviewsMatchSavedFiles(alternative: Bool) throws {
        let retained = ProcessInfo.processInfo.environment["LECTERN_PARTIAL_TABLE_STYLES_PIPELINE_ARTIFACTS"]
        let parent = retained.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("PartialTableStyles-" + UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: parent) } }
        let result = try LibraryLab.run(.partialTableStyles, options: .init(alternative: alternative), in: parent)
        #expect(result.passed && result.findings.isEmpty && result.slideCount == 3)
        let inspection = try DeckInspector.inspect(deckAt: result.afterURL)
        let deck = try Presentation(contentsOf: result.afterURL)
        deck.registerEmbeddedFonts()
        for page in 0..<3 {
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page + 1)), encoding: .utf8)
            #expect(inspection.previews[page] == saved)
            #expect(try deck.renderSVG(slideAt: page, pixelWidth: 640) == saved)
        }
    }

    @Test func publicOverrideRestorationChangesOnlyAuthoredPage() throws {
        let explicit = try PlatformLabRecipes.make(.partialTableStyles, options: .init(alternative: false))
        let restored = try PlatformLabRecipes.make(.partialTableStyles, options: .init(alternative: true))
        for page in 0..<2 { #expect(try explicit.deck.renderSVG(slideAt: page) == restored.deck.renderSVG(slideAt: page)) }
        #expect(try explicit.deck.renderSVG(slideAt: 2) != restored.deck.renderSVG(slideAt: 2))
        for (deck, cleared) in [(explicit.deck, false), (restored.deck, true)] {
            let table = try #require((deck.slides[2].shapes.first { $0.name == "Public partial-style control 3" } as? TableFrame)?.table)
            let cell = try table.cell(0, 0), resolver = TableStyleResolver(table: table, theme: deck.theme)
            #expect((cell.border(.left) == nil) == cleared)
            #expect(try resolver.border(.left, row: 0, column: 0)?.width == .points(cleared ? 1 : 4))
            #expect(cell.border(.right)?.isNone == true)
        }
    }

    @Test func auditRejectsPaintOrderAndUnmodeledPositions() throws {
        let draft = try PlatformLabRecipes.make(.partialTableStyles, options: .init())
        let reference = try PlatformLabRecipes.partialTableStylesReferences()
        let sample = try #require(reference.cases.first { $0.id == "partial-grid-whole" })
        let svg = try draft.deck.renderSVG(slideAt: 1)
        #expect(PartialTableStylesSVGPage.orderedCrossingsMatch(actual: sample.lines, native: sample.lines))
        #expect(!PartialTableStylesSVGPage.orderedCrossingsMatch(actual: sample.lines.reversed(), native: sample.lines))
        let parsed = try XML.parse(Data(svg.utf8))
        let line = try #require(DrawingLabFixtures.nodes(parsed, "line").first {
            $0[attribute: "x1"] == String(30 * EMU.perPoint) && $0[attribute: "y1"].flatMap(Double.init).map { $0 > 480 * Double(EMU.perPoint) } == true
        })
        for (key, value) in [("stroke-width", "1"), ("stroke", "#FF00FF"), ("transform", "translate(12700,0)"), ("stroke-dasharray", "1 2"), ("stroke-linecap", "round")] {
            let old = line[attribute: key]
            line[attribute: key] = value
            #expect(try !PartialTableStylesSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).vectorsMatch(sample), "Reject \(key)")
            line[attribute: key] = old
        }
        let body = try #require(DrawingLabFixtures.nodes(parsed, "text").first {
            guard $0.textContent == "Agjp", let transform = $0[attribute: "transform"] else { return false }
            let numbers = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            return numbers.count == 3 && numbers[0] < 270 * Double(EMU.perPoint) && numbers[1] > 495 * Double(EMU.perPoint)
        })
        let span = try #require(body.firstChild(named: "tspan"))
        for node in [body, span] {
            for (key, value) in [("dy", "1"), ("y", "1"), ("dx", "1"), ("rotate", "5"), ("baseline-shift", "1"), ("text-anchor", "middle")] {
                node[attribute: key] = value
                #expect(try !PartialTableStylesSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).glyphsMatch(sample), "Reject \(key)")
                node[attribute: key] = nil
            }
        }
        span[attribute: "textLength"] = "1"
        #expect(try !PartialTableStylesSVGPage(svg: parsed.serialized(), fonts: draft.deck.fonts).glyphsMatch(sample))
    }
}
