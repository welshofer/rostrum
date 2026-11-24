import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct DeckExporterTests {
    private func scratchDirectory() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func theFolderTakesTheDecksOwnName() {
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/Q3 Review.pptx")) == "Q3 Review")
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/deck.pptx")) == "deck")
        // No extension, and nothing left after trimming, both still name a folder.
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/plain")) == "plain")
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/   .pptx")) == "Deck")
    }

    @Test func exportsADeckIntoAFolderBesideIt() throws {
        let root = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let deck = try Presentation()
        try deck.slides[0].setNotes("Open with the anecdote.")
        let deckURL = root.appendingPathComponent("Q3 Review.pptx")
        try deck.serializedData().write(to: deckURL)

        let outcome = try DeckExporter.export(deckAt: deckURL, into: root)

        #expect(outcome.directory.lastPathComponent == "Q3 Review")
        #expect(outcome.markdownFile.lastPathComponent == "Q3 Review.md")
        #expect(outcome.slideCount == 1)
        #expect(outcome.warnings.isEmpty)

        let markdown = try String(contentsOf: outcome.markdownFile, encoding: .utf8)
        #expect(markdown.contains("Open with the anecdote."))
    }

    @Test func exportingTwiceRefreshesRatherThanDuplicates() throws {
        let root = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let deck = try Presentation()
        let deckURL = root.appendingPathComponent("Deck.pptx")
        try deck.serializedData().write(to: deckURL)

        let first = try DeckExporter.export(deckAt: deckURL, into: root)
        let second = try DeckExporter.export(deckAt: deckURL, into: root)

        #expect(first.directory == second.directory)
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(entries.filter { $0.hasPrefix("Deck") && !$0.hasSuffix(".pptx") } == ["Deck"])
    }

    @Test func dotOnlyDeckNamesFallBackToDeckAndStayInsideParent() throws {
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/...pptx")) == "Deck")
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/..pptx")) == "Deck")
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/.. .pptx")) == "Deck")
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/ .. .pptx")) == "Deck")
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/..")) == "Deck")
        #expect(DeckExporter.folderName(for: URL(fileURLWithPath: "/tmp/.")) == "Deck")

        let root = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let parent = root.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let deck = try Presentation()
        for filename in ["...pptx", " .. .pptx"] {
            let deckURL = root.appendingPathComponent(filename)
            try deck.serializedData().write(to: deckURL)

            let outcome = try DeckExporter.export(deckAt: deckURL, into: parent)
            #expect(outcome.directory.standardizedFileURL.deletingLastPathComponent().path == parent.standardizedFileURL.path)
            #expect(outcome.directory.lastPathComponent == "Deck")
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("..md").path))
        }

        // Callers such as CLI tools and tests often construct `parent` via
        // `URL(fileURLWithPath:)` without `isDirectory: true` (no trailing slash).
        let deckURL = root.appendingPathComponent("Plain.pptx")
        try deck.serializedData().write(to: deckURL)
        let plainParent = URL(fileURLWithPath: parent.path)
        let plainOutcome = try DeckExporter.export(deckAt: deckURL, into: plainParent)
        #expect(plainOutcome.directory.standardizedFileURL.deletingLastPathComponent().path == plainParent.standardizedFileURL.path)
        #expect(plainOutcome.directory.lastPathComponent == "Plain")
    }
}
