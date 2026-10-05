import Foundation
import Testing
@testable import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryLabPersistenceAppTests {
    private func waitForAutomaticScan(_ app: AppState) async throws {
        let limit = ContinuousClock.now + .seconds(5)
        while app.isRefreshingLibrary && ContinuousClock.now < limit { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!app.isRefreshingLibrary)
    }

    @Test func completedAppRunsPersistListAndReopenAfterNewAppState() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let model = LibraryLabModel()
        let diagnostics = context.libraryDirectory.appendingPathComponent("Diagnostics")
        await context.app.runLibraryDemos([.slides, .fillsAndLines], model: model, in: diagnostics).value
        try await waitForAutomaticScan(context.app)
        #expect(model.completed == 2 && model.failures.isEmpty && model.saveFailures.isEmpty)
        #expect(model.savedDecks.count == 2 && context.app.library.count == 2)
        let originalURLs = Set(model.savedDecks.values.map { $0.resolvingSymlinksInPath() })
        for (id, saved) in model.savedDecks {
            let result = try #require(model.results[id])
            #expect(saved.deletingLastPathComponent() == context.libraryDirectory)
            #expect(saved != result.afterURL)
            #expect(try Data(contentsOf: saved) == Data(contentsOf: result.afterURL))
            #expect(try Presentation(contentsOf: saved).slides.count == result.slideCount)
        }
        #expect(model.results[.fillsAndLines]?.findings.isEmpty == false)
        let fresh = context.makeApp()
        await fresh.start()
        #expect(Set(fresh.library.map { $0.url.resolvingSymlinksInPath() }) == originalURLs)
        let saved = try #require(fresh.library.first?.url)
        await fresh.inspect(deckAt: saved).value
        #expect(fresh.phase == .inspected && fresh.inspection?.fileURL == saved)
        await context.app.runLibraryDemos([.slides], model: model, in: diagnostics).value
        try await waitForAutomaticScan(context.app)
        #expect(context.app.library.count == 3)
        #expect(originalURLs.isSubset(of: Set(context.app.library.map { $0.url.resolvingSymlinksInPath() })))
        for url in originalURLs { #expect(FileManager.default.fileExists(atPath: url.path)) }
    }

    @Test func runAllPersistsEveryCompletedCatalogDeck() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let model = LibraryLabModel(), ids = LibraryLab.catalog.map(\.id)
        await context.app.runLibraryDemos(ids, model: model,
            in: context.libraryDirectory.appendingPathComponent("Diagnostics")).value
        try await waitForAutomaticScan(context.app)
        #expect(model.completed == ids.count && model.failures.isEmpty && model.saveFailures.isEmpty)
        #expect(Set(model.savedDecks.keys) == Set(ids))
        #expect(context.app.library.count == ids.count)
        for id in ids {
            let result = try #require(model.results[id]), saved = try #require(model.savedDecks[id])
            #expect(try Data(contentsOf: saved) == Data(contentsOf: result.afterURL))
        }
    }

    @Test func batchFailuresDoNotPreventOtherResultsFromBeingSaved() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let model = LibraryLabModel()
        await model.run([.slides, .text, .text, .tableStructure], in: parent, savingTo: context.libraryDirectory) { id, options, parent in
            if id == .slides { throw PersistenceFailure.controlled }
            return try LibraryLab.run(id, options: options, in: parent)
        }.value
        #expect(model.completed == 3 && model.total == 3)
        #expect(model.failures.count == 1 && model.results.count == 2)
        #expect(model.saveFailures.isEmpty && model.savedDecks.count == 2)
        #expect(DeckLibrary.decks(in: context.libraryDirectory).count == 2)
    }

    @Test func completedDeckWithFailedChecksIsStillSavedAndKeepsItsFindings() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let original = try LibraryLab.run(.fillsAndLines, in: parent)
        let result = LibraryLabResult(id: original.id, options: original.options, directory: original.directory,
            beforeURL: original.beforeURL, afterURL: original.afterURL, reportURL: original.reportURL,
            markdownURL: original.markdownURL, artifacts: original.artifacts, coverSVG: original.coverSVG,
            coverSlideNumber: original.coverSlideNumber, slideCount: original.slideCount,
            checks: [LibraryLabCheck("Controlled failed file check", false, "The completed deck remains inspectable.")],
            findings: original.findings, elapsedSeconds: original.elapsedSeconds)
        let model = LibraryLabModel()
        await model.run([result.id], in: parent, savingTo: context.libraryDirectory) { _, _, _ in result }.value
        let accepted = try #require(model.results[result.id]), saved = try #require(model.savedDecks[result.id])
        #expect(!accepted.passed && accepted.checks == result.checks)
        #expect(!accepted.findings.isEmpty && accepted.findings == result.findings)
        #expect(model.failures.isEmpty && model.saveFailures.isEmpty)
        #expect(try Data(contentsOf: saved) == Data(contentsOf: result.afterURL))
    }

    @Test func saveFailurePreservesTheCompletedInspectableResult() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let blocked = context.libraryDirectory.appendingPathComponent("not-a-directory")
        try Data("existing user file".utf8).write(to: blocked)
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let model = LibraryLabModel()
        await model.run([.slides], in: parent, savingTo: blocked).value
        let result = try #require(model.results[.slides])
        #expect(model.completed == 1 && model.failures.isEmpty && model.savedDecks.isEmpty)
        #expect(model.saveFailures[.slides]?.isEmpty == false)
        #expect(try String(contentsOf: blocked, encoding: .utf8) == "existing user file")
        await context.app.inspect(deckAt: result.afterURL).value
        #expect(context.app.phase == .inspected)
    }

    @Test(arguments: [false, true])
    func cancellationOrReplacementDuringCopyCannotPublishARetiredDeck(replace: Bool) async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let result = try LibraryLab.run(.slides, in: parent)
        let model = LibraryLabModel(), stage = ControlledDeckPreparation()
        let old = model.run([.slides], in: parent, savingTo: context.libraryDirectory,
                            preparingSave: stage.prepare) { _, _, _ in result }
        await stage.waitUntilPrepared()
        #expect(DeckLibrary.decks(in: context.libraryDirectory).isEmpty)
        if replace {
            await model.run([.text], in: parent, savingTo: context.libraryDirectory).value
        } else { model.cancel() }
        await stage.release()
        await old.value
        #expect(model.savedDecks[.slides] == nil && model.results[.slides] == nil)
        #expect(DeckLibrary.decks(in: context.libraryDirectory).count == (replace ? 1 : 0))
        let files = try FileManager.default.contentsOfDirectory(atPath: context.libraryDirectory.path)
        #expect(!files.contains { $0.hasPrefix(".library-demo-") })
    }

    @Test func retrySavesOriginalBytesRefreshesLibraryAndDoesNotDuplicateSuccessfulSave() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let model = LibraryLabModel()
        await model.run([.slides], in: parent, savingTo: context.libraryDirectory,
                        preparingSave: { _, _ in throw PersistenceFailure.controlled }) { id, options, parent in
            try LibraryLab.run(id, options: options, in: parent)
        }.value
        let result = try #require(model.results[.slides])
        let bytes = try Data(contentsOf: result.afterURL)
        #expect(model.saveFailures[.slides] != nil)
        await context.app.retrySavingLibraryDemo(result, model: model).value
        try await waitForAutomaticScan(context.app)
        let saved = try #require(model.savedDecks[.slides])
        #expect(saved.deletingLastPathComponent() == context.libraryDirectory)
        #expect(try Data(contentsOf: saved) == bytes)
        #expect(try Presentation(contentsOf: saved).slides.count == result.slideCount)
        #expect(context.app.library.map { $0.url.resolvingSymlinksInPath() } == [saved.resolvingSymlinksInPath()])
        #expect(model.results[.slides]?.afterURL == result.afterURL && model.completed == 1)
        #expect(model.saveFailures.isEmpty && model.savingIDs.isEmpty)
        await context.app.retrySavingLibraryDemo(result, model: model).value
        #expect(model.savedDecks[.slides] == saved)
        #expect(DeckLibrary.decks(in: context.libraryDirectory).count == 1)
        #expect(try Data(contentsOf: result.afterURL) == bytes)
        #expect(try Data(contentsOf: saved) == bytes)
    }

    @Test func concurrentRetryClicksShareOneCopyAndCannotOverwriteAnExistingFile() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let model = LibraryLabModel(), stage = ControlledDeckPreparation()
        await model.run([.slides], in: parent, savingTo: context.libraryDirectory,
                        preparingSave: { _, _ in throw PersistenceFailure.controlled }) { id, options, parent in
            try LibraryLab.run(id, options: options, in: parent)
        }.value
        let result = try #require(model.results[.slides])
        let first = model.retrySave(result, to: context.libraryDirectory, preparingSave: stage.prepare)
        await stage.waitUntilPrepared()
        #expect(model.savingIDs == [.slides])
        let second = model.retrySave(result, to: context.libraryDirectory,
                                     preparingSave: { _, _ in
                                         Issue.record("A concurrent click started another copy")
                                         throw PersistenceFailure.controlled
                                     })
        await stage.release(); await first.value; await second.value
        #expect(model.savedDecks.count == 1 && model.saveFailures.isEmpty)
        #expect(DeckLibrary.decks(in: context.libraryDirectory).count == 1)

        // A separate failed result exercises the final non-overwriting rename.
        await model.run([.text], in: parent, savingTo: context.libraryDirectory,
                        preparingSave: { _, _ in throw PersistenceFailure.controlled }) { id, options, parent in
            try LibraryLab.run(id, options: options, in: parent)
        }.value
        let other = try #require(model.results[.text])
        let collision = try DeckStorage.prepareDeckCopy(from: other.afterURL, title: "Existing", into: context.libraryDirectory)
        let existing = Data("existing destination must survive".utf8)
        try existing.write(to: collision.destination)
        await model.retrySave(other, to: context.libraryDirectory, preparingSave: { _, _ in collision }).value
        #expect(try Data(contentsOf: collision.destination) == existing)
        #expect(model.savedDecks[.text] == nil && model.saveFailures[.text] != nil)
        #expect(model.results[.text]?.afterURL == other.afterURL && model.savingIDs.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: context.libraryDirectory.path)
        #expect(!files.contains { $0.hasPrefix(".library-demo-") })
    }

    @Test(arguments: ["cancel-model", "cancel-task", "replace-result"])
    func retiredRetryCannotPublishOrChangeTheCurrentResult(action: String) async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let model = LibraryLabModel(), stage = ControlledDeckPreparation()
        await model.run([.slides], in: parent, savingTo: context.libraryDirectory,
                        preparingSave: { _, _ in throw PersistenceFailure.controlled }) { id, options, parent in
            try LibraryLab.run(id, options: options, in: parent)
        }.value
        let original = try #require(model.results[.slides])
        let retry = model.retrySave(original, to: context.libraryDirectory, preparingSave: stage.prepare)
        await stage.waitUntilPrepared()
        if action == "replace-result" {
            await model.run([.slides], in: parent, savingTo: context.libraryDirectory).value
        } else if action == "cancel-task" { retry.cancel() }
        else { model.cancel() }
        let current = try #require(model.results[.slides])
        await stage.release(); await retry.value
        #expect(model.results[.slides]?.afterURL == current.afterURL)
        #expect(model.savingIDs.isEmpty)
        #expect(DeckLibrary.decks(in: context.libraryDirectory).count == (action == "replace-result" ? 1 : 0))
        if action == "replace-result" {
            #expect(current.afterURL != original.afterURL && model.saveFailures[.slides] == nil)
            let saved = try #require(model.savedDecks[.slides])
            await model.retrySave(original, to: context.libraryDirectory).value
            #expect(model.savedDecks[.slides] == saved)
            #expect(try Data(contentsOf: saved) == Data(contentsOf: current.afterURL))
        } else {
            #expect(model.savedDecks[.slides] == nil && model.saveFailures[.slides] != nil)
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: context.libraryDirectory.path)
        #expect(!files.contains { $0.hasPrefix(".library-demo-") })
    }

    @Test func returnedTaskCancellationDoesNotPersistAnUnacceptedResult() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let result = try LibraryLab.run(.slides, in: parent)
        let model = LibraryLabModel(), stage = ControlledDeckPreparation()
        let task = model.run([.slides], in: parent, savingTo: context.libraryDirectory,
                             preparingSave: stage.prepare) { _, _, _ in result }
        await stage.waitUntilPrepared(); task.cancel(); await stage.release(); await task.value
        #expect(model.savedDecks.isEmpty && model.results.isEmpty && !model.isRunning)
        #expect(DeckLibrary.decks(in: context.libraryDirectory).isEmpty)
    }

    @Test func inspectingFirstCompletedDeckDoesNotCancelRemainingBatchSaves() async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let parent = context.libraryDirectory.appendingPathComponent("Diagnostics")
        let model = LibraryLabModel(), stage = ControlledDeckPreparation()
        let batch = model.run([.slides, .text], in: parent, savingTo: context.libraryDirectory,
                              onSaved: { _ in context.app.refreshLibrary() },
                              preparingSave: { result, library in
                                  if result.id == .text { return try await stage.prepare(result, library) }
                                  return try DeckStorage.prepareDeckCopy(from: result.afterURL, title: "First deck", into: library)
                              }) { id, options, parent in
            try LibraryLab.run(id, options: options, in: parent)
        }
        await stage.waitUntilPrepared()
        let first = try #require(model.savedDecks[.slides])
        #expect(model.completed == 1 && model.isRunning)
        await context.app.inspect(deckAt: first).value
        #expect(context.app.phase == .inspected && context.app.inspection?.fileURL == first)
        #expect(model.completed == 1 && model.isRunning && model.savedDecks[.text] == nil)
        await stage.release(); await batch.value
        try await waitForAutomaticScan(context.app)
        #expect(model.completed == 2 && !model.isRunning)
        #expect(model.savedDecks.count == 2 && model.saveFailures.isEmpty && model.failures.isEmpty)
        #expect(context.app.library.count == 2)
        for id in [LibraryDemoID.slides, .text] {
            let saved = try #require(model.savedDecks[id]), result = try #require(model.results[id])
            #expect(try Data(contentsOf: saved) == Data(contentsOf: result.afterURL))
        }
    }
}

private enum PersistenceFailure: Error { case controlled }

private actor ControlledDeckPreparation {
    private var ready = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<Void, Never>?
    func prepare(_ result: LibraryLabResult, _ library: URL) async throws -> DeckStorage.PreparedDeckCopy {
        let pending = try DeckStorage.prepareDeckCopy(from: result.afterURL, title: "Controlled demo", into: library)
        await withCheckedContinuation { continuation in
            self.continuation = continuation; ready = true
            waiters.forEach { $0.resume() }; waiters.removeAll()
        }
        return pending
    }
    func waitUntilPrepared() async {
        if ready { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() { continuation?.resume(); continuation = nil }
}
