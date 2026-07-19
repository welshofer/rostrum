import Foundation
import Testing
@testable import Rostrum

@Suite struct FontEmbeddingTests {
    /// A real system TTF when present (macOS), else nil (skip on Linux/CI).
    private var systemFont: Data? {
        let path = "/System/Library/Fonts/Supplemental/Georgia.ttf"
        return FileManager.default.isExecutableFile(atPath: path) || FileManager.default.fileExists(atPath: path)
            ? try? Data(contentsOf: URL(fileURLWithPath: path)) : nil
    }

    @Test func eotWrapperStructure() {
        let fake = Data((0..<500).map { UInt8($0 & 0xFF) })
        let eot = EOTLite.wrap(fake, typeface: "Test", style: "Regular", weight: 400, italic: false)
        let b = [UInt8](eot)
        func le32(_ o: Int) -> UInt32 { UInt32(b[o]) | UInt32(b[o+1]) << 8 | UInt32(b[o+2]) << 16 | UInt32(b[o+3]) << 24 }
        func le16(_ o: Int) -> UInt16 { UInt16(b[o]) | UInt16(b[o+1]) << 8 }
        #expect(le32(0) == UInt32(eot.count))       // EOTSize = total
        #expect(le32(4) == 500)                       // FontDataSize
        #expect(le32(8) == 0x0002_0001)               // Version
        #expect(le32(12) == 0)                        // Flags: no MTX, no XOR
        #expect(le16(34) == 0x504C)                   // MagicNumber
        // The original font bytes are appended, unmodified, at the tail.
        #expect(Data(b.suffix(500)) == fake)
    }

    @Test func embedFontWiresPartsRelsAndList() throws {
        let font = systemFont ?? Data(repeating: 0, count: 200)
        let deck = try Presentation()
        try deck.embedFont("Georgia", faces: FontFaces(regular: font, bold: font))

        let bytes = try deck.serializedData()
        let zip = try ZipReader(data: bytes)
        #expect(zip.contains("ppt/fonts/font1.fntdata"))
        #expect(zip.contains("ppt/fonts/font2.fntdata"))
        let ct = String(decoding: try zip.data(forEntry: "[Content_Types].xml"), as: UTF8.self)
        #expect(ct.contains("Extension=\"fntdata\"") && ct.contains("application/x-fontdata"))

        let reopened = try Presentation(data: bytes)
        let pres = try reopened.presentationPart.dom()
        #expect(pres[attribute: "embedTrueTypeFonts"] == "1")
        let font1 = pres.firstChild(named: "p:embeddedFontLst")!.firstChild(named: "p:embeddedFont")!
        #expect(font1.firstChild(named: "p:font")?[attribute: "typeface"] == "Georgia")
        // regular and bold reference real font relationships.
        let regId = font1.firstChild(named: "p:regular")![attribute: "r:id"]!
        #expect(reopened.presentationPart.rels.relationship(withId: regId)?.type == RelType.font)
        // embeddedFontLst comes after notesSz in schema order.
        let names = pres.childElements.map(\.name)
        #expect(names.firstIndex(of: "p:notesSz")! < names.firstIndex(of: "p:embeddedFontLst")!)
    }

    @Test func fsTypeParsedFromRealFont() throws {
        guard let font = systemFont else { return }
        // A shippable system font must be parseable and installable-embeddable.
        let fsType = EOTLite.fsType(of: font)
        #expect(fsType != nil)
        #expect((fsType! & EOTLite.fsTypeRestricted) == 0)
    }

    @Test func altTextRoundTrips() throws {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(1)))
        box.altText = "A friendly greeting"
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[0].shapes[0].altText == "A friendly greeting")
    }
}
