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

    @Test func noFillAndNoLineSuppressThumbnailWithoutInspectingHiddenSlide() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("")
        let (notes, master) = try parts(deck)
        try shape(notes, type: "body").removeChildren(named: "p:txBody"); notes.markDirty()
        let image = try shape(master, type: "sldImg")
        let properties = try #require(image.firstChild(named: "p:spPr"))
        let line = try #require(properties.firstChild(named: "a:ln"))
        line.children = [.element(XML.Element("a:noFill"))]; master.markDirty()
        // An unsupported slide shape must not poison a suppressed thumbnail.
        let slideTree = try #require(Slide.existingSpTree(of: deck.slides[0].part))
        slideTree.appendElement(XML.Element("p:grpSp")); try deck.slides[0].part.markDirty()
        let result = try deck.renderNotesSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(!result.svg.contains("<image"))
        // A local visible line restores the image and its own diagnostics.
        let local = try #require(shape(notes, type: "sldImg").firstChild(named: "p:spPr"))
        local.appendElement(try XML.parse(Data("<a:ln xmlns:a=\"\(MinimalTemplate.nsA)\" w=\"12700\"><a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill></a:ln>".utf8)))
        notes.markDirty()
        let visible = try deck.renderNotesSVGReportingProblems(slideAt: 0)
        #expect(visible.svg.contains("<image"))
        #expect(visible.problems.fidelityIssues.contains { $0.code == .omittedShape })
    }

    @Test func inheritedGroupsAndConnectorsAreDiagnosedAndStrictRefused() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("")
        let (_, master) = try parts(deck)
        let tree = try #require(Slide.existingSpTree(of: master))
        tree.appendElement(XML.Element("p:grpSp")); tree.appendElement(XML.Element("p:cxnSp")); master.markDirty()
        let result = try deck.renderNotesSVGReportingProblems(slideAt: 0)
        for kind in ["p:grpSp", "p:cxnSp"] {
            #expect(result.problems.fidelityIssues.contains {
                $0.code == .omittedShape && $0.location.partURI == master.uri.description && $0.message.contains(kind)
            })
        }
        #expect(throws: StrictRenderingError.self) { try deck.renderNotesSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func namespaceCanonicalizationHandlesDeepProgrammaticTreesIteratively() {
        let root = XML.Element("q:notes", attributes: [("xmlns:q", MinimalTemplate.nsP)])
        var cursor = root
        for _ in 0..<100_000 {
            let child = XML.Element("q:node"); cursor.appendElement(child); cursor = child
        }
        let copy = NotesPageRenderContext.canonical(root)
        #expect(copy.name == "p:notes" && root.name == "q:notes")
        var count = 0, current = copy
        while let child = current.childElements.first { count += 1; current = child }
        #expect(count == 100_000 && current.name == "p:node")
    }


    @Test func translucentSlideImageBackingAndFrameArePaintedExactlyOnce() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("")
        let (notes, master) = try parts(deck)
        try shape(notes, type: "body").removeChildren(named: "p:txBody"); notes.markDirty()
        let properties = try #require(shape(master, type: "sldImg").firstChild(named: "p:spPr"))
        properties.removeChildren(named: "a:noFill"); properties.removeChildren(named: "a:ln")
        properties.appendElement(try XML.parse(Data("<a:solidFill xmlns:a=\"\(MinimalTemplate.nsA)\"><a:srgbClr val=\"FF0000\"><a:alpha val=\"50000\"/></a:srgbClr></a:solidFill>".utf8)))
        properties.appendElement(try XML.parse(Data("<a:ln xmlns:a=\"\(MinimalTemplate.nsA)\" w=\"12700\"><a:solidFill><a:srgbClr val=\"0000FF\"><a:alpha val=\"50000\"/></a:srgbClr></a:solidFill></a:ln>".utf8)))
        master.markDirty()
        let result = try deck.renderNotesSVGReportingProblems(slideAt: 0, strictRendering: true)
        let root = try XML.parse(Data(result.svg.utf8))
        #expect(root.children(named: "rect").filter { $0[attribute: "fill"] == "rgba(255,0,0,0.5)" }.count == 1)
        #expect(root.children(named: "rect").filter { $0[attribute: "stroke"] == "rgba(0,0,255,0.5)" }.count == 1)
        #expect(root.children(named: "image").count == 1)
    }

}
