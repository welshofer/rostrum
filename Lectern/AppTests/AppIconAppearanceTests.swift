import CoreGraphics
import Foundation
import ImageIO
import Testing

/// L-ATTR-1: macOS 26 / iOS 26 ask each icon for dark and tinted appearances.
/// The `AppIcon.appiconset` gained iOS `universal` 1024 entries carrying the
/// asset-catalog `appearances` (`luminosity` / `dark` and `tinted`) keys, plus
/// the two derived PNGs. A compiled `Assets.car` hides all of this at runtime,
/// so these read the source catalog directly through `#filePath` — the repo is
/// deliberately local-only (no hosted macOS Actions job), so it resolves to the
/// real checkout. They would have caught a typo'd filename, a dropped variant,
/// a disturbed macOS ladder, or a tinted icon that stopped being grayscale.
@Suite struct AppIconAppearanceTests {
    private static var iconSet: URL {
        URL(fileURLWithPath: #filePath)          // …/Lectern/AppTests/AppIconAppearanceTests.swift
            .deletingLastPathComponent()          // …/Lectern/AppTests
            .deletingLastPathComponent()          // …/Lectern
            .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")
    }

    private struct Appearance: Decodable {
        let appearance: String
        let value: String
    }
    private struct Entry: Decodable {
        let filename: String?
        let idiom: String
        let platform: String?
        let size: String
        let appearances: [Appearance]?
    }
    private struct Catalog: Decodable {
        let images: [Entry]
    }

    private static func catalog() throws -> Catalog {
        let data = try Data(contentsOf: iconSet.appendingPathComponent("Contents.json"))
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    @Test func everyReferencedIconFileExistsOnDisk() throws {
        for entry in try Self.catalog().images {
            guard let name = entry.filename else { continue }
            let url = Self.iconSet.appendingPathComponent(name)
            #expect(
                FileManager.default.fileExists(atPath: url.path),
                "AppIcon references \(name) but it is missing on disk")
        }
    }

    @Test func iOSIconDeclaresDarkAndTintedAppearances() throws {
        let images = try Self.catalog().images
        func iosVariant(_ value: String) -> Entry? {
            images.first { entry in
                entry.platform == "ios" && entry.size == "1024x1024"
                    && (entry.appearances?.contains {
                        $0.appearance == "luminosity" && $0.value == value
                    } ?? false)
            }
        }
        #expect(iosVariant("dark")?.filename == "icon_1024_dark.png")
        #expect(iosVariant("tinted")?.filename == "icon_1024_tinted.png")

        // The default (no-appearances) iOS 1024 entry must survive alongside them.
        let base = images.first {
            $0.platform == "ios" && $0.size == "1024x1024" && $0.appearances == nil
        }
        #expect(base?.filename == "icon_1024.png")
    }

    @Test func macIconLadderIsUntouched() throws {
        let macSizes = Set(try Self.catalog().images.filter { $0.idiom == "mac" }.map(\.size))
        #expect(macSizes == Set(["16x16", "32x32", "128x128", "256x256", "512x512"]))
    }

    @Test func tintedVariantIsGrayscale() throws {
        let url = Self.iconSet.appendingPathComponent("icon_1024_tinted.png")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            Issue.record("could not decode icon_1024_tinted.png")
            return
        }
        #expect(image.width == 1024 && image.height == 1024)

        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &pixels, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            Issue.record("could not create RGBA bitmap context")
            return
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // A luminance map is R == G == B; tolerate ±2 for decode/colour rounding.
        // A coloured regression (e.g. the purple plate 94,31,141) differs by far more.
        var colouredPixels = 0
        var index = 0
        while index < pixels.count {
            let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
            if abs(r - g) > 2 || abs(g - b) > 2 || abs(r - b) > 2 { colouredPixels += 1 }
            index += 4
        }
        #expect(
            colouredPixels == 0,
            "tinted app icon must be a grayscale luminance map; found \(colouredPixels) coloured pixels")
    }
}
