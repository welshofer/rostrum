import Foundation

// Headless slide → SVG rendering, for thumbnails and deterministic visual-diff
// tests. Glyphs are delegated to the SVG viewer (no rasterizer), so this stays
// zero-dependency. Coordinates are EMU (the viewBox is in EMU); font sizes are
// points × 12700 EMU/pt. Not pixel-perfect — paragraphs whose typeface has no
// registered metrics are wrapped on a character-width estimate, so breaks land
// near, not exactly where, PowerPoint puts them. Unsupported shape-tree content
// is reported separately; SVG output is deterministic, not a fidelity certificate.
struct SVGRenderer {
    let slidePart: Part
    let slideSize: (width: EMU, height: EMU)
    let theme: Theme
    let package: OPCPackage
    /// Registered fonts: paragraphs whose typeface resolves here are wrapped
    /// on real advance widths with baseline placement; the rest are wrapped on
    /// a character-width estimate.
    let fonts: FontLibrary
    /// 1-based position of this slide, substituted into `slidenum` fields.
    let slideNumber: Int

    private let emuPerPoint = 12700

    func render(pixelWidth: Int) throws -> (svg: String, problems: SlideRenderProblems) {
        // Not for the value: this is the one call that surfaces a malformed
        // slide part as a thrown error. Everything below reaches the tree
        // through `existingSpTree`, which swallows the parse with `try?` and
        // would render a silently blank slide instead.
        _ = try slidePart.dom()
        // p:sldSz comes from the file too, and the aspect-ratio conversion below
        // goes through Int(_: Double), which traps when the double is out of
        // range — so bound the dimensions before dividing by them.
        let bound = OOXMLBounds.coordinate
        let w = bound.contains(slideSize.width.rawValue) ? slideSize.width.rawValue : 0
        let h = bound.contains(slideSize.height.rawValue) ? slideSize.height.rawValue : 0
        let pxH = w > 0 ? Int((Double(pixelWidth) * Double(h) / Double(w)).rounded()) : pixelWidth
        var defs = SVGDefinitions()
        var body = ""

        // A slide inherits its background and its furniture. Rendering only the
        // slide's own shapes on the slide's own background makes every deck
        // look like whatever it was before a template was applied: the logo,
        // the photo panel, the coloured field a brand puts on its layouts all
        // live on the layout and the master, not on the slide.
        let (chain, inheritedProblems) = inheritanceChain()
        var problems = inheritedProblems
        body += box(0, 0, w, h,
                    fill: backgroundFill(chain: chain, box: (0, 0, w, h), defs: &defs) ?? "#FFFFFF")

        if showsMasterShapes(chain: chain), let master = chain.master {
            body += renderInherited(master, defs: &defs, problems: &problems)
        }
        if let layout = chain.layout {
            body += renderInherited(layout, defs: &defs, problems: &problems)
        }

        if let spTree = Slide.existingSpTree(of: slidePart) {
            for child in spTree.childElements {
                body += renderNode(child, ownedBy: slidePart, defs: &defs, problems: &problems)
            }
        }

        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(pixelWidth)\" height=\"\(pxH)\" "
            + "viewBox=\"0 0 \(w) \(h)\"><defs>\(defs)</defs>\(body)</svg>"
        return (svg, problems)
    }

    // MARK: - Inheritance

    /// The layout this slide uses and that layout's master, plus a note of any
    /// link in that chain we could not follow.
    ///
    /// A slide points at a layout and the layout points at a master, and the
    /// slide inherits its background and furniture down that chain. When a link
    /// is broken the slide still renders — just without whatever it would have
    /// inherited — so the break leaves no trace in the SVG. Rather than flatten
    /// both breaks into a bare `nil`, record which one happened, so a caller
    /// can tell a damaged deck apart from one we rendered wrong.
    private func inheritanceChain()
        -> (chain: (layout: Part?, master: Part?), problems: SlideRenderProblems) {
        guard let rel = slidePart.rels.first(ofType: RelType.slideLayout),
              let layout = try? package.part(
                at: PackURI.resolve(target: rel.target, relativeTo: slidePart.uri.baseURI))
        else { return ((nil, nil), SlideRenderProblems(layoutUnresolved: true)) }
        guard let masterRel = layout.rels.first(ofType: RelType.slideMaster),
              let master = try? package.part(
                at: PackURI.resolve(target: masterRel.target, relativeTo: layout.uri.baseURI))
        else { return ((layout, nil), SlideRenderProblems(masterUnresolved: true)) }
        return ((layout, master), SlideRenderProblems())
    }

    /// The first background in the slide → layout → master chain, which is the
    /// order PowerPoint resolves it in. `p:bgRef` names a fill in the theme's
    /// `bgFillStyleLst`; its colour child is the one that fill is built from,
    /// which is close enough for a thumbnail and far closer than white.
    private func backgroundFill(chain: (layout: Part?, master: Part?),
                                box f: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String? {
        for part in [slidePart, chain.layout, chain.master].compactMap({ $0 }) {
            guard let bg = (try? part.dom())?
                .firstChild(named: "p:cSld")?.firstChild(named: "p:bg") else { continue }
            if let bgPr = bg.firstChild(named: "p:bgPr") {
                if let blip = bgPr.firstChild(named: "a:blipFill"),
                   let pattern = imagePattern(blip, ownedBy: part, box: f, defs: &defs) {
                    return pattern
                }
                if let paint = paint(for: bgPr, box: f, defs: &defs) { return paint }
            }
            if let bgRef = bg.firstChild(named: "p:bgRef") { return colorHex(in: bgRef) }
        }
        return nil
    }

    /// Whether the master's shapes are drawn — a layout or slide can switch
    /// them off with `showMasterSp="0"`, which is how a full-bleed layout drops
    /// the master's furniture.
    private func showsMasterShapes(chain: (layout: Part?, master: Part?)) -> Bool {
        for part in [slidePart, chain.layout].compactMap({ $0 }) {
            if (try? part.dom())?[attribute: "showMasterSp"] == "0" { return false }
        }
        return true
    }

    /// A layout's or master's own decoration, beneath the slide's shapes.
    ///
    /// Placeholders are skipped: on a layout or a master they are prompts
    /// ("Click to add title"), and PowerPoint never draws them on a slide.
    private func renderInherited(_ part: Part, defs: inout SVGDefinitions, problems: inout SlideRenderProblems) -> String {
        guard let tree = Slide.existingSpTree(of: part) else { return "" }
        var out = ""
        for child in tree.childElements {
            if Placeholders.phElement(of: child) != nil { continue }
            out += renderNode(child, ownedBy: part, defs: &defs, problems: &problems, inherited: true)
        }
        return out
    }

    // MARK: - Shape tree and transforms

    private func renderNode(_ node: XML.Element, ownedBy owner: Part, defs: inout SVGDefinitions,
                            problems: inout SlideRenderProblems, inherited: Bool = false,
                            depth: Int = 0, flippedTextH: Bool = false, flippedTextV: Bool = false) -> String {
        guard depth < 64 else {
            problems.record("Preview omitted shapes nested more than 64 levels deep.")
            return ""
        }
        if inherited && Placeholders.phElement(of: node) != nil { return "" }
        let nodeTransform = ShapeTransform.element(of: node)
        let localFlipH = ["1", "true"].contains(nodeTransform?[attribute: "flipH"] ?? "")
        let localFlipV = ["1", "true"].contains(nodeTransform?[attribute: "flipV"] ?? "")
        let textFlipH = flippedTextH != localFlipH, textFlipV = flippedTextV != localFlipV
        let content: String
        switch node.name {
        case "p:nvGrpSpPr", "p:grpSpPr", "p:extLst": return ""
        case "p:grpSp":
            let children = node.childElements.map {
                renderNode($0, ownedBy: owner, defs: &defs, problems: &problems,
                           inherited: inherited, depth: depth + 1, flippedTextH: textFlipH, flippedTextV: textFlipV)
            }.joined()
            let transform = ShapeTransform.element(of: node)
            guard let outer = ShapeTransform.rect(transform),
                  let child = ShapeTransform.childSpace(transform),
                  outer.width.rawValue > 0, outer.height.rawValue > 0,
                  child.width.rawValue > 0, child.height.rawValue > 0 else {
                problems.record("Preview could not map a group's coordinate space.")
                return children
            }
            let sx = Double(outer.width.rawValue) / Double(child.width.rawValue)
            let sy = Double(outer.height.rawValue) / Double(child.height.rawValue)
            let mapping = "translate(\(outer.x.rawValue) \(outer.y.rawValue)) scale(\(sx) \(sy)) translate(\(-child.x.rawValue) \(-child.y.rawValue))"
            content = "<g transform=\"\(mapping)\">\(children)</g>"
        case "p:sp":
            let properties = node.firstChild(named: "p:spPr")
            let preset = properties?.firstChild(named: "a:prstGeom")?[attribute: "prst"] ?? "rect"
            if properties?.firstChild(named: "a:custGeom") != nil || !SVGPresetGeometry.supported.contains(preset) {
                problems.record("Preview approximates custom or unsupported shape geometry as a rectangle.")
            }
            if let guides = properties?.firstChild(named: "a:prstGeom")?.firstChild(named: "a:avLst"),
               guides.children(named: "a:gd").contains(where: { guide in
                   let parts = (guide[attribute: "fmla"] ?? "").split(whereSeparator: { $0.isWhitespace })
                   return parts.count != 2 || parts.first != "val" || Double(parts.last ?? "")?.isFinite != true
               }) {
                problems.record("Preview uses default shape adjustments for unsupported guide formulas.")
            }
            if (flippedTextH || flippedTextV) && ShapeTransform.rotation(of: node) != 0 {
                problems.record("Preview may differ for rotated text inside a flipped group.")
            }
            content = renderShape(node, ownedBy: owner, defs: &defs, problems: &problems, textFlipH: textFlipH, textFlipV: textFlipV)
        case "p:pic": content = renderPicture(node, ownedBy: owner, defs: &defs, problems: &problems)
        case "p:cxnSp": content = renderConnector(node, defs: &defs, problems: &problems)
        case "p:graphicFrame": content = renderGraphicFrame(node, ownedBy: owner, defs: &defs, problems: &problems)
        default:
            problems.record("Preview omitted an unsupported shape-tree element.")
            return ""
        }
        guard let transform = ShapeTransform.element(of: node),
              let bounds = ShapeTransform.rect(transform) else { return content }
        // DrawingML flips about the shape/group center, then rotates clockwise.
        let rotation = ShapeTransform.rotation(of: node).truncatingRemainder(dividingBy: 360)
        let flipH = ["1", "true"].contains(transform[attribute: "flipH"] ?? "")
        let flipV = ["1", "true"].contains(transform[attribute: "flipV"] ?? "")
        guard rotation != 0 || flipH || flipV else { return content }
        let cx = Double(bounds.x.rawValue) + Double(bounds.width.rawValue) / 2
        let cy = Double(bounds.y.rawValue) + Double(bounds.height.rawValue) / 2
        return "<g transform=\"translate(\(cx) \(cy)) rotate(\(rotation)) scale(\(flipH ? -1 : 1) \(flipV ? -1 : 1)) translate(\(-cx) \(-cy))\">\(content)</g>"
    }

    private func renderConnector(_ node: XML.Element, defs: inout SVGDefinitions,
                                 problems: inout SlideRenderProblems) -> String {
        guard let properties = node.firstChild(named: "p:spPr") else { return "" }
        let (x, y, w, h) = frame(of: properties)
        let styled = effectiveLine(properties, reference: node.firstChild(named: "p:style")?.firstChild(named: "a:lnRef"))
        let line = styled.firstChild(named: "a:ln")
        if line?.firstChild(named: "a:noFill") != nil { return "" }
        let color = colorHex(in: line?.firstChild(named: "a:solidFill"))
            ?? colorHex(in: node.firstChild(named: "p:style")?.firstChild(named: "a:lnRef")) ?? "#000000"
        let width = max(1, line?.coordinate("w") ?? 12700)
        let preset = properties.firstChild(named: "a:prstGeom")?[attribute: "prst"] ?? "line"
        if preset != "line" && preset != "straightConnector1" {
            problems.record("Preview approximates bent or curved connectors with straight lines.")
        }
        var attrs = "stroke=\"\(color)\" stroke-width=\"\(width)\" fill=\"none\""
        if let dash = line?.firstChild(named: "a:prstDash")?[attribute: "val"], dash != "solid" {
            let pattern: String
            switch dash {
            case "dot", "sysDot": pattern = "\(width) \(width * 2)"
            case "dash", "sysDash": pattern = "\(width * 4) \(width * 3)"
            default:
                pattern = "\(width * 4) \(width * 3)"
                problems.record("Preview approximates an unsupported connector dash pattern.")
            }
            attrs += " stroke-dasharray=\"\(pattern)\""
        }
        for (element, attribute, start) in [("a:headEnd", "marker-start", true), ("a:tailEnd", "marker-end", false)] {
            guard let end = line?.firstChild(named: element), let type = end[attribute: "type"], type != "none" else { continue }
            guard ["triangle", "arrow", "diamond", "oval"].contains(type) else {
                problems.record("Preview omitted an unsupported connector arrowhead."); continue
            }
            let id = defs.nextID("arrow")
            func size(_ value: String?) -> Int { value == "lg" ? 5 : value == "sm" ? 2 : 3 }
            let markerWidth = size(end[attribute: "len"]), markerHeight = size(end[attribute: "w"])
            let shape: String
            switch type {
            case "oval": shape = "<ellipse cx=\"5\" cy=\"5\" rx=\"5\" ry=\"5\" fill=\"\(color)\"/>"
            case "diamond": shape = "<path d=\"M0 5 L5 0 L10 5 L5 10 Z\" fill=\"\(color)\"/>"
            case "arrow": shape = "<path d=\"M0 0 L10 5 L0 10\" fill=\"none\" stroke=\"\(color)\" stroke-width=\"2\"/>"
            default: shape = "<path d=\"M0 0 L10 5 L0 10 Z\" fill=\"\(color)\"/>"
            }
            // Explicitly reverse the start marker rather than relying on SVG 2
            // auto-start-reverse, which older viewers may not implement.
            let marker = start ? "<g transform=\"rotate(180 5 5)\">\(shape)</g>" : shape
            defs += "<marker id=\"\(id)\" viewBox=\"0 0 10 10\" refX=\"\(start ? 0 : 10)\" refY=\"5\" markerWidth=\"\(markerWidth)\" markerHeight=\"\(markerHeight)\" orient=\"auto\" overflow=\"visible\">\(marker)</marker>"
            attrs += " \(attribute)=\"url(#\(id))\""
        }
        return "<line x1=\"\(x)\" y1=\"\(y)\" x2=\"\(x + w)\" y2=\"\(y + h)\" \(attrs)/>"
    }

    // MARK: - Shapes

    private func renderShape(_ sp: XML.Element, ownedBy owner: Part,
                             defs: inout SVGDefinitions, problems: inout SlideRenderProblems, textFlipH: Bool = false, textFlipV: Bool = false) -> String {
        guard let spPr = sp.firstChild(named: "p:spPr") else { return "" }
        let f = resolvedFrame(of: sp, spPr: spPr, ownedBy: owner)
        var out = ""
        let preset = spPr.firstChild(named: "a:prstGeom")
        let prst = spPr.firstChild(named: "a:custGeom") != nil ? "rect" : preset?[attribute: "prst"] ?? "rect"
        let style = sp.firstChild(named: "p:style")
        let fillProperties = effectiveFill(spPr, reference: style?.firstChild(named: "a:fillRef"))
        let fill = fillProperties.firstChild(named: "a:blipFill").flatMap {
            imagePattern($0, ownedBy: owner, box: f, defs: &defs)
        } ?? paint(for: fillProperties, box: f, defs: &defs)
        let lineProperties = effectiveLine(spPr, reference: style?.firstChild(named: "a:lnRef"))
        let stroke = strokeAttrs(lineProperties)
        if fill != nil || !stroke.isEmpty {
            out += SVGPresetGeometry.render(prst, adjustments: preset?.firstChild(named: "a:avLst"),
                                           frame: f, fill: fill ?? "none", stroke: stroke)
        }
        if let txBody = sp.firstChild(named: "p:txBody") {
            let textFrame = SVGPresetGeometry.textFrame(prst, adjustments: preset?.firstChild(named: "a:avLst"), frame: f)
            let text = renderText(txBody, box: textFrame,
                                  inheriting: inheritedRunDefaults(for: sp, ownedBy: owner),
                                  fontReference: style?.firstChild(named: "a:fontRef"), respectInsets: true)
            // PowerPoint flips the shape and its placement, not the glyphs.
            // Counter-reflect text locally before the enclosing SVG transforms.
            if textFlipH || textFlipV {
                let cx = Double(f.0) + Double(f.2) / 2, cy = Double(f.1) + Double(f.3) / 2
                out += "<g data-text-unflip=\"true\" transform=\"translate(\(cx) \(cy)) scale(\(textFlipH ? -1 : 1) \(textFlipV ? -1 : 1)) translate(\(-cx) \(-cy))\">\(text)</g>"
            } else { out += text }
        }
        // An explicit empty effect list suppresses the theme's shadow.
        let effects = spPr.firstChild(named: "a:effectLst")
            ?? (spPr.firstChild(named: "a:effectDag") == nil
                ? styleEntry(style?.firstChild(named: "a:effectRef"), list: "a:effectStyleLst")?.firstChild(named: "a:effectLst") : nil)
        if let shadow = effects?.firstChild(named: "a:outerShdw") {
            let ordinary = ["sx", "sy"].allSatisfy { shadow[attribute: $0] == nil || shadow[attribute: $0] == "100000" }
                && ["kx", "ky"].allSatisfy { shadow[attribute: $0] == nil || shadow[attribute: $0] == "0" }
            if ordinary {
                let transform = spPr.firstChild(named: "a:xfrm")
                out = SVGShadow.wrap(out, shadow: shadow, frame: f, theme: theme,
                    rotation: ShapeTransform.rotation(of: sp),
                    flipH: ["1", "true"].contains(transform?[attribute: "flipH"] ?? ""),
                    flipV: ["1", "true"].contains(transform?[attribute: "flipV"] ?? ""), defs: &defs)
            } else { problems.record("Preview omitted a scaled or skewed outer shadow.") }
        }
        return out
    }

    /// A shape's frame, resolving placeholder inheritance when it carries no
    /// transform of its own — which is exactly what a placeholder cloned from a
    /// layout looks like, and without this every one of them renders at the
    /// slide's top-left corner with no size.
    private func resolvedFrame(of sp: XML.Element, spPr: XML.Element,
                               ownedBy owner: Part) -> (Int, Int, Int, Int) {
        if spPr.firstChild(named: "a:xfrm") != nil { return frame(of: spPr) }
        guard owner === slidePart, Placeholders.phElement(of: sp) != nil else {
            return frame(of: spPr)
        }
        let slide = Slide(part: slidePart, package: package)
        let shape = Shape(element: sp, part: slidePart, package: package)
        guard let r = slide.effectiveFrame(of: shape) else { return frame(of: spPr) }
        return (Int(r.x.rawValue), Int(r.y.rawValue),
                Int(r.width.rawValue), Int(r.height.rawValue))
    }

    /// Ordered inherited list styles, merged per paragraph level. Partial
    /// layout overrides must not discard the master's font or other defaults.
    private func inheritedRunDefaults(for sp: XML.Element, ownedBy owner: Part) -> [XML.Element] {
        let chain = inheritanceChain().chain
        let ph = Placeholders.phElement(of: sp)
        let idx = ph?[attribute: "idx"].flatMap(Int.init) ?? 0
        var type = ph?[attribute: "type"] ?? "obj"
        var layoutShape: XML.Element?
        if owner === slidePart, ph != nil, let layout = chain.layout {
            layoutShape = Slide.existingSpTree(of: layout)?.childElements.first {
                guard let candidate = Placeholders.phElement(of: $0) else { return false }
                return (candidate[attribute: "idx"].flatMap(Int.init) ?? 0) == idx
            }
            type = layoutShape.flatMap { Placeholders.phElement(of: $0)?[attribute: "type"] } ?? type
        }
        let reduced = Slide.masterTypeReduction[type] ?? "body"
        let bucket = ph == nil ? "p:otherStyle" : reduced == "title" ? "p:titleStyle" : reduced == "body" ? "p:bodyStyle" : "p:otherStyle"
        let masterDOM = try? chain.master?.dom()
        let masterShape = ph == nil ? nil : chain.master.flatMap { master in
            Slide.existingSpTree(of: master)?.childElements.first {
                guard let candidate = Placeholders.phElement(of: $0) else { return false }
                return (Slide.masterTypeReduction[candidate[attribute: "type"] ?? "obj"] ?? "body") == reduced
            }
        }
        return [(try? package.mainDocumentPart().dom())?.firstChild(named: "p:defaultTextStyle"),
                masterDOM?.firstChild(named: "p:txStyles")?.firstChild(named: bucket),
                masterShape?.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle"),
                layoutShape?.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle")].compactMap { $0 }
    }

    // MARK: - Text (wrapped on real metrics when the typeface is registered,
    // else on a character-width estimate)

    private func renderText(_ txBody: XML.Element, box f: (Int, Int, Int, Int),
                            inheriting inheritedStyles: [XML.Element] = [], fontReference: XML.Element? = nil, respectInsets: Bool = false) -> String {
        if SVGRichText.needsLayout(txBody, inherited: inheritedStyles) {
            return SVGRichText(theme: theme, fonts: fonts, slideNumber: slideNumber)
                .render(txBody, frame: f, inherited: inheritedStyles, reference: fontReference)
        }
        let (x, y, w, h) = f
        let bodyPr = txBody.firstChild(named: "a:bodyPr")
        // Bounded like every other coordinate here: `x + inset(…)` traps.
        func inset(_ name: String, _ fallback: Int) -> Int {
            bodyPr?.coordinate(name) ?? fallback
        }
        let contentX = x + inset("lIns", 91_440)
        let contentW = Swift.max(0, w - inset("lIns", 91_440) - inset("rIns", 91_440))
        let paragraphs = txBody.children(named: "a:p")

        // Laid out relative to the top of the box, so the finished block can be
        // moved as a unit to honour `a:bodyPr/@anchor` below.
        struct Line {
            let x: Int, baseline: Int, size: Int
            let fill: String, anchor: String, text: String
            let bold: Bool
            let typeface: String?
        }
        // A shape's font style reference overrides presentation/master defaults,
        // while explicit text-body, paragraph and run formatting remains stronger.
        let referenceDefaults = XML.Element("a:rPr")
        if let color = fontReference?.childElements.first(where: { SVGPaint.colorElements.contains($0.name) }) {
            referenceDefaults.appendElement(XML.Element("a:solidFill", children: [.element(color.deepCopy())]))
        }
        if let index = fontReference?[attribute: "idx"], ["major", "minor"].contains(index) {
            referenceDefaults.appendElement(XML.Element("a:latin", attributes: [("typeface", index == "major" ? "+mj-lt" : "+mn-lt")]))
        }
        var lines: [Line] = []
        var cursorY = 0
        for p in paragraphs {
            // Fields (slide number, date) are siblings of the runs and carry
            // their own cached text; a renderer that reads only `a:r` silently
            // drops the deck's furniture.
            let pieces = p.childElements.filter { $0.name == "a:r" || $0.name == "a:fld" }
            let text = pieces.map { piece -> String in
                if piece.name == "a:fld", piece[attribute: "type"] == "slidenum" {
                    // The cached value is whatever it was when written; the
                    // real number is the position we're rendering from.
                    return String(slideNumber)
                }
                return piece.firstChild(named: "a:t")?.textContent ?? ""
            }.joined()
            guard !text.isEmpty else { cursorY += emuPerPoint * 18; continue }
            let level = p.firstChild(named: "a:pPr")?.boundedInt("lvl", in: 0...8) ?? 0
            let defaults = mergedRunProperties(inheritedStyles.flatMap { style in
                [style.firstChild(named: "a:defPPr")?.firstChild(named: "a:defRPr"),
                 style.firstChild(named: "a:lvl\(level + 1)pPr")?.firstChild(named: "a:defRPr")]
            })
            let localStyle = txBody.firstChild(named: "a:lstStyle")
            let localDefaults = mergedRunProperties([
                localStyle?.firstChild(named: "a:defPPr")?.firstChild(named: "a:defRPr"),
                localStyle?.firstChild(named: "a:lvl\(level + 1)pPr")?.firstChild(named: "a:defRPr")])
            let rPr: XML.Element? = mergedRunProperties([defaults, referenceDefaults, localDefaults,
                p.firstChild(named: "a:pPr")?.firstChild(named: "a:defRPr"), pieces.first?.firstChild(named: "a:rPr")])
            // ST_TextFontSize is 1pt–4000pt in hundredths. The file can say
            // anything, and `sz * 12700` on a large Int is an overflow crash.
            let sizeHundredths = min(max(rPr?[attribute: "sz"].flatMap { Int($0) }
                ?? defaults[attribute: "sz"].flatMap { Int($0) } ?? 1800, 100),
                                     400_000)
            let sizeEMU = sizeHundredths * emuPerPoint / 100
            let bold = rPr?[attribute: "b"] == "1"
                || (rPr?[attribute: "b"] == nil && defaults[attribute: "b"] == "1")
            let color = rPr.flatMap { colorHex(in: $0.firstChild(named: "a:solidFill")) }
                ?? colorHex(in: defaults.firstChild(named: "a:solidFill"))
                ?? colorHex(in: fontReference) ?? "#1A1A1A"
            let align = p.firstChild(named: "a:pPr")?[attribute: "algn"]
                ?? txBody.firstChild(named: "a:lstStyle")?.firstChild(named: "a:lvl\(level + 1)pPr")?[attribute: "algn"] ?? "l"
            let alignX = respectInsets ? contentX : x, alignW = respectInsets ? contentW : w
            let (anchorX, textAnchor) = align == "ctr" ? (alignX + alignW / 2, "middle")
                : align == "r" ? (alignX + alignW, "end") : (alignX, "start")

            // A run usually inherits its typeface from the theme rather than
            // naming one, and `+mj-lt`/`+mn-lt` name it indirectly. Resolving
            // both is what lets a deck with registered fonts take the measured
            // path for the text it actually renders, not just for runs that
            // happen to carry an explicit `a:latin`.
            let typeface = explicitTypeface(rPr) ?? explicitTypeface(defaults)
                ?? (fontReference?[attribute: "idx"] == "major" ? theme.majorFont
                    : fontReference?[attribute: "idx"] == "minor" ? theme.minorFont : nil)
                ?? resolvedTypeface(nil)
            if pieces.count == 1, let typeface, let metrics = fonts.metrics(for: typeface) {
                // Measured path: real word wrap and baseline placement —
                // single-run paragraphs only, since a mixed-size/font
                // paragraph measured at the first run's metrics would wrap
                // wrong; those keep the estimated path below.
                // Both shape-text paths use the same preset text region and
                // body insets; measured metrics refine wrapping and baselines.
                let lineX = textAnchor == "start" ? contentX : anchorX
                let sizePt = Double(sizeEMU) / Double(emuPerPoint)
                let wrapped = TextMeasurer(metrics).wrap(
                    text, pointSize: sizePt, width: Double(contentW) / Double(emuPerPoint))
                let lineH = Int((metrics.lineHeight(pointSize: sizePt) * Double(emuPerPoint)).rounded())
                let ascent = Int((metrics.ascent(pointSize: sizePt) * Double(emuPerPoint)).rounded())
                for line in wrapped {
                    lines.append(Line(x: lineX, baseline: cursorY + ascent, size: sizeEMU,
                                      fill: color, anchor: textAnchor, text: line, bold: bold,
                                      typeface: typeface))
                    cursorY += lineH
                }
            } else {
                // No metrics for this typeface (or a mixed paragraph): estimate
                // a character width from the font size and wrap within the
                // available text region. This remains approximate typography.
                for line in wrapEstimated(text, width: respectInsets ? contentW : w, sizeEMU: sizeEMU) {
                    cursorY += sizeEMU
                    lines.append(Line(x: anchorX, baseline: cursorY, size: sizeEMU,
                                      fill: color, anchor: textAnchor, text: line, bold: bold,
                                      typeface: typeface))
                    cursorY += sizeEMU / 3
                }
            }
        }

        // `a:bodyPr/@anchor`: bottom- and center-anchored bodies grow away from
        // their anchored edge. Ignoring it put a wrapped bottom-anchored title
        // straight through the content below it instead of up into the space
        // the layout left for exactly that.
        let offsetY: Int
        switch bodyPr?[attribute: "anchor"] {
        case "b": offsetY = y + h - cursorY
        case "ctr": offsetY = y + (h - cursorY) / 2
        default: offsetY = y
        }
        return lines.map { line in
            textElement(line.text, x: line.x, baseline: line.baseline + offsetY,
                        sizeEMU: line.size, fill: line.fill, anchor: line.anchor,
                        bold: line.bold, typeface: line.typeface)
        }.joined()
    }


    // MARK: - Text emission

    /// One `<text>`, positioned in EMU but sized in points.
    ///
    /// The obvious markup — `font-size` in EMU, like every other length here —
    /// is silently unreadable in a browser. WebKit and Blink clamp computed
    /// `font-size` to a five-digit maximum *before* the viewBox transform
    /// shrinks it, so a 68pt title asking for `font-size="863600"` gets clamped
    /// and then scaled down to roughly one pixel. The text is present, in the
    /// right place, and invisible.
    ///
    /// So the glyphs are specified in points, under their own
    /// `translate(x, y) scale(emuPerPoint)`: the size never approaches the
    /// clamp, and the scale puts it back into EMU space. `text-anchor` still
    /// works — it anchors at x = 0 of the scaled space, which the translate has
    /// already put at the anchor point.
    private func textElement(_ text: String, x: Int, baseline: Int, sizeEMU: Int,
                             fill: String, anchor: String, bold: Bool,
                             typeface: String?) -> String {
        "<text transform=\"translate(\(x),\(baseline)) scale(\(emuPerPoint))\" "
            + "font-size=\"\(points(sizeEMU))\" fill=\"\(fill)\" text-anchor=\"\(anchor)\""
            + fontFamilyAttr(typeface)
            + (bold ? " font-weight=\"bold\"" : "") + ">"
            + escape(text) + "</text>"
    }

    /// The typeface the run resolved to, as a `font-family` the viewer can use.
    ///
    /// Without this every deck renders in the viewer's default serif, whatever
    /// its brand font is — the renderer already resolves the typeface to pick
    /// wrapping metrics, it just never said so in the markup. A generic
    /// fallback keeps a missing font from landing back on serif by accident.
    private func fontFamilyAttr(_ typeface: String?) -> String {
        guard let typeface, !typeface.isEmpty else { return " font-family=\"sans-serif\"" }
        return " font-family=\"\(escape(typeface)), sans-serif\""
    }

    /// EMU as points, formatted deterministically.
    ///
    /// Run sizes come from `a:rPr/@sz` in hundredths of a point, so this is at
    /// most two decimals; trailing zeros are trimmed so whole sizes stay whole
    /// and byte-identical output survives.
    private func points(_ emu: Int) -> String {
        let hundredths = emu * 100 / emuPerPoint
        let whole = hundredths / 100, frac = abs(hundredths % 100)
        if frac == 0 { return String(whole) }
        if frac % 10 == 0 { return "\(whole).\(frac / 10)" }
        return String(format: "%d.%02d", whole, frac)
    }

    /// The typeface a run renders in: its own `a:latin`, the theme font it
    /// names indirectly (`+mj-lt`/`+mn-lt`), or — when it names none — the
    /// first theme font the deck has metrics for.
    private func mergedRunProperties(_ sources: [XML.Element?]) -> XML.Element {
        let result = XML.Element("a:rPr")
        for source in sources.compactMap({ $0 }) {
            for attribute in source.attributes { result[attribute: attribute.name] = attribute.value }
            for child in source.childElements {
                result.children.removeAll { if case .element(let e) = $0 { return e.name == child.name }; return false }
                result.appendElement(child.deepCopy())
            }
        }
        return result
    }

    private func explicitTypeface(_ properties: XML.Element?) -> String? {
        guard let name = properties?.firstChild(named: "a:latin")?[attribute: "typeface"], !name.isEmpty else { return nil }
        return name == "+mj-lt" ? theme.majorFont : name == "+mn-lt" ? theme.minorFont : name
    }

    private func resolvedTypeface(_ rPr: XML.Element?) -> String? {
        let named = rPr?.firstChild(named: "a:latin")?[attribute: "typeface"]
        switch named {
        case "+mj-lt": return theme.majorFont
        case "+mn-lt": return theme.minorFont
        case .some(let face) where !face.isEmpty: return face
        default:
            for candidate in [theme.majorFont, theme.minorFont] {
                if let candidate, fonts.metrics(for: candidate) != nil { return candidate }
            }
            return theme.minorFont ?? theme.majorFont
        }
    }

    /// Bound on lines emitted for one estimated paragraph. Width comes out of
    /// the file, so a hostile deck can declare a one-EMU-wide shape holding a
    /// megabyte of text and ask for a line per character; the renderer is a
    /// pure read API that must survive whatever it is pointed at. The old
    /// single-line clip gave this bound for free — it is explicit now that
    /// more than one line can be emitted.
    private static let maxEstimatedLines = 64

    /// Break `text` into lines that fit `width`, estimating character width
    /// from the font size. Used when the paragraph's typeface has no
    /// registered metrics — register the font (`deck.fonts`) and the measured
    /// path above wraps on real advance widths instead.
    ///
    /// The trailing ellipsis appears only when the bound actually discarded
    /// text. That is tracked, not inferred from the line count: a paragraph
    /// that happens to fill exactly `maxEstimatedLines` with every word intact
    /// would otherwise be given an ellipsis it never earned *and* have a real
    /// character deleted to make room for it — the same silent rewriting of
    /// the deck's own words that replacing the clip was meant to end.
    private func wrapEstimated(_ text: String, width: Int, sizeEMU: Int) -> [String] {
        let approxCharWidth = sizeEMU / 2
        guard approxCharWidth > 0, width > 0 else { return [text] }
        let maxChars = Swift.max(1, width / approxCharWidth)
        guard text.count > maxChars else { return [text] }

        var lines: [String] = []
        var current = ""
        var truncated = false

        /// Appends a line; false once the bound is reached and nothing more
        /// may be emitted.
        func commit(_ line: String) -> Bool {
            lines.append(line)
            return lines.count < Self.maxEstimatedLines
        }

        outer: for word in text.split(separator: " ") {
            let candidate = current.isEmpty ? String(word) : current + " " + word
            if candidate.count <= maxChars {
                current = candidate
                continue
            }
            // Both exits below abandon this word and everything after it.
            if !current.isEmpty, !commit(current) {
                current = ""
                truncated = true
                break outer
            }
            // A single word wider than the line is hard-broken rather than
            // allowed to run past the shape's edge.
            var rest = Substring(word)
            while rest.count > maxChars {
                if !commit(String(rest.prefix(maxChars))) {
                    current = ""
                    truncated = true
                    break outer
                }
                rest = rest.dropFirst(maxChars)
            }
            current = String(rest)
        }
        if !current.isEmpty {
            if lines.count >= Self.maxEstimatedLines {
                truncated = true
            } else {
                lines.append(current)
            }
        }

        // Say so when the bound bit, rather than ending mid-sentence as if the
        // deck said that.
        if truncated, let last = lines.last {
            lines[lines.count - 1] = String(last.prefix(Swift.max(1, maxChars - 1))) + "…"
        }
        return lines.isEmpty ? [text] : lines
    }

    // MARK: - Pictures

    private func renderPicture(_ pic: XML.Element, ownedBy owner: Part, defs: inout SVGDefinitions,
                               problems: inout SlideRenderProblems) -> String {
        guard let spPr = pic.firstChild(named: "p:spPr"), let blip = pic.firstChild(named: "p:blipFill") else { return "" }
        let f = frame(of: spPr)
        guard let fill = imagePattern(blip, ownedBy: owner, box: f, defs: &defs) else {
            problems.record("Preview could not resolve a picture or its crop bounds."); return ""
        }
        let geom = spPr.firstChild(named: "a:prstGeom")
        return SVGPresetGeometry.render(geom?[attribute: "prst"] ?? "rect", adjustments: geom?.firstChild(named: "a:avLst"), frame: f, fill: fill, stroke: strokeAttrs(spPr))
    }

    /// A `data:` URL for an embedded image, resolved against the part that owns
    /// the relationship — a layout's photo lives in the layout's rels, not the
    /// slide's, so this cannot assume the slide.
    private func imageData(rId: String, ownedBy owner: Part) -> String? {
        guard let rel = owner.rels.relationship(withId: rId) else { return nil }
        let target = PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI)
        guard let media = package.parts[target] else { return nil }
        let ext = target.ext.lowercased()
        let mime = ext == "jpg" || ext == "jpeg" ? "image/jpeg" : ext == "gif" ? "image/gif" : "image/png"
        return "data:\(mime);base64,\(media.blob.base64EncodedString())"
    }

    /// An `a:blipFill` as an SVG pattern, so a photographic background renders
    /// as the photograph rather than as a neutral grey box.
    private func imagePattern(_ blip: XML.Element, ownedBy owner: Part,
                              box f: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String? {
        guard let rId = blip.firstChild(named: "a:blip")?[attribute: "r:embed"],
              let data = imageData(rId: rId, ownedBy: owner), f.2 > 0, f.3 > 0 else { return nil }
        let id = defs.nextID("bg")
        var pw = Double(f.2), ph = Double(f.3), ox = Double(f.0), oy = Double(f.1)
        var content: String
        if let tile = blip.firstChild(named: "a:tile"),
           let rel = owner.rels.relationship(withId: rId),
           let media = package.parts[PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI)],
           let info = ImageSniffer.sniff(media.blob) {
            let sx = Double(tile.boundedInt("sx", in: 1...10_000_000) ?? 100_000) / 100_000
            let sy = Double(tile.boundedInt("sy", in: 1...10_000_000) ?? 100_000) / 100_000
            pw = min(Double(f.2) * 100, max(1, Double(info.pixelWidth) / info.dpiX * 914_400 * sx))
            ph = min(Double(f.3) * 100, max(1, Double(info.pixelHeight) / info.dpiY * 914_400 * sy))
            let align = tile[attribute: "algn"] ?? "tl"
            if ["t", "ctr", "b"].contains(align) { ox += (Double(f.2) - pw) / 2 }
            if ["tr", "r", "br"].contains(align) { ox += Double(f.2) - pw }
            if ["l", "ctr", "r"].contains(align) { oy += (Double(f.3) - ph) / 2 }
            if ["bl", "b", "br"].contains(align) { oy += Double(f.3) - ph }
            ox += Double(tile.coordinate("tx") ?? 0); oy += Double(tile.coordinate("ty") ?? 0)
            guard let image = SVGImagePlacement.render(blip, data: data, width: pw, height: ph) else { return nil }
            content = image
            let flip = tile[attribute: "flip"] ?? "none"
            if flip == "x" || flip == "xy" { content += "<g transform=\"translate(\(2 * pw) 0) scale(-1 1)\">\(image)</g>"; pw *= 2 }
            if flip == "y" || flip == "xy" { content += "<g transform=\"translate(0 \(2 * ph)) scale(1 -1)\">\(content)</g>"; ph *= 2 }
        } else {
            guard let image = SVGImagePlacement.render(blip, data: data, width: pw, height: ph) else { return nil }
            content = image
        }
        defs += "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" x=\"\(ox)\" y=\"\(oy)\" width=\"\(pw)\" height=\"\(ph)\" viewBox=\"0 0 \(pw) \(ph)\">\(content)</pattern>"
        return "url(#\(id))"
    }

    // MARK: - Tables / charts

    private func renderGraphicFrame(_ gf: XML.Element, ownedBy owner: Part,
                                    defs: inout SVGDefinitions, problems: inout SlideRenderProblems) -> String {
        guard let xfrm = gf.firstChild(named: "p:xfrm"),
              let off = xfrm.firstChild(named: "a:off"), let ext = xfrm.firstChild(named: "a:ext") else { return "" }
        let x = intAttr(off, "x"), y = intAttr(off, "y")
        let w = intAttr(ext, "cx"), h = intAttr(ext, "cy")
        let uri = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?[attribute: "uri"] ?? ""
        if uri.hasSuffix("/table"),
           let tbl = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?.firstChild(named: "a:tbl") {
            return renderTable(tbl, x: x, y: y, width: w, height: h, defs: &defs)
        }
        if uri.hasSuffix("/chart"), let plot = renderChart(gf, ownedBy: owner, x: x, y: y, w: w, h: h) {
            return plot
        }
        // Anything still unplotted — SmartArt, OLE, a chart kind with no plot
        // here — keeps the labeled placeholder. Named rather than "[object]"
        // so a thumbnail says which thing it could not draw.
        let label: String
        if uri.hasSuffix("/chart") { label = "[chart]" }
        else if uri == GraphicDataURI.diagram { label = "[SmartArt]" }
        else if uri == GraphicDataURI.ole { label = "[embedded object]" }
        else { label = "[object]" }
        problems.record("Preview uses a placeholder for \(label).")
        return box(x, y, w, h, fill: "#F2F2F2", stroke: " stroke=\"#CCCCCC\" stroke-width=\"6350\"")
            + textElement(label, x: x + w / 2, baseline: y + h / 2,
                          sizeEMU: 18 * emuPerPoint, fill: "#999999", anchor: "middle",
                          bold: false, typeface: nil)
    }

    // MARK: - Charts

    /// Fallback series colors for decks whose theme has no accents.
    private static let chartPalette = ["#4472C4", "#ED7D31", "#A5A5A5", "#FFC000", "#5B9BD5", "#70AD47"]

    /// Plot a chart part into `frame`, or nil for a kind we don't draw (the
    /// caller then falls back to the labeled placeholder). Approximate by
    /// design — this is a thumbnail renderer — but it plots the chart's real
    /// categories and series, read back out of the chart XML by `Chart`.
    ///
    /// All scaling runs in `Double` and lands through `coord`: chart values
    /// come from the file unbounded, and coordinates are only bounded to
    /// ±2^40, so multiplying two of them would overflow `Int`.
    private func renderChart(_ gf: XML.Element, ownedBy owner: Part,
                             x: Int, y: Int, w: Int, h: Int) -> String? {
        guard w > 0, h > 0,
              let rId = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
                  .firstChild(named: "c:chart")?[attribute: "r:id"],
              let rel = owner.rels.relationship(withId: rId),
              let part = try? package.part(
                  at: PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI))
        else { return nil }
        let chart = Chart(part: part, package: package)
        guard let kind = chart.plotType else { return nil }
        // A fuzzed file can declare any number of series/points; bound both
        // rather than loop over whatever it claims.
        let entries = Array(zip(chart.series, chart.seriesElements).filter { !$0.0.values.isEmpty }.prefix(32))
        let series = entries.map { $0.0 }
        let styles = entries.map { $0.1 }
        let chartNode = chart.root?.firstChild(named: "c:chart")
        let legendNode = chartNode?.firstChild(named: "c:legend")
        let pointStyles: [[Int: XML.Element]] = styles.map { node in
            var result: [Int: XML.Element] = [:]
            for point in node.children(named: "c:dPt") {
                if let index = point.firstChild(named: "c:idx")?.boundedInt("val", in: 0...511), result[index] == nil,
                   let properties = point.firstChild(named: "c:spPr") { result[index] = properties }
            }
            return result
        }
        func color(_ seriesIndex: Int, _ point: Int?) -> String {
            guard styles.indices.contains(seriesIndex) else { return seriesColor(seriesIndex) }
            let properties = styles[seriesIndex].firstChild(named: "c:spPr")
            let override = point.flatMap { pointStyles[seriesIndex][$0] }
            if override?.firstChild(named: "a:noFill") != nil { return "none" }
            if let fill = colorHex(in: override?.firstChild(named: "a:solidFill")) { return fill }
            if kind == "lineChart", let fill = colorHex(in: properties?.firstChild(named: "a:ln")?.firstChild(named: "a:solidFill")) { return fill }
            if properties?.firstChild(named: "a:noFill") != nil { return "none" }
            if let fill = colorHex(in: properties?.firstChild(named: "a:solidFill")) { return fill }
            return seriesColor(point != nil && ["pieChart", "doughnutChart"].contains(kind) ? point! : seriesIndex)
        }
        guard !series.isEmpty else { return nil }
        let categories = chart.categories
        let pointCount = series.map(\.values.count).max() ?? 0
        let catCount = Swift.min(Swift.max(categories.count, pointCount), 512)
        guard catCount > 0 else { return nil }

        let fx = Double(x), fy = Double(y), fw = Double(w), fh = Double(h)
        let title = chart.title
        let hasLegend = legendNode != nil
        let legendPosition = legendNode?.firstChild(named: "c:legendPos")?[attribute: "val"] ?? "r"
        let sideLegend = hasLegend && ["l", "r", "tr"].contains(legendPosition)
        let padX = fw * 0.06
        let padTop = fh * (title == nil ? 0.07 : 0.17) + (hasLegend && legendPosition == "t" ? fh * 0.10 : 0)
        let padBottom = fh * (hasLegend && legendPosition == "b" ? 0.22 : 0.13)
        let plotX = fx + padX + (sideLegend && legendPosition == "l" ? fw * 0.22 : 0)
        let plotY = fy + padTop
        let plotW = Swift.max(1, fw - padX * 2 - (sideLegend ? fw * 0.22 : 0))
        let plotH = Swift.max(1, fh - padTop - padBottom)

        var out = ""
        if let title {
            let titlePr = chartNode?.firstChild(named: "c:title")?.firstChild(named: "c:tx")?.firstChild(named: "c:rich")?.firstChild(named: "a:p")
            let titleStyle = titlePr?.firstChild(named: "a:r")?.firstChild(named: "a:rPr") ?? titlePr?.firstChild(named: "a:pPr")?.firstChild(named: "a:defRPr")
            let titleSize = (titleStyle?.boundedInt("sz", in: 100...40_000) ?? 1300) * 127
            out += textElement(clipLabel(title, width: w, sizeEMU: titleSize),
                               x: coord(fx + fw / 2), baseline: coord(fy + fh * 0.11),
                               sizeEMU: titleSize, fill: colorHex(in: titleStyle?.firstChild(named: "a:solidFill")) ?? "#666666", anchor: "middle",
                               bold: ["1", "true"].contains(titleStyle?[attribute: "b"] ?? ""), typeface: titleStyle?.firstChild(named: "a:latin")?[attribute: "typeface"])
        }

        switch kind {
        case "pieChart", "doughnutChart":
            out += pieBody(series[0], kind: kind, cx: plotX + plotW / 2, cy: plotY + plotH / 2,
                           radius: Swift.min(plotW, plotH) / 2 * 0.88, color: { color(0, $0) })
        case "barChart", "lineChart", "areaChart":
            let plot = chart.plots.first
            let grouping = plot?.firstChild(named: "c:grouping")?[attribute: "val"] ?? "clustered"
            let axis = chartNode?.firstChild(named: "c:plotArea")?.firstChild(named: "c:valAx")
            let scale = ValueScale(series: series, catCount: catCount, grouping: grouping, axis: axis?.firstChild(named: "c:scaling"))
            let horizontal = kind == "barChart"
                && plot?.firstChild(named: "c:barDir")?[attribute: "val"] == "bar"
            out += axes(plotX: plotX, plotY: plotY, plotW: plotW, plotH: plotH, scale: scale, axis: axis, horizontal: horizontal)
            if kind == "barChart" {
                out += barBody(series, catCount: catCount, scale: scale, horizontal: horizontal,
                               plotX: plotX, plotY: plotY, plotW: plotW, plotH: plotH, color: color)
            } else {
                let body = lineBody(series, catCount: catCount, scale: scale, filled: kind == "areaChart",
                                plotX: plotX, plotY: plotY, plotW: plotW, plotH: plotH, styles: styles, color: { color($0, nil) })
                out += "<svg x=\"\(plotX)\" y=\"\(plotY)\" width=\"\(plotW)\" height=\"\(plotH)\" viewBox=\"\(plotX) \(plotY) \(plotW) \(plotH)\" overflow=\"hidden\">\(body)</svg>"
            }
            out += categoryLabels(categories, catCount: catCount, plotX: plotX, plotW: plotW,
                                  baseY: plotY + plotH, height: fh, horizontal: horizontal, plotY: plotY, plotH: plotH)
        default:
            return nil          // radar/scatter/bubble/surface → placeholder
        }
        if hasLegend {
            let lx = sideLegend ? (legendPosition == "l" ? fx : plotX + plotW + fw * 0.02) : fx
            let ly = sideLegend ? plotY : legendPosition == "t" ? plotY - fh * 0.11 : plotY + plotH + fh * 0.08
            out += legend(series, x: lx, y: ly, width: sideLegend ? fw * 0.21 : fw, height: fh,
                labels: ["pieChart", "doughnutChart"].contains(kind) ? categories : nil, vertical: sideLegend,
                color: { ["pieChart", "doughnutChart"].contains(kind) ? color(0, $0) : color($0, nil) })
        }
        return out
    }

    /// A finite plotted value, or nil for a gap (`c:val` legally omits points).
    private static func finite(_ entry: ChartData.Series, _ index: Int) -> Double? {
        guard index < entry.values.count, let value = entry.values[index], value.isFinite else { return nil }
        return value
    }

    /// Category × series values reduced to a plotting range, honouring the
    /// plot's grouping so stacked bars scale to their stack totals.
    private struct ValueScale {
        let minimum: Double
        let range: Double
        let stacked: Bool
        let percent: Bool

        init(series: [ChartData.Series], catCount: Int, grouping: String, axis: XML.Element? = nil) {
            percent = grouping == "percentStacked"
            stacked = percent || grouping == "stacked"
            var high = 0.0, low = 0.0
            if percent {
                high = 100
            } else if stacked {
                for index in 0..<catCount {
                    var positive = 0.0, negative = 0.0
                    for s in series {
                        guard let v = SVGRenderer.finite(s, index) else { continue }
                        if v >= 0 { positive += v } else { negative += v }
                    }
                    high = Swift.max(high, positive)
                    low = Swift.min(low, negative)
                }
            } else {
                for s in series {
                    for case let v? in s.values where v.isFinite {
                        high = Swift.max(high, v)
                        low = Swift.min(low, v)
                    }
                }
            }
            if let v = axis?.firstChild(named: "c:min")?[attribute: "val"].flatMap(Double.init), v.isFinite { low = v }
            if let v = axis?.firstChild(named: "c:max")?[attribute: "val"].flatMap(Double.init), v.isFinite { high = v }
            guard high.isFinite, low.isFinite, (high - low).isFinite, high - low > 0 else {
                minimum = 0; range = 1; return
            }
            minimum = low
            range = high - low
        }

        /// Where `value` sits in the plot, 0 at the bottom edge and 1 at the top.
        func fraction(_ value: Double) -> Double {
            guard value.isFinite else { return 0 }
            return (value - minimum) / range
        }
        var zeroFraction: Double { fraction(Swift.max(Swift.min(0, minimum + range), minimum)) }
    }

    private func axes(plotX: Double, plotY: Double, plotW: Double, plotH: Double,
                      scale: ValueScale, axis: XML.Element?, horizontal: Bool) -> String {
        guard axis?.firstChild(named: "c:delete")?[attribute: "val"] != "1" else { return "" }
        let zero = horizontal ? plotX + plotW * scale.zeroFraction : plotY + plotH * (1 - scale.zeroFraction)
        var out = horizontal
            ? "<line x1=\"\(coord(zero))\" y1=\"\(coord(plotY))\" x2=\"\(coord(zero))\" y2=\"\(coord(plotY + plotH))\" stroke=\"#BFBFBF\" stroke-width=\"6350\"/>"
            : "<line x1=\"\(coord(plotX))\" y1=\"\(coord(zero))\" x2=\"\(coord(plotX + plotW))\" y2=\"\(coord(zero))\" stroke=\"#BFBFBF\" stroke-width=\"6350\"/>"
        guard let axis else { return out }
        let exponent = pow(10, floor(log10(scale.range / 5)))
        guard exponent.isFinite, exponent > 0 else { return out }
        let unit = [1.0, 2, 5, 10].first { $0 * exponent >= scale.range / 5 }! * exponent
        let requested = axis.firstChild(named: "c:majorUnit")?[attribute: "val"].flatMap(Double.init)
        let step = requested.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? unit
        let start = ceil(scale.minimum / step) * step
        let grid = axis.firstChild(named: "c:majorGridlines")
        let gridStyle = grid?.firstChild(named: "c:spPr")
        let gridLine = gridStyle?.firstChild(named: "a:ln")
        let gridColor = gridLine?.firstChild(named: "a:noFill") != nil ? "none" : colorHex(in: gridLine?.firstChild(named: "a:solidFill")) ?? "#D9D9D9"
        let gridWidth = max(0, gridLine?.coordinate("w") ?? 6350)
        let stroke = " stroke=\"\(gridColor)\" stroke-width=\"\(gridWidth)\"" + dashAttributes(gridLine, width: gridWidth)
        let format = axis.firstChild(named: "c:numFmt")?[attribute: "formatCode"] ?? "General"
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = format.contains("%") ? .percent : .decimal
        let decimals = format.split(separator: ".", maxSplits: 1).dropFirst().first?.prefix { $0 == "0" || $0 == "#" }.count ?? 0
        formatter.minimumFractionDigits = min(decimals, 8); formatter.maximumFractionDigits = format == "General" ? 6 : min(decimals, 8)
        formatter.usesGroupingSeparator = format.contains(",")
        if format.contains("$") { formatter.positivePrefix = "$"; formatter.negativePrefix = "-$" }
        for i in 0..<128 {
            let value = start + Double(i) * step
            guard value.isFinite, value <= scale.minimum + scale.range + step * 1e-8 else { break }
            let fraction = scale.fraction(value)
            let position = horizontal ? plotX + fraction * plotW : plotY + (1 - fraction) * plotH
            if grid != nil {
                out += horizontal
                    ? "<line x1=\"\(coord(position))\" y1=\"\(coord(plotY))\" x2=\"\(coord(position))\" y2=\"\(coord(plotY + plotH))\"\(stroke)/>"
                    : "<line x1=\"\(coord(plotX))\" y1=\"\(coord(position))\" x2=\"\(coord(plotX + plotW))\" y2=\"\(coord(position))\"\(stroke)/>"
            }
            if axis.firstChild(named: "c:tickLblPos")?[attribute: "val"] != "none" {
                let label = formatter.string(from: NSNumber(value: value)) ?? String(value)
                out += textElement(label, x: coord(horizontal ? position : plotX - 45_720),
                    baseline: coord(horizontal ? plotY + plotH + 152_400 : position + 38_100), sizeEMU: 10 * emuPerPoint,
                    fill: "#666666", anchor: horizontal ? "middle" : "end", bold: false, typeface: nil)
            }
        }
        return out
    }

    private func barBody(_ series: [ChartData.Series], catCount: Int, scale: ValueScale,
                         horizontal: Bool, plotX: Double, plotY: Double,
                         plotW: Double, plotH: Double, color: (Int, Int?) -> String) -> String {
        let along = horizontal ? plotH : plotW
        let slot = along / Double(catCount)
        let inset = slot * 0.16
        let bandWidth = Swift.max(1, slot - inset * 2)
        let barWidth = scale.stacked ? bandWidth : Swift.max(1, bandWidth / Double(series.count))
        let zero = scale.zeroFraction
        var out = ""
        var positiveTops = [Double](repeating: 0, count: catCount)
        var negativeTops = [Double](repeating: 0, count: catCount)

        for index in 0..<catCount {
            let bandStart = (horizontal ? plotY : plotX) + Double(horizontal ? catCount - index - 1 : index) * slot + inset
            for (s, entry) in series.enumerated() {
                guard var value = Self.finite(entry, index) else { continue }
                if scale.percent {
                    let total = series.reduce(0.0) { sum, other in
                        sum + Swift.abs(Self.finite(other, index) ?? 0)
                    }
                    value = total > 0 ? value / total * 100 : 0
                }
                // Stacked bars grow from the running top of their own sign.
                let start: Double, end: Double
                if scale.stacked {
                    if value >= 0 {
                        start = positiveTops[index]; end = start + value
                        positiveTops[index] = end
                    } else {
                        start = negativeTops[index]; end = start + value
                        negativeTops[index] = end
                    }
                } else {
                    start = 0; end = value
                }
                let startFraction = scale.stacked ? scale.fraction(start) : zero
                let endFraction = scale.fraction(end)
                let lo = max(0, min(1, Swift.min(startFraction, endFraction))), hi = max(0, min(1, Swift.max(startFraction, endFraction)))
                let offset = scale.stacked ? 0 : Double(s) * barWidth
                let fill = color(s, index)
                if horizontal {
                    out += box(coord(plotX + plotW * lo), coord(bandStart + offset),
                               coord(plotW * (hi - lo)), coord(barWidth), fill: fill)
                } else {
                    out += box(coord(bandStart + offset), coord(plotY + plotH * (1 - hi)),
                               coord(barWidth), coord(plotH * (hi - lo)), fill: fill)
                }
            }
        }
        return out
    }

    private func lineBody(_ series: [ChartData.Series], catCount: Int, scale: ValueScale,
                          filled: Bool, plotX: Double, plotY: Double,
                          plotW: Double, plotH: Double, styles: [XML.Element], color: (Int) -> String) -> String {
        // Points sit at category centers, matching where bars are drawn.
        let step = plotW / Double(catCount)
        var out = ""
        for (s, entry) in series.enumerated() {
            var points: [(Double, Double)] = []
            for index in 0..<catCount {
                guard let value = Self.finite(entry, index) else { continue }
                points.append((plotX + step * (Double(index) + 0.5),
                               plotY + plotH * (1 - scale.fraction(value))))
            }
            guard points.count > 1 else { continue }
            let path = points.map { "\(coord($0.0)),\(coord($0.1))" }.joined(separator: " ")
            let color = color(s)
            if filled {
                let baseY = plotY + plotH * (1 - scale.zeroFraction)
                out += "<polygon points=\"\(coord(points[0].0)),\(coord(baseY)) \(path) "
                    + "\(coord(points[points.count - 1].0)),\(coord(baseY))\" fill=\"\(color)\" "
                    + "fill-opacity=\"0.55\"/>"
            }
            let properties = styles[s].firstChild(named: "c:spPr")
            let ln = properties?.firstChild(named: "a:ln")
            let stroke = ln?.firstChild(named: "a:noFill") != nil ? "none" : colorHex(in: ln?.firstChild(named: "a:solidFill")) ?? color
            let lineWidth = ln?.coordinate("w") ?? 25400
            let dash = dashAttributes(ln, width: lineWidth)
            out += "<polyline points=\"\(path)\" fill=\"none\" stroke=\"\(stroke)\" "
                + "stroke-width=\"\(lineWidth)\"\(dash) stroke-linejoin=\"round\"/>"
        }
        return out
    }

    private func pieBody(_ entry: ChartData.Series, kind: String,
                         cx: Double, cy: Double, radius: Double, color: (Int) -> String) -> String {
        guard radius > 0 else { return "" }
        let values = entry.values.enumerated().compactMap { index, value -> (Int, Double)? in
            guard let value, value.isFinite, value > 0 else { return nil }; return (index, value)
        }
        let total = values.reduce(0) { $0 + $1.1 }
        guard total.isFinite, total > 0 else { return "" }
        let doughnut = kind == "doughnutChart"
        // Doughnuts are stroked arcs rather than a pie with a punched hole, so
        // they don't need to know the slide background color.
        let ringWidth = radius * 0.42
        let ringRadius = radius - ringWidth / 2
        var out = ""
        var angle = -Double.pi / 2
        for (index, value) in values {
            let sweep = value / total * 2 * Double.pi
            let end = angle + sweep
            let color = color(index)
            let r = doughnut ? ringRadius : radius
            if values.count == 1 || sweep >= 2 * Double.pi - 1e-9 {
                // A single full-circle slice degenerates as an arc path.
                out += doughnut
                    ? "<circle cx=\"\(coord(cx))\" cy=\"\(coord(cy))\" r=\"\(coord(r))\" fill=\"none\" "
                        + "stroke=\"\(color)\" stroke-width=\"\(coord(ringWidth))\"/>"
                    : "<circle cx=\"\(coord(cx))\" cy=\"\(coord(cy))\" r=\"\(coord(r))\" fill=\"\(color)\"/>"
                angle = end
                continue
            }
            let x1 = cx + r * cos(angle), y1 = cy + r * sin(angle)
            let x2 = cx + r * cos(end), y2 = cy + r * sin(end)
            let largeArc = sweep > Double.pi ? 1 : 0
            if doughnut {
                out += "<path d=\"M \(coord(x1)) \(coord(y1)) A \(coord(r)) \(coord(r)) 0 \(largeArc) 1 "
                    + "\(coord(x2)) \(coord(y2))\" fill=\"none\" stroke=\"\(color)\" "
                    + "stroke-width=\"\(coord(ringWidth))\"/>"
            } else {
                out += "<path d=\"M \(coord(cx)) \(coord(cy)) L \(coord(x1)) \(coord(y1)) "
                    + "A \(coord(r)) \(coord(r)) 0 \(largeArc) 1 \(coord(x2)) \(coord(y2)) Z\" fill=\"\(color)\"/>"
            }
            angle = end
        }
        return out
    }

    private func categoryLabels(_ categories: [String], catCount: Int, plotX: Double,
                                plotW: Double, baseY: Double, height: Double, horizontal: Bool, plotY: Double, plotH: Double) -> String {
        guard !categories.isEmpty, catCount <= 12 else { return "" }
        let step = plotW / Double(catCount)
        let size = 10 * emuPerPoint
        var out = ""
        for (index, label) in categories.prefix(catCount).enumerated() {
            out += textElement(clipLabel(label, width: coord(step), sizeEMU: size),
                               x: coord(horizontal ? plotX - 45_720 : plotX + step * (Double(index) + 0.5)),
                               baseline: coord(horizontal ? plotY + plotH / Double(catCount) * (Double(catCount - index) - 0.5) + 38_100 : baseY + height * 0.06),
                               sizeEMU: size, fill: "#808080", anchor: horizontal ? "end" : "middle",
                               bold: false, typeface: nil)
        }
        return out
    }

    private func legend(_ series: [ChartData.Series], x: Double, y: Double, width: Double,
                        height: Double, labels: [String]?, vertical: Bool, color: (Int) -> String) -> String {
        let names = labels ?? series.map(\.name)
        let entries = Array(names.prefix(6)).enumerated().filter { !$0.element.isEmpty }
        guard !entries.isEmpty else { return "" }
        let size = 10 * emuPerPoint
        let slot = vertical ? width : width / Double(entries.count)
        let swatch = height * 0.035
        var out = ""
        for (slotIndex, entry) in entries.enumerated() {
            let left = x + (vertical ? 0 : slot * Double(slotIndex)) + slot * 0.1
            let y = y + (vertical ? Double(slotIndex) * max(height * 0.08, Double(size) * 1.5) : 0)
            out += box(coord(left), coord(y + height * 0.02), coord(swatch), coord(swatch),
                       fill: color(entry.offset))
            out += textElement(clipLabel(entry.element, width: coord(slot * 0.75), sizeEMU: size),
                               x: coord(left + swatch * 1.5),
                               baseline: coord(y + height * 0.02 + swatch * 0.85),
                               sizeEMU: size, fill: "#808080", anchor: "start",
                               bold: false, typeface: nil)
        }
        return out
    }

    /// Truncate a chart label to one line at the estimated glyph advance. Axis
    /// and legend labels are single-line by nature — wrapping them would push
    /// the plot around — so this is the one place an ellipsis is still right.
    private func clipLabel(_ text: String, width: Int, sizeEMU: Int) -> String {
        let approxCharWidth = sizeEMU / 2
        guard approxCharWidth > 0, width > 0 else { return text }
        let maxChars = Swift.max(1, width / approxCharWidth)
        guard text.count > maxChars else { return text }
        return String(text.prefix(Swift.max(1, maxChars - 1))) + "…"
    }

    /// Theme accents keep charts on-brand with the deck they live in.
    private func seriesColor(_ index: Int) -> String {
        if let color = theme.accent(index % 6 + 1) { return "#" + color.hex }
        return Self.chartPalette[index % Self.chartPalette.count]
    }

    /// Land a computed `Double` back on the EMU integer grid, bounded the same
    /// way every file-read coordinate is.
    private func coord(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let bound = Double(1 << 40)
        return Int(Swift.min(Swift.max(value.rounded(), -bound), bound))
    }

    private func renderTable(_ tbl: XML.Element, x: Int, y: Int, width: Int, height: Int,
                             defs: inout SVGDefinitions) -> String {
        let cols = Array((tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol") ?? []).prefix(2048)).map { max(0, intAttr($0, "w")) }
        let rows = Array(tbl.children(named: "a:tr").prefix(2048))
        let heights = rows.map { max(0, intAttr($0, "h")) }
        let totalW = cols.reduce(0, +), totalH = heights.reduce(0, +)
        guard totalW > 0, totalH > 0, width > 0, height > 0 else { return "" }
        let properties = tbl.firstChild(named: "a:tblPr")
        let styleID = properties?.firstChild(named: "a:tableStyleId")?.textContent
        let styleRoot = (try? package.mainDocumentPart().related(by: RelType.tableStyles, in: package).dom())
            ?? package.parts.values.filter { $0.contentType == ContentType.tableStyles }.sorted { $0.uri.value < $1.uri.value }.first.flatMap { try? $0.dom() }
        let style = styleRoot?.children(named: "a:tblStyle").first { $0[attribute: "styleId"] == styleID }
        func enabled(_ key: String) -> Bool { ["1", "true"].contains(properties?[attribute: key] ?? "") }
        var out = "", cy = 0
        for (r, tr) in rows.enumerated() {
            var cx = 0
            for (c, tc) in tr.children(named: "a:tc").prefix(cols.count).enumerated() {
                defer { cx += cols[c] }
                if ["1", "true"].contains(tc[attribute: "hMerge"] ?? "") || ["1", "true"].contains(tc[attribute: "vMerge"] ?? "") { continue }
                let cs = min(cols.count - c, tc.boundedInt("gridSpan", in: 1...2048) ?? 1)
                let rs = min(rows.count - r, tc.boundedInt("rowSpan", in: 1...2048) ?? 1)
                let cw = cols[c..<(c + cs)].reduce(0, +), rh = heights[r..<(r + rs)].reduce(0, +)
                var regions = ["wholeTbl"]
                if enabled("bandRow") { regions.append((r - (enabled("firstRow") ? 1 : 0)) % 2 == 0 ? "band1H" : "band2H") }
                if enabled("bandCol") { regions.append((c - (enabled("firstCol") ? 1 : 0)) % 2 == 0 ? "band1V" : "band2V") }
                if c == 0 && enabled("firstCol") { regions.append("firstCol") }
                if c + cs == cols.count && enabled("lastCol") { regions.append("lastCol") }
                if r == 0 && enabled("firstRow") { regions.append("firstRow") }
                if r + rs == rows.count && enabled("lastRow") { regions.append("lastRow") }
                let pr = XML.Element("a:tcPr"), defaults = XML.Element("a:defRPr")
                let edges = [("lnL", "left"), ("lnR", "right"), ("lnT", "top"), ("lnB", "bottom")]
                for region in regions {
                    guard let block = style?.firstChild(named: "a:" + region) else { continue }
                    if let cellStyle = block.firstChild(named: "a:tcStyle") {
                        if let fill = cellStyle.firstChild(named: "a:fill")?.childElements.first {
                            for name in ["a:solidFill", "a:noFill", "a:gradFill"] { pr.removeChildren(named: name) }
                            pr.appendElement(fill.deepCopy())
                        }
                        for (edge, name) in edges {
                            let borders = cellStyle.firstChild(named: "a:tcBdr")
                            let inside = edge == "lnL" && c > 0 || edge == "lnR" && c + cs < cols.count ? "insideV" :
                                edge == "lnT" && r > 0 || edge == "lnB" && r + rs < rows.count ? "insideH" : name
                            if let ln = borders?.firstChild(named: "a:" + inside)?.firstChild(named: "a:ln") {
                                pr.removeChildren(named: "a:" + edge)
                                let copy = XML.Element("a:" + edge, attributes: ln.attributes.map { ($0.name, $0.value) }, children: ln.childElements.map { .element($0.deepCopy()) })
                                pr.appendElement(copy)
                            }
                        }
                    }
                    if let tx = block.firstChild(named: "a:tcTxStyle") {
                        for attr in tx.attributes {
                            if ["b", "i"].contains(attr.name) {
                                if attr.value != "def" { defaults[attribute: attr.name] = attr.value == "on" ? "1" : "0" }
                            } else { defaults[attribute: attr.name] = attr.value }
                        }
                        if let color = tx.childElements.first(where: { SVGPaint.colorElements.contains($0.name) }) {
                            defaults.removeChildren(named: "a:solidFill")
                            defaults.appendElement(XML.Element("a:solidFill", children: [.element(color.deepCopy())]))
                        }
                        if let ref = tx.firstChild(named: "a:fontRef"), let idx = ref[attribute: "idx"] {
                            defaults.removeChildren(named: "a:latin")
                            defaults.appendElement(XML.Element("a:latin", attributes: [("typeface", idx == "major" ? "+mj-lt" : "+mn-lt")]))
                        }
                    }
                }
                if let direct = tc.firstChild(named: "a:tcPr") {
                    for attr in direct.attributes { pr[attribute: attr.name] = attr.value }
                    for child in direct.childElements {
                        if ["a:solidFill", "a:noFill", "a:gradFill"].contains(child.name) {
                            for name in ["a:solidFill", "a:noFill", "a:gradFill"] { pr.removeChildren(named: name) }
                        } else { pr.removeChildren(named: child.name) }
                        pr.appendElement(child.deepCopy())
                    }
                }
                let fill = paint(for: pr, box: (cx, cy, cw, rh), defs: &defs) ?? "none"
                out += box(cx, cy, cw, rh, fill: fill)
                for (index, edge) in edges.enumerated() {
                    guard let ln = pr.firstChild(named: "a:" + edge.0) else { continue }
                    let wrapper = XML.Element("p:spPr", children: [.element(XML.Element("a:ln", attributes: ln.attributes.map { ($0.name, $0.value) }, children: ln.childElements.map { .element($0.deepCopy()) }))])
                    let stroke = strokeAttrs(wrapper)
                    guard !stroke.isEmpty else { continue }
                    let x1 = index == 1 ? cx + cw : cx, y1 = index == 3 ? cy + rh : cy
                    let x2 = index < 2 ? x1 : cx + cw, y2 = index < 2 ? cy + rh : y1
                    out += "<line x1=\"\(x1)\" y1=\"\(y1)\" x2=\"\(x2)\" y2=\"\(y2)\"\(stroke)/>"
                }
                if let source = tc.firstChild(named: "a:txBody") {
                    let body = source.deepCopy()
                    let bp = body.firstChild(named: "a:bodyPr") ?? XML.Element("a:bodyPr")
                    if body.firstChild(named: "a:bodyPr") == nil { body.appendElement(bp) }
                    for (margin, inset, fallback) in [("marL", "lIns", 91440), ("marR", "rIns", 91440), ("marT", "tIns", 45720), ("marB", "bIns", 45720)] {
                        bp[attribute: inset] = String(pr.coordinate(margin) ?? fallback)
                    }
                    bp[attribute: "anchor"] = pr[attribute: "anchor"] ?? "t"
                    let inherited = XML.Element("a:lstStyle", children: [.element(XML.Element("a:defPPr", children: [.element(defaults)]))])
                    out += renderText(body, box: (cx, cy, cw, rh), inheriting: [inherited], respectInsets: true)
                }
            }
            cy += heights[r]
        }
        return "<g transform=\"translate(\(x) \(y)) scale(\(Double(width) / Double(totalW)) \(Double(height) / Double(totalH)))\">\(out)</g>"
    }

    // Style references are one-based theme matrix indices. Resolve into a detached
    // preview-only tree so phClr substitution never dirties the source package.
    private var formatScheme: XML.Element? {
        try? theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")
    }

    private func styleEntry(_ reference: XML.Element?, list: String, backgroundList: String? = nil) -> XML.Element? {
        guard let index = reference?[attribute: "idx"].flatMap(Int.init), index > 0, index != 1000 else { return nil }
        let background = index >= 1001 && backgroundList != nil
        let offset = background ? index - 1001 : index - 1
        let entries = formatScheme?.firstChild(named: background ? (backgroundList ?? list) : list)?.childElements ?? []
        guard entries.indices.contains(offset) else { return nil }
        let copy = entries[offset].deepCopy()
        if let color = reference?.childElements.first(where: { SVGPaint.colorElements.contains($0.name) }) {
            var stack = [copy]
            while let element = stack.popLast() {
                for child in element.childElements {
                    if child.name == "a:schemeClr", child[attribute: "val"] == "phClr" {
                        let replacement = color.deepCopy()
                        for transform in child.childElements { replacement.appendElement(transform.deepCopy()) }
                        if let index = element.children.firstIndex(where: { if case .element(let e) = $0 { return e === child }; return false }) {
                            element.children[index] = .element(replacement)
                        }
                    } else { stack.append(child) }
                }
            }
        }
        return copy
    }

    private func effectiveFill(_ properties: XML.Element, reference: XML.Element?) -> XML.Element {
        let fills = ["a:solidFill", "a:gradFill", "a:blipFill", "a:pattFill", "a:grpFill", "a:noFill"]
        guard !properties.childElements.contains(where: { fills.contains($0.name) }),
              let fill = styleEntry(reference, list: "a:fillStyleLst", backgroundList: "a:bgFillStyleLst") else { return properties }
        return XML.Element("p:spPr", children: [.element(fill)])
    }

    private func effectiveLine(_ properties: XML.Element, reference: XML.Element?) -> XML.Element {
        guard let inherited = styleEntry(reference, list: "a:lnStyleLst") else { return properties }
        if let direct = properties.firstChild(named: "a:ln") {
            // Direct attributes/children override the theme property by property.
            for attribute in direct.attributes { inherited[attribute: attribute.name] = attribute.value }
            for child in direct.childElements {
                if ["a:noFill", "a:solidFill", "a:gradFill", "a:pattFill"].contains(child.name) {
                    inherited.children.removeAll { node in
                        if case .element(let e) = node { return ["a:noFill", "a:solidFill", "a:gradFill", "a:pattFill"].contains(e.name) }
                        return false
                    }
                } else {
                    inherited.children.removeAll { if case .element(let e) = $0 { return e.name == child.name }; return false }
                }
                inherited.appendElement(child.deepCopy())
            }
        }
        return XML.Element("p:spPr", children: [.element(inherited)])
    }

    // MARK: - Paint / helpers

    private func paint(for pr: XML.Element, box f: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String? {
        if let solid = pr.firstChild(named: "a:solidFill") { return colorHex(in: solid) }
        if let grad = pr.firstChild(named: "a:gradFill") { return gradientRef(grad, box: f, defs: &defs) }
        if pr.firstChild(named: "a:blipFill") != nil { return "#DDDDDD" }   // image fill → neutral
        if pr.firstChild(named: "a:noFill") != nil { return nil }
        return nil
    }

    private func gradientRef(_ grad: XML.Element, box f: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String {
        let stops = grad.firstChild(named: "a:gsLst")?.children(named: "a:gs") ?? []
        let id = defs.nextID("g")
        let isRadial = grad.firstChild(named: "a:path") != nil
        var stopSVG = ""
        for gs in stops {
            let pos = Double(gs.boundedInt("pos", in: 0...100_000) ?? 0) / 100_000
            let color = SVGPaint.resolve(in: gs, theme: theme)
            stopSVG += "<stop offset=\"\(pos)\" stop-color=\"\(color?.hex ?? "#000000")\" stop-opacity=\"\(color?.opacity ?? 1)\"/>"
        }
        if isRadial {
            defs += "<radialGradient id=\"\(id)\">\(stopSVG)</radialGradient>"
        } else {
            let line = grad.firstChild(named: "a:lin")
            let vector = SVGPaint.gradientVector(line, frame: f)
            defs += "<linearGradient id=\"\(id)\" gradientUnits=\"userSpaceOnUse\" x1=\"\(vector.0)\" y1=\"\(vector.1)\" x2=\"\(vector.2)\" y2=\"\(vector.3)\">\(stopSVG)</linearGradient>"
        }
        return "url(#\(id))"
    }

    private func colorHex(in container: XML.Element?) -> String? {
        SVGPaint.resolve(in: container, theme: theme)?.css
    }

    private func strokeAttrs(_ spPr: XML.Element) -> String {
        guard let ln = spPr.firstChild(named: "a:ln"), ln.firstChild(named: "a:noFill") == nil,
              let color = colorHex(in: ln.firstChild(named: "a:solidFill")) else { return "" }
        let width = ln.coordinate("w") ?? 12700
        return " stroke=\"\(color)\" stroke-width=\"\(max(0, width))\"" + dashAttributes(ln, width: width)
    }

    private func dashAttributes(_ line: XML.Element?, width: Int) -> String {
        let patterns: [String: [Int]] = ["dot": [1, 3], "sysDot": [1, 1], "dash": [4, 3], "sysDash": [3, 1], "lgDash": [8, 3], "dashDot": [4, 3, 1, 3], "lgDashDot": [8, 3, 1, 3], "lgDashDotDot": [8, 3, 1, 3, 1, 3]]
        guard let name = line?.firstChild(named: "a:prstDash")?[attribute: "val"], let pattern = patterns[name] else { return "" }
        return " stroke-dasharray=\"" + pattern.map { String($0 * max(1, width)) }.joined(separator: " ") + "\""
    }

    private func frame(of spPr: XML.Element) -> (Int, Int, Int, Int) {
        guard let xfrm = spPr.firstChild(named: "a:xfrm"),
              let off = xfrm.firstChild(named: "a:off"), let ext = xfrm.firstChild(named: "a:ext") else {
            return (0, 0, 0, 0)
        }
        return (intAttr(off, "x"), intAttr(off, "y"), intAttr(ext, "cx"), intAttr(ext, "cy"))
    }

    /// Every coordinate the renderer reads goes through here, bounded.
    ///
    /// The renderer then adds, subtracts and accumulates these values freely
    /// (`x + inset`, `cx += cw`, `x + w / 2`), and Swift's `+` traps on
    /// overflow. Bounding at the single point where file bytes become numbers
    /// is what makes all of that arithmetic safe, rather than clamping each
    /// expression. A coordinate outside the bound reads as 0 — this is a
    /// preview renderer, and an absurd frame is not worth a crash.
    private func intAttr(_ e: XML.Element, _ name: String) -> Int {
        e.coordinate(name) ?? 0
    }

    private func box(_ x: Int, _ y: Int, _ w: Int, _ h: Int, fill: String, stroke: String = "") -> String {
        "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" fill=\"\(fill)\"\(stroke)/>"
    }

    private func escape(_ s: String) -> String {
        var out = ""
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(c)
            }
        }
        return out
    }
}

/// Broken inheritance and detected content approximations in an SVG preview.
///
/// `renderSVG(slideAt:pixelWidth:)` always produces an SVG, even from a deck
/// whose inheritance is broken — but a broken link means everything the slide
/// inherits (its background, its placeholder positions, its theme colours) is
/// missing from that SVG, with nothing in the output to say so. To a viewer the
/// slide then looks like Rostrum rendered it wrong, when really the deck is
/// damaged. These flags let a caller tell the two apart. An empty value
/// (`isEmpty`) means no supported diagnostic fired, not pixel-perfect fidelity.
public struct SlideRenderProblems: Sendable, Equatable {
    /// The slide names no layout, or the layout part it names could not be
    /// loaded. Nothing the layout would have contributed was drawn.
    public var layoutUnresolved: Bool

    /// The layout loaded, but it names no master, or the master part it names
    /// could not be loaded. Nothing the master would have contributed was drawn.
    public var masterUnresolved: Bool

    /// Content the preview omitted or approximated. The original file is unchanged.
    public var unsupportedContent: [String]

    public var messages: [String] {
        (layoutUnresolved ? ["Preview could not load the slide layout."] : [])
        + (masterUnresolved ? ["Preview could not load the slide master."] : [])
        + unsupportedContent
    }

    /// No detected problems; not a guarantee of PowerPoint rendering equivalence.
    public var isEmpty: Bool { messages.isEmpty }

    fileprivate mutating func record(_ message: String) {
        if !unsupportedContent.contains(message) { unsupportedContent.append(message) }
    }

    public init(layoutUnresolved: Bool = false, masterUnresolved: Bool = false, unsupportedContent: [String] = []) {
        self.layoutUnresolved = layoutUnresolved
        self.masterUnresolved = masterUnresolved
        self.unsupportedContent = unsupportedContent
    }
}

public extension Presentation {
    /// Render one slide to a self-contained SVG string (thumbnails / visual diff).
    func renderSVG(slideAt index: Int, pixelWidth: Int = 1280) throws -> String {
        try renderSVGReportingProblems(slideAt: index, pixelWidth: pixelWidth).svg
    }

    /// Render one slide, reporting broken inheritance and detected preview limits.
    ///
    /// The `svg` is exactly what `renderSVG(slideAt:pixelWidth:)` returns —
    /// this is the same render, with the diagnostics kept instead of dropped.
    /// `problems` names any broken link (see `SlideRenderProblems`), so a
    /// caller can tell a damaged deck apart from one rendered wrong. A slide
    /// with a broken chain still renders; it just comes back without whatever
    /// it would have inherited.
    func renderSVGReportingProblems(slideAt index: Int, pixelWidth: Int = 1280)
        throws -> (svg: String, problems: SlideRenderProblems) {
        try SVGRenderer(slidePart: slides[index].part, slideSize: slideSize,
                        theme: slides[index].master?.theme ?? theme, package: package, fonts: fonts,
                        slideNumber: index + 1).render(pixelWidth: pixelWidth)
    }

    /// Write one `slide-N.svg` per slide into `directory`; returns the URLs.
    @discardableResult
    func exportSVG(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var urls: [URL] = []
        for i in 0..<slides.count {
            let url = directory.appendingPathComponent(String(format: "slide-%02d.svg", i + 1))
            try renderSVG(slideAt: i).write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }
        return urls
    }
}
