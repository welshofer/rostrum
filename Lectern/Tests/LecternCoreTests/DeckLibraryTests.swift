import Foundation
import Testing
@testable import LecternCore

@Suite struct DeckLibraryTests {
    private func tempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("decklibrary-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func write(_ name: String, in dir: URL, modified: Date? = nil,
                       bytes: Int = 8) -> URL {
        let url = dir.appendingPathComponent(name)
        try? Data(repeating: 0x41, count: bytes).write(to: url)
        if let modified {
            try? FileManager.default.setAttributes([.modificationDate: modified],
                                                   ofItemAtPath: url.path)
        }
        return url
    }

    @Test func listsDecksNewestFirst() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let now = Date()
        write("oldest.pptx", in: dir, modified: now.addingTimeInterval(-3600))
        write("newest.pptx", in: dir, modified: now)
        write("middle.pptx", in: dir, modified: now.addingTimeInterval(-60))

        let decks = DeckLibrary.decks(in: dir)
        #expect(decks.map(\.name) == ["newest", "middle", "oldest"])
        // The name is what the user reads, so it loses the extension.
        #expect(decks.first?.url.lastPathComponent == "newest.pptx")
        #expect(decks.first?.byteCount == 8)
    }

    @Test func ignoresEverythingThatIsNotADeck() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        write("real.pptx", in: dir)
        // The rejected-draft file the generator leaves beside the decks, and
        // the sort of debris any Documents folder collects.
        write("rejected-draft.json", in: dir)
        write("notes.txt", in: dir)
        write(".hidden.pptx", in: dir)
        // PowerPoint's owner file for a deck it has open. Found in a real
        // Decks folder: it ends in .pptx, it is not hidden, and it would
        // otherwise have listed as a 165-byte deck nobody made.
        write("~$real.pptx", in: dir, bytes: 165)
        try? FileManager.default.createDirectory(
            at: dir.appendingPathComponent("folder.pptx"), withIntermediateDirectories: true)

        #expect(DeckLibrary.decks(in: dir).map(\.name) == ["real"])
    }

    @Test func aMissingOrEmptyDirectoryIsAnEmptyLibraryNotAnError() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(DeckLibrary.decks(in: dir).isEmpty)
        // What a fresh install looks like: nothing has been generated yet, so
        // the folder was never created.
        #expect(DeckLibrary.decks(in: dir.appendingPathComponent("never-made")).isEmpty)
    }

    @Test func decksWrittenInTheSameSecondStillComeBackInAStableOrder() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let sameInstant = Date()
        for name in ["charlie", "alpha", "bravo"] {
            write("\(name).pptx", in: dir, modified: sameInstant)
        }
        // Without the tiebreak this is whatever order the filesystem enumerates
        // in, which can differ between runs and platforms.
        #expect(DeckLibrary.decks(in: dir).map(\.name) == ["alpha", "bravo", "charlie"])
    }

    @Test func deletingRemovesTheDeckFromTheLibrary() throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        write("keep.pptx", in: dir)
        write("remove.pptx", in: dir)

        let doomed = try #require(DeckLibrary.decks(in: dir).first { $0.name == "remove" })
        try DeckLibrary.delete(doomed)

        #expect(DeckLibrary.decks(in: dir).map(\.name) == ["keep"])
        #expect(!FileManager.default.fileExists(atPath: doomed.url.path))
    }
}

// MARK: - Renaming

@Suite struct DeckRenameTests {
    private func scratch() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rename-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeDeck(_ name: String, in dir: URL) throws -> DeckFile {
        let url = dir.appendingPathComponent("\(name).pptx")
        try Data("deck".utf8).write(to: url)
        return DeckFile(url: url, name: name, modified: Date(), byteCount: 4)
    }

    @Test func renamingMovesTheFileTheUserSeesInFinder() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let deck = try makeDeck("ugly-model-generated-slug", in: dir)

        let renamed = try DeckLibrary.rename(deck, to: "Q3 Review")

        #expect(renamed.name == "Q3 Review")
        #expect(renamed.url.lastPathComponent == "Q3 Review.pptx")
        #expect(FileManager.default.fileExists(atPath: renamed.url.path))
        #expect(!FileManager.default.fileExists(atPath: deck.url.path))
    }

    /// Renaming onto a deck that already exists would destroy it.
    @Test func aNameAlreadyTakenIsRefusedRatherThanOverwriting() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = try makeDeck("Keep me", in: dir)
        let second = try makeDeck("Rename me", in: dir)

        #expect(throws: DeckLibrary.RenameProblem.nameTaken("Keep me")) {
            try DeckLibrary.rename(second, to: "Keep me")
        }
        // Both survive, and neither moved.
        #expect(FileManager.default.fileExists(atPath: first.url.path))
        #expect(FileManager.default.fileExists(atPath: second.url.path))
    }

    @Test func aNameThatIsOnlyPunctuationIsNotAName() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let deck = try makeDeck("Real", in: dir)

        #expect(throws: DeckLibrary.RenameProblem.empty) {
            try DeckLibrary.rename(deck, to: "   ")
        }
        #expect(throws: DeckLibrary.RenameProblem.empty) {
            try DeckLibrary.rename(deck, to: "/")
        }
    }

    /// A slash means one deck with a slash in the name, not an error and
    /// certainly not a subdirectory.
    @Test func charactersAFilenameCannotCarryAreStrippedNotRejected() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let deck = try makeDeck("Before", in: dir)

        let renamed = try DeckLibrary.rename(deck, to: "Q3 / Q4 review")

        #expect(renamed.name == "Q3   Q4 review")
        #expect(renamed.url.deletingLastPathComponent().path == dir.path)
    }

    @Test func renamingToTheSameNameIsANoOp() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let deck = try makeDeck("Steady", in: dir)

        let renamed = try DeckLibrary.rename(deck, to: "Steady")

        #expect(renamed == deck)
        #expect(FileManager.default.fileExists(atPath: deck.url.path))
    }
}
