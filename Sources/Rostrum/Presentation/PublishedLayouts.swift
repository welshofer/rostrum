import Foundation

public extension Presentation {
    /// Compile the selected design's shared typography/background into the
    /// native master. Palette and font scheme are written by applyDesign.
    func compileThemeMaster() throws {
        guard let master = slideMasters.first else { return }
        let s = style
        let dom = try master.part.dom()
        let common = try Slide.cSld(of: master.part)
        common[attribute: "name"] = appliedDesign?.name ?? "Lectern Theme"
        let bg = common.getOrAddChild("p:bg", beforeAnyOf: ["p:spTree"])
        let properties = XML.Element("p:bgPr")
        properties.appendElement(s.background.srgbElement().wrapped(in: "a:solidFill"))
        properties.appendElement(XML.Element("a:effectLst"))
        bg.replaceChildElements(with: [properties])
        let styles = dom.getOrAddChild("p:txStyles", beforeAnyOf: ["p:extLst"])
        for (bucket, role) in [("p:titleStyle", TypeRole.title), ("p:bodyStyle", .body), ("p:otherStyle", .caption)] {
            let target = styles.getOrAddChild(bucket)
            target.children = []
            for level in 1...9 {
                let paragraph = XML.Element("a:p")
                let p = Paragraph(p: paragraph, part: master.part)
                p.addRun(""); p.apply(s.type(role))
                if role == .body { p.setBullet(); p.setIndentation(left: .points(20 * Double(level)), hanging: .points(15)) }
                else { p.setNoBullet() }
                let source = paragraph.firstChild(named: "a:pPr")!
                let properties = XML.Element("a:lvl\(level)pPr", attributes: source.attributes,
                                             children: source.childElements.map { .element($0.deepCopy()) })
                let run = paragraph.firstChild(named: "a:r")!.firstChild(named: "a:rPr")!
                let defaults = XML.Element("a:defRPr", attributes: run.attributes,
                                           children: run.childElements.map { .element($0.deepCopy()) })
                defaults.firstChild(named: "a:latin")?[attribute: "typeface"] = role == .title ? "+mj-lt" : "+mn-lt"
                properties.removeChildren(named: "a:defRPr"); properties.appendElement(defaults)
                target.appendElement(properties)
            }
        }
        master.part.markDirty()
    }

    /// Publish an authored composition as a real subordinate PowerPoint layout.
    /// Text content stays on the slide; geometry, body defaults and uniform run
    /// formatting move to the layout. This is explicit authoring, never performed
    /// while opening or saving an existing document.
    @discardableResult
    func publishLayout(of slide: Slide, named name: String) throws -> SlideLayout {
        guard slide.package === package, let master = slide.master else {
            throw RostrumError.packageInvalid("The slide must belong to this deck and have a master.")
        }
        var number = 1
        while package.parts[PackURI("/ppt/slideLayouts/slideLayout\(number).xml")] != nil { number += 1 }
        let uri = PackURI("/ppt/slideLayouts/slideLayout\(number).xml")
        let layoutPart = package.addPart(uri: uri, contentType: ContentType.slideLayout,
                                        blob: Data(MinimalTemplate.slideLayoutXML.utf8))
        let layoutDOM = try layoutPart.dom()
        layoutDOM[attribute: "type"] = slide.layout?.type ?? "cust"
        let common = try Slide.cSld(of: layoutPart)
        common[attribute: "name"] = name
        let tree = try Slide.spTree(of: layoutPart)
        if let background = try slide.cSld().firstChild(named: "p:bg"),
           background.firstChild(named: "p:bgPr")?.firstChild(named: "a:blipFill") == nil {
            common.children.insert(.element(background.deepCopy()), at: 0)
            try slide.cSld().removeChild(background)
        }
        var index = 1
        for shape in slide.shapes.all {
            if [.picture, .chart, .table, .diagram].contains(shape.kind) {
                // Native objects remain on the slide, with an empty insertion
                // placeholder in the layout for PowerPoint's New Slide command.
                let phType = shape.kind == .picture ? "pic" : (shape.kind == .chart ? "chart" : (shape.kind == .table ? "tbl" : "dgm"))
                let prototype = try ShapeCollection(part: layoutPart, package: package).addTextBox(shape.frame)
                prototype.markAsPlaceholder(type: phType, idx: index)
                shape.markAsPlaceholder(type: phType, idx: index)
                index += 1
                continue
            }
            guard shape.kind == .autoShape else { continue }
            if shape.textFrame?.text.isEmpty != false {
                // Decorations without resource relationships are reusable layout
                // furniture. Resource-bearing artwork stays on its original slide.
                func hasRelationship(_ element: XML.Element) -> Bool {
                    element.attributes.contains { $0.name.hasPrefix("r:") }
                        || element.childElements.contains(where: hasRelationship)
                }
                if !hasRelationship(shape.element) {
                    tree.appendElement(shape.element.deepCopy())
                    try slide.spTree().removeChild(shape.element)
                }
                continue
            }
            guard let tx = shape.element.firstChild(named: "p:txBody"),
                  !tx.children(named: "a:p").isEmpty,
                  shape.textFrame?.text.isEmpty == false,
                  tx.children(named: "a:p").allSatisfy({ $0.children(named: "a:fld").isEmpty }) else { continue }
            let isTitle = ["title", "ctrTitle"].contains(shape.placeholder?.type ?? "")
            let slot = isTitle ? 0 : index
            if !isTitle { index += 1 }
            shape.markAsPlaceholder(type: isTitle ? "title" : "body", idx: slot)
            let prototype = shape.element.deepCopy()
            prototype.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] = isTitle ? "Title" : "Content \(slot)"
            guard let prototypeText = prototype.firstChild(named: "p:txBody") else { continue }
            let paragraphs = tx.children(named: "a:p")
            let runs = paragraphs.flatMap { $0.children(named: "a:r") }
            let firstProperties = runs.first?.firstChild(named: "a:rPr")
            // Only remove direct run formatting if every run agrees. Mixed
            // emphasis and hyperlinks remain local to their original content.
            func comparable(_ node: XML.Element?) -> String {
                guard let copy = node?.deepCopy() else { return "" }
                copy.removeChildren(named: "a:hlinkClick"); copy.removeChildren(named: "a:hlinkMouseOver")
                return copy.serialized()
            }
            let uniform = runs.allSatisfy { comparable($0.firstChild(named: "a:rPr")) == comparable(firstProperties) }
            let list = prototypeText.getOrAddChild("a:lstStyle", beforeAnyOf: ["a:p"])
            for level in 1...9 {
                let p = XML.Element("a:lvl\(level)pPr")
                if let source = paragraphs.first?.firstChild(named: "a:pPr") {
                    p.attributes = source.attributes.filter { $0.name != "lvl" }
                    p.children = source.children.map { node in
                        if case .element(let child) = node { return .element(child.deepCopy()) }
                        return node
                    }
                }
                if uniform, let r = firstProperties {
                    let defaults = XML.Element("a:defRPr", attributes: r.attributes)
                    for child in r.childElements where !["a:hlinkClick", "a:hlinkMouseOver"].contains(child.name) {
                        defaults.appendElement(child.deepCopy())
                    }
                    if let latin = defaults.firstChild(named: "a:latin") {
                        if latin[attribute: "typeface"] == style.headingFont { latin[attribute: "typeface"] = "+mj-lt" }
                        else if latin[attribute: "typeface"] == style.bodyFont { latin[attribute: "typeface"] = "+mn-lt" }
                    }
                    p.removeChildren(named: "a:defRPr"); p.appendElement(defaults)
                }
                list.removeChildren(named: p.name); list.appendElement(p)
            }
            prototypeText.removeChildren(named: "a:p")
            prototypeText.appendElement(XML.Element("a:p"))
            tree.appendElement(prototype)

            shape.element.firstChild(named: "p:spPr")?.removeChildren(named: "a:xfrm")
            // Empty bodyPr inherits margins and anchor from the layout.
            tx.firstChild(named: "a:bodyPr")?.attributes = []
            if uniform {
                for run in runs {
                    guard let r = run.firstChild(named: "a:rPr") else { continue }
                    let links = r.childElements.filter { ["a:hlinkClick", "a:hlinkMouseOver"].contains($0.name) }.map { $0.deepCopy() }
                    r.attributes = []; r.children = links.map { .element($0) }
                }
            }
        }
        // Match design colors back to native theme slots so changing the theme
        // in PowerPoint recolors layout furniture and inherited text together.
        func useThemeColors(_ element: XML.Element) {
            if element.name == "a:srgbClr", let value = element[attribute: "val"],
               let color = Color(validating: value),
               let slot = ThemeSlot.allCases.first(where: { master.theme?.color($0) == color }) {
                element.name = "a:schemeClr"; element[attribute: "val"] = slot.rawValue
            }
            for child in element.childElements { useThemeColors(child) }
        }
        useThemeColors(common)
        for (offset, element) in tree.childElements.filter({ $0.childElements.first?.firstChild(named: "p:cNvPr") != nil }).enumerated() {
            element.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"] = String(offset + 2)
        }
        layoutPart.rels.add(type: RelType.slideMaster, target: uri.relativeReference(to: master.part.uri))
        let rId = master.part.rels.add(type: RelType.slideLayout, target: master.part.uri.relativeReference(to: uri))
        let list = try master.part.dom().getOrAddChild("p:sldLayoutIdLst", beforeAnyOf: ["p:transition", "p:timing", "p:hf", "p:txStyles", "p:extLst"])
        let used = Set(slideMasters.flatMap { master in
            ((try? master.part.dom())?.firstChild(named: "p:sldLayoutIdLst")?.childElements ?? [])
                .compactMap { UInt32($0[attribute: "id"] ?? "") }
        })
        var id: UInt32 = 2_147_483_649
        while used.contains(id), id < UInt32.max { id += 1 }
        guard !used.contains(id) else { throw RostrumError.packageInvalid("No layout IDs available.") }
        list.appendElement(XML.Element("p:sldLayoutId", attributes: [("id", String(id)), ("r:id", rId)]))
        for rel in slide.part.rels.all(ofType: RelType.slideLayout) { slide.part.rels.remove(rId: rel.rId) }
        slide.part.rels.add(type: RelType.slideLayout, target: slide.part.uri.relativeReference(to: uri))
        layoutPart.markDirty(); master.part.markDirty(); slide.part.markDirty()
        return SlideLayout(part: layoutPart, package: package)
    }
}

private extension XML.Element {
    func wrapped(in name: String) -> XML.Element { XML.Element(name, children: [.element(self)]) }
}
