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
    @Test func requestingADeleteSetsThePendingTargetWithoutDeletingAnything() throws {
        let deck = try makeFixtureDeck()
        defer { try? FileManager.default.removeItem(at: deck.url) }

        let pending = DeckDeletionRequest.requesting(deck)

        #expect(pending == deck)
        #expect(FileManager.default.fileExists(atPath: deck.url.path))
    }

    @MainActor
    @Test func confirmingADeleteRemovesTheDeckAndClearsThePendingTarget() throws {
        let deck = try makeFixtureDeck()
        defer { try? FileManager.default.removeItem(at: deck.url) }
        let app = AppState(skipKeychain: true)

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
        let deck = try makeFixtureDeck()
        defer { try? FileManager.default.removeItem(at: deck.url) }
        let app = AppState(skipKeychain: true)

        // "Cancel" clears the pending slot without ever calling `confirming`;
        // this covers the defensive nil case, e.g. a dialog dismissed by
        // some route other than its own buttons.
        let cleared = DeckDeletionRequest.confirming(nil, in: app)

        #expect(cleared == nil)
        #expect(FileManager.default.fileExists(atPath: deck.url.path))
    }

    private func makeFixtureDeck() throws -> DeckFile {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-deletion-\(UUID().uuidString).pptx")
        try Data("not a real deck, just bytes to delete".utf8).write(to: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return DeckFile(url: url,
                         name: url.deletingPathExtension().lastPathComponent,
                         modified: attributes[.modificationDate] as? Date ?? Date(),
                         byteCount: attributes[.size] as? Int ?? 0)
    }
}
