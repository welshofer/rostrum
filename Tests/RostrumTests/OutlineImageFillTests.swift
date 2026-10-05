import Foundation
import Testing
@testable import Rostrum

@Suite struct OutlineImageFillTests {
    // Exact 84-byte Cell appearance recipe image, not a picture shape.
    private let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAG0lEQVR4nGP4z8DwH4SRIJoAlA8EDA0gjCEAAE9EIeGwsrFwAAAAAElFTkSuQmCC")!
    private let frame = Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(2))

    @Test func cellAppearanceImageExportsOriginalBytesWithoutPictures() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: frame)
        try table.cell(0, 0).setFill(.image(png))
        let saved = try deck.serializedData()
        let outline = deck.outline()
        #expect(outline.assetCount == 1)
        #expect(outline.slides[0].assets.first?.byteCount == 84)
        #expect(outline.slides[0].assets.first?.partName == "/ppt/media/image1.png")
        #expect(outline.warnings.isEmpty)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rostrum-fill-export-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try DeckExport.write(deck, to: directory, named: "fills")
        #expect(result.assetsWritten == 1 && result.slideFolders == 1)
        if result.assetsWritten == 1 {
            #expect(try Data(contentsOf: directory.appendingPathComponent("slide-01/image1.png")) == png)
        }
        #expect(try deck.serializedData() == saved)
        #expect(deck.outline() == outline)
        #expect(try Presentation(data: saved).outline() == outline)
    }
    private func addImage(_ deck: Presentation, owner: Part, name: String, tag: UInt8 = 0) -> (Part, String) {
        let part = deck.package.addPart(uri: PackURI("/ppt/media/" + name), contentType: ContentType.png, blob: png + Data([tag]))
        let id = owner.rels.add(type: RelType.image, target: owner.uri.relativeReference(to: part.uri))
        return (part, id)
    }
    private func style(_ content: String) throws -> XML.Element {
        try XML.parse(Data("<a:tblStyle xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" styleId=\"{22000000-0000-4000-8000-000000000022}\" styleName=\"Owned image inventory\"><a:wholeTbl><a:tcStyle>\(content)</a:tcStyle></a:wholeTbl></a:tblStyle>".utf8))
    }
    @Test func selectedStyleThemeAndDirectFillsKeepOwnersAndIgnoreUnusedRegions() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 2, columns: 2, frame: frame)
        try table.setStyleDefinition(style("<a:noFill/>"))
        let resolver = TableStyleResolver(table: table, theme: deck.theme)
        let owner = try #require(resolver.stylePart), root = try owner.dom()
        let definition = try #require(TableStyleXML.definitions(in: root).first)
        let cellStyle = try #require(definition.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle"))
        cellStyle.children = []
        let (styleImage, styleID) = addImage(deck, owner: owner, name: "Style.png", tag: 1)
        let styleFill = Fill.blipFill(rId: styleID, fit: .stretch)
        cellStyle.appendElement(XML.Element("a:fill", children: [.element(styleFill)]))
        // Aliased DrawingML names and relationship attribute are resolved by URI.
        root[attribute: "xmlns:d"] = TableStyleXML.drawing
        root[attribute: "xmlns:rel"] = TableStyleXML.relationships
        styleFill.name = "d:blipFill"
        let blip = try #require(styleFill.childElements.first)
        blip.name = "d:blip"; blip[attribute: "r:embed"] = nil; blip[attribute: "rel:embed"] = styleID
        let (_, unusedID) = addImage(deck, owner: owner, name: "unused.png", tag: 2)
        definition.appendElement(try XML.parse(Data("<a:firstRow><a:tcStyle><a:fill><a:blipFill><a:blip r:embed=\"\(unusedID)\"/></a:blipFill></a:fill></a:tcStyle></a:firstRow>".utf8)))
        table.tbl.firstChild(named: "a:tblPr")?[attribute: "firstRow"] = "0"; owner.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.partName) == [styleImage.uri.value])
        for row in 0..<2 { for col in 0..<2 { try table.cell(row, col).setFill(.none) } }
        #expect(deck.outline().assetCount == 0) // Entirely overridden style image is not exported.
        let (direct, directID) = addImage(deck, owner: slide.part, name: "direct.png", tag: 3)
        let cp = try #require(try table.cell(0, 0).tc.firstChild(named: "a:tcPr"))
        cp.removeChildren(named: "a:noFill"); cp.appendElement(Fill.blipFill(rId: directID, fit: .stretch)); slide.part.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.partName) == [direct.uri.value])
        // The selected style fillRef resolves its image through the theme part.
        for row in 0..<2 { for col in 0..<2 { try table.cell(row, col).tc.firstChild(named: "a:tcPr")?.removeChildren(named: "a:noFill") } }
        let (themeImage, themeID) = addImage(deck, owner: deck.theme.part, name: "theme.png", tag: 4)
        let matrix = try #require(try deck.theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:fillStyleLst"))
        matrix[attribute: "xmlns:themeRel"] = TableStyleXML.relationships
        let themeFill = Fill.blipFill(rId: themeID, fit: .stretch)
        themeFill.firstChild(named: "a:blip")?[attribute: "r:embed"] = nil
        themeFill.firstChild(named: "a:blip")?[attribute: "themeRel:embed"] = themeID
        matrix.children.insert(.element(themeFill), at: 0); deck.theme.part.markDirty()
        cellStyle.children = [.element(XML.Element("a:fillRef", attributes: [("idx", "1")]))]; owner.markDirty(); slide.part.markDirty()
        let before = try deck.serializedData(), result = deck.outline()
        #expect(result.slides[0].assets.map(\.partName) == [direct.uri.value, themeImage.uri.value])
        #expect(result.warnings.isEmpty)
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).outline() == result)
    }

    @Test func missingExternalAndMalformedFillRelationshipsWarnDeterministically() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 4, frame: frame)
        let external = slide.part.rels.add(type: RelType.image, target: "https://example.invalid/private.png", isExternal: true)
        let wrong = slide.part.rels.add(type: RelType.hyperlink, target: "../media/wrong.png")
        let missing = slide.part.rels.add(type: RelType.image, target: "../media/absent.png")
        for (c, id) in ["missing-id", external, wrong, missing].enumerated() {
            let properties = try #require(try table.cell(0, c).tc.firstChild(named: "a:tcPr"))
            properties.appendElement(Fill.blipFill(rId: id, fit: .stretch))
        }
        slide.part.markDirty()
        let before = try deck.serializedData(), result = deck.outline()
        #expect(result.assetCount == 0 && result.warnings.count == 4)
        #expect(result.warnings.allSatisfy { $0.contains("slide 1: /ppt/slides/slide1.xml") && $0.contains("/cell[") })
        #expect(result.warnings[0].contains("missing-id is missing"))
        #expect(result.warnings[1].contains("was not fetched"))
        #expect(result.warnings[2].contains("is malformed"))
        #expect(result.warnings[3].contains("has no image part"))
        #expect(deck.outline() == result)
        #expect(try Presentation(data: before).outline() == result)
        #expect(try deck.serializedData() == before)
    }

    @Test func picturesKeepOrderNamesAltTextAndActualPartDeduplication() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
        try table.cell(0, 0).setFill(.image(png))
        let picture = try slide.shapes.addPicture(png, frame: frame)
        picture.altText = "Original picture description"
        let original = deck.outline().slides[0].assets
        #expect(original.count == 1 && original[0].altText == "Original picture description")
        let shape = try slide.shapes.addTextBox(frame)
        let (_, id) = addImage(deck, owner: slide.part, name: "IMAGE1.PNG", tag: 7)
        let properties = try #require(shape.element.firstChild(named: "p:spPr"))
        for name in Fill.choiceNames { properties.removeChildren(named: name) }
        properties.appendElement(Fill.blipFill(rId: id, fit: .stretch)); slide.part.markDirty()
        let assets = deck.outline().slides[0].assets
        #expect(assets.count == 2 && assets[0] == original[0])
        if assets.count == 2 { #expect(assets[1].filename == "IMAGE1-2.PNG") }
    }
    private func setBackground(_ owner: Part, id: String?) throws {
        let common = try #require(try owner.dom().firstChild(named: "p:cSld"))
        common.removeChildren(named: "p:bg")
        let fill = id.map { Fill.blipFill(rId: $0, fit: .stretch) } ?? XML.Element("a:noFill")
        common.children.insert(.element(XML.Element("p:bg", children: [.element(XML.Element("p:bgPr", children: [.element(fill)]))])), at: 0)
        owner.markDirty()
    }
    @Test func backgroundAndOnlyMatchedPlaceholderInheritanceUseActualOwners() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let chain = slide.inheritanceParts
        #expect(chain.count == 3)
        let layout = chain[1], master = chain[2]
        let (masterImage, masterID) = addImage(deck, owner: master, name: "master.png", tag: 8)
        let (layoutImage, layoutID) = addImage(deck, owner: layout, name: "layout.png", tag: 9)
        try setBackground(master, id: masterID)
        #expect(deck.outline().slides[0].assets.map(\.partName) == [masterImage.uri.value])
        try setBackground(layout, id: layoutID)
        #expect(deck.outline().slides[0].assets.map(\.partName) == [layoutImage.uri.value])
        try setBackground(slide.part, id: nil)
        #expect(deck.outline().assetCount == 0)
        let shape = try slide.shapes.addTextBox(frame)
        let properties = try #require(shape.element.firstChild(named: "p:spPr"))
        properties.removeChildren(named: "a:noFill")
        let nonvisual = try #require(shape.element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr"))
        nonvisual.appendElement(XML.Element("p:ph", attributes: [("idx", "42"), ("type", "body")]))
        let layoutShape = shape.element.deepCopy()
        let inheritedProperties = try #require(layoutShape.firstChild(named: "p:spPr"))
        inheritedProperties.appendElement(Fill.blipFill(rId: layoutID, fit: .stretch))
        try Slide.spTree(of: layout).appendElement(layoutShape)
        let unrelated = layoutShape.deepCopy()
        Placeholders.phElement(of: unrelated)?[attribute: "idx"] = "43"
        unrelated.firstChild(named: "p:spPr")?.firstChild(named: "a:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"] = "bad-unrelated-template"
        try Slide.spTree(of: layout).appendElement(unrelated); layout.markDirty(); slide.part.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.partName) == [layoutImage.uri.value])
        #expect(deck.outline().warnings.isEmpty)
        properties.appendElement(XML.Element("a:noFill")); slide.part.markDirty()
        #expect(deck.outline().assetCount == 0)
        properties.removeChildren(named: "a:noFill"); inheritedProperties.removeChildren(named: "a:blipFill")
        let masterShape = layoutShape.deepCopy()
        Placeholders.phElement(of: masterShape)?[attribute: "type"] = "body"
        masterShape.firstChild(named: "p:spPr")?.appendElement(Fill.blipFill(rId: masterID, fit: .stretch))
        let tree = try Slide.spTree(of: master)
        tree.children.removeAll { if case .element(let e) = $0 { return Placeholders.phElement(of: e)?[attribute: "type"] == "body" }; return false }
        tree.appendElement(masterShape); master.markDirty(); layout.markDirty()
        let before = try deck.serializedData(), result = deck.outline()
        #expect(result.slides[0].assets.map(\.partName) == [masterImage.uri.value])
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).outline() == result)
    }

    @Test func activeFurnitureGroupSelectionAndAliasedCellFillAreBounded() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let (_, ownID) = addImage(deck, owner: slide.part, name: "group.png", tag: 10)
        let child = try slide.shapes.addTextBox(frame)
        let childProperties = try #require(child.element.firstChild(named: "p:spPr"))
        let tree = try Slide.spTree(of: slide.part)
        tree.children.removeAll { if case .element(let e) = $0 { return e === child.element }; return false }
        let group = XML.Element("p:grpSp", children: [.element(XML.Element("p:nvGrpSpPr")),
            .element(XML.Element("p:grpSpPr", children: [.element(Fill.blipFill(rId: ownID, fit: .stretch))])), .element(child.element)])
        tree.appendElement(group); slide.part.markDirty()
        #expect(deck.outline().assetCount == 0) // Unused group resource.
        childProperties.removeChildren(named: "a:noFill"); childProperties.appendElement(XML.Element("a:grpFill")); slide.part.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.filename) == ["group.png"])
        // Namespace declarations on the property container, not only the part root.
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
        let (_, aliasID) = addImage(deck, owner: slide.part, name: "alias.png", tag: 11)
        let cp = try #require(try table.cell(0, 0).tc.firstChild(named: "a:tcPr"))
        cp[attribute: "xmlns:d"] = TableStyleXML.drawing; cp[attribute: "xmlns:rel"] = TableStyleXML.relationships
        cp.appendElement(try XML.parse(Data("<d:blipFill><d:blip rel:embed=\"\(aliasID)\"/></d:blipFill>".utf8))); slide.part.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.filename) == ["group.png", "alias.png"])
        let master = slide.inheritanceParts[2]
        let (_, furnitureID) = addImage(deck, owner: master, name: "furniture.png", tag: 12)
        let decoration = child.element.deepCopy()
        let dp = try #require(decoration.firstChild(named: "p:spPr")); dp.children = [.element(Fill.blipFill(rId: furnitureID, fit: .stretch))]
        try Slide.spTree(of: master).appendElement(decoration); master.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.filename) == ["group.png", "alias.png", "furniture.png"])
        try slide.part.dom()[attribute: "showMasterSp"] = "0"; slide.part.markDirty()
        let before = try deck.serializedData(), result = deck.outline()
        #expect(result.slides[0].assets.map(\.filename) == ["group.png", "alias.png"])
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).outline() == result)
    }
    @Test func ancestorNamespaceBindingsShadowingAndLookalikesRemainDistinct() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let (image, id) = addImage(deck, owner: slide.part, name: "scoped.png", tag: 13)
        let common = try #require(try slide.part.dom().firstChild(named: "p:cSld"))
        common[attribute: "xmlns:rel"] = TableStyleXML.relationships
        try setBackground(slide.part, id: id)
        let backgroundBlip = try #require(common.firstChild(named: "p:bg")?.firstChild(named: "p:bgPr")?.firstChild(named: "a:blipFill")?.firstChild(named: "a:blip"))
        backgroundBlip[attribute: "r:embed"] = nil; backgroundBlip[attribute: "rel:embed"] = id
        #expect(deck.outline().slides[0].assets.map(\.partName) == [image.uri.value])
        try setBackground(slide.part, id: nil)
        let shape = try slide.shapes.addTextBox(frame)
        let properties = try #require(shape.element.firstChild(named: "p:spPr"))
        properties.removeChildren(named: "a:noFill")
        properties.appendElement(try XML.parse(Data("<a:blipFill><a:blip rel:embed=\"\(id)\"/></a:blipFill>".utf8)))
        #expect(deck.outline().slides[0].assets.map(\.partName) == [image.uri.value])
        let blip = try #require(properties.firstChild(named: "a:blipFill")?.firstChild(named: "a:blip"))
        blip[attribute: "xmlns:rel"] = "urn:lookalike"
        #expect(deck.outline().assetCount == 0)
        #expect(deck.outline().warnings.count == 1)
        properties.removeChildren(named: "a:blipFill")
        properties.appendElement(try XML.parse(Data("<other:blipFill xmlns:other=\"urn:lookalike\"><other:blip rel:embed=\"\(id)\"/></other:blipFill>".utf8)))
        #expect(deck.outline().assetCount == 0 && deck.outline().warnings.isEmpty)
    }

    @Test func structuralDrawingAliasesAndOrdinaryPictureFailuresAreReadOnly() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
        try table.cell(0, 0).setFill(.image(png))
        table.tbl[attribute: "xmlns:d"] = TableStyleXML.drawing
        TableStyleXML.walk(table.tbl) { node, scope in
            if TableStyleXML.expanded(node.name, namespaces: scope).hasPrefix("{\(TableStyleXML.drawing)}") {
                node.name = "d:" + String(node.name.split(separator: ":").last!)
            }
        }
        slide.part.markDirty()
        #expect(deck.outline().assetCount == 1)
        let picture = try slide.shapes.addPicture(png, frame: frame)
        let blip = try #require(picture.element.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip"))
        blip[attribute: "r:embed"] = "missing-picture-id"; slide.part.markDirty()
        let saved = try deck.serializedData(), result = deck.outline()
        #expect(result.assetCount == 1 && result.warnings.count == 1)
        #expect(result.warnings[0].contains("/picture: image relationship missing-picture-id is missing"))
        #expect(try deck.serializedData() == saved)
        #expect(try Presentation(data: saved).outline() == result)
    }
    @Test func inlineAndTableBackgroundFillsRespectExplicitOverrides() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
        let (cellImage, cellID) = addImage(deck, owner: slide.part, name: "inline.png", tag: 14)
        let (backgroundImage, backgroundID) = addImage(deck, owner: slide.part, name: "table-background.png", tag: 15)
        let definition = try style("<a:fill><a:blipFill><a:blip r:embed=\"\(cellID)\"/></a:blipFill></a:fill>")
        definition.name = "a:tableStyle"
        let background = XML.Element("a:tblBg", children: [.element(XML.Element("a:fill", children: [.element(Fill.blipFill(rId: backgroundID, fit: .stretch))]))])
        definition.children.insert(.element(background), at: 0)
        let properties = try #require(table.tbl.firstChild(named: "a:tblPr"))
        properties.removeChildren(named: "a:tableStyleId"); properties.appendElement(definition); slide.part.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.partName) == [backgroundImage.uri.value, cellImage.uri.value])
        try table.cell(0, 0).setFill(.none)
        #expect(deck.outline().slides[0].assets.map(\.partName) == [backgroundImage.uri.value])
        properties.appendElement(XML.Element("a:noFill")); slide.part.markDirty()
        #expect(deck.outline().assetCount == 0)
        properties.removeChildren(named: "a:noFill")
        let (themed, themeID) = addImage(deck, owner: deck.theme.part, name: "theme-background.png", tag: 16)
        let fills = try #require(try deck.theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:bgFillStyleLst"))
        fills.children.insert(.element(Fill.blipFill(rId: themeID, fit: .stretch)), at: 0)
        background.children = [.element(XML.Element("a:fillRef", attributes: [("idx", "1001")]))]
        slide.part.markDirty(); deck.theme.part.markDirty()
        let saved = try deck.serializedData(), result = deck.outline()
        #expect(result.slides[0].assets.map(\.partName) == [themed.uri.value])
        #expect(try deck.serializedData() == saved)
        #expect(try Presentation(data: saved).outline() == result)
    }

    @Test func onlyValidatedMergeContinuationsSuppressCellResources() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 2, frame: frame)
        try table.cell(0, 1).setFill(.image(png))
        try table.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2)
        #expect(deck.outline().assetCount == 0)
        // Malformed topology uses the same ordinary-cell fallback as rendering.
        try table.cell(0, 0).tc[attribute: "gridSpan"] = nil; slide.part.markDirty()
        let saved = try deck.serializedData(), result = deck.outline()
        #expect(result.assetCount == 1)
        #expect(try deck.serializedData() == saved)
        #expect(try Presentation(data: saved).outline() == result)
    }

    @Test func placeholderGroupFillRetainsTheGroupRelationshipOwner() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let (groupImage, groupID) = addImage(deck, owner: slide.part, name: "selected-group.png", tag: 17)
        let layout = slide.inheritanceParts[1]
        let (_, collisionID) = addImage(deck, owner: layout, name: "wrong-owner.png", tag: 18)
        #expect(groupID == collisionID) // Same rId, distinct owning parts.
        let child = try slide.shapes.addTextBox(frame)
        child.element.firstChild(named: "p:spPr")?.removeChildren(named: "a:noFill")
        let nv = try #require(child.element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr"))
        nv.appendElement(XML.Element("p:ph", attributes: [("idx", "999"), ("type", "body")]))
        let placeholder = child.element.deepCopy()
        placeholder.firstChild(named: "p:spPr")?.appendElement(XML.Element("a:grpFill"))
        try Slide.spTree(of: layout).appendElement(placeholder); layout.markDirty()
        let tree = try Slide.spTree(of: slide.part)
        tree.children.removeAll { if case .element(let e) = $0 { return e === child.element }; return false }
        tree.appendElement(XML.Element("p:grpSp", children: [.element(XML.Element("p:nvGrpSpPr")),
            .element(XML.Element("p:grpSpPr", children: [.element(Fill.blipFill(rId: groupID, fit: .stretch))])), .element(child.element)]))
        slide.part.markDirty()
        let saved = try deck.serializedData(), result = deck.outline()
        #expect(result.slides[0].assets.map(\.partName) == [groupImage.uri.value])
        #expect(result.warnings.isEmpty)
        #expect(try deck.serializedData() == saved)
        #expect(try Presentation(data: saved).outline() == result)
    }

    @Test func malformedOrdinaryPicturesNeverExportTheTargetAsAnImage() throws {
        for external in [false, true] {
            let deck = try Presentation(), slide = try deck.slides[0]
            let picture = try slide.shapes.addPicture(png, frame: frame)
            let part = try #require(picture.imagePart)
            let id = slide.part.rels.add(type: external ? RelType.image : RelType.hyperlink,
                target: slide.part.uri.relativeReference(to: part.uri), isExternal: external)
            picture.element.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"] = id
            slide.part.markDirty()
            let saved = try deck.serializedData(), result = deck.outline()
            #expect(result.assetCount == 0 && result.warnings.count == 1)
            #expect(result.warnings[0].contains(external ? "was not fetched" : "is malformed"))
            #expect(try deck.serializedData() == saved)
        }
    }

    private func aliasPresentation(_ element: XML.Element, uri: String = "http://schemas.openxmlformats.org/presentationml/2006/main") {
        element[attribute: "xmlns:q"] = uri
        func rename(_ node: XML.Element) {
            if node.name.hasPrefix("p:") { node.name = "q:" + node.name.dropFirst(2) }
            for child in node.childElements { rename(child) }
        }
        rename(element)
    }

    @Test func presentationAliasesPreserveHiddenAndInheritedPlaceholderSelection() throws {
        for alias in [false, true] {
            let deck = try Presentation(), slide = try deck.slides[0]
            let shape = try slide.shapes.addTextBox(frame)
            let (_, id) = addImage(deck, owner: slide.part, name: "hidden.png")
            shape.element.firstChild(named: "p:spPr")?.children = [.element(Fill.blipFill(rId: id, fit: .stretch))]
            shape.element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "hidden"] = "true"
            let picture = try slide.shapes.addPicture(png, frame: frame)
            picture.element.firstChild(named: "p:nvPicPr")?.firstChild(named: "p:cNvPr")?[attribute: "hidden"] = "1"
            picture.element.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"] = "hidden-unused"
            let layout = slide.inheritanceParts[1]
            let (_, layoutID) = addImage(deck, owner: layout, name: "unused-placeholder.png")
            let placeholder = shape.element.deepCopy()
            placeholder.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "hidden"] = nil
            placeholder.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.appendElement(XML.Element("p:ph", attributes: [("idx", "901")]))
            placeholder.firstChild(named: "p:spPr")?.children = [.element(Fill.blipFill(rId: layoutID, fit: .stretch))]
            try Slide.spTree(of: layout).appendElement(placeholder)
            if alias { aliasPresentation(shape.element); aliasPresentation(picture.element); aliasPresentation(placeholder) }
            slide.part.markDirty(); layout.markDirty()
            let saved = try deck.serializedData(), result = deck.outline()
            #expect(result.assetCount == 0 && result.warnings.isEmpty)
            #expect(try deck.serializedData() == saved)
            #expect(try Presentation(data: saved).outline() == result)
        }
    }

    @Test func aliasedMatchedPlaceholdersAndLookalikesKeepSelectionBounded() throws {
        let deck = try Presentation(), slide = try deck.slides[0], layout = slide.inheritanceParts[1]
        let shape = try slide.shapes.addTextBox(frame)
        shape.element.firstChild(named: "p:spPr")?.children = []
        shape.element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.appendElement(XML.Element("p:ph", attributes: [("idx", "902")]))
        let placeholder = shape.element.deepCopy()
        let (image, id) = addImage(deck, owner: layout, name: "matched.png")
        placeholder.firstChild(named: "p:spPr")?.appendElement(Fill.blipFill(rId: id, fit: .stretch))
        try Slide.spTree(of: layout).appendElement(placeholder)
        aliasPresentation(shape.element); aliasPresentation(placeholder)
        slide.part.markDirty(); layout.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.partName) == [image.uri.value])
        shape.element.firstChild(named: "q:spPr")?.appendElement(XML.Element("a:noFill"))
        #expect(deck.outline().assetCount == 0)
        shape.element.firstChild(named: "q:spPr")?.removeChildren(named: "a:noFill")
        placeholder[attribute: "xmlns:q"] = "urn:lookalike"
        #expect(deck.outline().assetCount == 0)
        shape.element[attribute: "xmlns:q"] = "urn:lookalike"
        #expect(deck.outline().assetCount == 0 && deck.outline().warnings.isEmpty)
    }

    @Test func fullyAliasedBackgroundsSelectActualOwnerAndRespectNoFill() throws {
        let deck = try Presentation(), slide = try deck.slides[0], layout = slide.inheritanceParts[1]
        let (image, id) = addImage(deck, owner: layout, name: "aliased-background.png")
        try setBackground(layout, id: id)
        let common = try #require(try layout.dom().firstChild(named: "p:cSld"))
        aliasPresentation(common); layout.markDirty()
        #expect(deck.outline().slides[0].assets.map(\.partName) == [image.uri.value])
        try setBackground(slide.part, id: nil)
        let local = try #require(try slide.part.dom().firstChild(named: "p:cSld"))
        aliasPresentation(local); slide.part.markDirty()
        #expect(deck.outline().assetCount == 0)
        local.firstChild(named: "q:bg")?[attribute: "xmlns:q"] = "urn:lookalike"
        slide.part.markDirty()
        let saved = try deck.serializedData(), result = deck.outline()
        #expect(result.slides[0].assets.map(\.partName) == [image.uri.value])
        #expect(result.warnings.isEmpty)
        #expect(try deck.serializedData() == saved)
        #expect(try Presentation(data: saved).outline() == result)
    }

    @Test func directCellFillInventoryUsesLastOverlayInLiveDocumentOrder() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
        let (image, id) = addImage(deck, owner: slide.part, name: "last-overlay.png")
        let properties = try #require(try table.cell(0, 0).tc.firstChild(named: "a:tcPr"))
        let imageFill = Fill.blipFill(rId: id, fit: .stretch), none = XML.Element("a:noFill")
        for imageLast in [false, true, false] {
            properties.children = imageLast ? [.element(none), .element(imageFill)] : [.element(imageFill), .element(none)]
            slide.part.markDirty()
            let saved = try deck.serializedData(), result = deck.outline()
            #expect(result.slides[0].assets.map(\.partName) == (imageLast ? [image.uri.value] : []))
            let effective = TableStyleResolver(table: table, theme: deck.theme).effective(row: 0, column: 0)
            #expect((effective.properties.firstChild(named: "a:blipFill") != nil) == imageLast)
            #expect(try deck.serializedData() == saved)
            #expect(try Presentation(data: saved).outline() == result)
        }
    }

    @Test func tableThemeReferencesShareNamespaceAwareStructuralSelection() throws {
        for prefix in ["d:", ""] {
            let deck = try Presentation(), slide = try deck.slides[0]
            let table = try slide.shapes.addTable(rows: 2, columns: 2, frame: frame)
            try table.setStyleDefinition(style("<a:fillRef idx=\"1\"/>"))
            let theme = deck.theme.part, root = try theme.dom()
            let elements = try #require(root.firstChild(named: "a:themeElements"))
            let scheme = try #require(elements.firstChild(named: "a:fmtScheme"))
            let list = try #require(scheme.firstChild(named: "a:fillStyleLst"))
            let (image, id) = addImage(deck, owner: theme, name: "aliased-theme.png")
            let fill = Fill.blipFill(rId: id, fit: .stretch)
            let blip = try #require(fill.firstChild(named: "a:blip"))
            blip[attribute: "r:embed"] = nil; blip[attribute: "scoped:embed"] = id
            list.children = [.element(fill)]
            root[attribute: "xmlns:scoped"] = TableStyleXML.relationships
            elements[attribute: prefix.isEmpty ? "xmlns" : "xmlns:d"] = TableStyleXML.drawing
            func rename(_ node: XML.Element) {
                if node.name.hasPrefix("a:") { node.name = prefix + node.name.dropFirst(2) }
                for child in node.childElements { rename(child) }
            }
            rename(elements); theme.markDirty()
            #expect(deck.outline().slides[0].assets.map(\.partName) == [image.uri.value])
            let shape = try slide.shapes.addTextBox(frame)
            shape.element.firstChild(named: "p:spPr")?.children = []
            shape.element.appendElement(XML.Element("p:style", children: [.element(XML.Element("a:fillRef", attributes: [("idx", "1")]))]))
            slide.part.markDirty()
            #expect(deck.outline().slides[0].assets.map(\.partName) == [image.uri.value])
            list[attribute: "xmlns:scoped"] = "urn:lookalike"
            #expect(deck.outline().assetCount == 0 && !deck.outline().warnings.isEmpty)
            list[attribute: "xmlns:scoped"] = TableStyleXML.relationships
            let saved = try deck.serializedData(), result = deck.outline()
            #expect(result.slides[0].assets.map(\.partName) == [image.uri.value] && result.warnings.isEmpty)
            #expect(try deck.serializedData() == saved)
            #expect(try Presentation(data: saved).outline() == result)
            list[attribute: prefix.isEmpty ? "xmlns" : "xmlns:d"] = "urn:not-drawingml"
            #expect(deck.outline().assetCount == 0)
        }
    }

    @Test func tableBackgroundThemeAliasesResolveBeforeOwnerSelection() throws {
        for prefix in ["d:", ""] {
            let deck = try Presentation(), slide = try deck.slides[0]
            try setBackground(slide.part, id: nil) // Isolate the table from the slide's default theme background.
            let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
            try table.setStyleDefinition(style("<a:noFill/>"))
            let resolver = TableStyleResolver(table: table, theme: deck.theme)
            let owner = try #require(resolver.stylePart)
            let definition = try #require(TableStyleXML.definitions(in: try owner.dom()).first)
            let background = XML.Element("a:tblBg", children: [.element(XML.Element("a:fillRef", attributes: [("idx", "1001")]))])
            definition.appendElement(background); owner.markDirty()
            let (wrong, ownerID) = addImage(deck, owner: owner, name: "background-wrong-owner.png")
            let (expected, themeID) = addImage(deck, owner: deck.theme.part, name: "background-theme.png")
            #expect(ownerID == themeID && wrong.uri != expected.uri)
            let themeRoot = try deck.theme.part.dom()
            let elements = try #require(themeRoot.firstChild(named: "a:themeElements"))
            let list = try #require(elements.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:bgFillStyleLst"))
            list.children = [.element(Fill.blipFill(rId: themeID, fit: .stretch))]
            elements[attribute: prefix.isEmpty ? "xmlns" : "xmlns:d"] = TableStyleXML.drawing
            func rename(_ node: XML.Element) {
                if node.name.hasPrefix("a:") { node.name = prefix + node.name.dropFirst(2) }
                for child in node.childElements { rename(child) }
            }
            rename(elements); deck.theme.part.markDirty()
            #expect(deck.outline().slides[0].assets.map(\.partName) == [expected.uri.value])
            background.children.insert(.element(XML.Element("a:fill", children: [.element(XML.Element("a:noFill"))])), at: 0)
            #expect(deck.outline().assetCount == 0)
            background.firstChild(named: "a:fill")?.children = [.element(Fill.blipFill(rId: ownerID, fit: .stretch))]
            #expect(deck.outline().slides[0].assets.map(\.partName) == [wrong.uri.value])
            let properties = try #require(table.tbl.firstChild(named: "a:tblPr"))
            properties.appendElement(XML.Element("a:noFill")); slide.part.markDirty()
            #expect(deck.outline().assetCount == 0)
            properties.removeChildren(named: "a:noFill")
            let (direct, directID) = addImage(deck, owner: slide.part, name: "background-direct.png")
            properties.appendElement(Fill.blipFill(rId: directID, fit: .stretch)); slide.part.markDirty()
            #expect(deck.outline().slides[0].assets.map(\.partName) == [direct.uri.value])
            properties.removeChildren(named: "a:blipFill"); background.removeChildren(named: "a:fill")
            slide.part.markDirty(); owner.markDirty()
            let saved = try deck.serializedData(), result = deck.outline()
            #expect(result.slides[0].assets.map(\.partName) == [expected.uri.value] && result.warnings.isEmpty)
            #expect(try deck.serializedData() == saved)
            #expect(try Presentation(data: saved).outline() == result)
        }
    }

}
