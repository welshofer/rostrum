import Foundation

/// Detached author/index merge for legacy comments, used by both import and
/// duplication. Legacy lacks GUID identities; match complete local records or
/// provider-presence identities, and resolve numeric ID collisions deterministically.
final class LegacyAnnotationAuthorImport {
    private let dest: OPCPackage
    private let presentation: Part
    private let authors: Part
    private let isNew: Bool
    private var mapping: [String: String] = [:]
    private var highIndex: [String: Int] = [:]
    private var recordsByID: [String: XML.Element] = [:]

    init(source: OPCPackage, dest: OPCPackage, presentation: Part,
         allocate: ((PackURI) -> PackURI)? = nil, register: ((Part, Part) throws -> Void)? = nil,
         lookup: ((PackURI) -> Part?)? = nil, mapped: ((PackURI) -> PackURI?)? = nil,
         bind: ((PackURI, PackURI) throws -> Void)? = nil, copy: ((PackURI) throws -> PackURI)? = nil) throws {
        self.dest = dest; self.presentation = presentation
        let sourceAuthors = try LegacyComments.authorPart(in: source)
        guard source === dest || copy != nil else { throw RostrumError.packageInvalid("cross-package author import requires graph staging") }
        sourceAuthors.flushIfDirty()
        let sourceRoot = try sourceAuthors.dom()
        if presentation.rels.first(ofType: LegacyComments.authorsRelType) != nil {
            let existing = try LegacyComments.authorPart(in: dest)
            existing.flushIfDirty()
            authors = Part(uri: existing.uri, contentType: existing.contentType, blob: existing.blob)
            authors.rels.setItems(existing.rels.items)
            isNew = false
        } else {
            var n = 1
            var uri = PackURI("/ppt/commentAuthors.xml")
            while dest.parts[uri] != nil { uri = PackURI("/ppt/commentAuthors\(n).xml"); n += 1 }
            authors = Part(uri: allocate?(uri) ?? uri, contentType: LegacyComments.authorsContentType, blob: sourceAuthors.blob)
            let root = try authors.dom()
            let recordIDs = Set(LegacyComments.elements(root, named: "cmAuthor").map(ObjectIdentifier.init))
            root.children.removeAll { node in
                if case .element(let element) = node { return recordIDs.contains(ObjectIdentifier(element)) }
                return false
            }
            authors.markDirty()
            isNew = true
        }
        let root = try authors.dom()
        var records = LegacyComments.elements(root, named: "cmAuthor")
        for record in records {
            guard let id = LegacyComments.idKey(record[attribute: "id"]), recordsByID[id] == nil,
                  record.boundedInt("id", in: OOXMLBounds.drawingElementID) != nil else {
                throw RostrumError.packageInvalid("destination legacy authors have invalid or duplicate IDs")
            }
            recordsByID[id] = record
        }
        try register?(sourceAuthors, authors)
        let dependencies = try AnnotationDependencies(source: source, original: sourceAuthors, target: authors,
            lookup: lookup ?? { dest.parts[$0] }, mapped: mapped ?? { source === dest ? $0 : nil },
            bind: bind ?? { _, _ in }, copy: copy ?? { $0 }, allowSemanticParts: source === dest && copy == nil)
        let priorMetadata = root.serialized()
        try AnnotationXML.mergeMetadata(from: sourceRoot, records: LegacyComments.elements(sourceRoot, named: "cmAuthor"),
            into: root, records: records, dependencies: dependencies, isNew: isNew)
        if root.serialized() != priorMetadata { authors.markDirty() }
        var sourceIDs: Set<String> = []
        for sourceRecord in LegacyComments.elements(sourceRoot, named: "cmAuthor") {
            guard let sourceID = sourceRecord[attribute: "id"], let sourceKey = LegacyComments.idKey(sourceID), sourceIDs.insert(sourceKey).inserted,
                  sourceRecord.boundedInt("id", in: OOXMLBounds.drawingElementID) != nil else {
                throw RostrumError.packageInvalid("source legacy authors have invalid or duplicate IDs")
            }
            let clone = try AnnotationXML.copy(sourceRecord, from: sourceRoot)
            let signature = Self.signature(sourceRecord)
            let identity = Self.presenceIdentity(sourceRecord)
            var match: XML.Element?
            for record in records {
                try dependencies.consumeComparisonWork()
                guard LegacyComments.idKey(record[attribute: "id"]) == sourceKey || (identity != nil && Self.presenceIdentity(record) == identity) else { continue }
                if try dependencies.equivalentRecord(clone, to: AnnotationXML.copy(record, from: root), ignoring: ["id", "lastIdx", "clrIdx"]) { match = record; break }
            }
            var id = sourceID
            if match == nil, recordsByID[sourceKey] != nil {
                let guid = SectionGUID.make(name: "legacy-author:\(sourceID):\(signature)", index: 0, avoiding: [])
                let hex = String(guid.dropFirst().prefix(8))
                var candidate = Int(UInt32(hex, radix: 16) ?? 0)
                while let existing = recordsByID[String(candidate)] {
                    if try dependencies.equivalentRecord(clone, to: AnnotationXML.copy(existing, from: root), ignoring: ["id", "lastIdx", "clrIdx"]) { match = existing; break }
                    guard candidate < OOXMLBounds.drawingElementID.upperBound else {
                        throw RostrumError.packageInvalid("legacy author ID collision cannot be resolved")
                    }
                    candidate += 1
                }
                id = String(candidate)
            }
            if let match, let matchedID = match[attribute: "id"] { id = matchedID }
            else {
                try dependencies.remap(clone)
                clone[attribute: "id"] = id
                root.appendElement(clone); authors.markDirty()
                records.append(clone); recordsByID[LegacyComments.idKey(id)!] = clone
            }
            mapping[sourceKey] = id
            if highIndex[id] == nil, let record = recordsByID[LegacyComments.idKey(id)!] {
                highIndex[id] = try LegacyComments.nextIndex(authorID: id, in: dest, record: record) - 1
            }
        }
    }

    private static func signature(_ record: XML.Element) -> String {
        let clone = record.deepCopy()
        for name in ["id", "lastIdx", "clrIdx"] { clone[attribute: name] = nil }
        clone.attributes.removeAll { $0.name == "xmlns" || $0.name.hasPrefix("xmlns:") }
        return clone.serialized()
    }

    private static func presenceIdentity(_ record: XML.Element) -> String? {
        var stack = [record]
        while let element = stack.popLast() {
            if let provider = element[attribute: "providerId"], let user = element[attribute: "userId"],
               !provider.isEmpty, provider != "None", !user.isEmpty { return "\(provider)\u{1}\(user)" }
            stack.append(contentsOf: element.childElements)
        }
        return nil
    }

    func remapAuthors(in comments: Part) throws {
        let root = try comments.dom()
        for cm in LegacyComments.elements(root, named: "cm") {
            guard let oldID = LegacyComments.idKey(cm[attribute: "authorId"]), let id = mapping[oldID],
                  let high = highIndex[id], high < OOXMLBounds.drawingElementID.upperBound,
                  let record = recordsByID[LegacyComments.idKey(id)!] else {
                throw RostrumError.packageInvalid("legacy comment author or index cannot be resolved")
            }
            let index = high + 1
            cm[attribute: "authorId"] = id; cm[attribute: "idx"] = String(index)
            record[attribute: "lastIdx"] = String(index)
            highIndex[id] = index
        }
        comments.markDirty(); authors.markDirty()
    }

    func commit() {
        authors.flushIfDirty()
        let installed: Part
        if let existing = dest.parts[authors.uri] {
            if existing.blob != authors.blob { existing.replaceBlob(authors.blob) }
            installed = existing
        } else { installed = dest.addPart(uri: authors.uri, contentType: authors.contentType, blob: authors.blob) }
        installed.rels.setItems(authors.rels.items)
        if isNew {
            presentation.rels.add(type: LegacyComments.authorsRelType,
                                  target: presentation.uri.relativeReference(to: authors.uri))
        }
    }
}
