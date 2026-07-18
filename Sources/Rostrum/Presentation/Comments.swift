import Foundation

/// Modern (threaded, PowerPoint 2021+/M365) comments.
///
/// Two Microsoft-extension part types: one package-wide `/ppt/authors.xml`
/// (root `p188:authorLst`) and one comment part per slide (root `p188:cmLst`),
/// namespace 2018/8, relationship types 2018/10 — the version skew is real.
/// Older PowerPoint (2016/2019) silently never shows these; that's the
/// format, not a bug.
public enum ModernComments {
    static let ns = "http://schemas.microsoft.com/office/powerpoint/2018/8/main"
    static let nsPC = "http://schemas.microsoft.com/office/powerpoint/2013/main/command"
    static let nsAC = "http://schemas.microsoft.com/office/drawing/2013/main/command"
    static let authorsRelType = "http://schemas.microsoft.com/office/2018/10/relationships/authors"
    static let commentsRelType = "http://schemas.microsoft.com/office/2018/10/relationships/comments"
    static let authorsContentType = "application/vnd.ms-powerpoint.authors+xml"
    /// PLURAL — the singular variant triggers the repair dialog.
    static let commentsContentType = "application/vnd.ms-powerpoint.comments+xml"
    static let commentRelExtURI = "{6950BFC3-D8DA-4A85-94F7-54DA5524770B}"

    static func guid() -> String {
        "{\(UUID().uuidString)}"
    }

    /// Desktop-PowerPoint style: local time, milliseconds, no zone designator.
    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

/// One comment thread (a `p188:cm`, or a `p188:reply` when `isReply`).
public final class Comment {
    let cm: XML.Element
    let part: Part
    let package: OPCPackage
    public let isReply: Bool

    init(cm: XML.Element, part: Part, package: OPCPackage, isReply: Bool = false) {
        self.cm = cm
        self.part = part
        self.package = package
        self.isReply = isReply
    }

    public var text: String {
        cm.firstChild(named: "p188:txBody")?.textContent ?? ""
    }

    /// Author display name, resolved through /ppt/authors.xml.
    public var authorName: String? {
        guard let authorId = cm[attribute: "authorId"],
              let authors = package.parts[PackURI("/ppt/authors.xml")],
              let dom = try? authors.dom() else { return nil }
        return dom.children(named: "p188:author")
            .first { $0[attribute: "id"] == authorId }?[attribute: "name"]
    }

    public var replies: [Comment] {
        cm.firstChild(named: "p188:replyLst")?.children(named: "p188:reply")
            .map { Comment(cm: $0, part: part, package: package, isReply: true) } ?? []
    }

    /// Add a threaded reply (single-level; replies carry no anchor or pos).
    @discardableResult
    public func addReply(_ text: String, author: String, initials: String? = nil) throws -> Comment {
        precondition(!isReply, "replies to replies are not part of the format")
        let authorId = try Slide.ensureAuthor(named: author, initials: initials, in: package)
        let reply = XML.Element("p188:reply", attributes: [
            ("id", ModernComments.guid()),
            ("authorId", authorId),
            ("created", ModernComments.timestamp()),
        ])
        reply.appendElement(Slide.commentTxBody(text))
        // replyLst sits between pos and txBody (strict sequence).
        let replyLst = cm.getOrAddChild("p188:replyLst", beforeAnyOf: ["p188:txBody"])
        replyLst.appendElement(reply)
        part.markDirty()
        return Comment(cm: reply, part: part, package: package, isReply: true)
    }

    /// Mark the thread resolved (root comments only).
    public func resolve() {
        cm[attribute: "status"] = "resolved"
        part.markDirty()
    }

    public var isResolved: Bool {
        cm[attribute: "status"] == "resolved"
    }
}

extension Slide {
    /// The slide's modern comment threads.
    public var comments: [Comment] {
        guard let commentsPart = try? existingCommentsPart(),
              let dom = try? commentsPart.dom() else { return [] }
        return dom.children(named: "p188:cm")
            .map { Comment(cm: $0, part: commentsPart, package: package) }
    }

    /// Add a slide-anchored comment thread at `position` (EMU from the
    /// slide's top-left).
    @discardableResult
    public func addComment(
        _ text: String, author: String, initials: String? = nil,
        at position: (x: EMU, y: EMU) = (.inches(0.5), .inches(0.5))
    ) throws -> Comment {
        let authorId = try Slide.ensureAuthor(named: author, initials: initials, in: package)
        let commentsPart = try existingCommentsPart() ?? createCommentsPart()

        let cm = XML.Element("p188:cm", attributes: [
            ("id", ModernComments.guid()),
            ("authorId", authorId),
            ("created", ModernComments.timestamp()),
        ])
        // Strict child order: anchor → pos → (replyLst) → txBody.
        let anchor = XML.Element("pc:sldMkLst", attributes: [("xmlns:pc", ModernComments.nsPC)])
        anchor.appendElement(XML.Element("pc:docMk"))
        anchor.appendElement(XML.Element("pc:sldMk", attributes: [
            ("cId", "0"), ("sldId", String(try slideID())),
        ]))
        cm.appendElement(anchor)
        cm.appendElement(XML.Element("p188:pos", attributes: [
            ("x", String(position.x.rawValue)), ("y", String(position.y.rawValue)),
        ]))
        cm.appendElement(Slide.commentTxBody(text))

        try commentsPart.dom().appendElement(cm)
        commentsPart.markDirty()
        return Comment(cm: cm, part: commentsPart, package: package)
    }

    // MARK: - Plumbing

    static func commentTxBody(_ text: String) -> XML.Element {
        let txBody = XML.Element("p188:txBody")
        txBody.appendElement(XML.Element("a:bodyPr"))
        txBody.appendElement(XML.Element("a:lstStyle"))
        let p = XML.Element("a:p")
        let r = XML.Element("a:r")
        r.appendElement(XML.Element("a:rPr", attributes: [("lang", "en-US")]))
        let t = XML.Element("a:t")
        t.children = [.text(text)]
        r.appendElement(t)
        p.appendElement(r)
        txBody.appendElement(p)
        return txBody
    }

    /// Get-or-create the package-wide authors part; returns the author GUID.
    static func ensureAuthor(named name: String, initials: String?, in package: OPCPackage) throws -> String {
        let uri = PackURI("/ppt/authors.xml")
        let authorsPart: Part
        if let existing = package.parts[uri] {
            authorsPart = existing
        } else {
            let root = XML.Element("p188:authorLst", attributes: [
                ("xmlns:a", MinimalTemplate.nsA),
                ("xmlns:r", MinimalTemplate.nsR),
                ("xmlns:p188", ModernComments.ns),
            ])
            authorsPart = package.addPart(
                uri: uri, contentType: ModernComments.authorsContentType,
                blob: XML.document(root))
            // Implicit relationship: rels entry only, nothing in the XML.
            let presentation = try package.mainDocumentPart()
            presentation.rels.add(type: ModernComments.authorsRelType, target: "authors.xml")
        }
        let dom = try authorsPart.dom()
        if let existing = dom.children(named: "p188:author").first(where: { $0[attribute: "name"] == name }),
           let id = existing[attribute: "id"] {
            return id
        }
        let id = ModernComments.guid()
        let derivedInitials = initials ?? String(
            name.split(separator: " ").compactMap(\.first).prefix(3)).uppercased()
        dom.appendElement(XML.Element("p188:author", attributes: [
            ("id", id), ("name", name), ("initials", derivedInitials),
            ("userId", name), ("providerId", "None"),
        ]))
        authorsPart.markDirty()
        return id
    }

    private func existingCommentsPart() throws -> Part? {
        guard let rel = part.rels.items.first(where: { $0.type == ModernComments.commentsRelType })
        else { return nil }
        return try package.part(at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
    }

    private func createCommentsPart() throws -> Part {
        var n = 1
        while package.parts[PackURI("/ppt/comments/modernComment_\(n).xml")] != nil { n += 1 }
        let uri = PackURI("/ppt/comments/modernComment_\(n).xml")

        let root = XML.Element("p188:cmLst", attributes: [
            ("xmlns:a", MinimalTemplate.nsA),
            ("xmlns:r", MinimalTemplate.nsR),
            ("xmlns:p188", ModernComments.ns),
        ])
        let commentsPart = package.addPart(
            uri: uri, contentType: ModernComments.commentsContentType,
            blob: XML.document(root))

        let rId = part.rels.add(
            type: ModernComments.commentsRelType,
            target: part.uri.relativeReference(to: uri))

        // The in-content reference: p:extLst as the LAST child of p:sld.
        let dom = try part.dom()
        let extLst = dom.getOrAddChild("p:extLst")
        let ext = XML.Element("p:ext", attributes: [("uri", ModernComments.commentRelExtURI)])
        ext.appendElement(XML.Element("p188:commentRel", attributes: [
            ("xmlns:p188", ModernComments.ns), ("r:id", rId),
        ]))
        extLst.appendElement(ext)
        part.markDirty()
        return commentsPart
    }

    /// This slide's `p:sldId id` in the presentation's slide list.
    func slideID() throws -> Int {
        let presentation = try package.mainDocumentPart()
        guard let list = try presentation.dom().firstChild(named: "p:sldIdLst") else {
            throw RostrumError.packageInvalid("presentation has no sldIdLst")
        }
        for entry in list.childElements {
            guard let rId = entry[attribute: "r:id"],
                  let rel = presentation.rels.relationship(withId: rId) else { continue }
            let uri = PackURI.resolve(target: rel.target, relativeTo: presentation.uri.baseURI)
            if uri == part.uri, let id = entry[attribute: "id"].flatMap({ Int($0) }) {
                return id
            }
        }
        throw RostrumError.packageInvalid("slide \(part.uri) not found in sldIdLst")
    }
}
