import Foundation
import Testing
@testable import Rostrum

/// Header-only image fixtures: the sniffer and packaging layers never decode
/// pixel data, so crafted headers suffice for unit tests.
private enum Fixture {
    /// Minimal PNG: signature + IHDR(40×30) + pHYs(144 dpi) + IEND-ish tail.
    static var png: Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        b += be32(13) + Array("IHDR".utf8) + be32(40) + be32(30)
        b += [8, 6, 0, 0, 0] + be32(0)
        let ppm = Int((144.0 / 0.0254).rounded())  // 144 dpi in px/meter
        b += be32(9) + Array("pHYs".utf8) + be32(ppm) + be32(ppm) + [1] + be32(0)
        b += be32(0) + Array("IEND".utf8) + be32(0)
        return Data(b)
    }

    /// Minimal JPEG: SOI + JFIF APP0 (96 dpi) + SOF0 (64×48) + EOI.
    static var jpeg: Data {
        var b: [UInt8] = [0xFF, 0xD8]
        b += [0xFF, 0xE0, 0x00, 0x10] + Array("JFIF\0".utf8) + [1, 1, 1, 0, 96, 0, 96, 0, 0]
        b += [0xFF, 0xC0, 0x00, 0x0B, 8] + be16(48) + be16(64) + [1]
        b += [0xFF, 0xD9]
        return Data(b)
    }

    static var gif: Data {
        Data(Array("GIF89a".utf8) + [10, 0, 20, 0, 0, 0, 0])
    }

    private static func be32(_ v: Int) -> [UInt8] {
        [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
    }
    private static func be16(_ v: Int) -> [UInt8] { [UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
}

@Suite struct ImageSnifferTests {
    @Test func pngWithDPI() {
        let info = ImageSniffer.sniff(Fixture.png)
        #expect(info?.format == .png)
        #expect(info?.pixelWidth == 40 && info?.pixelHeight == 30)
        #expect(abs((info?.dpiX ?? 0) - 144) < 1)
        // 40 px at 144 dpi = 0.2778in.
        #expect(abs((info?.nativeSize.width.inches ?? 0) - 40.0 / 144.0) < 0.01)
    }

    @Test func jpegWithJFIFDensity() {
        let info = ImageSniffer.sniff(Fixture.jpeg)
        #expect(info?.format == .jpeg)
        #expect(info?.pixelWidth == 64 && info?.pixelHeight == 48)
        #expect(info?.dpiX == 96)
    }

    @Test func gifAndGarbage() {
        #expect(ImageSniffer.sniff(Fixture.gif)?.format == .gif)
        #expect(ImageSniffer.sniff(Fixture.gif)?.pixelWidth == 10)
        #expect(ImageSniffer.sniff(Data([1, 2, 3, 4])) == nil)
        #expect(ImageSniffer.sniff(Data()) == nil)
    }
}

@Suite struct PictureTests {
    @Test func addPictureCreatesMediaPartAndRel() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addPicture(
            Fixture.png,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(3)))

        let reopened = try Presentation(data: try deck.serializedData())
        let media = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/") }
        #expect(media == [PackURI("/ppt/media/image1.png")])
        #expect(try reopened.package.part(at: media[0]).blob == Fixture.png)

        let pic = try reopened.slides[0].spTree().children(named: "p:pic")[0]
        let embed = pic.firstChild(named: "p:blipFill")?
            .firstChild(named: "a:blip")?[attribute: "r:embed"]
        #expect(embed != nil)
        #expect(reopened.slides[0].part.rels.relationship(withId: embed!)?.type == RelType.image)
    }

    @Test func identicalBytesDeduplicate() throws {
        let deck = try Presentation()
        try deck.slides.add()
        try deck.slides[0].shapes.addPicture(Fixture.png, x: .zero, y: .zero)
        try deck.slides[1].shapes.addPicture(Fixture.png, x: .inches(1), y: .inches(1))
        try deck.slides[1].shapes.addPicture(Fixture.jpeg, x: .inches(2), y: .inches(2))

        let media = deck.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/") }
        #expect(media.count == 2)  // one png (shared), one jpeg
    }

    @Test func naturalSizeUsesDPI() throws {
        let deck = try Presentation()
        let pic = try deck.slides[0].shapes.addPicture(Fixture.png, x: .zero, y: .zero)
        #expect(abs(pic.frame.width.inches - 40.0 / 144.0) < 0.01)
        #expect(abs(pic.frame.height.inches - 30.0 / 144.0) < 0.01)
    }

    @Test func contentTypesUseExtensionDefault() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addPicture(Fixture.png, x: .zero, y: .zero)
        let serialized = String(decoding: deck.package.contentTypes.serialized(), as: UTF8.self)
        #expect(serialized.contains("Extension=\"png\""))
        #expect(!serialized.contains("Override PartName=\"/ppt/media/"))
    }
}
