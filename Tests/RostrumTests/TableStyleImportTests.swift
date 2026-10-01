import Foundation
import Testing
@testable import Rostrum

@Suite struct TableStyleImportTests {
    func table(_ deck: Presentation) throws -> Table {
        try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(2)))
    }
    func style(_ id: String, _ hex: String) throws -> XML.Element {
        try XML.parse(Data("<a:tblStyle xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" styleId=\"\(id)\" styleName=\"Review\"><a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val=\"\(hex)\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl></a:tblStyle>".utf8))
    }
    @Test func importedSlideRetainsEmbeddedCustomStyle() throws {
        let source = try Presentation()
        let sourceTable = try table(source)
        try sourceTable.setStyleDefinition(style("{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}", "FF0000"))
        let destination = try Presentation()
        let slide = try destination.slides.import(from: source, at: 0)
        let importedTable = try #require((slide.shapes.all.first as? TableFrame)?.table)
        #expect(TableStyleResolver(table: importedTable, theme: destination.theme).hasStyleDefinition)
    }
    @Test func sameGuidCaseReplacesDefinition() throws {
        let deck = try Presentation()
        let value = try table(deck)
        try value.setStyleDefinition(style("{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}", "FF0000"))
        try value.setStyleDefinition(style("{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}", "00FF00"))
        #expect(try TableStyleResolver(table: value, theme: deck.theme).fill(row: 0, column: 0) == .solid(Color("00FF00"), alpha: 1))
    }
    @Test func aliasedRelationshipStyleRefusesAtomically() throws {
        let deck = try Presentation()
        let value = try table(deck)
        let definition = try style("{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}", "FF0000")
        definition[attribute: "xmlns:rel"] = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let cellStyle = try #require(definition.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle"))
        cellStyle.removeChildren(named: "a:fill")
        cellStyle.appendElement(XML.Element("a:fill", children: [.element(XML.Element("a:blipFill", children: [.element(XML.Element("a:blip", attributes: [("rel:embed", "rIdForeign")]))]))]))
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) { try value.setStyleDefinition(definition) }
        #expect(try deck.serializedData() == before)
    }

}

extension TableStyleImportTests {
    private static let guid = "{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}"
    private var png: Data { Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")! }
    private func styles(_ deck: Presentation) throws -> Part {
        try deck.presentationPart.related(by: RelType.tableStyles, in: deck.package)
    }
    private func importedTable(_ slide: Slide) throws -> Table {
        try #require((slide.shapes.all.first as? TableFrame)?.table)
    }

    @Test func conflictingGuidsRemapAndRepeatedImportsReuseEquivalentDefinition() throws {
        let source = try Presentation(), destination = try Presentation()
        let original = try table(destination), incoming = try table(source)
        try original.setStyleDefinition(style(Self.guid, "00FF00"))
        try incoming.setStyleDefinition(style(Self.guid, "FF0000"))
        let sourceBytes = try source.serializedData()
        let a = try importedTable(destination.slides.import(from: source, at: 0))
        let b = try importedTable(destination.slides.import(from: source, at: 0))
        #expect(a.styleID != original.styleID)
        #expect(a.styleID == b.styleID)
        #expect(try TableStyleResolver(table: original, theme: destination.theme).fill(row: 0, column: 0) == .solid(Color("00FF00"), alpha: 1))
        #expect(try TableStyleResolver(table: a, theme: destination.theme).fill(row: 0, column: 0) == .solid(Color("FF0000"), alpha: 1))
        #expect(try TableStyleXML.definitions(in: styles(destination).dom()).count == 2)
        #expect(try source.serializedData() == sourceBytes)
        let bytes = try destination.serializedData()
        #expect(try destination.serializedData() == bytes)
        let reopened = try Presentation(data: bytes)
        #expect(try importedTable(reopened.slides[1]).styleID == a.styleID)
        let another = try Presentation()
        try table(another).setStyleDefinition(style(Self.guid, "00FF00"))
        #expect(try importedTable(another.slides.import(from: source, at: 0)).styleID == a.styleID)
    }

    /// A foreign style list uses aliases on its root and owns a real image plus
    /// an unknown extension graph. Its dependency graph includes an external
    /// hyperlink and a cycle; neither can be dropped while remapping IDs.
    private func relationshipSource(missing: Bool = false) throws -> (Presentation, Part, XML.Element) {
        let source = try Presentation()
        let table = try table(source)
        try table.setStyleDefinition(style(Self.guid, "FF0000"))
        let owner = try styles(source)
        let root = try owner.dom()
        root[attribute: "xmlns:s"] = TableStyleXML.drawing
        root[attribute: "xmlns:rel"] = TableStyleXML.relationships
        root[attribute: "xmlns:custom"] = "urn:review:style"
        root[attribute: "xmlns:mc"] = "http://schemas.openxmlformats.org/markup-compatibility/2006"
        root[attribute: "mc:Ignorable"] = "custom"
        let definition = try #require(TableStyleXML.definitions(in: root).first)
        let image = source.package.addPart(uri: PackURI("/ppt/media/style.png"), contentType: ContentType.png, blob: png)
        let imageID = owner.rels.add(type: RelType.image, target: missing ? "media/missing.png" : owner.uri.relativeReference(to: image.uri))
        let fill = try #require(definition.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle")?.firstChild(named: "a:fill"))
        fill.children = [.element(XML.Element("a:blipFill", children: [
            .element(XML.Element("a:blip", attributes: [("rel:embed", imageID)])),
            .element(XML.Element("a:stretch", children: [.element(XML.Element("a:fillRect"))]))]))]
        let extra = source.package.addPart(uri: PackURI("/ppt/custom/style-extra.xml"), contentType: "application/xml", blob: Data("<extra>opaque</extra>".utf8))
        extra.rels.add(rId: "cycle", type: "urn:cycle", target: "style-extra.xml")
        extra.rels.add(rId: "external", type: "urn:external", target: "https://example.com/style", isExternal: true)
        let extraID = owner.rels.add(type: "urn:extension", target: owner.uri.relativeReference(to: extra.uri))
        definition.appendElement(XML.Element("a:extLst", children: [.element(XML.Element("custom:data", attributes: [("rel:id", extraID), ("custom:value", "preserve")]))]))
        TableStyleXML.walk(root) { node, _ in if node.name.hasPrefix("a:") { node.name = "s:" + node.name.dropFirst(2) } }
        owner.markDirty()
        return (source, owner, definition)
    }

    @Test func relationshipBackedAliasStylesTransferThroughSlidesAndStandaloneAPI() throws {
        let (source, owner, definition) = try relationshipSource()
        let sourceBytes = try source.serializedData()
        for standalone in [false, true] {
            let destination = try Presentation()
            let imported: Table
            if standalone {
                imported = try table(destination)
                try imported.setStyleDefinition(definition, from: owner, in: source.package)
            } else { imported = try importedTable(destination.slides.import(from: source, at: 0)) }
            let target = try styles(destination)
            let root = try target.dom()
            let copied = try #require(TableStyleXML.definitions(in: root).first)
            let view = TableStyleXML.drawingView(copied, root: root)
            let imageID = try #require(view.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle")?.firstChild(named: "a:fill")?.firstChild(named: "a:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"])
            let imageRel = try #require(target.rels.relationship(withId: imageID))
            let media = try destination.package.part(at: PackURI.resolve(target: imageRel.target, relativeTo: target.uri.baseURI))
            #expect(media.blob == png)
            let extraRel = try #require(target.rels.items.first { $0.type == "urn:extension" })
            let extra = try destination.package.part(at: PackURI.resolve(target: extraRel.target, relativeTo: target.uri.baseURI))
            #expect(extra.blob == Data("<extra>opaque</extra>".utf8))
            #expect(extra.rels.relationship(withId: "external")?.target == "https://example.com/style")
            #expect(PackURI.resolve(target: try #require(extra.rels.relationship(withId: "cycle")?.target), relativeTo: extra.uri.baseURI) == extra.uri)
            #expect(copied[attribute: "mc:Ignorable"] == "custom")
            #expect(copied.serialized().contains("custom:value=\"preserve\""))
            #expect(copied.serialized().contains("xmlns:custom=\"urn:review:style\""))
            #expect(TableStyleResolver(table: imported, theme: destination.theme).hasStyleDefinition)
            #expect(try destination.renderSVG(slideAt: standalone ? 0 : 1).contains("data:image/png;base64,"))
            let reopened = try Presentation(data: destination.serializedData())
            #expect(try reopened.renderSVG(slideAt: standalone ? 0 : 1).contains("data:image/png;base64,"))
            // Existing relationship IDs are respected on a second import and
            // graph equivalence avoids adding another style/media dependency.
            let count = destination.package.parts.count
            if standalone { try imported.setStyleDefinition(definition, from: owner, in: source.package) }
            #expect(destination.package.parts.count == count)
            #expect(try TableStyleXML.definitions(in: styles(destination).dom()).count == 1)
        }
        #expect(try source.serializedData() == sourceBytes)
    }

    @Test func missingStyleDependencyRefusesSlideAndStandaloneTransfersAtomically() throws {
        let (source, owner, definition) = try relationshipSource(missing: true)
        let destination = try Presentation(), target = try table(destination)
        try target.setStyleDefinition(style(Self.guid, "00FF00"))
        let before = try destination.serializedData()
        #expect(throws: RostrumError.self) { try destination.slides.import(from: source, at: 0) }
        #expect(try destination.serializedData() == before)
        #expect(throws: RostrumError.self) { try target.setStyleDefinition(definition, from: owner, in: source.package) }
        #expect(try destination.serializedData() == before)
        #expect(throws: RostrumError.self) { try target.setStyleDefinition(definition, from: owner, in: destination.package) }
        #expect(try destination.serializedData() == before)
    }

    @Test func implicitDefaultStyleBecomesExplicitDestinationReference() throws {
        let source = try Presentation(), destination = try Presentation()
        let incoming = try table(source)
        try incoming.setStyleDefinition(style(Self.guid, "FF0000"))
        incoming.styleID = nil
        let result = try importedTable(destination.slides.import(from: source, at: 0))
        #expect(result.styleID == Self.guid)
        #expect(try TableStyleResolver(table: result, theme: destination.theme).fill(row: 0, column: 0) == .solid(Color("FF0000"), alpha: 1))
    }
    @Test func identicalStyleXmlWithDifferentDependencyBytesDoesNotReuseWrongImage() throws {
        let (source, sourceOwner, sourceDefinition) = try relationshipSource()
        let (destination, _, _) = try relationshipSource()
        let differentPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAG0lEQVR4nGP4z8DwH4SRIJoAlA8EDA0gjCEAAE9EIeGwsrFwAAAAAElFTkSuQmCC")!
        try source.package.part(at: PackURI("/ppt/media/style.png")).replaceBlob(differentPNG)
        let target = try importedTable(destination.slides[0])
        try target.setStyleDefinition(sourceDefinition, from: sourceOwner, in: source.package)
        #expect(target.styleID != Self.guid)
        #expect(try TableStyleXML.definitions(in: styles(destination).dom()).count == 2)
        let chosen = try #require(TableStyleResolver.definition(for: target.tbl, package: destination.package).0)
        let owner = try styles(destination)
        let view = TableStyleXML.drawingView(chosen, root: try owner.dom())
        let id = try #require(view.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle")?.firstChild(named: "a:fill")?.firstChild(named: "a:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"])
        let rel = try #require(owner.rels.relationship(withId: id))
        #expect(try destination.package.part(at: PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI)).blob == differentPNG)
        let idBefore = target.styleID
        try target.setStyleDefinition(sourceDefinition, from: sourceOwner, in: source.package)
        #expect(target.styleID == idBefore)
        #expect(try TableStyleXML.definitions(in: styles(destination).dom()).count == 2)
    }

}
