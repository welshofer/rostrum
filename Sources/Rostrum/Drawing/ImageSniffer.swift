import Foundation

/// Metadata sniffed from image bytes — enough to size a picture shape
/// naturally without decoding pixels.
public struct ImageInfo: Hashable, Sendable {
    public enum Format: String, Sendable {
        case png, jpeg, gif, tiff, bmp, webp

        public var fileExtension: String { rawValue }
        public var contentType: String {
            switch self {
            case .png: return ContentType.png
            case .jpeg: return ContentType.jpeg
            case .gif: return ContentType.gif
            case .tiff: return ContentType.tiff
            case .bmp: return ContentType.bmp
            case .webp: return ContentType.webp
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

/// Pure-Swift header parsing for PNG, JPEG, GIF, TIFF, BMP, and WebP.
public enum ImageSniffer {
    public static func sniff(_ data: Data) -> ImageInfo? {
        let bytes = [UInt8](data.prefix(64 * 1024))
        if let png = sniffPNG(bytes) { return png }
        if let jpeg = sniffJPEG(bytes) { return jpeg }
        if let gif = sniffGIF(bytes) { return gif }
        if let tiff = sniffTIFF(bytes) { return tiff }
        if let bmp = sniffBMP(bytes) { return bmp }
        if let webp = sniffWebP(bytes) { return webp }
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
            guard length >= 0, offset <= b.count - 12 - length else { break }
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
            guard length >= 2 else { return nil }
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

    // MARK: - TIFF

    private static func sniffTIFF(_ b: [UInt8]) -> ImageInfo? {
        guard b.count >= 8 else { return nil }
        let littleEndian: Bool
        if b[0] == 0x49, b[1] == 0x49, b[2] == 0x2A, b[3] == 0x00 {
            littleEndian = true
        } else if b[0] == 0x4D, b[1] == 0x4D, b[2] == 0x00, b[3] == 0x2A {
            littleEndian = false
        } else {
            return nil
        }
        func u16(_ offset: Int) -> Int {
            littleEndian ? (Int(b[offset]) | Int(b[offset + 1]) << 8) : (Int(b[offset]) << 8 | Int(b[offset + 1]))
        }
        func u32(_ offset: Int) -> Int {
            littleEndian ? le32(b, offset) : be32(b, offset)
        }
        let ifdOffset = u32(4)
        guard ifdOffset >= 8, ifdOffset + 2 <= b.count else { return nil }
        let entryCount = u16(ifdOffset)
        guard entryCount > 0, entryCount <= 4096 else { return nil }
        var width = 0
        var height = 0
        for i in 0..<entryCount {
            let entryOffset = ifdOffset + 2 + i * 12
            guard entryOffset + 12 <= b.count else { break }
            let tag = u16(entryOffset)
            let fieldType = u16(entryOffset + 2)
            let value: Int
            switch fieldType {
            case 3: value = u16(entryOffset + 8) // SHORT
            case 4: value = u32(entryOffset + 8) // LONG
            default: continue
            }
            if tag == 256 { width = value }
            else if tag == 257 { height = value }
        }
        guard width > 0, height > 0 else { return nil }
        return ImageInfo(format: .tiff, pixelWidth: width, pixelHeight: height, dpiX: 72, dpiY: 72)
    }

    // MARK: - BMP

    private static func sniffBMP(_ b: [UInt8]) -> ImageInfo? {
        guard b.count >= 26, b[0] == 0x42, b[1] == 0x4D else { return nil }
        let dibSize = le32(b, 14)
        let width: Int
        let height: Int
        var dpiX = 72.0
        var dpiY = 72.0
        if dibSize == 12 {
            width = Int(b[18]) | Int(b[19]) << 8
            height = Int(b[20]) | Int(b[21]) << 8
        } else if dibSize >= 16 {
            let rawW = Int32(bitPattern: UInt32(bitPattern: Int32(truncatingIfNeeded: le32(b, 18))))
            let rawH = Int32(bitPattern: UInt32(bitPattern: Int32(truncatingIfNeeded: le32(b, 22))))
            guard rawW > 0, rawH != 0, rawH != Int32.min else { return nil }
            width = Int(rawW)
            height = Int(abs(rawH))
            if dibSize >= 40, b.count >= 46 {
                let ppmX = le32(b, 38)
                let ppmY = le32(b, 42)
                if ppmX > 0, ppmY > 0 {
                    dpiX = Double(ppmX) * 0.0254
                    dpiY = Double(ppmY) * 0.0254
                }
            }
        } else {
            return nil
        }
        guard width > 0, height > 0 else { return nil }
        return ImageInfo(format: .bmp, pixelWidth: width, pixelHeight: height, dpiX: dpiX, dpiY: dpiY)
    }

    // MARK: - WebP

    private static func sniffWebP(_ b: [UInt8]) -> ImageInfo? {
        guard b.count >= 25,
              Array(b[0..<4]) == Array("RIFF".utf8),
              Array(b[8..<12]) == Array("WEBP".utf8) else { return nil }
        let chunk = Array(b[12..<16])
        let width: Int
        let height: Int
        if chunk == Array("VP8 ".utf8) {
            guard b.count >= 30, b[23] == 0x9D, b[24] == 0x01, b[25] == 0x2A else { return nil }
            width = (Int(b[26]) | Int(b[27]) << 8) & 0x3FFF
            height = (Int(b[28]) | Int(b[29]) << 8) & 0x3FFF
        } else if chunk == Array("VP8L".utf8) {
            guard b.count >= 25, b[20] == 0x2F else { return nil }
            let bits = UInt32(b[21]) | UInt32(b[22]) << 8 | UInt32(b[23]) << 16 | UInt32(b[24]) << 24
            width = Int(bits & 0x3FFF) + 1
            height = Int((bits >> 14) & 0x3FFF) + 1
        } else if chunk == Array("VP8X".utf8) {
            guard b.count >= 30 else { return nil }
            width = (Int(b[24]) | Int(b[25]) << 8 | Int(b[26]) << 16) + 1
            height = (Int(b[27]) | Int(b[28]) << 8 | Int(b[29]) << 16) + 1
        } else {
            return nil
        }
        guard width > 0, height > 0 else { return nil }
        return ImageInfo(format: .webp, pixelWidth: width, pixelHeight: height, dpiX: 72, dpiY: 72)
    }

    private static func be32(_ b: [UInt8], _ offset: Int) -> Int {
        Int(b[offset]) << 24 | Int(b[offset + 1]) << 16 | Int(b[offset + 2]) << 8 | Int(b[offset + 3])
    }

    private static func le32(_ b: [UInt8], _ offset: Int) -> Int {
        Int(b[offset]) | Int(b[offset + 1]) << 8 | Int(b[offset + 2]) << 16 | Int(b[offset + 3]) << 24
    }
}
