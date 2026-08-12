import Foundation
import Testing
@testable import Lectern

/// L-REL-1: the three `fileImporter`s used to funnel their `Result` through
/// `try? result.get()`, which discarded a real failure exactly like a Cancel —
/// no message, no spinner, nothing. `FileImportOutcome.handle` is the shared
/// decision those closures now use; these exercise the once-silent failure path
/// (it must produce a message) alongside the success path (it must stay quiet
/// and still run the action).
@Suite struct FileImportFailureTests {
    private struct UnreachableFile: LocalizedError {
        var errorDescription: String? { "The file could not be reached." }
    }

    @MainActor
    @Test func aFailureResultDrivesTheErrorStateAndSkipsTheAction() {
        var chosen: URL?
        let message = FileImportOutcome.handle(.failure(UnreachableFile())) { chosen = $0 }

        // The previously-silent path: a message the alert can show, and the
        // success action never runs.
        #expect(message == "The file could not be reached.")
        #expect(chosen == nil)
    }

    @MainActor
    @Test func aSuccessResultRunsTheActionAndLeavesTheErrorStateClear() {
        let url = URL(fileURLWithPath: "/decks/example.pptx")
        var chosen: URL?
        let message = FileImportOutcome.handle(.success(url)) { chosen = $0 }

        // Success is unchanged: no error surfaced, and the URL reaches the
        // action verbatim.
        #expect(message == nil)
        #expect(chosen == url)
    }
}
