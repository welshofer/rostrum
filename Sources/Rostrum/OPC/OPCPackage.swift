import Foundation

/// One part in the package: a name, a content type, bytes, and its outgoing
/// relationships.
///
/// Pristine-until-mutated (the architecture's core mechanism): `blob` holds
/// the original bytes and stays authoritative until a facade mutates the DOM
/// and calls `markDirty()`. From then on the DOM is authoritative (one-way
/// flip) and `blob` is refreshed on flush. Parts never touched re-emit their
/// original bytes exactly — lossless round-trip by construction.
public final class Part {
    public let uri: PackURI
    /// The OPC content type. Settable within the library so a template's main
    /// part can be normalized to a presentation on open; read-only to callers.
    public internal(set) var contentType: String
    public let rels: Relationships

    /// The part's serialized bytes. Authoritative while `isDirty` is false.
    public internal(set) var blob: Data

    private var cachedDocument: XML.Document?
    public private(set) var isDirty = false

    public init(uri: PackURI, contentType: String, blob: Data, rels: Relationships = Relationships()) {
        self.uri = uri
        self.contentType = contentType
        self.blob = blob
        self.rels = rels
    }

    /// The part's DOM, parsed once and cached. Reading it does NOT flip
    /// authority — call `markDirty()` after any mutation.
    ///
    /// Parsed as a whole document, not a bare root: a comment or processing
    /// instruction ahead of the root element is XML we do not model, and a
    /// re-serialized part has to give it back.
    public func dom() throws -> XML.Element {
        if let cachedDocument { return cachedDocument.root }
        let document = try XML.parseDocument(blob)
        cachedDocument = document
        return document.root
    }

    /// Flip authority to the DOM. Every facade setter must call this; it is
    /// the single funnel that keeps blob/DOM coherence a checkable invariant.
    public func markDirty() {
        isDirty = true
    }

    /// Replace the part's bytes wholesale, discarding any cached DOM.
    public func replaceBlob(_ data: Data) {
        blob = data
        cachedDocument = nil
        isDirty = false
    }

    /// Re-serialize the DOM into `blob` if (and only if) it was mutated.
    func flushIfDirty() {
        guard isDirty, let cachedDocument else { return }
        blob = XML.document(cachedDocument)
        isDirty = false
    }

    /// The part a relationship of `type` points at, resolved through `package`.
    public func related(by type: String, in package: OPCPackage) throws -> Part {
        guard let rel = rels.first(ofType: type) else {
            throw RostrumError.packageInvalid("part \(uri) has no relationship of type \(type)")
        }
        return try package.part(at: PackURI.resolve(target: rel.target, relativeTo: uri.baseURI))
    }
}

/// An Open Packaging Conventions package: the zip container, the content-types
/// stream, and the relationship graph. Format-agnostic — knows nothing about
/// slides (that's `Presentation`'s job), exactly like python-pptx's `OpcPackage`.
public final class OPCPackage {
    public private(set) var parts: [PackURI: Part]
    /// Package-level relationships (`/_rels/.rels`).
    public let rels: Relationships
    public internal(set) var contentTypes: ContentTypesMap

    /// Zip entries whose name ends in "/": directory placeholders, which some
    /// writers emit and which are not parts. Kept verbatim so an untouched deck
    /// still round-trips every entry — dropping them silently made a foreign
    /// deck come back with fewer entries than it went in with, which is exactly
    /// what the corpus gate exists to catch.
    ///
    /// Stored in the order they arrived; `serialize()` sorts them on the way
    /// out, which is where determinism actually has to hold.
    private(set) var directoryEntries: [(name: String, data: Data)] = []

    /// `.rels` entries no part claims — an orphan, or a rels stream at a name
    /// `PackURI.relsURI` does not derive. Same reason as `directoryEntries`:
    /// read, not modelled, and previously not written back.
    private(set) var orphanRelationshipStreams: [(name: String, data: Data)] = []

    /// Diagnostics from `read`: carried entries (directory placeholders,
    /// orphan `.rels` streams) that could not be decoded and were dropped.
    /// Opening must survive them — they are not parts, and failing the whole
    /// package over one was worse — but a resave without them is not a
    /// byte-perfect round trip, and lossless round-tripping is this library's
    /// standing rule. The loss is therefore RECORDED, never silent: empty
    /// means the package read back everything it will write.
    public private(set) var readWarnings: [String] = []

    public init() {
        parts = [:]
        rels = Relationships()
        contentTypes = ContentTypesMap()
    }

    // MARK: - Reading

    /// Open a package.
    ///
    /// - Parameter limits: ceilings applied to the archive before anything is
    ///   decompressed. Defaults to `.default` (4 GiB of declared uncompressed
    ///   bytes) so untrusted input is bounded out of the box; pass
    ///   `.unlimited` for archives you already trust.
    public static func read(data: Data, limits: ZipReader.Limits = .default) throws -> OPCPackage {
        let zip = try ZipReader(data: data, limits: limits)

        guard zip.contains(PackURI.contentTypes.memberName) else {
            throw RostrumError.packageInvalid("missing [Content_Types].xml — not an OPC package")
        }
        let package = OPCPackage()
        package.contentTypes = try ContentTypesMap.parse(zip.data(forEntry: PackURI.contentTypes.memberName))

        // First pass: create every non-rels part with its content type.
        for name in zip.entryNames {
            if name == PackURI.contentTypes.memberName { continue }
            if name.hasSuffix(".rels") { continue }
            if name.hasSuffix("/") {
                // A directory placeholder, not a part. Carry it rather than
                // drop it: `serialize()` re-emits it, so the entry survives.
                //
                // Recovered, not `try`: before this branch existed the entry
                // was never touched, so nothing about its payload could stop a
                // deck opening. Decoding it makes every per-entry failure —
                // encrypted, unsupported method, bad CRC, truncated stream —
                // fatal to the whole package for something that is not even a
                // part. Carrying it is a fidelity improvement and must not cost
                // the ability to open the file — but a dropped entry is a lossy
                // round trip, so the drop lands in `readWarnings` rather than
                // happening silently.
                do {
                    package.directoryEntries.append((name, try zip.data(forEntry: name)))
                } catch {
                    package.readWarnings.append(
                        "directory placeholder \"\(name)\" could not be decoded and will not "
                            + "survive a resave: \(error)")
                }
                continue
            }
            // OPC part names have no empty segments (M1.1). Rostrum has to
            // reject them rather than tolerate them, because `PackURI`'s
            // identity is its raw string while `baseURI`/`filename` split on
            // "/" discarding empties: "ppt//slides/s.xml" and
            // "ppt/slides/s.xml" would be two distinct parts sharing one
            // `_rels/s.xml.rels`. That is a part-identity bug on its own, and
            // it lets an archive make the reader decode a single .rels entry
            // once per alias — work the read budget charged for once.
            // An EMPTY name is the same bug with no visible slash at all:
            // "/" + "" is `/`, whose relsURI is `/_rels/.rels` — the package
            // relationships. It passes both tests above (no prefix, no "//").
            guard !PackURI.hasEmptySegment(name) else {
                throw RostrumError.packageInvalid(
                    "part name \"\(name)\" has an empty segment")
            }
            let uri = PackURI("/" + name)
            let blob = try zip.data(forEntry: name)
            let ct = try package.contentTypes.contentType(for: uri)
            package.parts[uri] = Part(uri: uri, contentType: ct, blob: blob)
        }

        // Second pass: attach relationships to the package and to each part,
        // preserving parsed rIds verbatim — part XML references them by value.
        // `adopt`, not `setItems`: the parsed collection carries the bytes it
        // came from, and an untouched `.rels` part must re-emit them verbatim.
        if zip.contains(PackURI.packageRels.memberName) {
            let parsed = try Relationships.parse(zip.data(forEntry: PackURI.packageRels.memberName))
            package.rels.adopt(parsed)
        }
        var consumed: Set<String> = [PackURI.packageRels.memberName]
        for (uri, part) in package.parts {
            let relsName = uri.relsURI.memberName
            guard zip.contains(relsName) else { continue }
            consumed.insert(relsName)
            let parsed = try Relationships.parse(zip.data(forEntry: relsName))
            part.rels.adopt(parsed)
        }

        // The twin of the directory-placeholder skip, and it was missed the
        // first time: a `.rels` entry that no part claims is read, never
        // modelled, and was never written back. That happens for an orphan
        // (`_rels/slide9.xml.rels` with no `slide9.xml`) and for any rels
        // stream at a name `relsURI` does not derive. Carry those verbatim.
        //
        // Decided HERE rather than at the skip in the first pass, and that
        // ordering is load-bearing: carrying them earlier would emit both the
        // carried entry and the one `serialize()` derives for the real part,
        // giving two zip members with one name.
        for name in zip.entryNames where name.hasSuffix(".rels") && !consumed.contains(name) {
            do {
                package.orphanRelationshipStreams.append((name, try zip.data(forEntry: name)))
            } catch {
                package.readWarnings.append(
                    "orphan relationship stream \"\(name)\" could not be decoded and will not "
                        + "survive a resave: \(error)")
            }
        }
        return package
    }

    // MARK: - Composition

    public func part(at uri: PackURI) throws -> Part {
        guard let part = parts[uri] else { throw RostrumError.partMissing(uri.value) }
        return part
    }

    @discardableResult
    public func addPart(uri: PackURI, contentType: String, blob: Data) -> Part {
        let part = Part(uri: uri, contentType: contentType, blob: blob)
        parts[uri] = part
        contentTypes.setOverride(partName: uri, contentType: contentType)
        return part
    }

    public func removePart(at uri: PackURI) {
        parts[uri] = nil
        contentTypes.removeOverride(partName: uri)
    }

    /// The part the package-level officeDocument relationship points at
    /// (`/ppt/presentation.xml` in a .pptx).
    public func mainDocumentPart() throws -> Part {
        guard let rel = rels.first(ofType: RelType.officeDocument) else {
            throw RostrumError.packageInvalid("package has no officeDocument relationship")
        }
        return try part(at: PackURI.resolve(target: rel.target, relativeTo: "/"))
    }

    /// Extensions whose bytes are already a compressed container. Re-DEFLATEing
    /// one costs a full pass plus several times the payload in transient
    /// buffers and never shrinks it, so the result is thrown away. `wav` is
    /// deliberately absent: PCM audio is uncompressed and does compress.
    private static let storedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "xlsx", "zip",
        "mp4", "m4v", "mov", "avi", "wmv", "mp3", "m4a",
    ]

    // MARK: - Writing

    /// Serialize to zip bytes. Deterministic: [Content_Types].xml first, then
    /// package rels, then parts sorted by URI, each followed by its rels part.
    /// Only dirty parts are re-serialized; pristine parts emit original bytes.
    /// Why `read` would not give this part name back, or nil if it would.
    ///
    /// Kept beside `read`'s own skips so the two stay in step: every class
    /// `read` disposes of by `continue` is a part the writer must not emit,
    /// because emitting it means writing bytes that quietly disappear.
    static func unwritablePartName(_ uri: PackURI) -> String? {
        let name = uri.memberName
        if PackURI.hasEmptySegment(name) { return "has an empty segment" }
        if name == PackURI.contentTypes.memberName {
            return "collides with the content-types stream"
        }
        if name.hasSuffix(".rels") {
            return "would be read back as a relationships part, not as a part"
        }
        return nil
    }

    public func serialize() throws -> Data {
        for part in parts.values {
            part.flushIfDirty()
        }
        var zip = ZipWriter()
        zip.addFile(name: PackURI.contentTypes.memberName, data: contentTypes.serialized())
        if rels.isWritten {
            zip.addFile(name: PackURI.packageRels.memberName, data: rels.serialized())
        }
        // Every name this method will derive from a live part. A carried entry
        // is dropped when it collides with one, because two zip members under
        // one name is a malformed package that nothing here would notice: the
        // reader's duplicate handling is last-wins for byte-identical names, so
        // the carried bytes would silently vanish on reopen and the resave
        // would stop being a fixed point.
        //
        // This has to be computed rather than reasoned about. `read` classifies
        // a `.rels` entry as an orphan against the parts that existed AT READ
        // TIME, and every part-name allocator (`Slides.nextSlideURI`,
        // `Notes.createNotesPart`, `imagePart`, `DeckMerge`) picks the lowest
        // free slot from `parts` alone — so opening a deck whose producer left
        // `_rels/slide2.xml.rels` behind and then calling `slides.add()` gives
        // the new slide exactly that name, and its derived rels collides with
        // the carried orphan. An ordering argument cannot close that; only
        // checking the names can.
        var derived: Set<String> = [PackURI.contentTypes.memberName]
        if rels.isWritten {
            derived.insert(PackURI.packageRels.memberName)
        }
        for (uri, part) in parts {
            derived.insert(uri.memberName)
            if part.rels.isWritten {
                derived.insert(uri.relsURI.memberName)
            }
        }

        // Carried entries next, each sorted — a fixed position and a fixed
        // order, so output is deterministic and resaving is a fixed point.
        for entry in orphanRelationshipStreams.sorted(by: { $0.name < $1.name })
        where !derived.contains(entry.name) {
            zip.addFile(name: entry.name, data: entry.data)
        }
        for entry in directoryEntries.sorted(by: { $0.name < $1.name })
        where !derived.contains(entry.name) {
            // Compress like any other entry. A placeholder is normally empty,
            // where compression is a no-op either way; the no-compress flag
            // only mattered for a hostile non-empty one, and there it made
            // Rostrum write out the full expansion of what it had inflated.
            zip.addFile(name: entry.name, data: entry.data)
        }
        for (uri, part) in parts.sorted(by: { $0.key.value < $1.key.value }) {
            // Refuse to write a name `read` would not give back. `PackURI`'s
            // initializer only requires a leading slash, so a caller can build
            // any of these — and without this, Rostrum produces an archive it
            // then rejects, or worse, silently reads back as something else.
            //
            // `read` disposes of four name classes, and the first cut of this
            // guard implemented one of them while its comment claimed all four.
            // The three it missed do not throw on the way back in; they vanish.
            // A part named "/custom.rels" is skipped as a relationships stream,
            // one named "/[Content_Types].xml" collides with the stream written
            // above this loop and reopens as whichever came last, and a
            // trailing slash reads as a directory placeholder.
            if let reason = Self.unwritablePartName(uri) {
                throw RostrumError.packageInvalid(
                    "part name \"\(uri.value)\" \(reason)")
            }
            // Media and embedded workbooks are already compressed — don't
            // waste CPU re-DEFLATEing them; XML parts compress well.
            let alreadyCompressed = Self.storedExtensions.contains(uri.ext)
            zip.addFile(name: uri.memberName, data: part.blob, compress: !alreadyCompressed)
            // `isWritten`, not `!isEmpty`: a `<Relationships/>` with no
            // children is legal OPC and some producers emit it, and gating on
            // emptiness dropped it on resave. A part Rostrum created with no
            // relationships still gets no `.rels` entry. The same predicate
            // decides which carried entries would collide, which is why it is
            // one definition rather than a condition repeated at four sites.
            if part.rels.isWritten {
                zip.addFile(name: uri.relsURI.memberName, data: part.rels.serialized())
            }
        }
        return try zip.finalize()
    }
}
