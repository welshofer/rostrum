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

    init(source: OPCPackage, dest: OPCPackage, presentation: Part) throws {
        self.dest = dest; self.presentation = presentation
        let sourceAuthors = try LegacyComments.authorPart(in: source)
        sourceAuthors.flushIfDirty()
        let sourceRoot = try sourceAuthors.dom()
        if presentation.rels.first(ofType: LegacyComments.authorsRelType) != nil {
            let existing = try LegacyComments.authorPart(in: dest)
            existing.flushIfDirty()
            authors = Part(uri: existing.uri, contentType: existing.contentType, blob: existing.blob)
            isNew = false
        } else {
            var n = 1
            var uri = PackURI("/ppt/commentAuthors.xml")
            while dest.parts[uri] != nil { uri = PackURI("/ppt/commentAuthors\(n).xml"); n += 1 }
            authors = Part(uri: uri, contentType: LegacyComments.authorsContentType, blob: sourceAuthors.blob)
            let root = try authors.dom()
            for record in LegacyComments.elements(root, named: "cmAuthor") { root.removeChild(record) }
            authors.markDirty()
            isNew = true
        }
        let root = try authors.dom()
        var records = LegacyComments.elements(root, named: "cmAuthor")
        for record in records {
            guard let id = record[attribute: "id"], recordsByID[id] == nil,
                  record.boundedInt("id", in: OOXMLBounds.drawingElementID) != nil else {
                throw RostrumError.packageInvalid("destination legacy authors have invalid or duplicate IDs")
            }
            recordsByID[id] = record
        }
        for sourceRecord in LegacyComments.elements(sourceRoot, named: "cmAuthor") {
            guard let sourceID = sourceRecord[attribute: "id"], mapping[sourceID] == nil,
                  sourceRecord.boundedInt("id", in: OOXMLBounds.drawingElementID) != nil else {
                throw RostrumError.packageInvalid("source legacy authors have invalid or duplicate IDs")
            }
            let signature = Self.signature(sourceRecord)
            var match = records.first { $0[attribute: "id"] == sourceID && Self.signature($0) == signature }
            let identity = Self.presenceIdentity(sourceRecord)
            if match == nil, let identity { match = records.first { Self.presenceIdentity($0) == identity } }
            var id = sourceID
            if match == nil, recordsByID[id] != nil {
                let guid = SectionGUID.make(name: "legacy-author:\(sourceID):\(signature)", index: 0, avoiding: [])
                let hex = String(guid.dropFirst().prefix(8))
                var candidate = Int(UInt32(hex, radix: 16) ?? 0)
                while let existing = recordsByID[String(candidate)] {
                    if Self.signature(existing) == signature { match = existing; break }
                    guard candidate < OOXMLBounds.drawingElementID.upperBound else {
                        throw RostrumError.packageInvalid("legacy author ID collision cannot be resolved")
                    }
                    candidate += 1
                }
                id = String(candidate)
            }
            if let match, let matchedID = match[attribute: "id"] { id = matchedID }
            else {
                let clone = sourceRecord.deepCopy()
                for attr in sourceRoot.attributes where attr.name == "xmlns" || attr.name.hasPrefix("xmlns:") {
                    if clone[attribute: attr.name] == nil { clone[attribute: attr.name] = attr.value }
                }
                clone[attribute: "id"] = id
                root.appendElement(clone); authors.markDirty()
                records.append(clone); recordsByID[id] = clone
            }
            mapping[sourceID] = id
            if highIndex[id] == nil, let record = recordsByID[id] {
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
            guard let oldID = cm[attribute: "authorId"], let id = mapping[oldID],
                  let high = highIndex[id], high < OOXMLBounds.drawingElementID.upperBound,
                  let record = recordsByID[id] else {
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
        if let existing = dest.parts[authors.uri] {
            if existing.blob != authors.blob { existing.replaceBlob(authors.blob) }
        } else { dest.addPart(uri: authors.uri, contentType: authors.contentType, blob: authors.blob) }
        if isNew {
            presentation.rels.add(type: LegacyComments.authorsRelType,
                                  target: presentation.uri.relativeReference(to: authors.uri))
        }
    }
}
