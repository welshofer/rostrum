import Foundation

/// A slide layout.
public final class SlideLayout {
    public let part: Part
    let package: OPCPackage

    init(part: Part, package: OPCPackage) {
        self.part = part
        self.package = package
    }

    /// "Title Slide", "Blank", … (from `p:cSld@name`).
    public var name: String {
        (try? part.dom())?.firstChild(named: "p:cSld")?[attribute: "name"] ?? ""
    }

    /// The `p:sldLayout@type` token: "title", "obj", "secHead", "blank", …
    public var type: String? {
        (try? part.dom())?[attribute: "type"]
    }
}

extension Presentation {
    /// The first master's layouts, in `sldLayoutIdLst` order.
    public var layouts: [SlideLayout] {
        guard let master = try? presentationPart.related(by: RelType.slideMaster, in: package),
              let dom = try? master.dom(),
              let list = dom.firstChild(named: "p:sldLayoutIdLst") else { return [] }
        return list.childElements.compactMap { entry in
            guard let rId = entry[attribute: "r:id"],
                  let rel = master.rels.relationship(withId: rId),
                  let part = try? package.part(at: PackURI.resolve(target: rel.target, relativeTo: master.uri.baseURI))
            else { return nil }
            return SlideLayout(part: part, package: package)
        }
    }

    /// First layout with the given `p:sldLayout@type` token
    /// ("title", "obj", "secHead", "blank").
    public func layout(type: String) -> SlideLayout? {
        layouts.first { $0.type == type }
    }

    public func layout(named name: String) -> SlideLayout? {
        layouts.first { $0.name == name }
    }
}

extension Slides {
    /// Add a slide based on `layout`, cloning its placeholders.
    ///
    /// Cloning is synthesis, not copying (python-pptx semantics): each layout
    /// placeholder — except the latent date/footer/slide-number types — yields
    /// a fresh minimal `p:sp` carrying only the `p:ph` binding (type/idx/
    /// orient/sz), an empty `p:spPr` (geometry inherits), and an empty text
    /// body for text-bearing types. Copying layout geometry or prompt text
    /// would break inheritance.
    @discardableResult
    public func add(layout: SlideLayout) throws -> Slide {
        try add(layout: layout, cloningPlaceholders: true)
    }

    /// As `add(layout:)`, but a caller that authors its own placeholder shapes
    /// (the slide builders do, because they place and size them deliberately)
    /// passes `false` so it does not also get an empty cloned set.
    @discardableResult
    func add(layout: SlideLayout, cloningPlaceholders: Bool) throws -> Slide {
        let slide = try add()
        // Retarget the layout relationship from the default to the chosen one.
        if let rel = slide.part.rels.first(ofType: RelType.slideLayout) {
            slide.part.rels.remove(rId: rel.rId)
        }
        slide.part.rels.add(
            type: RelType.slideLayout,
            target: slide.part.uri.relativeReference(to: layout.part.uri))

        if cloningPlaceholders { try Placeholders.clone(from: layout.part, to: slide.part) }
        return slide
    }
}

enum Placeholders {
    /// Layout ph types never cloned onto slides.
    static let latentTypes: Set<String> = ["dt", "ftr", "sldNum"]
    /// Types whose clone carries an empty text body.
    static let textTypes: Set<String> = ["title", "ctrTitle", "subTitle", "body", "obj"]

    static let basenames: [String: String] = [
        "title": "Title", "ctrTitle": "Title", "subTitle": "Subtitle",
        "body": "Text Placeholder", "obj": "Content Placeholder",
        "chart": "Chart Placeholder", "tbl": "Table Placeholder",
        "pic": "Picture Placeholder", "clipArt": "ClipArt Placeholder",
        "media": "Media Placeholder", "dgm": "SmartArt Placeholder",
        "dt": "Date Placeholder", "ftr": "Footer Placeholder",
        "sldNum": "Slide Number Placeholder", "hdr": "Header Placeholder",
    ]

    static func clone(from layoutPart: Part, to slidePart: Part) throws {
        let layoutTree = try Slide.spTree(of: layoutPart)
        let slideTree = try Slide.spTree(of: slidePart)

        for sp in layoutTree.children(named: "p:sp") {
            guard let ph = phElement(of: sp) else { continue }
            let type = ph[attribute: "type"] ?? "obj"
            if latentTypes.contains(type) { continue }

            let id = try Slide.nextShapeID(of: slidePart)
            let basename = basenames[type] ?? "Placeholder"

            let clone = XML.Element("p:sp")
            let nvSpPr = XML.Element("p:nvSpPr")
            nvSpPr.appendElement(XML.Element("p:cNvPr", attributes: [
                ("id", String(id)), ("name", "\(basename) \(id - 1)"),
            ]))
            let cNvSpPr = XML.Element("p:cNvSpPr")
            cNvSpPr.appendElement(XML.Element("a:spLocks", attributes: [("noGrp", "1")]))
            nvSpPr.appendElement(cNvSpPr)
            let nvPr = XML.Element("p:nvPr")
            // Copy the ph binding attributes exactly as present (our templates
            // only carry non-default attributes, matching write-omission).
            nvPr.appendElement(XML.Element("p:ph", attributes: ph.attributes))
            nvSpPr.appendElement(nvPr)
            clone.appendElement(nvSpPr)
            clone.appendElement(XML.Element("p:spPr"))
            if textTypes.contains(type) {
                let txBody = XML.Element("p:txBody")
                txBody.appendElement(XML.Element("a:bodyPr"))
                txBody.appendElement(XML.Element("a:lstStyle"))
                txBody.appendElement(XML.Element("a:p"))
                clone.appendElement(txBody)
            }
            slideTree.appendElement(clone)
        }
        slidePart.markDirty()
    }

    /// The `p:ph` binding, read through whichever non-visual container this
    /// element kind uses — `p:nvSpPr`, `p:nvPicPr`, `p:nvGraphicFramePr`,
    /// `p:nvCxnSpPr` or `p:nvGrpSpPr`, always the first child. A picture or a
    /// table dropped into a content placeholder is a placeholder too.
    static func phElement(of sp: XML.Element) -> XML.Element? {
        sp.childElements.first?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")
    }
}

extension Shape {
    /// The placeholder binding, if this shape is a placeholder.
    /// Absent attributes resolve to their schema defaults (type "obj", idx 0).
    public var placeholder: (type: String, idx: Int)? {
        guard let ph = Placeholders.phElement(of: element) else { return nil }
        return (ph[attribute: "type"] ?? "obj", ph[attribute: "idx"].flatMap { Int($0) } ?? 0)
    }

    /// Declare what this shape is *for*, binding it to the layout placeholder
    /// of that type.
    ///
    /// A shape that carries its own geometry and formatting still renders
    /// exactly as before — the binding adds meaning, not appearance. What it
    /// buys is that the slide now says "this is the title" in the schema's own
    /// vocabulary, which is the only thing a layout, a theme, PowerPoint's
    /// Designer or `applyTemplate` can match on. A deck built entirely from
    /// unbound text boxes is un-restylable by anything, including PowerPoint.
    ///
    /// `idx` identifies which of the layout's placeholders is meant and is
    /// omitted for `title`/`ctrTitle`, which are always index 0.
    public func bindPlaceholder(type: String, idx: Int? = nil) {
        guard let nvContainer = element.childElements.first else { return }

        let nvPr: XML.Element
        if let existing = nvContainer.firstChild(named: "p:nvPr") {
            nvPr = existing
        } else {
            nvPr = XML.Element("p:nvPr")
            nvContainer.appendElement(nvPr)
        }
        if let stale = nvPr.firstChild(named: "p:ph") { nvPr.removeChild(stale) }

        var attributes: [(String, String)] = []
        if type != "obj" { attributes.append(("type", type)) }
        if let idx, idx != 0 { attributes.append(("idx", String(idx))) }
        // p:ph leads CT_ApplicationNonVisualDrawingProps.
        nvPr.insertChild(
            XML.Element("p:ph", attributes: attributes),
            beforeAnyOf: ["a:audioCd", "a:wavAudioFile", "a:audioFile", "a:videoFile",
                          "a:quickTimeFile", "p:custDataLst", "p:extLst"])

        // Placeholders are not text boxes and cannot be ungrouped — this is the
        // shape PowerPoint itself writes.
        if let cNvSpPr = nvContainer.firstChild(named: "p:cNvSpPr") {
            cNvSpPr[attribute: "txBox"] = nil
            if cNvSpPr.firstChild(named: "a:spLocks") == nil {
                cNvSpPr.insertChild(
                    XML.Element("a:spLocks", attributes: [("noGrp", "1")]),
                    beforeAnyOf: ["a:extLst"])
            }
        }
        part.markDirty()
    }
}

extension Slide {
    /// The slide's placeholder shapes, in document order.
    public var placeholders: [Shape] {
        shapes.all.filter { $0.placeholder != nil }
    }

    /// The title placeholder: first placeholder with idx 0, whether its type
    /// is `title` or `ctrTitle`.
    public var title: Shape? {
        placeholders.first { $0.placeholder?.idx == 0 }
    }

    public func placeholder(idx: Int) -> Shape? {
        placeholders.first { $0.placeholder?.idx == idx }
    }

    /// A shape's effective frame after placeholder inheritance:
    /// its own transform when present, else the layout's matching placeholder
    /// (by idx), else the master's (by reduced type). Returns nil for an
    /// orphan placeholder with no geometry anywhere in the chain.
    public func effectiveFrame(of shape: Shape) -> Rect? {
        if let own = explicitFrame(of: shape.element) { return own }
        guard let ph = shape.placeholder else { return nil }

        guard let layoutRel = part.rels.first(ofType: RelType.slideLayout),
              let layoutPart = try? package.part(
                at: PackURI.resolve(target: layoutRel.target, relativeTo: part.uri.baseURI))
        else { return nil }

        // Slide → layout: match on idx only.
        if let layoutSp = try? placeholderSp(in: layoutPart, matching: { lph in
            (lph[attribute: "idx"].flatMap { Int($0) } ?? 0) == ph.idx
        }) {
            if let frame = explicitFrame(of: layoutSp) { return frame }
            // Layout → master: match on reduced type.
            let layoutType = Placeholders.phElement(of: layoutSp)?[attribute: "type"] ?? "obj"
            let masterType = Self.masterTypeReduction[layoutType] ?? "body"
            if let masterRel = layoutPart.rels.first(ofType: RelType.slideMaster),
               let masterPart = try? package.part(
                at: PackURI.resolve(target: masterRel.target, relativeTo: layoutPart.uri.baseURI)),
               let masterSp = try? placeholderSp(in: masterPart, matching: { mph in
                   (mph[attribute: "type"] ?? "obj") == masterType
               }) {
                return explicitFrame(of: masterSp)
            }
        }
        return nil
    }

    static let masterTypeReduction: [String: String] = [
        "body": "body", "chart": "body", "clipArt": "body", "dgm": "body",
        "media": "body", "obj": "body", "pic": "body", "subTitle": "body", "tbl": "body",
        "ctrTitle": "title", "title": "title",
        "dt": "dt", "ftr": "ftr", "sldNum": "sldNum",
    ]

    /// Scans every shape-tree child, not just `p:sp`: layouts and masters put
    /// placeholders on pictures and graphic frames too.
    private func placeholderSp(
        in phPart: Part, matching predicate: (XML.Element) -> Bool
    ) throws -> XML.Element? {
        guard let tree = Slide.existingSpTree(of: phPart) else { return nil }
        for element in tree.childElements {
            // The tree's own properties are not shapes.
            switch element.name {
            case "p:nvGrpSpPr", "p:grpSpPr", "p:extLst": continue
            default: break
            }
            guard let ph = Placeholders.phElement(of: element), predicate(ph) else { continue }
            return element
        }
        return nil
    }

    /// The transform written on an element, through the same per-kind
    /// dispatch `Shape.explicitFrame` uses — so a chart, table or group
    /// reports the geometry it actually carries instead of nil.
    private func explicitFrame(of sp: XML.Element) -> Rect? {
        ShapeTransform.rect(ShapeTransform.element(of: sp))
    }
}

