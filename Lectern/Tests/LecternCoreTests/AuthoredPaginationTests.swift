import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct AuthoredPaginationTests {
    @Test func wrappedComparisonHeadingReservesSpaceAboveBody() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let heading = "Compare annual territorial emissions in the current year with cumulative totals across the historical record."
        let deck = DeckIR(meta: Meta(title: "Comparison"), slides: [IRSlide(id: "a", layout: "comparison", title: "Two views of the evidence",
            body: Body(left: .init(heading: heading, bullets: ["Annual observations."]),
                       right: .init(heading: "Historical contributions", bullets: ["Cumulative observations."])))])
        let result = try await DeckRenderer().render(deck, designURL: nil, notesEnabled: true, into: root)
        let output = try Presentation(contentsOf: result.url)
        let slide = try output.slides[0]
        let head = try #require(slide.shapes.all.first { $0.textFrame?.text == heading })
        let body = try #require(slide.shapes.all.first { $0.textFrame?.text.contains("Annual observations.") == true })
        #expect(try #require(slide.effectiveFrame(of: head)).maxY <= #require(slide.effectiveFrame(of: body)).y)
        #expect(result.droppedContent.isEmpty && result.schemaIssues.isEmpty)
    }

    @Test func recoveryAddsPagesToTheExistingSection() throws {
        let deck = try Presentation()
        _ = try deck.bulletSlide("Evidence", ["Old"])
        _ = try deck.bulletSlide("Neighbor", ["Untouched"])
        try deck.slides.remove(at: 0)
        try deck.slides[0].part.dom().firstChild(named: "p:cSld")?[attribute: "name"] = "Lectern:a"
        try deck.sections.set([("Evidence", 0)])
        let sectionID = try deck.sections[0].id
        let neighbor = try deck.slides[1].part.blob
        let rendered = try Presentation()
        for n in 0..<3 {
            let slide = try rendered.bulletSlide("Evidence", ["New \(n)"])
            try slide.part.dom().firstChild(named: "p:cSld")?[attribute: "name"] = n == 0 ? "Lectern:a" : "Lectern:a-continued-\(n + 1)"
        }
        try rendered.slides.remove(at: 0)
        try DeckRenderer.replaceAuthoredPages(in: deck, startingAt: 0, with: rendered,
            input: IRSlide(id: "a", layout: "bullets"), savedIDs: ["a", "b"])
        #expect(deck.slides.count == 4)
        #expect(try deck.sections[0].id == sectionID)
        #expect(try deck.sections[0].slideIndices == [0, 1, 2, 3])
        #expect(try deck.slides[3].part.blob == neighbor)
    }

    @Test func longChartSourcesMoveToReadableFollowingPages() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = String(repeating: "The source includes the measurement period, reference baseline, and publication details. ", count: 8)
        let deck = DeckIR(meta: Meta(title: "Evidence"), slides: [IRSlide(id: "a", layout: "chart", title: "Measured change",
            body: Body(chart: .init(kind: "bar", categories: ["A", "B"], series: [.init(name: "Value", values: [1, 2])]), source: source))])
        let result = try await DeckRenderer().render(deck, designURL: nil, notesEnabled: true, into: root)
        let output = try Presentation(contentsOf: result.url)
        #expect(result.slideCount > 1 && result.schemaIssues.isEmpty)
        #expect(output.package.parts.keys.contains { $0.value.contains("/charts/") })
        let text = output.slides.dropFirst().flatMap { $0.shapes.all.compactMap { $0.textFrame?.text } }.joined(separator: " ")
        #expect(text.contains("measurement period"))
        #expect(text.components(separatedBy: "publication details.").count - 1 == 8)
    }

    @Test func paginationPreservesContentImagesAndSections() throws {
        let bullets = (0..<7).map { Bullet(text: "Fact \($0)") }
        let slide = IRSlide(id: "a", layout: "imageRight", title: "Evidence",
            body: Body(bullets: bullets, lead: "Lead", source: "Source"), notes: "Notes")
        let deck = DeckIR(meta: Meta(title: "Keep"), sections: [.init(id: "s", title: "Section", slideIds: ["a"])], slides: [slide])
        let result = try AuthoredPagination.prepare(deck, images: ["a": Data([1])]) { slide, _ in
            (slide.body?.lead == nil) && (slide.body?.bullets?.count ?? 0) <= 3
        }
        #expect(result.deck.slides.count == 3)
        #expect(result.deck.slides.flatMap { $0.body?.bullets?.map(\.text) ?? [] } == ["Lead"] + bullets.map(\.text))
        #expect(result.deck.sections?[0].slideIds == result.deck.slides.map(\.id))
        #expect(result.deck.slides.allSatisfy { $0.notes == "Notes" && $0.body?.source == "Source" && result.images[$0.id] == Data([1]) })
    }

    @Test func denseAuthoredDeckRendersAndRecoveryKeepsAllPages() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let facts = (0..<18).map { "Evidence item \($0): preserve these words across readable continuation slides without summarizing the original material." }
        let deck = DeckIR(meta: Meta(title: "Dense recovery"), sections: [.init(id: "s", title: "Evidence", slideIds: ["a", "b"])], slides: [
            IRSlide(id: "a", layout: "bullets", title: "Evidence", body: Body(bullets: facts.map { Bullet(text: $0) }), notes: "Speaker notes"),
            IRSlide(id: "b", layout: "bullets", title: "Untouched", body: Body(bullets: [Bullet(text: "Neighbor")]))])
        let renderer = DeckRenderer()
        let initial = try await renderer.render(deck, designURL: nil, notesEnabled: true, into: root)
        let before = try Presentation(contentsOf: initial.url)
        #expect(initial.slideCount > 2)
        #expect(initial.schemaIssues.isEmpty && initial.droppedContent.isEmpty)
        let text = before.slides.flatMap { $0.shapes.all.compactMap { $0.textFrame?.text } }.joined(separator: "\n")
        #expect(facts.allSatisfy { text.contains($0) })
        try before.slides[1].addComment("Keep review", author: "Reviewer")
        try before.save(to: initial.url)
        let original = try Data(contentsOf: initial.url)
        let snapshot = try RenderSnapshot(deck: deck).save(in: root)
        let recovered = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: initial.url, slideID: "a", variant: 0, into: root)
        let after = try Presentation(contentsOf: recovered.url)
        #expect(after.slides.count == before.slides.count)
        #expect(try after.slides[1].comments.first?.text == "Keep review")
        #expect(try after.slides[after.slides.count - 1].part.blob == before.slides[before.slides.count - 1].part.blob)
        #expect(try after.sections[0].slideCount == after.slides.count)
        #expect(try Data(contentsOf: initial.url) == original)
        let recoveredText = after.slides.flatMap { $0.shapes.all.compactMap { $0.textFrame?.text } }.joined(separator: "\n")
        #expect(facts.allSatisfy { recoveredText.contains($0) })
    }
}
