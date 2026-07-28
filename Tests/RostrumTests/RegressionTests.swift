import Foundation
import Testing
@testable import Rostrum

/// Regression tests for defects confirmed by the 2026-07-18 adversarial review.
/// Each test names the failure it guards against.
@Suite struct RegressionTests {
    // MARK: OPC: rIds must survive read exactly as written

    @Test func parsedRIdsPreservedThroughReadAndSave() throws {
        // A rels file with gaps and out-of-order ids, as any deck with an edit
        // history has. Renumbering these corrupts every r:id reference.
        let relsXML = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId5" Type="\(RelType.slide)" Target="slides/slide1.xml"/><Relationship Id="rId2" Type="\(RelType.slideMaster)" Target="slideMasters/slideMaster1.xml"/></Relationships>
            """
        var zip = ZipWriter()
        var types = ContentTypesMap()
        types.setOverride(partName: PackURI("/ppt/presentation.xml"), contentType: ContentType.presentationMain)
        types.setOverride(partName: PackURI("/ppt/slides/slide1.xml"), contentType: ContentType.slide)
        types.setOverride(partName: PackURI("/ppt/slideMasters/slideMaster1.xml"), contentType: ContentType.slideMaster)
        zip.addFile(name: "[Content_Types].xml", data: types.serialized())
        zip.addFile(name: "_rels/.rels", data: {
            let r = Relationships()
            r.add(type: RelType.officeDocument, target: "ppt/presentation.xml")
            return r.serialized()
        }())
        zip.addFile(name: "ppt/presentation.xml", data: Data("<p:presentation xmlns:p=\"x\"/>".utf8))
        zip.addFile(name: "ppt/_rels/presentation.xml.rels", data: Data(relsXML.utf8))
        zip.addFile(name: "ppt/slides/slide1.xml", data: Data("<p:sld xmlns:p=\"x\"/>".utf8))
        zip.addFile(name: "ppt/slideMasters/slideMaster1.xml", data: Data("<p:sldMaster xmlns:p=\"x\"/>".utf8))

        let package = try OPCPackage.read(data: try zip.finalize())
        let main = try package.part(at: PackURI("/ppt/presentation.xml"))
        #expect(main.rels.relationship(withId: "rId5")?.type == RelType.slide)
        #expect(main.rels.relationship(withId: "rId2")?.type == RelType.slideMaster)
        #expect(main.rels.items.count == 2)

        // And they survive a full serialize→read cycle too.
        let reread = try OPCPackage.read(data: package.serialize())
        let mainAgain = try reread.part(at: PackURI("/ppt/presentation.xml"))
        #expect(mainAgain.rels.relationship(withId: "rId5")?.target == "slides/slide1.xml")
        // New additions never collide with preserved ids.
        let newId = mainAgain.rels.add(type: RelType.theme, target: "theme/theme1.xml")
        #expect(newId != "rId2" && newId != "rId5")
    }

    // MARK: OPC: removePart must drop the content-type override

    @Test func removePartDropsContentTypeOverride() throws {
        let package = try MinimalTemplate.makePackage()
        package.removePart(at: PackURI("/ppt/slides/slide1.xml"))
        let serialized = String(decoding: package.contentTypes.serialized(), as: UTF8.self)
        #expect(!serialized.contains("/ppt/slides/slide1.xml"))
    }

    // MARK: XML: escaping must operate on scalars, not grapheme clusters

    @Test func ampersandFollowedByCombiningMarkIsEscaped() throws {
        // "&" + U+0301 forms one grapheme cluster; Character-based matching
        // misses it and emits a bare ampersand no parser can reopen.
        let tricky = "R&\u{301}D"
        let root = XML.Element("a:t", children: [.text(tricky)])
        let serialized = root.serialized()
        // Compare exact scalars: `.contains("&amp;")` would itself fall into
        // the grapheme trap (the ";" merges with U+0301 into one grapheme).
        #expect(serialized == "<a:t>R&amp;\u{301}D</a:t>")
        let reparsed = try XML.parse(XML.document(root))
        #expect(reparsed.textContent == tricky)
    }

    // MARK: XML: control characters in attributes must be character references

    @Test func tabNewlineCRInAttributesSurviveRoundTrip() throws {
        // XML attribute-value normalization turns literal tab/LF/CR into
        // spaces on ANY conforming reparse; only character references survive.
        let multiline = "First line\nSecond\tline\rThird"
        let root = XML.Element("p:pic", attributes: [("descr", multiline)])
        let serialized = root.serialized()
        #expect(serialized.contains("&#10;") && serialized.contains("&#9;") && serialized.contains("&#13;"))
        let reparsed = try XML.parse(XML.document(root))
        #expect(reparsed[attribute: "descr"] == multiline)
    }

    @Test func carriageReturnInTextSurvivesRoundTrip() throws {
        // Line-ending normalization turns a literal CR in content into LF.
        let text = "a\rb"
        let root = XML.Element("a:t", children: [.text(text)])
        #expect(root.serialized().contains("&#13;"))
        let reparsed = try XML.parse(XML.document(root))
        #expect(reparsed.textContent == text)
    }

    // MARK: Zip: 65535 entries is a legal literal count, not a zip64 sentinel

    @Test func archiveWithMoreThan65535EntriesRoundTrips() throws {
        // The 16-bit EOCD count is the one 32-bit-era ceiling a .pptx can
        // plausibly reach — 65536 tiny parts is a few megabytes — so it is the
        // half of zip64 this project implements and can actually prove. The
        // 64-bit SIZE and OFFSET fields are not implemented and stay reported.
        var zip = ZipWriter()
        for i in 0..<65_536 {
            zip.addFile(name: "f\(i)", data: Data(), compress: false)
        }
        let archive = try zip.finalize()
        let reader = try ZipReader(data: archive)
        #expect(reader.entryNames.count == 65_536)
        #expect(reader.contains("f65535"))
        #expect(reader.contains("f0"))

        // The classic EOCD must carry the sentinel, and a zip64 EOCD + locator
        // must precede it — otherwise the count came from somewhere else and
        // this proves nothing about zip64.
        let bytes = [UInt8](archive)
        let eocd = bytes.count - 22
        func u16(_ at: Int) -> Int { Int(bytes[at]) | (Int(bytes[at + 1]) << 8) }
        func u32(_ at: Int) -> Int { (0..<4).reduce(0) { $0 | (Int(bytes[at + $1]) << (8 * $1)) } }
        #expect(u32(eocd) == 0x0605_4B50)
        #expect(u16(eocd + 10) == 0xFFFF, "the classic count must be the sentinel")
        #expect(u32(eocd - 20) == 0x0706_4B50, "a zip64 locator must precede the EOCD")
        let zip64EOCD = u32(eocd - 20 + 8)
        #expect(u32(zip64EOCD) == 0x0606_4B50)

        // External oracle: Info-ZIP must accept it. A format change is exactly
        // where our own reader agreeing with our own writer proves least.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-zip64-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try archive.write(to: url)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "unzip -t rejected the zip64 archive")
    }

    @Test func archiveWithExactly65535EntriesRoundTrips() throws {
        var zip = ZipWriter()
        let payload = Data()
        for i in 0..<65535 {
            zip.addFile(name: "f\(i)", data: payload)
        }
        let archive = try zip.finalize()
        let reader = try ZipReader(data: archive)
        #expect(reader.entryNames.count == 65535)
        #expect(reader.contains("f65534"))
        // 65535 fits the classic field, so NO zip64 structures are emitted —
        // the boundary matters, and an archive that fit before must still be
        // byte-identical to what it was.
        let bytes = [UInt8](archive)
        let eocd = bytes.count - 22
        func u16(_ at: Int) -> Int { Int(bytes[at]) | (Int(bytes[at + 1]) << 8) }
        func u32(_ at: Int) -> Int { (0..<4).reduce(0) { $0 | (Int(bytes[at + $1]) << (8 * $1)) } }
        #expect(u16(eocd + 10) == 65535, "0xFFFF here is a literal count, not a sentinel")
        #expect(u32(eocd - 20) != 0x0706_4B50, "no zip64 locator may be emitted at the boundary")
    }

    // MARK: Zip: CP437 entry names when the UTF-8 flag is clear

    @Test func cp437NameDecodedWhenUTF8FlagClear() throws {
        // Hand-built one-entry STORED archive: name "café.txt" in CP437
        // (0x82 = é), general-purpose flags 0x0000, empty data.
        let nameBytes: [UInt8] = [0x63, 0x61, 0x66, 0x82, 0x2E, 0x74, 0x78, 0x74]
        var bytes: [UInt8] = []
        func le16(_ v: Int) { bytes.append(UInt8(v & 0xFF)); bytes.append(UInt8((v >> 8) & 0xFF)) }
        func le32(_ v: UInt32) { for shift in [0, 8, 16, 24] { bytes.append(UInt8((v >> UInt32(shift)) & 0xFF)) } }
        // Local file header.
        le32(0x0403_4B50); le16(20); le16(0); le16(0); le16(0); le16(0x21)
        le32(0); le32(0); le32(0); le16(nameBytes.count); le16(0)
        bytes.append(contentsOf: nameBytes)
        let cdOffset = bytes.count
        // Central directory header.
        le32(0x0201_4B50); le16(20); le16(20); le16(0); le16(0); le16(0); le16(0x21)
        le32(0); le32(0); le32(0); le16(nameBytes.count); le16(0); le16(0)
        le16(0); le16(0); le32(0); le32(0)
        bytes.append(contentsOf: nameBytes)
        let cdSize = bytes.count - cdOffset
        // EOCD.
        le32(0x0605_4B50); le16(0); le16(0); le16(1); le16(1)
        le32(UInt32(cdSize)); le32(UInt32(cdOffset)); le16(0)

        let reader = try ZipReader(data: Data(bytes))
        #expect(reader.entryNames == ["café.txt"])
        #expect(try reader.data(forEntry: "café.txt").isEmpty)
    }

    @Test func utf8NameWithoutFlagStillDecodesAsUTF8() throws {
        // Modern tools often write UTF-8 names without setting bit 11; valid
        // UTF-8 must win over the CP437 fallback.
        var zip = ZipWriter()
        zip.addFile(name: "ppt/media/naïve.png", data: Data([1]))
        // Our writer sets bit 11; clear it in both headers to simulate.
        var bytes = [UInt8](try zip.finalize())
        // Local header flags at offset 6; central header flags at cd + 8.
        bytes[6] = 0; bytes[7] = 0
        let cdOffset = bytes.count - 22 - 46 - "ppt/media/naïve.png".utf8.count
        bytes[cdOffset + 8] = 0; bytes[cdOffset + 9] = 0
        let reader = try ZipReader(data: Data(bytes))
        #expect(reader.entryNames == ["ppt/media/naïve.png"])
    }

    // MARK: Shapes: txBody children must be DrawingML-namespaced

    @Test func txBodyChildrenUseDrawingMLNamespace() throws {
        // p:bodyPr instead of a:bodyPr makes renderers (LibreOffice,
        // QuickLook) silently drop the entire shape.
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        box.textFrame!.verticalAnchor = .middle
        let shape = try deck.slides[0].shapes.addShape(
            .rectangle, frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)),
            fill: .solid(.black))
        _ = shape
        let reopened = try Presentation(data: try deck.serializedData())
        for sp in try reopened.slides[0].spTree().children(named: "p:sp") {
            let txBody = sp.firstChild(named: "p:txBody")!
            for child in txBody.childElements {
                #expect(child.name.hasPrefix("a:"),
                        "txBody child \(child.name) must be in the a: namespace")
            }
        }
    }

    // MARK: Presentation: slideSize setter must create a missing p:sldSz

    @Test func slideSizeSetterCreatesMissingSldSz() throws {
        let deck = try Presentation()
        // Simulate a valid deck whose presentation.xml lacks p:sldSz.
        try deck.presentationPart.dom().children.removeAll {
            if case .element(let e) = $0 { return e.name == "p:sldSz" }
            return false
        }
        deck.slideSize = (width: .inches(10), height: .inches(7.5))

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slideSize.width == .inches(10))
        // And it landed at the schema-correct position: before p:notesSz.
        let names = try reopened.presentationPart.dom().childElements.map(\.name)
        let sldSzIndex = names.firstIndex(of: "p:sldSz")
        let notesSzIndex = names.firstIndex(of: "p:notesSz")
        #expect(sldSzIndex != nil && notesSzIndex != nil && sldSzIndex! < notesSzIndex!)
    }

    /// Deck bytes must not depend on the wall clock. core.xml carries a FIXED
    /// created/modified stamp, not `Date()` — otherwise two builds seconds apart
    /// differ (and the byte-identity gate is impossible).
    @Test func corePropertiesUseAFixedTimestamp() throws {
        let core = try Presentation().package.part(at: PackURI("/docProps/core.xml")).blob
        let xml = String(decoding: core, as: UTF8.self)
        #expect(xml.contains("2020-01-01T00:00:00Z"))
    }
}
