import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite struct TableRenderingTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func fixture(source: String = "Exact source retained.") -> DeckIR {
        let rows = (1...28).map { ["R\($0)", "Observation \($0) preserves every original word and needs room to wrap naturally.", "1,234"] }
        return DeckIR(meta: Meta(title: "Measured production tables"),
            sections: [.init(id: "evidence", title: "Evidence", slideIds: ["table", "neighbor"])], slides: [
                IRSlide(id: "table", sectionId: "evidence", layout: "table", title: "Evidence with room to read",
                    body: Body(kicker: "Supporting detail", table: IRTable(headers: ["ID", "Observation", "Value"], rows: rows),
                        lead: "Every record matters.", source: source), notes: "Original speaker notes."),
                IRSlide(id: "neighbor", sectionId: "evidence", layout: "bullets", title: "Untouched neighbor",
                    body: Body(bullets: [Bullet(text: "Keep this slide in its original section.")]))])
    }
    private func template(wide: Bool) throws -> PowerPointTemplate {
        let deck = try Presentation()
        if wide { deck.slideSize = (width: .points(960), height: .points(540)) }
        deck.theme.majorFont = "Calibri"
        deck.theme.minorFont = "Calibri"
        deck.documentKind = .template
        return try PowerPointTemplate(data: deck.serializedData(), name: "Caller typography")
    }

    @Test(arguments: ["authored", "serif", "4x3", "16x9"])
    func productionTablesKeepRowsGeometryAndInspectorOutput(mode: String) async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let input = fixture()
        let supplied = try ["authored", "serif"].contains(mode) ? nil : template(wide: mode == "16x9")
        let design = mode == "serif" ? URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("App/Resources/Styles/serif.md") : nil
        let renderer = DeckRenderer()
        let output = try await renderer.render(input, designURL: design, notesEnabled: true, into: root, template: supplied)
        #expect(output.slideCount > input.slides.count)
        #expect(output.schemaIssues.isEmpty && output.droppedContent.isEmpty)
        #expect(try RenderContentCheck.inspect(output.url, expected: input).issues.isEmpty)
        let deck = try Presentation(contentsOf: output.url)
        let inspection = try DeckInspector.inspect(deckAt: output.url)
        #expect(inspection.previewSlideNumbers == Array(1...output.slideCount))
        #expect(inspection.previews.count == output.slideCount)
        #expect(inspection.previewDiagnostics.allSatisfy { $0.failure == nil })
        #expect(inspection.sections.first?.slideIndices == Array(0..<output.slideCount))
        let grids = inspection.slides.flatMap(\.tables).map(\.rows)
        #expect(grids.allSatisfy { $0.first == input.slides[0].body?.table?.headers })
        #expect(grids.flatMap { $0.dropFirst() } == input.slides[0].body?.table?.rows)
        var widths: [EMU]?
        for slide in deck.slides {
            for frame in slide.shapes.all.compactMap({ $0 as? TableFrame }) {
                let table = try #require(frame.table)
                let font = try #require(table.cell(0, 0).textFrame.paragraphs.first?.runs.first?.fontName)
                _ = InstalledFonts.registerForGeneration(in: deck, families: [font])
                if supplied != nil { #expect(font == "Calibri") }
                let measured = try TableLayoutEngine(presentation: deck).plan(table)
                #expect(measured.fits && measured.totalHeight <= frame.frame.height)
                if let widths { #expect(widths == measured.columnWidths) }
                else { widths = measured.columnWidths }
                #expect(frame.frame.maxX <= deck.bounds.maxX && frame.frame.maxY <= deck.bounds.maxY)
                let caption = try #require(slide.shapes.all.first { $0.textFrame?.text.contains("Exact source retained.") == true })
                #expect(slide.effectiveFrame(of: caption)!.y >= frame.frame.maxY + .points(8))
                #expect(slide.notesText == "Original speaker notes.")
            }
        }
        #expect(try #require(widths)[1] > widths![0])
        let exported = try DeckExporter.export(deckAt: output.url, into: root)
        #expect(exported.slideCount == output.slideCount)
        let markdown = try String(contentsOf: exported.markdownFile, encoding: .utf8)
        #expect(markdown.contains("R28") && markdown.contains("Exact source retained."))
        if let supplied {
            let source = try Presentation(data: supplied.data)
            for (uri, part) in source.package.parts where uri.value.contains("slideLayout") || uri.value.contains("slideMaster") || uri.value.contains("theme") {
                #expect(try deck.package.part(at: uri).blob == part.blob)
            }
        }
        let second = try await renderer.render(input, designURL: design, notesEnabled: true, into: root, template: supplied)
        #expect(try Data(contentsOf: output.url) == Data(contentsOf: second.url))
        #expect(output.previews == second.previews && output.warnings == second.warnings)
    }

    @Test(arguments: [false, true])
    func tableRecoveryPreservesGroupIdentityAndReview(templateBacked: Bool) async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let input = fixture()
        let supplied = try templateBacked ? template(wide: false) : nil
        let renderer = DeckRenderer()
        let initial = try await renderer.render(input, designURL: nil, notesEnabled: true, into: root, template: supplied)
        let before = try Presentation(contentsOf: initial.url)
        #expect(before.slides.count > 2)
        try before.slides[1].addComment("Keep this review", author: "Reviewer")
        try before.save(to: initial.url)
        let bytes = try Data(contentsOf: initial.url)
        let snapshot = try RenderSnapshot(deck: input, template: supplied).save(in: root)
        let revised = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: initial.url, slideID: "table", variant: 0, into: root)
        let after = try Presentation(contentsOf: revised.url)
        #expect(after.slides.count == before.slides.count)
        #expect(try after.slides[1].comments.first?.text == "Keep this review")
        #expect(after.slides.map { $0.part.uri } == before.slides.map { $0.part.uri })
        #expect(try after.slides[after.slides.count - 1].part.blob == before.slides[before.slides.count - 1].part.blob)
        #expect(try after.sections[0].id == before.sections[0].id)
        #expect(try Data(contentsOf: initial.url) == bytes)
        #expect(try RenderContentCheck.inspect(revised.url, expected: input).issues.isEmpty)
        #expect(revised.schemaIssues.isEmpty)
        var shorter = input
        shorter.slides[0].body?.table?.rows = [["Only", "One observation", "1"]]
        let shortSnapshot = try RenderSnapshot(deck: shorter, template: supplied).save(in: root)
        await #expect(throws: (any Error).self) {
            try await renderer.retrySlide(snapshotURL: shortSnapshot, sourceURL: initial.url, slideID: "table", variant: 0, into: root)
        }
        #expect(try Data(contentsOf: initial.url) == bytes)
    }

    @Test(arguments: [false, true])
    func longCaptionFlowsAfterEveryTableRowAndDetectsDuplicateRows(templateBacked: Bool) async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let input = fixture(source: (1...90).map { "Source \($0) retains its exact evidence and publication details." }.joined(separator: "\n"))
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: true, into: root,
            template: templateBacked ? template(wide: false) : nil)
        #expect(try RenderContentCheck.inspect(result.url, expected: input).issues.isEmpty)
        let deck = try Presentation(contentsOf: result.url)
        let names = try deck.slides.map { try $0.part.dom().firstChild(named: "p:cSld")?[attribute: "name"] ?? "" }
        let firstNote = try #require(names.firstIndex { $0.hasPrefix("Lectern:table-source-notes") })
        #expect(deck.slides.prefix(firstNote).allSatisfy { $0.shapes.all.contains { $0 is TableFrame } })
        #expect(try deck.sections[0].slideCount == deck.slides.count)
        if !templateBacked {
            for slide in deck.slides.dropFirst(firstNote).dropLast() {
                let footer = try #require(slide.shapes.all.first { $0.textFrame?.text == input.meta.title })
                let footerFrame = try #require(slide.effectiveFrame(of: footer))
                for shape in slide.shapes.all where shape.textFrame?.text.contains("Source ") == true {
                    #expect(try #require(slide.effectiveFrame(of: shape)).maxY <= footerFrame.y)
                }
            }
        }
        // Tokens alone cannot catch a duplicated row: the native-cell oracle must.
        let frame = try #require(deck.slides[0].shapes.all.compactMap { $0 as? TableFrame }.first)
        let table = try #require(frame.table)
        for column in 0..<3 { try table.cell(2, column).text = table.cell(1, column).text }
        try deck.save(to: result.url)
        #expect(try RenderContentCheck.inspect(result.url, expected: input).issues.contains { $0.contains("native table cells changed") })
    }

    @Test func raggedRowsAndCollidingOriginalIDsSurvivePagination() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var input = fixture()
        input.slides[0].body?.table?.rows[0] = ["R1", "Short"]
        input.slides[0].body?.table?.rows[1].append("Extra cell retained")
        input.slides[1].id = "table-continued-2"
        input.sections?[0].slideIds = input.slides.map(\.id)
        let output = try await DeckRenderer().render(input, designURL: nil, notesEnabled: false, into: root)
        #expect(try RenderContentCheck.inspect(output.url, expected: input, notesEnabled: false).issues.isEmpty)
        let deck = try Presentation(contentsOf: output.url)
        let names = try deck.slides.map { try $0.part.dom().firstChild(named: "p:cSld")?[attribute: "name"] ?? "" }
        #expect(Set(names).count == names.count)
        #expect(names.last == "Lectern:table-continued-2")
        #expect(names.contains("Lectern:table-continued-2-next"))
        #expect(deck.slides.allSatisfy { $0.notesText.isEmpty })
    }

    @Test func embeddedTemplateFacesDriveGenerationAndSurviveRecovery() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let fontURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        let font = try Data(contentsOf: fontURL)
        let source = try Presentation()
        source.theme.majorFont = "DejaVu Sans"; source.theme.minorFont = "DejaVu Sans"
        try source.embedFont("DejaVu Sans", faces: FontFaces(regular: font))
        source.documentKind = .template
        let supplied = try PowerPointTemplate(data: source.serializedData(), name: "Embedded caller font")
        var input = fixture()
        input.slides = [input.slides[0]]; input.sections = nil
        let renderer = DeckRenderer()
        let initial = try await renderer.render(input, designURL: nil, notesEnabled: true, into: root, template: supplied)
        #expect(!initial.unmeasuredFonts.contains("DejaVu Sans Regular"))
        let snapshot = try RenderSnapshot(deck: input, template: supplied).save(in: root)
        let revised = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: initial.url, slideID: "table", variant: 0, into: root)
        let reopened = try Presentation(contentsOf: revised.url)
        let originalParts = source.package.parts.filter { $0.key.value.hasPrefix("/ppt/fonts/") }
        let savedParts = reopened.package.parts.filter { $0.key.value.hasPrefix("/ppt/fonts/") }
        #expect(savedParts.count == originalParts.count)
        for (uri, part) in originalParts { #expect(savedParts[uri]?.blob == part.blob) }
        #expect(reopened.registerEmbeddedFonts().contains("DejaVu Sans"))
        #expect(try RenderContentCheck.inspect(revised.url, expected: input).issues.isEmpty)
    }

    @Test func invalidOrOversizedRowsFailBeforeWritingADeck() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var input = fixture(source: "")
        input.slides[0].body?.table = IRTable(headers: ["Evidence"], rows: [[String(repeating: "Retain this word. ", count: 1500)]])
        let renderer = DeckRenderer()
        await #expect(throws: (any Error).self) {
            try await renderer.render(input, designURL: nil, notesEnabled: true, into: root)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
}
