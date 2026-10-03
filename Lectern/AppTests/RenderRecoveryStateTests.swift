import Foundation
import Testing
import LecternCore
@testable import Lectern

@MainActor @Suite struct RenderRecoveryStateTests {
    @Test func importedSnapshotIsCopiedAndSurvivesSourceRemoval() async throws {
        let name = "RenderRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = RenderSnapshot(deck: DeckIR(meta: Meta(title: "Recovery"), slides: [IRSlide(id: "one", layout: "bullets", title: "Saved")]))
        let original = try snapshot.save(in: directory)
        let app = AppState(skipKeychain: true, defaults: defaults)
        try await app.importRenderSnapshot(original)
        let copied = try #require(app.recoveryURL)
        defer { try? FileManager.default.removeItem(at: copied) }
        #expect(copied != original)
        #expect(app.recoverySourceURL == nil)
        try FileManager.default.removeItem(at: original)
        #expect(try RenderSnapshot.load(copied).deck.meta.title == "Recovery")
        let restarted = AppState(skipKeychain: true, defaults: defaults)
        await restarted.start()
        #expect(restarted.recoveryURL == copied)
        let bad = directory.appendingPathComponent("bad.json")
        try Data("{}".utf8).write(to: bad)
        await #expect(throws: (any Error).self) { try await app.importRenderSnapshot(bad) }
        #expect(app.recoveryURL == copied)
    }
}
