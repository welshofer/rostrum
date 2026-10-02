import Foundation
import Testing
@testable import Rostrum

@Suite struct NotesPageRendererTests {
    private func fixture(_ name: String) throws -> Presentation {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try Presentation(contentsOf: root.appendingPathComponent(name))
    }
    private func parts(_ deck: Presentation) throws -> (Part, Part) {
        let notes = try deck.slides[0].part.related(by: RelType.notesSlide, in: deck.package)
        return (notes, try notes.related(by: RelType.notesMaster, in: deck.package))
    }
    private func shape(_ owner: Part, type: String) throws -> XML.Element {
        try #require(Slide.existingSpTree(of: owner)?.childElements.first { NotesPageRenderContext.placeholderType($0) == type })
    }

    @Test func missingNotesAndInvalidDimensionsNeverCreateOrModifyParts() throws {
        let deck = try Presentation()
        let before = try deck.serializedData()
        #expect(throws: (any Error).self) { try deck.renderNotesSVG(slideAt: 0) }
        #expect(try deck.serializedData() == before)
        try deck.slides[0].setNotes("hello")
        let size = try #require(deck.presentationPart.dom().firstChild(named: "p:notesSz"))
        size[attribute: "cx"] = "0"; deck.presentationPart.markDirty()
        let invalid = try deck.serializedData()
        #expect(throws: (any Error).self) { try deck.renderNotesSVG(slideAt: 0) }
        #expect(try deck.serializedData() == invalid)
    }

    @Test func sourceSizeBackgroundAndGeometryAreReadWithoutMutation() throws {
        let deck = try fixture("NotesGeometry/geometry-source.pptx")
        let before = try deck.serializedData()
        let result = try deck.renderNotesSVGReportingProblems(slideAt: 0, pixelWidth: 750)
        #expect(result.svg.contains("width=\"750\" height=\"1000\" viewBox=\"0 0 6858000 9144000\""))
        #expect(result.svg.contains("#EDF2F7"))
        #expect(result.svg.contains("<image x=\"1371600\" y=\"914400\" width=\"4114800\" height=\"2743200\""))
        #expect(result.svg.contains("translate(1028700,"))
        #expect(result.svg.contains("Geometry-preserving"))
        #expect(!result.problems.masterUnresolved && !result.problems.layoutUnresolved)
        #expect(result.svg == (try deck.renderNotesSVG(slideAt: 0, pixelWidth: 750)))
        #expect(try deck.serializedData() == before)
        _ = try XML.parse(Data(result.svg.utf8))
    }

    @Test(arguments: ["geometry", "type-index-inherited", "type-index-local"])
    func importedPagesKeepSourceAppearanceAndTypeBasedAncestry(_ prefix: String) throws {
        let source = try fixture("NotesGeometry/\(prefix)-source.pptx")
        let imported = try fixture("NotesGeometry/\(prefix)-imported.pptx")
        #expect(try source.renderNotesSVG(slideAt: 0) == imported.renderNotesSVG(slideAt: 1))
        if prefix == "geometry" {
            let target = try fixture("NotesGeometry/geometry-target-before.pptx")
            #expect(try target.renderNotesSVG(slideAt: 0) == imported.renderNotesSVG(slideAt: 0))
        }
    }

    @Test func namespaceAliasesAndForeignLookalikesDoNotChangePlaceholderSelection() throws {
        let deck = try fixture("NotesGeometry/geometry-source.pptx")
        let expected = try deck.renderNotesSVG(slideAt: 0)
        let (notes, master) = try parts(deck)
        for part in [notes, master] {
            var xml = try part.dom().serialized().replacingOccurrences(of: "<p:", with: "<q:").replacingOccurrences(of: "</p:", with: "</q:")
                .replacingOccurrences(of: "xmlns:p=", with: "xmlns:q=")
                .replacingOccurrences(of: "a:", with: "draw:").replacingOccurrences(of: "xmlns:a=", with: "xmlns:draw=")
            xml = xml.replacingOccurrences(of: "<q:spPr>", with: "<q:spPr><fake:xfrm xmlns:fake=\"urn:foreign\"><fake:off x=\"1\" y=\"2\"/></fake:xfrm>")
            part.replaceBlob(Data(xml.utf8))
        }
        #expect(try deck.renderNotesSVG(slideAt: 0) == expected)
    }

    @Test func partialLocalTransformAndTextStylesOverrideMasterIndependently() throws {
        let deck = try fixture("NotesGeometry/geometry-source.pptx")
        let (notes, master) = try parts(deck)
        let body = try shape(notes, type: "body")
        let masterBody = try shape(master, type: "body")
        let properties = try #require(body.firstChild(named: "p:spPr"))
        properties.appendElement(try XML.parse(Data("<a:xfrm xmlns:a=\"\(MinimalTemplate.nsA)\"><a:off x=\"2000000\"/></a:xfrm>".utf8)))
        let txBody = try #require(body.firstChild(named: "p:txBody"))
        let ownBodyPr = try #require(txBody.firstChild(named: "a:bodyPr")); ownBodyPr[attribute: "lIns"] = "0"
        let inheritedBodyPr = try #require(masterBody.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr"))
        inheritedBodyPr[attribute: "tIns"] = "100000"
        let paragraph = try #require(txBody.firstChild(named: "a:p"))
        paragraph.insertChild(try XML.parse(Data("<a:pPr xmlns:a=\"\(MinimalTemplate.nsA)\"><a:defRPr sz=\"2400\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:defRPr></a:pPr>".utf8)), beforeAnyOf: ["a:r"])
        notes.markDirty(); master.markDirty()
        let dirty = [notes.isDirty, master.isDirty], blobs = [notes.blob, master.blob]
        let context = try NotesPageRenderContext(presentation: deck, slide: deck.slides[0], index: 0, pixelWidth: 750)
        let effective = context.effectiveShape(try shape(context.notes, type: "body"))
        let transform = try #require(effective.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm"))
        #expect(transform.firstChild(named: "a:off")?[attribute: "x"] == "2000000")
        #expect(transform.firstChild(named: "a:off")?[attribute: "y"] == "5029200")
        #expect(transform.firstChild(named: "a:ext")?[attribute: "cx"] == "4800600")
        #expect(effective.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?[attribute: "tIns"] == "100000")
        let svg = try deck.renderNotesSVG(slideAt: 0)
        #expect(svg.contains("translate(2000000,"))
        #expect(svg.contains("font-size=\"24\"") && svg.contains("#FF0000"))
        #expect([notes.isDirty, master.isDirty] == dirty)
        #expect([notes.blob, master.blob] == blobs)
    }

    @Test func unregisteredAmbiguousAndUnsupportedNotesRefuseStrictRendering() throws {
        let deck = try fixture("NotesGeometry/geometry-source.pptx")
        let (notes, master) = try parts(deck)
        try deck.presentationPart.dom().removeChildren(named: "p:notesMasterIdLst")
        let tree = try #require(Slide.existingSpTree(of: master))
        tree.appendElement(try shape(master, type: "body").deepCopy())
        let noteTree = try #require(Slide.existingSpTree(of: notes))
        noteTree.appendElement(XML.Element("p:grpSp"))
        deck.presentationPart.markDirty(); master.markDirty(); notes.markDirty()
        let before = try deck.serializedData()
        let problems = try deck.renderNotesSVGReportingProblems(slideAt: 0).problems
        #expect(problems.fidelityIssues.contains { $0.message.contains("not registered") })
        #expect(problems.fidelityIssues.contains { $0.message.contains("ambiguous") })
        #expect(problems.fidelityIssues.contains { $0.code == .omittedShape })
        #expect(throws: StrictRenderingError.self) { try deck.renderNotesSVG(slideAt: 0, strictRendering: true) }
        #expect(try deck.serializedData() == before)
    }

    @Test func nativeFixtureUnregisteredMastersStayDiagnosed() throws {
        for version in ["v1", "v2", "v3"] {
            let deck = try fixture("Conformance/python-tables\(version == "v1" ? "" : "-" + version).pptx")
            let result = try deck.renderNotesSVGReportingProblems(slideAt: 0)
            #expect(result.svg.contains("Independent table fixture notes."))
            #expect(result.problems.fidelityIssues.contains { $0.message.contains("not registered") } == (version != "v3"))
        }
    }

    @Test func isolatedThumbnailUsesSlideThemeWhileNotesUseNotesTheme() throws {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(1)))
        box.textFrame!.text = "Slide words"; box.textFrame!.paragraphs[0].runs[0].fontName = "Slide Face"
        try deck.slides[0].setNotes("Notes words")
        let (notes, master) = try parts(deck)
        let notesTheme = try master.related(by: RelType.theme, in: deck.package)
        let scheme = try #require(notesTheme.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fontScheme")?.firstChild(named: "a:minorFont")?.firstChild(named: "a:latin"))
        scheme[attribute: "typeface"] = "Notes Face"; notesTheme.markDirty()
        let bytes = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
        try deck.fonts.register(bytes, aliases: ["Slide Face", "Notes Face"])
        let dirty = notes.isDirty
        let result = try deck.renderNotesSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        let svg = try XML.parse(Data(result.svg.utf8))
        let image = try #require(svg.firstChild(named: "image"))
        let data = try #require(image[attribute: "href"]?.split(separator: ",", maxSplits: 1).last.flatMap { Data(base64Encoded: String($0)) })
        let thumbnail = try #require(String(data: data, encoding: .utf8))
        #expect(thumbnail.contains("Slide words"))
        #expect(!result.svg.contains("Slide words"))
        #expect(result.svg.contains("Notes words"))
        #expect(thumbnail.contains("RostrumEmbeddedFace1") && result.svg.contains("RostrumEmbeddedFace1"))
        #expect(notes.isDirty == dirty)
    }
}
