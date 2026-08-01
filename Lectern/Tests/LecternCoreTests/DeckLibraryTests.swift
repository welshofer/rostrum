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
