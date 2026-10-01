import Foundation
import Testing
@testable import Rostrum

@Suite struct DeckMergeTests {
    private var pngFixture: Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        // One append per field: long `[UInt8] + … + …` chains can time out the
        // Swift type-checker on some toolchains.
        b += be32(13); b += Array("IHDR".utf8); b += be32(40); b += be32(30); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }

    /// A source deck: slide 0 has a text box + picture, slide 1 has a chart.
    private func makeSource() throws -> Presentation {
        let deck = try Presentation()
        try deck.slides[0].shapes.addTextBox(Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(1)))
            .textFrame?.text = "Imported slide one"
        try deck.slides[0].shapes.addPicture(pngFixture, x: .inches(1), y: .inches(3))
        let s2 = try deck.slides.add(clonedFrom: deck.layout(type: "obj")!)
        try s2.shapes.addChart(.pie,
            data: ChartData(categories: ["X", "Y", "Z"], name: "Data", values: [3, 2, 1]),
            frame: Rect(x: .inches(2), y: .inches(2), width: .inches(6), height: .inches(4)))
        return deck
    }

    @Test func importSingleSlideBringsItsGraph() throws {
        let source = try makeSource()
        let dest = try Presentation()
        let before = dest.slides.count

        try dest.slides.import(from: source, at: 0)
        #expect(dest.slides.count == before + 1)

        let reopened = try Presentation(data: try dest.serializedData())
        #expect(reopened.slides.count == before + 1)
        // The imported slide's text and picture came along.
        let imported = try reopened.slides[reopened.slides.count - 1]
        #expect(imported.shapes.contains { $0.textFrame?.text == "Imported slide one" })
        let media = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/") }
        #expect(media.count == 1)
        // Every rel target resolves to a real part (no danglers).
        for (_, part) in reopened.package.parts {
            for rel in part.rels.items where !rel.isExternal {
                let target = PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)
                #expect(reopened.package.parts[target] != nil, "dangling rel to \(target)")
            }
        }
    }

    @Test func importChartSlideCopiesChartAndWorkbook() throws {
        let source = try makeSource()
        let dest = try Presentation()
        try dest.slides.import(from: source, at: 1)   // the chart slide

        let reopened = try Presentation(data: try dest.serializedData())
        let charts = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/charts/") }
        let books = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/embeddings/") }
        #expect(charts.count == 1 && books.count == 1)
        // The chart part's rId1 → workbook still resolves.
        let chart = try reopened.package.part(at: charts[0])
        #expect(chart.rels.relationship(withId: "rId1")?.type == RelType.package)
    }

    @Test func importAllDedupesSharedMaster() throws {
        let source = try makeSource()   // both slides share one master
        let dest = try Presentation()
        try dest.slides.importAll(from: source)

        let reopened = try Presentation(data: try dest.serializedData())
        // dest's original master + exactly one imported master (shared, deduped).
        let masters = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/slideMasters/") }
        #expect(masters.count == 2)
        // Every master in sldMasterIdLst resolves.
        let idLst = try reopened.presentationPart.dom().firstChild(named: "p:sldMasterIdLst")!
        #expect(idLst.childElements.count == 2)
        for entry in idLst.childElements {
            let rId = entry[attribute: "r:id"]!
            #expect(reopened.presentationPart.rels.relationship(withId: rId) != nil)
        }
    }

    /// The `sldMasterId`/`sldLayoutId` values share one global id namespace;
    /// a copied master must be renumbered off the source's ids, or PowerPoint
    /// silently "repairs" the deck. Assert uniqueness after import.
    private func allGlobalIds(_ p: Presentation) throws -> [Int] {
        var ids: [Int] = []
        if let list = try p.presentationPart.dom().firstChild(named: "p:sldMasterIdLst") {
            ids += list.childElements.compactMap { $0[attribute: "id"].flatMap(Int.init) }
        }
        for (uri, part) in p.package.parts where uri.value.hasPrefix("/ppt/slideMasters/") {
            if let list = try part.dom().firstChild(named: "p:sldLayoutIdLst") {
                ids += list.childElements.compactMap { $0[attribute: "id"].flatMap(Int.init) }
            }
        }
        return ids
    }

    @Test func importAllKeepsGlobalIdsUnique() throws {
        let source = try makeSource()
        let dest = try Presentation()
        try dest.slides.importAll(from: source)
        let ids = try allGlobalIds(try Presentation(data: try dest.serializedData()))
        #expect(Set(ids).count == ids.count, "duplicate global ids: \(ids.sorted())")
    }

    @Test func repeatedImportOfSameSourceKeepsGlobalIdsUnique() throws {
        // Two imports of the same source with independent copiers must not
        // collide on the source's original master/layout ids.
        let source = try makeSource()
        let dest = try Presentation()
        try dest.slides.import(from: source, at: 0)
        try dest.slides.import(from: source, at: 0)
        let ids = try allGlobalIds(try Presentation(data: try dest.serializedData()))
        #expect(Set(ids).count == ids.count, "duplicate global ids: \(ids.sorted())")
    }

    @Test func importPreservesCopiedBlobsVerbatim() throws {
        // The copied slide's blob must equal the source's (rIds preserved).
        let source = try makeSource()
        _ = try source.serializedData()   // flush the source's dirty parts
        let dest = try Presentation()
        let sourceBlob = try source.slides[0].part.blob
        try dest.slides.import(from: source, at: 0)
        let importedURI = dest.package.parts.keys
            .filter { $0.value.hasPrefix("/ppt/slides/") }
            .sorted { $0.value < $1.value }.last!
        #expect(try dest.package.part(at: importedURI).blob == sourceBlob)
    }
}

@Suite struct AnnotationImportTests {
    private func author(in deck: Presentation, named name: String, user: String, id: String? = nil) throws -> XML.Element {
        let part = try deck.presentationPart.related(by: ModernComments.authorsRelType, in: deck.package)
        let record = try #require(AnnotationAuthorImport.authorElements(part.dom()).first { $0[attribute: "name"] == name })
        record[attribute: "providerId"] = "Directory"
        record[attribute: "userId"] = user
        if let id { record[attribute: "id"] = id }
        part.markDirty()
        return record
    }

    @Test func importedCommentsKeepDistinctIdentitiesAndCorrectSlideAnchors() throws {
        let source = try Presentation()
        let thread = try source.slides[0].addComment("source", author: "Same Name")
        let reply = try thread.addReply("reply", author: "Reply Author")
        thread.resolve()
        let sourceIdentity = try author(in: source, named: "Same Name", user: "source-user")
        let unknown = XML.Element("custom:identity", attributes: [("xmlns:custom", "urn:custom"), ("key", "keep")])
        sourceIdentity.appendElement(unknown)
        let dest = try Presentation()
        let existing = try dest.slides[0].addComment("dest", author: "Same Name")
        let collision = try #require(sourceIdentity[attribute: "id"])
        _ = try author(in: dest, named: "Same Name", user: "different-user", id: collision)
        existing.cm[attribute: "authorId"] = collision
        existing.part.markDirty()
        let originalThreadID = thread.cm[attribute: "id"]
        let originalReplyID = reply.cm[attribute: "id"]
        let created = thread.cm[attribute: "created"]
        let imported = try dest.slides.import(from: source, at: 0, insertAt: 0)
        #expect(imported.comments.count == 1)
        let result = imported.comments[0]
        #expect(result.authorName == "Same Name")
        #expect(result.isResolved)
        #expect(result.replies[0].authorName == "Reply Author")
        #expect(result.cm[attribute: "authorId"] != existing.cm[attribute: "authorId"])
        #expect(result.cm[attribute: "created"] == created)
        #expect(result.cm[attribute: "id"] != originalThreadID)
        #expect(result.replies[0].cm[attribute: "id"] != originalReplyID)
        #expect(result.cm.firstChild(named: "pc:sldMkLst")?.firstChild(named: "pc:sldMk")?[attribute: "sldId"]
            == String(try imported.slideID()))
        let authors = try dest.presentationPart.related(by: ModernComments.authorsRelType, in: dest.package)
        let records = AnnotationAuthorImport.authorElements(try authors.dom())
        #expect(records.count == 3)
        #expect(records.first { $0[attribute: "userId"] == "source-user" }?.firstChild(named: "custom:identity")?.serialized()
            == unknown.serialized())
        let reopened = try Presentation(data: try dest.serializedData())
        #expect(try reopened.slides[0].comments[0].isResolved)
        #expect(try reopened.slides[0].comments[0].replies[0].text == "reply")
        #expect(try reopened.slides[1].comments[0].text == "dest")
        #expect(try reopened.validate().isEmpty)
    }

    @Test func repeatedImportsReuseDurableAuthorsButGiveThreadsNewIDs() throws {
        let source = try Presentation()
        try source.slides[0].addComment("source", author: "Reviewer")
        _ = try author(in: source, named: "Reviewer", user: "user-123")
        let dest = try Presentation()
        try dest.slides.remove(at: 0)
        let first = try dest.slides.import(from: source, at: 0)
        let second = try dest.slides.import(from: source, at: 0)
        #expect(first.comments[0].cm[attribute: "authorId"] == second.comments[0].cm[attribute: "authorId"])
        #expect(first.comments[0].cm[attribute: "id"] != second.comments[0].cm[attribute: "id"])
        let authors = try dest.presentationPart.related(by: ModernComments.authorsRelType, in: dest.package)
        #expect(AnnotationAuthorImport.authorElements(try authors.dom()).count == 1)
        let saved = try dest.serializedData()
        #expect(try Presentation(data: saved).serializedData() == saved)
    }

    @Test func importAllSharesAuthorsAndRetargetsEveryAnchor() throws {
        let source = try Presentation()
        try source.slides[0].addComment("first", author: "Reviewer")
        try source.slides.add().addComment("second", author: "Reviewer")
        let dest = try Presentation()
        let imported = try dest.slides.importAll(from: source)
        #expect(imported.count == 2)
        for slide in imported {
            #expect(slide.comments[0].authorName == "Reviewer")
            #expect(slide.comments[0].cm.firstChild(named: "pc:sldMkLst")?.firstChild(named: "pc:sldMk")?[attribute: "sldId"]
                == String(try slide.slideID()))
        }
        #expect(imported[0].comments[0].cm[attribute: "id"] != imported[1].comments[0].cm[attribute: "id"])
    }

    @Test func authorResolutionUsesPresentationRelationshipRatherThanFilename() throws {
        let source = try Presentation()
        let comment = try source.slides[0].addComment("source", author: "Reviewer")
        let old = try source.presentationPart.related(by: ModernComments.authorsRelType, in: source.package)
        old.flushIfDirty()
        let custom = source.package.addPart(uri: PackURI("/custom/identities.xml"), contentType: old.contentType, blob: old.blob)
        let rel = try #require(source.presentationPart.rels.first(ofType: ModernComments.authorsRelType))
        source.presentationPart.rels.remove(rId: rel.rId)
        source.presentationPart.rels.add(rId: rel.rId, type: rel.type,
                                       target: source.presentationPart.uri.relativeReference(to: custom.uri))
        source.package.removePart(at: old.uri)
        #expect(comment.authorName == "Reviewer")
        let dest = try Presentation()
        let imported = try dest.slides.import(from: source, at: 0)
        #expect(imported.comments[0].authorName == "Reviewer")
    }

    @Test func refusedImportAllLeavesNoPartsOrAuthorsBehind() throws {
        let source = try Presentation()
        try source.slides[0].addComment("valid", author: "Reviewer")
        let invalid = try source.slides.add().addComment("invalid", author: "Reviewer")
        invalid.cm[attribute: "authorId"] = "missing-author"
        invalid.part.markDirty()
        let dest = try Presentation()
        let before = try dest.serializedData()
        #expect(throws: (any Error).self) { try dest.slides.importAll(from: source) }
        #expect(try dest.serializedData() == before)
        #expect(throws: (any Error).self) { try dest.slides.import(from: source, at: 0, insertAt: -1) }
        #expect(try dest.serializedData() == before)
    }
}

@Suite struct NotesMasterImportTests {
    private func brandedSource() throws -> Presentation {
        let source = try Presentation()
        try source.slides[0].setNotes("branded notes")
        let master = try source.presentationPart.related(by: RelType.notesMaster, in: source.package)
        let root = try master.dom()
        let bg = try #require(root.firstChild(named: "p:cSld")?.firstChild(named: "p:bg"))
        bg.children = [.element(XML.Element("p:bgPr", children: [.element(
            XML.Element("a:solidFill", children: [.element(XML.Element("a:srgbClr", attributes: [("val", "123456")]))]))]))]
        root.appendElement(XML.Element("p:notesStyle", children: [.element(XML.Element("a:lvl1pPr", children: [
            .element(XML.Element("a:defRPr", attributes: [("sz", "2200")], children: [
                .element(XML.Element("a:latin", attributes: [("typeface", "Brand Notes Font")]))])),
        ]))]))
        root.appendElement(XML.Element("custom:extension", attributes: [("xmlns:custom", "urn:notes-brand"), ("keep", "opaque")]))
        master.markDirty()
        let theme = try master.related(by: RelType.theme, in: source.package)
        let themeRoot = try theme.dom()
        themeRoot[attribute: "name"] = "Notes Brand Theme"
        theme.markDirty()
        let image = source.package.addPart(uri: PackURI("/ppt/media/notesLogo.png"), contentType: ContentType.png,
            blob: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII=")!)
        master.rels.add(type: RelType.image, target: master.uri.relativeReference(to: image.uri))
        let size = try #require(source.presentationPart.dom().firstChild(named: "p:notesSz"))
        size[attribute: "cx"] = "7000000"
        size[attribute: "cy"] = "9000000"
        source.presentationPart.markDirty()
        return source
    }

    @Test func firstNotesMasterPreservesActualMasterThemeImagesAndPageSize() throws {
        let source = try brandedSource()
        _ = try source.serializedData()
        let oldMaster = try source.presentationPart.related(by: RelType.notesMaster, in: source.package)
        let alternate = source.package.addPart(uri: PackURI("/ppt/notesMasters/company.xml"),
            contentType: oldMaster.contentType, blob: oldMaster.blob)
        alternate.rels.setItems(oldMaster.rels.items)
        for part in source.package.parts.values {
            part.rels.setItems(part.rels.items.map { rel in
                guard !rel.isExternal,
                      PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI) == oldMaster.uri else { return rel }
                return Relationship(rId: rel.rId, type: rel.type,
                    target: part.uri.relativeReference(to: alternate.uri), isExternal: false)
            })
        }
        source.package.removePart(at: oldMaster.uri)
        let sourceMaster = try source.presentationPart.related(by: RelType.notesMaster, in: source.package)
        let dest = try Presentation()
        let imported = try dest.slides.import(from: source, at: 0)
        let notes = try imported.part.related(by: RelType.notesSlide, in: dest.package)
        let master = try notes.related(by: RelType.notesMaster, in: dest.package)
        #expect(master.blob == sourceMaster.blob)
        #expect(try master.related(by: RelType.theme, in: dest.package).blob
            == sourceMaster.related(by: RelType.theme, in: source.package).blob)
        #expect(try master.related(by: RelType.image, in: dest.package).blob
            == sourceMaster.related(by: RelType.image, in: source.package).blob)
        #expect(try dest.presentationPart.dom().firstChild(named: "p:notesSz")?.serialized()
            == source.presentationPart.dom().firstChild(named: "p:notesSz")?.serialized())
        #expect(imported.notesText == "branded notes")
        #expect(try notes.related(by: RelType.slide, in: dest.package).uri == imported.part.uri)
        let reopened = try Presentation(data: try dest.serializedData())
        let reopenedMaster = try reopened.presentationPart.related(by: RelType.notesMaster, in: reopened.package)
        #expect(reopenedMaster.blob == sourceMaster.blob)
        #expect(try reopened.validate().isEmpty)
        let added = try reopened.slides.add()
        try added.setNotes("new notes use imported master")
        let addedMaster = try added.part.related(by: RelType.notesSlide, in: reopened.package)
            .related(by: RelType.notesMaster, in: reopened.package)
        #expect(addedMaster.uri == reopenedMaster.uri)
    }

    @Test func compatibleMastersReuseExistingNotesAppearanceAcrossRepeatedImports() throws {
        let source = try brandedSource()
        let dest = try Presentation()
        try dest.slides.import(from: source, at: 0)
        let before = try dest.presentationPart.related(by: RelType.notesMaster, in: dest.package)
        try dest.slides.import(from: source, at: 0)
        #expect(dest.package.parts.values.filter { $0.contentType == ContentType.notesMaster }.count == 1)
        #expect(try dest.slides[2].part.related(by: RelType.notesSlide, in: dest.package)
            .related(by: RelType.notesMaster, in: dest.package).uri == before.uri)
        let saved = try dest.serializedData()
        #expect(try Presentation(data: saved).serializedData() == saved)
    }

    @Test func conflictingMastersThemesAndDimensionsAreRefusedAtomically() throws {
        let source = try brandedSource()
        let dest = try Presentation()
        try dest.slides.import(from: source, at: 0)
        let master = try source.presentationPart.related(by: RelType.notesMaster, in: source.package)
        let theme = try master.related(by: RelType.theme, in: source.package)
        let before = try dest.serializedData()
        try theme.dom()[attribute: "name"] = "Conflicting Theme"
        theme.markDirty()
        #expect(throws: NotesImportError.self) { try dest.slides.importAll(from: source) }
        #expect(try dest.serializedData() == before)
        let fresh = try brandedSource()
        try fresh.presentationPart.dom().firstChild(named: "p:notesSz")?[attribute: "cx"] = "8000000"
        fresh.presentationPart.markDirty()
        #expect(throws: NotesImportError.self) { try dest.slides.import(from: fresh, at: 0) }
        #expect(try dest.serializedData() == before)
        let unbranded = try Presentation()
        try unbranded.slides[0].setNotes("existing unbranded notes")
        let unbrandedBefore = try unbranded.serializedData()
        #expect(throws: NotesImportError.self) { try unbranded.slides.import(from: source, at: 0) }
        #expect(try unbranded.serializedData() == unbrandedBefore)
    }
}
