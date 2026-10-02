import Foundation

/// Detached author relationships share the slide copier's URI map, including
/// backlinks to the merged author list. No destination mutation occurs here.
final class AnnotationDependencies {
    private let source: OPCPackage
    private let original: Part
    private let target: Part
    private let lookup: (PackURI) -> Part?
    private let mapped: (PackURI) -> PackURI?
    private let bind: (PackURI, PackURI) throws -> Void
    private var sourceRelationships: [String: Relationship] = [:]
    private var targetRelationships: [String: Relationship] = [:]
    private var comparisonWork = 0
    private static let maxComparisonWork = 1_000_000
    private var sourceURIs: [PackURI] = []
    private var identities: [PackURI: PackURI] = [:]
    private var relationships: [String: String] = [:]
    private static let maxParts = 4096
    private static let maxEdges = 65536
    private static let maxDepth = 256
    private static let maxXMLNodes = 262144

    init(source: OPCPackage, original: Part, target: Part,
         lookup: @escaping (PackURI) -> Part?, mapped: @escaping (PackURI) -> PackURI?,
         bind: @escaping (PackURI, PackURI) throws -> Void,
         copy: (PackURI) throws -> PackURI, allowSemanticParts: Bool = false) throws {
        self.source = source; self.original = original; self.target = target
        self.lookup = lookup; self.mapped = mapped; self.bind = bind
        try validateGraph(allowSemanticParts: allowSemanticParts)
        try reserveMappedIdentities()
        var targetIDs: Set<String> = []
        for rel in target.rels.items {
            guard !rel.rId.isEmpty, targetIDs.insert(rel.rId).inserted else {
                throw RostrumError.packageInvalid("destination author list has duplicate or empty relationship IDs")
            }
        }
        for rel in original.rels.items {
            var reused: String?
            for candidate in target.rels.items {
                try consumeComparisonWork()
                if let pairs = try equivalent(rel, owner: original, candidate, owner: target) {
                    for (left, right) in pairs.sorted(by: { $0.key.value < $1.key.value }) { try bind(left, right); identities[right] = left }
                    reused = candidate.rId; break
                }
            }
            if let reused { relationships[rel.rId] = reused; continue }
            let destination: String
            if rel.isExternal { destination = rel.target }
            else {
                let uri = PackURI.resolve(target: rel.target, relativeTo: original.uri.baseURI)
                destination = target.uri.relativeReference(to: try copy(uri))
            }
            let id: String
            if target.rels.relationship(withId: rel.rId) == nil {
                target.rels.add(rId: rel.rId, type: rel.type, target: destination, isExternal: rel.isExternal)
                id = rel.rId
            } else { id = target.rels.add(type: rel.type, target: destination, isExternal: rel.isExternal) }
            relationships[rel.rId] = id
            try reserveMappedIdentities()
        }
        for rel in original.rels.items { sourceRelationships[rel.rId] = rel }
        for rel in target.rels.items { targetRelationships[rel.rId] = rel }
    }

    func consumeComparisonWork() throws {
        guard comparisonWork < Self.maxComparisonWork else {
            throw RostrumError.packageInvalid("annotation comparison exceeds its operation-wide work budget")
        }
        comparisonWork += 1
    }

    private func reserveMappedIdentities() throws {
        for sourceURI in sourceURIs {
            guard let destination = mapped(sourceURI) else { continue }
            guard identities[destination] == nil || identities[destination] == sourceURI else {
                throw RostrumError.packageInvalid("annotation graph has conflicting shared-part identities")
            }
            identities[destination] = sourceURI
        }
    }

    private func validateGraph(allowSemanticParts: Bool) throws {
        var pending = [(original.uri, 0)]
        var visited: Set<PackURI> = []
        var edges = 0, nodes = 0
        while let (uri, depth) = pending.popLast() {
            guard !visited.contains(uri) else { continue }
            guard depth <= Self.maxDepth, visited.count < Self.maxParts else {
                throw RostrumError.packageInvalid("annotation dependency graph exceeds its part/depth budget")
            }
            visited.insert(uri)
            sourceURIs.append(uri)
            let part = try source.part(at: uri)
            let semanticParts: Set<String> = [ContentType.presentationMain, ContentType.presentationTemplateMain,
                ContentType.slideShowMain, ContentType.slide, ContentType.slideLayout, ContentType.slideMaster,
                ContentType.notesSlide, ContentType.notesMaster, ContentType.presProps, ContentType.viewProps,
                ContentType.tableStyles, ModernComments.commentsContentType, LegacyComments.contentType]
            guard allowSemanticParts || !semanticParts.contains(part.contentType) else {
                throw RostrumError.packageInvalid("annotation dependency needs presentation/slide context; semantic part graphs are unsupported")
            }
            var ids: Set<String> = []
            for rel in part.rels.items {
                guard !rel.rId.isEmpty, ids.insert(rel.rId).inserted else {
                    throw RostrumError.packageInvalid("annotation dependency has duplicate or empty relationship IDs")
                }
                guard edges < Self.maxEdges else { throw RostrumError.packageInvalid("annotation dependency graph exceeds its relationship budget") }
                edges += 1
            }
            if part.contentType.lowercased().contains("xml") || part.uri.ext.lowercased() == "xml" {
                try AnnotationXML.walk(part.dom()) { element, scope in
                    guard nodes < Self.maxXMLNodes else { throw RostrumError.packageInvalid("annotation dependency graph exceeds its XML budget") }
                    let work = element.attributes.count + element.children.count + 1
                    guard work <= Self.maxXMLNodes - nodes else { throw RostrumError.packageInvalid("annotation dependency graph exceeds its XML budget") }
                    nodes += work
                    for name in AnnotationXML.relationshipAttributes(element, scope: scope) {
                        guard let id = element[attribute: name], ids.contains(id) else {
                            throw RostrumError.packageInvalid("annotation XML refers to a missing relationship")
                        }
                    }
                }
            }
            for rel in part.rels.items.reversed() where !rel.isExternal {
                pending.append((PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI), depth + 1))
            }
        }
    }

    /// Full payload and graph equivalence, with a bijection so shared nodes and
    /// distinct equal-byte nodes cannot accidentally be identified with each other.
    private func equivalent(_ leftRel: Relationship, owner left: Part,
                            _ rightRel: Relationship, owner right: Part) throws -> [PackURI: PackURI]? {
        try consumeComparisonWork()
        guard leftRel.type == rightRel.type, leftRel.isExternal == rightRel.isExternal else { return nil }
        if leftRel.isExternal { return leftRel.target == rightRel.target ? [:] : nil }
        var pending = [(PackURI.resolve(target: leftRel.target, relativeTo: left.uri.baseURI),
                        PackURI.resolve(target: rightRel.target, relativeTo: right.uri.baseURI))]
        var pairs: [PackURI: PackURI] = [:], inverse: [PackURI: PackURI] = [:]
        while let (sourceURI, destURI) = pending.popLast() {
            try consumeComparisonWork()
            if let existing = pairs[sourceURI] { if existing != destURI { return nil }; continue }
            if let existing = inverse[destURI], existing != sourceURI { return nil }
            if let existing = mapped(sourceURI), existing != destURI { return nil }
            if let existing = identities[destURI], existing != sourceURI { return nil }
            guard pairs.count < Self.maxParts else { throw RostrumError.packageInvalid("annotation comparison exceeds its part budget") }
            pairs[sourceURI] = destURI; inverse[destURI] = sourceURI
            if sourceURI == original.uri { guard destURI == target.uri else { return nil }; continue }
            let a = try source.part(at: sourceURI)
            guard let b = lookup(destURI) else { return nil }
            a.flushIfDirty(); b.flushIfDirty()
            guard a.contentType == b.contentType, a.blob == b.blob, a.rels.items.count == b.rels.items.count else { return nil }
            var rightByID: [String: Relationship] = [:]
            for rel in b.rels.items {
                try consumeComparisonWork()
                guard rightByID[rel.rId] == nil else { return nil }
                rightByID[rel.rId] = rel
            }
            for rel in a.rels.items {
                try consumeComparisonWork()
                guard let other = rightByID[rel.rId], rel.type == other.type, rel.isExternal == other.isExternal else { return nil }
                if rel.isExternal { if rel.target != other.target { return nil } }
                else {
                    pending.append((PackURI.resolve(target: rel.target, relativeTo: a.uri.baseURI),
                                    PackURI.resolve(target: other.target, relativeTo: b.uri.baseURI)))
                }
            }
        }
        return pairs
    }

    func equivalentRecord(_ sourceRecord: XML.Element, to record: XML.Element,
                          ignoring attributes: Set<String>) throws -> Bool {
        let a = try AnnotationXML.signature(sourceRecord, ignoring: attributes, consume: consumeComparisonWork)
        let b = try AnnotationXML.signature(record, ignoring: attributes, consume: consumeComparisonWork)
        guard a.text == b.text, a.references.count == b.references.count else { return false }
        var pairs: [PackURI: PackURI] = [:], inverse: [PackURI: PackURI] = [:]
        for (leftID, rightID) in zip(a.references, b.references) {
            guard let left = sourceRelationships[leftID],
                  let right = targetRelationships[rightID],
                  let matched = try equivalent(left, owner: original, right, owner: target) else { return false }
            for (left, right) in matched {
                if let existing = pairs[left], existing != right { return false }
                if let existing = inverse[right], existing != left { return false }
                pairs[left] = right; inverse[right] = left
            }
        }
        return true
    }

    func remap(_ root: XML.Element) throws {
        try AnnotationXML.walk(root) { node, scope in
            for name in AnnotationXML.relationshipAttributes(node, scope: scope) {
                guard let old = node[attribute: name], let id = relationships[old] else {
                    throw RostrumError.packageInvalid("author extension relationship cannot be resolved")
                }
                node[attribute: name] = id
            }
        }
    }
}

/// All namespace inspection is operation-local; original XML names are retained.
enum AnnotationXML {
    private static let relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private static let compatibility = "http://schemas.openxmlformats.org/markup-compatibility/2006"
    private static let defaults = ["": "", "xml": "http://www.w3.org/XML/1998/namespace"]

    static func bindings(_ root: XML.Element, inheriting: [String: String] = defaults) -> [String: String] {
        var scope = inheriting
        for attribute in root.attributes {
            if attribute.name == "xmlns" { scope[""] = attribute.value }
            else if attribute.name.hasPrefix("xmlns:") { scope[String(attribute.name.dropFirst(6))] = attribute.value }
        }
        return scope
    }
    private static func expanded(_ name: String, scope: [String: String], attribute: Bool = false) -> String {
        if name == "xmlns" { return "{http://www.w3.org/2000/xmlns/}xmlns" }
        if name.hasPrefix("xmlns:") { return "{http://www.w3.org/2000/xmlns/}" + String(name.dropFirst(6)) }
        let pieces = name.split(separator: ":", omittingEmptySubsequences: false)
        let prefix = pieces.count == 2 ? String(pieces[0]) : ""
        let namespace = attribute && prefix.isEmpty ? "" : scope[prefix] ?? ""
        return "{\(namespace)}" + String(pieces.last ?? "")
    }
    static func relationshipAttributes(_ element: XML.Element, scope: [String: String]) -> [String] {
        element.attributes.compactMap { expanded($0.name, scope: scope, attribute: true).hasPrefix("{\(relationships)}") ? $0.name : nil }
    }
    static func walk(_ root: XML.Element, _ body: (XML.Element, [String: String]) throws -> Void) rethrows {
        var pending = [(root, defaults)]
        while let (node, inherited) = pending.popLast() {
            let scope = bindings(node, inheriting: inherited)
            try body(node, scope)
            for child in node.childElements.reversed() { pending.append((child, scope)) }
        }
    }
    static func copy(_ node: XML.Element, from root: XML.Element) throws -> XML.Element {
        let clone = node.deepCopy()
        let scope = bindings(root)
        for (prefix, uri) in scope.sorted(by: { $0.key < $1.key }) where prefix != "xml" {
            let name = prefix.isEmpty ? "xmlns" : "xmlns:" + prefix
            if clone[attribute: name] == nil { clone[attribute: name] = uri }
        }
        for attribute in root.attributes {
            let name = expanded(attribute.name, scope: scope, attribute: true)
            if name.hasPrefix("{\(compatibility)}") {
                let prefix = String(attribute.name.split(separator: ":").first ?? "")
                guard bindings(clone)[prefix] == compatibility else {
                    throw RostrumError.packageInvalid("author extension rebinds inherited compatibility attributes")
                }
                for token in attribute.value.split(whereSeparator: \.isWhitespace) {
                    let prefix = String(token.split(separator: ":").first ?? "")
                    guard scope[prefix] == bindings(clone)[prefix] else {
                        throw RostrumError.packageInvalid("author extension rebinds inherited compatibility tokens")
                    }
                }
                let local = clone.attributes.first { expanded($0.name, scope: bindings(clone), attribute: true) == name }
                guard local == nil || local?.value == attribute.value else {
                    throw RostrumError.packageInvalid("author extension overrides inherited compatibility policy")
                }
                if local == nil { clone[attribute: attribute.name] = attribute.value }
            } else if attribute.name == "xml:space" || attribute.name == "xml:lang" {
                if clone[attribute: attribute.name] == nil { clone[attribute: attribute.name] = attribute.value }
            }
        }
        if clone[attribute: "xml:lang"] == nil { clone[attribute: "xml:lang"] = "" }
        if clone[attribute: "xml:space"] == nil { clone[attribute: "xml:space"] = "default" }
        return clone
    }

    static func mergeMetadata(from source: XML.Element, records sourceRecords: [XML.Element],
                              into destination: XML.Element, records destRecords: [XML.Element],
                              dependencies: AnnotationDependencies, isNew: Bool) throws {
        let sourceChildren = Set(source.childElements.map(ObjectIdentifier.init))
        let destChildren = Set(destination.childElements.map(ObjectIdentifier.init))
        let sourceRecordIDs = Set(sourceRecords.map(ObjectIdentifier.init))
        let destRecordIDs = Set(destRecords.map(ObjectIdentifier.init))
        guard sourceRecordIDs.isSubset(of: sourceChildren), destRecordIDs.isSubset(of: destChildren) else {
            throw RostrumError.packageInvalid("nested author definitions cannot be merged safely")
        }
        if isNew { try dependencies.remap(destination); return }
        let sourceScope = bindings(source), destScope = bindings(destination)
        func metadata(_ root: XML.Element, _ scope: [String: String]) -> [String: String] {
            var result: [String: String] = [:]
            for attr in root.attributes where attr.name != "xmlns" && !attr.name.hasPrefix("xmlns:") {
                let name = expanded(attr.name, scope: scope, attribute: true)
                if !name.hasPrefix("{\(compatibility)}"), attr.name != "xml:lang", attr.name != "xml:space" { result[name] = attr.value }
            }
            return result
        }
        guard metadata(source, sourceScope) == metadata(destination, destScope) else {
            throw RostrumError.packageInvalid("conflicting opaque author-list attributes cannot be merged safely")
        }
        for attr in destination.attributes where expanded(attr.name, scope: destScope, attribute: true).hasPrefix("{\(compatibility)}") {
            let counterpart = source.attributes.first { expanded($0.name, scope: sourceScope, attribute: true) == expanded(attr.name, scope: destScope, attribute: true) }
            guard counterpart?.value == attr.value else {
                throw RostrumError.packageInvalid("destination author-list compatibility context conflicts")
            }
            for token in attr.value.split(whereSeparator: \.isWhitespace) {
                let prefix = String(token.split(separator: ":").first ?? "")
                guard sourceScope[prefix] == destScope[prefix] else { throw RostrumError.packageInvalid("author-list compatibility bindings conflict") }
            }
        }
        for child in source.children {
            if case .element(let node) = child {
                if sourceRecordIDs.contains(ObjectIdentifier(node)) { continue }
                let clone = try copy(node, from: source)
                let candidates = try destination.childElements.filter { candidate in
                    try dependencies.consumeComparisonWork()
                    return !destRecordIDs.contains(ObjectIdentifier(candidate)) && expanded(candidate.name, scope: bindings(candidate, inheriting: destScope)) == expanded(node.name, scope: bindings(node, inheriting: sourceScope))
                }
                var equivalent = false
                for candidate in candidates {
                    if try dependencies.equivalentRecord(clone, to: copy(candidate, from: destination), ignoring: []) { equivalent = true; break }
                }
                if equivalent { continue }
                guard candidates.isEmpty else { throw RostrumError.packageInvalid("conflicting opaque author-list elements cannot be merged safely") }
                try dependencies.remap(clone); destination.appendElement(clone)
            } else {
                if case .text(let text) = child, text.allSatisfy(\.isWhitespace) { continue }
                let bytes = XML.Element("node", children: [child]).serialized()
                if !destination.children.contains(where: { XML.Element("node", children: [$0]).serialized() == bytes }) { destination.children.append(child) }
            }
        }
    }
    static func signature(_ root: XML.Element, ignoring attributes: Set<String>, consume: () throws -> Void = {}) throws -> (text: String, references: [String]) {
        enum Event { case node(XML.Node, [String: String], Bool), end }
        var pending = [Event.node(.element(root), defaults, true)]
        var result = "", refs: [String] = [], nodes = 0
        func token(_ value: String) { result += "\(value.utf8.count):" + value }
        func opaqueValue(_ value: String, scope: [String: String]) {
            token(value)
            // QName/prefix-valued opaque fields retain their binding identity.
            // Unused extra declarations do not prevent repeated import reuse.
            for word in value.split(whereSeparator: \.isWhitespace) {
                let prefix = String(word.split(separator: ":").first ?? "")
                token(scope[prefix] ?? "UNBOUND")
                token(scope[""] ?? "")
            }
        }
        while let event = pending.popLast() {
            switch event {
            case .end: result += "E"
            case .node(let node, let inherited, let isRoot):
                guard nodes < 262144 else { throw RostrumError.packageInvalid("author definition exceeds its XML budget") }
                nodes += 1
                try consume()
                if case .element(let element) = node {
                    let scope = bindings(element, inheriting: inherited)
                    result += "S"; token(expanded(element.name, scope: scope))
                    for attribute in element.attributes.sorted(by: { expanded($0.name, scope: scope, attribute: true) < expanded($1.name, scope: scope, attribute: true) }) where !(isRoot && attributes.contains(attribute.name)) && attribute.name != "xmlns" && !attribute.name.hasPrefix("xmlns:") {
                        try consume()
                        result += "A"; token(expanded(attribute.name, scope: scope, attribute: true))
                        if expanded(attribute.name, scope: scope, attribute: true).hasPrefix("{\(relationships)}") {
                            refs.append(attribute.value); token("REL")
                        } else { opaqueValue(attribute.value, scope: scope) }
                    }
                    pending.append(.end)
                    for child in element.children.reversed() { pending.append(.node(child, scope, false)) }
                } else { result += "N"; opaqueValue(XML.Element("node", children: [node]).serialized(), scope: inherited) }
            }
        }
        return (result, refs)
    }
}
