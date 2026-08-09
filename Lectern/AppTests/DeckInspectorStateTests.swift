import Foundation
import Testing
import LecternCore
@testable import Lectern

@Suite struct DeckInspectorStateTests {
    @MainActor
    @Test func openingADeckReachesTheInspector() async throws {
        let deck = try #require(
            Bundle(for: BundleMarker.self).url(
                forResource: "hello",
                withExtension: "pptx",
                subdirectory: "Fixtures"))
        let app = AppState(skipKeychain: true)

        app.inspectDeck(deck)
        let inspection = try await waitForInspection(in: app)

        #expect(inspection.fileName == "hello.pptx")
        #expect(inspection.slideCount > 0)
        #expect(app.inspectedPreviews.isEmpty)
        await app.loadInspectionPreview(at: 0)
        #expect(app.inspectedPreviews[0]?.contains("<svg") == true)
    }

    @MainActor
    @Test func anInvalidDeckReachesTheInspectionFailureState() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-deck-\(UUID().uuidString).pptx")
        try Data("not a deck".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let app = AppState(skipKeychain: true)

        app.inspectDeck(url)

        for _ in 0..<100 {
            if case .inspectionFailed(let message) = app.phase {
                #expect(message.contains("could not open"))
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("inspection never reached its failure state")
    }

    @MainActor
    private func waitForInspection(in app: AppState) async throws -> DeckInspection {
        for _ in 0..<250 {
            if case .inspected(let inspection) = app.phase { return inspection }
            if case .inspectionFailed(let message) = app.phase {
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
