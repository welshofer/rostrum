import Foundation

/// Locale-independent SVG numbers without invoking a locale/ICU formatter for
/// every text coordinate. Four fractional digits exceed the layout precision.
enum SVGNumber {
    static func decimal(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value.rounded() == value, abs(value) < 1e15 { return String(Int64(value)) }
        guard abs(value) < 9e14 else { return String(value) }
        let units = Int64((value * 10000).rounded(.toNearestOrEven))
        let magnitude = units.magnitude
        let fraction = String(magnitude % 10000)
        return (value.sign == .minus ? "-" : "") + String(magnitude / 10000)
            + "." + String(repeating: "0", count: 4 - fraction.count) + fraction
    }
}

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
    var notesContext: NotesPageRenderContext? = nil

    private let emuPerPoint = 12700
    private let diagnostics = RenderDiagnosticCollector()

    func render(pixelWidth: Int) throws -> (svg: String, problems: SlideRenderProblems) {
        // Not for the value: this is the one call that surfaces a malformed
        // slide part as a thrown error. Everything below reaches the tree
        // through `existingSpTree`, which swallows the parse with `try?` and
        // would render a silently blank slide instead.
        _ = try slidePart.dom()
        diagnostics.reset()
        diagnostics.location = FidelityLocation(slideIndex: slideNumber - 1,
            partURI: slidePart.uri.description, path: notesContext == nil ? "/p:sld" : "/p:notes")
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
        diagnostics.themeEffectOverrideProblem = themeEffectOverrideProblem(in: [slidePart, chain.layout].compactMap { $0 })
        if notesContext == nil && (inheritedProblems.layoutUnresolved || inheritedProblems.masterUnresolved) {
            diagnostics.record(.unresolvedInheritance, .missingResource, "The slide layout/master inheritance chain is incomplete.")
        }
        for owner in [slidePart, chain.layout, chain.master].compactMap({ $0 }) {
            guard let background = (try? owner.dom())?.firstChild(named: "p:cSld")?.firstChild(named: "p:bg") else { continue }
            diagnostics.inspect(background, owner: owner, slideIndex: slideNumber - 1,
                path: "/p:cSld/p:bg", package: package)
            if let reference = background.firstChild(named: "p:bgRef"), let index = reference[attribute: "idx"].flatMap(Int.init),
               let format = (try? theme.part.dom())?.firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme") {
                let list = index >= 1001 ? "a:bgFillStyleLst" : "a:fillStyleLst"
                let offset = index >= 1001 ? index - 1001 : index - 1
                if let fills = format.firstChild(named: list)?.childElements, fills.indices.contains(offset) {
                    diagnostics.inspect(fills[offset], owner: theme.part, slideIndex: slideNumber - 1,
                        path: "/a:theme/a:themeElements/a:fmtScheme/\(list)[\(offset + 1)]", package: package)
                }
            }
            break
        }
        body += box(0, 0, w, h,
                    fill: backgroundFill(chain: chain, box: (0, 0, w, h), defs: &defs) ?? "#FFFFFF")

        if showsMasterShapes(chain: chain), let master = chain.master {
            body += renderInherited(master, defs: &defs, problems: &problems)
        }
        if let layout = chain.layout {
            body += renderInherited(layout, defs: &defs, problems: &problems)
        }

        if let spTree = Slide.existingSpTree(of: slidePart) {
            for (index, child) in spTree.childElements.enumerated() {
                diagnostics.inspect(child, owner: slidePart, slideIndex: slideNumber - 1,
                    path: "/p:cSld/p:spTree/\(child.name)[\(index + 1)]", package: package)
                body += renderNode(child, ownedBy: slidePart, defs: &defs, problems: &problems)
            }
        }

        defs += diagnostics.fontDefinitions
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(pixelWidth)\" height=\"\(pxH)\" "
            + "viewBox=\"0 0 \(w) \(h)\"><defs>\(defs)</defs>\(body)</svg>"
        problems.fidelityIssues += diagnostics.issues
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
        if let notesContext { return ((nil, notesContext.master), notesContext.problems) }
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
        let parts = [slidePart, chain.layout, chain.master].compactMap { $0 }
        guard let selected = BackgroundResolver.fill(chain: parts, theme: theme) else { return nil }
        if let blip = selected.paint.firstChild(named: "a:blipFill") {
            return imagePattern(blip, ownedBy: selected.owner, box: f, defs: &defs)
        }
        return paint(for: selected.paint, box: f, defs: &defs)
    }

    /// Whether the master's shapes are drawn — a layout or slide can switch
    /// them off with `showMasterSp="0"`, which is how a full-bleed layout drops
    /// the master's furniture.
    private func showsMasterShapes(chain: (layout: Part?, master: Part?)) -> Bool {
        for part in [slidePart, chain.layout].compactMap({ $0 }) {
            let visibility = (try? part.dom())?[attribute: "showMasterSp"]
            if visibility == "0" || (notesContext != nil && visibility == "false") { return false }
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
        for (index, child) in tree.childElements.enumerated() {
            if Placeholders.phElement(of: child) != nil { continue }
            diagnostics.inspect(child, owner: part, slideIndex: slideNumber - 1,
                path: "/p:cSld/p:spTree/\(child.name)[\(index + 1)]", package: package)
            out += renderNode(child, ownedBy: part, defs: &defs, problems: &problems, inherited: true)
        }
        return out
    }

    // MARK: - Shape tree and transforms

    private func renderNode(_ node: XML.Element, ownedBy owner: Part, defs: inout SVGDefinitions,
                            problems: inout SlideRenderProblems, inherited: Bool = false,
                            depth: Int = 0, flippedTextH: Bool = false, flippedTextV: Bool = false) -> String {
        guard !ShapeCollection.isHidden(node) else { return "" }
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
            if properties?.firstChild(named: "a:custGeom") == nil && !SVGPresetGeometry.supported.contains(preset) {
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
        let sp = owner === slidePart ? notesContext?.effectiveShape(sp) ?? sp : sp
        if notesContext != nil {
            let location = diagnostics.location
            if let context = notesContext, owner === slidePart, let master = context.master {
                for style in context.styles(for: sp) {
                    let wrapper = XML.Element("p:sp", children: [.element(style)])
                    diagnostics.inspect(wrapper, owner: master, slideIndex: slideNumber - 1,
                        path: "/p:notesMaster/" + style.name, package: package)
                }
            }
            diagnostics.inspect(sp, owner: owner, slideIndex: slideNumber - 1, path: location.path, package: package)
        }
        guard let spPr = sp.firstChild(named: "p:spPr") else { return "" }
        diagnoseReferencedEffects(of: sp, properties: spPr)
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
        if let notesContext, NotesPageRenderContext.placeholderType(sp) == "sldImg" {
            if NotesPageRenderContext.suppressesSlideImage(spPr) { return out }
            // Native Office notes images keep slide proportions and paint the
            // unused image frame white, even when its shape has a:noFill.
            out += geometry(prst, f, fill: fill ?? "#FFFFFF", stroke: "")
            if prst != "rect" { diagnostics.record(.unsupportedGeometry, .approximation, "Slide-image placeholder clipping to non-rectangular geometry is not rendered.") }
            out += "<image x=\"\(f.0)\" y=\"\(f.1)\" width=\"\(f.2)\" height=\"\(f.3)\" preserveAspectRatio=\"xMidYMid meet\" href=\"\(notesContext.thumbnail)\"/>"
            // Draw the inherited/local image frame above the thumbnail.
            if !stroke.isEmpty { out += geometry(prst, f, fill: "none", stroke: stroke) }
        } else {
        if fill != nil || !stroke.isEmpty {
            if let custom = spPr.firstChild(named: "a:custGeom") {
                if let paths = SVGCustomGeometry.paths(custom, width: Double(f.2), height: Double(f.3)) {
                    out += SVGCustomGeometry.render(paths, x: f.0, y: f.1, fill: fill ?? "none", stroke: stroke)
                } else {
                    diagnostics.record(.unsupportedGeometry, .approximation, "Custom path commands or coordinates are unsupported; using a rectangle.")
                    problems.record("Preview approximates unsupported custom geometry as a rectangle.")
                    out += geometry("rect", f, fill: fill ?? "none", stroke: stroke)
                }
            } else {
                out += SVGPresetGeometry.render(prst, adjustments: preset?.firstChild(named: "a:avLst"),
                                               frame: f, fill: fill ?? "none", stroke: stroke)
            }
        }
        if let txBody = sp.firstChild(named: "p:txBody") {
            if !txBody.textContent.isEmpty, let rect = spPr.firstChild(named: "a:custGeom")?.firstChild(named: "a:rect"),
               ["l", "t", "r", "b"].contains(where: { rect[attribute: $0] != $0 }) {
                diagnostics.record(.unsupportedGeometry, .approximation, "Custom geometry text rectangle is not resolved; using the shape bounds.")
            }
            let textFrame = ShapeTransform.rect(sp.firstChild(named: "dsp:txXfrm")).map { ($0.x.rawValue, $0.y.rawValue, $0.width.rawValue, $0.height.rawValue) }
                ?? SVGPresetGeometry.textFrame(prst, adjustments: preset?.firstChild(named: "a:avLst"), frame: f)
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
        }
        return out
    }

    /// Theme effects are not descendants of the shape inspected by the
    /// diagnostic scanner. Report the active reference at the referring shape,
    /// including inherited layout/master furniture. Direct effect properties
    /// override the corresponding theme component, even when explicitly empty.
    private func diagnoseReferencedEffects(of shape: XML.Element, properties: XML.Element) {
        guard let reference = shape.firstChild(named: "p:style")?.firstChild(named: "a:effectRef") else { return }
        let here = diagnostics.location
        let location = FidelityLocation(slideIndex: here.slideIndex, partURI: here.partURI,
            shapeID: here.shapeID, path: here.path + "/p:style/a:effectRef")
        guard let index = reference[attribute: "idx"].flatMap(Int.init), index >= 0 else {
            diagnostics.record(.unresolvedInheritance, .missingResource, "The shape's theme effect reference is invalid.", at: location)
            return
        }
        guard index > 0 else { return }
        if let problem = diagnostics.themeEffectOverrideProblem {
            diagnostics.record(.unresolvedInheritance, .approximation, problem, at: location)
            return
        }
        guard let styles = (try? theme.part.dom())?.firstChild(named: "a:themeElements")?
                .firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst")?.children(named: "a:effectStyle"),
              styles.indices.contains(index - 1) else {
            diagnostics.record(.unresolvedInheritance, .missingResource, "The shape's theme effect style could not be resolved.", at: location)
            return
        }
        for component in styles[index - 1].childElements {
            guard ["a:effectLst", "a:effectDag", "a:scene3d", "a:sp3d"].contains(component.name) else { continue }
            let alternatives = ["a:effectLst", "a:effectDag"].contains(component.name)
                ? ["a:effectLst", "a:effectDag"] : [component.name]
            guard !alternatives.contains(where: { properties.firstChild(named: $0) != nil }),
                  RenderDiagnosticCollector.hasEffectContent(component) else { continue }
            diagnostics.record(.omittedEffect, .omission,
                "Referenced theme effect style \(index) in \(theme.part.uri) is not rendered.", at: location)
            break
        }
    }

    /// This renderer does not yet apply themeOverride format schemes. Check
    /// them once per render, so a shape cannot be certified from an inactive
    /// master effect style. Color/font-only overrides do not replace effects.
    private func themeEffectOverrideProblem(in owners: [Part]) -> String? {
        let type = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/themeOverride"
        let drawingNamespace = "http://schemas.openxmlformats.org/drawingml/2006/main"
        func scope(of element: XML.Element, inheriting parent: [String: String] = [:]) -> [String: String] {
            var scope = parent
            for attribute in element.attributes {
                if attribute.name == "xmlns" { scope[""] = attribute.value }
                else if attribute.name.hasPrefix("xmlns:") { scope[String(attribute.name.dropFirst(6))] = attribute.value }
            }
            return scope
        }
        func drawingName(_ element: XML.Element, in scope: [String: String]) -> String? {
            let pieces = element.name.split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count == 1 || pieces.count == 2 else { return nil }
            let prefix = pieces.count == 2 ? String(pieces[0]) : ""
            return scope[prefix] == drawingNamespace ? String(pieces.last!) : nil
        }
        for owner in owners {
            let relationships = owner.rels.items.filter { $0.type == type }
            guard !relationships.isEmpty else { continue }
            guard relationships.count == 1, let reference = relationships.first,
                  !reference.isExternal,
                  let part = try? package.part(at: PackURI.resolve(target: reference.target, relativeTo: owner.uri.baseURI)),
                  let root = try? part.dom(), drawingName(root, in: scope(of: root)) == "themeOverride" else {
                return "The theme override referenced by \(owner.uri) cannot be resolved for shape effects."
            }
            let rootScope = scope(of: root)
            if root.childElements.contains(where: { drawingName($0, in: scope(of: $0, inheriting: rootScope)) == "fmtScheme" }) {
                return "The format-scheme theme override in \(part.uri) is not applied to shape effects by this preview."
            }
        }
        return nil
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

    /// The default run properties a placeholder's text inherits.
    ///
    /// Resolution order is PowerPoint's: the layout's matching placeholder
    /// `a:lstStyle`, then the master's `p:txStyles` entry for that class of
    /// placeholder. Without this every inherited run falls back to 18pt dark
    /// grey, which is why a deck rebuilt on a template's layouts renders in the
    /// renderer's defaults instead of the template's typography — the one thing
    /// applying a template is supposed to change.
    private func inheritedRunDefaults(for sp: XML.Element, ownedBy owner: Part) -> XML.Element? {
        guard owner === slidePart else { return nil }
        let styles = notesContext?.styles(for: sp) ?? RichTextLayout.inheritedStyles(for: sp, owner: owner, package: package)
        guard !styles.isEmpty else { return nil }
        let resolved = XML.Element("rostrum:inheritedStyles")
        for style in styles { resolved.appendElement(style) }
        return resolved
    }

    private func geometry(_ prst: String, _ f: (Int, Int, Int, Int), fill: String, stroke: String) -> String {
        let (x, y, w, h) = f
        switch prst {
        case "ellipse":
            return "<ellipse cx=\"\(x + w / 2)\" cy=\"\(y + h / 2)\" rx=\"\(w / 2)\" ry=\"\(h / 2)\" fill=\"\(fill)\"\(stroke)/>"
        case "roundRect":
            let r = Swift.min(w, h) / 8
            return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"\(r)\" fill=\"\(fill)\"\(stroke)/>"
        default:
            return box(x, y, w, h, fill: fill, stroke: stroke)
        }
    }

    // MARK: - Text (wrapped on real metrics when the typeface is registered,
    // else on a character-width estimate)

    private func renderText(_ txBody: XML.Element, box f: (Int, Int, Int, Int),
                            inheriting defaults: XML.Element? = nil, fontReference: XML.Element? = nil, respectInsets: Bool = false,
                            insets: (left: Double, top: Double, right: Double, bottom: Double)? = nil,
                            verticalAnchor: String? = nil) -> String {
        var inherited = defaults.map { $0.name == "rostrum:inheritedStyles" ? $0.childElements : [$0] } ?? []
        if let reference = fontReference {
            let properties = XML.Element("a:defRPr")
            if let color = reference.childElements.first(where: { SVGPaint.colorElements.contains($0.name) }) {
                properties.appendElement(XML.Element("a:solidFill", children: [.element(color.deepCopy())]))
            }
            if let index = reference[attribute: "idx"], ["major", "minor"].contains(index) {
                properties.appendElement(XML.Element("a:latin", attributes: [("typeface", index == "major" ? "+mj-lt" : "+mn-lt")]))
            }
            let style = XML.Element("a:lstStyle")
            for level in 1...9 { style.appendElement(XML.Element("a:lvl\(level)pPr", children: [.element(properties.deepCopy())])) }
            inherited.insert(style, at: 0)
        }
        let layout = RichTextLayout(textBody: txBody,
            width: Double(f.2) / Double(emuPerPoint), height: Double(f.3) / Double(emuPerPoint),
            fonts: fonts, theme: theme, inheritedStyles: inherited,
            slideNumber: slideNumber, maxLines: 64, insets: insets, verticalAnchor: verticalAnchor)
        diagnostics.text(layout)
        let decimal = SVGNumber.decimal
        // A narrow table cell can produce many one-span lines. Scope one
        // inherited policy to this text body when every emitted run agrees.
        let blockDisablesLigatures = layout.lines.count > 1
            && layout.lines.contains { !$0.spans.isEmpty }
            && layout.lines.allSatisfy { $0.spans.allSatisfy { !$0.run.usesStandardLigatures } }
        let ligatureStyle = " style=\"font-feature-settings: 'liga' 0\""
        let text = layout.lines.map { line in
            let lineDisablesLigatures = !blockDisablesLigatures && !line.spans.isEmpty
                && line.spans.allSatisfy { !$0.run.usesStandardLigatures }
            let inheritsDisabled = blockDisablesLigatures || lineDisablesLigatures
            let baseline = Double(f.1) + line.baseline * Double(emuPerPoint)
            var result = "<text transform=\"translate(\(f.0),\(decimal(baseline))) scale(\(emuPerPoint))\" xml:space=\"preserve\""
                + (lineDisablesLigatures ? ligatureStyle : "") + ">"
            var usesViewerAdvances = false
            for span in line.spans {
                let run = span.run
                let embedded = run.fontFamily.flatMap {
                    diagnostics.embeddedFamily(for: FontFaceKey(family: $0, bold: run.bold, italic: run.italic), fonts: fonts)
                }
                if !span.followsPreviousRun { usesViewerAdvances = false }
                result += "<tspan"
                // Once a run uses an unregistered viewer font, let adjacent
                // runs follow its actual advance. An estimated absolute x can
                // overlap the preceding glyphs. Tabs and bullets reset flow.
                if !usesViewerAdvances { result += " x=\"\(decimal(span.x))\"" }
                result += diagnostics.textAttributes.attributes(for: run, family: embedded ?? run.fontFamily, inheritsDisabledStandardLigatures: inheritsDisabled)
                // An estimated width is useful for wrapping, but must not
                // squeeze the viewer's real glyphs into that estimate.
                let measured = run.fontFamily.flatMap {
                    fonts.previewFace(for: FontFaceKey(family: $0, bold: run.bold, italic: run.italic))
                } != nil
                if measured, span.width > 0 { result += " textLength=\"\(decimal(span.width))\" lengthAdjust=\"spacingAndGlyphs\"" }
                usesViewerAdvances = usesViewerAdvances || !measured
                result += ">" + escape(run.text) + "</tspan>"
            }
            return result + "</text>"
        }.joined()
        return blockDisablesLigatures ? "<g" + ligatureStyle + ">" + text + "</g>" : text
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
        diagnoseReferencedEffects(of: pic, properties: spPr)
        let f = frame(of: spPr)
        guard let fill = imagePattern(blip, ownedBy: owner, box: f, defs: &defs) else {
            problems.record("Preview could not resolve a picture or its crop bounds."); return ""
        }
        let geom = spPr.firstChild(named: "a:prstGeom")
        return SVGPresetGeometry.render(geom?[attribute: "prst"] ?? "rect", adjustments: geom?.firstChild(named: "a:avLst"), frame: f, fill: fill, stroke: strokeAttrs(spPr))
    }

    /// Read supported embedded raster bytes without recoding. Unsupported
    /// formats remain preserved in the package, but are not mislabeled PNGs.
    private func imageResource(rId: String, ownedBy owner: Part) -> (url: String, nativeSize: (width: Double, height: Double))? {
        guard let resource = diagnostics.images.resolve(rId, owner: owner, package: package),
              let size = resource.nativeSize, let url = diagnostics.images.url(for: resource) else { return nil }
        return (url, size)
    }

    /// Crop and stretch share ImagePlacement with picture editing. Tile uses
    /// the image's physical native size, percentage scale, alignment, offsets
    /// and optional alternating mirror tiles. SVG preserves intrinsic alpha.
    private func imagePattern(_ blip: XML.Element, ownedBy owner: Part,
                              box frame: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String? {
        guard let node = blip.firstChild(named: "a:blip"), let rId = SVGEmbeddedImage.reference(in: node),
              let resource = imageResource(rId: rId, ownedBy: owner), frame.2 > 0, frame.3 > 0 else { return nil }
        // Definitions only grow; byte count gives unique IDs without rescanning
        // all preceding base64 image data for extended grapheme clusters.
        let id = defs.nextID("image")
        if let tile = blip.firstChild(named: "a:tile") {
            let crop = PictureCrop.read(blip.firstChild(named: "a:srcRect"))
            guard crop.valid else { return nil }
            let sx = Double(tile.boundedInt("sx", in: 1...Int(Int32.max)) ?? 100000) / 100000
            let sy = Double(tile.boundedInt("sy", in: 1...Int(Int32.max)) ?? 100000) / 100000
            let width = resource.nativeSize.width * sx * (1 - crop.left - crop.right)
            let height = resource.nativeSize.height * sy * (1 - crop.top - crop.bottom)
            guard width.isFinite, height.isFinite, width >= 1, height >= 1 else { return nil }
            let flip = tile[attribute: "flip"] ?? "none"
            let mirrorX = flip == "x" || flip == "xy", mirrorY = flip == "y" || flip == "xy"
            let alignment = tile[attribute: "algn"] ?? "tl"
            let ax: Double = ["t", "ctr", "b"].contains(alignment) ? 0.5 : ["tr", "r", "br"].contains(alignment) ? 1 : 0
            let ay: Double = ["l", "ctr", "r"].contains(alignment) ? 0.5 : ["bl", "b", "br"].contains(alignment) ? 1 : 0
            let x = Double(frame.0) + (Double(frame.2) - width) * ax + Double(tile.coordinate("tx") ?? 0)
            let y = Double(frame.1) + (Double(frame.3) - height) * ay + Double(tile.coordinate("ty") ?? 0)
            let imageWidth = width / (1 - crop.left - crop.right), imageHeight = height / (1 - crop.top - crop.bottom)
            let clipID = "\(id)Clip"
            defs += "<clipPath id=\"\(clipID)\"><rect width=\"\(width)\" height=\"\(height)\"/></clipPath>"
            let image = "<g clip-path=\"url(#\(clipID))\"><image x=\"\(-crop.left * imageWidth)\" y=\"\(-crop.top * imageHeight)\" width=\"\(imageWidth)\" height=\"\(imageHeight)\" preserveAspectRatio=\"none\" href=\"\(resource.url)\"/></g>"
            defs += "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" x=\"\(x)\" y=\"\(y)\" width=\"\(width * (mirrorX ? 2 : 1))\" height=\"\(height * (mirrorY ? 2 : 1))\">\(image)"
            if mirrorX { defs += "<g transform=\"translate(\(2 * width) 0) scale(-1 1)\">\(image)</g>" }
            if mirrorY { defs += "<g transform=\"translate(0 \(2 * height)) scale(1 -1)\">\(image)</g>" }
            if mirrorX && mirrorY { defs += "<g transform=\"translate(\(2 * width) \(2 * height)) scale(-1 -1)\">\(image)</g>" }
            defs += "</pattern>"
        } else {
            guard let mapping = ImagePlacement(fill: blip, frame: frame) else { return nil }
            let clipID = "\(id)Clip"
            defs += "<clipPath id=\"\(clipID)\"><rect x=\"\(mapping.clip.x - Double(frame.0))\" y=\"\(mapping.clip.y - Double(frame.1))\" width=\"\(mapping.clip.width)\" height=\"\(mapping.clip.height)\"/></clipPath>"
            defs += "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" x=\"\(frame.0)\" y=\"\(frame.1)\" width=\"\(frame.2)\" height=\"\(frame.3)\">"
                + "<g clip-path=\"url(#\(clipID))\"><image x=\"\(mapping.image.x - Double(frame.0))\" y=\"\(mapping.image.y - Double(frame.1))\" width=\"\(mapping.image.width)\" height=\"\(mapping.image.height)\" preserveAspectRatio=\"none\" href=\"\(resource.url)\"/></g></pattern>"
        }
        return "url(#\(id))"
    }

    // MARK: - Tables / charts

    private func renderGraphicFrame(_ gf: XML.Element, ownedBy owner: Part,
                                    defs: inout SVGDefinitions, problems: inout SlideRenderProblems) -> String {
        guard let xfrm = gf.firstChild(named: "p:xfrm"),
              let off = xfrm.firstChild(named: "a:off"), let ext = xfrm.firstChild(named: "a:ext") else {
            diagnostics.record(.graphicPlaceholder, .omission, "Graphic frame has no usable transform.")
            return ""
        }
        let x = intAttr(off, "x"), y = intAttr(off, "y")
        let w = intAttr(ext, "cx"), h = intAttr(ext, "cy")
        let uri = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?[attribute: "uri"] ?? ""
        if uri.hasSuffix("/table"),
           let tbl = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?.firstChild(named: "a:tbl") {
            return renderTable(tbl, ownedBy: owner, x: x, y: y, defs: &defs)
        }
        if uri.hasSuffix("/chart"), let plot = renderChart(gf, ownedBy: owner, x: x, y: y, w: w, h: h) {
            return plot
        }
        if uri == GraphicDataURI.diagram,
           let cached = renderCachedDiagram(gf, ownedBy: owner, x: x, y: y, defs: &defs, problems: &problems) {
            return cached
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
        if uri == GraphicDataURI.diagram {
            diagnostics.record(.graphicPlaceholder, .omission, "SmartArt has no supported saved drawing; using a labeled placeholder.")
        }
        return box(x, y, w, h, fill: "#F2F2F2", stroke: " stroke=\"#CCCCCC\" stroke-width=\"6350\"")
            + textElement(label, x: x + w / 2, baseline: y + h / 2,
                          sizeEMU: 18 * emuPerPoint, fill: "#999999", anchor: "middle",
                          bold: false, typeface: nil)
    }

    /// Office stores a resolved drawing alongside many SmartArt data models.
    /// Render that snapshot; never run or rewrite the diagram's layout program.
    private func renderCachedDiagram(_ frame: XML.Element, ownedBy owner: Part, x: Int, y: Int,
                                     defs: inout SVGDefinitions, problems: inout SlideRenderProblems) -> String? {
        guard let id = frame.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
                .firstChild(named: "dgm:relIds")?[attribute: "r:dm"],
              let dataRel = owner.rels.relationship(withId: id), !dataRel.isExternal,
              let data = try? package.part(at: PackURI.resolve(target: dataRel.target, relativeTo: owner.uri.baseURI)),
              let root = try? data.dom() else { return nil }
        let extensions = root.firstChild(named: "dgm:extLst")?.children(named: "a:ext") ?? []
        guard let drawingID = extensions.compactMap({ $0.firstChild(named: "dsp:dataModelExt")?[attribute: "relId"] }).first,
              let relation = owner.rels.relationship(withId: drawingID), !relation.isExternal,
              relation.type.hasSuffix("/diagramDrawing"),
              let drawing = try? package.part(at: PackURI.resolve(target: relation.target, relativeTo: owner.uri.baseURI)),
              let tree = try? drawing.dom().firstChild(named: "dsp:spTree") else { return nil }
        // Nontrivial cached root mappings need their own coordinate conversion.
        if let transform = tree.firstChild(named: "dsp:grpSpPr")?.firstChild(named: "a:xfrm"),
           transform.childElements.contains(where: { $0.attributes.contains { Double($0.value) != 0 } }) {
            return nil
        }
        // Copies keep all unknown diagram XML byte-faithful in the package.
        func normalize(_ node: XML.Element, depth: Int = 0) -> XML.Element? {
            guard depth < 64 else { return nil }
            let copy = XML.Element(node.name, attributes: node.attributes)
            if ["dsp:sp", "dsp:grpSp", "dsp:spPr", "dsp:grpSpPr", "dsp:nvSpPr", "dsp:nvGrpSpPr",
                "dsp:cNvPr", "dsp:cNvSpPr", "dsp:cNvGrpSpPr", "dsp:style", "dsp:txBody"].contains(node.name) {
                copy.name = "p:" + node.name.dropFirst(4)
            }
            for child in node.children {
                if case .element(let element) = child {
                    guard let nested = normalize(element, depth: depth + 1) else { return nil }
                    copy.appendElement(nested)
                } else { copy.children.append(child) }
            }
            return copy
        }
        guard tree.childElements.contains(where: { ["dsp:sp", "dsp:grpSp"].contains($0.name) }) else { return nil }
        var output = ""
        let location = diagnostics.location
        defer { diagnostics.location = location }
        for node in tree.childElements where !["dsp:nvGrpSpPr", "dsp:grpSpPr", "dsp:extLst"].contains(node.name) {
            guard let shape = normalize(node), ["p:sp", "p:grpSp"].contains(shape.name) else { return nil }
            diagnostics.inspect(shape, owner: drawing, slideIndex: slideNumber - 1,
                path: "/dsp:drawing/dsp:spTree/" + node.name, package: package)
            output += renderNode(shape, ownedBy: drawing, defs: &defs, problems: &problems)
        }
        return "<g data-rostrum-diagram=\"cached\" transform=\"translate(\(x) \(y))\">\(output)</g>"
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

    private func renderTable(_ tbl: XML.Element, ownedBy owner: Part, x: Int, y: Int, defs: inout SVGDefinitions) -> String {
        let table = Table(tbl: tbl, part: owner, package: package)
        let grid = TableGridSnapshot(tbl)
        let topology = try? grid.topology()
        let resolver = TableStyleResolver(table: table, theme: theme)
        var styles = TableStyleResolver.RenderSession(resolver)
        let shadow = grid.columns.isEmpty || grid.rows.isEmpty ? nil : resolver.backgroundShadow()
        if let definition = resolver.activeDefinition() {
            let location = diagnostics.location
            diagnostics.inspect(definition, owner: resolver.stylePart ?? owner, slideIndex: slideNumber - 1,
                path: "/a:tblStyleLst/a:tblStyle[@styleId='\(table.styleID ?? "default")']", package: package,
                approximatedTableEffect: shadow?.fromTheme == false
                    ? definition.firstChild(named: "a:tblBg")?.firstChild(named: "a:effect")?.firstChild(named: "a:effectLst") : nil)
            for reference in resolver.themeReferences(in: definition) {
                diagnostics.inspect(reference.root, owner: theme.part, slideIndex: slideNumber - 1,
                    path: reference.path, package: package, tableStyleReference: true,
                    approximatedTableEffect: shadow?.fromTheme == true && reference.backgroundEffect
                        ? reference.root.firstChild(named: "a:effectLst") : nil)
            }
            diagnostics.location = location
        }
        if topology == nil {
            diagnostics.record(.unsupportedGeometry, .approximation, "Malformed table merges are previewed as separate physical cells.")
        }
        let widths = grid.columns.map { max(0, intAttr($0, "w")) }
        let heights = grid.rows.map { max(0, intAttr($0, "h")) }
        var xs = [0], ys = [0]
        for width in widths { xs.append(xs.last! + width) }
        for height in heights { ys.append(ys.last! + height) }
        let rtl = table.rightToLeft
        var out = "", diagonals = "", textContent = ""
        var reportedDoubleJunction = false
        struct BorderPaint {
            let color: String; let width: Int; let pattern: String
            let simpleSolid: Bool
            let double: Bool
        }
        var borders = TableBorderSegments<BorderPaint>()
        var maximumBorderWidth = 0
        func borderPaint(_ line: XML.Element?) -> BorderPaint? {
            guard let line, line.firstChild(named: "a:noFill") == nil,
                  let color = colorHex(in: line.firstChild(named: "a:solidFill")) else { return nil }
            let width = max(0, line.coordinate("w") ?? 12700)
            guard width > 0 else { return nil }
            maximumBorderWidth = max(maximumBorderWidth, width)
            let pattern: String
            switch line.firstChild(named: "a:prstDash")?[attribute: "val"] {
            case "dot", "sysDot": pattern = "\(width) \(width * 2)"
            case "dash": pattern = "\(width * 4) \(width * 3)"
            case "sysDash": pattern = "\(width * 3) \(width * 2)"
            case "lgDash": pattern = "\(width * 6) \(width * 2)"
            case "dashDot", "sysDashDot": pattern = "\(width * 3) \(width * 2) \(width) \(width * 2)"
            default: pattern = ""
            }
            let simpleSolid = (line.firstChild(named: "a:prstDash")?[attribute: "val"] ?? "solid") == "solid"
                && (line[attribute: "cmpd"] ?? "sng") == "sng"
                && (line[attribute: "cap"] ?? "flat") == "flat"
                && (line[attribute: "algn"] ?? "ctr") == "ctr"
                && ["a:custDash", "a:headEnd", "a:tailEnd", "a:round", "a:bevel"].allSatisfy {
                    line.firstChild(named: $0) == nil
                }
            return BorderPaint(color: color, width: width, pattern: pattern, simpleSolid: simpleSolid,
                               double: TableDoubleBorder.supports(line))
        }
        func lineSVG(_ paint: BorderPaint, _ endpoints: (Int, Int, Int, Int), offset: Int = 0,
                     startExtension: Double = 0, endExtension: Double = 0) -> String {
            if paint.double {
                return TableDoubleBorder.svg(color: paint.color, width: paint.width, endpoints: endpoints,
                                             startExtension: startExtension, endExtension: endExtension)
            }
            let dash = paint.pattern.isEmpty ? "" : " stroke-dasharray=\"\(paint.pattern)\""
                + (offset == 0 ? "" : " stroke-dashoffset=\"\(offset)\"")
            let coordinates: String
            if startExtension == 0, endExtension == 0 {
                coordinates = "x1=\"\(endpoints.0)\" y1=\"\(endpoints.1)\" x2=\"\(endpoints.2)\" y2=\"\(endpoints.3)\""
            } else if endpoints.0 == endpoints.2 {
                coordinates = "x1=\"\(endpoints.0)\" y1=\"\(SVGNumber.decimal(Double(endpoints.1) - startExtension))\" x2=\"\(endpoints.2)\" y2=\"\(SVGNumber.decimal(Double(endpoints.3) + endExtension))\""
            } else {
                coordinates = "x1=\"\(SVGNumber.decimal(Double(endpoints.0) - startExtension))\" y1=\"\(endpoints.1)\" x2=\"\(SVGNumber.decimal(Double(endpoints.2) + endExtension))\" y2=\"\(endpoints.3)\""
            }
            return "<line \(coordinates) stroke=\"\(paint.color)\" stroke-width=\"\(paint.width)\"\(dash)/>"
        }
        let background = resolver.background()
        let tableFrame = (x, y, xs.last!, ys.last!)
        let backgroundPaint: String?
        if let blip = background.properties.firstChild(named: "a:blipFill") {
            backgroundPaint = imagePattern(blip, ownedBy: background.owner, box: tableFrame, defs: &defs)
        } else if let gradient = background.properties.firstChild(named: "a:gradFill") {
            backgroundPaint = tableGradient(gradient, box: tableFrame, defs: &defs)
        } else { backgroundPaint = paint(for: background.properties, box: tableFrame, defs: &defs) }
        if let backgroundPaint {
            out += box(x, y, tableFrame.2, tableFrame.3, fill: backgroundPaint, stroke: "")
        }
        for r in grid.rows.indices {
            for c in grid.cells[r].indices where c < widths.count {
                let region = topology?.region(row: r, column: c)
                if let region, region.row != r || region.column != c { continue }
                let rowEnd = r + (region?.rowSpan ?? 1), columnEnd = c + (region?.columnSpan ?? 1)
                let cw = xs[columnEnd] - xs[c], rh = ys[rowEnd] - ys[r]
                let cx = x + (rtl ? xs.last! - xs[columnEnd] : xs[c]), cy = y + ys[r]
                let frame = (cx, cy, cw, rh)
                let effective = styles.effective(row: r, column: c)
                let properties = effective.properties
                var fill: String?
                if let blip = properties.firstChild(named: "a:blipFill") {
                    fill = imagePattern(blip, ownedBy: effective.fillOwner, box: frame, defs: &defs)
                } else if let gradient = properties.firstChild(named: "a:gradFill") {
                    fill = tableGradient(gradient, box: frame, defs: &defs)
                } else { fill = paint(for: properties, box: frame, defs: &defs) }
                if let fill {
                    out += box(cx, cy, cw, rh, fill: fill, stroke: "")
                }
                // PowerPoint assigns a shared edge to the earlier logical
                // cell, including noFill and dash gaps. A merge continuation
                // perpendicular to the edge does not donate it. Keep borders
                // above every cell fill so a neighbor cannot erase half a line.
                for edge in TableCellBorder.allCases {
                    if edge == .left, c > 0,
                       topology == nil || !TableMergeTopology.flag(grid.cells[r][c - 1], "vMerge") { continue }
                    if edge == .top, r > 0, grid.cells[r - 1].indices.contains(c),
                       topology == nil || !TableMergeTopology.flag(grid.cells[r - 1][c], "hMerge") { continue }
                    let edgeRow = edge == .bottom ? rowEnd - 1 : r
                    let edgeColumn = edge == .right ? columnEnd - 1 : c
                    let direct = grid.cells[r][c].firstChild(named: "a:tcPr")?.firstChild(named: edge.rawValue)
                    let edgeProperties = direct != nil || (edgeRow == r && edgeColumn == c) ? properties : styles.effective(row: edgeRow, column: edgeColumn).properties
                    let paint = borderPaint(edgeProperties.firstChild(named: edge.rawValue))
                    if paint?.double == true, edge == .diagonalDown || edge == .diagonalUp,
                       !reportedDoubleJunction,
                       [TableCellBorder.left, .right, .top, .bottom].contains(where: {
                           borderPaint(properties.firstChild(named: $0.rawValue)) != nil
                       }) {
                        diagnostics.record(.unsupportedBorder, .approximation,
                            "Double diagonal junctions with cell borders are approximated.")
                        reportedDoubleJunction = true
                    }
                    switch edge {
                    case .left, .right:
                        borders.append(axis: .vertical, boundary: edge == .left ? c : columnEnd,
                            range: r..<rowEnd, paint: paint)
                    case .top, .bottom:
                        borders.append(axis: .horizontal, boundary: edge == .top ? r : rowEnd,
                            range: c..<columnEnd, paint: paint)
                    case .diagonalDown:
                        if let paint { diagonals += lineSVG(paint, (cx, cy, cx + cw, cy + rh)) }
                    case .diagonalUp:
                        if let paint { diagonals += lineSVG(paint, (cx, cy + rh, cx + cw, cy)) }
                    }
                }

                if let body = grid.cells[r][c].firstChild(named: "a:txBody") {
                    // Cell geometry overrides bodyPr without copying XML or
                    // serializing margins only to parse them again in layout.
                    func inset(_ margin: String, _ fallback: Int) -> Double {
                        Double(properties.coordinate(margin) ?? fallback) / Double(emuPerPoint)
                    }
                    let insets = (left: inset("marL", 91440), top: inset("marT", 45720),
                                  right: inset("marR", 91440), bottom: inset("marB", 45720))
                    let anchor = properties[attribute: "anchor"] ?? "t"
                    let direction = properties[attribute: "vert"] ?? "horz"
                    // Rotation belongs to the cell, while text layout uses a
                    // horizontal box with swapped dimensions.
                    if direction == "vert" || direction == "vert270" {
                        let transform = direction == "vert" ? "translate(\(cx + cw) \(cy)) rotate(90)" : "translate(\(cx) \(cy + rh)) rotate(-90)"
                        textContent += "<g transform=\"\(transform)\">" + renderText(body, box: (0, 0, rh, cw), inheriting: effective.text,
                            insets: insets, verticalAnchor: anchor) + "</g>"
                    } else {
                        textContent += renderText(body, box: frame, inheriting: effective.text,
                            insets: insets, verticalAnchor: anchor)
                    }
                }
            }
        }
        let segments = borders.resolved()
        // The pinned Office v3 vector reference establishes this geometry and
        // paint order for uniform-width, opaque solid grids. Keep the previous
        // path for dashes, alpha, mixed widths and diagonals until comparable
        // independent references establish their intersection behavior.
        let uniformWidth = segments.first?.paint.width
        let joinedGrid = topology != nil && widths.allSatisfy { $0 > 0 } && heights.allSatisfy { $0 > 0 }
            && diagonals.isEmpty && !segments.isEmpty && segments.allSatisfy {
            $0.paint.width == uniformWidth && $0.paint.simpleSolid && $0.paint.color.hasPrefix("#")
        }
        func paintGroup(_ segment: TableBorderSegments<BorderPaint>.Segment) -> Int {
            let edge = segment.edge
            let outer = edge.boundary == 0 || edge.boundary == (edge.axis == .vertical ? widths.count : heights.count)
            return (outer ? 2 : 0) + (edge.axis == .vertical ? 0 : 1)
        }
        // Linear passes avoid sorting the potentially large grid. Interior
        // verticals precede horizontals, then the outer vertical/horizontal rim.
        for group in 0..<(joinedGrid ? 4 : 1) {
          for segment in segments where !joinedGrid || paintGroup(segment) == group {
            let edge = segment.edge, lower = segment.range.lowerBound, upper = segment.range.upperBound
            let endpoints: (Int, Int, Int, Int)
            let offset: Int
            if edge.axis == .vertical {
                let px = x + (rtl ? xs.last! - xs[edge.boundary] : xs[edge.boundary])
                endpoints = (px, y + ys[lower], px, y + ys[upper])
                offset = ys[lower] - ys[edge.range.lowerBound]
            } else {
                let py = y + ys[edge.boundary]
                let left = rtl ? xs.last! - xs[upper] : xs[lower]
                let right = rtl ? xs.last! - xs[lower] : xs[upper]
                endpoints = (x + left, py, x + right, py)
                offset = rtl ? xs[edge.range.upperBound] - xs[upper] : xs[lower] - xs[edge.range.lowerBound]
            }
            let joins = joinedGrid ? borders.terminalJoins(segment) : (lower: false, upper: false)
            let halfWidth = Double(segment.paint.width) / 2
            let start = edge.axis == .horizontal && rtl ? joins.upper : joins.lower
            let end = edge.axis == .horizontal && rtl ? joins.lower : joins.upper
            var startExtension = start ? halfWidth : 0, endExtension = end ? halfWidth : 0
            if segment.paint.double {
                // Collinear continuations suppress terminal extensions, but
                // cannot suppress diagnostics at an interior crossing.
                if !reportedDoubleJunction, borders.containsIntersection(segment, matching: { first, second in
                    guard let paint = first ?? second else { return false }
                    func plain(_ value: BorderPaint) -> Bool { value.simpleSolid && value.color.hasPrefix("#") }
                    return !plain(paint) || second.map { !plain($0) || $0.width != paint.width } == true
                }) {
                    diagnostics.record(.unsupportedBorder, .approximation,
                        "Double-border junctions with compound, dashed, translucent or unequal neighboring strokes are approximated.")
                    reportedDoubleJunction = true
                }
                let neighbors = borders.terminalPaints(segment)
                func extent(_ paints: [BorderPaint]) -> Double {
                    guard let first = paints.first else { return 0 }
                    guard paints.allSatisfy({ $0.simpleSolid && $0.color.hasPrefix("#") && $0.width == first.width }) else {
                        if !reportedDoubleJunction {
                            diagnostics.record(.unsupportedBorder, .approximation,
                                "Double-border junctions with compound, dashed, translucent or unequal neighboring strokes are approximated.")
                            reportedDoubleJunction = true
                        }
                        return 0
                    }
                    // The native Office PDF extends each component to the
                    // outside of a perpendicular plain border, not by half
                    // the double border's own (potentially wider) width.
                    return Double(first.width) / 2
                }
                let lower = extent(neighbors.lower), upper = extent(neighbors.upper)
                startExtension = edge.axis == .horizontal && rtl ? upper : lower
                endExtension = edge.axis == .horizontal && rtl ? lower : upper
            }
            out += lineSVG(segment.paint, endpoints, offset: offset,
                           startExtension: startExtension, endExtension: endExtension)
          }
        }
        if let shadow {
            // Table background effects apply to the combined fills and borders,
            // before text. SourceAlpha preserves holes and translucent paint;
            // an opaque rectangular substitute would invent a shadow there.
            let id = "ts\(defs.description.utf8.count)"
            let sigma = shadow.blurRadius / 2
            let borderPad = Double(maximumBorderWidth) / 2
            let pad = 3 * sigma + max(abs(shadow.dx), abs(shadow.dy)) + borderPad
            func number(_ value: Double) -> String { SVGNumber.decimal(value) }
            defs += "<filter id=\"\(id)\" filterUnits=\"userSpaceOnUse\" x=\"\(number(Double(x) - pad))\" y=\"\(number(Double(y) - pad))\" width=\"\(number(Double(tableFrame.2) + 2 * pad))\" height=\"\(number(Double(tableFrame.3) + 2 * pad))\" color-interpolation-filters=\"sRGB\">"
                + "<feGaussianBlur in=\"SourceAlpha\" stdDeviation=\"\(number(sigma))\" result=\"blur\"/>"
                + "<feOffset in=\"blur\" dx=\"\(number(shadow.dx))\" dy=\"\(number(shadow.dy))\" result=\"offset\"/>"
                + "<feFlood flood-color=\"#\(shadow.color.hex)\" flood-opacity=\"\(number(shadow.alpha))\" result=\"color\"/>"
                + "<feComposite in=\"color\" in2=\"offset\" operator=\"in\" result=\"shadow\"/>"
                + "<feMerge><feMergeNode in=\"shadow\"/><feMergeNode in=\"SourceGraphic\"/></feMerge></filter>"
            return "<g filter=\"url(#\(id))\">" + out + diagonals + "</g>" + textContent
        }
        return out + diagonals + textContent
    }

    private func tableGradient(_ gradient: XML.Element, box frame: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String {
        let id = defs.nextID("tg")
        let stops = GradientStops.svg(gradient, theme: theme)
        if gradient.firstChild(named: "a:path") != nil {
            defs += "<radialGradient id=\"\(id)\">\(stops)</radialGradient>"
        } else {
            let degrees = Double(gradient.firstChild(named: "a:lin")?.boundedInt("ang", in: 0...21600000) ?? 0) / 60000
            let radians = degrees * .pi / 180
            let dx = cos(radians), dy = sin(radians)
            defs += "<linearGradient id=\"\(id)\" x1=\"\((1 - dx) / 2)\" y1=\"\((1 - dy) / 2)\" x2=\"\((1 + dx) / 2)\" y2=\"\((1 + dy) / 2)\">\(stops)</linearGradient>"
        }
        return "url(#\(id))"
    }

    // MARK: - Paint / helpers

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

    private func paint(for pr: XML.Element, box f: (Int, Int, Int, Int), defs: inout SVGDefinitions, ownedBy owner: Part? = nil) -> String? {
        if let solid = pr.firstChild(named: "a:solidFill") { return colorHex(in: solid) }
        if let grad = pr.firstChild(named: "a:gradFill") { return gradientRef(grad, box: f, defs: &defs) }
        if let blip = pr.firstChild(named: "a:blipFill") { return imagePattern(blip, ownedBy: owner ?? slidePart, box: f, defs: &defs) }
        if pr.firstChild(named: "a:noFill") != nil { return nil }
        return nil
    }

    private func gradientRef(_ grad: XML.Element, box f: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String {
        let id = defs.nextID("g")
        let isRadial = grad.firstChild(named: "a:path") != nil
        let stopSVG = GradientStops.svg(grad, theme: theme)
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
        SVGMarkup.escape(s)
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
    public var fidelityIssues: [FidelityIssue]

    public var messages: [String] {
        (layoutUnresolved ? ["Preview could not load the slide layout."] : [])
        + (masterUnresolved ? ["Preview could not load the slide master."] : [])
        + unsupportedContent + Array(Set(fidelityIssues.map(\.message))).sorted()
    }

    /// No detected problems; not a guarantee of PowerPoint rendering equivalence.
    public var isEmpty: Bool { messages.isEmpty && fidelityIssues.isEmpty }

    fileprivate mutating func record(_ message: String) {
        if !unsupportedContent.contains(message) { unsupportedContent.append(message) }
    }

    public init(layoutUnresolved: Bool = false, masterUnresolved: Bool = false, unsupportedContent: [String] = [], fidelityIssues: [FidelityIssue] = []) {
        self.layoutUnresolved = layoutUnresolved
        self.masterUnresolved = masterUnresolved
        self.unsupportedContent = unsupportedContent
        self.fidelityIssues = fidelityIssues
    }
}

public extension Presentation {
    /// Render one slide to a self-contained SVG string (thumbnails / visual diff).
    func renderSVG(slideAt index: Int, pixelWidth: Int = 1280, strictRendering: Bool = false) throws -> String {
        try renderSVGReportingProblems(slideAt: index, pixelWidth: pixelWidth, strictRendering: strictRendering).svg
    }

    /// Render one slide, reporting broken inheritance and detected preview limits.
    ///
    /// The `svg` is exactly what `renderSVG(slideAt:pixelWidth:)` returns —
    /// this is the same render, with the diagnostics kept instead of dropped.
    /// `problems` names any broken link (see `SlideRenderProblems`), so a
    /// caller can tell a damaged deck apart from one rendered wrong. A slide
    /// with a broken chain still renders; it just comes back without whatever
    /// it would have inherited.
    func renderSVGReportingProblems(slideAt index: Int, pixelWidth: Int = 1280, strictRendering: Bool = false)
        throws -> (svg: String, problems: SlideRenderProblems) {
        let slide = try slides[index]
        let result = try SVGRenderer(slidePart: slide.part, slideSize: slideSize,
                        theme: slide.resolvedTheme, package: package, fonts: fonts,
                        slideNumber: index + 1).render(pixelWidth: pixelWidth)
        if strictRendering && !result.problems.isEmpty { throw StrictRenderingError(problems: result.problems) }
        return result
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
