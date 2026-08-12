import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct DeckInspectorTests {
    private func write(_ deck: Presentation, named name: String) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-inspect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(name)
        try deck.serializedData().write(to: url)
        return url
    }

    @Test func countsWhatTheDeckIsMadeOf() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("Say hello.")
        try deck.slides.add()
        let url = try write(deck, named: "Sample.pptx")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var events: [DeckInspector.Event] = []
        let inspection = try DeckInspector.inspect(deckAt: url, renderPreviews: false) {
            events.append($0)
        }

        #expect(inspection.fileName == "Sample.pptx")
        #expect(inspection.slideCount == 2)
        #expect(inspection.slides.count == 2)
        #expect(inspection.notesCount == 1)
        #expect(inspection.byteCount > 0)
        #expect(inspection.partCount > 0)
        #expect(inspection.slideSize.contains("in ×"))
        #expect(inspection.hasFindings == false)

        // Every step announces itself, so the window is never silently busy.
        #expect(events.contains(.opening))
        #expect(events.contains(.validating))
        #expect(events.contains(.extracting))
        #expect(events.contains(.finished))
        // Previews were skipped, so no rendering was claimed.
        #expect(inspection.previews.isEmpty)
        #expect(!events.contains { if case .rendering = $0 { return true } else { return false } })
    }

    @Test func digestsCarryTheSlidesWords() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add(clonedFrom: deck.layout(type: "title")!)
        slide.title?.textFrame?.text = "Quarterly review"
        slide.placeholder(idx: 1)?.textFrame?.text = "Fiscal 2026"
        try slide.setNotes("Open with the anecdote.")

        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(3), width: .inches(6), height: .inches(2)))
        let text = try #require(box.textFrame)
        text.clear()
        text.addParagraph().addRun("Revenue is up")
        let nested = text.addParagraph()
        nested.indentLevel = 1
        nested.addRun("Especially in EMEA")

        let url = try write(deck, named: "Words.pptx")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let inspection = try DeckInspector.inspect(deckAt: url, renderPreviews: false)
        let digest = inspection.slides[1]

        #expect(digest.number == 2)
        #expect(digest.title == "Quarterly review")
        #expect(digest.subtitle == "Fiscal 2026")
        #expect(digest.notes == ["Open with the anecdote."])
        // Indent level survives as leading space, so the view prints it flat.
        #expect(digest.bullets == ["Revenue is up", "    Especially in EMEA"])
        #expect(digest.hasAttachments == false)
    }

    @Test func rendersOnePreviewPerSlideAndReportsProgress() throws {
        let deck = try Presentation()
        try deck.slides.add()
        let url = try write(deck, named: "Pictures.pptx")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var rendered: [Int] = []
        let inspection = try DeckInspector.inspect(deckAt: url) { event in
            if case .rendering(let done, let total) = event {
                #expect(total == 2)
                rendered.append(done)
            }
        }

        #expect(inspection.previews.count == inspection.previewTitles.count)
        #expect(inspection.previews.count == 2)
        // Zero first, so a determinate bar starts empty rather than jumping.
        #expect(rendered == [0, 1, 2])
    }

    @Test func aFileThatIsNotADeckFailsRatherThanReturningNonsense() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-inspect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("not-a-deck.pptx")
        try Data("this is not a zip".utf8).write(to: url)

        #expect(throws: (any Error).self) {
            try DeckInspector.inspect(deckAt: url, renderPreviews: false)
        }
    }

    @Test func sizesAreReadable() throws {
        let deck = try Presentation()
        let url = try write(deck, named: "Size.pptx")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let inspection = try DeckInspector.inspect(deckAt: url, renderPreviews: false)
        #expect(inspection.formattedSize.hasSuffix("KB") || inspection.formattedSize.hasSuffix("B"))
    }
}
