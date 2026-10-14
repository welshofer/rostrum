import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite struct ContinuationReflowTests {
    @Test(arguments: [false, true])
    func oneSidedTailUsesFullWidthAndPreservesItsHeading(rightRemains: Bool) throws {
        let long = Column(heading: "Long side", bullets: (1...9).map { "Fact \($0)" })
        let short = Column(heading: "Short side", bullets: ["One observation"])
        let original = IRSlide(id: "a", sectionId: "s", layout: "comparison", title: "Evidence",
            body: Body(left: rightRemains ? short : long, right: rightRemains ? long : short, source: "Citation"), notes: "Notes")
        let deck = DeckIR(meta: Meta(title: "Keep"), sections: [.init(id: "s", title: "Evidence", slideIds: ["a"])], slides: [original])
        let result = try AuthoredPagination.prepare(deck, images: [:]) { slide, _ in
            if slide.kind == .bullets { return (slide.body?.bullets?.count ?? 0) <= 5 }
            return max(slide.body?.left?.bullets.count ?? 0, slide.body?.right?.bullets.count ?? 0) <= 2
        }
        #expect(result.deck.slides.count == 3)
        #expect(result.deck.slides[0].kind == .comparison)
        let tails = Array(result.deck.slides.dropFirst())
        #expect(tails.allSatisfy { $0.kind == .bullets && $0.body?.lead == long.heading && $0.body?.left == nil && $0.body?.right == nil })
        #expect(tails.flatMap { $0.body?.bullets?.map(\.text) ?? [] } == Array(long.bullets.dropFirst(2)))
        #expect(result.deck.sections?[0].slideIds == result.deck.slides.map(\.id))
        #expect(result.deck.slides.allSatisfy { $0.title == original.title && $0.sectionId == "s" && $0.notes == "Notes" && $0.body?.source == "Citation" })
    }

    @Test func sparseTailMovesOnlyMeasuredContentAndKeepsImageAssociations() throws {
        let bullets = (1...9).map { Bullet(text: "Evidence \($0)") }
        let input = DeckIR(meta: Meta(title: "Balance"), slides: [IRSlide(id: "a", layout: "imageRight",
            title: "Evidence", body: Body(bullets: bullets), notes: "Notes")])
        var measurements = 0
        let result = try AuthoredPagination.prepare(input, images: ["a": Data([1])], usage: { page, image in
            #expect(image)
            measurements += 1
            let count = page.body?.bullets?.count ?? 0
            return count <= 8 ? Double(count) / 8 : nil
        }, fits: { page, _ in (page.body?.bullets?.count ?? 0) <= 8 })
        #expect(result.deck.slides.map { $0.body?.bullets?.count } == [5, 4])
        #expect(result.deck.slides.flatMap { $0.body?.bullets ?? [] } == bullets)
        #expect(result.deck.slides.allSatisfy { result.images[$0.id] == Data([1]) && $0.notes == "Notes" })
        #expect(measurements <= 18)
    }

    @Test func rejectedTailMovesKeepTheOriginalPages() throws {
        let input = DeckIR(meta: Meta(title: "Keep"), slides: [IRSlide(id: "a", layout: "bullets",
            body: Body(bullets: (1...9).map { Bullet(text: "Fact \($0)") }))])
        let output = try AuthoredPagination.prepare(input, images: [:], usage: { page, _ in
            let values = page.body?.bullets ?? []
            if values.count == 8 { return 1 }
            if values.count == 1 { return 0.1 }
            return nil
        }, fits: { slide, _ in (slide.body?.bullets?.count ?? 0) <= 8 })
        #expect(output.deck.slides.map { $0.body?.bullets?.count } == [8, 1])
    }

    @Test func cancellationDuringBalancingDoesNotReturnPages() async throws {
        let task = Task {
            let input = DeckIR(meta: Meta(title: "Cancel"), slides: [IRSlide(id: "a", layout: "bullets",
                body: Body(bullets: (1...9).map { Bullet(text: "Fact \($0)") }))])
            return try AuthoredPagination.prepare(input, images: [:], usage: { _, _ in
                withUnsafeCurrentTask { $0?.cancel() }; return 0.1
            }, fits: { slide, _ in (slide.body?.bullets?.count ?? 0) <= 8 })
        }
        do { _ = try await task.value; Issue.record("Cancelled balancing returned pages") }
        catch is CancellationError { }
    }

    @Test(arguments: [720.0, 960.0])
    func sourceUsesFreeBandWithoutTouchingContentOrFurniture(width: Double) throws {
        let deck = try Presentation()
        deck.slideSize = (.points(width), .points(540))
        let slide = try deck.closingSlide("Workflow", callToAction: "Keep the evidence connected.")
        let before = slide.shapes.all.map { ($0.shapeID, $0.frame, $0.textFrame?.text) }
        let text = String(repeating: "Reference edition and original evidence; ", count: 7)
        let fitter = AuthoredLayoutEngine(presentation: deck)
        let source = try AuthoredSourcePlacement.add(text, to: slide, in: deck, fitter: fitter)
        #expect(source.textFrame?.text == text)
        #expect(source.frame.width == deck.bounds.width - deck.style.margin * 2)
        #expect(source.frame.maxY <= deck.bounds.maxY - .inches(0.55) - .points(6))
        #expect(source.textFrame?.paragraphs.flatMap(\.runs).allSatisfy { ($0.fontSize ?? 0) >= 10 } == true)
        for (id, frame, words) in before {
            let original = try #require(slide.shapes.all.first { $0.shapeID == id })
            #expect(original.frame == frame && original.textFrame?.text == words)
            #expect(source.frame.minY >= frame.maxY + .points(8))
        }
        let reopened = try Presentation(data: deck.serializedData())
        let savedText = reopened.slides.flatMap { $0.shapes.all.compactMap { $0.textFrame?.text } }
        #expect(savedText.contains(text))
    }

    @Test func aReservedImageOrOversizedSourceCannotBeOverpainted() throws {
        let deck = try Presentation()
        let slide = try deck.closingSlide("Workflow")
        let before = XML.document(try slide.part.dom())
        let text = String(repeating: "Reference edition and evidence; ", count: 7)
        #expect(throws: LayoutError.self) {
            try AuthoredSourcePlacement.add(text, to: slide, in: deck,
                fitter: AuthoredLayoutEngine(presentation: deck), reserved: [deck.bounds])
        }
        #expect(XML.document(try slide.part.dom()) == before)
        #expect(throws: LayoutError.self) {
            try AuthoredSourcePlacement.add(String(repeating: text, count: 30), to: slide, in: deck,
                fitter: AuthoredLayoutEngine(presentation: deck))
        }
        #expect(XML.document(try slide.part.dom()) == before)
    }

    @Test func productionContinuationKeepsWordsGeometryAndRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let facts = (1...17).map { "Evidence \($0): preserve every original word while the remaining observations use the available slide width." }
        let input = DeckIR(meta: Meta(title: "Reflow"), sections: [.init(id: "s", title: "Evidence", slideIds: ["a"])], slides: [
            IRSlide(id: "a", sectionId: "s", layout: "comparison", title: "Evidence", body: Body(
                left: .init(heading: "Detailed observations", bullets: facts),
                right: .init(heading: "Summary observations", bullets: ["A short conclusion."])), notes: "Keep the notes.")])
        let renderer = DeckRenderer()
        let result = try await renderer.render(input, designURL: nil, notesEnabled: true, into: root)
        #expect(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
        #expect(try RenderContentCheck.inspect(result.url, expected: input).issues.isEmpty)
        let deck = try Presentation(contentsOf: result.url)
        #expect(deck.slides.count > 1)
        let continuations = Array(deck.slides.dropFirst())
        var wideBodies = 0
        for page in continuations {
            let text = page.shapes.all.compactMap { $0.textFrame?.text }.joined(separator: "\n")
            if !text.contains("Summary observations") {
                #expect(text.contains("Detailed observations"))
                for shape in page.shapes.all where shape.textFrame?.text.contains("Evidence ") == true {
                    let frame = try #require(page.effectiveFrame(of: shape))
                    #expect(frame.width.points > deck.bounds.width.points * 0.75)
                    wideBodies += 1
                }
            }
        }
        #expect(wideBodies > 0)
        let text = deck.slides.flatMap { $0.shapes.all.compactMap { $0.textFrame?.text } }.joined(separator: "\n")
        for fact in facts { #expect(text.components(separatedBy: fact).count == 2) }
        #expect(try deck.sections[0].slideCount == deck.slides.count)
        let snapshot = try RenderSnapshot(deck: input).save(in: root)
        try deck.slides[1].addComment("Keep this review.", author: "Reviewer")
        try deck.save(to: result.url)
        let original = try Data(contentsOf: result.url)
        let recovered = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: result.url, slideID: "a", variant: 0, into: root)
        let revised = try Presentation(contentsOf: recovered.url)
        #expect(revised.slides.count == deck.slides.count)
        #expect(try revised.slides[1].comments.first?.text == "Keep this review.")
        #expect(try Data(contentsOf: result.url) == original)
        #expect(try RenderContentCheck.inspect(recovered.url, expected: input).issues.isEmpty)
    }

    @Test func productionClosingKeepsModerateSourceOnTheSlide() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = String(repeating: "Reference edition and original evidence; ", count: 7)
        let input = DeckIR(meta: Meta(title: "Sources"), slides: [
            IRSlide(id: "cover", layout: "title", title: "Sources"),
            IRSlide(id: "a", layout: "closing", title: "Keep the evidence connected", body: Body(
                callToAction: "Make the workflow explicit.", source: source), notes: "Speaker notes.")])
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: true, into: root)
        #expect(result.slideCount == 2)
        #expect(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
        #expect(try RenderContentCheck.inspect(result.url, expected: input).issues.isEmpty)
        let inspection = try DeckInspector.inspect(deckAt: result.url)
        #expect(inspection.previews == result.previews)
        #expect(inspection.previewDiagnostics == result.previewDiagnostics)
        let deck = try Presentation(contentsOf: result.url)
        let last = try deck.slides[1]
        let sourceShape = try #require(last.shapes.all.first { $0.textFrame?.text == source })
        let sourceFrame = try #require(last.effectiveFrame(of: sourceShape))
        #expect(sourceFrame.width.points > deck.bounds.width.points * 0.75)
        let footer = try #require(last.shapes.all.first { $0.textFrame?.text == input.meta.title })
        let footerFrame = try #require(last.effectiveFrame(of: footer))
        #expect(sourceFrame.maxY < footerFrame.minY)
    }

    @Test func productionSparseEndingRetainsEveryParagraph() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let facts = (1...23).map { "Fact \($0): preserve the complete evidence and its original wording while keeping the presentation readable." }
        let input = DeckIR(meta: Meta(title: "Balanced ending"), slides: [IRSlide(id: "a", layout: "bullets", title: "Evidence",
            body: Body(bullets: facts.map { Bullet(text: $0) }))])
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: true, into: root)
        let deck = try Presentation(contentsOf: result.url)
        #expect(deck.slides.count > 1)
        let paragraphs = deck.slides.map { slide in
            slide.shapes.all.flatMap { $0.textFrame?.paragraphs.map(\.plainText) ?? [] }.filter { facts.contains($0) }
        }
        #expect(paragraphs.flatMap { $0 } == facts)
        #expect((paragraphs.last?.count ?? 0) > 1)
        #expect(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
    }
}
