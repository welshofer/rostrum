import AppKit
import SwiftUI
import Testing
import Rostrum
import LecternCore
@testable import Lectern

@Suite struct PreviewIdentityTests {
    @MainActor
    @Test func damagedDeckReachesInspectorWithOriginalPreviewSlots() async throws {
        let deck = try Presentation()
        try deck.titleSlide("First")
        try deck.titleSlide("Missing middle")
        try deck.titleSlide("Third")
        try deck.slides.remove(at: 0)
        let middle = try deck.slides[1]
        deck.package.removePart(at: middle.part.uri)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-\(UUID()).pptx")
        try deck.save(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let app = AppState(skipKeychain: true)
        app.inspect(deckAt: url)
        for _ in 0..<250 {
            if app.phase == .inspected { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let inspection = try #require(app.inspection)
        let labels = inspection.previewRecords.map { $0.accessibilityLabel(total: inspection.slideCount) }
        #expect(labels.contains("Slide 2 of 3. Preview unavailable"))
        #expect(labels.contains { $0.hasPrefix("Slide 3 of 3: Third") })
        #expect(inspection.previewRecords[1].svg == nil)
        #expect(inspection.previewRecords[2].svg != nil)
        // Optional snapshot exercises the production contact sheet without UI automation
        // changing the lifetime of the app-hosted test runner.
        if let directory = ProcessInfo.processInfo.environment["LECTERN_AUDIT_OUTPUT"] {
            let view = NSHostingView(rootView: SlideContactSheet(records: inspection.previewRecords, total: 3)
                .frame(width: 1000, height: 300).background(Color.white).environment(\.colorScheme, .light))
            let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1000, height: 300),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = view
            window.setContentSize(NSSize(width: 1000, height: 300))
            window.orderBack(nil)
            defer { window.orderOut(nil) }
            for record in inspection.previewRecords {
                _ = await SlideRasterizer.shared.image(for: record.displaySVG)
            }
            try await Task.sleep(for: .milliseconds(200))
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("preview-identity.png"))
        }
    }
}
