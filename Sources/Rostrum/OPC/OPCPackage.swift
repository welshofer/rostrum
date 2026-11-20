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
    enum DeferredBlob {
        /// Stream and CRC already verified via `Inflate.verify` at open;
        /// guaranteed to inflate cleanly to `expectedSize` bytes.
        case verifiedDeflate(raw: Data, expectedSize: Int)
        /// Extracted raw archive entry (`validation: .onAccess`), decoded and
        /// CRC-verified on first read.
        case onAccess(raw: Data, entry: ZipReader.Entry)

        var declaredSize: Int {
            switch self {
            case .verifiedDeflate(_, let expectedSize): return expectedSize
            case .onAccess(_, let entry): return entry.uncompressedSize
            }
        }
    }

    public let uri: PackURI
    /// The OPC content type. Settable within the library so a template's main
    /// part can be normalized to a presentation on open; read-only to callers.
    public internal(set) var contentType: String
    public let rels: Relationships

    fileprivate var materializedBlob: Data?
    fileprivate var deferredBlob: DeferredBlob?
    private(set) var deferredDecodeError: (any Error)?
    var onDeferredDecodeFailure: ((PackURI, any Error) -> Void)?

    /// Whether the uncompressed byte buffer has been materialized in memory.
    var isBlobMaterialized: Bool { materializedBlob != nil }

    /// Uncompressed byte count without forcing inflation of clean archive parts.
    var uncompressedByteCount: Int {
        materializedBlob?.count ?? deferredBlob?.declaredSize ?? 0
    }

    /// The part's serialized bytes. Authoritative while `isDirty` is false.
    public internal(set) var blob: Data {
        get {
            if let materializedBlob { return materializedBlob }
            do {
                return try decodedData()
            } catch {
                if deferredDecodeError == nil {
                    deferredDecodeError = error
                    onDeferredDecodeFailure?(uri, error)
                }
                return Data()
            }
        }
        set {
            materializedBlob = newValue
            deferredBlob = nil
            deferredDecodeError = nil
            blobRevision &+= 1
            initialPayload = nil
            didReplaceBlob?()
        }
    }

    private(set) var blobRevision: UInt64 = 0
    var initialPayload: ZipWriter.Payload?
    var didReplaceBlob: (() -> Void)?

    private var cachedDocument: XML.Document?
    public private(set) var isDirty = false

    public init(uri: PackURI, contentType: String, blob: Data, rels: Relationships = Relationships()) {
        self.uri = uri
        self.contentType = contentType
        self.materializedBlob = blob
        self.rels = rels
    }

    init(
        uri: PackURI,
        contentType: String,
        deferred: DeferredBlob,
        initialPayload: ZipWriter.Payload?,
        rels: Relationships = Relationships()
    ) {
        self.uri = uri
        self.contentType = contentType
        self.deferredBlob = deferred
        self.initialPayload = initialPayload
        self.rels = rels
    }

    /// Return the part's uncompressed bytes, inflating and CRC-verifying on
    /// first access when the part was opened lazily without concealing errors.
    public func decodedData() throws -> Data {
        if let deferredDecodeError { throw deferredDecodeError }
        if let materializedBlob { return materializedBlob }
        guard let deferred = deferredBlob else { return Data() }
        let decoded: Data
        switch deferred {
        case .verifiedDeflate(let raw, let expectedSize):
            decoded = try Inflate.inflate(raw, expectedOutputSize: expectedSize)
        case .onAccess(let raw, let entry):
            decoded = try ZipReader.decodePayload(raw: raw, entry: entry)
        }
        materializedBlob = decoded
        deferredBlob = nil
        return decoded
    }

    /// Verify a deferred `.onAccess` payload without allocating an uncompressed
    /// buffer for DEFLATE streams.
    func verifyPayload() throws {
        if let deferredDecodeError { throw deferredDecodeError }
        if materializedBlob != nil { return }
        guard case .onAccess(let raw, let entry) = deferredBlob else { return }
        if entry.method == 8 {
            let verified = try Inflate.verify(raw, expectedOutputSize: entry.uncompressedSize)
            guard verified.size == entry.uncompressedSize else {
                throw RostrumError.zipCorrupt("uncompressed size mismatch on \"\(entry.name)\"")
            }
            guard verified.crc32 == entry.crc32 else {
                throw RostrumError.zipCorrupt("CRC-32 mismatch on \"\(entry.name)\"")
            }
            deferredBlob = .verifiedDeflate(raw: raw, expectedSize: entry.uncompressedSize)
        } else {
            materializedBlob = try ZipReader.decodePayload(raw: raw, entry: entry)
            deferredBlob = nil
        }
    }

    /// Create a detached clone at `uri`, preserving deferred storage and
    /// `initialPayload` when clean while validating `.onAccess` streams up front.
    func cloned(uri: PackURI) throws -> Part {
        flushIfDirty()
        try verifyPayload()
        let preservedInitial = (!isDirty && blobRevision == 0) ? initialPayload : nil
        if let materializedBlob {
            let copy = Part(uri: uri, contentType: contentType, blob: materializedBlob)
            copy.initialPayload = preservedInitial
            return copy
        }
        if let deferredBlob {
            return Part(uri: uri, contentType: contentType, deferred: deferredBlob, initialPayload: preservedInitial)
        }
        return Part(uri: uri, contentType: contentType, blob: Data())
    }

    /// The part's DOM, parsed once and cached. Reading it does NOT flip
    /// authority — call `markDirty()` after any mutation.
    ///
    /// Parsed as a whole document, not a bare root: a comment or processing
    /// instruction ahead of the root element is XML we do not model, and a
    /// re-serialized part has to give it back.
    public func dom() throws -> XML.Element {
        if let cachedDocument { return cachedDocument.root }
        let document = try XML.parseDocument(try decodedData())
        cachedDocument = document
        return document.root
    }

    /// Flip authority to the DOM. Every facade setter must call this; it is
    /// the single funnel that keeps blob/DOM coherence a checkable invariant.
    public func markDirty() {
        isDirty = true
        initialPayload = nil
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

    /// Non-part archive member carried across open → save, preserving its
    /// original compressed payload without eagerly materializing DEFLATE bytes.
    struct CarriedEntry {
        let name: String
        private let materializedData: Data?
        private let deferredRaw: Data?
        private let deferredEntry: ZipReader.Entry?
        let uncompressedSize: Int
        let initialPayload: ZipWriter.Payload?

        init(name: String, raw: Data, entry: ZipReader.Entry, initialPayload: ZipWriter.Payload?) {
            self.name = name
            self.materializedData = entry.method == 0 ? raw : nil
            self.deferredRaw = entry.method == 0 ? nil : raw
            self.deferredEntry = entry.method == 0 ? nil : entry
            self.uncompressedSize = entry.uncompressedSize
            self.initialPayload = initialPayload
        }

        var data: Data {
            if let materializedData { return materializedData }
            return (try? decodedData()) ?? Data()
        }

        func decodedData() throws -> Data {
            if let materializedData { return materializedData }
            if let raw = deferredRaw, let entry = deferredEntry {
                return try ZipReader.decodePayload(raw: raw, entry: entry)
            }
            return Data()
        }
    }

    /// Zip entries whose name ends in "/": directory placeholders, which some
    /// writers emit and which are not parts. Kept verbatim so an untouched deck
    /// still round-trips every entry — dropping them silently made a foreign
    /// deck come back with fewer entries than it went in with, which is exactly
    /// what the corpus gate exists to catch.
    ///
    /// Stored in the order they arrived; `serialize()` sorts them on the way
    /// out, which is where determinism actually has to hold.
    private(set) var directoryEntries: [CarriedEntry] = []

    /// `.rels` entries no part claims — an orphan, or a rels stream at a name
    /// `PackURI.relsURI` does not derive. Same reason as `directoryEntries`:
    /// read, not modelled, and previously not written back.
    private(set) var orphanRelationshipStreams: [CarriedEntry] = []

    /// Entries with no declared content type.
    ///
    /// `[Content_Types].xml` is required to cover every part (OPC M1.2), and a
    /// package that breaks that rule is malformed. But PowerPoint itself ships
    /// them: deleting content can leave a `/[trash]/0000.dat` behind in the
    /// archive with no Override and no matching Default, and PowerPoint reopens
    /// its own files perfectly happily. Refusing the whole deck over a part
    /// nothing references cost 12 of 471 real decks in one library — 2.5%,
    /// every one of which opens in PowerPoint and in python-pptx.
    ///
    /// So they are carried, not modelled and not rejected: same treatment as an
    /// orphan `.rels` stream, and for the same reason. They cannot become
    /// `Part`s — a `Part` without a content type has no legal serialization —
    /// and dropping them would break the round trip.
    private(set) var untypedEntries: [CarriedEntry] = []

    /// Diagnostics from `read`: carried entries (directory placeholders,
    /// orphan `.rels` streams) that could not be decoded and were dropped, or
    /// `.onAccess` parts whose non-throwing `.blob` fallback encountered an error.
    public private(set) var readWarnings: [String] = []

    public init() {
        parts = [:]
        rels = Relationships()
        contentTypes = ContentTypesMap()
    }

    // Indexed by size plus CRC, with exact-byte verification for collisions.
    private struct MediaKey: Hashable { let size: Int; let crc: UInt32 }
    private var mediaIndex: [MediaKey: [PackURI]]?

    private func watchPart(_ part: Part) {
        let uri = part.uri
        part.didReplaceBlob = { [weak self] in
            guard let self else { return }
            if uri.value.hasPrefix("/ppt/media/") { self.mediaIndex = nil }
            self.discardCachedPayload(at: uri)
        }
    }
    private func mediaKey(_ data: Data) -> MediaKey { MediaKey(size: data.count, crc: CRC32.checksum(data)) }
    private func mediaKey(for part: Part) -> MediaKey? {
        if !part.isDirty, part.blobRevision == 0, let initial = part.initialPayload {
            return MediaKey(size: Int(initial.size), crc: initial.crc)
        }
        guard let bytes = try? part.decodedData() else { return nil }
        return mediaKey(bytes)
    }

    private func ensureMediaIndex() {
        guard mediaIndex == nil else { return }
        var index: [MediaKey: [PackURI]] = [:]
        for (uri, part) in parts where uri.value.hasPrefix("/ppt/media/") {
            if let key = mediaKey(for: part) {
                index[key, default: []].append(uri)
            }
            watchPart(part)
        }
        for key in index.keys { index[key]!.sort { $0.value < $1.value } }
        mediaIndex = index
    }

    func matchingMedia(for data: Data) -> Part? {
        ensureMediaIndex()
        for uri in mediaIndex?[mediaKey(data)] ?? [] {
            if let part = parts[uri], (try? part.decodedData()) == data { return part }
        }
        return nil
    }

    func matchingMedia(for sourcePart: Part) throws -> Part? {
        sourcePart.flushIfDirty()
        try sourcePart.verifyPayload()
        ensureMediaIndex()
        let key: MediaKey
        if let fastKey = mediaKey(for: sourcePart) {
            key = fastKey
        } else {
            key = mediaKey(try sourcePart.decodedData())
        }
        guard let candidates = mediaIndex?[key], !candidates.isEmpty else { return nil }
        let data = try sourcePart.decodedData()
        for uri in candidates {
            if let part = parts[uri], (try? part.decodedData()) == data { return part }
        }
        return nil
    }

    // MARK: - Reading

    /// Maximum raw compressed byte count eligible for verbatim passthrough.
    ///
    /// Standard `zlib` / Apple `Compression` on incompressible media emits
    /// 5-byte RFC 1951 `BTYPE=00` headers every 16–64 KiB (~0.008–0.03%, e.g.
    /// +656 B on an 8 MB Keynote JPEG). Allowing `uncompressed + uncompressed/512 + 64`
    /// accommodates every legitimate encoder flush window while rejecting
    /// empty-block padding amplification (`> 64 B` on a `0 B` payload).
    static func maxPassthroughRawBytes(uncompressedSize: Int) -> UInt64 {
        let u = UInt64(max(0, uncompressedSize))
        return u + (u >> 9) + 64
    }

    static func initialPayload(raw: Data, entry: ZipReader.Entry) -> ZipWriter.Payload? {
        guard UInt64(entry.uncompressedSize) <= 0xFFFF_FFFF,
              UInt64(raw.count) <= 0xFFFF_FFFF,
              UInt64(raw.count) <= maxPassthroughRawBytes(uncompressedSize: entry.uncompressedSize) else {
            return nil
        }
        return ZipWriter.Payload(
            data: raw,
            method: entry.method,
            size: UInt32(entry.uncompressedSize),
            crc: entry.crc32
        )
    }

    private static func parseRelationships(_ name: String, from zip: ZipReader) throws -> Relationships {
        let loaded = try zip.entryPayload(forEntry: name)
        let parsed = try Relationships.parse(loaded.decoded)
        parsed.initialPayload = initialPayload(raw: loaded.raw, entry: loaded.entry)
        return parsed
    }

    /// Open a package.
    ///
    /// - Parameters:
    ///   - validation: `.strict` (the default) validates every entry's stream,
    ///     uncompressed size, and CRC-32 up front in a 64 KiB sliding window
    ///     without retaining uncompressed buffers for untouched DEFLATE parts;
    ///     `.onAccess` skips `Inflate` and `CRC32` altogether on untouched
    ///     parts and carried entries, decoding only `[Content_Types].xml` and
    ///     `.rels` streams at open and validating content parts on first read.
    ///   - limits: ceilings applied to the archive before anything is
    ///     decompressed. Defaults to `.default` (4 GiB of declared uncompressed
    ///     bytes) so untrusted input is bounded out of the box; pass
    ///     `.unlimited` for archives you already trust.
    public static func read(
        data: Data,
        validation: OPCArchive.Validation = .strict,
        limits: ZipReader.Limits = .default
    ) throws -> OPCPackage {
        let zip = try ZipReader(data: data, limits: limits)

        guard zip.contains(PackURI.contentTypes.memberName) else {
            throw RostrumError.packageInvalid("missing [Content_Types].xml — not an OPC package")
        }
        let package = OPCPackage()
        let contentTypesLoaded = try zip.entryPayload(forEntry: PackURI.contentTypes.memberName)
        var contentTypes = try ContentTypesMap.parse(contentTypesLoaded.decoded)
        contentTypes.initialPayload = Self.initialPayload(
            raw: contentTypesLoaded.raw, entry: contentTypesLoaded.entry)
        package.contentTypes = contentTypes

        func loadCarried(_ name: String) throws -> CarriedEntry {
            let loaded = validation == .strict
                ? try zip.verifiedRawPayload(forEntry: name)
                : try zip.rawEntryPayload(forEntry: name)
            return CarriedEntry(
                name: name, raw: loaded.raw, entry: loaded.entry,
                initialPayload: Self.initialPayload(raw: loaded.raw, entry: loaded.entry))
        }

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
                    package.directoryEntries.append(try loadCarried(name))
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
            guard let ct = package.contentTypes.declaredContentType(for: uri) else {
                // Not a part — nothing can reference it, because a relationship
                // target without a content type could not be loaded either.
                // Carried verbatim so the resave stays a fixed point.
                package.untypedEntries.append(try loadCarried(name))
                package.readWarnings.append(
                    "part \"\(name)\" has no declared content type and is carried "
                        + "through unmodelled")
                continue
            }

            let part: Part
            switch validation {
            case .strict:
                let verified = try zip.verifiedRawPayload(forEntry: name)
                let initial = Self.initialPayload(raw: verified.raw, entry: verified.entry)
                if verified.entry.method == 0 {
                    part = Part(uri: uri, contentType: ct, blob: verified.raw)
                    part.initialPayload = initial
                } else if let initial {
                    part = Part(
                        uri: uri, contentType: ct,
                        deferred: .verifiedDeflate(
                            raw: verified.raw, expectedSize: verified.entry.uncompressedSize),
                        initialPayload: initial)
                } else {
                    // Pathological empty-block padding: verified stream, but we
                    // decline raw passthrough and store the normalized output.
                    let decoded = try ZipReader.decodePayload(raw: verified.raw, entry: verified.entry)
                    part = Part(uri: uri, contentType: ct, blob: decoded)
                }
            case .onAccess:
                let rawLoaded = try zip.rawEntryPayload(forEntry: name)
                let initial = Self.initialPayload(raw: rawLoaded.raw, entry: rawLoaded.entry)
                part = Part(
                    uri: uri, contentType: ct,
                    deferred: .onAccess(raw: rawLoaded.raw, entry: rawLoaded.entry),
                    initialPayload: initial)
                part.onDeferredDecodeFailure = { [weak package] failedURI, error in
                    package?.readWarnings.append(
                        "deferred decode of \"\(failedURI.value)\" failed: \(error)")
                }
            }
            package.parts[uri] = part
        }

        // Second pass: attach relationships to the package and to each part,
        // preserving parsed rIds verbatim — part XML references them by value.
        // `adopt`, not `setItems`: the parsed collection carries the bytes it
        // came from, and an untouched `.rels` part must re-emit them verbatim.
        if zip.contains(PackURI.packageRels.memberName) {
            package.rels.adopt(try Self.parseRelationships(PackURI.packageRels.memberName, from: zip))
        }
        var consumed: Set<String> = [PackURI.packageRels.memberName]
        for (uri, part) in package.parts {
            let relsName = uri.relsURI.memberName
            guard zip.contains(relsName) else { continue }
            consumed.insert(relsName)
            part.rels.adopt(try Self.parseRelationships(relsName, from: zip))
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
                package.orphanRelationshipStreams.append(try loadCarried(name))
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
        if let part = parts[uri] { return part }
        if let decoded = uri.percentDecoded, let part = parts[decoded] { return part }
        throw RostrumError.partMissing(uri.value)
    }

    @discardableResult
    public func addPart(uri: PackURI, contentType: String, blob: Data) -> Part {
        discardCachedPayload(at: uri)
        let part = Part(uri: uri, contentType: contentType, blob: blob)
        if let old = parts[uri], old.uri.value.hasPrefix("/ppt/media/") { mediaIndex = nil }
        parts[uri] = part
        if uri.value.hasPrefix("/ppt/media/") {
            watchPart(part)
            if mediaIndex != nil {
                let key = mediaKey(blob)
                mediaIndex![key, default: []].append(uri)
                mediaIndex![key]!.sort { $0.value < $1.value }
            }
        }
        contentTypes.setOverride(partName: uri, contentType: contentType)
        return part
    }

    @discardableResult
    func installStagedPart(_ staged: Part) -> Part {
        staged.flushIfDirty()
        discardCachedPayload(at: staged.uri)
        let preservedInitial = (!staged.isDirty && staged.blobRevision == 0) ? staged.initialPayload : nil
        let part: Part
        if let materialized = staged.materializedBlob {
            part = Part(uri: staged.uri, contentType: staged.contentType, blob: materialized)
            part.initialPayload = preservedInitial
        } else if let deferred = staged.deferredBlob {
            part = Part(
                uri: staged.uri,
                contentType: staged.contentType,
                deferred: deferred,
                initialPayload: preservedInitial
            )
        } else {
            part = Part(uri: staged.uri, contentType: staged.contentType, blob: Data())
        }
        part.rels.setItems(staged.rels.items)
        part.onDeferredDecodeFailure = { [weak self] failedURI, error in
            self?.readWarnings.append(
                "part \"\(failedURI.value)\" could not be decoded on access: \(error)")
        }
        if let old = parts[staged.uri], old.uri.value.hasPrefix("/ppt/media/") { mediaIndex = nil }
        parts[staged.uri] = part
        if staged.uri.value.hasPrefix("/ppt/media/") {
            watchPart(part)
            if mediaIndex != nil, let key = mediaKey(for: part) {
                mediaIndex![key, default: []].append(staged.uri)
                mediaIndex![key]!.sort { $0.value < $1.value }
            }
        }
        contentTypes.setOverride(partName: staged.uri, contentType: staged.contentType)
        return part
    }

    public func removePart(at uri: PackURI) {
        parts[uri] = nil
        if let old = compressionCache.removeValue(forKey: uri) { compressionCacheBytes -= old.cost }
        if uri.value.hasPrefix("/ppt/media/") { mediaIndex = nil }
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

    /// Every part URI reachable from the package-level relationship graph
    /// (`/_rels/.rels`) by following internal relationships.
    public var reachablePartURIs: Set<PackURI> {
        var visited: Set<PackURI> = []
        var stack: [Part] = []
        for rel in rels.items where !rel.isExternal {
            let targetURI = PackURI.resolve(target: rel.target, relativeTo: "/")
            if let target = try? part(at: targetURI), visited.insert(target.uri).inserted {
                stack.append(target)
            }
        }
        while let current = stack.popLast() {
            let base = current.uri.baseURI
            for rel in current.rels.items where !rel.isExternal {
                let targetURI = PackURI.resolve(target: rel.target, relativeTo: base)
                if let target = try? part(at: targetURI), visited.insert(target.uri).inserted {
                    stack.append(target)
                }
            }
        }
        return visited
    }

    /// Parts in `parts` that are not reachable from `/_rels/.rels`, sorted by
    /// part URI. Ordinary saves preserve these parts for lossless round-trips;
    /// call `prune()` to remove them explicitly.
    public var orphanPartURIs: [PackURI] {
        let reachable = reachablePartURIs
        return parts.keys.filter { !reachable.contains($0) }.sorted { $0.value < $1.value }
    }

    /// Remove all parts unreachable from `/_rels/.rels` along with any carried
    /// orphan `.rels` streams and untyped entries, returning the removed part
    /// URIs in sorted order.
    @discardableResult
    public func prune() -> [PackURI] {
        let orphans = orphanPartURIs
        for uri in orphans {
            removePart(at: uri)
        }
        orphanRelationshipStreams.removeAll()
        untypedEntries.removeAll()
        return orphans
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

    public func serialize() throws -> Data { try makeZip().finalize() }

    /// Stream a complete ZIP to a sibling temporary file, then atomically
    /// replace the destination. Failures leave the existing file intact.
    public func writeAtomically(to url: URL) throws {
        guard url.isFileURL else { throw RostrumError.packageInvalid("save destination must be a file URL") }
        let zip = try makeZip()
        let existing = try? FileManager.default.attributesOfItem(atPath: url.path)
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".rostrum-\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw RostrumError.packageInvalid("cannot create temporary file beside \(url.path)")
        }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        do { try zip.write(to: handle); try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
        if existing?[.type] as? FileAttributeType == .typeRegular, let mode = existing?[.posixPermissions] {
            try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: temporary.path)
        }
        // Foundation re-exports this POSIX primitive on all supported platforms.
        // A sibling rename publishes atomically, refuses directory destinations,
        // and has no fallible metadata work after publication. In particular,
        // avoid FileManager.replaceItemAt's swap/cleanup behavior on directories
        // and the reversed-rename fallback in older Linux Foundation releases.
        let result = temporary.withUnsafeFileSystemRepresentation { source in
            url.withUnsafeFileSystemRepresentation { destination in
                guard let source, let destination else { errno = EINVAL; return Int32(-1) }
                return rename(source, destination)
            }
        }
        if result != 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path]) }
    }

    private struct CachedPayload {
        let part: Part
        let revision: UInt64
        let payload: ZipWriter.Payload
        var cost: Int { payload.method == 8 ? payload.data.count : 0 }
    }
    private var compressionCache: [PackURI: CachedPayload] = [:]
    private var compressionCacheBytes = 0
    private let compressionCacheLimit = 16 * 1024 * 1024

    private func discardCachedPayload(at uri: PackURI) {
        if let old = compressionCache.removeValue(forKey: uri) { compressionCacheBytes -= old.cost }
    }

    /// Rebuilt relationship and content-type streams, keyed by entry name and
    /// valid only while the serialized bytes are unchanged, so repeated saves
    /// of newly built or edited streams do not re-deflate them. Streams that
    /// still match what was opened from a file reuse their `pristinePayload`
    /// directly and cannot be evicted from this cache.
    private var streamCache: [String: (source: Data, payload: ZipWriter.Payload)] = [:]
    private var streamCacheBytes = 0
    private let streamCacheLimit = 4 * 1024 * 1024

    private func addStream(
        _ zip: inout ZipWriter, name: String, data: Data, initial: ZipWriter.Payload?
    ) {
        // Names and sizes the writer would refuse keep its own diagnostics.
        guard name.utf8.count <= 0xFFFF, UInt64(data.count) <= 0xFFFF_FFFF else {
            return zip.addFile(name: name, data: data)
        }
        if let initial {
            if let old = streamCache.removeValue(forKey: name) {
                streamCacheBytes -= old.source.count + old.payload.data.count
            }
            return zip.addFile(name: name, payload: initial)
        }
        zip.addFile(name: name, payload: preparedStream(name: name, data: data))
    }

    private func addCarried(_ zip: inout ZipWriter, _ entry: CarriedEntry) throws {
        guard entry.name.utf8.count <= 0xFFFF, UInt64(entry.uncompressedSize) <= 0xFFFF_FFFF,
              let initial = entry.initialPayload else {
            return zip.addFile(name: entry.name, data: try entry.decodedData())
        }
        zip.addFile(name: entry.name, payload: initial)
    }

    private func preparedStream(name: String, data: Data) -> ZipWriter.Payload {
        if let cached = streamCache[name], cached.source == data { return cached.payload }
        if let old = streamCache.removeValue(forKey: name) { streamCacheBytes -= old.source.count + old.payload.data.count }
        let payload = ZipWriter.prepare(data: data, compress: true)
        let cost = data.count + payload.data.count
        if cost <= streamCacheLimit {
            if streamCacheBytes + cost > streamCacheLimit { streamCache.removeAll(); streamCacheBytes = 0 }
            streamCache[name] = (data, payload)
            streamCacheBytes += cost
        }
        return payload
    }

    private func prepared(_ part: Part, compress: Bool) throws -> ZipWriter.Payload {
        watchPart(part)
        if !part.isDirty, part.blobRevision == 0, let initial = part.initialPayload {
            return initial
        }
        if let error = part.deferredDecodeError { throw error }
        if let cached = compressionCache[part.uri], cached.part === part, cached.revision == part.blobRevision { return cached.payload }
        if let old = compressionCache.removeValue(forKey: part.uri) { compressionCacheBytes -= old.cost }
        let payload = ZipWriter.prepare(data: try part.decodedData(), compress: compress)
        let cached = CachedPayload(part: part, revision: part.blobRevision, payload: payload)
        if cached.cost <= compressionCacheLimit {
            if compressionCacheBytes + cached.cost > compressionCacheLimit {
                compressionCache.removeAll(); compressionCacheBytes = 0
            }
            compressionCache[part.uri] = cached; compressionCacheBytes += cached.cost
        }
        return payload
    }

    private func makeZip() throws -> ZipWriter {
        for part in parts.values {
            part.flushIfDirty()
        }
        var zip = ZipWriter()
        addStream(&zip, name: PackURI.contentTypes.memberName,
                  data: contentTypes.serialized(), initial: contentTypes.pristinePayload)
        if rels.isWritten {
            addStream(&zip, name: PackURI.packageRels.memberName,
                      data: rels.serialized(), initial: rels.pristinePayload)
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
            try addCarried(&zip, entry)
        }
        for entry in untypedEntries.sorted(by: { $0.name < $1.name })
        where !derived.contains(entry.name) {
            try addCarried(&zip, entry)
        }
        for entry in directoryEntries.sorted(by: { $0.name < $1.name })
        where !derived.contains(entry.name) {
            // Preserve the original compressed payload when within normal
            // framing bounds; fall back to decoded + re-compressed output for
            // padded placeholders so Rostrum never copies empty-block bloat.
            try addCarried(&zip, entry)
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
            if UInt64(part.uncompressedByteCount) > 0xFFFF_FFFF {
                throw RostrumError.packageInvalid("part exceeds the supported ZIP size field")
            }
            zip.addFile(name: uri.memberName, payload: try prepared(part, compress: !alreadyCompressed))
            // `isWritten`, not `!isEmpty`: a `<Relationships/>` with no
            // children is legal OPC and some producers emit it, and gating on
            // emptiness dropped it on resave. A part Rostrum created with no
            // relationships still gets no `.rels` entry. The same predicate
            // decides which carried entries would collide, which is why it is
            // one definition rather than a condition repeated at four sites.
            if part.rels.isWritten {
                addStream(&zip, name: uri.relsURI.memberName,
                          data: part.rels.serialized(), initial: part.rels.pristinePayload)
            }
        }
        return zip
    }
}
