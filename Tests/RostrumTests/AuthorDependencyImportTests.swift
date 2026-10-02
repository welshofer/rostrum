import Foundation
import Testing
@testable import Rostrum

@Suite struct AuthorDependencyImportTests {
    private func fixture(legacy: Bool, payload: String = "payload") throws -> (Presentation, Part, XML.Element, Part) {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        if legacy { _ = try slide.addLegacyComment("source", author: "Reviewer") }
        else { _ = try slide.addComment("source", author: "Reviewer") }
        let authors = try authorPart(deck, legacy: legacy)
        let root = try authors.dom()
        let record = try #require(records(root, legacy: legacy).first)
        if !legacy { record[attribute: "providerId"] = "Directory"; record[attribute: "userId"] = "same-user" }
        // Deliberately bind a misleading r prefix, and use an inherited alias.
        root[attribute: "xmlns:rel"] = MinimalTemplate.nsR
        root[attribute: "xmlns:r"] = "urn:false-relationship"
        root[attribute: "xmlns:custom"] = "urn:author-extension"
        let part = deck.package.addPart(uri: PackURI("/ppt/custom/author-data.xml"), contentType: "application/xml",
            blob: Data("<?xml version=\"1.0\"?><?payload keep?><custom:data xmlns:custom=\"urn:author-extension\"><!--keep-->\(payload)</custom:data>".utf8))
        authors.rels.add(rId: "rId1", type: "urn:author-payload", target: authors.uri.relativeReference(to: part.uri))
        record.appendElement(XML.Element("custom:payload", attributes: [("rel:id", "rId1"), ("r:id", "opaque-token")]))
        authors.markDirty()
        return (deck, authors, record, part)
    }
    private func authorPart(_ deck: Presentation, legacy: Bool) throws -> Part {
        try deck.presentationPart.related(by: legacy ? LegacyComments.authorsRelType : ModernComments.authorsRelType, in: deck.package)
    }
    private func records(_ root: XML.Element, legacy: Bool) -> [XML.Element] {
        legacy ? LegacyComments.elements(root, named: "cmAuthor") : AnnotationAuthorImport.authorElements(root)
    }
    private func commentPart(_ slide: Slide, legacy: Bool) throws -> Part {
        try slide.part.related(by: legacy ? LegacyComments.commentsRelType : ModernComments.commentsRelType, in: slide.package)
    }
    private func commentID(_ slide: Slide, legacy: Bool) throws -> String {
        if legacy { return try #require(slide.legacyComments.first?.authorID) }
        return try #require(slide.comments.first?.cm[attribute: "authorId"])
    }

    @Test(arguments: [false, true]) func collisionsRetainBothGraphsAndAliases(legacy: Bool) throws {
        let (source, sourceAuthors, sourceRecord, payload) = try fixture(legacy: legacy, payload: "SOURCE")
        let (dest, authors, existing, oldPayload) = try fixture(legacy: legacy, payload: "DESTINATION")
        let sourceID = try #require(sourceRecord[attribute: "id"])
        existing[attribute: "id"] = sourceID; authors.markDirty()
        let existingComment = try commentPart(dest.slides[0], legacy: legacy)
        let cm = try #require(legacy ? LegacyComments.elements(existingComment.dom(), named: "cm").first : dest.slides[0].comments.first?.cm)
        cm[attribute: "authorId"] = sourceID; existingComment.markDirty()
        let sourceBytes = try source.serializedData()
        let originalGraph = authors.rels.items
        let imported = try dest.slides.import(from: source, at: 0)
        let importedID = try commentID(imported, legacy: legacy)
        #expect(importedID != sourceID)
        #expect(try commentID(dest.slides[0], legacy: legacy) == sourceID)
        #expect(authors.rels.items.first == originalGraph.first)
        #expect(oldPayload.blob != payload.blob)
        let record = try #require(records(authors.dom(), legacy: legacy).first { $0[attribute: "id"] == importedID })
        let extensionNode = try #require(record.firstChild(named: "custom:payload"))
        #expect(extensionNode[attribute: "r:id"] == "opaque-token")
        let relationshipID = try #require(extensionNode[attribute: "rel:id"])
        let rel = try #require(authors.rels.relationship(withId: relationshipID))
        #expect(rel.rId != "rId1")
        let copied = try dest.package.part(at: PackURI.resolve(target: rel.target, relativeTo: authors.uri.baseURI))
        #expect(copied.blob == payload.blob)
        #expect(record[attribute: "xmlns:rel"] == MinimalTemplate.nsR)
        #expect(record[attribute: "xmlns:r"] == "urn:false-relationship")
        #expect(try source.serializedData() == sourceBytes)
        #expect(sourceAuthors.rels.items.count == 1)
        let second = try dest.slides.import(from: source, at: 0)
        #expect(try commentID(second, legacy: legacy) == importedID)
        #expect(records(try authors.dom(), legacy: legacy).count == 2)
        #expect(authors.rels.items.count == 2)
        let saved = try dest.serializedData()
        #expect(try Presentation(data: saved).serializedData() == saved)
    }

    @Test(arguments: [false, true]) func cyclesDiamondsAndExternalDependenciesRemainConnected(legacy: Bool) throws {
        let (source, authors, _, payload) = try fixture(legacy: legacy)
        let leaf = source.package.addPart(uri: PackURI("/ppt/custom/leaf.bin"), contentType: "application/octet-stream", blob: Data([0, 1, 255]))
        let sibling = source.package.addPart(uri: PackURI("/ppt/custom/sibling.xml"), contentType: "application/xml", blob: Data("<opaque/>".utf8))
        payload.rels.add(rId: "back", type: "urn:backlink", target: payload.uri.relativeReference(to: authors.uri))
        payload.rels.add(rId: "leaf", type: "urn:leaf", target: payload.uri.relativeReference(to: leaf.uri))
        payload.rels.add(rId: "sibling", type: "urn:sibling", target: payload.uri.relativeReference(to: sibling.uri))
        payload.rels.add(rId: "web", type: "urn:external", target: "https://example.org/identity?a=1&b=2", isExternal: true)
        sibling.rels.add(rId: "leaf", type: "urn:leaf", target: sibling.uri.relativeReference(to: leaf.uri))
        let before = try source.serializedData()
        let dest = try Presentation()
        _ = try dest.slides.importAll(from: source)
        let installed = try authorPart(dest, legacy: legacy)
        let copied = try installed.related(by: "urn:author-payload", in: dest.package)
        #expect(copied.blob == payload.blob)
        #expect(try copied.related(by: "urn:backlink", in: dest.package) === installed)
        let copiedLeaf = try copied.related(by: "urn:leaf", in: dest.package)
        #expect(try copied.related(by: "urn:sibling", in: dest.package).related(by: "urn:leaf", in: dest.package) === copiedLeaf)
        #expect(copied.rels.relationship(withId: "web") == payload.rels.relationship(withId: "web"))
        let customParts = Set(dest.package.parts.keys.filter { $0.value.hasPrefix("/ppt/custom/") })
        _ = try dest.slides.import(from: source, at: 0)
        #expect(installed.rels.items.count == 1)
        #expect(records(try installed.dom(), legacy: legacy).count == 1)
        #expect(Set(dest.package.parts.keys.filter { $0.value.hasPrefix("/ppt/custom/") }) == customParts)
        #expect(try source.serializedData() == before)
        let bytes = try dest.serializedData()
        #expect(try Presentation(data: bytes).serializedData() == bytes)
    }

    @Test(arguments: [false, true]) func equalPayloadsWithDifferentTargetsCannotReuseAuthor(legacy: Bool) throws {
        let (source, _, sourceRecord, payload) = try fixture(legacy: legacy)
        let (dest, destAuthors, record, destPayload) = try fixture(legacy: legacy)
        let id = try #require(record[attribute: "id"])
        sourceRecord[attribute: "id"] = id
        let sourceAuthors = try authorPart(source, legacy: legacy); sourceAuthors.markDirty()
        let sourceComment = try commentPart(source.slides[0], legacy: legacy)
        let cm = try #require(legacy ? LegacyComments.elements(sourceComment.dom(), named: "cm").first : source.slides[0].comments.first?.cm)
        cm[attribute: "authorId"] = id; sourceComment.markDirty()
        for (deck, node, bytes) in [(source, payload, Data([1])), (dest, destPayload, Data([2]))] {
            let leaf = deck.package.addPart(uri: PackURI("/ppt/custom/leaf.bin"), contentType: "application/octet-stream", blob: bytes)
            node.rels.add(rId: "same", type: "urn:leaf", target: node.uri.relativeReference(to: leaf.uri))
        }
        let imported = try dest.slides.import(from: source, at: 0)
        #expect(try commentID(imported, legacy: legacy) != id)
        #expect(records(try destAuthors.dom(), legacy: legacy).count == 2)
        #expect(destAuthors.rels.items.count == 2)
    }

    @Test(arguments: ["missing-part", "missing-reference", "duplicate-relationship", "depth", "conflicting-root", "duplicate-author"]) func invalidGraphsRefuseWithoutChangingDestination(kind: String) throws {
        let (source, authors, record, payload) = try fixture(legacy: false)
        switch kind {
        case "missing-part": payload.rels.add(type: "urn:missing", target: "missing.xml")
        case "missing-reference": record.firstChild(named: "custom:payload")?[attribute: "rel:id"] = "missing"; authors.markDirty()
        case "duplicate-relationship": authors.rels.add(rId: "rId1", type: "urn:duplicate", target: "author-data.xml")
        case "depth":
            var prior = payload
            for index in 0..<257 {
                let next = source.package.addPart(uri: PackURI("/ppt/custom/chain\(index).bin"), contentType: "application/octet-stream", blob: Data([1]))
                prior.rels.add(type: "urn:next", target: prior.uri.relativeReference(to: next.uri)); prior = next
            }
        case "conflicting-root": (try authors.dom())[attribute: "custom:root-meaning"] = "unmergeable"; authors.markDirty()
        default:
            let clone = record.deepCopy(); clone[attribute: "id"] = record[attribute: "id"]?.lowercased()
            try authors.dom().appendElement(clone); authors.markDirty()
        }
        let dest = try Presentation()
        _ = try dest.slides[0].addComment("existing", author: "Existing")
        let before = try dest.serializedData(), sourceBytes = try source.serializedData()
        #expect(throws: RostrumError.self) { _ = try dest.slides.import(from: source, at: 0) }
        #expect(try dest.serializedData() == before)
        #expect(throws: RostrumError.self) { _ = try dest.slides.importAll(from: source) }
        #expect(try dest.serializedData() == before)
        #expect(try source.serializedData() == sourceBytes)
    }

    @Test func rootMetadataOnlyMergeFlushesEvenWhenAuthorReused() throws {
        let (source, sourceAuthors, _, _) = try fixture(legacy: false)
        let dest = try Presentation()
        _ = try dest.slides.import(from: source, at: 0)
        let marker = XML.Element("custom:rootData", attributes: [("key", "retain")], children: [.comment("root")])
        try sourceAuthors.dom().appendElement(marker); sourceAuthors.markDirty()
        _ = try dest.slides.import(from: source, at: 0)
        let installed = try authorPart(dest, legacy: false)
        #expect(records(try installed.dom(), legacy: false).count == 1)
        let reopened = try Presentation(data: dest.serializedData())
        #expect(try authorPart(reopened, legacy: false).dom().firstChild(named: "custom:rootData")?.textContent == "")
        #expect(try authorPart(reopened, legacy: false).dom().serialized().contains("<!--root-->"))
    }

    @Test func leadingZeroLegacyIDsCollideNumericallyAndRetainDestinationID() throws {
        let (source, sourceAuthors, sourceRecord, _) = try fixture(legacy: true, payload: "SOURCE")
        let (dest, destAuthors, destRecord, _) = try fixture(legacy: true, payload: "DEST")
        sourceRecord[attribute: "id"] = "01"; sourceAuthors.markDirty()
        destRecord[attribute: "id"] = "1"; destAuthors.markDirty()
        for deck in [source, dest] {
            let comments = try commentPart(deck.slides[0], legacy: true)
            try #require(LegacyComments.elements(comments.dom(), named: "cm").first)[attribute: "authorId"] = "1"
            comments.markDirty()
        }
        let imported = try dest.slides.import(from: source, at: 0)
        #expect(imported.legacyComments.first?.authorName == "Reviewer")
        #expect(imported.legacyComments.first?.authorID != "1")
        #expect(try dest.slides[0].legacyComments.first?.authorID == "1")
        #expect(records(try destAuthors.dom(), legacy: true).count == 2)
    }
    @Test func distinctEqualByteNodesRemainDistinctAcrossRootRelationships() throws {
        let (source, authors, record, payload) = try fixture(legacy: false)
        let (dest, installed, _, _) = try fixture(legacy: false)
        let second = source.package.addPart(uri: PackURI("/ppt/custom/second.xml"), contentType: payload.contentType, blob: payload.blob)
        authors.rels.add(rId: "rId2", type: "urn:author-payload", target: authors.uri.relativeReference(to: second.uri))
        record.appendElement(XML.Element("custom:payload", attributes: [("rel:id", "rId2"), ("r:id", "opaque-token")]))
        authors.markDirty()
        let imported = try dest.slides.import(from: source, at: 0)
        let id = try commentID(imported, legacy: false)
        let importedRecord = try #require(records(installed.dom(), legacy: false).first { $0[attribute: "id"] == id })
        let ids = importedRecord.children(named: "custom:payload").compactMap { $0[attribute: "rel:id"] }
        #expect(Set(ids).count == 2)
        let targets = try ids.map { id in
            let rel = try #require(installed.rels.relationship(withId: id))
            return PackURI.resolve(target: rel.target, relativeTo: installed.uri.baseURI)
        }
        #expect(Set(targets).count == 2)
        #expect(installed.rels.items.count == 2)
        #expect(try dest.package.part(at: targets[0]).blob == dest.package.part(at: targets[1]).blob)
    }

    @Test func relationshipBearingMediaDoesNotReuseDestinationLeaf() throws {
        let (source, authors, _, payload) = try fixture(legacy: false)
        let media = source.package.addPart(uri: PackURI("/ppt/media/custom.bin"), contentType: "application/octet-stream", blob: Data([1, 2, 3]))
        media.rels.add(type: "urn:back", target: media.uri.relativeReference(to: payload.uri))
        payload.rels.add(type: "urn:media", target: payload.uri.relativeReference(to: media.uri))
        let dest = try Presentation()
        let leaf = dest.package.addPart(uri: PackURI("/ppt/media/existing.bin"), contentType: media.contentType, blob: media.blob)
        _ = try dest.slides.import(from: source, at: 0)
        let installed = try authorPart(dest, legacy: false)
        let copiedPayload = try installed.related(by: "urn:author-payload", in: dest.package)
        let copiedMedia = try copiedPayload.related(by: "urn:media", in: dest.package)
        #expect(copiedMedia !== leaf)
        #expect(copiedMedia.blob == media.blob)
        #expect(try copiedMedia.related(by: "urn:back", in: dest.package) === copiedPayload)
        #expect(authors.rels.items.count == 1)
    }

    @Test func laterInvalidCommentRollsBackAlreadyPreparedDependencyGraph() throws {
        let (source, _, _, _) = try fixture(legacy: false)
        let second = try source.slides.add()
        let bad = try second.addComment("invalid", author: "Reviewer")
        bad.cm[attribute: "authorId"] = "missing"; bad.part.markDirty()
        let dest = try Presentation()
        let before = try dest.serializedData()
        #expect(throws: RostrumError.self) { _ = try dest.slides.importAll(from: source) }
        #expect(try dest.serializedData() == before)
    }

    @Test func authorGUIDCaseAndAssignedToReferencesResolveWithoutChangingIdentity() throws {
        let (source, authors, record, _) = try fixture(legacy: false)
        let comment = try source.slides[0].comments[0]
        let id = try #require(record[attribute: "id"])
        comment.cm[attribute: "authorId"] = id.lowercased()
        comment.cm[attribute: "assignedTo"] = id.lowercased()
        comment.part.markDirty()
        let dest = try Presentation()
        let imported = try dest.slides.import(from: source, at: 0)
        #expect(imported.comments[0].cm[attribute: "authorId"] == id)
        #expect(imported.comments[0].cm[attribute: "assignedTo"] == id)
        #expect(try authors.dom().serialized().contains(id))
    }

    @Test(arguments: [false, true]) func linkedCommentBodiesRefuseWithoutOwnerContext(legacy: Bool) throws {
        let (source, authors, _, _) = try fixture(legacy: legacy)
        let second = try source.slides.add()
        if legacy { _ = try second.addLegacyComment("linked", author: "Reviewer") }
        else { _ = try second.addComment("linked", author: "Reviewer") }
        let comments = try commentPart(second, legacy: legacy)
        authors.rels.add(type: "urn:linked-comments", target: authors.uri.relativeReference(to: comments.uri))
        let dest = try Presentation()
        let before = try dest.serializedData()
        #expect(throws: RostrumError.self) { _ = try dest.slides.import(from: source, at: 0) }
        #expect(try dest.serializedData() == before)
        let sourceBefore = try source.serializedData()
        #expect(throws: RostrumError.self) { _ = try source.slides.import(from: source, at: 0) }
        #expect(try source.serializedData() == sourceBefore)
        if legacy {
            // Direct duplication keeps presentation-owned author dependencies.
            _ = try source.slides.duplicate(at: 0)
            #expect(try authors.related(by: "urn:linked-comments", in: source.package) === comments)
        }
    }

    @Test func candidateComparisonsShareOneOperationBudget() throws {
        let (source, authors, _, _) = try fixture(legacy: false)
        let (dest, installed, _, _) = try fixture(legacy: false)
        // Equal-byte external identities still require checking exact targets.
        // This bounded fixture exhausts comparison work without a deep graph.
        for index in 0..<1001 {
            authors.rels.add(type: "urn:source", target: "https://example.org/source/\(index)", isExternal: true)
            installed.rels.add(type: "urn:destination", target: "https://example.org/dest/\(index)", isExternal: true)
        }
        let before = try dest.serializedData()
        #expect(throws: RostrumError.self) { _ = try dest.slides.import(from: source, at: 0) }
        #expect(try dest.serializedData() == before)
    }

    @Test func realPowerPointAuthorsImportWithCustomExtensionGraph() throws {
        let url = (Bundle.module.resourceURL ?? Bundle.module.bundleURL)
            .appendingPathComponent("Fixtures/RealDecks/MovieAndComments.pptx")
        let source = try Presentation(data: Data(contentsOf: url))
        let slideIndex = try #require(Array(source.slides).firstIndex { !$0.comments.isEmpty })
        let sourceAuthor = try #require(source.slides[slideIndex].comments.first?.author)
        let authors = try authorPart(source, legacy: false)
        let record = try #require(records(authors.dom(), legacy: false).first)
        let payload = source.package.addPart(uri: PackURI("/custom/author-extension.xml"), contentType: "application/xml",
            blob: Data("<?extension retain?><custom xmlns=\"urn:rel3-oracle\"><!--keep-->Office author payload</custom>".utf8))
        let rel = authors.rels.add(type: "urn:rel3-oracle", target: authors.uri.relativeReference(to: payload.uri))
        // MS-PPTX CT_Author specifies p188:extLst with p:CT_ExtensionList.
        let extensionNode = XML.Element("p:ext", attributes: [("xmlns:p", MinimalTemplate.nsP), ("uri", "urn:rel3-oracle")],
            children: [.element(XML.Element("custom:payload", attributes: [("xmlns:custom", "urn:rel3-oracle"), ("xmlns:rel", MinimalTemplate.nsR), ("rel:id", rel)]))])
        record.appendElement(XML.Element(ModernComments.qualified("extLst", like: record), children: [.element(extensionNode)]))
        authors.markDirty()
        let dest = try Presentation()
        let imported = try dest.slides.import(from: source, at: slideIndex)
        #expect(imported.comments.first?.author == sourceAuthor)
        #expect(try authorPart(dest, legacy: false).related(by: "urn:rel3-oracle", in: dest.package).blob == payload.blob)
        let saved = try dest.serializedData()
        #expect(try Presentation(data: saved).serializedData() == saved)
        if let output = ProcessInfo.processInfo.environment["ROSTRUM_REL3_REVIEW_OUTPUT"] {
            try saved.write(to: URL(fileURLWithPath: output))
        }
    }

}
