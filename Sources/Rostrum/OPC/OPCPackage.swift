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

    private var cachedDOM: XML.Element?
    public private(set) var isDirty = false

    public init(uri: PackURI, contentType: String, blob: Data, rels: Relationships = Relationships()) {
        self.uri = uri
        self.contentType = contentType
        self.blob = blob
        self.rels = rels
    }

    /// The part's DOM, parsed once and cached. Reading it does NOT flip
    /// authority — call `markDirty()` after any mutation.
    public func dom() throws -> XML.Element {
        if let cachedDOM { return cachedDOM }
        let dom = try XML.parse(blob)
        cachedDOM = dom
        return dom
    }

    /// Flip authority to the DOM. Every facade setter must call this; it is
    /// the single funnel that keeps blob/DOM coherence a checkable invariant.
    public func markDirty() {
        isDirty = true
    }

    /// Replace the part's bytes wholesale, discarding any cached DOM.
    public func replaceBlob(_ data: Data) {
        blob = data
        cachedDOM = nil
        isDirty = false
    }

    /// Re-serialize the DOM into `blob` if (and only if) it was mutated.
    func flushIfDirty() {
        guard isDirty, let cachedDOM else { return }
        blob = XML.document(cachedDOM)
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
    /// what the corpus gate exists to catch. Sorted, so output stays
    /// deterministic regardless of the order they arrived in.
    private(set) var directoryEntries: [(name: String, data: Data)] = []

    public init() {
        parts = [:]
        rels = Relationships()
        contentTypes = ContentTypesMap()
    }

    // MARK: - Reading

    /// Open a package.
    ///
    /// - Parameter limits: ceilings applied to the archive before anything is
    ///   decompressed. Defaults to `.unlimited`; pass a budget when the bytes
    ///   came from somewhere you do not control.
    public static func read(data: Data, limits: ZipReader.Limits = .unlimited) throws -> OPCPackage {
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
                package.directoryEntries.append((name, try zip.data(forEntry: name)))
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
        for (uri, part) in package.parts {
            let relsName = uri.relsURI.memberName
            guard zip.contains(relsName) else { continue }
            let parsed = try Relationships.parse(zip.data(forEntry: relsName))
            part.rels.adopt(parsed)
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
        if !rels.isEmpty {
            zip.addFile(name: PackURI.packageRels.memberName, data: rels.serialized())
        }
        // Directory placeholders next, sorted — a fixed position and a fixed
        // order, so the output is deterministic and resaving is a fixed point.
        for entry in directoryEntries.sorted(by: { $0.name < $1.name }) {
            zip.addFile(name: entry.name, data: entry.data, compress: false)
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
            if !part.rels.isEmpty {
                zip.addFile(name: uri.relsURI.memberName, data: part.rels.serialized())
            }
        }
        return try zip.finalize()
    }
}
