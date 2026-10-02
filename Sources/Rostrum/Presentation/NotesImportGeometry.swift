import Foundation

/// Bounded notes-master reconciliation: only position/size changes on body and
/// slide-image placeholders. Everything else, including opaque XML and actual
/// dependency payloads, must agree. Text/styles/fills remain inherited intact.
struct NotesImportGeometry {
    private struct Key: Hashable {
        let type: String
        let index: String
    }
    private struct Placeholder {
        let properties: XML.Element
        let scope: [String: String]
    }
    private struct Transform {
        let element: XML.Element
        let scope: [String: String]
    }
    private let transforms: [Key: Transform]

    init(source: Part, destination: Part) throws {
        source.flushIfDirty()
        destination.flushIfDirty()
        let sourceDocument = try XML.parseDocument(source.blob)
        let destinationDocument = try XML.parseDocument(destination.blob)
        let sourceShapes = try Self.placeholders(in: sourceDocument.root, rootName: "notesMaster")
        let destinationShapes = try Self.placeholders(in: destinationDocument.root, rootName: "notesMaster")
        guard Set(sourceShapes.keys) == Set(destinationShapes.keys) else { throw Self.unsupported() }
        var changed: [Key: Transform] = [:]
        for (key, shape) in sourceShapes {
            let other = destinationShapes[key]!
            let geometry = Self.children(shape.properties, named: "xfrm", namespace: MinimalTemplate.nsA, scope: shape.scope)
            let otherGeometry = Self.children(other.properties, named: "xfrm", namespace: MinimalTemplate.nsA, scope: other.scope)
            guard geometry.count <= 1, otherGeometry.count <= 1 else { throw Self.unsupported() }
            if geometry.first?.serialized() == otherGeometry.first?.serialized() { continue }
            guard ["body", "sldImg"].contains(key.type),
                  let transform = geometry.first, let otherTransform = otherGeometry.first,
                  Self.isPositionAndSize(transform, scope: shape.scope),
                  Self.isPositionAndSize(otherTransform, scope: other.scope) else { throw Self.unsupported() }
            changed[key] = Transform(element: transform.deepCopy(), scope: Self.bindings(transform, inherited: shape.scope))
            shape.properties.children.removeAll { if case .element(let node) = $0 { return node === transform }; return false }
            other.properties.children.removeAll { if case .element(let node) = $0 { return node === otherTransform }; return false }
        }
        // Preserve document markup as well as every node outside the removed
        // transforms. A differing extension is never treated as appearance-free.
        guard !changed.isEmpty, XML.document(sourceDocument) == XML.document(destinationDocument) else { throw Self.unsupported() }
        transforms = changed
    }

    /// Work only on a detached copied part. Validate every affected placeholder
    /// before writing any XML, then add complete source transforms in schema order.
    func materialize(in notes: Part) throws {
        let shapes = try Self.placeholders(in: notes.dom(), rootName: "notes")
        var updates: [(Placeholder, Transform)] = []
        for (key, transform) in transforms {
            guard let shape = shapes[key] else {
                throw Self.unsupported("changed master placeholder is absent from the notes page")
            }
            let local = Self.children(shape.properties, named: "xfrm", namespace: MinimalTemplate.nsA, scope: shape.scope)
            guard local.count <= 1 else { throw Self.unsupported() }
            if let local = local.first {
                // Complete existing overrides already retain their source
                // position/size. Partial or unknown transforms could still inherit.
                guard Self.isPositionAndSize(local, scope: shape.scope) else {
                    throw Self.unsupported("partial or extended local placeholder transform")
                }
            } else { updates.append((shape, transform)) }
        }
        for (shape, transform) in updates {
            let copy = transform.element.deepCopy()
            // A master and its notes page can use different namespace aliases.
            // Close over inherited bindings so copied qualified names stay valid.
            for (prefix, namespace) in transform.scope.sorted(by: { $0.key < $1.key })
                where shape.scope[prefix] != namespace {
                copy[attribute: prefix.isEmpty ? "xmlns" : "xmlns:\(prefix)"] = namespace
            }
            shape.properties.insertChild(copy, beforeAnyOf: shape.properties.childElements.map(\.name))
        }
        if !updates.isEmpty { notes.markDirty() }
    }

    private static func placeholders(in root: XML.Element, rootName: String) throws -> [Key: Placeholder] {
        let scope = bindings(root, inherited: [:])
        guard matches(root, rootName, MinimalTemplate.nsP, scope),
              let common = try onlyChild(root, "cSld", MinimalTemplate.nsP, scope) else { throw unsupported() }
        let commonScope = bindings(common, inherited: scope)
        guard let tree = try onlyChild(common, "spTree", MinimalTemplate.nsP, commonScope) else { throw unsupported() }
        let treeScope = bindings(tree, inherited: commonScope)
        // Grouped or compatibility-selected placeholders need their own layout
        // inheritance analysis. Refuse rather than flatten either representation.
        var pending = [(tree, treeScope)]
        while let (element, inherited) = pending.popLast() {
            let current = bindings(element, inherited: inherited)
            guard !matches(element, "grpSp", MinimalTemplate.nsP, current),
                  !matches(element, "AlternateContent", "http://schemas.openxmlformats.org/markup-compatibility/2006", current) else {
                throw unsupported("grouped or compatibility-selected notes placeholders")
            }
            pending.append(contentsOf: element.childElements.map { ($0, current) })
        }
        var result: [Key: Placeholder] = [:]
        for shape in children(tree, named: "sp", namespace: MinimalTemplate.nsP, scope: treeScope) {
            let shapeScope = bindings(shape, inherited: treeScope)
            guard let nonvisual = try onlyChild(shape, "nvSpPr", MinimalTemplate.nsP, shapeScope) else { throw unsupported() }
            let nvScope = bindings(nonvisual, inherited: shapeScope)
            guard let nv = try onlyChild(nonvisual, "nvPr", MinimalTemplate.nsP, nvScope) else { throw unsupported() }
            let nvPropertiesScope = bindings(nv, inherited: nvScope)
            guard let placeholder = try onlyChild(nv, "ph", MinimalTemplate.nsP, nvPropertiesScope) else { continue }
            guard let properties = try onlyChild(shape, "spPr", MinimalTemplate.nsP, shapeScope) else { throw unsupported() }
            let key = Key(type: placeholder[attribute: "type"] ?? "obj", index: placeholder[attribute: "idx"] ?? "0")
            guard result.updateValue(Placeholder(properties: properties, scope: bindings(properties, inherited: shapeScope)), forKey: key) == nil else {
                throw unsupported("ambiguous notes placeholder identity")
            }
        }
        return result
    }

    private static func isPositionAndSize(_ transform: XML.Element, scope: [String: String]) -> Bool {
        let scope = bindings(transform, inherited: scope)
        guard matches(transform, "xfrm", MinimalTemplate.nsA, scope),
              transform.attributes.allSatisfy({ $0.name == "xmlns" || $0.name.hasPrefix("xmlns:") }),
              transform.children.count == 2, transform.childElements.count == 2 else { return false }
        let offset = transform.childElements[0], extent = transform.childElements[1]
        guard matches(offset, "off", MinimalTemplate.nsA, bindings(offset, inherited: scope)),
              matches(extent, "ext", MinimalTemplate.nsA, bindings(extent, inherited: scope)),
              offset.children.isEmpty, extent.children.isEmpty,
              Set(offset.attributes.map(\.name)) == ["x", "y"], offset.attributes.count == 2,
              Set(extent.attributes.map(\.name)) == ["cx", "cy"], extent.attributes.count == 2,
              let x = Int(offset[attribute: "x"] ?? ""), let y = Int(offset[attribute: "y"] ?? ""),
              let width = Int(extent[attribute: "cx"] ?? ""), let height = Int(extent[attribute: "cy"] ?? "") else { return false }
        return Int(Int32.min)...Int(Int32.max) ~= x && Int(Int32.min)...Int(Int32.max) ~= y
            && width > 0 && width <= Int32.max && height > 0 && height <= Int32.max
    }

    private static func onlyChild(_ parent: XML.Element, _ name: String, _ namespace: String, _ scope: [String: String]) throws -> XML.Element? {
        let matches = children(parent, named: name, namespace: namespace, scope: scope)
        guard matches.count <= 1 else { throw unsupported() }
        return matches.first
    }

    private static func children(_ parent: XML.Element, named name: String, namespace: String, scope: [String: String]) -> [XML.Element] {
        parent.childElements.filter { matches($0, name, namespace, bindings($0, inherited: scope)) }
    }

    private static func matches(_ element: XML.Element, _ name: String, _ namespace: String, _ scope: [String: String]) -> Bool {
        let pieces = element.name.split(separator: ":", maxSplits: 1).map(String.init)
        return pieces.last == name && scope[pieces.count == 2 ? pieces[0] : ""] == namespace
    }

    private static func bindings(_ element: XML.Element, inherited: [String: String]) -> [String: String] {
        var scope = inherited
        for attribute in element.attributes {
            if attribute.name == "xmlns" { scope[""] = attribute.value }
            else if attribute.name.hasPrefix("xmlns:") { scope[String(attribute.name.dropFirst(6))] = attribute.value }
        }
        return scope
    }

    private static func unsupported(_ reason: String = "masters differ beyond supported placeholder position/size") -> NotesImportError {
        .incompatibleAppearance(reason)
    }
}
