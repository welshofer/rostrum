import Foundation

/// Presentation-owned author records are outside a slide's reachable graph.
/// Merge them on detached XML, retaining source identity and unknown fields.
final class AnnotationAuthorImport {
    private let dest: OPCPackage
    private let presentation: Part
    private let authors: Part
    private let isNew: Bool
    private var mapping: [String: String] = [:]

    init(source: OPCPackage, dest: OPCPackage, presentation: Part,
         allocate: (PackURI) -> PackURI, register: (Part, Part) throws -> Void,
         lookup: @escaping (PackURI) -> Part?, mapped: @escaping (PackURI) -> PackURI?,
         bind: @escaping (PackURI, PackURI) throws -> Void, copy: (PackURI) throws -> PackURI) throws {
        self.dest = dest
        self.presentation = presentation
        let sourcePresentation = try source.mainDocumentPart()
        let sourceAuthors = try sourcePresentation.related(by: ModernComments.authorsRelType, in: source)
        sourceAuthors.flushIfDirty()
        let sourceRoot = try sourceAuthors.dom()
        if let rel = presentation.rels.first(ofType: ModernComments.authorsRelType) {
            guard !rel.isExternal else { throw RostrumError.packageInvalid("authors must be internal") }
            let existing = try dest.part(at: PackURI.resolve(target: rel.target, relativeTo: presentation.uri.baseURI))
            existing.flushIfDirty()
            authors = Part(uri: existing.uri, contentType: existing.contentType, blob: existing.blob)
            authors.rels.setItems(existing.rels.items)
            isNew = false
        } else {
            authors = Part(uri: allocate(PackURI("/ppt/authors.xml")), contentType: ModernComments.authorsContentType, blob: sourceAuthors.blob)
            let root = try authors.dom()
            let recordIDs = Set(Self.authorElements(root).map(ObjectIdentifier.init))
            root.children.removeAll { node in
                if case .element(let element) = node { return recordIDs.contains(ObjectIdentifier(element)) }
                return false
            }
            authors.markDirty()
            isNew = true
        }
        let root = try authors.dom()
        var existing = Self.authorElements(root)
        var destinationIDs: Set<String> = []
        for record in existing {
            guard let id = record[attribute: "id"], !id.isEmpty, destinationIDs.insert(id.uppercased()).inserted else {
                throw RostrumError.packageInvalid("destination authors have missing or duplicate IDs")
            }
        }
        try register(sourceAuthors, authors)
        let dependencies = try AnnotationDependencies(source: source, original: sourceAuthors, target: authors,
            lookup: lookup, mapped: mapped, bind: bind, copy: copy)
        let priorMetadata = root.serialized()
        try AnnotationXML.mergeMetadata(from: sourceRoot, records: Self.authorElements(sourceRoot),
            into: root, records: existing, dependencies: dependencies, isNew: isNew)
        if root.serialized() != priorMetadata { authors.markDirty() }
        var sourceIDs: Set<String> = []
        var ids = Set(existing.compactMap { $0[attribute: "id"]?.uppercased() })
        for (index, sourceAuthor) in Self.authorElements(sourceRoot).enumerated() {
            guard let sourceID = sourceAuthor[attribute: "id"], !sourceID.isEmpty, sourceIDs.insert(sourceID.uppercased()).inserted else {
                throw RostrumError.packageInvalid("author list contains missing or duplicate IDs")
            }
            let clone = try AnnotationXML.copy(sourceAuthor, from: sourceRoot)
            var match: XML.Element?
            for record in existing {
                try dependencies.consumeComparisonWork()
                guard Self.identity(record) == Self.identity(sourceAuthor) else { continue }
                if try dependencies.equivalentRecord(clone, to: AnnotationXML.copy(record, from: root), ignoring: ["id"]) { match = record; break }
            }
            if let id = match?[attribute: "id"] { mapping[sourceID.uppercased()] = id; continue }
            try dependencies.remap(clone)
            let id = ids.contains(sourceID.uppercased())
                ? SectionGUID.make(name: "author:\(Self.identity(sourceAuthor))", index: index, avoiding: ids)
                : sourceID
            clone[attribute: "id"] = id
            root.appendElement(clone)
            authors.markDirty()
            existing.append(clone)
            ids.insert(id.uppercased())
            mapping[sourceID.uppercased()] = id
        }
    }

    private static func identity(_ author: XML.Element) -> String {
        let provider = author[attribute: "providerId"] ?? ""
        let user = author[attribute: "userId"] ?? ""
        if !provider.isEmpty, provider != "None", !user.isEmpty {
            return "provider:\(provider)\u{1}\(user)"
        }
        return "local:\(author[attribute: "id"]?.uppercased() ?? "")\u{1}\(provider)\u{1}\(user)"
    }

    static func authorElements(_ root: XML.Element) -> [XML.Element] {
        var result: [XML.Element] = []
        ModernComments.visit(in: root) { element, ns, name in
            if ns == ModernComments.ns, name == "author" { result.append(element) }
        }
        return result
    }

    func remapAuthors(in comments: Part) throws {
        var unresolved: String?
        ModernComments.visit(in: try comments.dom()) { element, ns, name in
            if ns == ModernComments.ns, name == "cm" || name == "reply" {
                guard let old = element[attribute: "authorId"], let id = mapping[old.uppercased()] else {
                    unresolved = element[attribute: "authorId"] ?? "missing"
                    return
                }
                element[attribute: "authorId"] = id
                if let assigned = element[attribute: "assignedTo"] {
                    let oldIDs = assigned.split(whereSeparator: \.isWhitespace).map(String.init)
                    let remapped = oldIDs.compactMap { mapping[$0.uppercased()] }
                    if remapped.count != oldIDs.count { unresolved = "assigned author" }
                    else { element[attribute: "assignedTo"] = remapped.joined(separator: " ") }
                }
            }
        }
        if let unresolved { throw RostrumError.packageInvalid("comment author \(unresolved) cannot be resolved") }
        comments.markDirty()
    }

    func commit() {
        authors.flushIfDirty()
        let installed: Part
        if let existing = dest.parts[authors.uri] {
            if existing.blob != authors.blob { existing.replaceBlob(authors.blob) }
            installed = existing
        }
        else { installed = dest.addPart(uri: authors.uri, contentType: authors.contentType, blob: authors.blob) }
        installed.rels.setItems(authors.rels.items)
        if isNew {
            presentation.rels.add(type: ModernComments.authorsRelType,
                                  target: presentation.uri.relativeReference(to: authors.uri))
        }
    }
}
