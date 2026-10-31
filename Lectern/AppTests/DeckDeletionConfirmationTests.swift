import Foundation
import Testing
import LecternCore
@testable import Lectern

/// The redesigned library's "Delete…" buttons read as a promise — the
/// trailing ellipsis is the HIG's own signal that a confirmation follows —
/// so the two steps behind them must actually behave that way: asking
/// first, deleting only on confirmation.
///
/// `DeckCardView` and `DeckListView` gate their delete with `@State private
/// var pendingDelete`, exactly like `DeckLibrarySheet`'s existing
/// confirmation. `@State` only takes effect once a view is installed in a
/// live SwiftUI hierarchy, which a plain unit test cannot arrange, so the
/// actual decision logic behind both buttons is factored out into
/// `DeckDeletionRequest` (see `LibraryView.swift`) and exercised here
/// directly — the same functions the views' buttons call.
@Suite struct DeckDeletionConfirmationTests {
    @MainActor
    @Test func requestingADeleteSetsThePendingTargetWithoutDeletingAnything() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let deck = try makeFixtureDeck(in: context.libraryDirectory)
        defer { try? FileManager.default.removeItem(at: deck.url) }

        let pending = DeckDeletionRequest.requesting(deck)

        #expect(pending == deck)
        #expect(FileManager.default.fileExists(atPath: deck.url.path))
    }

    @MainActor
    @Test func confirmingADeleteRemovesTheDeckAndClearsThePendingTarget() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let deck = try makeFixtureDeck(in: context.libraryDirectory)
        defer { try? FileManager.default.removeItem(at: deck.url) }
        let app = context.app

        // The two-step sequence a tap on "Delete…" followed by a tap on the
        // confirmation's own "Delete" produces.
        let pending = DeckDeletionRequest.requesting(deck)
        #expect(FileManager.default.fileExists(atPath: deck.url.path))

        let cleared = DeckDeletionRequest.confirming(pending, in: app)

        #expect(cleared == nil)
        #expect(!FileManager.default.fileExists(atPath: deck.url.path))
    }

    @MainActor
    @Test func confirmingWithNoPendingTargetDeletesNothing() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let deck = try makeFixtureDeck(in: context.libraryDirectory)
        defer { try? FileManager.default.removeItem(at: deck.url) }
        let app = context.app

        // "Cancel" clears the pending slot without ever calling `confirming`;
        // this covers the defensive nil case, e.g. a dialog dismissed by
        // some route other than its own buttons.
        let cleared = DeckDeletionRequest.confirming(nil, in: app)

        #expect(cleared == nil)
        #expect(FileManager.default.fileExists(atPath: deck.url.path))
    }

    /// A trash that fails after the user confirmed "Delete" must explain
    /// itself rather than leave the row in place silently, and the next
    /// successful delete clears the stale explanation.
    @MainActor
    @Test func aFailedDeleteSetsDeleteProblemAndASuccessfulOneClearsIt() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app

        // The test context's injected `deletingDeck` refuses any deck outside
        // its owned library directory, which stands in for a trash that fails.
        let outside = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("deck-deletion-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let refused = try makeFixtureDeck(in: outside)

        app.deleteFromLibrary(refused)

        let problem = try #require(app.deleteProblem)
        #expect(!problem.isEmpty)
        #expect(FileManager.default.fileExists(atPath: refused.url.path))

        let deck = try makeFixtureDeck(in: context.libraryDirectory)
        defer { try? FileManager.default.removeItem(at: deck.url) }

        app.deleteFromLibrary(deck)

        #expect(app.deleteProblem == nil)
        #expect(!FileManager.default.fileExists(atPath: deck.url.path))
    }

    private func makeFixtureDeck(in directory: URL) throws -> DeckFile {
        let url = directory
            .appendingPathComponent("deck-deletion-\(UUID().uuidString).pptx")
        try Data("not a real deck, just bytes to delete".utf8).write(to: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return DeckFile(url: url,
                         name: url.deletingPathExtension().lastPathComponent,
                         modified: attributes[.modificationDate] as? Date ?? Date(),
                         byteCount: attributes[.size] as? Int ?? 0)
    }
}
