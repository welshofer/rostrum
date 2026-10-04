import Foundation
import Testing
import LecternCore
@testable import Lectern

@Suite @MainActor struct NotesPagePreviewTests {
    @Test(arguments: [false, true])
    func replacementRejectsOldSuccessAndFailure(fails: Bool) async throws {
        let result = try notesPreviewFixture()
        let request = NotesPagePreviewRequest(fileURL: result.fileURL, slideNumber: 1)
        let model = NotesPagePreviewModel()
        let old = ControlledNotesPreview(), live = ControlledNotesPreview()
        let oldTask = model.load(request, using: old.run)
        await old.waitUntilStarted()
        let liveTask = model.load(request, using: live.run)
        await live.waitUntilStarted()
        await old.finish(fails ? .failure(NotesPreviewTestError.controlled) : .success(result))
        await oldTask.value
        #expect(model.isLoading && model.preview == nil && model.problem == nil)
        model.cancel()
        await live.finish(.success(result))
        await liveTask.value
        #expect(await live.observedCancellation)
        #expect(!model.isLoading && model.preview == nil && model.problem == nil)
    }

    @Test func lateOldFailureCannotReplaceNewPreview() async throws {
        let result = try notesPreviewFixture()
        let request = NotesPagePreviewRequest(fileURL: result.fileURL, slideNumber: 1)
        let model = NotesPagePreviewModel()
        let old = ControlledNotesPreview(), live = ControlledNotesPreview()
        let oldTask = model.load(request, using: old.run)
        await old.waitUntilStarted()
        let liveTask = model.load(request, using: live.run)
        await live.waitUntilStarted()
        await live.finish(.success(result))
        await liveTask.value
        await old.finish(.failure(NotesPreviewTestError.controlled))
        await oldTask.value
        #expect(!model.isLoading && model.problem == nil)
        #expect(model.preview?.svg == result.svg)
    }

    @Test(arguments: [false, true])
    func directTaskCancellationRejectsUncooperativeCompletion(fails: Bool) async throws {
        let result = try notesPreviewFixture()
        let model = NotesPagePreviewModel()
        let worker = ControlledNotesPreview()
        let task = model.load(.init(fileURL: result.fileURL, slideNumber: 1), using: worker.run)
        await worker.waitUntilStarted()
        task.cancel()
        await worker.finish(fails ? .failure(NotesPreviewTestError.controlled) : .success(result))
        await task.value
        #expect(!model.isLoading && model.preview == nil && model.problem == nil)
    }

    @Test func fileBackedLoadRecoversAfterFailureAndClearsOnDismiss() async throws {
        let expected = try notesPreviewFixture()
        let model = NotesPagePreviewModel()
        await model.load(.init(fileURL: expected.fileURL, slideNumber: 999)).value
        #expect(!model.isLoading && model.preview == nil && model.problem != nil)
        await model.load(.init(fileURL: expected.fileURL, slideNumber: 1)).value
        #expect(!model.isLoading && model.problem == nil)
        #expect(model.preview?.svg == expected.svg)
        #expect(model.preview?.diagnostics == expected.diagnostics)
        model.cancel()
        #expect(model.preview == nil && model.problem == nil)
    }
}

func notesPreviewFixture() throws -> NotesPageInspection {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: NotesPreviewBundleMarker.self)
    #endif
    let url = try #require(bundle.url(forResource: "notes-geometry", withExtension: "pptx", subdirectory: "Fixtures"))
    return try DeckInspector.inspectNotesPage(deckAt: url, slideNumber: 1)
}

private final class NotesPreviewBundleMarker {}
private enum NotesPreviewTestError: Error { case controlled }

private actor ControlledNotesPreview {
    private var completion: CheckedContinuation<NotesPageInspection, Error>?
    private var started: [CheckedContinuation<Void, Never>] = []
    private var hasStarted = false
    private(set) var observedCancellation = false

    func run(_ request: NotesPagePreviewRequest) async throws -> NotesPageInspection {
        defer { observedCancellation = Task.isCancelled }
        return try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            hasStarted = true
            for waiter in started { waiter.resume() }
            started.removeAll()
        }
    }

    func waitUntilStarted() async {
        if hasStarted { return }
        await withCheckedContinuation { started.append($0) }
    }

    func finish(_ result: Result<NotesPageInspection, Error>) {
        precondition(completion != nil)
        completion?.resume(with: result)
        completion = nil
    }
}
