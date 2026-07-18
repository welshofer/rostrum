import Foundation

/// Metadata sniffed from image bytes — enough to size a picture shape
/// naturally without decoding pixels.
public struct ImageInfo: Hashable, Sendable {
    public enum Format: String, Sendable {
        case png, jpeg, gif

        public var fileExtension: String { rawValue }
        public var contentType: String {
            switch self {
            case .png: return ContentType.png
            case .jpeg: return ContentType.jpeg
            case .gif: return ContentType.gif
            }
        }
    }

    public let format: Format
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// Dots per inch; 72 when the file doesn't say.
    public let dpiX: Double
    public let dpiY: Double

    /// The image's natural size on a slide (pixels ÷ dpi).
    public var nativeSize: (width: EMU, height: EMU) {
        (.inches(Double(pixelWidth) / dpiX), .inches(Double(pixelHeight) / dpiY))
    }
}

/// Pure-Swift header parsing for PNG, JPEG and GIF.
public enum ImageSniffer {
    public static func sniff(_ data: Data) -> ImageInfo? {
        let bytes = [UInt8](data.prefix(64 * 1024))
        if let png = sniffPNG(bytes) { return png }
        if let jpeg = sniffJPEG(bytes) { return jpeg }
        if let gif = sniffGIF(bytes) { return gif }
        return nil
    }

    // MARK: - PNG

    private static func sniffPNG(_ b: [UInt8]) -> ImageInfo? {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard b.count >= 33, Array(b[0..<8]) == signature else { return nil }
        // First chunk must be IHDR: length(4) type(4)="IHDR" width(4) height(4).
        guard Array(b[12..<16]) == Array("IHDR".utf8) else { return nil }
        let width = be32(b, 16), height = be32(b, 20)
        guard width > 0, height > 0 else { return nil }

        // Optional pHYs chunk: pixels per meter when unit specifier == 1.
        var dpiX = 72.0, dpiY = 72.0
        var offset = 8
        while offset + 12 <= b.count {
            let length = be32(b, offset)
            let type = Array(b[offset + 4..<offset + 8])
            if type == Array("pHYs".utf8), offset + 8 + 9 <= b.count {
                let ppmX = be32(b, offset + 8), ppmY = be32(b, offset + 12)
                if b[offset + 16] == 1, ppmX > 0, ppmY > 0 {
                    dpiX = Double(ppmX) * 0.0254
                    dpiY = Double(ppmY) * 0.0254
                }
                break
            }
            if type == Array("IDAT".utf8) { break }
            offset += 12 + length
        }
        return ImageInfo(format: .png, pixelWidth: width, pixelHeight: height, dpiX: dpiX, dpiY: dpiY)
    }

    // MARK: - JPEG

    private static func sniffJPEG(_ b: [UInt8]) -> ImageInfo? {
        guard b.count > 4, b[0] == 0xFF, b[1] == 0xD8 else { return nil }
        var dpiX = 72.0, dpiY = 72.0
        var offset = 2
        while offset + 4 <= b.count {
            guard b[offset] == 0xFF else { return nil }
            let marker = b[offset + 1]
            if marker == 0xD8 || (0xD0...0xD7).contains(marker) { offset += 2; continue }
            let length = Int(b[offset + 2]) << 8 | Int(b[offset + 3])
            // JFIF APP0: density fields.
            if marker == 0xE0, offset + 2 + 14 <= b.count,
               Array(b[offset + 4..<offset + 9]) == Array("JFIF\0".utf8) {
                let units = b[offset + 11]
                let dx = Double(Int(b[offset + 12]) << 8 | Int(b[offset + 13]))
                let dy = Double(Int(b[offset + 14]) << 8 | Int(b[offset + 15]))
                if units == 1, dx > 0, dy > 0 { dpiX = dx; dpiY = dy }
                if units == 2, dx > 0, dy > 0 { dpiX = dx * 2.54; dpiY = dy * 2.54 }
            }
            // SOF markers carry dimensions (all C0-CF except C4/C8/CC).
            if (0xC0...0xCF).contains(marker), marker != 0xC4, marker != 0xC8, marker != 0xCC {
                guard offset + 9 <= b.count else { return nil }
                let height = Int(b[offset + 5]) << 8 | Int(b[offset + 6])
                let width = Int(b[offset + 7]) << 8 | Int(b[offset + 8])
                guard width > 0, height > 0 else { return nil }
                return ImageInfo(format: .jpeg, pixelWidth: width, pixelHeight: height, dpiX: dpiX, dpiY: dpiY)
            }
            offset += 2 + length
        }
        return nil
    }

    // MARK: - GIF

    private static func sniffGIF(_ b: [UInt8]) -> ImageInfo? {
        guard b.count >= 10, Array(b[0..<4]) == Array("GIF8".utf8) else { return nil }
        let width = Int(b[6]) | Int(b[7]) << 8
        let height = Int(b[8]) | Int(b[9]) << 8
        guard width > 0, height > 0 else { return nil }
        return ImageInfo(format: .gif, pixelWidth: width, pixelHeight: height, dpiX: 72, dpiY: 72)
    }

    private static func be32(_ b: [UInt8], _ offset: Int) -> Int {
        Int(b[offset]) << 24 | Int(b[offset + 1]) << 16 | Int(b[offset + 2]) << 8 | Int(b[offset + 3])
    }
}
