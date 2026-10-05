import Foundation
import Testing
import LecternCore
@testable import Lectern

@MainActor @Suite struct RenderRecoveryStateTests {
    @Test func importedSnapshotIsCopiedAndSurvivesSourceRemoval() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let directory = context.libraryDirectory.appendingPathComponent("Imported", isDirectory: true)
        let snapshot = RenderSnapshot(deck: DeckIR(meta: Meta(title: "Recovery"), slides: [IRSlide(id: "one", layout: "bullets", title: "Saved")]))
        let original = try snapshot.save(in: directory)
        let app = context.app
        try await app.importRenderSnapshot(original)
        let copied = try #require(app.recoveryURL)
        #expect(copied != original)
        #expect(copied.deletingLastPathComponent().standardizedFileURL == context.libraryDirectory.appendingPathComponent("Diagnostics", isDirectory: true).standardizedFileURL)
        #expect(app.recoverySourceURL == nil)
        try FileManager.default.removeItem(at: original)
        #expect(try RenderSnapshot.load(copied).deck.meta.title == "Recovery")
        let restarted = context.makeApp()
        await restarted.start()
        #expect(restarted.recoveryURL == copied)
        let bad = directory.appendingPathComponent("bad.json")
        try Data("{}".utf8).write(to: bad)
        await #expect(throws: (any Error).self) { try await app.importRenderSnapshot(bad) }
        #expect(app.recoveryURL == copied)
        #expect(try RenderSnapshot.load(copied).deck.meta.title == "Recovery")
    }
}
