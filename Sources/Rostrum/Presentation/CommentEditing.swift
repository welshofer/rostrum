import Foundation

/// Explicit modern comment targets. Text offsets count UTF-16 code units in
/// OfficeArt plain text (paragraph separators are carriage returns).
public enum CommentAnchor: Sendable, Equatable {
    case slide(slideID: Int)
    case shape(slideID: Int, shapeID: Int)
    case text(slideID: Int, shapeID: Int, start: Int, length: Int)
    /// Unrecognized anchors remain intact until an explicit anchor edit.
    case unknown(xml: String)
}

public struct CommentAuthor: Sendable, Equatable {
    public let id: String
    public let name: String
    public let initials: String?
    public let userID: String?
    public let providerID: String?

    init(_ element: XML.Element) {
        id = element[attribute: "id"] ?? ""
        name = element[attribute: "name"] ?? ""
        initials = element[attribute: "initials"]
        userID = element[attribute: "userId"]
        providerID = element[attribute: "providerId"]
    }
}

extension ModernComments {
    static func directChildren(of parent: XML.Element, in root: XML.Element,
                               namespace: String, named name: String) -> [XML.Element] {
        let children = parent.childElements
        var result: [XML.Element] = []
        visit(in: root) { element, ns, local in
            if ns == namespace, local == name, children.contains(where: { $0 === element }) {
                result.append(element)
            }
        }
        return result
    }

    static func qualified(_ localName: String, like element: XML.Element) -> String {
        let components = element.name.split(separator: ":", maxSplits: 1)
        return components.count == 2 ? "\(components[0]):\(localName)" : localName
    }

    static func owner(of comments: Part, in package: OPCPackage) throws -> Slide {
        let owners = package.parts.values.filter { part in
            part.contentType == ContentType.slide && part.rels.items.contains {
                !$0.isExternal && PackURI.resolve(target: $0.target, relativeTo: part.uri.baseURI) == comments.uri
            }
        }
        guard owners.count == 1, let part = owners.first else {
            throw RostrumError.packageInvalid("comment part has no unique owning slide")
        }
        return Slide(part: part, package: package)
    }

    /// The moniker sequence follows MS-PPTX CT_Comment and MS-ODRAWXML
    /// CT_DrawingElementMonikerList / CT_TextCharRangeMoniker.
    static func anchorElement(_ anchor: CommentAnchor, for slide: Slide) throws -> XML.Element {
        let actualID = try slide.slideID()
        let slideID: Int
        let shapeID: Int?
        let range: (start: Int, length: Int)?
        switch anchor {
        case .slide(let id): slideID = id; shapeID = nil; range = nil
        case .shape(let id, let shape): slideID = id; shapeID = shape; range = nil
        case .text(let id, let shape, let start, let length):
            slideID = id; shapeID = shape; range = (start, length)
        case .unknown:
            throw RostrumError.packageInvalid("unknown anchors are preserved but cannot be authored")
        }
        guard slideID == actualID else {
            throw RostrumError.packageInvalid("comment anchor must target its owning slide")
        }
        let rootName = range != nil ? "ac:txMkLst" : shapeID != nil ? "ac:deMkLst" : "pc:sldMkLst"
        let anchor = XML.Element(rootName, attributes: [("xmlns:pc", nsPC), ("xmlns:ac", nsAC)])
        anchor.appendElement(XML.Element("pc:docMk"))
        anchor.appendElement(XML.Element("pc:sldMk", attributes: [("cId", "0"), ("sldId", String(actualID))]))
        if let shapeID {
            let tree = try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")
            let names: [String: String] = ["p:sp": "spMk", "p:pic": "picMk", "p:graphicFrame": "graphicFrameMk",
                                           "p:cxnSp": "cxnSpMk", "p:grpSp": "grpSpMk"]
            let shape = tree?.childElements.first { element in
                guard names[element.name] != nil else { return false }
                return element.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"] == String(shapeID)
            }
            guard OOXMLBounds.drawingElementID.contains(shapeID), let shape, let name = names[shape.name] else {
                throw RostrumError.packageInvalid("comment shape anchor cannot resolve a top-level drawing element")
            }
            anchor.appendElement(XML.Element("ac:\(name)", attributes: [("id", String(shapeID))]))
            if let range {
                guard let body = shape.firstChild(named: "p:txBody") else {
                    throw RostrumError.packageInvalid("text anchor target has no text body")
                }
                let count = body.children(named: "a:p").map { paragraph in
                    var text = ""
                    for child in paragraph.childElements {
                        if child.name == "a:br" { text += "\u{000B}" }
                        else { text += child.textContent }
                    }
                    return text
                }.joined(separator: "\r").utf16.count
                guard range.start >= 0, range.length >= 0, range.start <= Int(Int32.max),
                      range.length <= Int(Int32.max), range.start <= count, range.length <= count - range.start else {
                    throw RostrumError.packageInvalid("comment text range is outside the shape text")
                }
                anchor.appendElement(XML.Element("ac:txMk", attributes: [("cp", String(range.start)), ("len", String(range.length))]))
            }
        }
        return anchor
    }
}

extension Comment {
    func children(_ name: String, in parent: XML.Element? = nil, namespace: String = ModernComments.ns) -> [XML.Element] {
        guard let root = try? part.dom() else { return [] }
        return ModernComments.directChildren(of: parent ?? cm, in: root, namespace: namespace, named: name)
    }

    public var id: String? { cm[attribute: "id"] }
    public var authorID: String? { cm[attribute: "authorId"] }
    /// Exact source timestamp, retaining milliseconds and its zone spelling.
    public var createdTimestamp: String? { cm[attribute: "created"] }
    public var author: CommentAuthor? {
        guard let id = authorID, let presentation = try? package.mainDocumentPart(),
              let authors = try? presentation.related(by: ModernComments.authorsRelType, in: package),
              let root = try? authors.dom(),
              let record = AnnotationAuthorImport.authorElements(root).first(where: { $0[attribute: "id"] == id }) else { return nil }
        return CommentAuthor(record)
    }

    public var textParagraphs: [String] {
        guard let body = children("txBody").first else { return [] }
        return children("p", in: body, namespace: MinimalTemplate.nsA).map(\.textContent)
    }

    /// Replace text while retaining the text-body properties, reused paragraph
    /// formatting and unknown markup. Refuse removal of a paragraph carrying
    /// unmodeled data instead of silently discarding it.
    public func setText(_ text: String) throws {
        guard let body = children("txBody").first else {
            throw RostrumError.packageInvalid("comment has no text body")
        }
        let strings = text.components(separatedBy: "\n")
        let old = children("p", in: body, namespace: MinimalTemplate.nsA)
        for paragraph in old.dropFirst(strings.count) {
            var unknown = false
            ModernComments.visit(in: try part.dom()) { element, ns, _ in
                var stack = [paragraph]
                while let candidate = stack.popLast() {
                    if candidate === element, ns != MinimalTemplate.nsA { unknown = true }
                    stack.append(contentsOf: candidate.childElements)
                }
            }
            var stack = [paragraph]
            while let element = stack.popLast() {
                let editableAttributes: Set<String> = ["lang", "sz", "b", "i", "u", "strike", "baseline", "kern", "dirty", "smtClean", "typeface", "val", "marL", "indent", "algn", "lvl", "defTabSz", "rtl", "hangingPunct", "latinLnBrk", "eaLnBrk", "fontAlgn", "xml:space"]
                if element.attributes.contains(where: { !$0.name.hasPrefix("xmlns") && !editableAttributes.contains($0.name) }) { unknown = true }
                for node in element.children {
                    switch node {
                    case .comment, .processingInstruction: unknown = true
                    case .element(let child): stack.append(child)
                    case .text: break
                    }
                }
            }
            guard !unknown else { throw RostrumError.packageInvalid("text edit would remove unmodeled paragraph data") }
        }
        var paragraphs: [XML.Element] = []
        for (index, string) in strings.enumerated() {
            let paragraph = index < old.count ? old[index].deepCopy() : XML.Element("a:p", attributes: [("xmlns:a", MinimalTemplate.nsA)])
            var texts: [XML.Element] = []
            // Existing DrawingML prefixes may be inherited from the source
            // document. Collect by identity through its namespace-aware walk.
            if index < old.count {
                var originals: [XML.Element] = []
                var descendants = [old[index]]
                while let element = descendants.popLast() { originals.append(element); descendants.append(contentsOf: element.childElements) }
                var names: Set<String> = []
                var breakNames: Set<String> = []
                ModernComments.visit(in: try part.dom()) { element, ns, local in
                    if ns == MinimalTemplate.nsA, originals.contains(where: { $0 === element }) {
                        if local == "t" { names.insert(element.name) }
                        if local == "br" { breakNames.insert(element.name) }
                    }
                }
                var stack = [paragraph]
                while let element = stack.popLast() {
                    if names.contains(element.name) { texts.append(element) }
                    element.children.removeAll { node in
                        if case .element(let child) = node { return breakNames.contains(child.name) }
                        return false
                    }
                    stack.append(contentsOf: element.childElements.reversed())
                }
            }
            if let first = texts.first {
                first.children = [.text(string)]
                for extra in texts.dropFirst() { extra.children = [.text("")] }
            } else {
                paragraph.insertChild(XML.Element("a:r", attributes: [("xmlns:a", MinimalTemplate.nsA)], children: [
                    .element(XML.Element("a:t", children: [.text(string)])),
                ]), beforeAnyOf: ["a:endParaRPr"])
            }
            paragraphs.append(paragraph)
        }
        var index = 0
        var replacement: [XML.Node] = []
        for node in body.children {
            if case .element(let element) = node, old.contains(where: { $0 === element }) {
                if index < paragraphs.count { replacement.append(.element(paragraphs[index])); index += 1 }
            } else { replacement.append(node) }
        }
        replacement.append(contentsOf: paragraphs.dropFirst(index).map { .element($0) })
        body.children = replacement
        part.markDirty()
    }

    /// Reopen a resolved root thread. Replies have no independent lifecycle in
    /// this API, so refusing a reply operation leaves its XML unchanged.
    @discardableResult
    public func reopen() -> Bool {
        guard !isReply else { return false }
        cm[attribute: "status"] = nil
        part.markDirty()
        return true
    }

    public var position: (x: EMU, y: EMU)? {
        guard let element = children("pos").first,
              let x = element.coordinate("x"), let y = element.coordinate("y") else { return nil }
        return (EMU(x), EMU(y))
    }

    public func setPosition(x: EMU, y: EMU) throws {
        guard !isReply, OOXMLBounds.coordinate.contains(x.rawValue), OOXMLBounds.coordinate.contains(y.rawValue) else {
            throw RostrumError.packageInvalid("invalid comment position or reply operation")
        }
        let position = children("pos").first ?? XML.Element(ModernComments.qualified("pos", like: cm))
        if !cm.childElements.contains(where: { $0 === position }) {
            cm.insertChild(position, beforeAnyOf: [children("replyLst").first?.name, children("txBody").first?.name].compactMap { $0 })
        }
        position[attribute: "x"] = String(x.rawValue)
        position[attribute: "y"] = String(y.rawValue)
        part.markDirty()
    }

    public var anchor: CommentAnchor? {
        guard !isReply, let root = try? part.dom() else { return nil }
        let candidates = cm.childElements
        var anchors: [XML.Element] = []
        ModernComments.visit(in: root) { element, ns, name in
            if candidates.contains(where: { $0 === element }),
               (ns == ModernComments.nsPC && name == "sldMkLst")
                || (ns == ModernComments.nsAC && (name == "deMkLst" || name == "txMkLst"))
                || (ns == ModernComments.ns && name == "unknownAnchor") { anchors.append(element) }
        }
        guard let node = anchors.first else { return nil }
        var slideID: Int?
        var shapeID: Int?
        var range: (Int, Int)?
        ModernComments.visit(in: root) { element, ns, name in
            var stack = [node]
            var contains = false
            while let candidate = stack.popLast() {
                if candidate === element { contains = true; break }
                stack.append(contentsOf: candidate.childElements)
            }
            guard contains else { return }
            if ns == ModernComments.nsPC, name == "sldMk" { slideID = element[attribute: "sldId"].flatMap(Int.init) }
            if ns == ModernComments.nsAC, ["spMk", "picMk", "graphicFrameMk", "grpSpMk", "cxnSpMk", "inkMk"].contains(name) {
                shapeID = element[attribute: "id"].flatMap(Int.init)
            }
            if ns == ModernComments.nsAC, name == "txMk", let start = element[attribute: "cp"].flatMap(Int.init) {
                range = (start, element[attribute: "len"].flatMap(Int.init) ?? 0)
            }
        }
        guard let slideID else { return .unknown(xml: node.serialized()) }
        if let shapeID, let range { return .text(slideID: slideID, shapeID: shapeID, start: range.0, length: range.1) }
        if let shapeID { return .shape(slideID: slideID, shapeID: shapeID) }
        return .slide(slideID: slideID)
    }

    public func setAnchor(_ anchor: CommentAnchor) throws {
        guard !isReply else { throw RostrumError.packageInvalid("replies cannot carry anchors") }
        let owner = try ModernComments.owner(of: part, in: package)
        let replacement = try ModernComments.anchorElement(anchor, for: owner)
        let root = try part.dom()
        let candidates = cm.childElements
        var old: [XML.Element] = []
        ModernComments.visit(in: root) { element, ns, name in
            if candidates.contains(where: { $0 === element }),
               (ns == ModernComments.nsPC && name == "sldMkLst")
                || (ns == ModernComments.nsAC && (name == "deMkLst" || name == "txMkLst"))
                || (ns == ModernComments.ns && name == "unknownAnchor") { old.append(element) }
        }
        for element in old { cm.removeChild(element) }
        cm.children.insert(.element(replacement), at: 0)
        part.markDirty()
    }

    /// Delete this root thread (including its replies), or this reply only.
    public func delete() throws {
        let root = try part.dom()
        var stack = [root]
        while let parent = stack.popLast() {
            if parent.childElements.contains(where: { $0 === cm }) {
                parent.removeChild(cm)
                part.markDirty()
                return
            }
            stack.append(contentsOf: parent.childElements)
        }
        throw RostrumError.packageInvalid("comment has already been deleted")
    }
}
