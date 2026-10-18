import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite(.serialized) struct GeneratedLayoutTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func vocabularyValidationAndPromptContract() throws {
        let input = LibraryLab.generatedLayoutExample()
        #expect(try DeckValidator().validate(input).deck == input)
        let schema = DeckSchema.inputSchema()
        let props = try #require(schema["properties"] as? [String: Any])
        let slides = try #require(props["slides"] as? [String: Any])
        let item = try #require(slides["items"] as? [String: Any])
        let slide = try #require(item["properties"] as? [String: Any])
        let layout = try #require(slide["layout"] as? [String: Any])
        #expect(layout["enum"] as? [String] == SlideLayoutKind.knownCases.map(\.name))
        var invalid = input
        invalid.slides[2].body?.panels?.removeLast()
        #expect(throws: ValidationError.self) { try DeckValidator().validate(invalid) }
        let request = DeckRequest(prompt: "Offline", audience: "Team", goal: "inform", slideCount: 5)
        for name in ["cards", "threeColumn", "numberedSteps", "additionalHeaders", "textDirections"] {
            #expect(PromptTemplates.system(for: request).contains(name))
        }
    }

    @Test func refusesLossyAndHostileTableMetadata() throws {
        let base = try #require(LibraryLab.generatedLayoutExample().slides.last?.body?.table)
        var variants: [IRTable] = []
        var table = base; table.merges?.append(.init(row: Int.max, column: 0, rowSpan: Int.max, columnSpan: 2)); variants.append(table)
        table = base; table.merges?.append(.init(row: 0, column: 0, rowSpan: 2, columnSpan: 1)); variants.append(table)
        table = base; table.additionalHeaders?[0][0] = "Never discard"; variants.append(table)
        table = base; table.merges = [.init(row: 1, column: 1, rowSpan: 2, columnSpan: 1)]; variants.append(table)
        table = base; table.textDirections?.append(.init(row: 1, column: 0, direction: .vertical)); variants.append(table)
        table = base; table.textDirections?.append(.init(row: 0, column: 0, direction: .horizontal)); variants.append(table)
        table = base; table.textDirections = [.init(row: -1, column: 0, direction: .horizontal)]; variants.append(table)
        table = base; table.additionalHeaders = [[]]; variants.append(table)
        for value in variants {
            #expect(value.structureProblem != nil)
            #expect(throws: LayoutError.self) { try value.layoutContent() }
            var deck = LibraryLab.generatedLayoutExample(); deck.slides[4].body?.table = value
            #expect(throws: ValidationError.self) { try DeckValidator().validate(deck) }
        }
        // A plain-table repair must not silently erase advanced table metadata.
        var empty = LibraryLab.generatedLayoutExample()
        empty.slides[4].body?.table?.rows = []
        empty.slides[4].body?.bullets = [.init(text: "Fallback words")]
        #expect(throws: ValidationError.self) { try DeckValidator().validate(empty) }
    }

    @Test(arguments: [false, true]) func sourceCoordinatesFollowEveryPage(templateBacked: Bool) async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var input = LibraryLab.generatedLayoutExample()
        for index in 1...3 {
            input.slides[index].body?.source = "Synthetic source."
            input.slides[index].notes = "Panel speaker notes."
        }
        let templateDeck = try Presentation()
        templateDeck.documentKind = .template
        let template = templateBacked ? try PowerPointTemplate(data: templateDeck.serializedData(), name: "Native slots") : nil
        let renderer = DeckRenderer()
        let output = try await renderer.render(input, designURL: nil, notesEnabled: true, into: root, template: template)
        #expect(output.schemaIssues.isEmpty && output.droppedContent.isEmpty)
        #expect(try RenderContentCheck.inspect(output.url, expected: input).issues.isEmpty)
        let saved = try Presentation(contentsOf: output.url)
        #expect(saved.slides.count > input.slides.count)
        let tables = saved.slides.flatMap { $0.shapes.all.compactMap { ($0 as? TableFrame)?.table } }
        #expect(tables.count >= 2)
        for table in tables {
            #expect(table.rowCount >= 4 && (table.rowCount - 2) % 2 == 0)
            #expect(try table.cell(0, 0).textDirection == .vertical)
            #expect(try table.cell(0, 3).textDirection == .vertical270)
            #expect(try table.mergedRegions.filter { $0.row < 2 }.count == 3)
        }
        for slide in saved.slides {
            for shape in slide.shapes.all {
                if let frame = slide.effectiveFrame(of: shape) {
                    #expect(frame.x >= .zero && frame.y >= .zero && frame.maxX <= saved.bounds.maxX && frame.maxY <= saved.bounds.maxY)
                }
            }
        }
        let inspection = try DeckInspector.inspect(deckAt: output.url)
        #expect(inspection.previews == output.previews && inspection.previewDiagnostics == output.previewDiagnostics)
        let export = try DeckExporter.export(deckAt: output.url, into: root.appendingPathComponent("export"))
        #expect(try String(contentsOf: export.markdownFile, encoding: .utf8).contains("R16"))
        let second = try await renderer.render(input, designURL: nil, notesEnabled: true, into: root, template: template)
        #expect(try Data(contentsOf: output.url) == Data(contentsOf: second.url))
        #expect(output.previews == second.previews)
        let snapshot = try RenderSnapshot(deck: input, images: [:], template: template).save(in: root)
        let snapshotDeck = try RenderSnapshot.load(snapshot).deck
        #expect(snapshotDeck == input)
        let revised = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: output.url,
            slideID: "table", variant: 0, into: root.appendingPathComponent("revised"))
        #expect(try RenderContentCheck.inspect(revised.url, expected: input).issues.isEmpty)
        let reopened = try Presentation(contentsOf: revised.url)
        for index in 0..<4 { #expect(try saved.slides[index].part.blob == reopened.slides[index].part.blob) }
        for id in ["cards", "columns", "steps"] {
            let recovered = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: output.url,
                slideID: id, variant: 0, into: root.appendingPathComponent("recover-" + id))
            #expect(try RenderContentCheck.inspect(recovered.url, expected: input).issues.isEmpty)
        }
        // Detection must fail even when all source words remain visible.
        try tables[0].cell(0, 0).textDirection = .horizontal
        let broken = root.appendingPathComponent("broken.pptx"); try saved.save(to: broken)
        #expect(try RenderContentCheck.inspect(broken, expected: input).issues.contains { $0.contains("directions changed") })
    }

    @Test func pageValuesRetainHeaderAndBodyAnchors() throws {
        let input = try #require(LibraryLab.generatedLayoutExample().slides.last?.body?.table)
        let deck = try Presentation()
        let original = DeckIR(meta: Meta(title: "Pages"), slides: [IRSlide(id: "t", layout: "table", title: "Keep groups", body: Body(table: input))])
        let prepared = try TableRendering.prepare(original, engine: TemplateLayoutEngine(presentation: deck))
        #expect(prepared.deck.slides.count > 1)
        var body: [[String]] = []
        for slide in prepared.deck.slides {
            let table = try #require(slide.body?.table)
            #expect(table.additionalHeaders == input.additionalHeaders)
            #expect(table.structureProblem == nil)
            body += table.rows
            #expect(table.merges?.contains { $0.row == 2 && $0.rowSpan == 2 } == true)
        }
        #expect(body == input.rows)
    }

    @Test(arguments: [false, true]) func offlineLabInBothRatios(narrow: Bool) throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let result = try LibraryLab.run(.generatedLayouts, options: .init(alternative: narrow), in: root)
        #expect(result.passed, "\(result.checks.filter { !$0.passed })")
        let fixtureURL = result.directory.appendingPathComponent("generated-layouts.json")
        let input = try JSONDecoder().decode(DeckIR.self, from: Data(contentsOf: fixtureURL))
        #expect(try RenderContentCheck.inspect(result.afterURL, expected: input).issues.isEmpty)
    }
}
