import Foundation
import Testing
import LecternCore
@testable import Lectern

/// The app-level half of inspection: that picking a deck actually lands on the
/// inspector with a populated model, and that a file which is not a deck fails
/// visibly instead of leaving the window on the progress screen.
@Suite struct DeckInspectorStateTests {
    @MainActor
    @Test func openingADeckReachesTheInspector() async throws {
        let deck = try #require(
            Bundle(for: BundleMarker.self).url(
                forResource: "hello",
                withExtension: "pptx",
                subdirectory: "Fixtures"))
        let app = AppState(skipKeychain: true)

        app.inspect(deckAt: deck)
        let inspection = try await waitForInspection(in: app)

        #expect(inspection.fileName == "hello.pptx")
        #expect(inspection.slideCount > 0)
        // Previews are rendered as part of the inspection now, rather than
        // being faulted in one slide at a time.
        #expect(inspection.previews.count == inspection.slideCount)
        #expect(inspection.previews.allSatisfy { $0.contains("<svg") })
        // The deeper reading came along with it.
        #expect(!inspection.documentKind.isEmpty)
        #expect(!inspection.masters.isEmpty)
    }

    @MainActor
    @Test func anInvalidDeckReachesTheInspectionFailureState() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-deck-\(UUID().uuidString).pptx")
        try Data("not a deck".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let app = AppState(skipKeychain: true)

        app.inspect(deckAt: url)

        for _ in 0..<250 {
            if case .failed(let message) = app.phase {
                #expect(message.contains("Couldn't open that deck"))
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("inspection never reached its failure state")
    }

    @MainActor
    private func waitForInspection(in app: AppState) async throws -> DeckInspection {
        for _ in 0..<250 {
            if app.phase == .inspected, let inspection = app.inspection { return inspection }
            if case .failed(let message) = app.phase {
                Issue.record("inspection failed: \(message)")
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw TestError.timedOut
    }

    private enum TestError: Error { case timedOut }
}

private final class BundleMarker {}
