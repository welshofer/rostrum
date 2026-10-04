import Foundation

/// Namespace-aware inspection shared by standalone and slide style transfers.
/// Persisted XML keeps its original prefixes; only the resolver's detached view
/// normalizes DrawingML names for the existing drawing readers.
enum TableStyleXML {
    static let drawing = "http://schemas.openxmlformats.org/drawingml/2006/main"
    static let relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    static let defaults = ["a": drawing, "r": relationships]

    static func bindings(_ node: XML.Element, inheriting: [String: String]) -> [String: String] {
        var result = inheriting
        for attribute in node.attributes {
            if attribute.name == "xmlns" { result[""] = attribute.value }
            else if attribute.name.hasPrefix("xmlns:") { result[String(attribute.name.dropFirst(6))] = attribute.value }
        }
        return result
    }
    static func expanded(_ name: String, namespaces: [String: String], attribute: Bool = false) -> String {
        let pieces = name.split(separator: ":", maxSplits: 1).map(String.init)
        let prefix = pieces.count == 2 ? pieces[0] : ""
        let namespace = attribute && prefix.isEmpty ? "" : namespaces[prefix] ?? ""
        return "{\(namespace)}\(pieces.last!)"
    }
    static func walk(_ root: XML.Element, namespaces: [String: String] = defaults,
                     _ body: (XML.Element, [String: String]) throws -> Void) rethrows {
        var stack = [(root, namespaces)]
        while let (node, inherited) = stack.popLast() {
            let scope = bindings(node, inheriting: inherited)
            try body(node, scope)
            for child in node.childElements.reversed() { stack.append((child, scope)) }
        }
    }
    static func isDrawing(_ node: XML.Element, _ local: String, namespaces: [String: String]) -> Bool {
        expanded(node.name, namespaces: bindings(node, inheriting: namespaces)) == "{\(drawing)}\(local)"
    }
    static func relationshipAttributes(_ node: XML.Element, namespaces: [String: String]) -> [String] {
        node.attributes.compactMap {
            expanded($0.name, namespaces: namespaces, attribute: true).hasPrefix("{\(relationships)}") ? $0.name : nil
        }
    }
    static func copy(_ definition: XML.Element, from root: XML.Element?) -> XML.Element {
        let clone = definition.deepCopy()
        let scope = bindings(root ?? definition, inheriting: defaults)
        for (prefix, namespace) in scope.sorted(by: { $0.key < $1.key }) {
            let name = prefix.isEmpty ? "xmlns" : "xmlns:\(prefix)"
            if clone[attribute: name] == nil { clone[attribute: name] = namespace }
        }
        // Markup-compatibility and xml:space/lang context is inherited by
        // descendants just like namespace bindings. Keep it with moved XML.
        for attribute in root?.attributes ?? [] {
            let name = expanded(attribute.name, namespaces: scope, attribute: true)
            if name.hasPrefix("{http://schemas.openxmlformats.org/markup-compatibility/2006}")
                || attribute.name == "xml:space" || attribute.name == "xml:lang" {
                if clone[attribute: attribute.name] == nil { clone[attribute: attribute.name] = attribute.value }
            }
        }
        return clone
    }
    static func drawingView(_ definition: XML.Element, root: XML.Element?) -> XML.Element {
        let clone = copy(definition, from: root)
        walk(clone) { node, scope in
            if expanded(node.name, namespaces: scope).hasPrefix("{\(drawing)}") {
                node.name = "a:" + String(node.name.split(separator: ":").last!)
            }
            for name in relationshipAttributes(node, namespaces: scope) where !name.hasPrefix("r:") {
                let value = node[attribute: name]
                node[attribute: name] = nil
                node[attribute: "r:" + String(name.split(separator: ":").last!)] = value
            }
        }
        return clone
    }
    static func definitions(in root: XML.Element) -> [XML.Element] {
        let scope = bindings(root, inheriting: defaults)
        return root.childElements.filter { isDrawing($0, "tblStyle", namespaces: scope) }
    }
}

/// Detached presentation-owned styles. Dependencies are staged by SlideCopier,
/// so missing targets or invalid style references cannot partially edit a deck.
final class TableStyleImport {
    private let source: OPCPackage
    private let destination: OPCPackage
    private let presentation: Part
    private let styles: Part
    private let isNew: Bool
    private var imported: [String: String] = [:]

    init(source: OPCPackage, destination: OPCPackage, presentation: Part,
         allocate: (PackURI) -> PackURI) throws {
        self.source = source; self.destination = destination; self.presentation = presentation
        if let rel = presentation.rels.first(ofType: RelType.tableStyles) {
            guard !rel.isExternal else { throw RostrumError.packageInvalid("table styles must be internal") }
            let existing = try presentation.related(by: RelType.tableStyles, in: destination)
            existing.flushIfDirty()
            styles = Part(uri: existing.uri, contentType: existing.contentType, blob: existing.blob)
            styles.rels.setItems(existing.rels.items)
            isNew = false
        } else {
            styles = Part(uri: allocate(PackURI("/ppt/tableStyles.xml")), contentType: ContentType.tableStyles,
                blob: Data("<a:tblStyleLst xmlns:a=\"\(TableStyleXML.drawing)\"/>".utf8))
            isNew = true
        }
        guard TableStyleXML.isDrawing(try styles.dom(), "tblStyleLst", namespaces: TableStyleXML.defaults) else {
            throw RostrumError.packageInvalid("invalid destination table style list")
        }
    }

    func transfer(_ definition: XML.Element, from owner: Part,
                  copying: (PackURI) throws -> PackURI) throws -> String {
        guard source.parts[owner.uri] === owner else { throw RostrumError.packageInvalid("style source part belongs to another package") }
        let clone = TableStyleXML.copy(definition, from: try owner.dom())
        guard TableStyleXML.isDrawing(clone, "tblStyle", namespaces: TableStyleXML.defaults),
              let sourceID = clone[attribute: "styleId"], !sourceID.isEmpty else {
            throw RostrumError.packageInvalid("table style requires tblStyle/styleId")
        }
        let key = owner.uri.value + "\u{1}" + sourceID.lowercased()
        if let id = imported[key] { return id }
        let root = try styles.dom()
        let definitions = TableStyleXML.definitions(in: root)
        for existing in definitions {
            if try equivalent(clone, owner: owner, to: TableStyleXML.copy(existing, from: root)),
               let id = existing[attribute: "styleId"] {
                imported[key] = id
                return id
            }
        }
        let ids = Set(definitions.compactMap { $0[attribute: "styleId"]?.uppercased() })
        let id = ids.contains(sourceID.uppercased())
            ? SectionGUID.make(name: "tableStyle:" + clone.serialized(), index: 0, avoiding: ids) : sourceID
        clone[attribute: "styleId"] = id
        var relMap: [String: String] = [:]
        try TableStyleXML.walk(clone) { node, scope in
            for name in TableStyleXML.relationshipAttributes(node, namespaces: scope) {
                let oldID = node[attribute: name]!
                if let mapped = relMap[oldID] { node[attribute: name] = mapped; continue }
                guard let rel = owner.rels.relationship(withId: oldID) else {
                    throw RostrumError.packageInvalid("table style relationship \(oldID) is missing")
                }
                let target: String
                if rel.isExternal { target = rel.target }
                else {
                    let uri = PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI)
                    target = styles.uri.relativeReference(to: try copying(uri))
                }
                let mapped = styles.rels.add(type: rel.type, target: target, isExternal: rel.isExternal)
                relMap[oldID] = mapped; node[attribute: name] = mapped
            }
        }
        root.insertChild(clone, beforeAnyOf: root.childElements.filter {
            TableStyleXML.isDrawing($0, "extLst", namespaces: TableStyleXML.bindings(root, inheriting: TableStyleXML.defaults))
        }.map(\.name))
        if root[attribute: "def"] == nil { root[attribute: "def"] = id }
        styles.markDirty(); imported[key] = id
        return id
    }

    /// Compare expanded names and dependency graphs conservatively. Namespace
    /// declarations and opaque XML remain significant when deciding reuse.
    private func equivalent(_ lhs: XML.Element, owner: Part, to rhs: XML.Element) throws -> Bool {
        func signature(_ root: XML.Element) -> (String, [String]) {
            var refs: [String] = []
            func node(_ value: XML.Element, scope inherited: [String: String], isRoot: Bool) -> String {
                let scope = TableStyleXML.bindings(value, inheriting: inherited)
                var result = TableStyleXML.expanded(value.name, namespaces: scope)
                let attributes = value.attributes.filter { !(isRoot && $0.name == "styleId") }
                    .sorted { TableStyleXML.expanded($0.name, namespaces: scope, attribute: true) < TableStyleXML.expanded($1.name, namespaces: scope, attribute: true) }
                for attr in attributes {
                    let name = TableStyleXML.expanded(attr.name, namespaces: scope, attribute: true)
                    let text: String
                    if name.hasPrefix("{\(TableStyleXML.relationships)}") { refs.append(attr.value); text = "REL" }
                    else { text = attr.value }
                    result += "|\(name.utf8.count):\(name)=\(text.utf8.count):\(text)"
                }
                for child in value.children {
                    switch child {
                    case .element(let element): result += "[" + node(element, scope: scope, isRoot: false) + "]"
                    default: result += XML.Element("node", children: [child]).serialized()
                    }
                }
                return result
            }
            return (node(root, scope: TableStyleXML.defaults, isRoot: true), refs)
        }
        let a = signature(lhs), b = signature(rhs)
        guard a.0 == b.0, a.1.count == b.1.count else { return false }
        var visited: Set<String> = []
        func matches(_ left: Part, _ right: Part) throws -> Bool {
            let key = left.uri.value + "\u{1}" + right.uri.value
            guard visited.insert(key).inserted else { return true }
            left.flushIfDirty(); right.flushIfDirty()
            guard left.contentType == right.contentType, left.blob == right.blob, left.rels.items.count == right.rels.items.count else { return false }
            for rel in left.rels.items {
                guard let other = right.rels.relationship(withId: rel.rId), try relationship(rel, left: left, other, right: right) else { return false }
            }
            return true
        }
        func relationship(_ leftRel: Relationship, left: Part, _ rightRel: Relationship, right: Part) throws -> Bool {
            guard leftRel.type == rightRel.type, leftRel.isExternal == rightRel.isExternal else { return false }
            if leftRel.isExternal { return leftRel.target == rightRel.target }
            let leftPart = try source.part(at: PackURI.resolve(target: leftRel.target, relativeTo: left.uri.baseURI))
            // Previously staged dependencies aren't installed yet. Decline reuse
            // conservatively; the per-source map still deduplicates bulk imports.
            guard let rightPart = destination.parts[PackURI.resolve(target: rightRel.target, relativeTo: right.uri.baseURI)] else { return false }
            return try matches(leftPart, rightPart)
        }
        for (leftID, rightID) in zip(a.1, b.1) {
            guard let left = owner.rels.relationship(withId: leftID), let right = styles.rels.relationship(withId: rightID),
                  try relationship(left, left: owner, right, right: styles) else { return false }
        }
        return true
    }

    func commit() {
        guard !imported.isEmpty else { return }
        styles.flushIfDirty()
        let target: Part
        if let existing = destination.parts[styles.uri] {
            if existing.blob != styles.blob { existing.replaceBlob(styles.blob) }
            target = existing
        }
        else { target = destination.addPart(uri: styles.uri, contentType: styles.contentType, blob: styles.blob) }
        target.rels.setItems(styles.rels.items)
        if isNew { presentation.rels.add(type: RelType.tableStyles, target: presentation.uri.relativeReference(to: styles.uri)) }
    }
}
