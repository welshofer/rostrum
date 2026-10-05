import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGInheritedDefaultsReuseTests {
    private func fixture() throws -> (Presentation, [Shape], Part, XML.Element) {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        var shapes: [Shape] = []
        for index in 0..<3 {
            let shape = try slide.shapes.addTextBox(Rect(x: .points(Double(index * 200)), y: .points(20), width: .points(180), height: .points(100)))
            shape.textFrame?.text = "ordinary \(index)"
            shapes.append(shape)
        }
        let master = try #require(slide.master).part
        let style = try master.dom().getOrAddChild("p:txStyles").getOrAddChild("p:otherStyle")
        style.children = try XML.parse(Data("""
        <p:otherStyle><a:lvl1pPr><a:buFont typeface="InheritedAlias"/><a:buChar char="•"/>
        <a:defRPr sz="1400"><a:solidFill><a:srgbClr val="123456"/></a:solidFill><a:latin typeface="InheritedAlias"/></a:defRPr>
        <a:extLst><a:ext uri="keep"><future:payload xmlns:future="urn:reuse">unchanged</future:payload></a:ext></a:extLst>
        </a:lvl1pPr></p:otherStyle>
        """.utf8)).children
        master.markDirty()
        return (deck, shapes, master, style)
    }

    private func renderer(_ deck: Presentation) throws -> SVGRenderer {
        let slide = try deck.slides[0]
        return SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
    }

    @discardableResult
    private func check(_ reused: SVGRenderer, _ deck: Presentation) throws -> String {
        let before = try deck.serializedData()
        let actual = try reused.render(pixelWidth: 640)
        let fresh = try renderer(deck).render(pixelWidth: 640)
        #expect(actual.svg == fresh.svg)
        #expect(actual.problems == fresh.problems)
        #expect(try deck.serializedData() == before)
        return actual.svg
    }

    @Test(arguments: [false, true])
    func directAndAliasedMasterEditsStayLiveAcrossRenderCalls(registered: Bool) throws {
        let (deck, shapes, master, style) = try fixture()
        if registered { try deck.fonts.register(FontFaceTests.font(400, bold: false, italic: false), aliases: ["InheritedAlias"]) }
        let reused = try renderer(deck)
        let first = try check(reused, deck)
        #expect(first.contains("#123456") && first.contains("font-size=\"14\""))
        let level = try #require(style.firstChild(named: "a:lvl1pPr"))
        let shared = try #require(level.firstChild(named: "a:defRPr"))
        let alias = XML.Element("future:alias", attributes: [("xmlns:future", "urn:reuse")], children: [.element(shared)])
        style.appendElement(alias)
        shared[attribute: "sz"] = "2200"
        shared.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"] = "654321"
        master.markDirty()
        let second = try check(reused, deck)
        #expect(second != first && second.contains("#654321") && second.contains("font-size=\"22\""))
        #expect(alias.firstChild(named: "a:defRPr") === shared)
        #expect(style.serialized().contains("unchanged") && level.firstChild(named: "a:buChar")?[attribute: "char"] == "•")
        // Local properties on one shape must not become defaults for its siblings.
        let run = try #require(shapes[1].textFrame?.paragraphs.first?.runs.first)
        run.fontSize = 30
        let third = try check(reused, deck)
        #expect(third.contains("font-size=\"30\"") && third.contains("font-size=\"22\""))
        if registered {
            try deck.fonts.register(FontFaceTests.font(700, bold: false, italic: false), aliases: ["InheritedAlias"])
            #expect(try check(reused, deck) != third)
        }
    }

    @Test func missingResourcesAndChangedRelationshipsDoNotRetainAnEmptyOrOldResult() throws {
        let (deck, _, master, _) = try fixture()
        let slide = try deck.slides[0]
        let layout = try slide.part.related(by: RelType.slideLayout, in: deck.package)
        let relationship = try #require(slide.part.rels.first(ofType: RelType.slideLayout))
        let reused = try renderer(deck)
        let initial = try check(reused, deck)
        slide.part.rels.remove(rId: relationship.rId)
        let absent = try check(reused, deck)
        #expect(absent != initial)
        slide.part.rels.add(rId: relationship.rId, type: relationship.type, target: relationship.target)
        #expect(try check(reused, deck) == initial)
        let masterRelationship = try #require(layout.rels.first(ofType: RelType.slideMaster))
        let replacement = deck.package.addPart(uri: PackURI("/ppt/slideMasters/reuse-test.xml"), contentType: master.contentType, blob: Data(try master.dom().serialized().utf8))
        replacement.rels.setItems(master.rels.items)
        let replacementStyle = try #require(replacement.dom().firstChild(named: "p:txStyles")?.firstChild(named: "p:otherStyle"))
        replacementStyle.firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr")?[attribute: "sz"] = "2700"
        replacement.markDirty()
        layout.rels.remove(rId: masterRelationship.rId)
        layout.rels.add(rId: masterRelationship.rId, type: masterRelationship.type, target: replacement.uri.value)
        let changed = try check(reused, deck)
        #expect(changed != initial && changed.contains("font-size=\"27\""))
        let bytes = replacement.blob, relationships = replacement.rels.items
        deck.package.removePart(at: replacement.uri)
        #expect(try check(reused, deck) != changed)
        let restored = deck.package.addPart(uri: replacement.uri, contentType: replacement.contentType, blob: bytes)
        restored.rels.setItems(relationships)
        #expect(try check(reused, deck) == changed)
        // An existing master with no ordinary style is another legitimate nil result.
        let styles = try #require(restored.dom().firstChild(named: "p:txStyles"))
        let other = try #require(styles.firstChild(named: "p:otherStyle"))
        styles.removeChildren(named: "p:otherStyle"); restored.markDirty()
        #expect(try check(reused, deck) != changed)
        styles.appendElement(other); restored.markDirty()
        #expect(try check(reused, deck) == changed)
    }

    @Test func placeholdersAndInheritedFurnitureKeepTheirOwnOwnerAndStyles() throws {
        let (deck, shapes, master, _) = try fixture()
        let slide = try deck.slides[0]
        let placeholder = shapes[1].element
        placeholder.getOrAddChild("p:nvSpPr").getOrAddChild("p:nvPr").appendElement(XML.Element("p:ph", attributes: [("type", "body"), ("idx", "7")]))
        let layout = try slide.part.related(by: RelType.slideLayout, in: deck.package)
        let layoutShape = placeholder.deepCopy()
        let list = try #require(layoutShape.firstChild(named: "p:txBody")).getOrAddChild("a:lstStyle")
        list.children = try XML.parse(Data("<a:lstStyle><a:lvl1pPr><a:defRPr sz=\"2600\"><a:solidFill><a:srgbClr val=\"ABCDEF\"/></a:solidFill></a:defRPr></a:lvl1pPr></a:lstStyle>".utf8)).children
        try #require(Slide.existingSpTree(of: layout)).appendElement(layoutShape)
        let furniture = shapes[0].element.deepCopy()
        try #require(Slide.existingSpTree(of: master)).appendElement(furniture)
        layout.markDirty(); master.markDirty(); slide.part.markDirty()
        let reused = try renderer(deck)
        let first = try check(reused, deck)
        #expect(first.contains("#ABCDEF") && first.contains("#123456"))
        list.firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr")?[attribute: "sz"] = "3200"
        layout.markDirty()
        let second = try check(reused, deck)
        #expect(second != first && second.contains("font-size=\"32\""))
        #expect(Placeholders.phElement(of: furniture) == nil)
    }

    @Test func notesRetainTheirSeparateContextWhenRendererIsReused() throws {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let deck = try Presentation(contentsOf: root.appendingPathComponent("NotesGeometry/geometry-source.pptx"))
        let context = try NotesPageRenderContext(presentation: deck, slide: deck.slides[0], index: 0, pixelWidth: 640)
        let size = try NotesPageTemplate.pageSize(in: deck.presentationPart.dom())
        func make() -> SVGRenderer {
            SVGRenderer(slidePart: context.notes, slideSize: (EMU(size.0), EMU(size.1)), theme: context.theme,
                package: deck.package, fonts: deck.fonts, slideNumber: 1, notesContext: context)
        }
        let reused = make(), before = try deck.serializedData()
        let first = try reused.render(pixelWidth: 640)
        #expect(first.svg == (try deck.renderNotesSVG(slideAt: 0, pixelWidth: 640)))
        let body = try #require(Slide.existingSpTree(of: context.notes)?.childElements.first { NotesPageRenderContext.placeholderType($0) == "body" })
        let paragraph = try #require(body.firstChild(named: "p:txBody")?.firstChild(named: "a:p"))
        paragraph.appendElement(XML.Element("a:r", children: [.element(XML.Element("a:t", children: [.text(" live notes edit")]))]))
        let second = try reused.render(pixelWidth: 640), fresh = try make().render(pixelWidth: 640)
        #expect(second.svg != first.svg && second.svg == fresh.svg && second.problems == fresh.problems)
        #expect(second.svg.contains("live notes edit"))
        #expect(try deck.serializedData() == before)
    }
}
