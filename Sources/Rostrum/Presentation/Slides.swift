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

    /// Iterates the resolvable slides. Entries whose relationship or part is
    /// missing are skipped — `for`-`in` cannot throw, and a malformed deck
    /// must never abort the host process. Use `slide(at:)` to surface the
    /// underlying error for a specific index.
    public func makeIterator() -> AnyIterator<Slide> {
        var index = 0
        return AnyIterator {
            while index < self.count {
                defer { index += 1 }
                if let slide = try? self.slide(at: index) { return slide }
            }
            return nil
        }
    }

    // MARK: - Mutation

    /// Append a new blank slide (using the deck's first layout) and return it.
    @discardableResult
    public func add() throws -> Slide {
        let uri = nextSlideURI()
        let part = package.addPart(
            uri: uri, contentType: ContentType.slide,
            blob: Data(MinimalTemplate.slideXML.utf8))

        let layout = try firstLayoutPart()
        part.rels.add(type: RelType.slideLayout, target: uri.relativeReference(to: layout.uri))

        let rId = presentationPart.rels.add(
            type: RelType.slide,
            target: presentationPart.uri.relativeReference(to: uri))

        let entry = XML.Element("p:sldId", attributes: [
            ("id", String(try nextSlideID())), ("r:id", rId),
        ])
        try sldIdLst().appendElement(entry)
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
        if let rId = entry[attribute: "r:id"],
           let rel = presentationPart.rels.relationship(withId: rId) {
            let uri = PackURI.resolve(target: rel.target, relativeTo: presentationPart.uri.baseURI)
            presentationPart.rels.remove(rId: rId)
            package.removePart(at: uri)
        }
        list.removeChild(entry)
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
        list.replaceChildElements(with: entries)
        presentationPart.markDirty()
    }

    /// Duplicate the slide at `index`, inserting the copy immediately after
    /// the original. Copies the slide XML and its relationships.
    @discardableResult
    public func duplicate(at index: Int) throws -> Slide {
        let source = try slide(at: index)
        source.part.flushIfDirty()

        let uri = nextSlideURI()
        let copy = package.addPart(uri: uri, contentType: ContentType.slide, blob: source.part.blob)
        // Relationship targets are relative to /ppt/slides for both parts, so
        // they copy verbatim; rIds are preserved because the slide XML
        // references them by value.
        copy.rels.setItems(source.part.rels.items)

        let rId = presentationPart.rels.add(
            type: RelType.slide,
            target: presentationPart.uri.relativeReference(to: uri))
        let entry = XML.Element("p:sldId", attributes: [
            ("id", String(try nextSlideID())), ("r:id", rId),
        ])
        let list = try sldIdLst()
        var entries = list.childElements
        entries.insert(entry, at: index + 1)
        list.replaceChildElements(with: entries)
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
        let master = try presentationPart.related(by: RelType.slideMaster, in: package)
        return try master.related(by: RelType.slideLayout, in: package)
    }
}
