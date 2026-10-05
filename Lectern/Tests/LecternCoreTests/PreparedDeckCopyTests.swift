import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PreparedDeckCopyTests {
    private func fixture() throws -> (root: URL, source: URL, library: URL, bytes: Data) {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("PreparedDeck-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bytes = try Presentation().serializedData(), source = root.appendingPathComponent("original.pptx")
        try bytes.write(to: source)
        return (root, source, root.appendingPathComponent("Library"), bytes)
    }
    @Test func preparedCopyIsHiddenThenListedAndReopensWithExactBytes() throws {
        let f = try fixture(); defer { try? FileManager.default.removeItem(at: f.root) }
        let copy = try DeckStorage.prepareDeckCopy(from: f.source, title: "Cell appearance", into: f.library,
                                                   now: Date(timeIntervalSince1970: 0))
        defer { copy.discard() }
        #expect(DeckLibrary.decks(in: f.library).isEmpty)
        let saved = try copy.commit()
        #expect(saved.lastPathComponent.hasPrefix("Cell appearance-19700101T000000Z-"))
        #expect(DeckLibrary.decks(in: f.library).map { $0.url.resolvingSymlinksInPath() } == [saved.resolvingSymlinksInPath()])
        #expect(try Data(contentsOf: saved) == f.bytes)
        #expect(throws: (any Error).self) { try copy.commit() }
        #expect(DeckLibrary.decks(in: f.library).count == 1)
        #expect(try Data(contentsOf: f.source) == f.bytes)
        #expect(try Presentation(contentsOf: saved).serializedData() == f.bytes)
    }
    @Test func repeatedRunsAndEvenForcedDestinationCollisionNeverReplaceExistingDecks() throws {
        let f = try fixture(); defer { try? FileManager.default.removeItem(at: f.root) }
        let date = Date(timeIntervalSince1970: 0), id = UUID()
        let first = try DeckStorage.prepareDeckCopy(from: f.source, title: "Same demo", into: f.library, now: date, identifier: id)
        let saved = try first.commit()
        let userEdited = Data("existing user edit".utf8)
        try userEdited.write(to: saved)
        let collision = try DeckStorage.prepareDeckCopy(from: f.source, title: "Same demo", into: f.library, now: date, identifier: id)
        defer { collision.discard() }
        #expect(throws: (any Error).self) { try collision.commit() }
        #expect(try Data(contentsOf: saved) == userEdited)
        let next = try DeckStorage.prepareDeckCopy(from: f.source, title: "Same demo", into: f.library, now: date)
        let nextURL = try next.commit()
        #expect(saved != nextURL && DeckLibrary.decks(in: f.library).count == 2)
        #expect(try Data(contentsOf: nextURL) == f.bytes)
    }
    @Test func discardAndCopyFailureLeaveNoListedOrTemporaryDecks() throws {
        let f = try fixture(); defer { try? FileManager.default.removeItem(at: f.root) }
        let prepared = try DeckStorage.prepareDeckCopy(from: f.source, title: "Cancelled", into: f.library)
        prepared.discard()
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.library.path).isEmpty)
        #expect(throws: (any Error).self) {
            try DeckStorage.prepareDeckCopy(from: f.root.appendingPathComponent("missing.pptx"), title: "Missing", into: f.library)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.library.path).isEmpty)
        #expect(try Data(contentsOf: f.source) == f.bytes)
    }
    @Test func unsafeAndLongTitlesStayInsideTheLibraryAndVisible() throws {
        let f = try fixture(); defer { try? FileManager.default.removeItem(at: f.root) }
        for title in ["../folder:bad\\name", String(repeating: "🎨", count: 150), "..."] {
            let pending = try DeckStorage.prepareDeckCopy(from: f.source, title: title, into: f.library)
            let url = try pending.commit()
            #expect(url.deletingLastPathComponent().standardizedFileURL == f.library.standardizedFileURL)
            #expect(!url.lastPathComponent.hasPrefix(".") && url.lastPathComponent.utf8.count < 255)
            #expect(try Data(contentsOf: url) == f.bytes)
        }
        #expect(DeckLibrary.decks(in: f.library).count == 3)
    }
}
