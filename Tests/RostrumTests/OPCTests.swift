import Foundation
import Testing
@testable import Rostrum

@Suite struct PackURITests {
    @Test func componentsDerive() {
        let uri = PackURI("/ppt/slides/slide1.xml")
        #expect(uri.filename == "slide1.xml")
        #expect(uri.ext == "xml")
        #expect(uri.baseURI == "/ppt/slides")
        #expect(uri.memberName == "ppt/slides/slide1.xml")
        #expect(uri.relsURI.value == "/ppt/slides/_rels/slide1.xml.rels")
    }

    @Test func rootLevelPart() {
        let uri = PackURI("/[Content_Types].xml")
        #expect(uri.baseURI == "/")
        // Package-level rels live at /_rels/.rels; a root part's rels URI still
        // follows the standard pattern.
        #expect(PackURI("/docProps/core.xml").relsURI.value == "/docProps/_rels/core.xml.rels")
    }

    @Test func resolveRelativeTargets() {
        #expect(PackURI.resolve(target: "slideMasters/slideMaster1.xml", relativeTo: "/ppt").value
            == "/ppt/slideMasters/slideMaster1.xml")
        #expect(PackURI.resolve(target: "../slideLayouts/slideLayout1.xml", relativeTo: "/ppt/slideMasters").value
            == "/ppt/slideLayouts/slideLayout1.xml")
        #expect(PackURI.resolve(target: "./theme/theme1.xml", relativeTo: "/ppt").value
            == "/ppt/theme/theme1.xml")
        #expect(PackURI.resolve(target: "/ppt/presentation.xml", relativeTo: "/ignored").value
            == "/ppt/presentation.xml")
        #expect(PackURI.resolve(target: "ppt/presentation.xml", relativeTo: "/").value
            == "/ppt/presentation.xml")
    }

    @Test func relativeReference() {
        let master = PackURI("/ppt/slideMasters/slideMaster1.xml")
        #expect(master.relativeReference(to: PackURI("/ppt/slideLayouts/slideLayout1.xml"))
            == "../slideLayouts/slideLayout1.xml")
        let presentation = PackURI("/ppt/presentation.xml")
        #expect(presentation.relativeReference(to: PackURI("/ppt/slides/slide1.xml"))
            == "slides/slide1.xml")
    }
}

@Suite struct ContentTypesTests {
    @Test func overrideBeatsDefault() throws {
        var map = ContentTypesMap()
        map.setOverride(partName: PackURI("/ppt/presentation.xml"), contentType: ContentType.presentationMain)
        #expect(try map.contentType(for: PackURI("/ppt/presentation.xml")) == ContentType.presentationMain)
        // Falls back to the xml Default for a part with no Override.
        #expect(try map.contentType(for: PackURI("/other/thing.xml")) == "application/xml")
    }

    @Test func unknownExtensionThrows() {
        let map = ContentTypesMap()
        #expect(throws: RostrumError.self) {
            try map.contentType(for: PackURI("/media/image1.png"))
        }
    }

    @Test func parseSerializeRoundTrip() throws {
        var map = ContentTypesMap()
        map.setDefault(extension: "png", contentType: ContentType.png)
        map.setOverride(partName: PackURI("/ppt/presentation.xml"), contentType: ContentType.presentationMain)
        map.setOverride(partName: PackURI("/ppt/slides/slide1.xml"), contentType: ContentType.slide)

        let reparsed = try ContentTypesMap.parse(map.serialized())
        #expect(reparsed.defaults == map.defaults)
        #expect(reparsed.overrides == map.overrides)
        // Deterministic output.
        #expect(map.serialized() == map.serialized())
    }
}

@Suite struct RelationshipsTests {
    @Test func addAssignsSequentialRIds() {
        let rels = Relationships()
        #expect(rels.add(type: RelType.slideMaster, target: "slideMasters/slideMaster1.xml") == "rId1")
        #expect(rels.add(type: RelType.slide, target: "slides/slide1.xml") == "rId2")
        rels.remove(rId: "rId1")
        // Next id never collides with a live one.
        let next = rels.add(type: RelType.theme, target: "theme/theme1.xml")
        #expect(rels.relationship(withId: next) != nil)
        #expect(Set(rels.items.map(\.rId)).count == rels.items.count)
    }

    @Test func parseSerializeRoundTrip() throws {
        let rels = Relationships()
        rels.add(type: RelType.slide, target: "slides/slide1.xml")
        rels.add(type: RelType.hyperlink, target: "https://example.com/", isExternal: true)

        let reparsed = try Relationships.parse(rels.serialized())
        #expect(reparsed.items == rels.items)
        #expect(reparsed.first(ofType: RelType.hyperlink)?.isExternal == true)
    }
}

@Suite struct OPCPackageTests {
    @Test func serializeReadRoundTrip() throws {
        let package = OPCPackage()
        let part = package.addPart(
            uri: PackURI("/ppt/presentation.xml"),
            contentType: ContentType.presentationMain,
            blob: Data("<p:presentation xmlns:p=\"x\"/>".utf8))
        part.rels.add(type: RelType.slide, target: "slides/slide1.xml")
        package.addPart(
            uri: PackURI("/ppt/slides/slide1.xml"),
            contentType: ContentType.slide,
            blob: Data("<p:sld xmlns:p=\"x\"/>".utf8))
        package.rels.add(type: RelType.officeDocument, target: "ppt/presentation.xml")

        let reread = try OPCPackage.read(data: package.serialize())
        #expect(Set(reread.parts.keys) == Set(package.parts.keys))
        let main = try reread.mainDocumentPart()
        #expect(main.uri.value == "/ppt/presentation.xml")
        #expect(main.contentType == ContentType.presentationMain)
        #expect(main.rels.first(ofType: RelType.slide)?.target == "slides/slide1.xml")
        #expect(main.blob == part.blob)
    }

    @Test func missingContentTypesRejected() throws {
        var zip = ZipWriter()
        zip.addFile(name: "ppt/presentation.xml", data: Data("<x/>".utf8))
        #expect(throws: RostrumError.self) {
            try OPCPackage.read(data: try zip.finalize())
        }
    }

    @Test func relatedPartTraversal() throws {
        let package = try MinimalTemplate.makePackage()
        let presentation = try package.mainDocumentPart()
        let master = try presentation.related(by: RelType.slideMaster, in: package)
        #expect(master.uri.value == "/ppt/slideMasters/slideMaster1.xml")
        let theme = try master.related(by: RelType.theme, in: package)
        #expect(theme.uri.value == "/ppt/theme/theme1.xml")
    }

    /// A part that gets edited is rebuilt from its DOM, so anything the DOM
    /// cannot hold is gone at that moment. Comments and processing
    /// instructions are the plainest case of XML Rostrum does not model, and
    /// the round-trip promise is about exactly that XML.
    @Test func editingAPartKeepsTheMarkupItDoesNotModel() throws {
        let original = Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r
            <?mso-application progid="PowerPoint.Show"?><!-- produced elsewhere -->\
            <p:sld xmlns:p="x"><!-- keep me --><p:cSld/></p:sld>
            """.utf8)
        let part = Part(uri: PackURI("/ppt/slides/slide1.xml"),
                        contentType: ContentType.slide, blob: original)
        // Untouched, the original bytes stand.
        part.flushIfDirty()
        #expect(part.blob == original)

        try part.dom().appendElement(XML.Element("p:extLst"))
        part.markDirty()
        part.flushIfDirty()
        #expect(part.blob != original)
        let rebuilt = String(decoding: part.blob, as: UTF8.self)
        #expect(rebuilt.contains(#"<?mso-application progid="PowerPoint.Show"?>"#))
        #expect(rebuilt.contains("<!-- produced elsewhere -->"))
        #expect(rebuilt.contains("<!-- keep me -->"))
        #expect(rebuilt.hasSuffix("<!-- keep me --><p:cSld/><p:extLst/></p:sld>"))
        // Still well-formed, and stable on a second pass.
        let reread = try XML.parseDocument(part.blob)
        #expect(XML.document(reread) == part.blob)
    }
}
