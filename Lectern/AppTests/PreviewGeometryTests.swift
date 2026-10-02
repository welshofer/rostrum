import AppKit
import SwiftUI
import Testing
import LecternCore
@testable import Lectern

@Suite struct PreviewGeometryTests {
    @MainActor
    @Test func snapshotsPreserveAllCornersAndCacheResolution() async throws {
        let host = SnapshotHost()
        let rasterizer = SlideRasterizer(capacity: 8)
        var records: [SlidePreviewRecord] = []
        var timings: [[String: Double]] = []
        let directory = ProcessInfo.processInfo.environment["LECTERN_AUDIT_OUTPUT"]
        for (index, ratio) in [16.0 / 9, 4.0 / 3, 9.0 / 16].enumerated() {
            let height = 640 / ratio
            let svg = Self.svg(height: height)
            records.append(SlidePreviewRecord(number: index + 1, title: "Aspect \(index + 1)", svg: svg))
            for width: CGFloat in [320, 640] {
                let size = SlideRasterizer.size(for: svg, pixelWidth: width)
                let image = try #require(await host.snapshot(svg: svg, size: size))
                #expect(abs(image.size.width - size.width) <= 1)
                #expect(abs(image.size.height - size.height) <= 1)
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: tiff))
                let x = bitmap.pixelsWide / 100, y = bitmap.pixelsHigh / 100
                let points = [(x, y), (bitmap.pixelsWide - x - 1, y),
                              (x, bitmap.pixelsHigh - y - 1),
                              (bitmap.pixelsWide - x - 1, bitmap.pixelsHigh - y - 1)]
                let colors = points.compactMap { x, y -> String? in
                    guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return nil }
                    if c.redComponent > 0.8, c.greenComponent < 0.2, c.blueComponent < 0.2 { return "red" }
                    if c.redComponent < 0.2, c.greenComponent > 0.8, c.blueComponent < 0.2 { return "green" }
                    if c.redComponent < 0.2, c.greenComponent < 0.2, c.blueComponent > 0.8 { return "blue" }
                    if c.redComponent > 0.8, c.greenComponent > 0.8, c.blueComponent < 0.2 { return "yellow" }
                    return "missing"
                }
                #expect(Set(colors) == Set(["red", "green", "blue", "yellow"]))
                if let directory {
                    try bitmap.representation(using: .png, properties: [:])?.write(
                        to: URL(fileURLWithPath: directory).appendingPathComponent("aspect-\(index)-\(Int(width)).png"))
                }
            }
            let small = SlideRasterizer.size(for: svg, pixelWidth: 320)
            let large = SlideRasterizer.size(for: svg, pixelWidth: 640)
            #expect(SlideRasterizer.key(for: svg, size: small) != SlideRasterizer.key(for: svg, size: large))
            let start = ProcessInfo.processInfo.systemUptime
            #expect(await rasterizer.image(for: svg) != nil)
            let cold = ProcessInfo.processInfo.systemUptime - start
            let warmStart = ProcessInfo.processInfo.systemUptime
            for _ in 0..<100 { #expect(await rasterizer.image(for: svg) != nil) }
            let warm = (ProcessInfo.processInfo.systemUptime - warmStart) / 100
            #expect(await rasterizer.image(for: svg, pixelWidth: 320) != nil)
            #expect(rasterizer.cacheCount == (index + 1) * 2)
            timings.append(["aspectRatio": ratio, "coldMS": cold * 1000, "cachedMS": warm * 1000])
        }
        if let directory {
            let data = try JSONSerialization.data(withJSONObject: timings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("preview-timings.json"))
            for width in [720.0, 1000.0] {
                try await Self.capture(records: records, width: width, directory: directory)
            }
        }
    }

    static func svg(height: Double) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="640" height="\(height)" viewBox="0 0 640 \(height)">
          <rect width="640" height="\(height)" fill="white"/>
          <rect x="0" y="0" width="32" height="32" fill="#ff0000"/>
          <rect x="608" y="0" width="32" height="32" fill="#00ff00"/>
          <rect x="0" y="\(height - 32)" width="32" height="32" fill="#0000ff"/>
          <rect x="608" y="\(height - 32)" width="32" height="32" fill="#ffff00"/>
          <text x="320" y="\(height / 2)" text-anchor="middle" font-family="sans-serif" font-size="32" fill="#111111">640 × \(Int(height.rounded()))</text>
        </svg>
        """
    }

    @MainActor
    private static func capture(records: [SlidePreviewRecord], width: Double, directory: String) async throws {
        let height = width / 3 * 16 / 9 + 230
        let content = VStack {
            SlideContactSheet(records: records, total: 3)
            SlideFilmstrip(records: records, total: 3)
        }.frame(width: width, height: height).background(Color.white).environment(\.colorScheme, .light)
        let view = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.setContentSize(NSSize(width: width, height: height))
        window.orderBack(nil)
        defer { window.orderOut(nil) }
        for record in records { _ = await SlideRasterizer.shared.image(for: record.displaySVG) }
        try await Task.sleep(for: .milliseconds(200))
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("preview-layout-\(Int(width)).png"))
    }
}
