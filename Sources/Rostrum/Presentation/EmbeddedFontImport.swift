import Foundation

/// Presentation-owned font declarations are outside the slide relationship graph.
/// Keep their XML context when moving them, including extension relationships.
enum EmbeddedFontXML {
    static let presentation = "http://schemas.openxmlformats.org/presentationml/2006/main"
    static let relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    static let defaults = ["p": presentation, "r": relationships, "": "", "xml": "http://www.w3.org/XML/1998/namespace"]
    static let variants = ["regular", "bold", "italic", "boldItalic"]

    static func scope(_ node: XML.Element, _ inherited: [String: String] = defaults) -> [String: String] {
        var result = inherited
        for attribute in node.attributes {
            if attribute.name == "xmlns" { result[""] = attribute.value }
            else if attribute.name.hasPrefix("xmlns:") { result[String(attribute.name.dropFirst(6))] = attribute.value }
        }
        return result
    }

    static func expanded(_ name: String, _ scope: [String: String], attribute: Bool = false) -> String {
        let pieces = name.split(separator: ":", maxSplits: 1).map(String.init)
        let prefix = pieces.count == 2 ? pieces[0] : ""
        let namespace = attribute && prefix.isEmpty ? "" : scope[prefix] ?? ""
        return "{\(namespace)}\(pieces.last ?? "")"
    }

    static func children(_ node: XML.Element, _ local: String,
                         inheriting: [String: String] = defaults) -> [XML.Element] {
        node.childElements.filter { expanded($0.name, scope($0, scope(node, inheriting))) == "{\(presentation)}\(local)" }
    }

    static func detached(_ node: XML.Element, from parent: XML.Element) throws -> XML.Element {
        let clone = node.deepCopy()
        let inherited = scope(parent)
        for (prefix, namespace) in inherited.sorted(by: { $0.key < $1.key }) where prefix != "xml" {
            let name = prefix.isEmpty ? "xmlns" : "xmlns:\(prefix)"
            if clone[attribute: name] == nil { clone[attribute: name] = namespace }
        }
        let compatibility = "http://schemas.openxmlformats.org/markup-compatibility/2006"
        for attribute in parent.attributes {
            let name = expanded(attribute.name, inherited, attribute: true)
            if name.hasPrefix("{\(compatibility)}") {
                let bindings = scope(clone)
                guard expanded(attribute.name, bindings, attribute: true) == name else {
                    throw RostrumError.packageInvalid("embedded font rebinds inherited compatibility attributes")
                }
                for token in attribute.value.split(whereSeparator: \.isWhitespace) {
                    let prefix = String(token.split(separator: ":").first ?? "")
                    guard inherited[prefix] == bindings[prefix] else {
                        throw RostrumError.packageInvalid("embedded font rebinds inherited compatibility tokens")
                    }
                }
                let local = clone.attributes.first { expanded($0.name, bindings, attribute: true) == name }
                guard local == nil || local?.value == attribute.value else {
                    throw RostrumError.packageInvalid("embedded font overrides inherited compatibility policy")
                }
                if local == nil { clone[attribute: attribute.name] = attribute.value }
            } else if attribute.name == "xml:lang" || attribute.name == "xml:space" {
                if clone[attribute: attribute.name] == nil { clone[attribute: attribute.name] = attribute.value }
            }
        }
        return clone
    }

    static func references(_ root: XML.Element) -> [(XML.Element, String)] {
        var result: [(XML.Element, String)] = []
        var stack = [(root, defaults)]
        while let (node, inherited) = stack.popLast() {
            let bindings = scope(node, inherited)
            for attribute in node.attributes.sorted(by: { expanded($0.name, bindings, attribute: true) < expanded($1.name, bindings, attribute: true) }) where expanded(attribute.name, bindings, attribute: true).hasPrefix("{\(relationships)}") {
                result.append((node, attribute.name))
            }
            for child in node.childElements.reversed() { stack.append((child, bindings)) }
        }
        return result
    }
}

/// All edits and dependency copies are detached until SlideCopier commits.
/// Different bytes for the same family/style cannot coexist unambiguously in
/// PowerPoint, so refuse those imports instead of changing either slide's font.
final class EmbeddedFontImport {
    private struct Origin {
        let node: XML.Element
        let owner: Part
        let package: OPCPackage
    }
    private struct Family {
        let node: XML.Element
        let metadata: Origin
        var faces: [String: Origin]
    }
    private let presentation: Part
    private let root: XML.Element
    private let existingList: XML.Element?
    private let list: XML.Element
    private var pending: [(XML.Element, String, Relationship, String)] = []
    private var changed = false

    init(source: OPCPackage, destination: OPCPackage, presentation: Part,
         copying: (PackURI) throws -> PackURI) throws {
        self.presentation = presentation
        root = try presentation.dom()
        let owner = try source.mainDocumentPart()
        let sourceRoot = try owner.dom()
        let lists = EmbeddedFontXML.children(sourceRoot, "embeddedFontLst")
        let destinationLists = EmbeddedFontXML.children(root, "embeddedFontLst")
        guard lists.count <= 1, destinationLists.count <= 1 else {
            throw RostrumError.packageInvalid("ambiguous embedded font lists")
        }
        existingList = destinationLists.first
        guard let original = lists.first else {
            list = XML.Element("p:embeddedFontLst")
            return
        }
        let incoming = try EmbeddedFontXML.detached(original, from: sourceRoot)
        if let existingList { list = try EmbeddedFontXML.detached(existingList, from: root) }
        else { list = incoming.deepCopy() }
        func metadata(_ node: XML.Element, excluding names: [String]) -> XML.Element {
            let copy = node.deepCopy()
            let excluded = Set(names.flatMap { EmbeddedFontXML.children(copy, $0) }.map(ObjectIdentifier.init))
            copy.children.removeAll { child in
                if case .element(let element) = child { return excluded.contains(ObjectIdentifier(element)) }
                return false
            }
            return copy
        }
        let sourceContext = Origin(node: metadata(incoming, excluding: ["embeddedFont"]), owner: owner, package: source)
        if existingList != nil {
            let targetContext = Origin(node: metadata(list, excluding: ["embeddedFont"]), owner: presentation, package: destination)
            guard try equivalent(sourceContext, targetContext) else {
                throw RostrumError.packageInvalid("embedded font list metadata conflicts")
            }
        } else {
            list.children = metadata(list, excluding: ["embeddedFont"]).children
            try stageReferences(in: list, owner: owner, copying: copying)
            changed = true
        }
        func describe(_ node: XML.Element, owner: Part, package: OPCPackage) throws -> (String, Family) {
            let declarations = EmbeddedFontXML.children(node, "font")
            guard declarations.count == 1, let name = declarations[0][attribute: "typeface"], !name.isEmpty else {
                throw RostrumError.packageInvalid("embedded font requires one typeface declaration")
            }
            var faces: [String: Origin] = [:]
            for variant in EmbeddedFontXML.variants {
                let nodes = EmbeddedFontXML.children(node, variant)
                guard nodes.count <= 1 else { throw RostrumError.packageInvalid("ambiguous embedded font face: \(name) \(variant)") }
                guard let face = nodes.first else { continue }
                let clone = try EmbeddedFontXML.detached(face, from: node)
                let refs = EmbeddedFontXML.references(clone).filter {
                    $0.0 === clone && EmbeddedFontXML.expanded($0.1, EmbeddedFontXML.scope(clone), attribute: true) == "{\(EmbeddedFontXML.relationships)}id"
                }
                guard refs.count == 1, let id = clone[attribute: refs[0].1],
                      let rel = owner.rels.relationship(withId: id), rel.type == RelType.font, !rel.isExternal else {
                    throw RostrumError.packageInvalid("embedded font face requires an internal font relationship: \(name) \(variant)")
                }
                let part = try package.part(at: PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI))
                guard part.contentType == "application/x-fontdata" else {
                    throw RostrumError.packageInvalid("embedded font relationship targets a non-font part: \(name) \(variant)")
                }
                faces[variant] = Origin(node: clone, owner: owner, package: package)
            }
            let meta = metadata(node, excluding: EmbeddedFontXML.variants)
            EmbeddedFontXML.children(meta, "font").first?[attribute: "typeface"] = name.lowercased()
            return (name.lowercased(), Family(node: node, metadata: Origin(node: meta, owner: owner, package: package), faces: faces))
        }
        var families: [String: Family] = [:]
        for node in EmbeddedFontXML.children(list, "embeddedFont") {
            let (key, family) = try describe(EmbeddedFontXML.detached(node, from: list), owner: presentation, package: destination)
            guard families[key] == nil else { throw RostrumError.packageInvalid("ambiguous destination embedded family: \(key)") }
            // Keep the attached node as the edit target; metadata/faces retain context.
            families[key] = Family(node: node, metadata: family.metadata, faces: family.faces)
        }
        let positions = Dictionary(uniqueKeysWithValues: incoming.children.enumerated().compactMap { index, child -> (ObjectIdentifier, Int)? in
            if case .element(let node) = child { return (ObjectIdentifier(node), index) }
            return nil
        })
        var processed = 0, inserted = 0
        for node in EmbeddedFontXML.children(incoming, "embeddedFont") {
            defer { processed += 1 }
            let clone = try EmbeddedFontXML.detached(node, from: incoming)
            let (key, family) = try describe(clone, owner: owner, package: source)
            if var existing = families[key] {
                guard try equivalent(family.metadata, existing.metadata) else {
                    throw RostrumError.packageInvalid("embedded font metadata conflicts: \(key)")
                }
                for variant in EmbeddedFontXML.variants {
                    guard let face = family.faces[variant] else { continue }
                    if let other = existing.faces[variant] {
                        guard try equivalent(face, other) else {
                            throw RostrumError.packageInvalid("embedded font face conflicts: \(key) \(variant)")
                        }
                    } else {
                        let added = face.node.deepCopy()
                        try stageReferences(in: added, owner: owner, copying: copying)
                        let later = Array(EmbeddedFontXML.variants.drop(while: { $0 != variant }).dropFirst())
                        let before = later.flatMap { EmbeddedFontXML.children(existing.node, $0) }.map(\.name)
                        existing.node.insertChild(added, beforeAnyOf: before)
                        existing.faces[variant] = face
                        changed = true
                    }
                }
                families[key] = existing
            } else {
                // Keep an unmodified origin for comparisons against duplicate
                // source declarations; only the output clone gets fresh rIds.
                let output = clone.deepCopy()
                try stageReferences(in: output, owner: owner, copying: copying)
                if existingList == nil, let position = positions[ObjectIdentifier(node)] {
                    // Preserve interleaved opaque nodes, comments and whitespace
                    // when copying a new list. Only duplicate font records vanish.
                    list.children.insert(.element(output), at: position - processed + inserted)
                    inserted += 1
                } else { list.appendElement(output) }
                families[key] = Family(node: output, metadata: family.metadata, faces: family.faces)
                changed = true
            }
        }
    }

    private func stageReferences(in node: XML.Element, owner: Part, copying: (PackURI) throws -> PackURI) throws {
        for (element, attribute) in EmbeddedFontXML.references(node) {
            guard let id = element[attribute: attribute], let rel = owner.rels.relationship(withId: id) else {
                throw RostrumError.packageInvalid("embedded font relationship is missing")
            }
            let target = try rel.isExternal ? rel.target : presentation.uri.relativeReference(to: copying(
                PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI)))
            pending.append((element, attribute, rel, target))
        }
    }

    private func equivalent(_ lhs: Origin, _ rhs: Origin) throws -> Bool {
        func signature(_ element: XML.Element, inherited: [String: String] = EmbeddedFontXML.defaults) -> String {
            let scope = EmbeddedFontXML.scope(element, inherited)
            let elementName = EmbeddedFontXML.expanded(element.name, scope)
            var fields = [elementName]
            // Opaque XML can contain QName-valued strings. Without its schema,
            // different namespace contexts are not safely interchangeable.
            let structuralNames = ["embeddedFontLst", "embeddedFont", "font"] + EmbeddedFontXML.variants
            let isStructure = structuralNames.contains { elementName == "{\(EmbeddedFontXML.presentation)}\($0)" }
            let knownAttributes: Set<String> = elementName == "{\(EmbeddedFontXML.presentation)}font"
                ? ["typeface", "panose", "pitchFamily", "charset"] : []
            let hasOpaqueContext = !isStructure || element.attributes.contains {
                $0.name != "xmlns" && !$0.name.hasPrefix("xmlns:") && !knownAttributes.contains($0.name)
                    && !EmbeddedFontXML.expanded($0.name, scope, attribute: true).hasPrefix("{\(EmbeddedFontXML.relationships)}")
            }
            if hasOpaqueContext {
                for key in scope.keys.sorted() { fields += [key, scope[key]!] }
            }
            for attr in element.attributes.filter({ $0.name != "xmlns" && !$0.name.hasPrefix("xmlns:") })
                .sorted(by: { EmbeddedFontXML.expanded($0.name, scope, attribute: true) < EmbeddedFontXML.expanded($1.name, scope, attribute: true) }) {
                let name = EmbeddedFontXML.expanded(attr.name, scope, attribute: true)
                fields += [name, name.hasPrefix("{\(EmbeddedFontXML.relationships)}") ? "REL" : attr.value]
            }
            for child in element.children {
                // PresentationML font containers have element-only content.
                // Formatting whitespace is insignificant for reuse; the actual
                // stored XML (including whitespace in opaque nodes) is retained.
                if isStructure, case .text(let text) = child, text.allSatisfy(\.isWhitespace) { continue }
                if case .element(let node) = child { fields.append(signature(node, inherited: scope)) }
                else { fields.append(XML.Element("node", children: [child]).serialized()) }
            }
            return fields.map { "\($0.utf8.count):\($0)" }.joined()
        }
        guard signature(lhs.node) == signature(rhs.node) else { return false }
        var visited: Set<String> = []
        func relationship(_ left: Relationship, _ leftOwner: Part, _ right: Relationship, _ rightOwner: Part) throws -> Bool {
            guard left.type == right.type, left.isExternal == right.isExternal else { return false }
            if left.isExternal { return left.target == right.target }
            let a = try lhs.package.part(at: PackURI.resolve(target: left.target, relativeTo: leftOwner.uri.baseURI))
            let b = try rhs.package.part(at: PackURI.resolve(target: right.target, relativeTo: rightOwner.uri.baseURI))
            let key = a.uri.value + "\u{1}" + b.uri.value
            guard visited.insert(key).inserted else { return true }
            a.flushIfDirty(); b.flushIfDirty()
            guard a.contentType == b.contentType, a.blob == b.blob, a.rels.items.count == b.rels.items.count else { return false }
            for rel in a.rels.items {
                guard let other = b.rels.relationship(withId: rel.rId), try relationship(rel, a, other, b) else { return false }
            }
            return true
        }
        let left = EmbeddedFontXML.references(lhs.node), right = EmbeddedFontXML.references(rhs.node)
        guard left.count == right.count else { return false }
        for (a, b) in zip(left, right) {
            guard let aid = a.0[attribute: a.1], let bid = b.0[attribute: b.1],
                  let ar = lhs.owner.rels.relationship(withId: aid), let br = rhs.owner.rels.relationship(withId: bid),
                  try relationship(ar, lhs.owner, br, rhs.owner) else { return false }
        }
        return true
    }

    func commit() {
        guard changed else { return }
        var ids: [String: String] = [:]
        for (node, attribute, relationship, target) in pending {
            let key = relationship.rId
            let id = ids[key] ?? presentation.rels.add(type: relationship.type, target: target, isExternal: relationship.isExternal)
            ids[key] = id
            node[attribute: attribute] = id
        }
        if let existingList { existingList.attributes = list.attributes; existingList.children = list.children }
        else {
            root.insertChild(list, beforeAnyOf: ["p:custShowLst", "p:photoAlbum", "p:custDataLst", "p:kinsoku", "p:defaultTextStyle", "p:modifyVerifier", "p:extLst"])
        }
        root[attribute: "embedTrueTypeFonts"] = "1"
        presentation.markDirty()
    }
}
