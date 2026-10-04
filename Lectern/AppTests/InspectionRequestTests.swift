import Foundation
import Testing
import LecternCore
@testable import Lectern

/// Suspend real AppState operations at their completion boundary. The worker
/// deliberately ignores cancellation, as a synchronous final render can do.
@Suite struct InspectionRequestTests {
    @MainActor
    @Test(arguments: [false, true])
    func replacedRequestCannotPublishOrClearTheLiveTask(fails: Bool) async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        let old = ControlledInspection(), live = ControlledInspection()
        let oldTask = app.inspect(deckAt: fixture.old.fileURL, inspecting: old.run)
        await old.waitUntilStarted()
        let liveTask = app.inspect(deckAt: fixture.live.fileURL, inspecting: live.run)
        await live.waitUntilStarted()
        await live.report(.rendering(done: 1, total: 2))
        await old.report(.rendering(done: 99, total: 100))
        #expect(app.inspectDone == 1 && app.inspectTotal == 2)

        await old.finish(with: outcome(fixture.old, fails: fails))
        await oldTask.value
        #expect(app.phase == .inspecting)
        #expect(app.inspection == nil)
        #expect(app.inspectDone == 1 && app.inspectTotal == 2)

        // A stale completion must not clear the replacement's task handle.
        app.cancelInspection()
        await live.finish(with: .success(fixture.live))
        await liveTask.value
        #expect(await live.observedCancellation)
        #expect(app.phase == .home && app.inspection == nil)
    }

    @MainActor
    @Test(arguments: [false, true])
    func replacementFinishesBeforeTheOldRequest(fails: Bool) async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        let old = ControlledInspection(), live = ControlledInspection()
        let oldTask = app.inspect(deckAt: fixture.old.fileURL, inspecting: old.run)
        await old.waitUntilStarted()
        let liveTask = app.inspect(deckAt: fixture.live.fileURL, inspecting: live.run)
        await live.waitUntilStarted()
        await live.finish(with: .success(fixture.live))
        await liveTask.value
        await old.finish(with: outcome(fixture.old, fails: fails))
        await oldTask.value
        await old.report(.rendering(done: 99, total: 100))

        #expect(app.phase == .inspected)
        #expect(app.inspection?.fileURL == fixture.live.fileURL)
        #expect(app.inspection?.previews == fixture.live.previews)
        #expect(app.inspection?.previewSlideNumbers == fixture.live.previewSlideNumbers)
        #expect(app.inspection?.previewDiagnostics == fixture.live.previewDiagnostics)
        #expect(app.inspectStage == "Done")
        #expect(app.inspectDone == fixture.live.slideCount)
        #expect(app.inspectTotal == fixture.live.slideCount)
    }

    @MainActor
    @Test(arguments: [false, true])
    func cancelRejectsLateProgressAndCompletion(fails: Bool) async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        let worker = ControlledInspection()
        let task = app.inspect(deckAt: fixture.old.fileURL, inspecting: worker.run)
        await worker.waitUntilStarted()
        await worker.report(.rendering(done: 1, total: 2))
        app.cancelInspection()
        await worker.report(.rendering(done: 99, total: 100))
        await worker.finish(with: outcome(fixture.old, fails: fails))
        await task.value

        #expect(app.phase == .home && app.inspection == nil)
        #expect(app.inspectDone == 1 && app.inspectTotal == 2)
        #expect(await worker.observedCancellation)
    }

    @MainActor
    @Test(arguments: [false, true])
    func terminalPublicationRejectsQueuedProgress(fails: Bool) async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        let worker = ControlledInspection()
        let task = app.inspect(deckAt: fixture.live.fileURL, inspecting: worker.run)
        await worker.waitUntilStarted()
        await worker.report(.rendering(done: 1, total: 2))
        await worker.finish(with: outcome(fixture.live, fails: fails))
        await task.value
        let stage = app.inspectStage, done = app.inspectDone, total = app.inspectTotal
        await worker.report(.rendering(done: 99, total: 100))
        await worker.report(.finished)

        #expect(app.inspectStage == stage && app.inspectDone == done && app.inspectTotal == total)
        if fails {
            #expect(app.phase == .failed("Couldn't open that deck: controlledFailure"))
            #expect(app.inspection == nil)
        } else {
            #expect(app.phase == .inspected)
            #expect(app.inspection?.fileURL == fixture.live.fileURL)
            #expect(stage == "Done" && done == fixture.live.slideCount && total == done)
        }
    }

    @MainActor
    @Test(arguments: [false, true])
    func leavingInspectionInvalidatesItsRequest(create: Bool) async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        let worker = ControlledInspection()
        let task = app.inspect(deckAt: fixture.old.fileURL, inspecting: worker.run)
        await worker.waitUntilStarted()
        if create { app.startCreate() } else { app.goHome() }
        await worker.report(.rendering(done: 99, total: 100))
        await worker.finish(with: .success(fixture.old))
        await task.value

        #expect(app.phase == (create ? .compose : .home))
        #expect(app.inspection == nil)
        #expect(app.inspectDone == 0 && app.inspectTotal == 0)
        #expect(await worker.observedCancellation)
    }

    @MainActor
    @Test(arguments: [DirectCompletion.success, .failure, .cancellation])
    func directTaskCancellationRejectsAllPublications(completion: DirectCompletion) async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        let worker = ControlledInspection()
        let task = app.inspect(deckAt: fixture.old.fileURL, inspecting: worker.run)
        await worker.waitUntilStarted()
        await worker.report(.rendering(done: 1, total: 2))
        task.cancel()
        await worker.report(.rendering(done: 99, total: 100))
        #expect(app.inspectDone == 1 && app.inspectTotal == 2)
        let result: Result<DeckInspection, Error>
        switch completion {
        case .success: result = .success(fixture.old)
        case .failure: result = .failure(ControlledError.controlledFailure)
        case .cancellation: result = .failure(CancellationError())
        }
        await worker.finish(with: result)
        await task.value
        await worker.report(.finished)

        #expect(app.phase == .home && app.inspection == nil)
        #expect(app.inspectStage == "Rendering slide previews")
        #expect(app.inspectDone == 1 && app.inspectTotal == 2)
        #expect(await worker.observedCancellation)
    }

    @MainActor
    @Test func operationCancellationRetiresTheCurrentRequest() async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        let worker = ControlledInspection()
        let task = app.inspect(deckAt: fixture.old.fileURL, inspecting: worker.run)
        await worker.waitUntilStarted()
        await worker.finish(with: .failure(CancellationError()))
        await task.value
        await worker.report(.rendering(done: 99, total: 100))
        #expect(app.phase == .home && app.inspection == nil)
        #expect(app.inspectDone == 0 && app.inspectTotal == 0)
    }

    @MainActor
    @Test func defaultOperationStillInspectsTheDeck() async throws {
        let fixture = try InspectionFixture()
        defer { fixture.remove() }
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        await app.inspect(deckAt: fixture.live.fileURL).value
        #expect(app.phase == .inspected)
        #expect(app.inspection?.fileURL == fixture.live.fileURL)
        #expect(app.inspection?.previews == fixture.live.previews)
        #expect(app.inspection?.previewDiagnostics == fixture.live.previewDiagnostics)
        #expect(app.inspectStage == "Done")
    }

    private func outcome(_ result: DeckInspection, fails: Bool) -> Result<DeckInspection, Error> {
        fails ? .failure(ControlledError.controlledFailure) : .success(result)
    }

    enum DirectCompletion: Sendable { case success, failure, cancellation }
}

private enum ControlledError: Error { case controlledFailure }

private actor ControlledInspection {
    private var completion: CheckedContinuation<DeckInspection, Error>?
    private var started: [CheckedContinuation<Void, Never>] = []
    private var progress: (@Sendable (DeckInspector.Event) async -> Void)?
    private(set) var observedCancellation = false

    func run(
        _ url: URL,
        _ progress: @escaping @Sendable (DeckInspector.Event) async -> Void
    ) async throws -> DeckInspection {
        self.progress = progress
        defer { observedCancellation = Task.isCancelled }
        return try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            for waiter in started { waiter.resume() }
            started.removeAll()
        }
    }

    func waitUntilStarted() async {
        if progress != nil { return }
        await withCheckedContinuation { started.append($0) }
    }

    func report(_ event: DeckInspector.Event) async { await progress?(event) }

    func finish(with result: Result<DeckInspection, Error>) {
        precondition(completion != nil)
        completion?.resume(with: result)
        completion = nil
    }
}

private struct InspectionFixture {
    let directory: URL
    let old: DeckInspection
    let live: DeckInspection

    init() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: InspectionBundleMarker.self)
        #endif
        let source = try #require(bundle.url(forResource: "hello", withExtension: "pptx", subdirectory: "Fixtures"))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Lectern-inspection-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let oldURL = directory.appendingPathComponent("old.pptx")
            let liveURL = directory.appendingPathComponent("live.pptx")
            try FileManager.default.copyItem(at: source, to: oldURL)
            try FileManager.default.copyItem(at: source, to: liveURL)
            old = try DeckInspector.inspect(deckAt: oldURL)
            live = try DeckInspector.inspect(deckAt: liveURL)
            self.directory = directory
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
}

private final class InspectionBundleMarker {}
