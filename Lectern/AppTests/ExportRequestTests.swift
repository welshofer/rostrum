import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@MainActor
@Suite struct ExportRequestTests {
    @Test func actualInspectionAndExportPublishAnOwnedMarkdownDirectory() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let source = try fixture(in: context, name: "owned")
        let app = context.app
        await app.inspect(deckAt: source).value
        #expect(app.phase == .inspected)
        let output = context.libraryDirectory.appendingPathComponent("Export", isDirectory: true)
        let work = try #require(app.exportInspected(into: output))
        await work.value
        #expect(!app.isExporting && app.exportProblem == nil)
        let directory = try #require(app.exportedDirectory)
        #expect(directory.standardizedFileURL == output.appendingPathComponent("owned", isDirectory: true).standardizedFileURL)
        #expect(app.exportSummary?.contains("slide") == true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdown = try #require(files.first { $0.pathExtension == "md" })
        #expect(!(try String(contentsOf: markdown, encoding: .utf8)).isEmpty)
    }

    @Test(arguments: [false, true], [false, true])
    func staleExportCannotOverwriteAReplacementOrClearItsHandle(fails: Bool, replacesInspection: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let oldSource = try fixture(in: context, name: "old")
        let newSource = try fixture(in: context, name: "new")
        let app = context.app
        await app.inspect(deckAt: oldSource).value
        let oldGate = StartupSignal(), liveGate = StartupSignal()
        let oldParent = context.libraryDirectory.appendingPathComponent("OldExport")
        let old = try #require(app.exportInspected(into: oldParent) { deck, parent in
            await oldGate.run()
            if fails { throw ExportFailure.controlled }
            return try DeckExporter.export(deckAt: deck, into: parent)
        })
        await oldGate.waitUntilStarted()
        if replacesInspection { await app.inspect(deckAt: newSource).value }
        else { app.clearExportReport() }
        let liveParent = context.libraryDirectory.appendingPathComponent("LiveExport")
        let live = try #require(app.exportInspected(into: liveParent) { deck, parent in
            await liveGate.run()
            return try DeckExporter.export(deckAt: deck, into: parent)
        })
        await oldGate.finish()
        await old.value
        await liveGate.waitUntilStarted()
        #expect(app.isExporting && app.exportedDirectory == nil && app.exportProblem == nil)
        #expect(app.inspection?.fileURL == (replacesInspection ? newSource : oldSource))
        await liveGate.finish()
        await live.value
        #expect(!app.isExporting && app.exportProblem == nil)
        #expect(app.exportedDirectory?.deletingLastPathComponent().standardizedFileURL == liveParent.standardizedFileURL)
    }

    @Test func replacementExportWaitsForOldWritesIntoTheSameFolder() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        func source(_ folder: String, note: String) throws -> URL {
            let directory = context.libraryDirectory.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let deck = try Presentation()
            try deck.slides[0].setNotes(note)
            let url = directory.appendingPathComponent("deck.pptx")
            try deck.serializedData().write(to: url)
            return url
        }
        let oldSource = try source("Old", note: "OLD EXPORT PAYLOAD")
        let liveSource = try source("Live", note: "LIVE EXPORT PAYLOAD")
        let output = context.libraryDirectory.appendingPathComponent("SameOutput")
        let app = context.app
        let oldGate = StartupSignal(), liveGate = StartupSignal(), order = ExportWriteOrder()
        await app.inspect(deckAt: oldSource).value
        let old = try #require(app.exportInspected(into: output) { deck, parent in
            await order.beginOld()
            await oldGate.run() // Intentionally ignores cancellation, like synchronous export.
            // Model an I/O job already past its cancellation checkpoint. The
            // detached worker intentionally completes even after UI cancellation.
            let result = try await Task.detached {
                try DeckExporter.export(deckAt: deck, into: parent)
            }.value
            await order.finishOld()
            return result
        })
        await oldGate.waitUntilStarted()
        await app.inspect(deckAt: liveSource).value
        let live = try #require(app.exportInspected(into: output) { deck, parent in
            #expect(await order.oldFinished)
            await liveGate.run()
            return try DeckExporter.export(deckAt: deck, into: parent)
        })
        #expect(app.isExporting && app.exportedDirectory == nil)
        await oldGate.finish()
        await old.value
        await liveGate.waitUntilStarted()
        #expect(app.isExporting && app.exportedDirectory == nil)
        await liveGate.finish()
        await live.value
        let markdown = try String(contentsOf: output.appendingPathComponent("deck/deck.md"), encoding: .utf8)
        #expect(markdown.contains("LIVE EXPORT PAYLOAD"))
        #expect(!markdown.contains("OLD EXPORT PAYLOAD"))
        #expect(app.exportedDirectory?.standardizedFileURL == output.appendingPathComponent("deck").standardizedFileURL)
        #expect(!app.isExporting && app.exportProblem == nil)
    }

    @Test(arguments: [false, true], ["home", "create", "clear", "cancel"])
    func abandonedExportCannotPublishSuccessOrFailure(fails: Bool, route: String) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let source = try fixture(in: context, name: "owned")
        let app = context.app
        await app.inspect(deckAt: source).value
        let gate = StartupSignal()
        let work = try #require(app.exportInspected(into: context.libraryDirectory.appendingPathComponent("Export")) { deck, parent in
            await gate.run()
            if fails { throw ExportFailure.controlled }
            return try DeckExporter.export(deckAt: deck, into: parent)
        })
        await gate.waitUntilStarted()
        switch route {
        case "home": app.goHome()
        case "create": app.startCreate()
        case "clear": app.clearExportReport()
        default: work.cancel()
        }
        await gate.finish()
        await work.value
        #expect(!app.isExporting)
        #expect(app.exportedDirectory == nil && app.exportSummary == nil && app.exportProblem == nil)
        if route == "home" { #expect(app.phase == .home) }
        if route == "create" { #expect(app.phase == .compose) }
    }

    private func fixture(in context: AppStateTestContext, name: String) throws -> URL {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ExportBundleMarker.self)
        #endif
        let source = try #require(bundle.url(forResource: "hello", withExtension: "pptx", subdirectory: "Fixtures"))
        let destination = context.libraryDirectory.appendingPathComponent(name + ".pptx")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}

private enum ExportFailure: Error { case controlled }
private final class ExportBundleMarker {}

private actor ExportWriteOrder {
    private(set) var oldFinished = false
    func beginOld() { oldFinished = false }
    func finishOld() { oldFinished = true }
}
