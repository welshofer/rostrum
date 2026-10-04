import Foundation

/// Office 2007–2019 comment parts. Numeric comment indices are unique across
/// the document for each author; legacy comments have no modern thread state.
enum LegacyComments {
    static let commentsRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"
    static let authorsRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/commentAuthors"
    static let contentType = "application/vnd.openxmlformats-officedocument.presentationml.comments+xml"
    static let authorsContentType = "application/vnd.openxmlformats-officedocument.presentationml.commentAuthors+xml"

    static func elements(_ root: XML.Element, named name: String) -> [XML.Element] {
        var result: [XML.Element] = []
        ModernComments.visit(in: root) { element, ns, local in
            if ns == MinimalTemplate.nsP, local == name { result.append(element) }
        }
        return result
    }

    static func authorPart(in package: OPCPackage) throws -> Part {
        try package.mainDocumentPart().related(by: authorsRelType, in: package)
    }

    static func idKey(_ raw: String?) -> String? {
        guard let raw, let value = Int(raw), OOXMLBounds.drawingElementID.contains(value) else { return nil }
        return String(value)
    }

    static func nextIndex(authorID: String, in package: OPCPackage, record: XML.Element) throws -> Int {
        var maximum = record.boundedInt("lastIdx", in: OOXMLBounds.drawingElementID) ?? 0
        for part in package.parts.values where part.contentType == contentType {
            for cm in elements(try part.dom(), named: "cm") where idKey(cm[attribute: "authorId"]) == idKey(authorID) {
                maximum = max(maximum, cm.boundedInt("idx", in: OOXMLBounds.drawingElementID) ?? 0)
            }
        }
        guard maximum < OOXMLBounds.drawingElementID.upperBound else {
            throw RostrumError.packageInvalid("legacy comment indices exhausted for author \(authorID)")
        }
        return maximum + 1
    }
}

public final class LegacyComment {
    let cm: XML.Element
    let part: Part
    let package: OPCPackage

    init(cm: XML.Element, part: Part, package: OPCPackage) {
        self.cm = cm; self.part = part; self.package = package
    }

    public var id: String? { cm[attribute: "idx"] }
    public var authorID: String? { cm[attribute: "authorId"] }
    public var createdTimestamp: String? { cm[attribute: "dt"] }
    public var author: CommentAuthor? {
        guard let id = LegacyComments.idKey(authorID), let authors = try? LegacyComments.authorPart(in: package),
              let root = try? authors.dom(),
              let author = LegacyComments.elements(root, named: "cmAuthor").first(where: { LegacyComments.idKey($0[attribute: "id"]) == id }) else { return nil }
        return CommentAuthor(author)
    }
    public var authorName: String? { author?.name }
    public var text: String {
        guard let root = try? part.dom() else { return "" }
        return ModernComments.directChildren(of: cm, in: root, namespace: MinimalTemplate.nsP, named: "text").first?.textContent ?? ""
    }
    public var anchor: CommentAnchor? {
        guard let slide = try? ModernComments.owner(of: part, in: package), let id = try? slide.slideID() else { return nil }
        return .slide(slideID: id)
    }
    public var position: (x: EMU, y: EMU)? {
        guard let root = try? part.dom(), let position = ModernComments.directChildren(
            of: cm, in: root, namespace: MinimalTemplate.nsP, named: "pos").first,
              let x = position.coordinate("x"), let y = position.coordinate("y") else { return nil }
        return (EMU(x), EMU(y))
    }

    public func setText(_ text: String) throws {
        let root = try part.dom()
        let element = ModernComments.directChildren(of: cm, in: root, namespace: MinimalTemplate.nsP, named: "text").first
            ?? XML.Element(ModernComments.qualified("text", like: cm))
        // Keep comments, instructions and extension elements inside p:text;
        // replace only the edited character data.
        var replacement: [XML.Node] = []
        var written = false
        for child in element.children {
            if case .text = child {
                if !written { replacement.append(.text(text)); written = true }
            } else { replacement.append(child) }
        }
        if !written { replacement.insert(.text(text), at: 0) }
        element.children = replacement
        if !cm.childElements.contains(where: { $0 === element }) {
            cm.insertChild(element, beforeAnyOf: [ModernComments.qualified("extLst", like: cm)])
        }
        part.markDirty()
    }

    public func setPosition(x: EMU, y: EMU) throws {
        guard OOXMLBounds.coordinate.contains(x.rawValue), OOXMLBounds.coordinate.contains(y.rawValue) else {
            throw RostrumError.packageInvalid("legacy comment position out of bounds")
        }
        let root = try part.dom()
        let position = ModernComments.directChildren(of: cm, in: root, namespace: MinimalTemplate.nsP, named: "pos").first
            ?? XML.Element(ModernComments.qualified("pos", like: cm))
        position[attribute: "x"] = String(x.rawValue); position[attribute: "y"] = String(y.rawValue)
        if !cm.childElements.contains(where: { $0 === position }) { cm.children.insert(.element(position), at: 0) }
        part.markDirty()
    }

    public func delete() throws {
        let root = try part.dom()
        guard root.childElements.contains(where: { $0 === cm }) else {
            throw RostrumError.packageInvalid("legacy comment has already been deleted")
        }
        root.removeChild(cm)
        part.markDirty()
    }
}

extension Slide {
    public var legacyComments: [LegacyComment] {
        guard let rel = part.rels.first(ofType: LegacyComments.commentsRelType), !rel.isExternal,
              let comments = try? package.part(at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)),
              let root = try? comments.dom() else { return [] }
        return LegacyComments.elements(root, named: "cm").filter { element in root.childElements.contains { $0 === element } }
            .map { LegacyComment(cm: $0, part: comments, package: package) }
    }

    @discardableResult
    public func addLegacyComment(_ text: String, author: String, initials: String? = nil,
                                 at position: (x: EMU, y: EMU) = (.inches(0.5), .inches(0.5))) throws -> LegacyComment {
        guard OOXMLBounds.coordinate.contains(position.x.rawValue), OOXMLBounds.coordinate.contains(position.y.rawValue) else {
            throw RostrumError.packageInvalid("legacy comment position out of bounds")
        }
        _ = try slideID()
        let presentation = try package.mainDocumentPart()
        let existing: Part?
        if let rel = part.rels.first(ofType: LegacyComments.commentsRelType) {
            guard !rel.isExternal else { throw RostrumError.packageInvalid("legacy comments must be internal") }
            existing = try package.part(at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
            _ = try existing?.dom()
        } else { existing = nil }
        let authors: Part
        if presentation.rels.first(ofType: LegacyComments.authorsRelType) != nil {
            authors = try LegacyComments.authorPart(in: package)
        } else {
            var n = 1
            var uri = PackURI("/ppt/commentAuthors.xml")
            while package.parts[uri] != nil { uri = PackURI("/ppt/commentAuthors\(n).xml"); n += 1 }
            authors = Part(uri: uri, contentType: LegacyComments.authorsContentType,
                blob: XML.document(XML.Element("p:cmAuthorLst", attributes: [("xmlns:p", MinimalTemplate.nsP)])))
        }
        let root = try authors.dom()
        let records = LegacyComments.elements(root, named: "cmAuthor")
        let record: XML.Element
        if let matching = records.first(where: { $0[attribute: "name"] == author && (initials == nil || $0[attribute: "initials"] == initials) }) {
            record = matching
        } else {
            var id = 0
            let used = Set(records.compactMap { $0.boundedInt("id", in: OOXMLBounds.drawingElementID) })
            while used.contains(id), id < OOXMLBounds.drawingElementID.upperBound { id += 1 }
            guard !used.contains(id) else { throw RostrumError.packageInvalid("legacy author IDs exhausted") }
            record = XML.Element(ModernComments.qualified("cmAuthor", like: root), attributes: [
                ("id", String(id)), ("name", author), ("initials", initials ?? String(author.split(separator: " ").compactMap(\.first).prefix(3)).uppercased()),
                ("lastIdx", "0"), ("clrIdx", String(id % 8)),
            ])
        }
        let authorID = try requireLegacyID(record)
        let index = try LegacyComments.nextIndex(authorID: authorID, in: package, record: record)
        // All throwing work is complete before installing a new part/author.
        if package.parts[authors.uri] == nil {
            package.addPart(uri: authors.uri, contentType: authors.contentType, blob: authors.blob)
            // The local staged DOM must be transferred after its edits below.
            presentation.rels.add(type: LegacyComments.authorsRelType, target: presentation.uri.relativeReference(to: authors.uri))
        }
        if !records.contains(where: { $0 === record }) { root.appendElement(record) }
        record[attribute: "lastIdx"] = String(index)
        authors.markDirty(); authors.flushIfDirty()
        package.parts[authors.uri]?.replaceBlob(authors.blob)
        let comments: Part
        if let existing { comments = existing }
        else {
            var n = 1
            while package.parts[PackURI("/ppt/comments/comment\(n).xml")] != nil { n += 1 }
            let uri = PackURI("/ppt/comments/comment\(n).xml")
            comments = package.addPart(uri: uri, contentType: LegacyComments.contentType,
                blob: XML.document(XML.Element("p:cmLst", attributes: [("xmlns:p", MinimalTemplate.nsP)])))
            part.rels.add(type: LegacyComments.commentsRelType, target: part.uri.relativeReference(to: uri))
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let commentRoot = try comments.dom()
        let cm = XML.Element(ModernComments.qualified("cm", like: commentRoot), attributes: [
            ("authorId", authorID), ("dt", formatter.string(from: Date())), ("idx", String(index)),
        ], children: [
            .element(XML.Element(ModernComments.qualified("pos", like: commentRoot), attributes: [("x", String(position.x.rawValue)), ("y", String(position.y.rawValue))])),
            .element(XML.Element(ModernComments.qualified("text", like: commentRoot), children: [.text(text)])),
        ])
        commentRoot.appendElement(cm); comments.markDirty()
        return LegacyComment(cm: cm, part: comments, package: package)
    }

    private func requireLegacyID(_ record: XML.Element) throws -> String {
        guard let id = record[attribute: "id"], record.boundedInt("id", in: OOXMLBounds.drawingElementID) != nil else {
            throw RostrumError.packageInvalid("legacy author has invalid ID")
        }
        return id
    }
}
