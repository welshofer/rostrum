import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct SavedDeckPreviewTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func template(missingFont: Bool) throws -> PowerPointTemplate {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        let deck = try Presentation()
        let family = missingFont ? "Missing Preview QZX" : "DejaVu Sans"
        deck.theme.majorFont = family; deck.theme.minorFont = family
        // A redistributable test font under the fallback alias exercises the
        // same missing-font path on Linux without shipping Microsoft's fonts.
        try deck.embedFont("Arial", faces: FontFaces(regular: Data(contentsOf: url)))
        deck.documentKind = .template
        return try PowerPointTemplate(data: deck.serializedData(), name: "Preview font test")
    }

    private func expectInspectionParity(_ result: DeckResult) throws {
        let bytes = try Data(contentsOf: result.url)
        let inspection = try DeckInspector.inspect(deckAt: result.url)
        #expect(result.previews == inspection.previews)
        #expect(result.previewDiagnostics == inspection.previewDiagnostics)
        #expect(result.previewWarnings == inspection.previewWarnings)
        #expect(result.previewTitles == inspection.previewTitles)
        #expect(result.previewSlideNumbers == inspection.previewSlideNumbers)
        #expect(result.slideCount == inspection.slideCount)
        #expect(try Data(contentsOf: result.url) == bytes)
    }

    @Test(arguments: ["authored", "embedded", "missing"])
    func generatedAndRecoveredPreviewsMatchInspection(mode: String) async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let supplied = mode == "authored" ? nil : try template(missingFont: mode == "missing")
        let input = DeckIR(meta: Meta(title: "Preview parity"), slides: [
            IRSlide(id: "title", layout: "title", title: "Preview parity"),
            IRSlide(id: "body", layout: "bullets", title: "Measure and draw the same font",
                body: Body(bullets: [
                    Bullet(text: "Persistent project context keeps the rendering workflow consistent across previews and inspection."),
                    Bullet(text: "Narrow iii and wide WWW characters need different advances when wrapping lines.")]),
                notes: "Keep these speaker notes.")
        ])
        let renderer = DeckRenderer()
        let result = try await renderer.render(input, designURL: nil, notesEnabled: true, into: root, template: supplied)
        try expectInspectionParity(result)
        #expect(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
        #expect(try RenderContentCheck.inspect(result.url, expected: input).issues.isEmpty)
        let bytes = try Data(contentsOf: result.url)
        if mode == "missing" {
            #expect(result.previewDiagnostics.flatMap(\.issues).contains {
                $0.code == "missingFont" && $0.message.contains("preview uses registered Arial")
            })
            // The preview fallback must never rewrite the caller's font names.
            let saved = try Presentation(data: bytes)
            #expect(saved.theme.majorFont == "Missing Preview QZX")
            #expect(saved.theme.minorFont == "Missing Preview QZX")
            // This was the old result-screen path: reopened bytes with only
            // registered embedded fonts still reproduce its different geometry.
            _ = saved.registerEmbeddedFonts()
            #expect(result.previews[1] != (try saved.renderSVG(slideAt: 1, pixelWidth: 640)))
        }
        let snapshot = try RenderSnapshot(deck: input, template: supplied).save(in: root)
        let recovered = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: result.url,
            slideID: "body", variant: 0, into: root)
        try expectInspectionParity(recovered)
        #expect(try RenderContentCheck.inspect(recovered.url, expected: input).issues.isEmpty)
        #expect(try Data(contentsOf: result.url) == bytes)
    }

    @Test func savedBytesWinOverUnsavedTextAndFontState() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let deck = try Presentation()
        try deck.titleSlide("On disk")
        let url = root.appendingPathComponent("saved.pptx")
        try deck.save(to: url)
        let bytes = try Data(contentsOf: url)
        deck.theme.majorFont = "Unsaved font"
        try deck.slides[1].title?.textFrame?.text = "Unsaved text"
        let previews = DeckPreviews.savedDeck(at: url, failureContext: deck)
        let inspected = try DeckInspector.inspect(deckAt: url)
        #expect(previews.svgs == inspected.previews)
        #expect(previews.diagnostics == inspected.previewDiagnostics)
        #expect(previews.titles.last == "On disk")
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func unreadableSavedFileKeepsSlidePositionsAndFailureDiagnostics() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let deck = try Presentation()
        deck.slideSize = (.points(720), .points(540))
        try deck.titleSlide("Second slide")
        let url = root.appendingPathComponent("unreadable.pptx")
        let bytes = Data("Not a ZIP file".utf8)
        try bytes.write(to: url)
        let previews = DeckPreviews.savedDeck(at: url, failureContext: deck)
        #expect(previews.slideNumbers == [1, 2])
        #expect(previews.titles.last == "Second slide")
        #expect(previews.records.allSatisfy { $0.svg == nil && $0.geometry.aspectRatio == 4.0 / 3.0 })
        #expect(previews.diagnostics.count == 2 && previews.diagnostics.allSatisfy { $0.failure != nil })
        #expect(previews.warnings.count == 2)
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func cancellationSkipsSavedPreviewsAndStopsSharedRenderingBetweenSlides() async throws {
        let skipped = try await Task {
            let deck = try Presentation()
            withUnsafeCurrentTask { $0?.cancel() }
            // Build state stays task-local; cancellation occurs before file I/O.
            return DeckPreviews.savedDeck(at: URL(fileURLWithPath: "/not-read.pptx"), failureContext: deck).svgs
        }.value
        #expect(skipped.isEmpty)
        let stopped = try await Task {
            let deck = try Presentation()
            try deck.titleSlide("Second slide")
            var progress: [Int] = []
            do {
                _ = try DeckPreviews.render(from: deck) { done, _ in
                    progress.append(done)
                    if done == 1 { withUnsafeCurrentTask { $0?.cancel() } }
                }
                return false
            } catch is CancellationError { return progress == [0, 1] }
        }.value
        #expect(stopped)
    }
}
