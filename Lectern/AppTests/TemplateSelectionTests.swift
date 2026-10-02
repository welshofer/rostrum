import Foundation
import Testing
import Rostrum
import LecternCore
@testable import Lectern

@Suite @MainActor struct TemplateSelectionTests {
    @Test(arguments: ["potx", "pptx"])
    func importedFileIsAnOwnedSnapshotUsedByRendering(fileExtension: String) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let file = context.libraryDirectory.appendingPathComponent("Brand.\(fileExtension)")
        let original = try templateBytes(isTemplate: fileExtension == "potx")
        try original.write(to: file)

        let selection = context.app.templateSelection
        await selection.select(file).value
        let template = try #require(selection.selected)
        #expect(!selection.isLoading && selection.problem == nil)
        #expect(template.name == file.lastPathComponent)
        #expect(template.slideCount == 2 && template.layoutCount > 0)
        #expect(template.widthInches == 10 && template.heightInches == 7.5)
        #expect(try Data(contentsOf: file) == original)

        // The file provider may remove its download or the owner may edit the
        // source after import. Generation must use the validated selection.
        try Data("Changed after selection".utf8).write(to: file)
        try FileManager.default.removeItem(at: file)
        let deck = DeckIR(meta: Meta(title: "From selected template"), slides: [
            IRSlide(id: "new", layout: "title", title: "New content"),
        ])
        let result = try await DeckRenderer().render(deck, designURL: nil, notesEnabled: false,
            template: template, into: context.libraryDirectory)
        let reopened = try Presentation(contentsOf: result.url)
        #expect(reopened.documentKind == .presentation)
        #expect(reopened.slides.count == 1)
        #expect(reopened.slideSize.width == .inches(10))
        #expect(reopened.slideSize.height == .inches(7.5))
        #expect(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func malformedReplacementKeepsPreviousSelectionAndReportsAnError() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let file = context.libraryDirectory.appendingPathComponent("Brand.potx")
        let original = try templateBytes()
        try original.write(to: file)
        let model = context.app.templateSelection
        await model.select(file).value
        #expect(model.selected?.name == "Brand.potx")

        let malformed = context.libraryDirectory.appendingPathComponent("Damaged.potx")
        let invalidBytes = Data("This is not an Office package".utf8)
        try invalidBytes.write(to: malformed)
        await model.select(malformed).value
        #expect(!model.isLoading && model.problem?.isEmpty == false)
        #expect(model.selected?.name == "Brand.potx")
        #expect(try Data(contentsOf: file) == original)
        #expect(try Data(contentsOf: malformed) == invalidBytes)

        // A successful retry also dismisses the old, now irrelevant error.
        await model.select(file).value
        #expect(!model.isLoading && model.problem == nil)
        #expect(model.selected?.name == "Brand.potx")
    }

    @Test(arguments: [false, true])
    func replacementRejectsRetiredCompletionAndFailure(fails: Bool) async throws {
        let model = TemplateSelectionModel()
        let initial = try snapshot(named: "Initial.potx")
        let replacement = try snapshot(named: "Replacement.potx")
        await model.select(sourceURL, loading: { _ in initial }).value
        let retired = ControlledTemplateLoad(), live = ControlledTemplateLoad()
        let oldTask = model.select(sourceURL, loading: retired.load)
        await retired.waitUntilStarted()
        let newTask = model.select(sourceURL, loading: live.load)
        await live.waitUntilStarted()

        await retired.finish(fails ? .failure(TemplateTestError.controlled) : .success(initial))
        await oldTask.value
        #expect(await retired.observedCancellation)
        #expect(model.isLoading && model.problem == nil)
        #expect(model.selected?.name == initial.name)

        await live.finish(.success(replacement))
        await newTask.value
        #expect(!model.isLoading && model.problem == nil)
        #expect(model.selected?.name == replacement.name)
    }

    @Test(arguments: [false, true])
    func clearCancelsImportAndRejectsRetiredResults(fails: Bool) async throws {
        let model = TemplateSelectionModel()
        let template = try snapshot(named: "Initial.potx")
        await model.select(sourceURL, loading: { _ in template }).value
        let worker = ControlledTemplateLoad()
        let task = model.select(sourceURL, loading: worker.load)
        await worker.waitUntilStarted()

        model.clear()
        #expect(model.selected == nil && !model.isLoading && model.problem == nil)
        await worker.finish(fails ? .failure(TemplateTestError.controlled) : .success(template))
        await task.value
        #expect(await worker.observedCancellation)
        #expect(model.selected == nil && !model.isLoading && model.problem == nil)
    }

    @Test func cancelImportKeepsTheExistingSelection() async throws {
        let model = TemplateSelectionModel()
        let initial = try snapshot(named: "Initial.potx")
        let replacement = try snapshot(named: "Replacement.potx")
        await model.select(sourceURL, loading: { _ in initial }).value
        let worker = ControlledTemplateLoad()
        let task = model.select(sourceURL, loading: worker.load)
        await worker.waitUntilStarted()

        model.cancelImport()
        #expect(model.selected?.name == initial.name && !model.isLoading && model.problem == nil)
        await worker.finish(.success(replacement))
        await task.value
        #expect(await worker.observedCancellation)
        #expect(model.selected?.name == initial.name && !model.isLoading && model.problem == nil)
    }

    @Test(arguments: [false, true])
    func returnedTaskCancellationEndsLoadingWithoutReplacingTheSelection(fails: Bool) async throws {
        let model = TemplateSelectionModel()
        let initial = try snapshot(named: "Initial.potx")
        let replacement = try snapshot(named: "Replacement.potx")
        await model.select(sourceURL, loading: { _ in initial }).value
        let worker = ControlledTemplateLoad()
        let task = model.select(sourceURL, loading: worker.load)
        await worker.waitUntilStarted()

        task.cancel()
        await worker.finish(fails ? .failure(TemplateTestError.controlled) : .success(replacement))
        await task.value
        #expect(await worker.observedCancellation)
        #expect(model.selected?.name == initial.name && !model.isLoading && model.problem == nil)
    }

    @Test func pendingTemplatePreventsDirectGenerationBeforeKeyValidation() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        app.startCreate()
        app.prompt = "Explain the quarterly results"
        let worker = ControlledTemplateLoad()
        let task = app.templateSelection.select(sourceURL, loading: worker.load)
        await worker.waitUntilStarted()

        #expect(!app.canGenerate)
        app.generate()
        #expect(app.phase == .compose && app.lastFailure == nil)
        #expect(app.stage.isEmpty && app.drafted == 0 && app.total == 0)

        app.templateSelection.cancelImport()
        await worker.finish(.failure(TemplateTestError.controlled))
        await task.value
        // With the import finished, the same action reaches the normal missing
        // key check. No provider credentials or network call enter this test.
        app.generate()
        #expect(app.lastFailure == .noKey)
        if case .failed = app.phase {} else { Issue.record("Missing key should report a generation failure") }
    }

    private var sourceURL: URL { URL(fileURLWithPath: "/owned-test-template.potx") }

    private func snapshot(named name: String) throws -> DeckTemplate {
        try DeckTemplate(data: templateBytes(), name: name)
    }

    private func templateBytes(isTemplate: Bool = true) throws -> Data {
        let deck = try Presentation()
        deck.documentKind = isTemplate ? .template : .presentation
        deck.slideSize = (.inches(10), .inches(7.5))
        _ = try deck.slides.add()
        return try deck.serializedData()
    }
}

private enum TemplateTestError: LocalizedError {
    case controlled
    var errorDescription: String? { "The template could not be imported." }
}

private actor ControlledTemplateLoad {
    private var completion: CheckedContinuation<DeckTemplate, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var started = false
    private(set) var observedCancellation = false

    func load(_ url: URL) async throws -> DeckTemplate {
        defer { observedCancellation = Task.isCancelled }
        return try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            started = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func finish(_ result: Result<DeckTemplate, Error>) {
        completion?.resume(with: result)
        completion = nil
    }
}
