import Foundation
import Testing
@testable import Rostrum

@Suite struct EmbeddedFontImportTests {
    @Test func importedSlidesRetainEveryEmbeddedFamilyAndFace() throws {
        let source = try Presentation()
        let families = ["Example Sans", "Example Serif"]
        var expected: [FontFaceKey: (Data, Int)] = [:]
        for (index, family) in families.enumerated() {
            let widths = (0..<4).map { 400 + index * 40 + $0 * 100 }
            let data = widths.map { FontFaceTests.font($0, bold: false, italic: false) }
            try source.embedFont(family, faces: FontFaces(regular: data[0], bold: data[1],
                italic: data[2], boldItalic: data[3]))
            for (i, style) in [(false, false), (true, false), (false, true), (true, true)].enumerated() {
                expected[FontFaceKey(family: family, bold: style.0, italic: style.1)] = (data[i], widths[i])
            }
            let slide = try source.slides.add()
            let shape = try slide.shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(300), height: .points(100)))
            shape.textFrame?.text = "Selected family"
            shape.textFrame?.paragraphs[0].runs[0].fontName = family
        }
        let original = try source.serializedData()
        let destination = try Presentation()
        try destination.slides.importAll(from: source)
        #expect(destination.fonts.metrics(for: families[0]) == nil)
        let saved = try destination.serializedData()
        let reopened = try Presentation(data: saved)
        #expect(reopened.registerEmbeddedFonts() == families)
        for (face, expected) in expected {
            #expect(reopened.fonts.data(for: face) == expected.0)
            #expect(reopened.fonts.metrics(for: face)?.advance(of: "W") == expected.1)
        }
        #expect(try reopened.validate().isEmpty)
        #expect(try reopened.serializedData() == saved)
        #expect(try source.serializedData() == original)
    }
}

extension EmbeddedFontImportTests {
    private func deck(bold: Bool = false) throws -> Presentation {
        let deck = try Presentation()
        let data = TestFont.standard(familyName: "Example Sans")
        try deck.embedFont("Example Sans", faces: FontFaces(regular: data, bold: bold ? data : nil))
        return deck
    }
    private func list(_ deck: Presentation) throws -> XML.Element {
        try #require(deck.presentationPart.dom().firstChild(named: "p:embeddedFontLst"))
    }
    private func regular(_ deck: Presentation) throws -> XML.Element {
        try #require(list(deck).firstChild(named: "p:embeddedFont")?.firstChild(named: "p:regular"))
    }
    private func fontPart(_ deck: Presentation) throws -> Part {
        try deck.presentationPart.related(by: RelType.font, in: deck.package)
    }
    private func refuses(_ source: Presentation, into target: Presentation) throws {
        let before = try target.serializedData(), original = try source.serializedData()
        #expect(throws: RostrumError.self) { try target.slides.importAll(from: source) }
        #expect(try target.serializedData() == before)
        #expect(try source.serializedData() == original)
    }

    @Test func repeatedImportsMergeMissingFacesAndReuseExactResources() throws {
        let source = try deck(bold: true), target = try deck()
        // Family matching uses case-insensitive declared names, not filenames.
        try list(target).firstChild(named: "p:embeddedFont")?.firstChild(named: "p:font")?[attribute: "typeface"] = "EXAMPLE SANS"
        target.presentationPart.markDirty()
        let original = try fontPart(target).blob
        try target.slides.import(from: source, at: 0)
        try target.slides.importAll(from: source)
        let reopened = try Presentation(data: target.serializedData())
        #expect(try list(reopened).children(named: "p:embeddedFont").count == 1)
        #expect(reopened.presentationPart.rels.all(ofType: RelType.font).count == 2)
        #expect(reopened.package.parts.values.filter { $0.contentType == "application/x-fontdata" }.count == 2)
        #expect(try fontPart(reopened).blob == original)
        #expect(reopened.registerEmbeddedFonts() == ["EXAMPLE SANS"])
        #expect(reopened.fonts.metrics(for: "Example Sans", bold: true, italic: false) != nil)
        #expect(reopened.fonts.metrics(for: "Example Sans", bold: false, italic: true) == nil)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func conflictingFacesAndMetadataRefuseWithoutChangingAnyPackageBytes() throws {
        let source = try deck(), target = try deck()
        // A new family is staged before discovering a later conflicting face.
        try target.embedFont("Other", faces: FontFaces(regular: TestFont.standard()))
        try source.embedFont("First staged", faces: FontFaces(regular: TestFont.standard()))
        let entries = try list(source).childElements
        try list(source).replaceChildElements(with: entries.reversed())
        try fontPart(source).replaceBlob(Data("different opaque font".utf8))
        source.presentationPart.markDirty()
        try refuses(source, into: target)
        let metadataConflict = try deck()
        try list(metadataConflict).firstChild(named: "p:embeddedFont")?.firstChild(named: "p:font")?[attribute: "panose"] = "020B0604030504040204"
        metadataConflict.presentationPart.markDirty()
        try refuses(metadataConflict, into: target)
    }

    @Test(arguments: ["missing", "external", "wrongType", "wrongPart", "missingPart", "duplicateFace"])
    func invalidFontReferencesRefuseAtomically(_ kind: String) throws {
        let source = try deck(), target = try Presentation()
        let id = try #require(regular(source)[attribute: "r:id"])
        let rel = try #require(source.presentationPart.rels.relationship(withId: id))
        if kind == "duplicateFace" {
            try list(source).firstChild(named: "p:embeddedFont")?.appendElement(regular(source).deepCopy())
        } else {
            source.presentationPart.rels.remove(rId: id)
            if kind != "missing" {
                let targetURI = kind == "wrongPart" ? "slides/slide1.xml" : kind == "missingPart" ? "fonts/missing.fntdata" : rel.target
                source.presentationPart.rels.add(rId: id, type: kind == "wrongType" ? RelType.image : RelType.font,
                    target: targetURI, isExternal: kind == "external")
            }
        }
        source.presentationPart.markDirty()
        try refuses(source, into: target)
    }

    @Test func unrelatedLateSlideFailureDoesNotCommitPreparedFonts() throws {
        let source = try deck(), target = try Presentation()
        try source.slides[0].part.rels.add(type: RelType.image, target: "../media/missing.png")
        try refuses(source, into: target)
    }

    @Test func emptyImportAndSelfImportDoNotDuplicateFonts() throws {
        let source = try deck()
        let before = try source.serializedData()
        #expect(try source.slides.importAll(from: source, at: 0..<0).isEmpty)
        #expect(try source.serializedData() == before)
        try source.slides.import(from: source, at: 0)
        #expect(source.presentationPart.rels.all(ofType: RelType.font).count == 1)
        #expect(try list(source).children(named: "p:embeddedFont").count == 1)
    }

    @Test func namespaceAliasesOpaqueFontsAndExtensionGraphsArePreserved() throws {
        let source = try deck(), target = try Presentation()
        let root = try source.presentationPart.dom()
        root[attribute: "xmlns:q"] = EmbeddedFontXML.presentation
        root[attribute: "xmlns:rel"] = EmbeddedFontXML.relationships
        let fonts = try list(source)
        // Unknown data owns a cyclic dependency and an external reference.
        fonts[attribute: "xmlns:x"] = "urn:font-extension"
        fonts[attribute: "xmlns:mc"] = "http://schemas.openxmlformats.org/markup-compatibility/2006"
        fonts[attribute: "mc:Ignorable"] = "x"
        let part = source.package.addPart(uri: PackURI("/ppt/fonts/extra.xml"), contentType: "application/xml", blob: Data("<opaque/>".utf8))
        part.rels.add(rId: "cycle", type: "urn:cycle", target: "extra.xml")
        part.rels.add(rId: "link", type: "urn:external", target: "https://example.com/font", isExternal: true)
        let id = source.presentationPart.rels.add(type: "urn:font-extension", target: "fonts/extra.xml")
        fonts.appendElement(XML.Element("x:payload", attributes: [("rel:id", id), ("x:value", "intact")]))
        var stack = [fonts]
        while let node = stack.popLast() {
            if node.name.hasPrefix("p:") { node.name = "q:" + node.name.dropFirst(2) }
            if let id = node[attribute: "r:id"] { node[attribute: "r:id"] = nil; node[attribute: "rel:id"] = id }
            stack += node.childElements
        }
        // Aliased declarations must also remain measurable when readable.
        source.presentationPart.markDirty()
        #expect(source.registerEmbeddedFonts() == ["Example Sans"])
        let payload = Data("opaque compressed font data; preserve exactly".utf8)
        try fontPart(source).replaceBlob(payload)
        let original = try source.serializedData()
        try target.slides.importAll(from: source)
        try target.slides.importAll(from: source)
        let bytes = try target.serializedData(), reopened = try Presentation(data: bytes)
        #expect(try fontPart(reopened).blob == payload)
        #expect(reopened.registerEmbeddedFonts().isEmpty)
        #expect(reopened.presentationPart.rels.all(ofType: RelType.font).count == 1)
        let extraRel = try #require(reopened.presentationPart.rels.first(ofType: "urn:font-extension"))
        let extra = try reopened.package.part(at: PackURI.resolve(target: extraRel.target, relativeTo: reopened.presentationPart.uri.baseURI))
        #expect(extra.blob == part.blob)
        #expect(extra.rels.relationship(withId: "link")?.target == "https://example.com/font")
        #expect(PackURI.resolve(target: try #require(extra.rels.relationship(withId: "cycle")?.target), relativeTo: extra.uri.baseURI) == extra.uri)
        let xml = try reopened.presentationPart.dom().serialized()
        #expect(xml.contains("x:value=\"intact\""))
        #expect(xml.contains("mc:Ignorable=\"x\""))
        #expect(try reopened.serializedData() == bytes)
        #expect(try source.serializedData() == original)
    }
}


extension EmbeddedFontImportTests {
    @Test func duplicateSourceFamiliesReuseOneDeclaration() throws {
        let source = try deck(), target = try Presentation()
        // Foreign files can repeat a family declaration even though embedFont
        // now reuses it. Keep that import case explicit in this fixture.
        let fonts = try list(source)
        fonts.appendElement(try #require(fonts.firstChild(named: "p:embeddedFont")).deepCopy())
        source.presentationPart.markDirty()
        try target.slides.importAll(from: source)
        #expect(try list(target).children(named: "p:embeddedFont").count == 1)
        #expect(target.presentationPart.rels.all(ofType: RelType.font).count == 1)
    }

    @Test func inheritedCompatibilityRebindingRefusesAtomically() throws {
        let source = try deck(), target = try Presentation()
        let fonts = try list(source)
        fonts[attribute: "xmlns:x"] = "urn:source"
        fonts[attribute: "xmlns:mc"] = "http://schemas.openxmlformats.org/markup-compatibility/2006"
        fonts[attribute: "mc:Ignorable"] = "x"
        fonts.firstChild(named: "p:embeddedFont")?[attribute: "xmlns:x"] = "urn:rebound"
        source.presentationPart.markDirty()
        try refuses(source, into: target)
    }
}


extension EmbeddedFontImportTests {
    @Test func formattedDeclarationsStillMergeMissingStyles() throws {
        let source = try deck(bold: true), target = try deck()
        let fonts = try list(source)
        fonts.children.insert(.text("\n  "), at: 0)
        fonts.children.append(.text("\n"))
        let family = try #require(fonts.firstChild(named: "p:embeddedFont"))
        family.children.insert(.text("\n    "), at: 0)
        family.children.append(.text("\n  "))
        source.presentationPart.markDirty()
        try target.slides.importAll(from: source)
        #expect(target.registerEmbeddedFonts() == ["Example Sans"])
        #expect(target.fonts.metrics(for: "Example Sans", bold: true, italic: false) != nil)
        #expect(target.presentationPart.rels.all(ofType: RelType.font).count == 2)
    }

    @Test func opaqueQNameBindingsCannotBeSilentlyReused() throws {
        let source = try deck(), target = try deck()
        for (deck, namespace) in [(source, "urn:source"), (target, "urn:destination")] {
            let family = try #require(list(deck).firstChild(named: "p:embeddedFont"))
            family[attribute: "xmlns:x"] = namespace
            family[attribute: "opaque"] = "x:token"
            deck.presentationPart.markDirty()
        }
        try refuses(source, into: target)
    }
}


extension EmbeddedFontImportTests {
    @Test func newListPreservesInterleavedOpaqueMarkup() throws {
        let source = try deck(), target = try Presentation()
        try source.embedFont("Example Serif", faces: FontFaces(regular: TestFont.standard()))
        let fonts = try list(source)
        fonts[attribute: "xmlns:x"] = "urn:opaque"
        fonts.children.insert(.comment("between families"), at: 1)
        fonts.children.insert(.element(XML.Element("x:payload", children: [.text(" retain spacing ")])), at: 2)
        fonts.children.insert(.text("\n"), at: 3)
        source.presentationPart.markDirty()
        try target.slides.importAll(from: source)
        let copy = try list(target)
        #expect(copy.childElements.map(\.name) == fonts.childElements.map(\.name))
        #expect(copy.children.count == fonts.children.count)
        #expect(XML.Element("nodes", children: Array(copy.children[1...3])).serialized()
                == XML.Element("nodes", children: Array(fonts.children[1...3])).serialized())
    }
}
