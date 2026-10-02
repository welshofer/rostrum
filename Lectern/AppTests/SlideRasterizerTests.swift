import SwiftUI
import Testing
#if os(macOS)
import AppKit
#endif
@testable import Lectern

@Suite struct SlidePreviewGeometryTests {
    @Test(arguments: [(640, 480), (300, 600), (1200, 700)])
    func intrinsicDimensionsAndViewBoxKeepTheWholeSlide(_ dimensions: (Int, Int)) throws {
        let (width, height) = dimensions
        for attributes in ["width=\"\(width)\" height=\"\(height)\"", "viewBox=\"0 0 \(width) \(height)\""] {
            let geometry = try #require(SlidePreviewGeometry(svg: "<svg xmlns=\"http://www.w3.org/2000/svg\" \(attributes)/>"))
            #expect(geometry.aspectRatio == Double(width) / Double(height))
            #expect(geometry.snapshotSize(pixelWidth: CGFloat(width)) == CGSize(width: width, height: height))
        }
        let points = try #require(SlidePreviewGeometry(svg: "<svg width=\"864pt\" height=\"504pt\" viewBox=\"0 0 12 7\"/>"))
        #expect(points.snapshotSize(pixelWidth: 1200) == CGSize(width: 1200, height: 700))
    }

    @Test func unsafeAndMalformedSizesAreRefusedOrBounded() throws {
        for svg in ["<html/>", "<svg xmlns=\"urn:foreign\" width=\"4\" height=\"3\"/>",
                    "<svg viewBox=\"0 0 4 bad 3\"/>", "<svg width=\"nan\" height=\"3\"/>",
                    "<svg viewBox=\"0 0 -4 3\"/>", "<svg viewBox=\"0 0 1e300 1e-300\"/>"] {
            #expect(SlidePreviewGeometry(svg: svg) == nil)
        }
        let geometry = try #require(SlidePreviewGeometry(svg: "<svg viewBox=\"0,0,1,4\"/>"))
        #expect(geometry.snapshotSize(pixelWidth: .nan) == nil)
        #expect(geometry.snapshotSize(pixelWidth: .infinity) == nil)
        #expect(geometry.snapshotSize(pixelWidth: -1) == nil)
        let bounded = try #require(geometry.snapshotSize(pixelWidth: 1_000_000))
        #expect(bounded.width == 1024 && bounded.height == 4096)
        #expect(bounded.width * bounded.height <= 4_194_304)
        let awkward = try #require(SlidePreviewGeometry(svg: "<svg viewBox=\"0 0 2503 10000\"/>"))
        let awkwardSize = try #require(awkward.snapshotSize(pixelWidth: 4096))
        #expect(awkwardSize.width * awkwardSize.height <= 4_194_304)
        #expect(awkwardSize.width <= 4096 && awkwardSize.height <= 4096)
        // Reading dimensions does not parse or allocate embedded payload DOMs.
        let large = "<svg viewBox=\"0 0 4 3\"><defs>" + String(repeating: "x", count: 100_000) + "</defs></svg>"
        #expect(SlidePreviewGeometry(svg: large)?.aspectRatio == 4.0 / 3)
    }
}

#if os(macOS)
@MainActor
@Suite struct SlideRasterizerTests {
    private let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 3\"/>"

    private func until(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(predicate())
    }

    @Test func cacheUsesFullMarkupAndRequestedResolution() async throws {
        var sizes: [CGSize] = []
        let rasterizer = SlideRasterizer(snapshot: { _, size in
            sizes.append(size)
            return Image(systemName: "square")
        })
        #expect(await rasterizer.image(for: svg, pixelWidth: 320) != nil)
        #expect(await rasterizer.image(for: svg, pixelWidth: 320) != nil)
        #expect(await rasterizer.image(for: svg, pixelWidth: 640) != nil)
        #expect(await rasterizer.image(for: svg + " ", pixelWidth: 320) != nil)
        #expect(sizes == [CGSize(width: 320, height: 240), CGSize(width: 640, height: 480), CGSize(width: 320, height: 240)])
        #expect(rasterizer.cacheCount == 3)
        #expect(SlideRasterizer.key(for: svg, size: sizes[0]).svg == svg)
    }

    @Test func cancelledWaiterDoesNotRenderAndActiveCancellationReleasesQueue() async throws {
        let active = SlideSnapshotRequest<Image>()
        var calls = 0
        let rasterizer = SlideRasterizer(snapshot: { _, _ in
            calls += 1
            if calls == 1 { return await active.value(timeout: .seconds(2), start: {}, stop: {}) }
            return Image(systemName: "square")
        })
        let first = Task { await rasterizer.image(for: svg) }
        try await until { calls == 1 }
        let cancelled = Task { await rasterizer.image(for: svg + " ") }
        try await until { rasterizer.pendingCount == 1 }
        cancelled.cancel()
        #expect(await cancelled.value == nil)
        #expect(rasterizer.pendingCount == 0)
        let next = Task { await rasterizer.image(for: svg + "  ") }
        try await until { rasterizer.pendingCount == 1 }
        first.cancel()
        #expect(await first.value == nil)
        #expect(await next.value != nil)
        active.finish(Image(systemName: "circle")) // stale completion is harmless
        #expect(calls == 2 && rasterizer.cacheCount == 1)
    }

    @Test func deadlineReleasesQueueAndIgnoresLateCompletion() async throws {
        let expired = SlideSnapshotRequest<Image>()
        var calls = 0, stops = 0
        let rasterizer = SlideRasterizer(snapshot: { _, _ in
            calls += 1
            if calls == 1 {
                return await expired.value(timeout: .milliseconds(30), start: {}, stop: { stops += 1 })
            }
            return Image(systemName: "square")
        })
        let first = Task { await rasterizer.image(for: svg) }
        try await until { calls == 1 }
        let second = Task { await rasterizer.image(for: svg + " ") }
        #expect(await first.value == nil)
        #expect(await second.value != nil)
        expired.finish(Image(systemName: "circle"))
        #expect(stops == 1 && rasterizer.cacheCount == 1)
    }

    @Test func queueRejectsExcessWorkWithoutGrowing() async throws {
        let active = SlideSnapshotRequest<Image>()
        var started = false
        let rasterizer = SlideRasterizer(snapshot: { _, _ in
            started = true
            return await active.value(timeout: .seconds(2), start: {}, stop: {})
        })
        let first = Task { await rasterizer.image(for: svg) }
        try await until { started }
        let pending = (0..<SlideRasterizer.maximumPendingRequests).map { index in
            Task { await rasterizer.image(for: svg + String(repeating: " ", count: index + 1)) }
        }
        try await until { rasterizer.pendingCount == SlideRasterizer.maximumPendingRequests }
        #expect(await rasterizer.image(for: svg + "<!--extra-->") == nil)
        #expect(rasterizer.pendingCount == SlideRasterizer.maximumPendingRequests)
        for task in pending { task.cancel() }
        for task in pending { #expect(await task.value == nil) }
        first.cancel()
        #expect(await first.value == nil)
        #expect(rasterizer.pendingCount == 0 && rasterizer.cacheCount == 0)
    }

    /// Opt in only in the app-hosted macOS run. Headless tests above never
    /// create an NSWindow or WKWebView.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func nativeSnapshotIncludesTheBottomOfPortraitAndFourByThreeSlides() async throws {
        for (width, height) in [(400, 300), (300, 600)] {
            let markup = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(width) \(height)\"><rect width=\"100%\" height=\"100%\" fill=\"red\"/><rect y=\"\(height - 40)\" width=\"100%\" height=\"40\" fill=\"blue\"/></svg>"
            let image = try #require(await SlideRasterizer.shared.image(for: markup, pixelWidth: CGFloat(width)))
            let rendered = try #require(ImageRenderer(content: image).nsImage)
            #expect(rendered.size == CGSize(width: width, height: height))
            let data = try #require(rendered.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: data))
            let color = try #require(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh - 5)?.usingColorSpace(.deviceRGB))
            #expect(color.blueComponent > 0.9 && color.redComponent < 0.1)
        }
    }
}
#endif
