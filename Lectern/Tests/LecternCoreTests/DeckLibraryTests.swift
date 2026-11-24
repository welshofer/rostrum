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

    @Test func caseOnlyRenameSucceedsOnCaseInsensitiveVolume() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let deck = try makeDeck("q3 review", in: dir)
        let fm = CaseInsensitiveFileManager()

        let renamed = try DeckLibrary.rename(deck, to: "Q3 Review", fileManager: fm)

        #expect(renamed.name == "Q3 Review")
        #expect(renamed.url.lastPathComponent == "Q3 Review.pptx")
        #expect(FileManager.default.fileExists(atPath: renamed.url.path))
        #expect(try Data(contentsOf: renamed.url) == Data("deck".utf8))
    }

    @Test func caseOnlyRenameFallsBackWhenDirectMoveRejectsSameTarget() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let deck = try makeDeck("q3 review", in: dir)
        let fm = CaseInsensitiveFileManager(rejectDirectCaseOnlyMove: true)

        let renamed = try DeckLibrary.rename(deck, to: "Q3 Review", fileManager: fm)

        #expect(renamed.name == "Q3 Review")
        #expect(renamed.url.lastPathComponent == "Q3 Review.pptx")
        #expect(try Data(contentsOf: renamed.url) == Data("deck".utf8))
    }

    @Test func caseInsensitiveCollisionWithDistinctDeckStillThrowsNameTaken() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let existing = try makeDeck("keep me", in: dir)
        let other = try makeDeck("rename me", in: dir)
        let fm = CaseInsensitiveFileManager()

        #expect(throws: DeckLibrary.RenameProblem.nameTaken("Keep Me")) {
            try DeckLibrary.rename(other, to: "Keep Me", fileManager: fm)
        }
        #expect(FileManager.default.fileExists(atPath: existing.url.path))
        #expect(FileManager.default.fileExists(atPath: other.url.path))
    }

    @Test func distinctCaseVariantFilesOnCaseSensitiveVolumeStillThrowNameTaken() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let lower = try makeDeck("q3 review", in: dir)
        let upperURL = dir.appendingPathComponent("Q3 Review.pptx")
        try Data("other".utf8).write(to: upperURL)

        let lowerData = try Data(contentsOf: lower.url)
        let upperData = try Data(contentsOf: upperURL)
        guard lowerData != upperData else { return } // Case-insensitive host volume overwrote the same file.

        #expect(throws: DeckLibrary.RenameProblem.nameTaken("Q3 Review")) {
            try DeckLibrary.rename(lower, to: "Q3 Review")
        }
        #expect(try Data(contentsOf: lower.url) == Data("deck".utf8))
        #expect(try Data(contentsOf: upperURL) == Data("other".utf8))
    }
}

/// Simulates a case-insensitive, case-preserving volume (like default macOS APFS)
/// on case-sensitive Linux CI filesystems.
private final class CaseInsensitiveFileManager: FileManager {
    private let rejectDirectCaseOnlyMove: Bool

    init(rejectDirectCaseOnlyMove: Bool = false) {
        self.rejectDirectCaseOnlyMove = rejectDirectCaseOnlyMove
        super.init()
    }

    private func resolve(_ path: String) -> String? {
        if super.fileExists(atPath: path) { return path }
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent()
        let target = url.lastPathComponent
        guard let entries = try? super.contentsOfDirectory(atPath: parent.path),
              let match = entries.first(where: { $0.caseInsensitiveCompare(target) == .orderedSame }) else {
            return nil
        }
        return parent.appendingPathComponent(match).path
    }

    override func fileExists(atPath path: String) -> Bool {
        resolve(path) != nil
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try super.attributesOfItem(atPath: resolve(path) ?? path)
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if rejectDirectCaseOnlyMove,
           srcURL.deletingLastPathComponent().standardizedFileURL == dstURL.deletingLastPathComponent().standardizedFileURL,
           srcURL.lastPathComponent.caseInsensitiveCompare(dstURL.lastPathComponent) == .orderedSame,
           srcURL.lastPathComponent != dstURL.lastPathComponent {
            throw CocoaError(.fileWriteFileExists)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
