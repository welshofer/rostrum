import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PipelineTraceTests {
    @Test func traceIsScopedBoundedAndRecordsFailure() async throws {
        #expect(PipelineTrace.begin("disabled") == nil)
        let trace = PipelineTrace(capacity: 2)
        await PipelineTrace.$current.withValue(trace) {
            let span = PipelineTrace.begin("once")
            span?.end(); span?.end()
            enum Failure: Error { case expected }
            #expect(throws: Failure.self) {
                try PipelineTrace.measure("failure") { throw Failure.expected }
            }
            await Task { PipelineTrace.measure("child") {} }.value
            #expect(await Task.detached { PipelineTrace.begin("detached") == nil }.value)
        }
        #expect(PipelineTrace.current == nil)
        #expect(trace.report.samples.map(\.stage) == ["once", "failure"])
        #expect(trace.report.samples.map(\.outcome) == ["completed", "failed"])
        #expect(trace.report.droppedSamples == 1)
        #expect(trace.report.samples.allSatisfy { $0.startSeconds >= 0 && $0.elapsedSeconds >= 0 && $0.cpuSeconds >= 0 })
    }

    @Test func simultaneousOperationsKeepTheirOwnTrace() async {
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    let trace = PipelineTrace()
                    await PipelineTrace.$current.withValue(trace) {
                        await Task.yield()
                        PipelineTrace.measure("operation-\(index)") {}
                    }
                    #expect(trace.report.samples.map(\.stage) == ["operation-\(index)"])
                }
            }
        }
    }

    @Test func instrumentationPreservesGeneratedBytesAndInspection() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let deck = DeckIR(meta: Meta(title: "Profile parity"), slides: [
            IRSlide(id: "cover", layout: "title", title: "Rostrum in Lectern"),
            IRSlide(id: "table", layout: "table", title: "Retain every row", body: Body(table: .init(
                headers: ["Record", "Evidence"], rows: (1...12).map { ["R\($0)", "Exact original text \($0) wraps naturally."] })),
                notes: "Retained notes")
        ])
        let renderer = DeckRenderer()
        let baseline = try await renderer.render(deck, designURL: nil, notesEnabled: true,
                                                into: root.appendingPathComponent("baseline"))
        let trace = PipelineTrace()
        let measured = try await PipelineTrace.$current.withValue(trace) {
            try await renderer.render(deck, designURL: nil, notesEnabled: true,
                                      into: root.appendingPathComponent("measured"))
        }
        #expect(try Data(contentsOf: baseline.url) == Data(contentsOf: measured.url))
        let copied = PipelineTrace.$current.withValue(trace) {
            DeckResult.savedCopy(of: baseline, at: measured.url)
        }
        #expect(copied == measured)
        #expect(measured.previewRecords.map(\.content.svg) == measured.previews)
        #expect(trace.report.samples.filter { $0.stage == "preview.identity" }.count == measured.previewRecords.count)
        let stages = Set(trace.report.samples.map(\.stage))
        #expect(stages.isSuperset(of: ["generation.prepare", "generation.fontDiscovery", "generation.installedFonts",
            "generation.layout", "generation.compose", "generation.save", "preview.reopen", "preview.embeddedFonts",
            "preview.fontDiscovery", "preview.installedFonts", "preview.svg"]))
        #expect(trace.report.samples.allSatisfy { $0.outcome == "completed" })
        let inspectionTrace = PipelineTrace()
        let inspection = try PipelineTrace.$current.withValue(inspectionTrace) {
            try DeckInspector.inspect(deckAt: measured.url)
        }
        #expect(inspection.previews == measured.previews)
        #expect(inspection.previewDiagnostics == measured.previewDiagnostics)
        #expect(inspection.previewSlideNumbers == measured.previewSlideNumbers)
        #expect(inspectionTrace.report.samples.filter { $0.stage == "preview.svg" }.map(\.slideNumber)
            == measured.previewSlideNumbers.map(Optional.some))
        #expect(try RenderContentCheck.inspect(measured.url, expected: deck).issues.isEmpty)
    }

    @Test func failedOpenDoesNotReportSuccessfulPreview() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a deck".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let trace = PipelineTrace()
        PipelineTrace.$current.withValue(trace) {
            #expect(throws: DeckInspectionError.self) { try DeckInspector.inspect(deckAt: url) }
        }
        #expect(trace.report.samples.map(\.stage) == ["inspect.read", "inspect.open"])
        #expect(trace.report.samples.last?.outcome == "failed")
    }
}
