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
    private final class WeakElementBox {
        weak var element: XML.Element?
        init(_ element: XML.Element) { self.element = element }
    }

    private struct ParentLink {
        let parentBox: WeakElementBox
        var indexHint: Int
    }

    private struct RootIndexState {
        weak var root: XML.Element?
        var indexedChildCount: Int = 0
        var frontShift: Int = 0
        weak var lastRootComment: XML.Element?
    }

    private final class AncestorPathCache: @unchecked Sendable {
        private let lock = NSLock()
        private var links: [ObjectIdentifier: ParentLink] = [:]
        private var roots: [ObjectIdentifier: RootIndexState] = [:]

        private func indexSubtree(_ subtree: XML.Element) {
            var stack: [XML.Element] = [subtree]
            while let parent = stack.popLast() {
                let box = WeakElementBox(parent)
                for (idx, node) in parent.children.enumerated() {
                    guard case .element(let child) = node else { continue }
                    links[ObjectIdentifier(child)] = ParentLink(parentBox: box, indexHint: idx)
                    if !child.children.isEmpty {
                        stack.append(child)
                    }
                }
            }
        }

        private func indexAll(from root: XML.Element) {
            if links.count > 65_536 {
                links.removeAll(keepingCapacity: true)
                roots.removeAll(keepingCapacity: true)
            }
            let rootBox = WeakElementBox(root)
            var lastComment: XML.Element?
            for (idx, node) in root.children.enumerated() {
                guard case .element(let child) = node else { continue }
                links[ObjectIdentifier(child)] = ParentLink(parentBox: rootBox, indexHint: idx)
                lastComment = child
                if !child.children.isEmpty {
                    indexSubtree(child)
                }
            }
            roots[ObjectIdentifier(root)] = RootIndexState(
                root: root,
                indexedChildCount: root.children.count,
                frontShift: 0,
                lastRootComment: lastComment
            )
        }

        private func reindexRootChildrenOnly(_ root: XML.Element) {
            let rootBox = WeakElementBox(root)
            let prevLast = roots[ObjectIdentifier(root)].flatMap { $0.root === root ? $0.lastRootComment : nil }
            for (idx, node) in root.children.enumerated() {
                guard case .element(let child) = node else { continue }
                links[ObjectIdentifier(child)] = ParentLink(parentBox: rootBox, indexHint: idx)
            }
            roots[ObjectIdentifier(root)] = RootIndexState(
                root: root,
                indexedChildCount: root.children.count,
                frontShift: 0,
                lastRootComment: prevLast
            )
        }

        private func tryWalkUp(
            from target: XML.Element,
            in root: XML.Element
        ) -> (chain: [XML.Element], lastChildIndex: Int)? {
            var reversed: [XML.Element] = [target]
            var targetIndexInParent = -1
            var cur = target
            var steps = 0
            let rootID = ObjectIdentifier(root)

            while cur !== root && steps <= XML.maxDepth {
                steps += 1
                let curID = ObjectIdentifier(cur)
                guard let link = links[curID], let parent = link.parentBox.element else {
                    return nil
                }
                let isRootParent = (parent === root)
                let shift = isRootParent
                    ? (roots[rootID].flatMap { $0.root === root ? $0.frontShift : nil } ?? 0)
                    : 0
                let hinted = link.indexHint - shift
                var actualIdx = -1

                if hinted >= 0, hinted < parent.children.count,
                   case .element(let candidate) = parent.children[hinted], candidate === cur {
                    actualIdx = hinted
                } else if hinted - 1 >= 0, hinted - 1 < parent.children.count,
                          case .element(let candidate) = parent.children[hinted - 1], candidate === cur {
                    actualIdx = hinted - 1
                    if !isRootParent {
                        links[curID] = ParentLink(parentBox: link.parentBox, indexHint: actualIdx)
                    }
                } else if !isRootParent {
                    let parentBox = WeakElementBox(parent)
                    for (idx, node) in parent.children.enumerated() {
                        guard case .element(let child) = node else { continue }
                        links[ObjectIdentifier(child)] = ParentLink(parentBox: parentBox, indexHint: idx)
                        if child === cur { actualIdx = idx }
                    }
                } else {
                    reindexRootChildrenOnly(root)
                    if let refreshed = links[curID],
                       refreshed.indexHint >= 0, refreshed.indexHint < root.children.count,
                       case .element(let candidate) = root.children[refreshed.indexHint], candidate === cur {
                        actualIdx = refreshed.indexHint
                    }
                }

                guard actualIdx >= 0 else {
                    links.removeValue(forKey: curID)
                    return nil
                }
                if cur === target {
                    targetIndexInParent = actualIdx
                }
                if isRootParent, roots[rootID]?.root === root {
                    roots[rootID]?.lastRootComment = cur
                }
                reversed.append(parent)
                cur = parent
            }
            guard cur === root else { return nil }
            reversed.reverse()
            return (reversed, targetIndexInParent)
        }

        func resolve(
            target: XML.Element,
            in root: XML.Element
        ) -> (chain: [XML.Element], lastChildIndex: Int)? {
            if target === root { return ([root], -1) }
            lock.lock()
            defer { lock.unlock() }

            if let hit = tryWalkUp(from: target, in: root) {
                return hit
            }

            let rootID = ObjectIdentifier(root)
            if var state = roots[rootID], state.root === root {
                let liveIndexed = max(0, state.indexedChildCount - state.frontShift)
                if liveIndexed < root.children.count {
                    let rootBox = WeakElementBox(root)
                    for idx in liveIndexed..<root.children.count {
                        guard case .element(let child) = root.children[idx] else { continue }
                        links[ObjectIdentifier(child)] = ParentLink(
                            parentBox: rootBox,
                            indexHint: idx + state.frontShift
                        )
                        state.lastRootComment = child
                        if !child.children.isEmpty {
                            indexSubtree(child)
                        }
                    }
                    state.indexedChildCount = root.children.count + state.frontShift
                    roots[rootID] = state
                    if let hit = tryWalkUp(from: target, in: root) {
                        return hit
                    }
                }
                if let lastComment = state.lastRootComment {
                    indexSubtree(lastComment)
                    if let hit = tryWalkUp(from: target, in: root) {
                        return hit
                    }
                }
            }

            indexAll(from: root)
            return tryWalkUp(from: target, in: root)
        }

        func didRemoveChild(
            _ child: XML.Element,
            from parent: XML.Element,
            at removedIndex: Int,
            in root: XML.Element
        ) {
            lock.lock()
            links.removeValue(forKey: ObjectIdentifier(child))
            let rootID = ObjectIdentifier(root)
            if parent === root, var state = roots[rootID], state.root === root {
                if root.children.isEmpty {
                    state = RootIndexState(root: root, indexedChildCount: 0, frontShift: 0, lastRootComment: nil)
                } else if removedIndex == 0 {
                    state.frontShift += 1
                } else if removedIndex == root.children.count {
                    state.indexedChildCount = min(state.indexedChildCount, root.children.count + state.frontShift)
                }
                if state.lastRootComment === child {
                    state.lastRootComment = nil
                }
                roots[rootID] = state
            }
            lock.unlock()
        }
    }

    private static let pathCache = AncestorPathCache()

    static func applyingNamespaces(
        of element: XML.Element,
        to inherited: [String: String]
    ) -> [String: String] {
        var namespaces = inherited
        for attribute in element.attributes {
            if attribute.name == "xmlns" {
                namespaces[""] = attribute.value
            } else if attribute.name.hasPrefix("xmlns:") {
                namespaces[String(attribute.name.dropFirst(6))] = attribute.value
            }
        }
        return namespaces
    }

    static func splitQualifiedName(_ qualifiedName: String) -> (prefix: String, localName: String) {
        if let colon = qualifiedName.firstIndex(of: ":") {
            return (
                String(qualifiedName[..<colon]),
                String(qualifiedName[qualifiedName.index(after: colon)...])
            )
        }
        return ("", qualifiedName)
    }

    fileprivate static func ancestorChainWithLastIndex(
        to target: XML.Element,
        in root: XML.Element
    ) -> (chain: [XML.Element], lastChildIndex: Int)? {
        pathCache.resolve(target: target, in: root)
    }

    fileprivate static func removeIndexedChild(
        _ child: XML.Element,
        at index: Int,
        of parent: XML.Element,
        in root: XML.Element
    ) {
        parent.children.remove(at: index)
        pathCache.didRemoveChild(child, from: parent, at: index, in: root)
    }

    static func namespacesInScope(at target: XML.Element, in root: XML.Element) -> [String: String]? {
        guard let resolved = pathCache.resolve(target: target, in: root) else { return nil }
        var namespaces: [String: String] = [:]
        for ancestor in resolved.chain {
            namespaces = applyingNamespaces(of: ancestor, to: namespaces)
        }
        return namespaces
    }

    static func visitSubtree(
        _ subtreeRoot: XML.Element,
        parentNamespaces: [String: String],
        _ body: (XML.Element, String?, String) -> Void
    ) {
        var stack: [(XML.Element, [String: String])] = [(subtreeRoot, parentNamespaces)]
        while let (element, inherited) = stack.popLast() {
            let namespaces = applyingNamespaces(of: element, to: inherited)
            let (prefix, localName) = splitQualifiedName(element.name)
            body(element, namespaces[prefix], localName)
            for node in element.children.reversed() {
                if case .element(let child) = node {
                    stack.append((child, namespaces))
                }
            }
        }
    }

    static func directChildren(of parent: XML.Element, in root: XML.Element,
                               namespace: String, named name: String) -> [XML.Element] {
        guard let parentNamespaces = namespacesInScope(at: parent, in: root) else { return [] }
        var result: [XML.Element] = []
        for node in parent.children {
            guard case .element(let child) = node else { continue }
            let childNamespaces = applyingNamespaces(of: child, to: parentNamespaces)
            let (prefix, localName) = splitQualifiedName(child.name)
            if childNamespaces[prefix] == namespace, localName == name {
                result.append(child)
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
        let root = try part.dom()
        guard let body = ModernComments.directChildren(
            of: cm, in: root, namespace: ModernComments.ns, named: "txBody"
        ).first,
        let bodyNamespaces = ModernComments.namespacesInScope(at: body, in: root) else {
            throw RostrumError.packageInvalid("comment has no text body")
        }
        let strings = text.components(separatedBy: "\n")
        let old = ModernComments.directChildren(of: body, in: root, namespace: MinimalTemplate.nsA, named: "p")
        let editableAttributes: Set<String> = [
            "lang", "sz", "b", "i", "u", "strike", "baseline", "kern", "dirty", "smtClean",
            "typeface", "val", "marL", "indent", "algn", "lvl", "defTabSz", "rtl",
            "hangingPunct", "latinLnBrk", "eaLnBrk", "fontAlgn", "xml:space",
        ]
        for paragraph in old.dropFirst(strings.count) {
            var unknown = false
            ModernComments.visitSubtree(paragraph, parentNamespaces: bodyNamespaces) { element, ns, _ in
                if ns != MinimalTemplate.nsA { unknown = true }
                if element.attributes.contains(where: {
                    !$0.name.hasPrefix("xmlns") && !editableAttributes.contains($0.name)
                }) {
                    unknown = true
                }
                for node in element.children {
                    switch node {
                    case .comment, .processingInstruction: unknown = true
                    case .element, .text: break
                    }
                }
            }
            guard !unknown else { throw RostrumError.packageInvalid("text edit would remove unmodeled paragraph data") }
        }
        var paragraphs: [XML.Element] = []
        for (index, string) in strings.enumerated() {
            let paragraph = index < old.count ? old[index].deepCopy() : XML.Element("a:p", attributes: [("xmlns:a", MinimalTemplate.nsA)])
            var texts: [XML.Element] = []
            var endParaNames: [String] = ["a:endParaRPr"]
            // Existing DrawingML prefixes may be inherited from the source
            // document. Collect by identity through its namespace-aware walk.
            if index < old.count {
                var breakElements: Set<ObjectIdentifier> = []
                ModernComments.visitSubtree(paragraph, parentNamespaces: bodyNamespaces) { element, ns, local in
                    if ns == MinimalTemplate.nsA {
                        if local == "t" { texts.append(element) }
                        else if local == "br" { breakElements.insert(ObjectIdentifier(element)) }
                        else if local == "endParaRPr", !endParaNames.contains(element.name) {
                            endParaNames.append(element.name)
                        }
                    }
                }
                if !breakElements.isEmpty {
                    var stack = [paragraph]
                    while let element = stack.popLast() {
                        element.children.removeAll { node in
                            if case .element(let child) = node {
                                return breakElements.contains(ObjectIdentifier(child))
                            }
                            return false
                        }
                        stack.append(contentsOf: element.childElements.reversed())
                    }
                }
            }
            if let first = texts.first {
                first.children = [.text(string)]
                for extra in texts.dropFirst() { extra.children = [.text("")] }
            } else {
                paragraph.insertChild(XML.Element("a:r", attributes: [("xmlns:a", MinimalTemplate.nsA)], children: [
                    .element(XML.Element("a:t", children: [.text(string)])),
                ]), beforeAnyOf: endParaNames)
            }
            paragraphs.append(paragraph)
        }
        let oldIDs = Set(old.map(ObjectIdentifier.init))
        var index = 0
        var replacement: [XML.Node] = []
        for node in body.children {
            if case .element(let element) = node, oldIDs.contains(ObjectIdentifier(element)) {
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
        guard !isReply, let root = try? part.dom(),
              let cmNamespaces = ModernComments.namespacesInScope(at: cm, in: root) else { return nil }
        var anchorNode: XML.Element?
        for childNode in cm.children {
            guard case .element(let element) = childNode else { continue }
            let nsMap = ModernComments.applyingNamespaces(of: element, to: cmNamespaces)
            let (prefix, name) = ModernComments.splitQualifiedName(element.name)
            let ns = nsMap[prefix]
            if (ns == ModernComments.nsPC && name == "sldMkLst")
                || (ns == ModernComments.nsAC && (name == "deMkLst" || name == "txMkLst"))
                || (ns == ModernComments.ns && name == "unknownAnchor") {
                anchorNode = element
                break
            }
        }
        guard let node = anchorNode else { return nil }
        var slideID: Int?
        var shapeID: Int?
        var range: (Int, Int)?
        ModernComments.visitSubtree(node, parentNamespaces: cmNamespaces) { element, ns, name in
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
        guard let cmNamespaces = ModernComments.namespacesInScope(at: cm, in: root) else {
            throw RostrumError.packageInvalid("comment has already been deleted")
        }
        var old: [XML.Element] = []
        for childNode in cm.children {
            guard case .element(let element) = childNode else { continue }
            let nsMap = ModernComments.applyingNamespaces(of: element, to: cmNamespaces)
            let (prefix, name) = ModernComments.splitQualifiedName(element.name)
            let ns = nsMap[prefix]
            if (ns == ModernComments.nsPC && name == "sldMkLst")
                || (ns == ModernComments.nsAC && (name == "deMkLst" || name == "txMkLst"))
                || (ns == ModernComments.ns && name == "unknownAnchor") {
                old.append(element)
            }
        }
        for element in old { cm.removeChild(element) }
        cm.children.insert(.element(replacement), at: 0)
        part.markDirty()
    }

    /// Delete this root thread (including its replies), or this reply only.
    public func delete() throws {
        let root = try part.dom()
        guard let resolved = ModernComments.ancestorChainWithLastIndex(to: cm, in: root),
              resolved.chain.count >= 2, resolved.lastChildIndex >= 0 else {
            throw RostrumError.packageInvalid("comment has already been deleted")
        }
        let parent = resolved.chain[resolved.chain.count - 2]
        ModernComments.removeIndexedChild(cm, at: resolved.lastChildIndex, of: parent, in: root)
        part.markDirty()
    }
}
