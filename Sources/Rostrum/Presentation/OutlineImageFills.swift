import Foundation

/// Selected fill resources, not a package-wide media scan or pixel visibility
/// analysis. All state belongs to one outline operation; no source DOM changes.
struct OutlineImageFills {
    struct Image { let part: Part; let altText: String? }
    private struct Node {
        let xml: XML.Element
        let scope: [String: String]
        init(_ xml: XML.Element, scope: [String: String]) {
            self.xml = xml; self.scope = TableStyleXML.bindings(xml, inheriting: scope)
        }
        var name: String { TableStyleXML.expanded(xml.name, namespaces: scope) }
        func child(_ local: String, namespace: String = TableStyleXML.drawing) -> Node? {
            children.first { $0.name == "{\(namespace)}\(local)" }
        }
        var children: [Node] { xml.childElements.map { Node($0, scope: scope) } }
        func relationship(_ local: String) -> String? {
            xml.attributes.first { TableStyleXML.expanded($0.name, namespaces: scope, attribute: true)
                == "{\(TableStyleXML.relationships)}\(local)" }?.value
        }
    }
    private static let presentation = "http://schemas.openxmlformats.org/presentationml/2006/main"
    private let slide: Slide
    private let theme: Theme
    private let chain: [Part]
    private var images: [Image] = []
    private var warnings: [String] = []
    private var warned: Set<String> = []
    private var seenReferences: Set<String> = []
    private var seenImages: Set<String> = []

    init(slide: Slide) { self.slide = slide; theme = slide.resolvedTheme; chain = slide.inheritanceParts }

    mutating func collect() -> (images: [Image], warnings: [String]) {
        // Follow the same nearest-background selection without losing URI
        // identity or ancestor bindings when PresentationML uses another prefix.
        for owner in chain {
            guard let root = try? owner.dom(), let background = node(root, owner: owner)
                .child("cSld", namespace: Self.presentation)?.child("bg", namespace: Self.presentation) else { continue }
            if let properties = background.child("bgPr", namespace: Self.presentation) {
                if let solid = properties.child("solidFill") {
                    let context = XML.Element("context", attributes: solid.scope.map {
                        ($0.key.isEmpty ? "xmlns" : "xmlns:" + $0.key, $0.value)
                    })
                    let canonical = TableStyleXML.drawingView(solid.xml, root: context)
                    if BackgroundResolver.colour(in: canonical, theme: theme) == nil { continue }
                }
                if let selected = properties.child("blipFill") {
                    image(selected, owner: owner, path: "background", alt: nil)
                }
            } else if let reference = background.child("bgRef", namespace: Self.presentation),
                      let index = reference.xml.boundedInt("idx", in: 1...Int(UInt32.max)), index != 1000,
                      let selected = themeFill(reference), selected.name == "{\(TableStyleXML.drawing)}blipFill" {
                image(selected, owner: theme.part, path: "background", alt: nil)
            }
            // Explicit noFill, invalid references and unknown backgrounds stop
            // inheritance just as the existing background resolver does.
            break
        }
        walkShapes(owner: slide.part, inherited: false)
        if chain.count > 1 { walkShapes(owner: chain[1], inherited: true) }
        let showsMaster = chain.prefix(2).allSatisfy {
            !["0", "false"].contains((try? $0.dom())?[attribute: "showMasterSp"] ?? "1")
        }
        if chain.count > 2 && showsMaster { walkShapes(owner: chain[2], inherited: true) }
        return (images, warnings)
    }
    private func node(_ xml: XML.Element, owner: Part) -> Node {
        let defaults = TableStyleXML.defaults.merging(["p": Self.presentation]) { _, new in new }
        let scope = (try? owner.dom()).map { TableStyleXML.bindings($0, inheriting: defaults) } ?? defaults
        return Node(xml, scope: scope)
    }
    private func fill(in properties: Node?) -> Node? {
        properties?.children.first { n in
            ["solidFill", "gradFill", "blipFill", "pattFill", "grpFill", "noFill"].contains { n.name == "{\(TableStyleXML.drawing)}\($0)" }
        }
    }
    /// Shared inventory-only theme lookup. Retains ancestor bindings and the
    /// original selected node; callers resolve relationships through theme.part.
    static func themeSelection(index: Int, theme: Theme) -> (element: XML.Element, namespaces: [String: String])? {
        guard index > 0, let root = try? theme.part.dom() else { return nil }
        let scheme = Node(root, scope: TableStyleXML.defaults).child("themeElements")?.child("fmtScheme")
        guard let list = scheme?.child(index >= 1001 ? "bgFillStyleLst" : "fillStyleLst") else { return nil }
        let entries = list.xml.childElements
        let offset = index >= 1001 ? index - 1001 : index - 1
        guard entries.indices.contains(offset) else { return nil }
        return (entries[offset], list.scope)
    }
    private func themeFill(_ reference: Node?) -> Node? {
        guard let index = reference?.xml[attribute: "idx"].flatMap(Int.init),
              let selected = Self.themeSelection(index: index, theme: theme) else { return nil }
        return Node(selected.element, scope: selected.namespaces)
    }
    private mutating func walkShapes(owner: Part, inherited: Bool) {
        guard let root = try? owner.dom(), let tree = node(root, owner: owner)
            .child("cSld", namespace: Self.presentation)?.child("spTree", namespace: Self.presentation) else { return }
        walk(tree, owner: owner, inherited: inherited, groupFill: nil, path: "shapes", depth: 0)
    }
    private mutating func walk(_ container: Node, owner: Part, inherited: Bool,
                               groupFill: (Node, Part)?, path: String, depth: Int) {
        guard depth < 64 else { warn(owner, path, "shape nesting exceeds 64 levels"); return }
        for (index, shape) in container.children.enumerated() {
            let location = "\(path)/\(shape.xml.name)[\(index + 1)]"
            guard !hidden(shape) else { continue }
            if inherited && placeholder(shape) != nil { continue }
            let alt = shape.children.first?.child("cNvPr", namespace: Self.presentation)?.xml[attribute: "descr"]
            if shape.name == "{\(Self.presentation)}grpSp" {
                // An unused group fill is not an attachment. It is selected
                // only by an explicit descendant grpFill reference.
                let own = fill(in: shape.child("grpSpPr", namespace: Self.presentation))
                let selected: (Node, Part)? = own.map { ($0, owner) } ?? groupFill
                let resolved = own?.name == "{\(TableStyleXML.drawing)}grpFill" ? groupFill : selected
                walk(shape, owner: owner, inherited: inherited, groupFill: resolved, path: location, depth: depth + 1)
            } else if shape.name == "{\(Self.presentation)}graphicFrame",
                      let tableNode = shape.child("graphic")?.child("graphicData")?.child("tbl") {
                // The core grid reader is lexical. Normalize a detached view
                // only for aliased structural DrawingML; ordinary grids share DOM.
                let aliased = tableNode.xml.name != "a:tbl" || tableNode.children.contains { child in
                    ["tblPr", "tblGrid", "tr"].contains { child.name == "{\(TableStyleXML.drawing)}\($0)" && child.xml.name != "a:" + $0 }
                        || child.children.contains { node in
                            ["tc", "gridCol"].contains { node.name == "{\(TableStyleXML.drawing)}\($0)" && node.xml.name != "a:" + $0 }
                        }
                }
                let context = XML.Element("context", attributes: tableNode.scope.sorted { $0.key < $1.key }.map {
                    ($0.key.isEmpty ? "xmlns" : "xmlns:" + $0.key, $0.value)
                })
                let view = aliased ? TableStyleXML.drawingView(tableNode.xml, root: context) : tableNode.xml
                let table = Table(tbl: view, part: owner, graphicFrame: shape.xml, package: slide.package)
                let resolver = TableStyleResolver(table: table, theme: theme)
                if let direct = fill(in: tableNode.child("tblPr")) {
                    if direct.name == "{\(TableStyleXML.drawing)}blipFill" {
                        image(direct, owner: owner, path: location + "/tableBackground", alt: alt)
                    }
                } else if let background = resolver.definition?.firstChild(named: "a:tblBg") {
                    let styleOwner = resolver.stylePart ?? owner
                    let selected: Node?
                    let selectedOwner: Part
                    if let direct = background.firstChild(named: "a:fill")?.childElements.first {
                        selected = node(direct, owner: styleOwner); selectedOwner = styleOwner
                    } else {
                        selected = themeFill(background.firstChild(named: "a:fillRef").map { node($0, owner: styleOwner) })
                        selectedOwner = theme.part
                    }
                    if let selected, selected.name == "{\(TableStyleXML.drawing)}blipFill" {
                        image(selected, owner: selectedOwner, path: location + "/tableBackground", alt: alt)
                    }
                }
                var session = TableStyleResolver.ImageFillSession(resolver, namespaces: tableNode.scope)
                let topology = try? resolver.grid.topology()
                for (r, row) in resolver.grid.cells.enumerated() {
                    for c in row.indices where c < resolver.grid.columns.count {
                        if let region = topology?.region(row: r, column: c), region.row != r || region.column != c { continue }
                        let selected = session.selected(row: r, column: c)
                        if let element = selected.fill {
                            let selectedNode = selected.namespaces.map { Node(element, scope: $0) } ?? node(element, owner: selected.owner)
                            if selectedNode.name == "{\(TableStyleXML.drawing)}blipFill" {
                                image(selectedNode, owner: selected.owner, path: location + "/cell[\(r + 1),\(c + 1)]", alt: alt)
                            }
                        }
                    }
                }
            } else if ["sp", "pic", "cxnSp"].contains(where: { shape.name == "{\(Self.presentation)}\($0)" }) {
                var selected = fill(in: shape.child("spPr", namespace: Self.presentation))
                var selectedOwner = owner
                if selected == nil, let themed = themeFill(shape.child("style", namespace: Self.presentation)?.child("fillRef")) {
                    selected = themed; selectedOwner = theme.part
                }
                if selected == nil && !inherited {
                    if let inheritedFill = placeholderFill(shape) { selected = inheritedFill.0; selectedOwner = inheritedFill.1 }
                }
                if selected?.name == "{\(TableStyleXML.drawing)}grpFill" {
                    selected = groupFill?.0
                    if let groupFill { selectedOwner = groupFill.1 }
                }
                if let selected, selected.name == "{\(TableStyleXML.drawing)}blipFill" {
                    image(selected, owner: selectedOwner, path: location + "/fill", alt: alt)
                }
                if shape.name == "{\(Self.presentation)}pic",
                   !Picture(element: shape.xml, part: owner, package: slide.package).isMedia {
                    if let blip = shape.child("blipFill", namespace: Self.presentation) {
                        image(blip, owner: owner, path: location + "/picture", alt: alt)
                    } else { warn(owner, location + "/picture", "picture has no image fill") }
                }
            }
        }
    }
    private func nonvisual(_ shape: Node) -> Node? {
        let pairs = [("sp", "nvSpPr"), ("pic", "nvPicPr"), ("cxnSp", "nvCxnSpPr"),
                     ("grpSp", "nvGrpSpPr"), ("graphicFrame", "nvGraphicFramePr")]
        guard let pair = pairs.first(where: { shape.name == "{\(Self.presentation)}" + $0.0 }) else { return nil }
        return shape.child(pair.1, namespace: Self.presentation)
    }
    private func hidden(_ shape: Node) -> Bool {
        let value = nonvisual(shape)?.child("cNvPr", namespace: Self.presentation)?.xml[attribute: "hidden"]
        return value == "1" || value == "true"
    }
    private func placeholder(_ shape: Node) -> XML.Element? {
        nonvisual(shape)?.child("nvPr", namespace: Self.presentation)?.child("ph", namespace: Self.presentation)?.xml
    }
    private func placeholderFill(_ shape: Node) -> (Node, Part)? {
        guard let ph = placeholder(shape) else { return nil }
        guard chain.count > 1 else { return nil }
        let idx = ph[attribute: "idx"] ?? "0"
        func shapes(_ owner: Part) -> [Node] {
            guard let root = try? owner.dom() else { return [] }
            return node(root, owner: owner).child("cSld", namespace: Self.presentation)?
                .child("spTree", namespace: Self.presentation)?.children ?? []
        }
        guard let layoutShape = shapes(chain[1]).first(where: {
            placeholder($0).map { ($0[attribute: "idx"] ?? "0") == idx } ?? false
        }) else { return nil }
        var candidates: [(Node, Part)] = [(layoutShape, chain[1])]
        if chain.count > 2 {
            let kind = placeholder(layoutShape)?[attribute: "type"] ?? "obj"
            let reduced = Slide.masterTypeReduction[kind] ?? "body"
            if let master = shapes(chain[2]).first(where: {
                placeholder($0).map { ($0[attribute: "type"] ?? "obj") == reduced } ?? false
            }) { candidates.append((master, chain[2])) }
        }
        for (candidate, owner) in candidates {
            if let own = fill(in: candidate.child("spPr", namespace: Self.presentation)) { return (own, owner) }
            if let themed = themeFill(candidate.child("style", namespace: Self.presentation)?.child("fillRef")) { return (themed, theme.part) }
        }
        return nil
    }
    private mutating func image(_ fill: Node, owner: Part, path: String, alt: String?) {
        guard let blip = fill.child("blip") else { warn(owner, path, "image fill has no blip"); return }
        guard let id = blip.relationship("embed"), !id.isEmpty else {
            warn(owner, path, blip.relationship("link") == nil ? "image fill has no embedded relationship" : "external image link was not fetched"); return
        }
        guard seenReferences.insert(owner.uri.value + "\u{0}" + id).inserted else { return }
        guard let relationship = owner.rels.relationship(withId: id) else { warn(owner, path, "image relationship \(id) is missing"); return }
        guard !relationship.isExternal else { warn(owner, path, "external image relationship \(id) was not fetched"); return }
        guard relationship.type == RelType.image, !relationship.target.isEmpty else { warn(owner, path, "image relationship \(id) is malformed"); return }
        guard let part = try? slide.package.part(at: PackURI.resolve(target: relationship.target, relativeTo: owner.uri.baseURI)),
              part.contentType.hasPrefix("image/") else { warn(owner, path, "image relationship \(id) has no image part"); return }
        guard seenImages.insert(part.uri.value).inserted else { return }
        images.append(Image(part: part, altText: alt.flatMap { $0.isEmpty ? nil : $0 }))
    }
    private mutating func warn(_ owner: Part, _ path: String, _ reason: String) {
        let message = "\(owner.uri.value) \(path): \(reason)"
        if warned.insert(message).inserted { warnings.append(message) }
    }
}
