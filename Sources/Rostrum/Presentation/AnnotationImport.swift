import Foundation

/// Presentation-owned author records are outside a slide's reachable graph.
/// Merge them on detached XML, retaining source identity and unknown fields.
final class AnnotationAuthorImport {
    private let dest: OPCPackage
    private let presentation: Part
    private let authors: Part
    private let isNew: Bool
    private var mapping: [String: String] = [:]

    init(source: OPCPackage, dest: OPCPackage, presentation: Part) throws {
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
            isNew = false
        } else {
            var n = 1
            var uri = PackURI("/ppt/authors.xml")
            while dest.parts[uri] != nil { uri = PackURI("/ppt/authors\(n).xml"); n += 1 }
            authors = Part(uri: uri, contentType: ModernComments.authorsContentType, blob: sourceAuthors.blob)
            let root = try authors.dom()
            for author in Self.authorElements(root) { root.removeChild(author) }
            authors.markDirty()
            isNew = true
        }
        let root = try authors.dom()
        var existing = Self.authorElements(root)
        var ids = Set(existing.compactMap { $0[attribute: "id"]?.uppercased() })
        for (index, sourceAuthor) in Self.authorElements(sourceRoot).enumerated() {
            guard let sourceID = sourceAuthor[attribute: "id"], mapping[sourceID] == nil else {
                throw RostrumError.packageInvalid("author list contains missing or duplicate IDs")
            }
            if let match = existing.first(where: { Self.identity($0) == Self.identity(sourceAuthor) }),
               let id = match[attribute: "id"] {
                mapping[sourceID] = id
                continue
            }
            let clone = sourceAuthor.deepCopy()
            // Imported extension children may inherit namespaces from the
            // source author-list root. Carry those bindings on the new author.
            for attr in sourceRoot.attributes where attr.name == "xmlns" || attr.name.hasPrefix("xmlns:") {
                if clone[attribute: attr.name] == nil { clone[attribute: attr.name] = attr.value }
            }
            let id = ids.contains(sourceID.uppercased())
                ? SectionGUID.make(name: "author:\(Self.identity(sourceAuthor))", index: index, avoiding: ids)
                : sourceID
            clone[attribute: "id"] = id
            root.appendElement(clone)
            authors.markDirty()
            existing.append(clone)
            ids.insert(id.uppercased())
            mapping[sourceID] = id
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
                guard let old = element[attribute: "authorId"], let id = mapping[old] else {
                    unresolved = element[attribute: "authorId"] ?? "missing"
                    return
                }
                element[attribute: "authorId"] = id
                if let assigned = element[attribute: "assignedTo"] {
                    let oldIDs = assigned.split(whereSeparator: \.isWhitespace).map(String.init)
                    let remapped = oldIDs.compactMap { mapping[$0] }
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
        if let existing = dest.parts[authors.uri] {
            if existing.blob != authors.blob { existing.replaceBlob(authors.blob) }
        }
        else { dest.addPart(uri: authors.uri, contentType: authors.contentType, blob: authors.blob) }
        if isNew {
            presentation.rels.add(type: ModernComments.authorsRelType,
                                  target: presentation.uri.relativeReference(to: authors.uri))
        }
    }
}
