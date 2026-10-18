import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite(.serialized) struct PanelPaginationTests {
    private func fixture() throws -> DeckIR {
        let url = try #require(Bundle.module.url(forResource: "crowded-panels", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(DeckIR.self, from: Data(contentsOf: url))
    }

    @Test func fittingPanelsAreUntouchedAndFourCardsCanKeepTheirStyle() throws {
        let input = try fixture()
        var calls = 0
        let unchanged = try AuthoredPagination.prepare(input, images: [:]) { _, _ in calls += 1; return true }
        #expect(unchanged.deck == input && unchanged.warnings.isEmpty)
        #expect(calls == input.slides.count)
        var deck = input; deck.slides = [input.slides[0]]
        let result = try AuthoredPagination.prepare(deck, images: [:]) { slide, _ in slide.body?.panels?.count == 2 }
        #expect(result.deck.slides.count == 2)
        #expect(result.deck.slides.allSatisfy { $0.layout == "cards" && $0.notes == input.slides[0].notes })
        #expect(result.deck.slides.flatMap { $0.body?.panels ?? [] } == input.slides[0].body?.panels)
    }

    @Test func continuationPreservesExactTextHeadingsStepNumbersAndIDs() throws {
        var input = try fixture()
        let steps = input.slides[2]
        // Force one panel's detail to split, with non-normalized Unicode and
        // whitespace. A heading must remain visible with every detail fragment.
        input.slides = [steps, IRSlide(id: steps.id + "-continued-2", layout: "title", title: "Existing")]
        input.slides[0].body?.panels?[0].detail = String(repeating: "Cafe\u{301}  costs\t£23\n", count: 20)
        let result = try AuthoredPagination.prepare(input, images: [:]) { slide, _ in
            guard slide.kind == .bullets else { return slide.kind == .title }
            return (slide.body?.bullets ?? []).reduce(0) { $0 + $1.text.utf8.count } <= 240
        }
        let pages = Array(result.deck.slides.dropLast())
        #expect(Set(result.deck.slides.map(\.id)).count == result.deck.slides.count)
        #expect(pages[1].id == steps.id + "-continued-2-next")
        #expect(pages.allSatisfy { $0.notes == steps.notes && $0.sectionId == steps.sectionId })
        let text = pages.flatMap { $0.body?.bullets?.map(\.text) ?? [] }
        for (index, panel) in (input.slides[0].body?.panels ?? []).enumerated() {
            let prefix = "\(index + 1). \(panel.heading)\n"
            let chunks = text.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
            #expect(Data(chunks.joined().utf8) == Data(panel.detail.utf8))
        }
        for label in [steps.body?.kicker, steps.body?.lead, steps.body?.source].compactMap({ $0 }) {
            #expect(text.contains(label))
        }
        #expect(result.deck.sections?[0].slideIds.contains(pages.last!.id) == true)
    }

    @Test func cancellationAndNonLayoutFailuresPropagate() async throws {
        let slide = try fixture().slides[0]
        struct ProbeError: Error {}
        #expect(throws: ProbeError.self) { try PanelPagination.reflow(slide) { _ in throw ProbeError() } }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try PanelPagination.reflow(slide) { _ in Issue.record("Cancelled probe ran"); return true }
        }
        do { _ = try await task.value; Issue.record("Cancellation was swallowed") }
        catch is CancellationError {} catch { throw error }
    }

    @Test func impossibleEmptyDetailCannotDiscardItsHeading() throws {
        let slide = IRSlide(id: "empty", layout: "cards", title: "Evidence", body: Body(panels: [
            .init(heading: "Keep this heading", detail: ""), .init(heading: "Other", detail: "")]))
        #expect(throws: LayoutError.self) { try PanelPagination.reflow(slide) { _ in false } }
    }

    @Test(arguments: ["design", "template16x9", "template4x3"])
    func crowdedPanelsRenderAndRecover(mode: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var input = try fixture()
        let design = "# Cost planning\n## Fonts\n- Heading: Arial\n- Body: Arial\n## Palette\n- Text: #22303F\n- Accent 1: #18A999\n"
        let designURL = root.appendingPathComponent("design.md")
        try design.write(to: designURL, atomically: true, encoding: .utf8)
        let source = try Presentation()
        if mode == "template4x3" {
            let originalWidth = source.slideSize.width.points
            source.slideSize = (.inches(10), .inches(7.5))
            let scale = source.slideSize.width.points / originalWidth
            for part in source.package.parts.values where [ContentType.slideLayout, ContentType.slideMaster].contains(part.contentType) {
                var pending = [try part.dom()]
                while let node = pending.popLast() {
                    for key in node.name == "a:off" ? ["x"] : node.name == "a:ext" ? ["cx"] : [] {
                        if let value = node[attribute: key].flatMap(Double.init) { node[attribute: key] = String(Int((value * scale).rounded())) }
                    }
                    pending += node.childElements
                }
                part.markDirty()
            }
        }
        source.documentKind = .template
        let template = mode == "design" ? nil : try PowerPointTemplate(data: source.serializedData(), name: "Native slots")
        // Establish that the original strict panel composer rejects this input.
        #expect(throws: LayoutError.self) { try PanelRendering.build(input.slides[0], in: source) }
        input.slides.append(IRSlide(id: "neighbor", layout: "bullets", title: "Untouched", body: Body(bullets: [.init(text: "Neighbor text")])))
        let renderer = DeckRenderer()
        let result = try await renderer.render(input, designURL: designURL, notesEnabled: true, into: root, template: template)
        #expect(result.slideCount > input.slides.count)
        #expect(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
        #expect(result.warnings.contains { $0.contains("crowded panels were reflowed") })
        #expect(try RenderContentCheck.inspect(result.url, expected: input).issues.isEmpty)
        let saved = try Presentation(contentsOf: result.url)
        #expect(saved.slideSize.width == source.slideSize.width)
        try saved.validateTemplateBindings()
        if template != nil {
            for part in source.package.parts.values where [ContentType.slideLayout, ContentType.slideMaster, ContentType.theme].contains(part.contentType) {
                #expect(saved.package.parts[part.uri]?.blob == part.blob)
            }
        }
        for slide in saved.slides { for shape in slide.shapes.all {
            if let frame = slide.effectiveFrame(of: shape) {
                #expect(frame.x >= .zero && frame.y >= .zero && frame.maxX <= saved.bounds.maxX && frame.maxY <= saved.bounds.maxY)
            }
        } }
        let inspected = try DeckInspector.inspect(deckAt: result.url)
        #expect(inspected.previews == result.previews && inspected.previewDiagnostics == result.previewDiagnostics)
        let second = try await renderer.render(input, designURL: designURL, notesEnabled: true, into: root, template: template)
        #expect(try Data(contentsOf: result.url) == Data(contentsOf: second.url))
        let snapshot = try RenderSnapshot(deck: input, design: design, template: template).save(in: root)
        let rebuilt = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: nil,
            slideID: input.slides[0].id, variant: 0, into: root.appendingPathComponent("rebuilt"))
        #expect(try Data(contentsOf: result.url) == Data(contentsOf: rebuilt.url))
        try saved.slides[1].addComment("Keep review", author: "Reviewer")
        try saved.save(to: result.url)
        let recovered = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: result.url,
            slideID: input.slides[0].id, variant: 0, into: root.appendingPathComponent("recover"))
        let reopened = try Presentation(contentsOf: recovered.url)
        #expect(try reopened.slides[1].comments.first?.text == "Keep review")
        #expect(reopened.slides.count == saved.slides.count)
        #expect(try reopened.slides[reopened.slides.count - 1].part.blob == saved.slides[saved.slides.count - 1].part.blob)
        #expect(try RenderContentCheck.inspect(recovered.url, expected: input).issues.isEmpty)
    }
}
