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
        let sharedFonts = environment["LECTERN_PREVIEW_SHARED_FONTS"] == "1"
        let rasterizer = SlideRasterizer(shareFontResources: sharedFonts)
        defer { rasterizer.close() }
        var profiles: [[String: Any]] = []
        var reference: DeckInspection?
        for operation in 1...2 {
            let trace = PipelineTrace()
            let inspection = try await Task.detached {
                try PipelineTrace.$current.withValue(trace) { try DeckInspector.inspect(deckAt: input) }
            }.value
            if let reference {
                // Keep private slide contents out of assertion logs, which the
                // collector includes in the shareable diagnostic archive.
                let samePreviews = reference.previews == inspection.previews
                let sameDiagnostics = reference.previewDiagnostics == inspection.previewDiagnostics
                    && reference.schemaIssues == inspection.schemaIssues
                    && reference.readWarnings == inspection.readWarnings
                    && reference.outlineWarnings == inspection.outlineWarnings
                try #require(samePreviews, "Repeated inspection changed SVG output")
                try #require(sameDiagnostics, "Repeated inspection changed ordered diagnostics")
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
                "fontResources": rasterizer.fontResourceStatistics,
                "stages": try JSONSerialization.jsonObject(with: JSONEncoder().encode(trace.report))])
        }
        // Outside measured operations: compare real pixels for every slide,
        // through independent uncached hosts, including embedded-font loading.
        // Do not publish successful candidate timing evidence on a mismatch.
        var parityCount = 0
        var comparisonCount = 0
        var mismatchedSlides: [Int] = []
        if sharedFonts, let reference {
            let inline = SnapshotHost(), shared = SnapshotHost(shareFontResources: true)
            defer { inline.close(); shared.close() }
            let bitmaps = output.appendingPathComponent("native-bitmaps", isDirectory: true)
            try FileManager.default.createDirectory(at: bitmaps, withIntermediateDirectories: true)
            func save(_ image: NSImage, to url: URL) throws {
                let bitmap = NSBitmapImageRep(cgImage: try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
                try #require(bitmap.representation(using: .png, properties: [:])).write(to: url)
            }
            for record in reference.previewRecords {
                let svg = try #require(record.svg)
                let size = try #require(SlidePreviewGeometry(svg: svg)?.snapshotSize(pixelWidth: 640))
                let original = try #require(await inline.snapshot(svg: svg, size: size))
                let candidate = try #require(await shared.snapshot(svg: svg, size: size))
                let originalPixels = try PreviewBitmapPixels(original)
                let candidatePixels = try PreviewBitmapPixels(candidate)
                let samePixels = originalPixels == candidatePixels
                // Local fidelity evidence only: after measurements, excluded from
                // the collector's explicit diagnostic archive allowlist.
                try save(original, to: bitmaps.appendingPathComponent("slide-\(record.number).png"))
                if !samePixels {
                    mismatchedSlides.append(record.number)
                    let directory = output.appendingPathComponent("bitmap-mismatch-slide-\(record.number)", isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try save(original, to: directory.appendingPathComponent("inline-first.png"))
                    try save(candidate, to: directory.appendingPathComponent("shared-first.png"))
                    let inlineRepeat = try #require(await inline.snapshot(svg: svg, size: size))
                    let sharedRepeat = try #require(await shared.snapshot(svg: svg, size: size))
                    try save(inlineRepeat, to: directory.appendingPathComponent("inline-repeat.png"))
                    try save(sharedRepeat, to: directory.appendingPathComponent("shared-repeat.png"))
                    let inlineRepeatPixels = try PreviewBitmapPixels(inlineRepeat)
                    let sharedRepeatPixels = try PreviewBitmapPixels(sharedRepeat)
                    let controls = ["inlineStable": originalPixels == inlineRepeatPixels,
                                    "sharedStable": candidatePixels == sharedRepeatPixels,
                                    "repeatParity": inlineRepeatPixels == sharedRepeatPixels]
                    try JSONSerialization.data(withJSONObject: controls, options: [.prettyPrinted, .sortedKeys])
                        .write(to: directory.appendingPathComponent("controls.json"))
                }
                comparisonCount += 1
                if samePixels { parityCount += 1 }
            }
            try #require(shared.fontResourceStatistics["servedFontRequests", default: 0] > 0,
                         "Choose a deck containing embedded preview fonts to exercise shared resources")
        }
        let sourceUnchanged = try Data(contentsOf: input) == original
        try #require(sourceUnchanged, "Profiling changed the source deck")
        // Outside measured operations. Retain ordering and locations so the
        // paired collector can reject diagnostic drift as well as SVG drift.
        let inspected = try #require(reference)
        let diagnostics: [String: Any] = [
            "schemaIssues": inspected.schemaIssues, "readWarnings": inspected.readWarnings,
            "outlineWarnings": inspected.outlineWarnings,
            "previews": inspected.previewRecords.map { record -> [String: Any] in
                ["slideNumber": record.number, "warnings": record.warnings]
            },
            "diagnostics": inspected.previewDiagnostics.map { diagnostic -> [String: Any] in
                ["slideNumber": diagnostic.slideNumber, "layoutUnresolved": diagnostic.layoutUnresolved,
                 "masterUnresolved": diagnostic.masterUnresolved,
                 "failure": diagnostic.failure as Any? ?? NSNull(), "messages": diagnostic.messages,
                 "issues": diagnostic.issues.map { issue -> [String: Any] in
                     ["code": issue.code, "impact": issue.impact, "message": issue.message,
                      "partURI": issue.partURI, "shapeID": issue.shapeID as Any? ?? NSNull(), "path": issue.path]
                 }]
            }
        ]
        try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("diagnostics.json"))
        #if DEBUG
        let mode = "debug"
        #else
        let mode = "release"
        #endif
        let report: [String: Any] = ["schemaVersion": 3, "buildMode": mode, "platform": ProcessInfo.processInfo.operatingSystemVersionString,
            "fontResourceMode": sharedFonts ? "shared" : "inline", "bitmapParityCount": parityCount,
            "bitmapComparisonCount": comparisonCount, "bitmapMismatchSlides": mismatchedSlides,
            "samples": profiles, "nativeVisualAcceptance": "pending",
            "measurementScope": "Production inspection then sequential production raster requests, first-use and repeated on the same bounded cache. First bitmap availability is not first visible frame. Process CPU excludes WebKit helper processes. RSS is the app process lifetime peak, includes test-host startup, and is not per-operation or total WebKit memory. SVG evidence writes are outside stage timings but within first-bitmap wall offsets on later slides. Input hashing/reads may warm filesystem caches."]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("timings.json"))
        // Retain truthful measured data and failure evidence before failing the
        // strict acceptance check. Diagnostic collection must not call this a pass.
        let allPixelsMatch = mismatchedSlides.isEmpty
        try #require(allPixelsMatch, "Native bitmap comparison differed on slides \(mismatchedSlides)")
    }
}
