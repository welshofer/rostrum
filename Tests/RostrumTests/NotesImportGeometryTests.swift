import Foundation
import Testing
@testable import Rostrum

@Suite struct NotesImportGeometryTests {
    private func notes(_ slide: Slide, in deck: Presentation) throws -> Part {
        try slide.part.related(by: RelType.notesSlide, in: deck.package)
    }

    private func master(in deck: Presentation) throws -> Part {
        try deck.presentationPart.related(by: RelType.notesMaster, in: deck.package)
    }

    private func shape(_ type: String, in part: Part) throws -> XML.Element {
        try #require(part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?
            .children(named: "p:sp").first {
                $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?
                    .firstChild(named: "p:ph")?[attribute: "type"] == type
            })
    }

    private func transform(_ type: String, in part: Part) throws -> XML.Element {
        try #require(shape(type, in: part).firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm"))
    }

    private func fixture() throws -> (source: Presentation, target: Presentation) {
        let source = try Presentation()
        try source.slides[0].shapes.addShape(.rectangle,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(7), height: .inches(3)),
            fill: .solid(Color("276D89")))
        try source.slides[0].setNotes(["Geometry-preserving import", "Inherited Arial notes on a branded background."])
        let sourceMaster = try master(in: source)
        let background = try #require(sourceMaster.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:bg"))
        background.children = [.element(XML.Element("p:bgPr", children: [.element(XML.Element("a:solidFill", children: [
            .element(XML.Element("a:srgbClr", attributes: [("val", "EDF2F7")]))
        ]))]))]
        let font = try #require(sourceMaster.dom().firstChild(named: "p:notesStyle")?
            .firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr")?.firstChild(named: "a:latin"))
        font[attribute: "typeface"] = "Arial"
        let opaque = XML.Element("p:extLst", children: [.element(XML.Element("p:ext", attributes: [("uri", "urn:rostrum:notes-test")], children: [
            .element(XML.Element("foreign:payload", attributes: [("xmlns:foreign", "urn:foreign"), ("keep", "master")], children: [.comment("opaque master")]))
        ]))])
        try sourceMaster.dom().appendElement(opaque)
        sourceMaster.markDirty()
        let sourceNotes = try notes(source.slides[0], in: source)
        try sourceNotes.dom().appendElement(XML.Element("p:extLst", children: [.element(XML.Element("p:ext", attributes: [("uri", "urn:rostrum:notes-test")], children: [
            .element(XML.Element("foreign:payload", attributes: [("xmlns:foreign", "urn:foreign"), ("keep", "notes")], children: [.comment("opaque notes"), .processingInstruction(target: "opaque", data: "preserved")]))
        ]))]))
        sourceNotes.markDirty()
        let target = try Presentation(data: source.serializedData())
        // Change only the source's inherited body/image rectangle. Both source
        // and target retain identical text, styles, fills, extensions and theme.
        let body = try transform("body", in: sourceMaster)
        body.firstChild(named: "a:off")?[attribute: "x"] = "1028700"
        body.firstChild(named: "a:off")?[attribute: "y"] = "5029200"
        body.firstChild(named: "a:ext")?[attribute: "cx"] = "4800600"
        body.firstChild(named: "a:ext")?[attribute: "cy"] = "3200400"
        let image = try transform("sldImg", in: sourceMaster)
        image.firstChild(named: "a:off")?[attribute: "x"] = "1371600"
        image.firstChild(named: "a:off")?[attribute: "y"] = "914400"
        image.firstChild(named: "a:ext")?[attribute: "cx"] = "4114800"
        image.firstChild(named: "a:ext")?[attribute: "cy"] = "2743200"
        sourceMaster.markDirty()
        return (source, target)
    }

    @Test func conflictingGeometryRetainsSourceAppearanceAndExistingTargetNotes() throws {
        let (source, target) = try fixture()
        let sourceBefore = try source.serializedData()
        let targetBefore = try target.serializedData()
        let targetMaster = try master(in: target)
        let targetMasterBefore = targetMaster.blob
        let existingNotes = try notes(target.slides[0], in: target)
        let existingNotesBefore = existingNotes.blob
        let sourceMaster = try master(in: source)
        let sourceNotes = try notes(source.slides[0], in: source)
        let imported = try target.slides.import(from: source, at: 0)
        let importedNotes = try notes(imported, in: target)
        #expect(try imported.notesParagraphs == source.slides[0].notesParagraphs)
        for type in ["body", "sldImg"] {
            #expect(try transform(type, in: importedNotes).serialized() == transform(type, in: sourceMaster).serialized())
            #expect(try shape(type, in: sourceNotes).firstChild(named: "p:spPr")?.children(named: "a:xfrm").isEmpty == true)
        }
        #expect(try importedNotes.dom().firstChild(named: "p:extLst")?.serialized()
            == sourceNotes.dom().firstChild(named: "p:extLst")?.serialized())
        #expect(try importedNotes.related(by: RelType.notesMaster, in: target.package).uri == targetMaster.uri)
        #expect(try importedNotes.related(by: RelType.slide, in: target.package).uri == imported.part.uri)
        #expect(target.package.parts.values.filter { $0.contentType == ContentType.notesMaster }.count == 1)
        #expect(targetMaster.blob == targetMasterBefore)
        #expect(existingNotes.blob == existingNotesBefore)
        let saved = try target.serializedData()
        let reopened = try Presentation(data: saved)
        #expect(try reopened.serializedData() == saved)
        #expect(try reopened.validate().isEmpty)
        #expect(try source.serializedData() == sourceBefore)
        let reopenedNotes = try notes(reopened.slides[1], in: reopened)
        #expect(try transform("body", in: reopenedNotes).serialized() == transform("body", in: sourceMaster).serialized())
        // Repeated imports must materialize every copied page, even after the
        // notes-master mapping has been cached by an earlier page.
        try target.slides.importAll(from: source)
        #expect(try transform("body", in: notes(target.slides[2], in: target)).serialized() == transform("body", in: sourceMaster).serialized())
        if let folder = ProcessInfo.processInfo.environment["ROSTRUM_NOTES_ORACLE_OUTPUT"] {
            let url = URL(fileURLWithPath: folder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try sourceBefore.write(to: url.appendingPathComponent("geometry-source.pptx"))
            try targetBefore.write(to: url.appendingPathComponent("geometry-target-before.pptx"))
            try saved.write(to: url.appendingPathComponent("geometry-imported.pptx"))
        }
    }


    @Test func aliasedNotesKeepOpaqueXMLAndMasterDrawingPrefixBindings() throws {
        let (source, target) = try fixture()
        let sourceNotes = try notes(source.slides[0], in: source)
        sourceNotes.flushIfDirty()
        let xml = String(decoding: sourceNotes.blob, as: UTF8.self)
            .replacingOccurrences(of: "<p:", with: "<q:")
            .replacingOccurrences(of: "</p:", with: "</q:")
            .replacingOccurrences(of: "xmlns:p", with: "xmlns:q")
            .replacingOccurrences(of: "<a:", with: "<d:")
            .replacingOccurrences(of: "</a:", with: "</d:")
            .replacingOccurrences(of: "xmlns:a", with: "xmlns:d")
        sourceNotes.blob = Data(xml.utf8)
        let sourceBefore = try source.serializedData()
        let imported = try target.slides.import(from: source, at: 0)
        let copied = try notes(imported, in: target)
        let root = try copied.dom()
        let body = try #require(root.firstChild(named: "q:cSld")?.firstChild(named: "q:spTree")?
            .children(named: "q:sp").first {
                $0.firstChild(named: "q:nvSpPr")?.firstChild(named: "q:nvPr")?
                    .firstChild(named: "q:ph")?[attribute: "type"] == "body"
            })
        let geometry = try #require(body.firstChild(named: "q:spPr")?.firstChild(named: "a:xfrm"))
        #expect(geometry[attribute: "xmlns:a"] == MinimalTemplate.nsA)
        #expect(geometry.firstChild(named: "a:off")?[attribute: "x"] == "1028700")
        #expect(try root.firstChild(named: "q:extLst")?.serialized() == XML.parse(Data(xml.utf8)).firstChild(named: "q:extLst")?.serialized())
        #expect(try source.serializedData() == sourceBefore)
        let saved = try target.serializedData()
        #expect(try Presentation(data: saved).serializedData() == saved)
    }

    @Test func completeLocalGeometryWinsWhileInheritedGeometryMaterializesOnEveryPage() throws {
        let (source, target) = try fixture()
        let second = try source.slides.add()
        try second.setNotes("Local override must remain authoritative.")
        let secondNotes = try notes(second, in: source)
        let local = try transform("body", in: master(in: target)).deepCopy()
        local.firstChild(named: "a:off")?[attribute: "x"] = "2000000"
        try shape("body", in: secondNotes).firstChild(named: "p:spPr")?.appendElement(local)
        secondNotes.markDirty()
        let sourceBefore = try source.serializedData()
        let imported = try target.slides.importAll(from: source)
        #expect(imported.count == 2)
        let copiedSecondNotes = try notes(imported[1], in: target)
        #expect(try transform("body", in: copiedSecondNotes).serialized() == local.serialized())
        #expect(try transform("sldImg", in: copiedSecondNotes).serialized() == transform("sldImg", in: master(in: source)).serialized())
        #expect(try source.serializedData() == sourceBefore)
    }

    @Test(arguments: [false, true])
    func notesPlaceholderMatchesMasterByTypeEvenWhenIndexDiffers(localOverride: Bool) throws {
        let (source, target) = try fixture()
        let sourceNotes = try notes(source.slides[0], in: source)
        let body = try shape("body", in: sourceNotes)
        let placeholder = try #require(body.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph"))
        placeholder[attribute: "idx"] = "17"
        let expected = try transform("body", in: master(in: source)).deepCopy()
        if localOverride {
            expected.firstChild(named: "a:off")?[attribute: "x"] = "2000000"
            body.firstChild(named: "p:spPr")?.appendElement(expected.deepCopy())
        }
        sourceNotes.markDirty()
        let sourceBefore = try source.serializedData()
        let imported = try target.slides.import(from: source, at: 0)
        let importedNotes = try notes(imported, in: target)
        #expect(try transform("body", in: importedNotes).serialized() == expected.serialized())
        #expect(try shape("body", in: importedNotes).firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "idx"] == "17")
        #expect(try source.serializedData() == sourceBefore)
        let saved = try target.serializedData()
        #expect(try Presentation(data: saved).serializedData() == saved)
        if let folder = ProcessInfo.processInfo.environment["ROSTRUM_NOTES_TYPE_ORACLE_OUTPUT"] {
            let url = URL(fileURLWithPath: folder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let suffix = localOverride ? "local" : "inherited"
            try sourceBefore.write(to: url.appendingPathComponent("type-index-\(suffix)-source.pptx"))
            try saved.write(to: url.appendingPathComponent("type-index-\(suffix)-imported.pptx"))
        }
    }

    @Test(arguments: ["notes", "master"])
    func duplicatePlaceholderTypesWithDistinctIndexesRefuseWholeBatchAtomically(_ owner: String) throws {
        let (source, target) = try fixture()
        let second = try source.slides.add()
        try second.setNotes("Ambiguous second page")
        let ownerPart = try owner == "notes" ? notes(second, in: source) : master(in: source)
        let body = try shape("body", in: ownerPart).deepCopy()
        let nonvisual = try #require(body.firstChild(named: "p:nvSpPr"))
        nonvisual.firstChild(named: "p:cNvPr")?[attribute: "id"] = "4"
        nonvisual.firstChild(named: "p:cNvPr")?[attribute: "name"] = "Distinct index body"
        nonvisual.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "idx"] = "17"
        try ownerPart.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.appendElement(body)
        ownerPart.markDirty()
        let before = try target.serializedData()
        let sourceBefore = try source.serializedData()
        // Retain an independent baseline reproduction if the buggy importer
        // silently accepts this ambiguous page. Correct code emits no candidate.
        if let folder = ProcessInfo.processInfo.environment["ROSTRUM_NOTES_TYPE_ORACLE_OUTPUT"] {
            let url = URL(fileURLWithPath: folder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try sourceBefore.write(to: url.appendingPathComponent("duplicate-\(owner)-source.pptx"))
            let reproduction = try Presentation(data: before)
            if (try? reproduction.slides.importAll(from: source)) != nil {
                try reproduction.serializedData().write(to: url.appendingPathComponent("duplicate-\(owner)-accepted.pptx"))
            }
        }
        #expect(throws: NotesImportError.self) { try target.slides.importAll(from: source) }
        #expect(try target.serializedData() == before)
        #expect(try source.serializedData() == sourceBefore)
    }

    @Test(arguments: ["missing", "partial", "duplicate", "namespace", "extended"])
    func malformedOrUnmodeledLocalGeometryRefusesWholeBatchAtomically(_ failure: String) throws {
        let (source, target) = try fixture()
        let second = try source.slides.add()
        try second.setNotes("Rejected second page")
        let secondNotes = try notes(second, in: source)
        let body = try shape("body", in: secondNotes)
        let properties = try #require(body.firstChild(named: "p:spPr"))
        switch failure {
        case "missing":
            let tree = try #require(secondNotes.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
            tree.children.removeAll { if case .element(let element) = $0 { return element === body }; return false }
        case "partial": properties.appendElement(XML.Element("a:xfrm", children: [.element(XML.Element("a:off", attributes: [("x", "1"), ("y", "2")]))]))
        case "duplicate":
            let tree = try #require(secondNotes.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
            tree.appendElement(body.deepCopy())
        case "namespace":
            body[attribute: "xmlns:p"] = "urn:not-presentationml"
        default:
            let local = try transform("body", in: master(in: source)).deepCopy()
            local.appendElement(XML.Element("foreign:transform", attributes: [("xmlns:foreign", "urn:foreign")]))
            properties.appendElement(local)
        }
        secondNotes.markDirty()
        let before = try target.serializedData()
        let sourceBefore = try source.serializedData()
        #expect(throws: NotesImportError.self) { try target.slides.importAll(from: source) }
        #expect(try target.serializedData() == before)
        #expect(try source.serializedData() == sourceBefore)
    }

    @Test(arguments: ["rotation", "style", "extension", "theme", "absent", "extent", "markup"])
    func conflictsOutsidePositionAndSizeRemainAtomicRefusals(_ failure: String) throws {
        let (source, target) = try fixture()
        let sourceMaster = try master(in: source)
        switch failure {
        case "rotation": try transform("body", in: sourceMaster)[attribute: "rot"] = "60000"
        case "style": try sourceMaster.dom().firstChild(named: "p:notesStyle")?.firstChild(named: "a:lvl1pPr")?[attribute: "algn"] = "ctr"
        case "extension": try sourceMaster.dom().firstChild(named: "p:extLst")?.firstChild(named: "p:ext")?[attribute: "uri"] = "urn:changed"
        case "theme":
            let theme = try sourceMaster.related(by: RelType.theme, in: source.package)
            try theme.dom()[attribute: "name"] = "Different Theme"
            theme.markDirty()
        case "absent": try shape("body", in: sourceMaster).firstChild(named: "p:spPr")?.removeChildren(named: "a:xfrm")
        case "extent": try transform("body", in: sourceMaster).firstChild(named: "a:ext")?[attribute: "cx"] = "0"
        default:
            sourceMaster.flushIfDirty()
            sourceMaster.blob = XML.document(XML.Document(root: try sourceMaster.dom().deepCopy(),
                prologue: [.processingInstruction(target: "opaque", data: "changed")]))
        }
        if failure != "markup" { sourceMaster.markDirty() }
        let before = try target.serializedData()
        #expect(throws: NotesImportError.self) { try target.slides.import(from: source, at: 0) }
        #expect(try target.serializedData() == before)
    }
}
