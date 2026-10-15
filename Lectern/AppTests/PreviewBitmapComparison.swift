#if os(macOS)
import AppKit
import Testing

struct PreviewBitmapPixels: Equatable {
    let width: Int
    let height: Int
    let rgba: Data

    @MainActor init(_ image: NSImage) throws {
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        width = cgImage.width; height = cgImage.height
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = Data(count: width * height * 4)
        let width = width, height = height
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        rgba = bytes
    }
}
#endif
