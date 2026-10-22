#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import Lectern

/// Opt-in reproduction of native WebKit's unstable clipped-pattern sampling.
/// This is deliberately outside the passing preview regression selection: a
/// failure identifies a platform rendering limitation, not font-transport loss.
@MainActor
@Suite struct NativeImageStabilityDiagnosticTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_IMAGE_STABILITY"] == "1"),
          arguments: [false, true])
    func repeatedInlineImagesHaveIdenticalPixels(patterned: Bool) async throws {
        let size = 1024
        let image = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: size * 3, bitsPerPixel: 24))
        let bytes = try #require(image.bitmapData)
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 3
                bytes[index] = UInt8((x * 13 + y * 3) % 256)
                bytes[index + 1] = UInt8((x / 8 + y / 8) % 2 == 0 ? 230 : 20)
                bytes[index + 2] = UInt8((x * 7 + y * 11) % 256)
            }
        }
        let jpeg = try #require(image.representation(using: .jpeg, properties: [.compressionFactor: 0.9]))
        let source = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        let picture: String
        if patterned {
            picture = """
            <defs>
              <clipPath id="pictureClip"><rect width="3931920" height="3931920"/></clipPath>
              <pattern id="picture" patternUnits="userSpaceOnUse" x="822960" y="2310383" width="3931920" height="3931920">
                <g clip-path="url(#pictureClip)"><image width="3931920" height="3931920" preserveAspectRatio="none" href="\(source)"/></g>
              </pattern>
            </defs>
            <rect x="822960" y="2310383" width="3931920" height="3931920" fill="url(#picture)"/>
            """
        } else {
            picture = "<image x=\"822960\" y=\"2310383\" width=\"3931920\" height=\"3931920\" preserveAspectRatio=\"none\" href=\"\(source)\"/>"
        }
        let markup = """
        <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 12191695 6858000">
          <rect width="12191695" height="6858000" fill="white"/>\(picture)
        </svg>
        """
        let host = SnapshotHost()
        defer { host.close() }
        let viewport = CGSize(width: 640, height: 360)
        let original = try PreviewBitmapPixels(#require(await host.snapshot(svg: markup, size: viewport)))
        try #require(original.rgba.contains { $0 < 128 }, "The synthetic JPEG must actually draw")
        for capture in 1...12 {
            let repeated = try PreviewBitmapPixels(#require(await host.snapshot(svg: markup, size: viewport)))
            let stable = repeated == original
            #expect(stable, "Inline capture \(capture) changed image pixels; patterned=\(patterned)")
        }
    }
}
#endif
