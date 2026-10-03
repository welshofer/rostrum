import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite struct CompositionRecoveryTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    @Test func structuredTemplateContentIsEditableAndNeverFlattened() async throws {
        let source = try Presentation()
        source.documentKind = .template
        let bytes = try source.serializedData()
        let template = try PowerPointTemplate(data: bytes, name: "Native")
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let slides = [
            IRSlide(id: "metrics", layout: "metrics", title: "Measures", body: Body(stats: [.init(value: "31%", label: "Private"), .init(value: "17%", label: "Public")])),
            IRSlide(id: "process", layout: "diagram", title: "Process", body: Body(diagram: .init(kind: "process", items: ["Observe", "Act", "Learn"]))),
            IRSlide(id: "timeline", layout: "timeline", title: "Timeline", body: Body(milestones: [.init(label: "Now", detail: "Observe"), .init(label: "Next", detail: "Act")])),
            IRSlide(id: "quadrant", layout: "quadrant", title: "Choices", body: Body(quadrants: [.init(heading: "A", detail: "First"), .init(heading: "B", detail: "Second"), .init(heading: "C", detail: "Third"), .init(heading: "D", detail: "Fourth")]))]
        let result = try await DeckRenderer().render(DeckIR(meta: Meta(title: "Structures"), slides: slides), designURL: nil, notesEnabled: true, into: root, template: template)
        let output = try Presentation(contentsOf: result.url)
        #expect(result.schemaIssues.isEmpty)
        #expect(!result.warnings.contains { $0.contains("arranged as text") })
        #expect(try output.slides[0].shapes.all.contains { $0.textFrame?.text == "31%" })
        #expect(try output.slides[0].shapes.all.contains { $0.textFrame?.text == "Private" })
        #expect(try output.slides[1].shapes.all.contains { $0.textFrame?.text == "→" })
        for (uri, part) in source.package.parts where uri.value.contains("slideLayout") || uri.value.contains("slideMaster") || uri.value.contains("theme") {
            #expect(output.package.parts[uri]?.blob == part.blob)
        }
    }
    @Test func retryChangesOnlyTheSelectedSlideAndKeepsNotesAndOriginalFile() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let source = try Presentation()
        source.documentKind = .template
        let template = try PowerPointTemplate(data: source.serializedData(), name: "Native")
        let ir = DeckIR(meta: Meta(title: "Recover"), slides: [
            IRSlide(id: "a", layout: "bullets", title: "Evidence", body: Body(bullets: [.init(text: "Keep this fact")]), notes: "Speaker notes retained"),
            IRSlide(id: "b", layout: "bullets", title: "Untouched", body: Body(bullets: [.init(text: "Keep this other fact")]))])
        let renderer = DeckRenderer()
        let initial = try await renderer.render(ir, designURL: nil, notesEnabled: true, into: root, template: template)
        let annotated = try Presentation(contentsOf: initial.url)
        try annotated.slides[0].addComment("Keep this review", author: "Regression reviewer")
        try annotated.save(to: initial.url)
        let originalBytes = try Data(contentsOf: initial.url)
        let before = try Presentation(data: originalBytes)
        let snapshot = try RenderSnapshot(deck: ir, template: template).save(in: root)
        let revised = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: initial.url, slideID: "a", variant: 1, into: root)
        let after = try Presentation(contentsOf: revised.url)
        #expect(try Data(contentsOf: initial.url) == originalBytes)
        #expect(after.slides.count == before.slides.count)
        #expect(try before.slides[0].part.uri == after.slides[0].part.uri)
        #expect(try before.slides[1].part.blob == after.slides[1].part.blob)
        #expect(try before.slides[1].part.rels.serialized() == after.slides[1].part.rels.serialized())
        #expect(try before.slides[0].notesText == after.slides[0].notesText)
        #expect(try after.slides[0].comments.first?.text == "Keep this review")
        #expect(revised.schemaIssues.isEmpty)
        #if !os(iOS)
        #expect((try FileManager.default.attributesOfItem(atPath: snapshot.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #endif
    }
    @Test func authoredRetryKeepsExistingMastersAndOtherSlides() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let deck = DeckIR(meta: Meta(title: "Authored recovery"), slides: [
            IRSlide(id: "a", layout: "bullets", title: "Revise", body: Body(bullets: [.init(text: "First fact"), .init(text: "Second fact")])),
            IRSlide(id: "b", layout: "bullets", title: "Keep", body: Body(bullets: [.init(text: "Untouched fact")]))])
        let renderer = DeckRenderer()
        let initial = try await renderer.render(deck, designURL: nil, notesEnabled: true, into: root)
        let snapshot = try RenderSnapshot(deck: deck, design: "# Custom\n\n## Color palette\n- #008080\n- #FFFFFF").save(in: root)
        let before = try Presentation(contentsOf: initial.url)
        let result = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: initial.url, slideID: "a", variant: 1, into: root)
        let after = try Presentation(contentsOf: result.url)
        #expect(try before.slides[1].part.blob == after.slides[1].part.blob)
        for (uri, part) in before.package.parts where uri.value.contains("slideMaster") || uri.value.contains("theme") {
            #expect(after.package.parts[uri]?.blob == part.blob)
        }
        let words = try after.slides[0].shapes.all.compactMap { $0.textFrame?.text }.joined(separator: "\n")
        #expect(words.contains("First fact") && words.contains("Second fact"))
    }

    @Test func snapshotRetentionAndAssetsRoundTrip() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let deck = DeckIR(meta: Meta(title: "Saved"), slides: [IRSlide(id: "a", layout: "title", title: "Saved")])
        let snapshot = RenderSnapshot(deck: deck, images: ["a": Data([1, 2, 3])], design: "# Design")
        let url = try snapshot.save(in: root)
        let loaded = try RenderSnapshot.load(url)
        #expect(loaded.deck == deck && loaded.images == snapshot.images && loaded.design == snapshot.design)
        #expect(DeckStorage.pruneDiagnostics(in: root, olderThan: 1, now: Date().addingTimeInterval(2)) == 1)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
    @Test func cancelledRecoveryCreatesNoOutput() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = try RenderSnapshot(deck: DeckIR(meta: Meta(title: "Cancelled"), slides: [
            IRSlide(id: "a", layout: "title", title: "Saved")])).save(in: root)
        let output = root.appendingPathComponent("output")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await DeckRenderer().retrySlide(snapshotURL: snapshot, sourceURL: nil,
                slideID: "a", variant: 0, into: output)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }
    @Test func denseComparisonFitsAuthoredThemeWithoutDroppingText() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let items = ["Explain the evidence and sources of change.",
            "Connect global outcomes with unequal exposure and vulnerability.",
            "Explore prevention, adaptation and practical next steps.",
            "Annual evidence review (2025); consolidated research synthesis (2023)."]
        let ir = DeckIR(meta: Meta(title: "Dense comparison"), slides: [IRSlide(id: "a", layout: "comparison",
            title: "Human choices drive change; practical solutions can limit harm",
            body: Body(left: .init(heading: "Evidence", bullets: Array(items.prefix(3))),
                       right: .init(heading: "Our route", bullets: items)))])
        let style = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Resources/Styles/serif.md")
        let result = try await DeckRenderer().render(ir, designURL: style, notesEnabled: true, into: root)
        let presentation = try Presentation(contentsOf: result.url)
        let text = try presentation.slides[0].shapes.all.compactMap { $0.textFrame?.text }.joined(separator: "\n")
        #expect(items.allSatisfy { text.contains($0) })
        #expect(result.schemaIssues.isEmpty)
    }

    @Test func generatedObjectTypographyScalesWithTemplateCanvas() throws {
        let source = try Presentation()
        source.slideSize = (width: .points(1920), height: .points(1080))
        let engine = TemplateLayoutEngine(presentation: source)
        #expect(engine.objectScale == 2)
        let style = engine.objectStyle(layout: try #require(source.layout(type: "obj")), slot: 1)
        let table = IRTable(headers: ["Label"], rows: [["Value"]])
        let heights = TemplateRendering.tableRowHeights(table, width: 800, style: style, engine: engine)
        #expect(heights.allSatisfy { $0 >= 50 })
    }

    @Test func explanatoryColumnsReceiveMoreWidth() {
        let table = IRTable(headers: ["Year", "Explanation"], rows: [["2024", "A considerably longer explanation that needs more width"]])
        let widths = TemplateRendering.tableColumnWidths(table, width: 600)
        #expect(widths[1] > widths[0])
        #expect(abs(widths.reduce(0, +) - 600) < 0.01)
    }
}
