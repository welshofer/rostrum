import Foundation
import Testing
@testable import Rostrum

@Suite struct AtomicFontEmbeddingTests {
    private func restrictedFont() -> Data {
        var os2 = TestFont.os2(useTypoMetrics: false)
        os2.replaceSubrange(8..<10, with: TestFont.be16(2))
        return TestFont.standard(os2: os2)
    }

    @Test func laterRestrictedFaceDoesNotChangePackage() throws {
        let deck = try Presentation()
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) {
            try deck.embedFont("Example", faces: .init(regular: TestFont.standard(), bold: restrictedFont()))
        }
        #expect(try deck.serializedData() == before)
        #expect(deck.presentationPart.rels.all(ofType: RelType.font).isEmpty)
    }

    @Test func repeatedEmbeddingIsByteIdenticalAfterReopen() throws {
        let font = TestFont.standard(familyName: "Example")
        let faces = FontFaces(regular: font, bold: font, italic: font, boldItalic: font)
        let deck = try Presentation()
        try deck.embedFont("Example", faces: faces)
        let before = try deck.serializedData()
        let reopened = try Presentation(data: before)
        try reopened.embedFont("EXAMPLE", faces: faces)
        #expect(try reopened.serializedData() == before)
        #expect(reopened.presentationPart.rels.all(ofType: RelType.font).count == 4)
    }

    private func family(_ deck: Presentation) throws -> XML.Element {
        try #require(deck.presentationPart.dom().firstChild(named: "p:embeddedFontLst")?.firstChild(named: "p:embeddedFont"))
    }

    @Test func addsMissingStylesInOrderAndPreservesExistingMarkup() throws {
        let font = TestFont.standard()
        let deck = try Presentation()
        try deck.embedFont("Example", faces: .init(regular: font, italic: font))
        let entry = try family(deck)
        entry[attribute: "xmlns:x"] = "urn:opaque"
        entry.firstChild(named: "p:font")?[attribute: "panose"] = "020B0604030504040204"
        let payload = XML.Element("x:keep", attributes: [("x:value", "untouched")])
        entry.appendElement(payload)
        entry.appendElement(XML.Element("p:extLst"))
        deck.presentationPart.markDirty()
        let originals = deck.package.parts.values.filter { $0.contentType == "application/x-fontdata" }.map { ($0.uri, $0.blob) }
        try deck.embedFont("EXAMPLE", faces: .init(regular: font, bold: font, boldItalic: font))
        let reopened = try Presentation(data: deck.serializedData())
        let saved = try family(reopened)
        #expect(saved.childElements.map(\.name) == ["p:font", "p:regular", "p:bold", "p:italic", "x:keep", "p:boldItalic", "p:extLst"])
        #expect(saved.firstChild(named: "p:font")?[attribute: "panose"] == "020B0604030504040204")
        #expect(saved.firstChild(named: "x:keep")?.serialized() == payload.serialized())
        #expect(reopened.registerEmbeddedFonts() == ["Example"])
        #expect(reopened.fonts.metrics(for: "Example", bold: true, italic: true) != nil)
        for (uri, bytes) in originals { #expect(try reopened.package.part(at: uri).blob == bytes) }
        #expect(try reopened.validate().isEmpty)
    }

    @Test func lateConflictDoesNotInstallEarlierPreparedFace() throws {
        let deck = try Presentation(), original = TestFont.standard()
        try deck.embedFont("Example", faces: .init(regular: original, bold: original))
        // A foreign declaration may omit regular while retaining bold.
        try family(deck).removeChildren(named: "p:regular")
        deck.presentationPart.markDirty()
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) {
            try deck.embedFont("Example", faces: .init(regular: original, bold: FontFaceTests.font(900, bold: true, italic: false)))
        }
        #expect(try deck.serializedData() == before)
    }

    @Test(arguments: ["missing", "external", "wrongType", "missingPart", "wrongPart", "duplicateFace", "duplicateFamily", "duplicateList", "duplicateTypeface", "changedFont", "opaque"])
    func damagedOrConflictingDestinationIsUnchanged(_ kind: String) throws {
        let font = TestFont.standard(), deck = try Presentation()
        try deck.embedFont("Example", faces: .init(regular: font))
        let entry = try family(deck)
        let root = try deck.presentationPart.dom()
        let list = try #require(root.firstChild(named: "p:embeddedFontLst"))
        let face = try #require(entry.firstChild(named: "p:regular"))
        let id = try #require(face[attribute: "r:id"])
        let rel = try #require(deck.presentationPart.rels.relationship(withId: id))
        switch kind {
        case "duplicateFace": entry.appendElement(face.deepCopy())
        case "duplicateFamily": list.appendElement(entry.deepCopy())
        case "duplicateList": root.appendElement(list.deepCopy())
        case "duplicateTypeface": entry.appendElement(try #require(entry.firstChild(named: "p:font")).deepCopy())
        case "changedFont", "opaque":
            let part = try deck.presentationPart.related(by: RelType.font, in: deck.package)
            part.replaceBlob(kind == "opaque" ? Data("opaque compressed font".utf8) :
                EOTLite.wrap(FontFaceTests.font(900, bold: false, italic: false), typeface: "Example", style: "Regular", weight: 400, italic: false))
        default:
            deck.presentationPart.rels.remove(rId: id)
            if kind != "missing" {
                deck.presentationPart.rels.add(rId: id, type: kind == "wrongType" ? RelType.image : RelType.font,
                    target: kind == "missingPart" ? "fonts/missing.fntdata" : kind == "wrongPart" ? "slides/slide1.xml" : rel.target,
                    isExternal: kind == "external")
            }
        }
        deck.presentationPart.markDirty()
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) { try deck.embedFont("Example", faces: .init(regular: font, italic: font)) }
        #expect(try deck.serializedData() == before)
    }

    @Test func reusePreservesForeignWrapperAndStillChecksLicense() throws {
        let font = restrictedFont(), deck = try Presentation()
        try deck.embedFont("Example", faces: .init(regular: font), allowRestrictedLicense: true)
        let part = try deck.presentationPart.related(by: RelType.font, in: deck.package)
        var foreign = part.blob
        foreign[16] = 2 // Different EOT metadata, identical underlying sfnt.
        part.replaceBlob(foreign)
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) { try deck.embedFont("Example", faces: .init(regular: font)) }
        #expect(try deck.serializedData() == before)
        try deck.embedFont("Example", faces: .init(regular: font), allowRestrictedLicense: true)
        #expect(try deck.serializedData() == before)
    }

    @Test func aliasesAndShadowedPrefixesRetainMeaningWhenAddingFaces() throws {
        let font = TestFont.standard(), deck = try Presentation()
        try deck.embedFont("Example", faces: .init(regular: font))
        let root = try deck.presentationPart.dom(), entry = try family(deck)
        root[attribute: "xmlns:q"] = EmbeddedFontXML.presentation
        root[attribute: "xmlns:rel"] = EmbeddedFontXML.relationships
        var stack = [try #require(root.firstChild(named: "p:embeddedFontLst"))]
        while let node = stack.popLast() {
            node.name = "q:" + node.name.dropFirst(2)
            if let id = node[attribute: "r:id"] { node[attribute: "r:id"] = nil; node[attribute: "rel:id"] = id }
            stack += node.childElements
        }
        entry[attribute: "xmlns:p"] = "urn:opaque"
        entry[attribute: "xmlns:r"] = "urn:opaque-relationships"
        entry.appendElement(XML.Element("p:keep", attributes: [("r:id", "opaque-token")]))
        deck.presentationPart.markDirty()
        try deck.embedFont("Example", faces: .init(regular: font, bold: font))
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        #expect(reopened.registerEmbeddedFonts() == ["Example"])
        #expect(reopened.fonts.metrics(for: "Example", bold: true, italic: false) != nil)
        let xml = try reopened.presentationPart.dom().serialized()
        #expect(xml.contains("<p:keep r:id=\"opaque-token\""))
        try reopened.embedFont("Example", faces: .init(regular: font, bold: font))
        #expect(try reopened.serializedData() == bytes)
    }

    @Test func respectsUnrelatedContentTypeDefault() throws {
        let deck = try Presentation()
        deck.package.contentTypes.setDefault(extension: "fntdata", contentType: "application/opaque")
        try deck.embedFont("Example", faces: .init(regular: TestFont.standard()))
        let reopened = try Presentation(data: deck.serializedData())
        #expect(reopened.package.contentTypes.defaults["fntdata"] == "application/opaque")
        #expect(reopened.registerEmbeddedFonts() == ["Example"])
    }

    @Test func doesNotOverwriteOrRetypeAnUnmodeledFontEntry() throws {
        let reader = try ZipReader(data: Presentation().serializedData())
        var zip = ZipWriter()
        for name in reader.entryNames { zip.addFile(name: name, data: try reader.data(forEntry: name)) }
        let opaque = Data("untyped producer resource".utf8)
        zip.addFile(name: "ppt/fonts/font1.fntdata", data: opaque)
        let deck = try Presentation(data: zip.finalize())
        try deck.embedFont("Example", faces: .init(regular: TestFont.standard()))
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        #expect(try ZipReader(data: bytes).data(forEntry: "ppt/fonts/font1.fntdata") == opaque)
        #expect(reopened.package.contentTypes.declaredContentType(for: PackURI("/ppt/fonts/font1.fntdata")) == nil)
        #expect(reopened.package.parts[PackURI("/ppt/fonts/font2.fntdata")]?.contentType == "application/x-fontdata")
        #expect(reopened.registerEmbeddedFonts() == ["Example"])
    }

    @Test(arguments: ["<broken", "<unexpected/>"])
    func invalidPresentationDoesNotInstallFonts(_ xml: String) throws {
        let deck = try Presentation()
        deck.presentationPart.replaceBlob(Data(xml.utf8))
        let before = try deck.package.serialize()
        #expect(throws: RostrumError.self) { try deck.embedFont("Example", faces: .init(regular: TestFont.standard())) }
        #expect(try deck.package.serialize() == before)
    }

    @Test func lateOversizedNameThrowsWithoutMutation() throws {
        let deck = try Presentation(), font = TestFont.standard()
        let before = try deck.serializedData()
        // Regular fits UInt16's UTF-16 byte length; Bold Italic does not.
        let name = String(repeating: "A", count: 32757)
        #expect(throws: RostrumError.self) {
            try deck.embedFont(name, faces: .init(regular: font, boldItalic: font))
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func largestRepresentableFullNameRetainsRawBytes() throws {
        let deck = try Presentation(), font = TestFont.standard()
        let name = String(repeating: "A", count: 32755)
        try deck.embedFont(name, faces: .init(regular: font, boldItalic: font))
        let reopened = try Presentation(data: deck.serializedData())
        for rel in reopened.presentationPart.rels.all(ofType: RelType.font) {
            let uri = PackURI.resolve(target: rel.target, relativeTo: reopened.presentationPart.uri.baseURI)
            #expect(try EOTLite.unwrap(reopened.package.part(at: uri).blob) == font)
        }
    }
}
