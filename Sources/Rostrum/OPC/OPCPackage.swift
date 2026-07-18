import Foundation

/// One part in the package: a name, a content type, bytes, and its outgoing
/// relationships. XML parts are parsed lazily by the layers above; the OPC
/// layer deals only in blobs.
public final class Part {
    public let uri: PackURI
    public let contentType: String
    public var blob: Data
    public let rels: Relationships

    public init(uri: PackURI, contentType: String, blob: Data, rels: Relationships = Relationships()) {
        self.uri = uri
        self.contentType = contentType
        self.blob = blob
        self.rels = rels
    }

    /// Parse this part's blob as XML.
    public func xml() throws -> XML.Element {
        try XML.parse(blob)
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
    public private(set) var contentTypes: ContentTypesMap

    public init() {
        parts = [:]
        rels = Relationships()
        contentTypes = ContentTypesMap()
    }

    // MARK: - Reading

    public static func read(data: Data) throws -> OPCPackage {
        let zip = try ZipReader(data: data)

        guard zip.contains(PackURI.contentTypes.memberName) else {
            throw RostrumError.packageInvalid("missing [Content_Types].xml — not an OPC package")
        }
        let package = OPCPackage()
        package.contentTypes = try ContentTypesMap.parse(zip.data(forEntry: PackURI.contentTypes.memberName))

        // First pass: create every non-rels part with its content type.
        for name in zip.entryNames {
            if name == PackURI.contentTypes.memberName { continue }
            if name.hasSuffix(".rels") { continue }
            if name.hasSuffix("/") { continue }  // directory placeholder entries
            let uri = PackURI("/" + name)
            let blob = try zip.data(forEntry: name)
            let ct = try package.contentTypes.contentType(for: uri)
            package.parts[uri] = Part(uri: uri, contentType: ct, blob: blob)
        }

        // Second pass: attach relationships to the package and to each part,
        // preserving parsed rIds verbatim — part XML references them by value.
        if zip.contains(PackURI.packageRels.memberName) {
            let parsed = try Relationships.parse(zip.data(forEntry: PackURI.packageRels.memberName))
            package.rels.setItems(parsed.items)
        }
        for (uri, part) in package.parts {
            let relsName = uri.relsURI.memberName
            guard zip.contains(relsName) else { continue }
            let parsed = try Relationships.parse(zip.data(forEntry: relsName))
            part.rels.setItems(parsed.items)
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

    // MARK: - Writing

    /// Serialize to zip bytes. Deterministic: [Content_Types].xml first, then
    /// package rels, then parts sorted by URI, each followed by its rels part.
    public func serialize() throws -> Data {
        var zip = ZipWriter()
        zip.addFile(name: PackURI.contentTypes.memberName, data: contentTypes.serialized())
        if !rels.isEmpty {
            zip.addFile(name: PackURI.packageRels.memberName, data: rels.serialized())
        }
        for (uri, part) in parts.sorted(by: { $0.key.value < $1.key.value }) {
            zip.addFile(name: uri.memberName, data: part.blob)
            if !part.rels.isEmpty {
                zip.addFile(name: uri.relsURI.memberName, data: part.rels.serialized())
            }
        }
        return zip.finalize()
    }
}
