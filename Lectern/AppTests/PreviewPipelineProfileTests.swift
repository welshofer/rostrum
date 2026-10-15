import AppKit
import Darwin
import SwiftUI
import Testing
import LecternCore
@testable import Lectern

@MainActor
@Suite struct PreviewPipelineTraceTests {
    @Test func cacheHitDoesNotRepeatRasterizationInTrace() async throws {
        let trace = PipelineTrace()
        let rasterizer = SlideRasterizer(snapshot: { _, _ in Image(systemName: "square") })
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 3\"/>"
        await PipelineTrace.$current.withValue(trace) {
            #expect(await rasterizer.image(for: svg) != nil)
            #expect(await rasterizer.image(for: svg) != nil)
        }
        #expect(trace.report.samples.filter { $0.stage == "thumbnail.request" }.map(\.outcome) == ["rendered", "cacheHit"])
        #expect(trace.report.samples.filter { $0.stage == "thumbnail.queue" }.count == 1)
    }

    @Test func preparedContentIsReusedAndByteBudgetDeclinesOversizedImages() async throws {
        let trace = PipelineTrace()
        let content = PreviewContent(svg: "<svg viewBox=\"0 0 4 3\"/>")
        var renders = 0
        let cost = content.byteCount + 320 * 240 * 4
        let rasterizer = SlideRasterizer(byteLimit: cost, snapshot: { _, _ in
            renders += 1
            return Image(systemName: "square")
        })
        await PipelineTrace.$current.withValue(trace) {
            #expect(await rasterizer.image(for: content, pixelWidth: 320) != nil)
            #expect(await rasterizer.image(for: content, pixelWidth: 320) != nil)
            #expect(await rasterizer.image(for: content, pixelWidth: 640) != nil)
            #expect(await rasterizer.image(for: content, pixelWidth: 320) != nil)
        }
        #expect(renders == 2)
        #expect(rasterizer.cacheCount == 1)
        #expect(rasterizer.cacheCostBytes == cost)
        #expect(trace.report.samples.filter { $0.stage == "preview.identity" }.isEmpty)
        #expect(trace.report.samples.filter { $0.stage == "thumbnail.cacheInsert" }.map(\.outcome) == ["admitted", "overBudget"])
        #expect(SlideRasterizer.bitmapCost(width: Int.max, height: 2) == Int.max)
    }

}

@MainActor
@Suite struct PreviewPipelineProfileTests {
    /// An opt-in, isolated native probe. It uses the real inspector and bitmap
    /// host, never the snapshot override. Run alone in Release via the script;
    /// no assertion about physical display presentation or Office parity.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_PREVIEW_PROFILE_INPUT"] != nil))
    func profileSavedDeck() async throws {
        let environment = ProcessInfo.processInfo.environment
        let input = URL(fileURLWithPath: try #require(environment["LECTERN_PREVIEW_PROFILE_INPUT"]))
        let output = URL(fileURLWithPath: try #require(environment["LECTERN_PREVIEW_PROFILE_OUTPUT"]))
        try #require(!FileManager.default.fileExists(atPath: output.path), "Choose a new output directory")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let original = try Data(contentsOf: input)
        let rasterizer = SlideRasterizer()
        defer { rasterizer.close() }
        var profiles: [[String: Any]] = []
        var reference: DeckInspection?
        for operation in 1...2 {
            let trace = PipelineTrace()
            let inspection = try await Task.detached {
                try PipelineTrace.$current.withValue(trace) { try DeckInspector.inspect(deckAt: input) }
            }.value
            if let reference {
                #expect(reference.previews == inspection.previews)
                #expect(reference.previewDiagnostics == inspection.previewDiagnostics)
            }
            reference = inspection
            try #require(!inspection.previewRecords.isEmpty)
            var firstBitmapSeconds: Double?
            for record in inspection.previewRecords {
                try #require(record.svg != nil, "A failed SVG slot is not a usable thumbnail")
                let image = await PipelineTrace.$current.withValue(trace) {
                    await rasterizer.image(for: record.content)
                }
                try #require(image != nil, "WebKit must produce an actual bitmap")
                if firstBitmapSeconds == nil, let sample = trace.report.samples.last(where: { $0.stage == "thumbnail.request" }) {
                    firstBitmapSeconds = sample.startSeconds + sample.elapsedSeconds
                }
                // Persist the SVGs used by the bitmap path for exact input comparison.
                if operation == 1 {
                    try record.displaySVG.write(to: output.appendingPathComponent("slide-\(record.number).svg"), atomically: true, encoding: .utf8)
                }
            }
            var usage = rusage()
            try #require(getrusage(RUSAGE_SELF, &usage) == 0)
            profiles.append(["operationInProcess": operation,
                "firstBitmapAvailableSeconds": firstBitmapSeconds as Any? ?? NSNull(),
                "appProcessLifetimePeakRSSBytes": usage.ru_maxrss,
                "thumbnailCacheEntries": rasterizer.cacheCount,
                "thumbnailCacheAccountedBytes": rasterizer.cacheCostBytes,
                "thumbnailCacheByteLimit": rasterizer.cacheByteLimit,
                "stages": try JSONSerialization.jsonObject(with: JSONEncoder().encode(trace.report))])
        }
        #expect(try Data(contentsOf: input) == original)
        #if DEBUG
        let mode = "debug"
        #else
        let mode = "release"
        #endif
        let report: [String: Any] = ["schemaVersion": 2, "buildMode": mode, "platform": ProcessInfo.processInfo.operatingSystemVersionString,
            "samples": profiles, "nativeVisualAcceptance": "pending",
            "measurementScope": "Production inspection then sequential production raster requests, first-use and repeated on the same bounded cache. First bitmap availability is not first visible frame. Process CPU excludes WebKit helper processes. RSS is the app process lifetime peak, includes test-host startup, and is not per-operation or total WebKit memory. SVG evidence writes are outside stage timings but within first-bitmap wall offsets on later slides. Input hashing/reads may warm filesystem caches."]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("timings.json"))
    }
}
