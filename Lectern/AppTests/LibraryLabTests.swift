import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryLabAppTests {
    @Test func filesReachInspectorAndExportWithoutAProvider() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabApp-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        let ids: [LibraryDemoID] = [.tableStructure, .notes, .comments]
        await model.run(ids, in: root).value
        #expect(!model.isRunning && model.failures.isEmpty && model.completed == 3)
        for id in ids {
            let result = try #require(model.results[id])
            #expect(result.passed)
            for url in [result.beforeURL, result.afterURL].compactMap({ $0 }) {
                await context.app.inspect(deckAt: url).value
                #expect(context.app.phase == .inspected)
                #expect(context.app.inspection?.fileURL == url)
                #expect(context.app.inspection?.previews.isEmpty == false)
                context.app.goHome()
            }
            await context.app.inspect(deckAt: result.afterURL).value
            let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export-" + id.rawValue)))
            await task.value
            #expect(context.app.exportProblem == nil)
            #expect(context.app.exportedDirectory != nil)
            context.app.goHome()
        }
        #expect(model.results.count == 3)
    }

    @Test(arguments: [false, true])
    func paragraphDemoReachesInspectorAndExport(narrow: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabParagraph-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(text: "App paragraph demonstration", sampleSize: 6, alternative: narrow)
        await model.run([.paragraphLayout], in: root).value
        let result = try #require(model.results[.paragraphLayout])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.checks.contains { $0.name == "Paragraph positions survive reopening" && $0.passed })
        await context.app.inspect(deckAt: result.afterURL).value
        #expect(context.app.phase == .inspected)
        #expect(context.app.inspection?.previews.count == 2)
        let exportRoot = root.appendingPathComponent("Export")
        let task = try #require(context.app.exportInspected(into: exportRoot))
        await task.value
        #expect(context.app.exportProblem == nil)
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("App paragraph demonstration"))
        #expect(markdown.contains("The last line remains natural."))
        #expect(context.app.exportSummary == "2 slides · 0 media files · 0 chart CSVs")
        let deck = try Presentation(contentsOf: result.afterURL)
        #expect(deck.slides.count == 2)
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        let shape = try #require(deck.slides[0].shapes.all.first { $0.name == "Justified paragraph" })
        #expect(shape.textFrame?.paragraphs.first?.alignment == .justified)
        let tree = try #require(deck.slides[0].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        let node = try #require(tree.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == "Justified paragraph"
        })
        let body = try #require(node.firstChild(named: "p:txBody"))
        let layout = RichTextLayout(textBody: body, width: shape.frame.width.points,
                                    height: shape.frame.height.points, fonts: deck.fonts, theme: deck.theme)
        let metrics = try #require(deck.fonts.metrics(for: "DejaVu Sans"))
        #expect(layout.fits && layout.diagnostics.isEmpty)
        #expect(layout.lines.first?.spans.contains {
            $0.run.text == " " && $0.width > metrics.width(of: " ", pointSize: $0.run.fontSize) + 0.1
        } == true)
        #expect(model.results[.paragraphLayout]?.directory == result.directory)
    }

    @Test func aFailureDoesNotPreventRemainingDemos() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabFailure-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        await model.run([.slides, .tableStructure, .tableStructure], in: root) { id, options, root in
            if id == .slides { throw LabAppError.controlled }
            return try LibraryLab.run(id, options: options, in: root)
        }.value
        #expect(!model.isRunning && model.completed == 2 && model.total == 2)
        #expect(model.failures[.slides] != nil && model.results[.tableStructure]?.passed == true)
    }

    @Test(arguments: [false, true])
    func replacementAndCancellationRejectRetiredCompletion(fails: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabRetired-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try LibraryLab.run(.tableStructure, in: root)
        let model = LibraryLabModel()
        let old = ControlledLab(), live = ControlledLab()
        let oldTask = model.run([.tableStructure], in: root, using: old.run)
        await old.waitUntilStarted()
        let liveTask = model.run([.tableStructure], in: root, using: live.run)
        await live.waitUntilStarted()
        await old.finish(fails ? .failure(LabAppError.controlled) : .success(result))
        await oldTask.value
        #expect(model.isRunning && model.completed == 0 && model.failures.isEmpty && model.results.isEmpty)
        model.cancel()
        await live.finish(.success(result))
        await liveTask.value
        #expect(await live.observedCancellation)
        #expect(!model.isRunning && model.completed == 0 && model.failures.isEmpty && model.results.isEmpty)
    }

    @Test func returnedTaskCancellationRetiresProgress() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabCancel-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try LibraryLab.run(.tableStructure, in: root)
        let model = LibraryLabModel(), worker = ControlledLab()
        let task = model.run([.tableStructure], in: root, using: worker.run)
        await worker.waitUntilStarted()
        task.cancel()
        await worker.finish(.success(result))
        await task.value
        #expect(!model.isRunning && model.activeID == nil && model.results.isEmpty)
    }
}

private enum LabAppError: Error { case controlled }

private actor ControlledLab {
    private var completion: CheckedContinuation<LibraryLabResult, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var started = false
    private(set) var observedCancellation = false

    func run(_ id: LibraryDemoID, _ options: LibraryLabOptions, _ parent: URL) async throws -> LibraryLabResult {
        defer { observedCancellation = Task.isCancelled }
        return try await withCheckedThrowingContinuation { completion in
            self.completion = completion
            started = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func finish(_ result: Result<LibraryLabResult, Error>) {
        completion?.resume(with: result)
        completion = nil
    }
}
