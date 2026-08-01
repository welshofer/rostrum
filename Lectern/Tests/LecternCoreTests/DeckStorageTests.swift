import Foundation
import Testing
@testable import LecternCore

@Suite struct DeckStorageTests {
    private func tempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("deckstorage-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ name: String, _ contents: String, in dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? Data(contents.utf8).write(to: dir.appendingPathComponent(name))
    }

    private func read(_ name: String, in dir: URL) -> String? {
        (try? Data(contentsOf: dir.appendingPathComponent(name))).map { String(decoding: $0, as: UTF8.self) }
    }

    private func names(in dir: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .map(\.lastPathComponent) ?? [])
    }

    @Test func decksMoveToTheNewHomeAndTheOldFolderGoes() {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("Application Support/Lectern/Decks", isDirectory: true)
        let destination = root.appendingPathComponent("Documents/Lectern", isDirectory: true)
        write("one.pptx", "first", in: legacy)
        write("two.pptx", "second", in: legacy)

        #expect(DeckStorage.migrateDecks(from: legacy, to: destination) == 2)
        #expect(names(in: destination) == ["one.pptx", "two.pptx"])
        #expect(read("one.pptx", in: destination) == "first")
        // Emptied, so it is cleaned up rather than left as a confusing husk.
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    /// The one thing this must never do is lose a deck. A name already at the
    /// destination is the copy in use, so the old one is left where it is
    /// rather than written over.
    @Test func aNameCollisionNeverOverwritesTheDeckAlreadyThere() {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("legacy", isDirectory: true)
        let destination = root.appendingPathComponent("current", isDirectory: true)
        write("deck.pptx", "OLD", in: legacy)
        write("deck.pptx", "CURRENT", in: destination)
        write("other.pptx", "moved", in: legacy)

        #expect(DeckStorage.migrateDecks(from: legacy, to: destination) == 1)
        #expect(read("deck.pptx", in: destination) == "CURRENT", "the deck in use was overwritten")
        #expect(read("other.pptx", in: destination) == "moved")
        // The skipped deck is still on disk, and because something is left the
        // old folder stays too — better a stray file than a deleted one.
        #expect(read("deck.pptx", in: legacy) == "OLD")
        #expect(FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func nothingToMoveIsNotAnError() {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("current", isDirectory: true)

        // No old folder at all — the ordinary case for a new install.
        #expect(DeckStorage.migrateDecks(from: root.appendingPathComponent("absent"), to: destination) == 0)
        // An empty one, and a destination that was never created.
        let empty = root.appendingPathComponent("empty", isDirectory: true)
        try? FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(DeckStorage.migrateDecks(from: empty, to: destination) == 0)
        #expect(!FileManager.default.fileExists(atPath: destination.path),
                "a no-op migration should not create the destination")
    }

    @Test func migratingAFolderOntoItselfDoesNothing() {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent("Decks", isDirectory: true)
        write("deck.pptx", "keep", in: dir)

        // Same path spelled two ways: without the guard this would move each
        // deck onto itself.
        let alias = root.appendingPathComponent("Decks/", isDirectory: true)
        #expect(DeckStorage.migrateDecks(from: dir, to: alias) == 0)
        #expect(read("deck.pptx", in: dir) == "keep")
    }

    /// Documents is for the user's documents. The rejected-draft diagnostic is
    /// the app's — and it holds the model's rendering of the prompt plus
    /// whatever was lifted from an attached PDF — so it stays in Application
    /// Support rather than being carried into someone's Documents folder.
    @Test func onlyDecksMoveAndAppDataStaysBehind() {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("legacy", isDirectory: true)
        let destination = root.appendingPathComponent("Documents/Lectern", isDirectory: true)
        write("real.pptx", "deck", in: legacy)
        write("rejected-draft.json", "{}", in: legacy)
        // PowerPoint's owner file for a deck it has open.
        write("~$real.pptx", "lock", in: legacy)

        #expect(DeckStorage.migrateDecks(from: legacy, to: destination) == 1)
        #expect(names(in: destination) == ["real.pptx"])
        // Left exactly where they were, and the folder survives because it
        // still holds something.
        #expect(read("rejected-draft.json", in: legacy) == "{}")
        #expect(read("~$real.pptx", in: legacy) == "lock")
        #expect(FileManager.default.fileExists(atPath: legacy.path))
    }

    /// A folder holding nothing but app data has no decks to move, so it is
    /// left completely alone — including not creating the destination.
    @Test func aFolderWithNoDecksIsUntouched() {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("legacy", isDirectory: true)
        let destination = root.appendingPathComponent("Documents/Lectern", isDirectory: true)
        write("rejected-draft.json", "{}", in: legacy)

        #expect(DeckStorage.migrateDecks(from: legacy, to: destination) == 0)
        #expect(read("rejected-draft.json", in: legacy) == "{}")
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    // MARK: - Diagnostics retention

    @Test func oldRejectedDraftsArePrunedAndRecentOnesKept() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let now = Date()
        func draft(_ name: String, ageDays: Double) {
            write(name, "{}", in: dir)
            try? FileManager.default.setAttributes(
                [.modificationDate: now.addingTimeInterval(-ageDays * 24 * 3600)],
                ofItemAtPath: dir.appendingPathComponent(name).path)
        }
        draft("rejected-draft-20260701T120000Z.json", ageDays: 30)
        draft("rejected-draft-20260730T120000Z.json", ageDays: 1)

        #expect(DeckStorage.pruneDiagnostics(in: dir, now: now) == 1)
        #expect(names(in: dir) == ["rejected-draft-20260730T120000Z.json"])
    }

    /// It deletes files. Anything it did not write is not its business — a
    /// prune that reaches past its own output is how a retention policy
    /// becomes a data-loss bug.
    @Test func pruningTouchesOnlyOurOwnDrafts() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let ancient = Date().addingTimeInterval(-365 * 24 * 3600)
        for name in ["rejected-draft-old.json", "notes.txt", "deck.pptx", "something.json"] {
            write(name, "x", in: dir)
            try? FileManager.default.setAttributes(
                [.modificationDate: ancient], ofItemAtPath: dir.appendingPathComponent(name).path)
        }
        #expect(DeckStorage.pruneDiagnostics(in: dir) == 1)
        #expect(names(in: dir) == ["notes.txt", "deck.pptx", "something.json"])
    }

    @Test func pruningAMissingDirectoryIsNotAnError() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(DeckStorage.pruneDiagnostics(in: dir.appendingPathComponent("absent")) == 0)
    }

    /// Per-run names, so a second failure does not overwrite the evidence for
    /// the first — and sortable, so the newest is obvious.
    @Test func theTimestampIsSortableAndFilenameSafe() {
        let epoch = Date(timeIntervalSince1970: 0)
        #expect(DeckStorage.timestamp(epoch) == "19700101T000000Z")
        let later = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(DeckStorage.timestamp(later) > DeckStorage.timestamp(epoch))
        for stamp in [DeckStorage.timestamp(epoch), DeckStorage.timestamp(later)] {
            #expect(!stamp.contains(":"), "colons are a nuisance in paths")
            #expect(!stamp.contains("/"))
            #expect(stamp.count == 16)
        }
    }
}
