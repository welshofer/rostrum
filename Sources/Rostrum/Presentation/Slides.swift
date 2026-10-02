import Foundation

/// The slide collection: a live view over `p:sldIdLst`, the presentation
/// part's relationships, and the slide parts themselves.
///
/// Includes the three operations python-pptx never shipped: `remove(at:)`,
/// `move(from:to:)`, and `duplicate(at:)`.
public final class Slides: Sequence {
    let package: OPCPackage
    let presentationPart: Part

    init(package: OPCPackage, presentationPart: Part) {
        self.package = package
        self.presentationPart = presentationPart
    }

    private func sldIdLst() throws -> XML.Element {
        try presentationPart.dom().getOrAddChild(
            "p:sldIdLst", beforeAnyOf: ["p:sldSz", "p:notesSz"])
    }

    // MARK: - Reading

    public var count: Int {
        (try? sldIdLst())?.childElements.count ?? 0
    }

    /// The slide at `index`. Throws on out-of-range and on malformed decks
    /// (a `sldId` whose relationship or part cannot be resolved) — opening
    /// untrusted files must never abort the host process.
    public subscript(index: Int) -> Slide {
        get throws {
            try slide(at: index)
        }
    }

    public func slide(at index: Int) throws -> Slide {
        let entries = try sldIdLst().childElements
        guard entries.indices.contains(index) else {
            throw RostrumError.packageInvalid("slide index \(index) out of range 0..<\(entries.count)")
        }
        guard let rId = entries[index][attribute: "r:id"],
              let rel = presentationPart.rels.relationship(withId: rId) else {
            throw RostrumError.packageInvalid("sldId at index \(index) has no resolvable r:id")
        }
        let uri = PackURI.resolve(target: rel.target, relativeTo: presentationPart.uri.baseURI)
        return Slide(part: try package.part(at: uri), package: package)
    }

    /// Iterates an operation-local snapshot of the resolvable slide identities. Entries whose relationship or part is
    /// missing are skipped — `for`-`in` cannot throw, and a malformed deck
    /// must never abort the host process. Use `slide(at:)` to surface the
    /// underlying error for a specific index.
    public func makeIterator() -> AnyIterator<Slide> {
        // Snapshot the operation, not the mutable DOM's lifetime. This avoids
        // rescanning the entire slide-id list and relationships for each item.
        let entries = (try? sldIdLst().childElements) ?? []
        var byID: [String: Relationship] = [:]
        for rel in presentationPart.rels.items where byID[rel.rId] == nil { byID[rel.rId] = rel }
        let uris = entries.compactMap { entry -> PackURI? in
            guard let id = entry[attribute: "r:id"], let rel = byID[id] else { return nil }
            return PackURI.resolve(target: rel.target, relativeTo: presentationPart.uri.baseURI)
        }
        var iterator = uris.makeIterator()
        return AnyIterator {
            while let uri = iterator.next() {
                if let part = try? self.package.part(at: uri) { return Slide(part: part, package: self.package) }
            }
            return nil
        }
    }

    // MARK: - Mutation

    /// Append a new blank slide (using the deck's first layout) and return it.
    @discardableResult
    public func add() throws -> Slide {
        let uri = nextSlideURI()
        let slideID = try nextSlideID()
        let layout = try firstLayoutPart()
        let list = try sldIdLst()
        let oldIDs = list.childElements.compactMap { $0[attribute: "id"].flatMap(Int.init) }
        let sections = try Sections(package: package, presentationPart: presentationPart)
            .maintainSectionMembership(order: oldIDs + [slideID], insertedIDs: [slideID])
        let part = package.addPart(
            uri: uri, contentType: ContentType.slide,
            blob: Data(MinimalTemplate.slideXML.utf8))
        part.rels.add(type: RelType.slideLayout, target: uri.relativeReference(to: layout.uri))

        let rId = presentationPart.rels.add(
            type: RelType.slide,
            target: presentationPart.uri.relativeReference(to: uri))

        let entry = XML.Element("p:sldId", attributes: [
            ("id", String(slideID)), ("r:id", rId),
        ])
        list.appendElement(entry)
        sections?.commit()
        presentationPart.markDirty()
        return Slide(part: part, package: package)
    }

    /// Remove the slide at `index`: drops its `sldId` entry, its relationship,
    /// and its part.
    public func remove(at index: Int) throws {
        let list = try sldIdLst()
        let entries = list.childElements
        guard entries.indices.contains(index) else {
            throw RostrumError.packageInvalid("slide index \(index) out of range 0..<\(entries.count)")
        }
        let entry = entries[index]
        let remainingIDs = entries.enumerated().filter { $0.offset != index }
            .compactMap { $0.element[attribute: "id"].flatMap(Int.init) }
        let sections = try Sections(package: package, presentationPart: presentationPart)
            .maintainSectionMembership(order: remainingIDs)
        if let rId = entry[attribute: "r:id"],
           let rel = presentationPart.rels.relationship(withId: rId) {
            let uri = PackURI.resolve(target: rel.target, relativeTo: presentationPart.uri.baseURI)
            let annotations = try annotationRemovalPlan(for: try package.part(at: uri))
            presentationPart.rels.remove(rId: rId)
            package.removePart(at: uri)
            for annotationURI in annotations.removed { package.removePart(at: annotationURI) }
            for (part, relationships) in annotations.retained {
                part.rels.setItems(relationships)
            }
        }
        list.removeChild(entry)
        sections?.commit()
        presentationPart.markDirty()
    }

    /// Move the slide at `from` to position `to` (positions after removal,
    /// Array.move semantics).
    public func move(from: Int, to: Int) throws {
        let list = try sldIdLst()
        var entries = list.childElements
        guard entries.indices.contains(from), entries.indices.contains(to) else {
            throw RostrumError.packageInvalid("move(\(from)→\(to)) out of range 0..<\(entries.count)")
        }
        let entry = entries.remove(at: from)
        entries.insert(entry, at: to)
        let order = entries.compactMap { $0[attribute: "id"].flatMap(Int.init) }
        let sections = try Sections(package: package, presentationPart: presentationPart)
            .maintainSectionMembership(order: order, insertedAt: to,
                                      moving: entry[attribute: "id"].flatMap(Int.init))
        list.replaceChildElements(with: entries)
        sections?.commit()
        presentationPart.markDirty()
    }

    /// Duplicate the slide at `index`, inserting the copy immediately after
    /// the original. Copies slide-owned notes and comments independently;
    /// layout, notes master, authors and media remain shared.
    @discardableResult
    public func duplicate(at index: Int) throws -> Slide {
        let source = try slide(at: index)
        source.part.flushIfDirty()

        let uri = nextSlideURI()
        let slideID = try nextSlideID()
        let list = try sldIdLst()
        var entries = list.childElements
        // Resolve and parse every annotation before changing the package. A
        // missing or malformed part must not leave a half-inserted duplicate.
        let annotations = try copySlideAnnotations(from: source.part, to: uri, slideID: slideID)
        var order = entries.compactMap { $0[attribute: "id"].flatMap(Int.init) }
        order.insert(slideID, at: index + 1)
        let sections = try Sections(package: package, presentationPart: presentationPart)
            .maintainSectionMembership(order: order, insertedAt: index + 1,
                                      insertedIDs: [slideID], duplicateOf: try source.slideID())

        let copy = package.addPart(uri: uri, contentType: ContentType.slide, blob: source.part.blob)
        copy.rels.setItems(annotations.relationships)
        for annotation in annotations.parts {
            let installed = package.addPart(
                uri: annotation.uri, contentType: annotation.contentType, blob: annotation.blob)
            installed.rels.setItems(annotation.rels.items)
        }
        annotations.legacyAuthors?.commit()
        let rId = presentationPart.rels.add(
            type: RelType.slide,
            target: presentationPart.uri.relativeReference(to: uri))
        let entry = XML.Element("p:sldId", attributes: [
            ("id", String(slideID)), ("r:id", rId),
        ])
        entries.insert(entry, at: index + 1)
        list.replaceChildElements(with: entries)
        sections?.commit()
        presentationPart.markDirty()
        return Slide(part: copy, package: package)
    }

    // MARK: - Allocation

    private func nextSlideURI() -> PackURI {
        var n = 1
        while package.parts[PackURI("/ppt/slides/slide\(n).xml")] != nil { n += 1 }
        return PackURI("/ppt/slides/slide\(n).xml")
    }

    /// sldId values live in 256..<2147483648.
    private func nextSlideID() throws -> Int {
        // Bounded: an id of Int.max parses fine and then overflows the +1.
        let used = (try? sldIdLst())?.childElements
            .compactMap { $0.boundedInt("id", in: OOXMLBounds.slideID) } ?? []
        let highest = Swift.max(255, used.max() ?? 255)
        guard highest < OOXMLBounds.slideID.upperBound else {
            throw RostrumError.packageInvalid(
                "slide ids reach the format's maximum; there is no id left to assign")
        }
        return highest + 1
    }

    private func firstLayoutPart() throws -> Part {
        let master = try firstPresentationMaster(presentationPart, in: package)
        guard let entry = try master.dom().firstChild(named: "p:sldLayoutIdLst")?.children(named: "p:sldLayoutId").first,
              let id = entry[attribute: "r:id"], let relationship = master.rels.relationship(withId: id),
              relationship.type == RelType.slideLayout, !relationship.isExternal else {
            throw RostrumError.packageInvalid("slide master has no resolvable first layout")
        }
        return try package.part(at: PackURI.resolve(target: relationship.target, relativeTo: master.uri.baseURI))
    }
}
