import Foundation

/// A template slot, identified by its placeholder index rather than its name
/// (names are localized and are not unique across masters).
public struct TemplatePlaceholder {
    public let index: Int
    public let type: String
    public let name: String
    public let frame: Rect?
    public var isTitle: Bool { type == "title" || type == "ctrTitle" }
    public var isFurniture: Bool { ["dt", "ftr", "sldNum", "hdr"].contains(type) }
}

public extension SlideLayout {
    /// Fixed layout/master artwork used to bound new text flow. Placeholder
    /// geometry is available separately so callers can distinguish content slots.
    var artworkFrames: [Rect] {
        ([part] + [master?.part].compactMap { $0 }).flatMap { source in
            ShapeCollection(part: source, package: package).all.compactMap {
                $0.placeholder == nil ? $0.explicitFrame : nil
            }
        }
    }

    var placeholders: [TemplatePlaceholder] {
        ShapeCollection(part: part, package: package).all.compactMap { shape in
            guard let ph = shape.placeholder else { return nil }
            let inherited = master.flatMap { master in
                ShapeCollection(part: master.part, package: package).all.first {
                    $0.placeholder?.type == (Slide.masterTypeReduction[ph.type] ?? "body")
                }?.explicitFrame
            }
            return TemplatePlaceholder(index: ph.idx, type: ph.type, name: shape.name,
                                       frame: shape.explicitFrame ?? inherited)
        }
    }

    /// Effective paragraph/body defaults, merged property by property. The
    /// returned XML is detached; inspecting or editing it cannot alter a template.
    func textDefaults(for index: Int, level: Int = 0) -> (paragraph: XML.Element, body: XML.Element) {
        let levelName = "a:lvl\(min(8, max(0, level)) + 1)pPr"
        let shape = ShapeCollection(part: part, package: package).all.first { $0.placeholder?.idx == index }
        let type = shape?.placeholder?.type ?? "body"
        let reduced = Slide.masterTypeReduction[type] ?? "body"
        let masterShape = master.flatMap { master in
            ShapeCollection(part: master.part, package: package).all.first { $0.placeholder?.type == reduced }
        }
        let bucket = reduced == "title" ? "p:titleStyle" : (reduced == "body" ? "p:bodyStyle" : "p:otherStyle")
        let paragraph = XML.Element("a:pPr")
        let body = XML.Element("a:bodyPr")
        func merge(_ source: XML.Element?, into target: XML.Element) {
            guard let source else { return }
            for attribute in source.attributes { target[attribute: attribute.name] = attribute.value }
            for child in source.childElements {
                if child.name == "a:defRPr", let old = target.firstChild(named: child.name) {
                    merge(child, into: old)
                } else {
                    // Autofit and bullet alternatives are mutually exclusive.
                    if ["a:noAutofit", "a:normAutofit", "a:spAutoFit"].contains(child.name) {
                        for n in ["a:noAutofit", "a:normAutofit", "a:spAutoFit"] { target.removeChildren(named: n) }
                    }
                    if ["a:buNone", "a:buChar", "a:buAutoNum", "a:buBlip"].contains(child.name) {
                        for n in ["a:buNone", "a:buChar", "a:buAutoNum", "a:buBlip"] { target.removeChildren(named: n) }
                    }
                    target.removeChildren(named: child.name)
                    target.appendElement(child.deepCopy())
                }
            }
        }
        merge((try? package.mainDocumentPart().dom())?.firstChild(named: "p:defaultTextStyle")?.firstChild(named: levelName), into: paragraph)
        merge((try? master?.part.dom())?.firstChild(named: "p:txStyles")?.firstChild(named: bucket)?.firstChild(named: levelName), into: paragraph)
        for element in [masterShape?.element, shape?.element] {
            let tx = element?.firstChild(named: "p:txBody")
            merge(tx?.firstChild(named: "a:bodyPr"), into: body)
            merge(tx?.firstChild(named: "a:lstStyle")?.firstChild(named: "a:defPPr"), into: paragraph)
            merge(tx?.firstChild(named: "a:lstStyle")?.firstChild(named: levelName), into: paragraph)
        }
        return (paragraph, body)
    }
}

public extension Presentation {
    /// Start a new deck from a POTX. All masters, layouts, themes and their
    /// assets remain in the package. Starter slides and their exclusively-owned
    /// parts are removed; opening/saving a template normally remains lossless.
    static func fromTemplate(data: Data) throws -> Presentation {
        let deck = try Presentation(data: data)
        guard deck.documentKind == .template else {
            throw RostrumError.packageInvalid("Choose a PowerPoint .potx template.")
        }
        guard !deck.slideMasters.isEmpty, !deck.allLayouts.isEmpty else {
            throw RostrumError.packageInvalid("The template has no usable masters or layouts.")
        }
        let originalSlides = Set(deck.slides.map { $0.part.uri })
        var sourceClosure = Set<PackURI>(), sourcePending = Array(originalSlides)
        while let uri = sourcePending.popLast() {
            guard sourceClosure.insert(uri).inserted, let part = deck.package.parts[uri] else { continue }
            sourcePending += part.rels.items.filter { !$0.isExternal }.map { PackURI.resolve(target: $0.target, relativeTo: uri.baseURI) }
        }
        let independentRoots = Set(deck.package.parts.keys).subtracting(sourceClosure)
        // Remove slide-based navigation belonging to the starter document.
        let dom = try deck.presentationPart.dom()
        dom.removeChildren(named: "p:custShowLst")
        if let ext = dom.firstChild(named: "p:extLst") {
            for item in ext.childElements where item[attribute: "uri"] == SectionExt.uri { ext.removeChild(item) }
        }
        while deck.slides.count > 0 { try deck.slides.remove(at: deck.slides.count - 1) }
        deck.documentKind = .presentation
        deck.presentationPart.markDirty()

        // Retain every part reachable from the package root, including parts
        // Rostrum doesn't model. Never follow external relationships.
        var seen = Set<PackURI>()
        var pending = deck.package.rels.items.filter { !$0.isExternal }.map {
            PackURI.resolve(target: $0.target, relativeTo: "/")
        }
        pending += independentRoots.filter { deck.package.parts[$0] != nil }
        while let uri = pending.popLast() {
            guard seen.insert(uri).inserted else { continue }
            guard let part = deck.package.parts[uri] else {
                throw RostrumError.packageInvalid("Template relationship targets missing part \(uri).")
            }
            for rel in part.rels.items where !rel.isExternal {
                let target = PackURI.resolve(target: rel.target, relativeTo: uri.baseURI)
                if originalSlides.contains(target) {
                    throw RostrumError.packageInvalid("Template artwork links to a starter slide; remove that link before using this template for a new deck.")
                }
                pending.append(target)
            }
        }
        for uri in Array(deck.package.parts.keys) where !seen.contains(uri) { deck.package.removePart(at: uri) }
        return deck
    }

    /// Verify that every slide carries its complete layout/master/theme chain.
    /// Missing dependencies are an export failure, not a preview warning.
    func validateTemplateBindings() throws {
        for slide in slides {
            guard let layout = slide.layout, let master = layout.master, master.theme != nil,
                  slideMasters.contains(where: { $0.part.uri == master.part.uri }),
                  master.layouts.contains(where: { $0.part.uri == layout.part.uri }) else {
                throw RostrumError.packageInvalid("Slide \(slide.part.uri) has an incomplete layout/master/theme chain.")
            }
        }
    }
}

public extension Slide {
    /// Fill a template text slot without flattening its inherited typography.
    /// The caller supplies paragraph levels; bullet and font choices remain in
    /// the layout/master. No geometry or formatting overrides are written.
    func fillPlaceholder(index: Int, paragraphs: [(text: String, level: Int)]) throws {
        guard let shape = placeholder(idx: index), let text = shape.textFrame else {
            throw RostrumError.packageInvalid("No text placeholder at index \(index).")
        }
        text.clear()
        for item in paragraphs {
            let p = text.addParagraph()
            p.indentLevel = min(8, max(0, item.level))
            p.addRun(item.text)
        }
        if paragraphs.isEmpty { _ = text.addParagraph() }
    }

    /// Replace a template's content placeholder with a native chart, table or
    /// picture. Retains its placeholder index so PowerPoint recognizes the
    /// layout association (including Reset/reapply layout).
    func replacePlaceholder(index: Int, with replacement: Shape) throws {
        guard replacement.part === part, let old = placeholder(idx: index),
              let ph = old.element.childElements.first?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph"),
              let nv = replacement.element.childElements.first?.firstChild(named: "p:nvPr") else {
            throw RostrumError.packageInvalid("Cannot replace placeholder \(index).")
        }
        nv.removeChildren(named: "p:ph")
        nv.appendElement(ph.deepCopy())
        try spTree().removeChild(old.element)
        part.markDirty()
    }
}

public extension Slide {
    /// Replace the selected slide's visual contents using a slide built in this
    /// same package. Keep the destination URI/slide ID, notes and incoming links;
    /// callers may then remove the temporary source slide from the collection.
    func replaceVisualContents(with source: Slide) throws {
        guard package === source.package, part !== source.part,
              part.uri.baseURI == source.part.uri.baseURI else {
            throw RostrumError.packageInvalid("Replacement must be a different slide in the same package directory.")
        }
        let oldRoot = try part.dom()
        let oldExtensions = oldRoot.firstChild(named: "p:extLst")?.deepCopy()
        var extensionIDs = Set<String>()
        func collectIDs(_ node: XML.Element) {
            for attribute in node.attributes where attribute.name.hasPrefix("r:") { extensionIDs.insert(attribute.value) }
            for child in node.childElements { collectIDs(child) }
        }
        if let oldExtensions { collectIDs(oldExtensions) }
        let preserved = part.rels.items.filter {
            $0.type == RelType.notesSlide || $0.type == ModernComments.commentsRelType
                || $0.type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"
                || extensionIDs.contains($0.rId)
        }
        let root = try source.part.dom().deepCopy()
        for attribute in oldRoot.attributes where attribute.name.hasPrefix("xmlns:") && root[attribute: attribute.name] == nil {
            root[attribute: attribute.name] = attribute.value
        }
        if let oldExtensions { root.removeChildren(named: "p:extLst"); root.appendElement(oldExtensions) }
        part.replaceBlob(XML.document(root))
        part.rels.setItems(source.part.rels.items.filter { $0.type != RelType.notesSlide && $0.type != ModernComments.commentsRelType })
        var remapped: [String: String] = [:]
        for rel in preserved {
            remapped[rel.rId] = part.rels.add(type: rel.type, target: rel.target, isExternal: rel.isExternal)
        }
        func remap(_ node: XML.Element) {
            for attribute in node.attributes where attribute.name.hasPrefix("r:") {
                if let id = remapped[attribute.value] { node[attribute: attribute.name] = id }
            }
            for child in node.childElements { remap(child) }
        }
        if let ext = try part.dom().firstChild(named: "p:extLst") { remap(ext); part.markDirty() }
    }
}
