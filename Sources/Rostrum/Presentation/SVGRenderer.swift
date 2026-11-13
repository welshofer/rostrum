import Foundation

/// Scratch storage for one render. It retains no style nodes between calls,
/// including when an internal renderer value is reused after direct DOM edits.
private final class SVGOrdinaryInheritedDefaults {
    var resolved = false
    var value: XML.Element?

    func clear() {
        resolved = false
        value = nil
    }
}

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
    private let ordinaryInheritedDefaults = SVGOrdinaryInheritedDefaults()

    func render(pixelWidth: Int) throws -> (svg: String, problems: SlideRenderProblems) {
        ordinaryInheritedDefaults.clear()
        defer { ordinaryInheritedDefaults.clear() }
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
                path: "/p:cSld/p:spTree/\(child.name)[\(index + 1)]", package: package, ignoringPlaceholders: true)
            out += renderNode(child, ownedBy: part, defs: &defs, problems: &problems, inherited: true)
        }
        return out
    }

    // MARK: - Shape tree and transforms

    private func shapeHyperlinkHref(_ node: XML.Element, ownedBy owner: Part) -> String? {
        guard let hlink = node.childElements.first?.firstChild(named: "p:cNvPr")?.firstChild(named: "a:hlinkClick") else {
            return nil
        }
        let action = hlink[attribute: "action"]
        if action == "ppaction://media" { return nil }
        if let rId = hlink[attribute: "r:id"], !rId.isEmpty,
           let rel = owner.rels.relationship(withId: rId) {
            if !rel.isExternal, rel.type == RelType.slide {
                let targetURI = PackURI.resolve(target: rel.target, relativeTo: owner.uri.baseURI)
                if let main = try? package.mainDocumentPart(),
                   let sldIdLst = (try? main.dom())?.firstChild(named: "p:sldIdLst") {
                    for (idx, sldId) in sldIdLst.children(named: "p:sldId").enumerated() {
                        if let sRelId = sldId[attribute: "r:id"],
                           let sRel = main.rels.relationship(withId: sRelId),
                           PackURI.resolve(target: sRel.target, relativeTo: main.uri.baseURI) == targetURI {
                            return "#slide-\(idx + 1)"
                        }
                    }
                }
            }
            return rel.target
        }
        if let action, !action.isEmpty { return action }
        return nil
    }

    private func renderNode(_ node: XML.Element, ownedBy owner: Part, defs: inout SVGDefinitions,
                            problems: inout SlideRenderProblems, inherited: Bool = false,
                            depth: Int = 0, flippedTextH: Bool = false, flippedTextV: Bool = false,
                            groupFill: (properties: XML.Element, owner: Part)? = nil) -> String {
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
            let grpSpPr = node.firstChild(named: "p:grpSpPr")
            let directFills = ["a:solidFill", "a:gradFill", "a:blipFill", "a:pattFill", "a:noFill"]
            let childGroupFill: (properties: XML.Element, owner: Part)?
            if let grpSpPr, grpSpPr.childElements.contains(where: { directFills.contains($0.name) }) {
                childGroupFill = (grpSpPr, owner)
            } else {
                childGroupFill = groupFill
            }
            let groupLocation = diagnostics.location
            var occurrences: [String: Int] = [:]
            let children = node.childElements.map { child in
                occurrences[child.name, default: 0] += 1
                // Match the scanner's same-name indices, including hidden
                // siblings, and restore the group before visiting the next child.
                diagnostics.location = FidelityLocation(slideIndex: groupLocation.slideIndex,
                    partURI: owner.uri.description,
                    shapeID: child.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"],
                    path: groupLocation.path + "/\(child.name)[\(occurrences[child.name]!)]")
                defer { diagnostics.location = groupLocation }
                return renderNode(child, ownedBy: owner, defs: &defs, problems: &problems,
                           inherited: inherited, depth: depth + 1, flippedTextH: textFlipH, flippedTextV: textFlipV,
                           groupFill: childGroupFill)
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
            content = renderShape(node, ownedBy: owner, defs: &defs, problems: &problems,
                                  textFlipH: textFlipH, textFlipV: textFlipV, groupFill: groupFill)
        case "p:pic": content = renderPicture(node, ownedBy: owner, defs: &defs, problems: &problems)
        case "p:cxnSp": content = renderConnector(node, defs: &defs, problems: &problems)
        case "p:graphicFrame": content = renderGraphicFrame(node, ownedBy: owner, defs: &defs, problems: &problems)
        default:
            problems.record("Preview omitted an unsupported shape-tree element.")
            return ""
        }
        let transformed: String
        if let transform = ShapeTransform.element(of: node),
           let bounds = ShapeTransform.rect(transform) {
            // DrawingML flips about the shape/group center, then rotates clockwise.
            let rotation = ShapeTransform.rotation(of: node).truncatingRemainder(dividingBy: 360)
            let flipH = ["1", "true"].contains(transform[attribute: "flipH"] ?? "")
            let flipV = ["1", "true"].contains(transform[attribute: "flipV"] ?? "")
            if rotation != 0 || flipH || flipV {
                let cx = Double(bounds.x.rawValue) + Double(bounds.width.rawValue) / 2
                let cy = Double(bounds.y.rawValue) + Double(bounds.height.rawValue) / 2
                transformed = "<g transform=\"translate(\(cx) \(cy)) rotate(\(rotation)) scale(\(flipH ? -1 : 1) \(flipV ? -1 : 1)) translate(\(-cx) \(-cy))\">\(content)</g>"
            } else {
                transformed = content
            }
        } else {
            transformed = content
        }
        if !transformed.isEmpty, let href = shapeHyperlinkHref(node, ownedBy: owner) {
            return "<a href=\"\(escape(href))\">\(transformed)</a>"
        }
        return transformed
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
        if !["line", "straightConnector1", "bentConnector2", "bentConnector3", "bentConnector4", "bentConnector5",
             "curvedConnector2", "curvedConnector3", "curvedConnector4", "curvedConnector5"].contains(preset) {
            diagnostics.record(.unsupportedGeometry, .approximation,
                "Preview approximates this bent or curved connector with a straight line.")
        }
        var optionalProblems: SlideRenderProblems? = problems
        let attrs = "stroke=\"\(color)\" stroke-width=\"\(width)\" fill=\"none\""
            + dashAttributes(line, width: width, problems: &optionalProblems)
            + lineEndMarkers(line, color: color, defs: &defs, problems: &problems)
        if let updated = optionalProblems { problems = updated }
        func adjustment(_ name: String, default fallback: Double = 0.5) -> Double {
            guard let guide = properties.firstChild(named: "a:prstGeom")?.firstChild(named: "a:avLst")?
                .children(named: "a:gd").first(where: { $0[attribute: "name"] == name }) else {
                return fallback
            }
            let formula = (guide[attribute: "fmla"] ?? "").split(whereSeparator: \.isWhitespace)
            if formula.count == 2, formula.first == "val", let value = Double(formula[1]),
               value.isFinite, abs(value) <= 1_000_000 {
                return value / 100_000
            }
            diagnostics.record(.unsupportedGeometry, .approximation,
                "Unsupported connector guide formula uses the default elbow adjustment.")
            return fallback
        }
        switch preset {
        case "bentConnector2":
            if w != 0 && h != 0 {
                return "<path d=\"M\(x) \(y) H\(x + w) V\(y + h)\" \(attrs)/>"
            }
        case "bentConnector3":
            let adj1 = adjustment("adj1")
            if h != 0 || !(0...1).contains(adj1) {
                let middle = coord(Double(x) + Double(w) * adj1)
                return "<path d=\"M\(x) \(y) H\(middle) V\(y + h) H\(x + w)\" \(attrs)/>"
            }
        case "bentConnector4":
            let adj1 = adjustment("adj1"), adj2 = adjustment("adj2")
            if w != 0 || h != 0 || !(0...1).contains(adj1) || !(0...1).contains(adj2) {
                let x1 = coord(Double(x) + Double(w) * adj1)
                let y2 = coord(Double(y) + Double(h) * adj2)
                return "<path d=\"M\(x) \(y) H\(x1) V\(y2) H\(x + w) V\(y + h)\" \(attrs)/>"
            }
        case "bentConnector5":
            let adj1 = adjustment("adj1"), adj2 = adjustment("adj2"), adj3 = adjustment("adj3")
            if w != 0 || h != 0 || !(0...1).contains(adj1) || !(0...1).contains(adj2) || !(0...1).contains(adj3) {
                let x1 = coord(Double(x) + Double(w) * adj1)
                let y2 = coord(Double(y) + Double(h) * adj2)
                let x3 = coord(Double(x) + Double(w) * adj3)
                return "<path d=\"M\(x) \(y) H\(x1) V\(y2) H\(x3) V\(y + h) H\(x + w)\" \(attrs)/>"
            }
        case "curvedConnector2":
            if w != 0 && h != 0 {
                let cx = coord(Double(x) + Double(w) * 0.5)
                let cy = coord(Double(y) + Double(h) * 0.5)
                return "<path d=\"M\(x) \(y) C\(cx) \(y) \(x + w) \(cy) \(x + w) \(y + h)\" \(attrs)/>"
            }
        case "curvedConnector3":
            let adj1 = adjustment("adj1")
            if h != 0 || !(0...1).contains(adj1) {
                let x1 = coord(Double(x) + Double(w) * adj1)
                let cy = coord(Double(y) + Double(h) * 0.5)
                let hx1 = coord(Double(x) + Double(w) * adj1 * 0.5)
                let hx2 = coord(Double(x1) + Double(x + w - x1) * 0.5)
                return "<path d=\"M\(x) \(y) C\(hx1) \(y) \(x1) \( coord(Double(y) + Double(h) * 0.25) ) \(x1) \(cy) C\(x1) \( coord(Double(y) + Double(h) * 0.75) ) \(hx2) \(y + h) \(x + w) \(y + h)\" \(attrs)/>"
            }
        case "curvedConnector4":
            let adj1 = adjustment("adj1"), adj2 = adjustment("adj2")
            if w != 0 || h != 0 || !(0...1).contains(adj1) || !(0...1).contains(adj2) {
                let x1 = coord(Double(x) + Double(w) * adj1)
                let y2 = coord(Double(y) + Double(h) * adj2)
                let mx = coord(Double(x1) + Double(x + w - x1) * 0.5)
                return "<path d=\"M\(x) \(y) C\(x1) \(y) \(x1) \(y2) \(mx) \(y2) C\(x + w) \(y2) \(x + w) \( coord(Double(y2) + Double(y + h - y2) * 0.5) ) \(x + w) \(y + h)\" \(attrs)/>"
            }
        case "curvedConnector5":
            let adj1 = adjustment("adj1"), adj2 = adjustment("adj2"), adj3 = adjustment("adj3")
            if w != 0 || h != 0 || !(0...1).contains(adj1) || !(0...1).contains(adj2) || !(0...1).contains(adj3) {
                let x1 = coord(Double(x) + Double(w) * adj1)
                let y2 = coord(Double(y) + Double(h) * adj2)
                let x3 = coord(Double(x) + Double(w) * adj3)
                return "<path d=\"M\(x) \(y) C\(x1) \(y) \(x1) \(y2) \( coord(Double(x1 + x3) * 0.5) ) \(y2) C\(x3) \(y2) \(x3) \(y + h) \(x + w) \(y + h)\" \(attrs)/>"
            }
        default:
            break
        }
        return "<line x1=\"\(x)\" y1=\"\(y)\" x2=\"\(x + w)\" y2=\"\(y + h)\" \(attrs)/>"
    }

    // MARK: - Shapes

    private func renderShape(_ sp: XML.Element, ownedBy owner: Part,
                             defs: inout SVGDefinitions, problems: inout SlideRenderProblems,
                             textFlipH: Bool = false, textFlipV: Bool = false,
                             groupFill: (properties: XML.Element, owner: Part)? = nil) -> String {
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
        let shapeLocation = diagnostics.location
        diagnoseReferencedEffects(of: sp, properties: spPr)
        let f = resolvedFrame(of: sp, spPr: spPr, ownedBy: owner)
        var out = ""
        let preset = spPr.firstChild(named: "a:prstGeom")
        let prst = spPr.firstChild(named: "a:custGeom") != nil ? "rect" : preset?[attribute: "prst"] ?? "rect"
        let style = sp.firstChild(named: "p:style")
        let selectedFill = effectiveFill(spPr, reference: style?.firstChild(named: "a:fillRef"), ownedBy: owner, groupFill: groupFill)
        let fill: String?
        let shapeRotation = ShapeTransform.rotation(of: sp).truncatingRemainder(dividingBy: 360)
        if let blip = selectedFill.properties.firstChild(named: "a:blipFill") {
            if selectedFill.properties !== spPr {
                // Direct paint was inspected with the shape. Referenced paint
                // belongs to the theme and must use that same owner for both
                // diagnostics and drawing, including colliding relationship IDs.
                let location = diagnostics.location
                diagnostics.inspect(blip, owner: selectedFill.owner, slideIndex: slideNumber - 1,
                    path: location.path + "/p:style/a:fillRef", package: package)
                diagnostics.location = location
            }
            fill = imagePattern(blip, ownedBy: selectedFill.owner, box: f, defs: &defs, shapeRotation: shapeRotation)
        } else {
            fill = paint(for: selectedFill.properties, box: f, defs: &defs, ownedBy: selectedFill.owner, shapeRotation: shapeRotation)
        }
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
            let ln = lineProperties.firstChild(named: "a:ln")
            let strokeColor = ln.flatMap { colorHex(in: $0.firstChild(named: "a:solidFill")) }
                ?? style?.firstChild(named: "a:lnRef").flatMap { colorHex(in: $0) }
            if let custom = spPr.firstChild(named: "a:custGeom") {
                if let paths = SVGCustomGeometry.paths(custom, width: Double(f.2), height: Double(f.3)) {
                    let markerAttrs = (!stroke.isEmpty && paths.contains { $0.stroke && !$0.closed })
                        ? strokeColor.map { lineEndMarkers(ln, color: $0, defs: &defs, problems: &problems) } ?? ""
                        : ""
                    out += SVGCustomGeometry.render(paths, x: f.0, y: f.1, fill: fill ?? "none", stroke: stroke, openMarkerAttrs: markerAttrs)
                } else {
                    diagnostics.record(.unsupportedGeometry, .approximation, "Custom path commands or coordinates are unsupported; using a rectangle.")
                    problems.record("Preview approximates unsupported custom geometry as a rectangle.")
                    out += geometry("rect", f, fill: fill ?? "none", stroke: stroke)
                }
            } else if let doubleSVG = doubleShapeSVG(preset: prst, frame: f, fill: fill, lineProperties: lineProperties) {
                out += doubleSVG
            } else {
                let markerAttrs = (!stroke.isEmpty && SVGPresetGeometry.openPresets.contains(prst))
                    ? strokeColor.map { lineEndMarkers(ln, color: $0, defs: &defs, problems: &problems) } ?? ""
                    : ""
                out += SVGPresetGeometry.render(prst, adjustments: preset?.firstChild(named: "a:avLst"),
                                               frame: f, fill: fill ?? "none", stroke: stroke + markerAttrs)
            }
        }
        if let txBody = sp.firstChild(named: "p:txBody") {
            // A custom geometry places its text in its own `a:rect`, which may
            // be inset from the shape bounds by guide formulas.
            var customTextFrame: (Int, Int, Int, Int)?
            if let custom = spPr.firstChild(named: "a:custGeom"), let rect = custom.firstChild(named: "a:rect"),
               ["l", "t", "r", "b"].contains(where: { rect[attribute: $0] != $0 }) {
                if let resolved = SVGCustomGeometry.resolve(custom, width: Double(f.2), height: Double(f.3))?.textRect,
                   resolved.right - resolved.left >= 1, resolved.bottom - resolved.top >= 1 {
                    customTextFrame = (f.0 + Int(resolved.left.rounded()), f.1 + Int(resolved.top.rounded()),
                                       Int((resolved.right - resolved.left).rounded()), Int((resolved.bottom - resolved.top).rounded()))
                } else if !txBody.textContent.isEmpty {
                    diagnostics.record(.unsupportedGeometry, .approximation, "Custom geometry text rectangle is not resolved; using the shape bounds.")
                }
            }
            let textFrame = ShapeTransform.rect(sp.firstChild(named: "dsp:txXfrm")).map { ($0.x.rawValue, $0.y.rawValue, $0.width.rawValue, $0.height.rawValue) }
                ?? customTextFrame
                ?? SVGPresetGeometry.textFrame(prst, adjustments: preset?.firstChild(named: "a:avLst"), frame: f)
            let text = renderText(txBody, box: textFrame,
                                  inheriting: inheritedRunDefaults(for: sp, ownedBy: owner),
                                  fontReference: style?.firstChild(named: "a:fontRef"), respectInsets: true,
                                  owner: owner)
            // PowerPoint flips the shape and its placement, not the glyphs.
            // Counter-reflect text locally before the enclosing SVG transforms.
            if textFlipH || textFlipV {
                let cx = Double(f.0) + Double(f.2) / 2, cy = Double(f.1) + Double(f.3) / 2
                out += "<g data-text-unflip=\"true\" transform=\"translate(\(cx) \(cy)) scale(\(textFlipH ? -1 : 1) \(textFlipV ? -1 : 1)) translate(\(-cx) \(-cy))\">\(text)</g>"
            } else { out += text }
        }
        // An explicit empty effect list suppresses the theme's shadow.
        let directEffects = spPr.firstChild(named: "a:effectLst")
        let inheritedEffects = directEffects == nil && spPr.firstChild(named: "a:effectDag") == nil
            ? styleEntry(style?.firstChild(named: "a:effectRef"), list: "a:effectStyleLst") : nil
        let effects = directEffects ?? inheritedEffects?.firstChild(named: "a:effectLst")
        if let effects {
            let transform = spPr.firstChild(named: "a:xfrm")
            let rotation = ShapeTransform.rotation(of: sp)
            let flipH = ["1", "true"].contains(transform?[attribute: "flipH"] ?? "")
            let flipV = ["1", "true"].contains(transform?[attribute: "flipV"] ?? "")
            // Inside out: effects that change the shape's own pixels first,
            // then the ones painted behind it.
            var rendered: [String] = []
            if let edge = effects.firstChild(named: "a:softEdge"),
               let painted = SVGShadow.softEdge(out, edge: edge, frame: f, defs: &defs) {
                out = painted
                rendered.append("soft edge")
            }
            if let inner = effects.firstChild(named: "a:innerShdw"),
               let painted = SVGShadow.innerShadow(out, shadow: inner, frame: f, theme: theme,
                                                   rotation: rotation, flipH: flipH, flipV: flipV, defs: &defs) {
                out = painted
                rendered.append("inner shadow")
            }
            if let glow = effects.firstChild(named: "a:glow"),
               let painted = SVGShadow.glow(out, glow: glow, frame: f, theme: theme, defs: &defs) {
                out = painted
                rendered.append("glow")
            }
            if let shadow = effects.firstChild(named: "a:outerShdw") {
                let ordinary = ["sx", "sy"].allSatisfy { shadow[attribute: $0] == nil || shadow[attribute: $0] == "100000" }
                    && ["kx", "ky"].allSatisfy { shadow[attribute: $0] == nil || shadow[attribute: $0] == "0" }
                if !ordinary {
                    problems.record("Preview omitted a scaled or skewed outer shadow.")
                } else if let painted = SVGShadow.wrap(out, shadow: shadow, frame: f, theme: theme,
                                                       rotation: rotation, flipH: flipH, flipV: flipV, defs: &defs) {
                    out = painted
                    rendered.append("outer shadow")
                }
            }
            // A partly drawn list still omits effects. A theme-reference issue
            // also covers other active components, including 3D effects.
            let otherInheritedEffects = inheritedEffects?.childElements.contains { component in
                ["a:effectDag", "a:scene3d", "a:sp3d"].contains(component.name)
                    && spPr.firstChild(named: component.name) == nil
                    && RenderDiagnosticCollector.hasEffectContent(component)
            } ?? false
            if !rendered.isEmpty, rendered.count == effects.childElements.count, !otherInheritedEffects {
                let suffix = directEffects == nil ? "/p:style/a:effectRef" : "/p:spPr[1]/a:effectLst[1]"
                diagnostics.renderedEffects(rendered, at: FidelityLocation(slideIndex: shapeLocation.slideIndex,
                    partURI: shapeLocation.partURI, shapeID: shapeLocation.shapeID, path: shapeLocation.path + suffix))
            }
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
        // Ordinary slide shapes share the same final master style. Placeholder
        // matching and notes inheritance remain specific to each shape.
        let ordinary = notesContext == nil && Placeholders.phElement(of: sp) == nil
        if ordinary && ordinaryInheritedDefaults.resolved { return ordinaryInheritedDefaults.value }
        let styles = notesContext?.styles(for: sp) ?? RichTextLayout.inheritedStyles(for: sp, owner: owner, package: package)
        guard !styles.isEmpty else {
            if ordinary { ordinaryInheritedDefaults.resolved = true }
            return nil
        }
        let resolved = XML.Element("rostrum:inheritedStyles")
        for style in styles { resolved.appendElement(style) }
        if ordinary {
            ordinaryInheritedDefaults.value = resolved
            ordinaryInheritedDefaults.resolved = true
        }
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
                            verticalAnchor: String? = nil, context: RichTextLayout.Context = .shape,
                            owner: Part? = nil) -> String {
        if context == .shape, let bodyPr = txBody.firstChild(named: "a:bodyPr") {
            let vert = bodyPr[attribute: "vert"] ?? "horz"
            let numColRaw = bodyPr[attribute: "numCol"]
            let numCol = bodyPr.boundedInt("numCol", in: 1...16) ?? 1
            if (vert == "vert" || vert == "vert270") && (numColRaw == nil || numColRaw == "1") {
                let copy = txBody.deepCopy()
                copy.firstChild(named: "a:bodyPr")?[attribute: "vert"] = nil
                let transform = vert == "vert"
                    ? "translate(\(f.0 + f.2) \(f.1)) rotate(90)"
                    : "translate(\(f.0) \(f.1 + f.3)) rotate(-90)"
                let inner = renderText(copy, box: (0, 0, f.3, f.2), inheriting: defaults,
                                       fontReference: fontReference, respectInsets: respectInsets,
                                       insets: insets, verticalAnchor: verticalAnchor,
                                       context: context, owner: owner)
                return inner.isEmpty ? "" : "<g transform=\"\(transform)\">\(inner)</g>"
            }
            if numCol > 1 && vert == "horz" {
                let paragraphs = txBody.children(named: "a:p")
                if !paragraphs.isEmpty {
                    let spcCol = max(0, bodyPr.coordinate("spcCol") ?? 0)
                    let lIns = max(0, bodyPr.coordinate("lIns") ?? 91440)
                    let rIns = max(0, bodyPr.coordinate("rIns") ?? 91440)
                    let usableW = max(1, f.2 - lIns - rIns - spcCol * (numCol - 1))
                    let colW = max(1, usableW / numCol)
                    let perCol = max(1, (paragraphs.count + numCol - 1) / numCol)
                    var colSVG = ""
                    for col in 0..<numCol {
                        let startIdx = col * perCol
                        guard startIdx < paragraphs.count else { break }
                        let endIdx = min(paragraphs.count, startIdx + perCol)
                        let sliceBody = XML.Element(txBody.name, attributes: txBody.attributes)
                        let slicePr = bodyPr.deepCopy()
                        slicePr[attribute: "numCol"] = nil
                        slicePr[attribute: "spcCol"] = nil
                        slicePr[attribute: "lIns"] = "0"
                        slicePr[attribute: "rIns"] = "0"
                        sliceBody.appendElement(slicePr)
                        if let lstStyle = txBody.firstChild(named: "a:lstStyle") {
                            sliceBody.appendElement(lstStyle.deepCopy())
                        }
                        for p in paragraphs[startIdx..<endIdx] {
                            sliceBody.appendElement(p.deepCopy())
                        }
                        let colX = f.0 + lIns + col * (colW + spcCol)
                        colSVG += renderText(sliceBody, box: (colX, f.1, colW, f.3), inheriting: defaults,
                                             fontReference: fontReference, respectInsets: respectInsets,
                                             insets: insets, verticalAnchor: verticalAnchor,
                                             context: context, owner: owner)
                    }
                    return colSVG
                }
            }
        }
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
            slideNumber: slideNumber, maxLines: 64, insets: insets, verticalAnchor: verticalAnchor, context: context)
        diagnostics.text(layout)
        let decimal = SVGNumber.decimal
        // A narrow table cell can produce many one-span lines. Scope one
        // inherited policy to this text body when every emitted run agrees.
        let blockDisablesLigatures = layout.lines.count > 1
            && layout.lines.contains { !$0.spans.isEmpty }
            && layout.lines.allSatisfy { $0.spans.allSatisfy { !$0.run.usesStandardLigatures } }
        let ligatureStyle = " style=\"font-feature-settings: 'liga' 0\""
        var pictureBulletsSVG = ""
        let paragraphs = txBody.children(named: "a:p")
        if paragraphs.contains(where: { $0.firstChild(named: "a:pPr")?.firstChild(named: "a:buBlip") != nil }) {
            let resolvedOwner = owner ?? slidePart
            for (pIndex, p) in paragraphs.enumerated() where pIndex < layout.lines.count {
                guard let buBlip = p.firstChild(named: "a:pPr")?.firstChild(named: "a:buBlip")?.firstChild(named: "a:blip"),
                      let resource = SVGEmbeddedImage.resolve(in: buBlip, owner: resolvedOwner, package: package, resources: diagnostics.images),
                      resource.supported,
                      let url = diagnostics.images.url(for: resource) else { continue }
                let line = layout.lines[pIndex]
                let firstSpan = line.spans.first
                let fontSize = firstSpan?.run.fontSize ?? 18.0
                let sizeEMU = max(12700, Int((fontSize * 0.75 * Double(emuPerPoint)).rounded()))
                let spanX = firstSpan?.x ?? 0
                let bx = f.0 + max(0, Int((spanX * Double(emuPerPoint)).rounded()) - Int(Double(sizeEMU) * 1.35))
                let by = Int((Double(f.1) + line.baseline * Double(emuPerPoint)).rounded()) - Int(Double(sizeEMU) * 0.85)
                pictureBulletsSVG += "<image data-rostrum-bullet=\"blip\" x=\"\(bx)\" y=\"\(by)\" width=\"\(sizeEMU)\" height=\"\(sizeEMU)\" href=\"\(url)\"/>"
            }
        }
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
                let previewFace = run.fontFamily.flatMap {
                    fonts.previewFace(for: FontFaceKey(family: $0, bold: run.bold, italic: run.italic))
                }
                if !span.followsPreviousRun { usesViewerAdvances = false }
                result += "<tspan"
                var markOffsetsApplied = false
                if !usesViewerAdvances, let previewFace,
                   run.text.unicodeScalars.contains(where: { $0.properties.isGraphemeExtend }),
                   let metrics = fonts.metrics(for: previewFace) {
                    let shaped = TextShaper(metrics).shape(
                        run.text,
                        pointSize: run.measurementPointSize,
                        kerning: run.usesKerning,
                        standardLigatures: run.usesStandardLigatures
                    )
                    if shaped.isSupported,
                       shaped.glyphs.count == run.text.unicodeScalars.count,
                       shaped.glyphs.contains(where: { $0.xOffset != 0 || $0.yOffset != 0 }) {
                        var xs: [String] = []
                        var dys: [String] = []
                        var pen = span.x
                        var prevY = 0.0
                        for g in shaped.glyphs {
                            xs.append(decimal(pen + g.xOffset))
                            let curY = -g.yOffset
                            dys.append(decimal(curY - prevY))
                            prevY = curY
                            pen += g.advance
                        }
                        result += " x=\"\(xs.joined(separator: " "))\""
                        if shaped.glyphs.contains(where: { $0.yOffset != 0 }) {
                            result += " dy=\"\(dys.joined(separator: " "))\""
                        }
                        markOffsetsApplied = true
                    }
                }
                // Once a run uses an unregistered viewer font, let adjacent
                // runs follow its actual advance. An estimated absolute x can
                // overlap the preceding glyphs. Tabs and bullets reset flow.
                if !usesViewerAdvances && !markOffsetsApplied {
                    let positions = span.scalarPositions.map { $0.map(decimal).joined(separator: " ") } ?? decimal(span.x)
                    result += " x=\"\(positions)\""
                }
                result += diagnostics.textAttributes.attributes(for: run, family: embedded ?? previewFace?.family ?? run.fontFamily, inheritsDisabledStandardLigatures: inheritsDisabled)
                // An estimated width is useful for wrapping, but must not
                // squeeze the viewer's real glyphs into that estimate.
                let measured = previewFace != nil
                if measured, !markOffsetsApplied, run.nativeSizing == nil, span.width > 0 { result += " textLength=\"\(decimal(span.width))\" lengthAdjust=\"spacingAndGlyphs\"" }
                usesViewerAdvances = usesViewerAdvances || !measured
                result += ">" + escape(run.text) + "</tspan>"
            }
            return result + "</text>"
        }.joined()
        let fullText = blockDisablesLigatures ? "<g" + ligatureStyle + ">" + text + "</g>" : text
        return pictureBulletsSVG + fullText
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
                             typeface: String?, italic: Bool = false) -> String {
        "<text transform=\"translate(\(x),\(baseline)) scale(\(emuPerPoint))\" "
            + "font-size=\"\(points(sizeEMU))\" fill=\"\(fill)\" text-anchor=\"\(anchor)\""
            + fontFamilyAttr(typeface)
            + (bold ? " font-weight=\"bold\"" : "") + (italic ? " font-style=\"italic\"" : "") + ">"
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
        let shapeRotation = ShapeTransform.rotation(of: pic).truncatingRemainder(dividingBy: 360)
        guard let fill = imagePattern(blip, ownedBy: owner, box: f, defs: &defs, shapeRotation: shapeRotation) else {
            problems.record("Preview could not resolve a picture or its crop bounds."); return ""
        }
        let geom = spPr.firstChild(named: "a:prstGeom")
        return SVGPresetGeometry.render(geom?[attribute: "prst"] ?? "rect", adjustments: geom?.firstChild(named: "a:avLst"), frame: f, fill: fill, stroke: strokeAttrs(spPr))
    }

    /// Read supported embedded raster or self-contained SVG bytes without recoding.
    private func imageResource(in blip: XML.Element, ownedBy owner: Part) -> (url: String, nativeSize: (width: Double, height: Double))? {
        guard let resource = SVGEmbeddedImage.resolve(in: blip, owner: owner, package: package, resources: diagnostics.images),
              let size = resource.nativeSize, let url = diagnostics.images.url(for: resource) else { return nil }
        return (url, size)
    }

    /// Crop and stretch share ImagePlacement with picture editing. Tile uses
    /// the image's physical native size, percentage scale, alignment, offsets
    /// and optional alternating mirror tiles. SVG preserves intrinsic alpha.
    private func imagePattern(_ blip: XML.Element, ownedBy owner: Part,
                              box frame: (Int, Int, Int, Int), defs: inout SVGDefinitions,
                              shapeRotation: Double = 0) -> String? {
        guard let node = blip.firstChild(named: "a:blip"),
              let resource = imageResource(in: node, ownedBy: owner), frame.2 > 0, frame.3 > 0 else { return nil }
        // Definitions only grow; byte count gives unique IDs without rescanning
        // all preceding base64 image data for extended grapheme clusters.
        let id = defs.nextID("image")
        let blipEffect = SVGPaint.blipFilterSVG(id: "\(id)Filter", blip: node, theme: theme)
        var filterAttr = ""
        if let filterDef = blipEffect.filterDef {
            defs += filterDef
            filterAttr = " filter=\"url(#\(id)Filter)\""
        }
        if let opacity = blipEffect.opacity {
            filterAttr += " opacity=\"\(SVGNumber.decimal(opacity))\""
        }
        var patternTransformAttr = ""
        if (blip[attribute: "rotWithShape"] == "0" || blip[attribute: "rotWithShape"] == "false") && shapeRotation != 0 {
            let cx = Double(frame.0) + Double(frame.2) / 2
            let cy = Double(frame.1) + Double(frame.3) / 2
            patternTransformAttr = " patternTransform=\"rotate(\(SVGNumber.decimal(-shapeRotation)) \(cx) \(cy))\""
        }
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
            let image = "<g clip-path=\"url(#\(clipID))\"><image x=\"\(-crop.left * imageWidth)\" y=\"\(-crop.top * imageHeight)\" width=\"\(imageWidth)\" height=\"\(imageHeight)\" preserveAspectRatio=\"none\"\(filterAttr) href=\"\(resource.url)\"/></g>"
            defs += "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" x=\"\(x)\" y=\"\(y)\" width=\"\(width * (mirrorX ? 2 : 1))\" height=\"\(height * (mirrorY ? 2 : 1))\"\(patternTransformAttr)>\(image)"
            if mirrorX { defs += "<g transform=\"translate(\(2 * width) 0) scale(-1 1)\">\(image)</g>" }
            if mirrorY { defs += "<g transform=\"translate(0 \(2 * height)) scale(1 -1)\">\(image)</g>" }
            if mirrorX && mirrorY { defs += "<g transform=\"translate(\(2 * width) \(2 * height)) scale(-1 -1)\">\(image)</g>" }
            defs += "</pattern>"
        } else {
            guard let mapping = ImagePlacement(fill: blip, frame: frame) else { return nil }
            let clipID = "\(id)Clip"
            defs += "<clipPath id=\"\(clipID)\"><rect x=\"\(mapping.clip.x - Double(frame.0))\" y=\"\(mapping.clip.y - Double(frame.1))\" width=\"\(mapping.clip.width)\" height=\"\(mapping.clip.height)\"/></clipPath>"
            defs += "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" x=\"\(frame.0)\" y=\"\(frame.1)\" width=\"\(frame.2)\" height=\"\(frame.3)\"\(patternTransformAttr)>"
                + "<g clip-path=\"url(#\(clipID))\"><image x=\"\(mapping.image.x - Double(frame.0))\" y=\"\(mapping.image.y - Double(frame.1))\" width=\"\(mapping.image.width)\" height=\"\(mapping.image.height)\" preserveAspectRatio=\"none\"\(filterAttr) href=\"\(resource.url)\"/></g></pattern>"
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
        if uri == ExtendedChart.namespace, let plot = renderExtendedChart(gf, ownedBy: owner, x: x, y: y, w: w, h: h) {
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
        if uri.hasSuffix("/chart") || uri == ExtendedChart.namespace { label = "[chart]" }
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
        var groupTransform = "translate(\(x) \(y))"
        if let transform = tree.firstChild(named: "dsp:grpSpPr")?.firstChild(named: "a:xfrm"),
           transform.childElements.contains(where: { $0.attributes.contains { Double($0.value) != 0 } }) {
            if let outer = ShapeTransform.rect(transform),
               let child = ShapeTransform.childSpace(transform),
               outer.width.rawValue > 0, outer.height.rawValue > 0,
               child.width.rawValue > 0, child.height.rawValue > 0 {
                let sx = Double(outer.width.rawValue) / Double(child.width.rawValue)
                let sy = Double(outer.height.rawValue) / Double(child.height.rawValue)
                groupTransform = "translate(\(x + outer.x.rawValue) \(y + outer.y.rawValue)) scale(\(sx) \(sy)) translate(\(-child.x.rawValue) \(-child.y.rawValue))"
            } else {
                return nil
            }
        }
        // Copies keep all unknown diagram XML byte-faithful in the package.
        func normalize(_ node: XML.Element, depth: Int = 0) -> XML.Element? {
            guard depth < 64 else { return nil }
            let copy = XML.Element(node.name, attributes: node.attributes)
            if ["dsp:sp", "dsp:grpSp", "dsp:cxnSp", "dsp:spPr", "dsp:grpSpPr", "dsp:nvSpPr", "dsp:nvGrpSpPr", "dsp:nvCxnSpPr",
                "dsp:cNvPr", "dsp:cNvSpPr", "dsp:cNvGrpSpPr", "dsp:cNvCxnSpPr", "dsp:style", "dsp:txBody"].contains(node.name) {
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
        guard tree.childElements.contains(where: { ["dsp:sp", "dsp:grpSp", "dsp:cxnSp"].contains($0.name) }) else { return nil }
        var output = ""
        let location = diagnostics.location
        defer { diagnostics.location = location }
        for node in tree.childElements where !["dsp:nvGrpSpPr", "dsp:grpSpPr", "dsp:extLst"].contains(node.name) {
            guard let shape = normalize(node), ["p:sp", "p:grpSp", "p:cxnSp"].contains(shape.name) else { return nil }
            diagnostics.inspect(shape, owner: drawing, slideIndex: slideNumber - 1,
                path: "/dsp:drawing/dsp:spTree/" + node.name, package: package)
            output += renderNode(shape, ownedBy: drawing, defs: &defs, problems: &problems)
        }
        return "<g data-rostrum-diagram=\"cached\" transform=\"\(groupTransform)\">\(output)</g>"
    }

    // MARK: - Charts

    /// Fallback series colors for decks whose theme has no accents.
    private static let chartPalette = ["#4472C4", "#ED7D31", "#A5A5A5", "#FFC000", "#5B9BD5", "#70AD47"]

    /// Plot a chart part into `frame`, or nil for a kind we don't draw (the
    /// caller then falls back to the labeled placeholder). Text is measured
    /// with registered faces; automatic chart geometry still approximates
    /// PowerPoint. Data and styles come from the saved chart XML.
    ///
    /// All scaling runs in `Double` and lands through `coord`: chart values
    /// come from the file unbounded, and coordinates are only bounded to
    /// ±2^40, so multiplying two of them would overflow `Int`.
    private struct ChartTextAppearance {
        var size = 10 * 12700
        var fill: String
        var typeface: String?
        var bold = false
        var italic = false
        var measurementFamily = "Calibri"
        var kerningThreshold: Int?
        var kerning: Bool { kerningThreshold.map { $0 > 0 && size >= $0 * 127 } ?? true }
        var measurement: ChartTextMeasurer.Style {
            .init(face: FontFaceKey(family: measurementFamily, bold: bold, italic: italic), size: size, kerning: kerning)
        }
    }

    private func chartTextStyle(_ nodes: [XML.Element?], color: String, size: Int = 127000) -> ChartTextAppearance {
        var style = ChartTextAppearance(size: size, fill: color)
        for node in nodes.compactMap({ $0 }) {
            let paragraph = node.firstChild(named: "a:p")
            let defaults = paragraph?.firstChild(named: "a:pPr")?.firstChild(named: "a:defRPr")
            let run = paragraph?.firstChild(named: "a:r")?.firstChild(named: "a:rPr")
            for properties in [defaults, run].compactMap({ $0 }) {
                if let size = properties.boundedInt("sz", in: 100...40_000) { style.size = size * 127 }
                if let fill = colorHex(in: properties.firstChild(named: "a:solidFill")) { style.fill = fill }
                if let family = properties.firstChild(named: "a:latin")?[attribute: "typeface"] {
                    style.typeface = family == "+mj-lt" ? theme.majorFont : family == "+mn-lt" ? theme.minorFont : family
                }
                if let bold = properties[attribute: "b"] { style.bold = ["1", "true"].contains(bold) }
                if let italic = properties[attribute: "i"] { style.italic = ["1", "true"].contains(italic) }
                if let kern = properties.boundedInt("kern", in: 0...400_000) {
                    style.kerningThreshold = kern
                }
            }
        }
        style.measurementFamily = style.typeface ?? theme.minorFont ?? "Calibri"
        style.typeface = style.measurementFamily
        if let family = style.typeface {
            let face = FontFaceKey(family: family, bold: style.bold, italic: style.italic)
            style.typeface = diagnostics.embeddedFamily(for: face, fonts: fonts) ?? family
        }
        return style
    }

    private func chartTextElement(_ value: String, x: Double, baseline: Double,
                                  style: ChartTextAppearance, anchor: String) -> String {
        textElement(value, x: coord(x), baseline: coord(baseline), sizeEMU: style.size,
            fill: style.fill, anchor: anchor, bold: style.bold, typeface: style.typeface, italic: style.italic)
            .replacingOccurrences(of: "<text ", with: "<text font-kerning=\"\(style.kerning ? "normal" : "none")\" ")
    }

    private func chartNumberFormat(_ code: String) -> ChartNumberFormat {
        let format = ChartNumberFormat(code)
        if !format.isSupported {
            diagnostics.record(.chartApproximation, .approximation,
                "Chart number format is outside the supported numeric subset; preview uses General formatting.")
        }
        return format
    }

    private struct ChartBarRect {
        let x: Double, y: Double, width: Double, height: Double
    }
    private struct ChartLabel {
        let hidden: Bool
        let showValue: Bool, showCategory: Bool, showSeries: Bool, showPercent: Bool, showBubbleSize: Bool
        let customText: String?
        let position: String, separator: String
        let format: ChartNumberFormat
        let percentFormat: ChartNumberFormat
        let style: ChartTextAppearance
    }
    private struct ChartLabels {
        let standard: ChartLabel
        let points: [Int: ChartLabel]
    }

    private static func extractChartTxText(_ tx: XML.Element?) -> String? {
        guard let tx else { return nil }
        if let rich = tx.firstChild(named: "c:rich") {
            let text = rich.children(named: "a:p").map { p in
                p.childElements.compactMap { child -> String? in
                    switch child.name {
                    case "a:r", "a:fld": return child.firstChild(named: "a:t")?.textContent
                    case "a:br": return "\n"
                    default: return nil
                    }
                }.joined()
            }.joined(separator: "\n")
            if !text.isEmpty { return text }
        }
        if let pts = tx.firstChild(named: "c:strRef")?.firstChild(named: "c:strCache")?.children(named: "c:pt") {
            let text = pts.compactMap { $0.firstChild(named: "c:v")?.textContent }.joined(separator: " ")
            if !text.isEmpty { return text }
        }
        if let v = tx.firstChild(named: "c:v")?.textContent, !v.isEmpty {
            return v
        }
        return nil
    }

    private func chartLabels(plot: XML.Element?, series: [XML.Element], chartText: XML.Element?,
                             kind: String, seriesPlots: [XML.Element] = []) -> [ChartLabels] {
        var formats: [String: ChartNumberFormat] = [:]
        func label(_ nodes: [XML.Element], plotKind: String) -> ChartLabel {
            func property(_ name: String) -> XML.Element? {
                nodes.reversed().lazy.compactMap { $0.firstChild(named: name) }.first
            }
            func flag(_ name: String) -> Bool { ["1", "true"].contains(property(name)?[attribute: "val"] ?? "0") }
            let explicitCode = property("c:numFmt")?[attribute: "formatCode"]
            let code = explicitCode ?? "General"
            let format = formats[code] ?? chartNumberFormat(code)
            formats[code] = format
            let percentCode = explicitCode ?? "0%"
            let percentFormat = formats[percentCode] ?? chartNumberFormat(percentCode)
            formats[percentCode] = percentFormat
            let defaultPos = ["lineChart", "line3DChart", "scatterChart", "bubbleChart", "radarChart"].contains(plotKind) ? "t" : "outEnd"
            let position = property("c:dLblPos")?[attribute: "val"] ?? defaultPos
            let customTxNode = property("c:tx")
            let customText = Self.extractChartTxText(customTxNode)
            if !["outEnd", "inEnd", "inBase", "ctr", "bestFit", "t", "b", "l", "r"].contains(position)
                || (flag("c:showPercent") && !["pieChart", "pie3DChart", "doughnutChart", "ofPieChart"].contains(plotKind))
                || (customTxNode != nil && customText == nil) {
                diagnostics.record(.chartApproximation, .approximation,
                    "Custom chart label text or unsupported label properties are approximated.")
            }
            return ChartLabel(hidden: flag("c:delete"), showValue: flag("c:showVal"),
                showCategory: flag("c:showCatName"), showSeries: flag("c:showSerName"),
                showPercent: flag("c:showPercent"), showBubbleSize: flag("c:showBubbleSize"),
                customText: customText,
                position: position, separator: property("c:separator")?.textContent ?? ", ", format: format,
                percentFormat: percentFormat,
                style: chartTextStyle([chartText] + nodes.map { $0.firstChild(named: "c:txPr") }
                    + [customTxNode?.firstChild(named: "c:rich")], color: "#666666"))
        }
        return series.enumerated().map { s, series in
            let owningPlot = s < seriesPlots.count ? seriesPlots[s] : plot
            let plotKind = owningPlot?.name.split(separator: ":").last.map(String.init) ?? kind
            let nodes = [owningPlot?.firstChild(named: "c:dLbls"), series.firstChild(named: "c:dLbls")].compactMap { $0 }
            let standard = label(nodes, plotKind: plotKind)
            var overrides: [Int: [XML.Element]] = [:]
            for node in nodes {
                for point in node.children(named: "c:dLbl") {
                    if let index = point.firstChild(named: "c:idx")?.boundedInt("val", in: 0...511) {
                        overrides[index, default: []].append(point)
                    }
                }
            }
            var points: [Int: ChartLabel] = [:]
            for index in overrides.keys.sorted() { points[index] = label(nodes + overrides[index]!, plotKind: plotKind) }
            return ChartLabels(standard: standard, points: points)
        }
    }

    private struct ChartPreparedText {
        let source: String
        let block: ChartTextMeasurer.Block
        let style: ChartTextAppearance
    }
    private struct ChartPreparedLabel {
        let text: ChartPreparedText
        let position: String
    }
    private struct ChartTick {
        let value: Double
        let text: ChartPreparedText?
    }

    private func prepareChartText(_ value: String, style: ChartTextAppearance,
                                  measure: ChartTextMeasurer, width: Double, lines: Int = 3) -> ChartPreparedText? {
        guard let block = measure.block(value, style: style.measurement, width: width, maxLines: lines) else { return nil }
        return ChartPreparedText(source: value, block: block, style: style)
    }

    private func chartTextBlock(_ text: ChartPreparedText, in rect: ChartTextRect,
                                anchor: String = "start", role: String) -> String {
        var out = "<g data-rostrum-chart-role=\"\(role)\" data-rostrum-chart-bounds=\"\(coord(rect.x)) \(coord(rect.y)) \(coord(rect.width)) \(coord(rect.height))\">"
        let x = anchor == "middle" ? rect.x + rect.width / 2 : anchor == "end" ? rect.right : rect.x
        for (index, line) in text.block.lines.enumerated() {
            out += chartTextElement(line.text, x: x,
                baseline: rect.y + text.block.ascent + Double(index) * text.block.lineHeight,
                style: text.style, anchor: anchor)
        }
        return out + "</g>"
    }

    private func chartOmission(_ role: String) {
        diagnostics.record(.chartApproximation, .omission,
            "Chart preview omits \(role) that cannot fit without overlapping or leaving the chart frame. Source content is unchanged.")
    }

    private func chartTicks(scale: ValueScale, axis: XML.Element?, style: ChartTextAppearance,
                            measure: ChartTextMeasurer, width: Double) -> [ChartTick] {
        guard let axis, !["1", "true"].contains(axis.firstChild(named: "c:delete")?[attribute: "val"] ?? "0") else { return [] }
        let exponent = pow(10, floor(log10(scale.range / 5)))
        guard exponent.isFinite, exponent > 0 else { return [] }
        let unit = ([1.0, 2, 5, 10].first { $0 * exponent >= scale.range / 5 } ?? 10) * exponent
        let requested = axis.firstChild(named: "c:majorUnit")?[attribute: "val"].flatMap(Double.init)
        let step = requested.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? unit
        let start = ceil(scale.minimum / step) * step
        let formatter = chartNumberFormat(axis.firstChild(named: "c:numFmt")?[attribute: "formatCode"] ?? "General")
        let visible = axis.firstChild(named: "c:tickLblPos")?[attribute: "val"] != "none"
        var ticks: [ChartTick] = []
        for i in 0..<128 {
            let value = start + Double(i) * step
            guard value.isFinite, value <= scale.minimum + scale.range + step * 1e-8 else { break }
            let text = visible ? prepareChartText(formatter.string(value), style: style, measure: measure, width: width, lines: 2) : nil
            if visible && text == nil { chartOmission("value-axis labels") }
            ticks.append(ChartTick(value: value, text: text))
        }
        if start + 128 * step <= scale.minimum + scale.range {
            diagnostics.record(.chartApproximation, .omission, "Chart preview bounds value-axis ticks to 128.")
        }
        return ticks
    }

    private func chartAxisTitle(_ axis: XML.Element?, chartText: XML.Element?,
                                measure: ChartTextMeasurer, content: inout ChartTextRect,
                                vertical: Bool, rightSide: Bool = false) -> String {
        guard !["1", "true"].contains(axis?.firstChild(named: "c:delete")?[attribute: "val"] ?? "0"),
              let node = axis?.firstChild(named: "c:title") else { return "" }
        func text(_ node: XML.Element, depth: Int = 0) -> String {
            guard depth < 32 else { return "" }
            if node.name == "a:t" || node.name == "c:v" { return node.textContent }
            return node.childElements.map { text($0, depth: depth + 1) }.joined()
        }
        let value = text(node.firstChild(named: "c:tx") ?? node)
        guard !value.isEmpty else { return "" }
        let style = chartTextStyle([chartText, node.firstChild(named: "c:txPr"),
            node.firstChild(named: "c:tx")?.firstChild(named: "c:rich")], color: "#666666")
        guard let prepared = prepareChartText(value, style: style, measure: measure,
            width: vertical ? content.height : content.width, lines: 2),
            prepared.block.height < (vertical ? content.width : content.height) * 0.2 else {
            chartOmission("axis titles"); return ""
        }
        let gap = 6.0 * Double(emuPerPoint), height = prepared.block.height
        if vertical {
            let centerY = content.y + content.height / 2
            let xPos = rightSide ? content.right - height : content.x
            let rect = ChartTextRect(x: xPos, y: centerY - prepared.block.width / 2,
                                     width: height, height: prepared.block.width)
            var out = "<g data-rostrum-chart-role=\"axis-title\" data-rostrum-chart-bounds=\"\(coord(rect.x)) \(coord(rect.y)) \(coord(rect.width)) \(coord(rect.height))\" transform=\"translate(\(coord(xPos)),\(coord(centerY))) rotate(-90)\">"
            for (index, line) in prepared.block.lines.enumerated() {
                out += chartTextElement(line.text, x: 0, baseline: prepared.block.ascent + Double(index) * prepared.block.lineHeight,
                    style: style, anchor: "middle")
            }
            if !rightSide { content.x += height + gap }
            content.width -= height + gap
            return out + "</g>"
        }
        let rect = ChartTextRect(x: content.x, y: content.bottom - height, width: content.width, height: height)
        content.height -= height + gap
        return chartTextBlock(prepared, in: rect, anchor: "middle", role: "axis-title")
    }

    /// Reserve just the rows/column actually occupied by measured entries.
    private func chartLegend(_ names: [String], position: String, style: ChartTextAppearance,
                             measure: ChartTextMeasurer, content: inout ChartTextRect,
                             color: (Int) -> String) -> String {
        let gap = 4.0 * Double(emuPerPoint), swatch = Double(style.size) * 0.7
        let vertical = ["l", "r", "tr"].contains(position)
        let maxWidth = vertical ? content.width * 0.35 : content.width
        let maxHeight = vertical ? content.height : content.height * 0.3
        var items: [(Int, ChartPreparedText, ChartTextRect)] = []
        var x = 0.0, y = 0.0, rowHeight = 0.0, usedWidth = 0.0
        for (index, name) in names.prefix(512).enumerated() where !name.isEmpty {
            guard let text = prepareChartText(name, style: style, measure: measure,
                width: maxWidth - swatch - gap, lines: 3) else { chartOmission("legend entries"); continue }
            let itemWidth = swatch + gap + text.block.width
            let itemHeight = max(swatch, text.block.height)
            if !vertical && x > 0 && x + itemWidth > maxWidth { x = 0; y += rowHeight + gap; rowHeight = 0 }
            guard y + itemHeight <= maxHeight else { chartOmission("legend entries"); continue }
            let rect = ChartTextRect(x: x, y: y, width: itemWidth, height: itemHeight)
            items.append((index, text, rect))
            usedWidth = max(usedWidth, rect.right)
            if vertical { y += itemHeight + gap }
            else { x += itemWidth + gap * 2; rowHeight = max(rowHeight, itemHeight) }
        }
        guard !items.isEmpty else { return "" }
        let usedHeight = items.map { $0.2.bottom }.max() ?? 0
        let left = vertical && position != "l" ? content.right - usedWidth : content.x
        let top = !vertical && position != "t" ? content.bottom - usedHeight : content.y
        var out = ""
        for (index, text, rect) in items {
            out += box(coord(left + rect.x), coord(top + rect.y + (rect.height - swatch) / 2),
                       coord(swatch), coord(swatch), fill: color(index))
            out += chartTextBlock(text, in: ChartTextRect(x: left + rect.x + swatch + gap,
                y: top + rect.y, width: text.block.width, height: text.block.height), role: "legend")
        }
        if vertical {
            if position == "l" { content.x += usedWidth + gap * 2 }
            content.width -= usedWidth + gap * 2
        } else {
            if position == "t" { content.y += usedHeight + gap * 2 }
            content.height -= usedHeight + gap * 2
        }
        return out
    }

    private func prepareChartLabels(_ specs: [ChartLabels], series: [ChartData.Series], categories: [String],
                                    xySeries: [Chart.XYSeries] = [], kind: String, measure: ChartTextMeasurer,
                                    bounds: ChartTextRect) -> [[Int: ChartPreparedLabel]] {
        var count = 0
        let pie = ["pieChart", "pie3DChart", "doughnutChart", "ofPieChart"].contains(kind)
        let isXY = ["scatterChart", "bubbleChart"].contains(kind)
        return series.enumerated().map { s, entry in
            var result: [Int: ChartPreparedLabel] = [:]
            let positive = entry.values.prefix(512).compactMap { $0 }.filter { $0.isFinite && $0 > 0 }
            // Normalize before summing so very large finite pie values remain usable.
            let largest = positive.max() ?? 1
            let total = positive.reduce(0) { $0 + $1 / largest }
            let xy = s < xySeries.count ? xySeries[s] : nil
            for index in 0..<min(512, entry.values.count) {
                guard let value = Self.finite(entry, index), !pie || value > 0 else { continue }
                let spec = specs[s].points[index] ?? specs[s].standard
                guard !spec.hidden else { continue }
                let labelString: String
                if let customText = spec.customText, !customText.isEmpty {
                    labelString = customText
                } else {
                    var fields: [String] = []
                    if spec.showSeries { fields.append(entry.name) }
                    if spec.showCategory {
                        if isXY, let xy {
                            if index < xy.points.count, let x = xy.points[index].x, x.isFinite {
                                fields.append(spec.format.string(x))
                            } else if index < xy.xLabels.count, !xy.xLabels[index].isEmpty {
                                fields.append(xy.xLabels[index])
                            }
                        } else if categories.indices.contains(index) {
                            fields.append(categories[index])
                        }
                    }
                    if spec.showValue { fields.append(spec.format.string(value)) }
                    if spec.showBubbleSize, kind == "bubbleChart", let xy, index < xy.points.count,
                       let size = xy.points[index].size, size.isFinite {
                        fields.append(spec.format.string(size))
                    }
                    if spec.showPercent && pie { fields.append(spec.percentFormat.string(total > 0 ? value / largest / total : 0)) }
                    guard !fields.isEmpty else { continue }
                    labelString = fields.joined(separator: spec.separator)
                }
                guard count < 512 else { chartOmission("data labels above the 512-label preview bound"); continue }
                count += 1
                guard let text = prepareChartText(labelString, style: spec.style,
                    measure: measure, width: bounds.width * 0.35, lines: 3), text.block.height <= bounds.height * 0.35 else {
                    chartOmission("data labels"); continue
                }
                result[index] = ChartPreparedLabel(text: text, position: spec.position)
            }
            return result
        }
    }

    private func renderBarLabel(_ label: ChartPreparedLabel?, value: Double, rect: ChartBarRect,
                                horizontal: Bool, placements: ChartLabelPlacement) -> String {
        guard let label else { return "" }
        let width = label.text.block.width, height = label.text.block.height
        let gap = 3.0 * Double(emuPerPoint)
        let centered = label.position == "ctr" || label.position == "bestFit"
        let inside = label.position == "inEnd", base = label.position == "inBase"
        var x = rect.x + (rect.width - width) / 2, y = rect.y + (rect.height - height) / 2
        var anchor = "middle"
        if !centered {
            if horizontal {
                let right = base ? value < 0 : value >= 0
                let edge = right ? rect.x + rect.width : rect.x
                let beforeEdge = right == (inside || base)
                x = beforeEdge ? edge - gap - width : edge + gap
                anchor = beforeEdge ? "end" : "start"
            } else {
                let top = base ? value < 0 : value >= 0
                let edge = top ? rect.y : rect.y + rect.height
                y = top == (inside || base) ? edge + gap : edge - gap - height
            }
        }
        let desired = ChartTextRect(x: x, y: y, width: width, height: height)
        if centered || inside || base {
            guard ChartTextRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height).contains(desired) else {
                chartOmission("data labels inside small bars"); return ""
            }
        }
        guard let placed = placements.place([desired]) else { chartOmission("data labels"); return "" }
        return chartTextBlock(label.text, in: placed, anchor: anchor, role: "data-label")
    }

    private func renderPointLabel(_ label: ChartPreparedLabel?, x: Double, y: Double,
                                  placements: ChartLabelPlacement) -> String {
        guard let label else { return "" }
        let width = label.text.block.width, height = label.text.block.height, gap = 5.0 * Double(emuPerPoint)
        let top = ChartTextRect(x: x - width / 2, y: y - gap - height, width: width, height: height)
        let bottom = ChartTextRect(x: x - width / 2, y: y + gap, width: width, height: height)
        let left = ChartTextRect(x: x - gap - width, y: y - height / 2, width: width, height: height)
        let right = ChartTextRect(x: x + gap, y: y - height / 2, width: width, height: height)
        let center = ChartTextRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
        let candidates: [ChartTextRect]
        switch label.position {
        case "b": candidates = [bottom]
        case "l": candidates = [left]
        case "r": candidates = [right]
        case "ctr": candidates = [center]
        case "bestFit": candidates = [top, right, bottom, left]
        default: candidates = [top]
        }
        guard let placed = placements.place(candidates) else { chartOmission("data labels"); return "" }
        return chartTextBlock(label.text, in: placed, anchor: "middle", role: "data-label")
    }

    private func measuredPie(_ entry: ChartData.Series, kind: String, plot: XML.Element?,
                             bounds: ChartTextRect, labels: [Int: ChartPreparedLabel], color: (Int) -> String) -> String {
        let gap = 5.0 * Double(emuPerPoint)
        let outside = labels.values.filter { !["ctr", "inEnd", "bestFit"].contains($0.position) }
        let outsideWidth = outside.map { $0.text.block.width }.max() ?? 0
        let radius = min(bounds.width / 2 - (outsideWidth > 0 ? outsideWidth + gap * 2 : 0), bounds.height / 2 - gap)
        guard radius > 0 else { chartOmission("pie geometry and labels"); return "" }
        let cx = bounds.x + bounds.width / 2, cy = bounds.y + bounds.height / 2
        var entries: [(ChartPreparedLabel, Double, Double, Double)] = []
        var out = pieBody(entry, kind: kind, plot: plot, cx: cx, cy: cy, radius: radius, color: color,
            label: { index, angle, r in
                if let label = labels[index] { entries.append((label, angle, cx + r * cos(angle), cy + r * sin(angle))) }
            })
        let placements = ChartLabelPlacement(bounds: bounds)
        for (label, angle, _, _) in entries where ["ctr", "inEnd", "bestFit"].contains(label.position) {
            let distance = kind == "doughnutChart" ? radius * 0.79 : radius * 0.60
            let rect = ChartTextRect(x: cx + distance * cos(angle) - label.text.block.width / 2,
                y: cy + distance * sin(angle) - label.text.block.height / 2,
                width: label.text.block.width, height: label.text.block.height)
            // A rectangle's four corners must fit inside the circle.
            let inside = [rect.x, rect.right].allSatisfy { x in
                [rect.y, rect.bottom].allSatisfy { y in hypot(x - cx, y - cy) <= radius }
            }
            if inside, let placed = placements.place([rect]) {
                out += chartTextBlock(label.text, in: placed, anchor: "middle", role: "data-label")
            } else { chartOmission("pie data labels"); }
        }
        for right in [false, true] {
            let side = entries.enumerated().filter { item in
                !["ctr", "inEnd", "bestFit"].contains(item.element.0.position) && (cos(item.element.1) >= 0) == right
            }.sorted {
                $0.element.3 == $1.element.3 ? $0.offset < $1.offset : $0.element.3 < $1.element.3
            }
            var packed: [(ChartPreparedLabel, Double, Double, ChartTextRect)] = []
            var totalHeight = 0.0
            for item in side {
                let (label, _, sx, sy) = item.element
                let height = label.text.block.height
                guard totalHeight + height <= bounds.height else { chartOmission("pie data labels"); continue }
                let x = right ? cx + radius + gap : cx - radius - gap - label.text.block.width
                let desired = ChartTextRect(x: x, y: sy - height / 2, width: label.text.block.width, height: height)
                packed.append((label, sx, sy, desired))
                totalHeight += height + gap
            }
            var next = bounds.y
            for i in packed.indices {
                packed[i].3.y = max(next, packed[i].3.y)
                next = packed[i].3.bottom + gap
            }
            next = bounds.bottom
            for i in packed.indices.reversed() {
                packed[i].3.y = min(packed[i].3.y, next - packed[i].3.height)
                next = packed[i].3.y - gap
            }
            for (label, sx, sy, desired) in packed {
                guard let rect = placements.place([desired]) else { chartOmission("pie data labels"); continue }
                let ex = right ? rect.x : rect.right, ey = rect.y + rect.height / 2
                out += "<polyline points=\"\(coord(sx)),\(coord(sy)) \(coord(ex)),\(coord(ey))\" fill=\"none\" stroke=\"\(label.text.style.fill)\" stroke-width=\"6350\"/>"
                out += chartTextBlock(label.text, in: rect, anchor: right ? "start" : "end", role: "data-label")
            }
        }
        return out
    }

    private func chartMarker(_ node: XML.Element?, inherited: XML.Element?, x: Double, y: Double, defaultColor: String) -> String {
        guard node != nil || inherited != nil else { return "" }
        func property(_ name: String) -> XML.Element? {
            node?.firstChild(named: name) ?? inherited?.firstChild(named: name)
        }
        let symbol = property("c:symbol")?[attribute: "val"] ?? "none"
        guard symbol != "none" else { return "" }
        let radius = Double((property("c:size")?.boundedInt("val", in: 2...72) ?? 5) * emuPerPoint) / 2
        let properties = node?.firstChild(named: "c:spPr")
        let inheritedProperties = inherited?.firstChild(named: "c:spPr")
        let fillProperties = properties?.firstChild(named: "a:noFill") != nil || properties?.firstChild(named: "a:solidFill") != nil
            ? properties : inheritedProperties
        let fill = fillProperties?.firstChild(named: "a:noFill") != nil ? "none"
            : colorHex(in: fillProperties?.firstChild(named: "a:solidFill")) ?? defaultColor
        let line = properties?.firstChild(named: "a:ln") ?? inheritedProperties?.firstChild(named: "a:ln")
        let stroke = line?.firstChild(named: "a:noFill") != nil ? "none"
            : colorHex(in: line?.firstChild(named: "a:solidFill")) ?? defaultColor
        let attributes = " fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(max(0, line?.coordinate("w") ?? 12700))\""
        switch symbol {
        case "circle", "dot":
            return "<circle cx=\"\(coord(x))\" cy=\"\(coord(y))\" r=\"\(coord(radius))\"\(attributes)/>"
        case "square":
            return "<rect x=\"\(coord(x-radius))\" y=\"\(coord(y-radius))\" width=\"\(coord(2*radius))\" height=\"\(coord(2*radius))\"\(attributes)/>"
        case "diamond":
            return "<polygon points=\"\(coord(x)),\(coord(y-radius)) \(coord(x+radius)),\(coord(y)) \(coord(x)),\(coord(y+radius)) \(coord(x-radius)),\(coord(y))\"\(attributes)/>"
        case "triangle":
            return "<polygon points=\"\(coord(x)),\(coord(y-radius)) \(coord(x+radius)),\(coord(y+radius)) \(coord(x-radius)),\(coord(y+radius))\"\(attributes)/>"
        default:
            diagnostics.record(.chartApproximation, .omission, "Unsupported chart marker symbol is omitted from the preview.")
            return ""
        }
    }

    /// Render `c:trendline` (linear OLS regression) and `c:errBars` whiskers for a series.
    private func renderSeriesOverlays(_ seriesElement: XML.Element, points: [(x: Double, y: Double, val: Double)],
                                      scale: ValueScale, area: ChartTextRect, horizontal: Bool,
                                      defaultColor: String) -> String {
        var svg = ""
        if let errBars = seriesElement.firstChild(named: "c:errBars"), !points.isEmpty {
            let errValType = errBars.firstChild(named: "c:errValType")?[attribute: "val"] ?? "fixedVal"
            let rawVal = errBars.firstChild(named: "c:val")?[attribute: "val"].flatMap(Double.init) ?? 5.0
            let ln = errBars.firstChild(named: "c:spPr")?.firstChild(named: "a:ln")
            let stroke = colorHex(in: ln?.firstChild(named: "a:solidFill")) ?? "#595959"
            let width = max(6350, ln?.coordinate("w") ?? 12700)
            let capHalf = Double(3 * emuPerPoint)
            let noEndCap = ["1", "true"].contains(errBars.firstChild(named: "c:noEndCap")?[attribute: "val"] ?? "0")
            for pt in points {
                let delta: Double
                switch errValType {
                case "percentage": delta = abs(pt.val) * (rawVal / 100.0)
                default: delta = abs(rawVal)
                }
                guard delta > 0, delta.isFinite else { continue }
                if horizontal {
                    let xLo = area.x + area.width * max(0, min(1, scale.fraction(pt.val - delta)))
                    let xHi = area.x + area.width * max(0, min(1, scale.fraction(pt.val + delta)))
                    svg += "<line data-rostrum-chart-role=\"error-bar\" x1=\"\(coord(xLo))\" y1=\"\(coord(pt.y))\" x2=\"\(coord(xHi))\" y2=\"\(coord(pt.y))\" stroke=\"\(stroke)\" stroke-width=\"\(width)\"/>"
                    if !noEndCap {
                        svg += "<line x1=\"\(coord(xLo))\" y1=\"\(coord(pt.y - capHalf))\" x2=\"\(coord(xLo))\" y2=\"\(coord(pt.y + capHalf))\" stroke=\"\(stroke)\" stroke-width=\"\(width)\"/>"
                        svg += "<line x1=\"\(coord(xHi))\" y1=\"\(coord(pt.y - capHalf))\" x2=\"\(coord(xHi))\" y2=\"\(coord(pt.y + capHalf))\" stroke=\"\(stroke)\" stroke-width=\"\(width)\"/>"
                    }
                } else {
                    let yHi = area.y + area.height * (1 - max(0, min(1, scale.fraction(pt.val + delta))))
                    let yLo = area.y + area.height * (1 - max(0, min(1, scale.fraction(pt.val - delta))))
                    svg += "<line data-rostrum-chart-role=\"error-bar\" x1=\"\(coord(pt.x))\" y1=\"\(coord(yHi))\" x2=\"\(coord(pt.x))\" y2=\"\(coord(yLo))\" stroke=\"\(stroke)\" stroke-width=\"\(width)\"/>"
                    if !noEndCap {
                        svg += "<line x1=\"\(coord(pt.x - capHalf))\" y1=\"\(coord(yHi))\" x2=\"\(coord(pt.x + capHalf))\" y2=\"\(coord(yHi))\" stroke=\"\(stroke)\" stroke-width=\"\(width)\"/>"
                        svg += "<line x1=\"\(coord(pt.x - capHalf))\" y1=\"\(coord(yLo))\" x2=\"\(coord(pt.x + capHalf))\" y2=\"\(coord(yLo))\" stroke=\"\(stroke)\" stroke-width=\"\(width)\"/>"
                    }
                }
            }
        }
        for trendline in seriesElement.children(named: "c:trendline") where points.count >= 2 {
            let n = Double(points.count)
            let sumX = points.reduce(0.0) { $0 + $1.x }
            let sumY = points.reduce(0.0) { $0 + $1.y }
            let meanX = sumX / n, meanY = sumY / n
            var num = 0.0, den = 0.0
            for pt in points {
                num += (pt.x - meanX) * (pt.y - meanY)
                den += (pt.x - meanX) * (pt.x - meanX)
            }
            guard den > 1e-9 else { continue }
            let slope = num / den
            let intercept = meanY - slope * meanX
            let x1 = points.first!.x, x2 = points.last!.x
            let y1 = slope * x1 + intercept, y2 = slope * x2 + intercept
            let ln = trendline.firstChild(named: "c:spPr")?.firstChild(named: "a:ln")
            let stroke = colorHex(in: ln?.firstChild(named: "a:solidFill")) ?? defaultColor
            let width = max(6350, ln?.coordinate("w") ?? 19050)
            let dash = dashAttributes(ln, width: width).isEmpty
                ? " stroke-dasharray=\"\(width * 3) \(width * 2)\""
                : dashAttributes(ln, width: width)
            svg += "<line data-rostrum-chart-role=\"trendline\" x1=\"\(coord(x1))\" y1=\"\(coord(y1))\" x2=\"\(coord(x2))\" y2=\"\(coord(y2))\" stroke=\"\(stroke)\" stroke-width=\"\(width)\"\(dash)/>"
        }
        return svg
    }

    private func renderExtendedChart(_ gf: XML.Element, ownedBy owner: Part,
                                     x: Int, y: Int, w: Int, h: Int) -> String? {
        guard w > 0, h > 0 else { return nil }
        let frame = GraphicFrame(element: gf, part: owner, package: package)
        guard let extChart = frame.extendedChart,
              let firstSeries = extChart.series.first,
              !firstSeries.values.isEmpty else { return nil }
        let values = firstSeries.values.prefix(512).map { $0 ?? 0 }
        let categories = extChart.categories
        let count = values.count
        guard count > 0 else { return nil }
        let measure = ChartTextMeasurer(fonts: fonts) { code, impact, message in
            diagnostics.record(code, impact, message)
        }
        let gap = 4.0 * Double(emuPerPoint)
        let margin = min(max(6.0 * Double(emuPerPoint), Double(12 * emuPerPoint)), Double(min(w, h)) * 0.05)
        var content = ChartTextRect(x: Double(x) + margin, y: Double(y) + margin,
                                    width: Double(w) - 2 * margin, height: Double(h) - 2 * margin)
        var out = ""
        if let title = extChart.title, !title.isEmpty {
            let style = chartTextStyle([], color: "#666666", size: 13 * emuPerPoint)
            if let text = prepareChartText(title, style: style, measure: measure, width: content.width),
               text.block.height < content.height * 0.3 {
                out += chartTextBlock(text, in: ChartTextRect(x: content.x, y: content.y,
                    width: content.width, height: text.block.height), anchor: "middle", role: "title")
                content.y += text.block.height + gap * 2
                content.height -= text.block.height + gap * 2
            }
        }
        let catStyle = chartTextStyle([], color: "#666666", size: 9 * emuPerPoint)
        switch extChart.kind {
        case .waterfall:
            let subtotals = Set(extChart.subtotalIndices)
            var running = 0.0
            var intervals: [(start: Double, end: Double, isSubtotal: Bool, val: Double)] = []
            var lo = 0.0, hi = 0.0
            for (idx, v) in values.enumerated() {
                if subtotals.contains(idx) {
                    let totalVal = v != 0 ? v : running
                    running = totalVal
                    intervals.append((0, totalVal, true, totalVal))
                    lo = min(lo, 0, totalVal); hi = max(hi, 0, totalVal)
                } else {
                    let next = running + v
                    intervals.append((running, next, false, v))
                    lo = min(lo, running, next); hi = max(hi, running, next)
                    running = next
                }
            }
            let range = max(1e-9, hi - lo)
            let plotH = max(Double(emuPerPoint), content.height - Double(18 * emuPerPoint))
            let slot = content.width / Double(count)
            let barW = max(Double(emuPerPoint), slot * 0.68)
            for (idx, item) in intervals.enumerated() {
                let bx = content.x + Double(idx) * slot + (slot - barW) / 2
                let f1 = (item.start - lo) / range, f2 = (item.end - lo) / range
                let yTop = content.y + plotH * (1 - max(f1, f2))
                let yBot = content.y + plotH * (1 - min(f1, f2))
                let fill = item.isSubtotal ? seriesColor(2) : (item.val >= 0 ? seriesColor(0) : seriesColor(1))
                out += box(coord(bx), coord(yTop), coord(barW), max(12700, coord(yBot - yTop)), fill: fill)
                if idx + 1 < intervals.count {
                    let nextBx = content.x + Double(idx + 1) * slot + (slot - barW) / 2
                    let connY = content.y + plotH * (1 - f2)
                    out += "<line x1=\"\(coord(bx + barW))\" y1=\"\(coord(connY))\" x2=\"\(coord(nextBx))\" y2=\"\(coord(connY))\" stroke=\"#A6A6A6\" stroke-width=\"6350\" stroke-dasharray=\"19050 12700\"/>"
                }
                if idx < categories.count, let text = prepareChartText(categories[idx], style: catStyle, measure: measure, width: slot, lines: 1) {
                    let rect = ChartTextRect(x: content.x + Double(idx) * slot, y: content.y + plotH + gap, width: slot, height: text.block.height)
                    out += chartTextBlock(text, in: rect, anchor: "middle", role: "category")
                }
            }
        case .funnel:
            let maxVal = max(1e-9, values.map(abs).max() ?? 1)
            let rowH = content.height / Double(count)
            let barH = max(Double(emuPerPoint), rowH * 0.78)
            for (idx, v) in values.enumerated() {
                let frac = max(0.05, min(1.0, abs(v) / maxVal))
                let barW = content.width * frac
                let bx = content.x + (content.width - barW) / 2
                let by = content.y + Double(idx) * rowH + (rowH - barH) / 2
                out += box(coord(bx), coord(by), coord(barW), coord(barH), fill: seriesColor(idx))
                if idx < categories.count, let text = prepareChartText(categories[idx], style: chartTextStyle([], color: "#FFFFFF", size: 9 * emuPerPoint), measure: measure, width: barW, lines: 1) {
                    let rect = ChartTextRect(x: bx, y: by + (barH - text.block.height) / 2, width: barW, height: text.block.height)
                    out += chartTextBlock(text, in: rect, anchor: "middle", role: "data-label")
                }
            }
        case .treemap:
            let positives = values.enumerated().map { ($0.offset, max(0.001, abs($0.element))) }
            let total = max(1e-9, positives.reduce(0.0) { $0 + $1.1 })
            var remX = content.x, remY = content.y, remW = content.width, remH = content.height
            var remainingTotal = total
            for (i, (idx, v)) in positives.enumerated() {
                let share = v / max(1e-9, remainingTotal)
                let rectX = remX, rectY = remY
                let rectW: Double, rectH: Double
                if i == positives.count - 1 {
                    rectW = remW; rectH = remH
                } else if remW >= remH {
                    rectW = remW * share; rectH = remH
                    remX += rectW; remW -= rectW
                } else {
                    rectW = remW; rectH = remH * share
                    remY += rectH; remH -= rectH
                }
                remainingTotal -= v
                out += box(coord(rectX), coord(rectY), max(12700, coord(rectW)), max(12700, coord(rectH)),
                           fill: seriesColor(idx), stroke: " stroke=\"#FFFFFF\" stroke-width=\"12700\"")
                if idx < categories.count, let text = prepareChartText(categories[idx], style: chartTextStyle([], color: "#FFFFFF", size: 9 * emuPerPoint), measure: measure, width: max(1, rectW - gap * 2), lines: 1) {
                    let rect = ChartTextRect(x: rectX + gap, y: rectY + gap, width: max(1, rectW - gap * 2), height: text.block.height)
                    out += chartTextBlock(text, in: rect, anchor: "start", role: "data-label")
                }
            }
        case .sunburst:
            let radius = max(Double(emuPerPoint), min(content.width, content.height) * 0.45)
            let cx = content.x + content.width / 2, cy = content.y + content.height / 2
            let seriesEntry = ChartData.Series(name: firstSeries.name, values: values.map { Optional($0) })
            let doughnutPlot = XML.Element("c:doughnutChart", children: [
                .element(XML.Element("c:holeSize", attributes: [("val", "45")]))
            ])
            out += pieBody(seriesEntry, kind: "doughnutChart", plot: doughnutPlot, cx: cx, cy: cy, radius: radius,
                           color: { self.seriesColor($0) }, label: { _, _, _ in })
        default:
            let maxVal = max(1e-9, values.map(abs).max() ?? 1)
            let plotH = max(Double(emuPerPoint), content.height - Double(18 * emuPerPoint))
            let slot = content.width / Double(count)
            let barW = max(Double(emuPerPoint), slot * 0.72)
            for (idx, v) in values.enumerated() {
                let frac = max(0, min(1, abs(v) / maxVal))
                let bh = max(12700.0, plotH * frac)
                let bx = content.x + Double(idx) * slot + (slot - barW) / 2
                let by = content.y + plotH - bh
                out += box(coord(bx), coord(by), coord(barW), coord(bh), fill: seriesColor(0),
                           stroke: " stroke=\"#FFFFFF\" stroke-width=\"6350\"")
                if idx < categories.count, let text = prepareChartText(categories[idx], style: catStyle, measure: measure, width: slot, lines: 1) {
                    let rect = ChartTextRect(x: content.x + Double(idx) * slot, y: content.y + plotH + gap, width: slot, height: text.block.height)
                    out += chartTextBlock(text, in: rect, anchor: "middle", role: "category")
                }
            }
        }
        return "<g data-rostrum-chart=\"extended\" data-rostrum-chart-kind=\"\(extChart.kind?.rawValue ?? "unknown")\">\(out)</g>"
    }

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
        let isXY = ["scatterChart", "bubbleChart"].contains(kind)
        // A fuzzed file can declare any number of series/points; bound both
        // rather than loop over whatever it claims.
        let series: [ChartData.Series]
        let styles: [XML.Element]
        let seriesPlots: [XML.Element]
        let xyEntries: [Chart.XYSeries]
        if isXY {
            let xyCandidates = zip(chart.xySeries, chart.seriesElements).filter { !$0.0.points.isEmpty }
            let picked = Array(xyCandidates.prefix(32))
            if xyCandidates.count > 32 {
                diagnostics.record(.chartApproximation, .omission, "Chart preview shows the first 32 nonempty series; additional series are omitted.")
            }
            xyEntries = picked.map { $0.0 }
            styles = picked.map { $0.1 }
            series = xyEntries.map { ChartData.Series(name: $0.name, values: $0.points.map(\.y)) }
            seriesPlots = styles.compactMap { serEl in
                chart.plots.first { $0.children(named: "c:ser").contains { $0 === serEl } }
            }
        } else {
            let candidates = zip(chart.series, chart.seriesElements).filter { !$0.0.values.isEmpty }
            let entries = Array(candidates.prefix(32))
            if candidates.count > 32 {
                diagnostics.record(.chartApproximation, .omission, "Chart preview shows the first 32 nonempty series; additional series are omitted.")
            }
            series = entries.map { $0.0 }
            styles = entries.map { $0.1 }
            seriesPlots = styles.compactMap { serEl in
                chart.plots.first { $0.children(named: "c:ser").contains { $0 === serEl } }
            }
            xyEntries = []
        }
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
            let seriesKind = seriesIndex < seriesPlots.count
                ? (seriesPlots[seriesIndex].name.split(separator: ":").last.map(String.init) ?? kind)
                : kind
            if ["lineChart", "line3DChart", "scatterChart", "radarChart", "stockChart"].contains(seriesKind),
               let fill = colorHex(in: properties?.firstChild(named: "a:ln")?.firstChild(named: "a:solidFill")) { return fill }
            if properties?.firstChild(named: "a:noFill") != nil { return "none" }
            if let fill = colorHex(in: properties?.firstChild(named: "a:solidFill")) { return fill }
            return seriesColor(point != nil && ["pieChart", "pie3DChart", "doughnutChart", "ofPieChart"].contains(kind) ? point! : seriesIndex)
        }
        guard !series.isEmpty else { return nil }
        let categories = chart.categories
        let pointCount = series.map(\.values.count).max() ?? 0
        let catCount = Swift.min(Swift.max(categories.count, pointCount), 512)
        if max(categories.count, pointCount) > 512 {
            diagnostics.record(.chartApproximation, .omission, "Chart preview shows the first 512 categories; additional points are omitted.")
        }
        guard catCount > 0 else { return nil }
        let chartText = chart.root?.firstChild(named: "c:txPr")
        let measure = ChartTextMeasurer(fonts: fonts) { code, impact, message in
            diagnostics.record(code, impact, message)
        }
        let gap = 4.0 * Double(emuPerPoint)
        // Keep an outer text-height inset as well as the measured plot gutters.
        // Native decks can place independent annotations across the frame edge;
        // pulling an endpoint tick up to that edge crowds those annotations.
        let frameStyle = chartTextStyle([chartText], color: "#666666")
        let textHeight = measure.block("", style: frameStyle.measurement, width: Double(w))?.height ?? 0
        let margin = min(max(6.0 * Double(emuPerPoint), textHeight), Double(min(w, h)) * 0.05)
        var content = ChartTextRect(x: Double(x) + margin, y: Double(y) + margin,
                                   width: Double(w) - 2 * margin, height: Double(h) - 2 * margin)
        var out = ""
        if let title = chart.title {
            let node = chartNode?.firstChild(named: "c:title")
            let style = chartTextStyle([chartText, node?.firstChild(named: "c:txPr"),
                node?.firstChild(named: "c:tx")?.firstChild(named: "c:rich")], color: "#666666", size: 13 * emuPerPoint)
            if let text = prepareChartText(title, style: style, measure: measure, width: content.width),
               text.block.height < content.height * 0.3 {
                out += chartTextBlock(text, in: ChartTextRect(x: content.x, y: content.y,
                    width: content.width, height: text.block.height), anchor: "middle", role: "title")
                content.y += text.block.height + gap * 2
                content.height -= text.block.height + gap * 2
            } else { chartOmission("the chart title") }
        }
        let pie = ["pieChart", "pie3DChart", "doughnutChart", "ofPieChart"].contains(kind)
        if let legendNode {
            out += chartLegend(pie ? Array(categories.prefix(catCount)) : series.map(\.name),
                position: legendNode.firstChild(named: "c:legendPos")?[attribute: "val"] ?? "r",
                style: chartTextStyle([chartText, legendNode.firstChild(named: "c:txPr")], color: "#808080"),
                measure: measure, content: &content, color: { pie ? color(0, $0) : color($0, nil) })
        }
        let plot = chart.plots.first
        let specs = chartLabels(plot: plot, series: styles, chartText: chartText, kind: kind, seriesPlots: seriesPlots)
        let labels = prepareChartLabels(specs, series: series, categories: categories, xySeries: xyEntries,
                                        kind: kind, measure: measure, bounds: content)
        if pie {
            out += measuredPie(series[0], kind: kind, plot: plot, bounds: content,
                               labels: labels[0], color: { color(0, $0) })
            return out
        }
        if kind == "radarChart" {
            let plotArea = chartNode?.firstChild(named: "c:plotArea")
            let axis = plotArea?.firstChild(named: "c:valAx")
            let categoryAxis = plotArea?.firstChild(named: "c:catAx") ?? plotArea?.firstChild(named: "c:dateAx")
            let scale = ValueScale(series: series, catCount: catCount, grouping: "standard", axis: axis?.firstChild(named: "c:scaling"))
            let categoryStyle = chartTextStyle([chartText, categoryAxis?.firstChild(named: "c:txPr")], color: "#808080")
            let categoriesVisible = !["1", "true"].contains(categoryAxis?.firstChild(named: "c:delete")?[attribute: "val"] ?? "0")
                && categoryAxis?.firstChild(named: "c:tickLblPos")?[attribute: "val"] != "none"
            var preparedCategories: [(Int, ChartPreparedText)] = []
            if categoriesVisible && !categories.isEmpty {
                for index in 0..<min(catCount, categories.count) where !categories[index].isEmpty {
                    if let text = prepareChartText(categories[index], style: categoryStyle,
                                                   measure: measure, width: content.width * 0.28, lines: 2) {
                        preparedCategories.append((index, text))
                    } else {
                        chartOmission("category labels")
                    }
                }
            }
            let flattened = labels.flatMap { $0.values }
            let outsideLabelW = flattened.map { $0.text.block.width }.max() ?? 0
            let outsideLabelH = flattened.map { $0.text.block.height }.max() ?? 0
            let maxCatW = preparedCategories.map { $0.1.block.width }.max() ?? 0
            let maxCatH = preparedCategories.map { $0.1.block.height }.max() ?? 0
            let catOffsetX = max(gap * 1.5, outsideLabelW / 2 + gap * 1.5)
            let catOffsetY = gap * 1.5
            let padX = max(maxCatW > 0 ? maxCatW + catOffsetX + gap : gap, outsideLabelW > 0 ? outsideLabelW + gap : gap)
            let padY = max(maxCatH > 0 ? maxCatH + catOffsetY + gap : gap, outsideLabelH > 0 ? outsideLabelH + gap : gap)
            var radius = min(content.width / 2 - padX, content.height / 2 - padY)
            if radius < Double(6 * emuPerPoint) && !preparedCategories.isEmpty {
                preparedCategories.removeAll()
                chartOmission("category labels")
                radius = min(content.width / 2 - gap * 2, content.height / 2 - gap * 2)
            }
            guard radius >= Double(emuPerPoint) else {
                chartOmission("the plot because its measured labels leave no plotting area")
                return out
            }
            let cx = content.x + content.width / 2
            let cy = content.y + content.height / 2
            func vertexAngle(_ index: Int) -> Double {
                -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(1, catCount))
            }
            for ring in 1...4 {
                let r = radius * Double(ring) / 4.0
                if catCount >= 3 {
                    let ringPts = (0..<catCount).map { i -> String in
                        let a = vertexAngle(i)
                        return "\(coord(cx + r * cos(a))),\(coord(cy + r * sin(a)))"
                    }.joined(separator: " ")
                    out += "<polygon points=\"\(ringPts)\" fill=\"none\" stroke=\"#D9D9D9\" stroke-width=\"6350\"/>"
                } else {
                    out += "<circle cx=\"\(coord(cx))\" cy=\"\(coord(cy))\" r=\"\(coord(r))\" fill=\"none\" stroke=\"#D9D9D9\" stroke-width=\"6350\"/>"
                }
            }
            for i in 0..<catCount {
                let a = vertexAngle(i)
                out += "<line x1=\"\(coord(cx))\" y1=\"\(coord(cy))\" x2=\"\(coord(cx + radius * cos(a)))\" y2=\"\(coord(cy + radius * sin(a)))\" stroke=\"#D9D9D9\" stroke-width=\"6350\"/>"
            }
            let radarStyle = plot?.firstChild(named: "c:radarStyle")?[attribute: "val"] ?? "standard"
            let isFilled = radarStyle == "filled"
            let defaultMarkers = radarStyle == "marker"
            let fallbackMarker = XML.Element("c:marker", children: [
                .element(XML.Element("c:symbol", attributes: [("val", "circle")]))
            ])
            let placements = ChartLabelPlacement(bounds: content)
            var categorySVG = ""
            for (index, text) in preparedCategories {
                let a = vertexAngle(index)
                let c = cos(a), s = sin(a)
                let ax = cx + (radius + (abs(c) < 0.2 ? catOffsetY : catOffsetX)) * c
                let ay = cy + (radius + catOffsetY) * s
                let w = text.block.width, h = text.block.height
                let desired: ChartTextRect
                let anchor: String
                if abs(c) < 0.2 {
                    anchor = "middle"
                    desired = ChartTextRect(x: ax - w / 2, y: s < 0 ? ay - h : ay, width: w, height: h)
                } else if c > 0 {
                    anchor = "start"
                    desired = ChartTextRect(x: ax, y: ay - h / 2, width: w, height: h)
                } else {
                    anchor = "end"
                    desired = ChartTextRect(x: ax - w, y: ay - h / 2, width: w, height: h)
                }
                guard let rect = placements.place([desired]) else { chartOmission("category labels"); continue }
                categorySVG += chartTextBlock(text, in: rect, anchor: anchor, role: "category")
            }
            var decorations = ""
            for (s, entry) in series.enumerated() {
                var points: [(Double, Double)] = []
                let seriesMarker = styles[s].firstChild(named: "c:marker") ?? (defaultMarkers ? fallbackMarker : nil)
                var pointMarkers: [Int: XML.Element] = [:]
                for point in styles[s].children(named: "c:dPt") {
                    if let index = point.firstChild(named: "c:idx")?.boundedInt("val", in: 0...511),
                       let marker = point.firstChild(named: "c:marker") { pointMarkers[index] = marker }
                }
                for index in 0..<catCount {
                    guard let value = Self.finite(entry, index) else { continue }
                    let frac = max(0, min(1, scale.fraction(value)))
                    let a = vertexAngle(index)
                    let px = cx + radius * frac * cos(a)
                    let py = cy + radius * frac * sin(a)
                    points.append((px, py))
                    decorations += chartMarker(pointMarkers[index], inherited: seriesMarker,
                                               x: px, y: py, defaultColor: color(s, index))
                    decorations += renderPointLabel(labels[s][index], x: px, y: py, placements: placements)
                }
                guard points.count >= 2 else { continue }
                let path = points.map { "\(coord($0.0)),\(coord($0.1))" }.joined(separator: " ")
                let serColor = color(s, nil)
                let properties = styles[s].firstChild(named: "c:spPr")
                let ln = properties?.firstChild(named: "a:ln")
                let stroke = ln?.firstChild(named: "a:noFill") != nil ? "none" : colorHex(in: ln?.firstChild(named: "a:solidFill")) ?? serColor
                let lineWidth = ln?.coordinate("w") ?? 25400
                let dash = dashAttributes(ln, width: lineWidth)
                let fillAttr = isFilled ? " fill=\"\(serColor)\" fill-opacity=\"0.35\"" : " fill=\"none\""
                out += "<polygon points=\"\(path)\"\(fillAttr) stroke=\"\(stroke)\" stroke-width=\"\(lineWidth)\"\(dash) stroke-linejoin=\"round\"/>"
            }
            out += decorations + categorySVG
            return out
        }
        if isXY {
            let plotArea = chartNode?.firstChild(named: "c:plotArea")
            let valAxes = plotArea?.children(named: "c:valAx") ?? []
            let xAxis = valAxes.first { ["b", "t"].contains($0.firstChild(named: "c:axPos")?[attribute: "val"] ?? "") }
                ?? plotArea?.firstChild(named: "c:catAx")
                ?? plotArea?.firstChild(named: "c:dateAx")
                ?? valAxes.first
            let yAxis = valAxes.first { $0 !== xAxis && ["l", "r"].contains($0.firstChild(named: "c:axPos")?[attribute: "val"] ?? "") }
                ?? valAxes.dropFirst().first { $0 !== xAxis }
                ?? valAxes.first
            let xSeries = xyEntries.map { xy in
                ChartData.Series(name: xy.name, values: (0..<min(catCount, xy.points.count)).map { index in
                    if let xVal = xy.points[index].x, xVal.isFinite { return xVal }
                    if index < xy.xLabels.count { return Double(index + 1) }
                    return nil
                })
            }
            let xScale = ValueScale(series: xSeries, catCount: catCount, grouping: "standard", axis: xAxis?.firstChild(named: "c:scaling"))
            let yScale = ValueScale(series: series, catCount: catCount, grouping: "standard", axis: yAxis?.firstChild(named: "c:scaling"))
            out += chartAxisTitle(yAxis, chartText: chartText, measure: measure, content: &content, vertical: true)
            out += chartAxisTitle(xAxis, chartText: chartText, measure: measure, content: &content, vertical: false)
            let yTicks = chartTicks(scale: yScale, axis: yAxis,
                style: chartTextStyle([chartText, yAxis?.firstChild(named: "c:txPr")], color: "#666666"),
                measure: measure, width: content.width * 0.35)
            let xTicks = chartTicks(scale: xScale, axis: xAxis,
                style: chartTextStyle([chartText, xAxis?.firstChild(named: "c:txPr")], color: "#666666"),
                measure: measure, width: content.width * 0.25)
            let yTickWidth = yTicks.compactMap(\.text).map { $0.block.width }.max() ?? 0
            let yTickHeight = yTicks.compactMap(\.text).map { $0.block.height }.max() ?? 0
            let xTickWidth = xTicks.compactMap(\.text).map { $0.block.width }.max() ?? 0
            let xTickHeight = xTicks.compactMap(\.text).map { $0.block.height }.max() ?? 0
            let flattened = labels.flatMap { $0.values }
            let outside = flattened.filter { $0.position != "ctr" }
            let labelWidth = outside.map { $0.text.block.width }.max() ?? 0
            let labelHeight = outside.map { $0.text.block.height }.max() ?? 0
            let outsideX = labelWidth > 0 ? labelWidth + gap : 0
            let outsideY = labelHeight > 0 ? labelHeight + gap * 2 : 0
            let leftTick = max(yTickWidth + (yTickWidth > 0 ? gap : 0), xTickWidth / 2)
            let rightTick = xTickWidth / 2
            let topTick = yTickHeight / 2
            let bottomTick = max(xTickHeight + (xTickHeight > 0 ? gap : 0), yTickHeight / 2)
            let left = leftTick + outsideX
            let right = rightTick + outsideX
            let top = max(topTick, outsideY)
            let bottom = bottomTick + outsideY
            let area = ChartTextRect(x: content.x + left, y: content.y + top,
                width: content.width - left - right, height: content.height - top - bottom)
            guard area.width >= Double(emuPerPoint), area.height >= Double(emuPerPoint) else {
                chartOmission("the plot because its measured labels leave no plotting area")
                return out
            }
            let labelBounds = ChartTextRect(x: area.x - outsideX, y: area.y - outsideY,
                width: area.width + outsideX * 2, height: area.height + outsideY * 2)
            let placements = ChartLabelPlacement(bounds: labelBounds)
            out += measuredAxes(area: area, scale: yScale, axis: yAxis, ticks: yTicks, horizontal: false,
                                labelX: area.x - outsideX - gap, labelY: area.bottom + outsideY + gap, bounds: content)
            out += measuredAxes(area: area, scale: xScale, axis: xAxis, ticks: xTicks, horizontal: true,
                                labelX: area.x - outsideX - gap, labelY: area.bottom + outsideY + gap, bounds: content)
            var body = ""
            var decorations = ""
            if kind == "bubbleChart" {
                let showNeg = ["1", "true"].contains(plot?.firstChild(named: "c:showNegBubbles")?[attribute: "val"] ?? "0")
                let bubbleScale = Double(plot?.firstChild(named: "c:bubbleScale")?.boundedInt("val", in: 0...300) ?? 100) / 100.0
                let sizes = xyEntries.flatMap { $0.points.prefix(catCount) }.compactMap(\.size).filter {
                    $0.isFinite && ($0 > 0 || (showNeg && $0 < 0))
                }.map(abs)
                let maxSize = sizes.max() ?? 1
                let maxRadius = max(Double(3 * emuPerPoint), min(area.width, area.height) * 0.12 * max(0.25, bubbleScale))
                for (s, xy) in xyEntries.enumerated() {
                    for index in 0..<min(catCount, xy.points.count) {
                        guard let xVal = Self.finite(xSeries[s], index),
                              let yVal = Self.finite(series[s], index) else { continue }
                        let rawSize = xy.points[index].size ?? 1
                        guard rawSize.isFinite, rawSize > 0 || (showNeg && rawSize < 0) else { continue }
                        let px = area.x + area.width * xScale.fraction(xVal)
                        let py = area.y + area.height * (1 - yScale.fraction(yVal))
                        let r = max(Double(2 * emuPerPoint), maxRadius * sqrt(abs(rawSize) / max(maxSize, 1e-12)))
                        let ptColor = color(s, index)
                        let stroke = ptColor == "none" ? "none" : ptColor
                        body += "<circle cx=\"\(coord(px))\" cy=\"\(coord(py))\" r=\"\(coord(r))\" fill=\"\(ptColor)\" fill-opacity=\"0.65\" stroke=\"\(stroke)\" stroke-width=\"12700\"/>"
                        if px >= area.x - 0.01 && px <= area.right + 0.01 && py >= area.y - 0.01 && py <= area.bottom + 0.01 {
                            decorations += renderPointLabel(labels[s][index], x: px, y: py, placements: placements)
                        }
                    }
                }
            } else {
                let scatterStyle = plot?.firstChild(named: "c:scatterStyle")?[attribute: "val"] ?? "lineMarker"
                let defaultLine = ["line", "lineMarker", "smooth", "smoothMarker"].contains(scatterStyle)
                let defaultMarkers = ["lineMarker", "smoothMarker", "marker"].contains(scatterStyle)
                let fallbackMarker = XML.Element("c:marker", children: [
                    .element(XML.Element("c:symbol", attributes: [("val", "circle")]))
                ])
                for (s, xy) in xyEntries.enumerated() {
                    var points: [(Double, Double)] = []
                    var overlayPts: [(x: Double, y: Double, val: Double)] = []
                    let seriesMarker = styles[s].firstChild(named: "c:marker") ?? (defaultMarkers ? fallbackMarker : nil)
                    var pointMarkers: [Int: XML.Element] = [:]
                    for point in styles[s].children(named: "c:dPt") {
                        if let index = point.firstChild(named: "c:idx")?.boundedInt("val", in: 0...511),
                           let marker = point.firstChild(named: "c:marker") { pointMarkers[index] = marker }
                    }
                    let seriesCol = color(s, nil)
                    for index in 0..<min(catCount, xy.points.count) {
                        guard let xVal = Self.finite(xSeries[s], index),
                              let yVal = Self.finite(series[s], index) else { continue }
                        let px = area.x + area.width * xScale.fraction(xVal)
                        let py = area.y + area.height * (1 - yScale.fraction(yVal))
                        points.append((px, py))
                        overlayPts.append((px, py, yVal))
                        if px >= area.x - 0.01 && px <= area.right + 0.01 && py >= area.y - 0.01 && py <= area.bottom + 0.01 {
                            decorations += chartMarker(pointMarkers[index], inherited: seriesMarker,
                                x: px, y: py, defaultColor: color(s, index))
                            decorations += renderPointLabel(labels[s][index], x: px, y: py, placements: placements)
                        }
                    }
                    let properties = styles[s].firstChild(named: "c:spPr")
                    let ln = properties?.firstChild(named: "a:ln")
                    let hasExplicitLine = ln?.firstChild(named: "a:solidFill") != nil
                    if points.count > 1, (defaultLine || hasExplicitLine), ln?.firstChild(named: "a:noFill") == nil {
                        let path = points.map { "\(coord($0.0)),\(coord($0.1))" }.joined(separator: " ")
                        let stroke = colorHex(in: ln?.firstChild(named: "a:solidFill")) ?? seriesCol
                        let lineWidth = ln?.coordinate("w") ?? 25400
                        let dash = dashAttributes(ln, width: lineWidth)
                        body += "<polyline points=\"\(path)\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(lineWidth)\"\(dash) stroke-linejoin=\"round\"/>"
                    }
                    body += renderSeriesOverlays(styles[s], points: overlayPts, scale: yScale, area: area, horizontal: false, defaultColor: seriesCol)
                }
            }
            out += "<svg x=\"\(area.x)\" y=\"\(area.y)\" width=\"\(area.width)\" height=\"\(area.height)\" viewBox=\"\(area.x) \(area.y) \(area.width) \(area.height)\" overflow=\"hidden\">\(body)</svg>" + decorations
            return out
        }
        let supportedCartesianKinds: Set<String> = [
            "barChart", "bar3DChart", "lineChart", "line3DChart",
            "areaChart", "area3DChart", "stockChart", "surfaceChart", "surface3DChart"
        ]
        let allPlotKinds = chart.plotTypes
        guard !allPlotKinds.isEmpty, allPlotKinds.allSatisfy({ supportedCartesianKinds.contains($0) }) else { return nil }
        let plotArea = chartNode?.firstChild(named: "c:plotArea")
        let valAxes = plotArea?.children(named: "c:valAx") ?? []
        let axis = valAxes.first
        let secondaryAxis = chart.isCombo ? valAxes.dropFirst().first : nil
        let secondaryAxisID = secondaryAxis?.firstChild(named: "c:axId")?[attribute: "val"]
        let categoryAxis = plotArea?.firstChild(named: "c:catAx") ?? plotArea?.firstChild(named: "c:dateAx")
        let horizontal = !chart.isCombo && ["barChart", "bar3DChart"].contains(kind) && plot?.firstChild(named: "c:barDir")?[attribute: "val"] == "bar"

        struct PlotEntry {
            let element: XML.Element
            let kind: String
            let seriesIndices: [Int]
            let usesSecondaryAxis: Bool
            let rawScale: ValueScale
        }
        let plotEntries: [PlotEntry] = chart.plots.compactMap { plotEl in
            let indices = series.indices.filter { $0 < seriesPlots.count && seriesPlots[$0] === plotEl }
            guard !indices.isEmpty else { return nil }
            let pKind = plotEl.name.split(separator: ":").last.map(String.init) ?? kind
            let axIDs = plotEl.children(named: "c:axId").compactMap { $0[attribute: "val"] }
            let isSec = secondaryAxisID != nil && axIDs.contains(secondaryAxisID!)
            let targetAxis = isSec ? secondaryAxis : axis
            let grp = plotEl.firstChild(named: "c:grouping")?[attribute: "val"] ?? (["barChart", "bar3DChart"].contains(pKind) ? "clustered" : "standard")
            let raw = ValueScale(series: indices.map { series[$0] }, catCount: catCount,
                                 grouping: grp, axis: targetAxis?.firstChild(named: "c:scaling"))
            return PlotEntry(element: plotEl, kind: pKind, seriesIndices: indices, usesSecondaryAxis: isSec, rawScale: raw)
        }
        let primaryEntries = plotEntries.filter { !$0.usesSecondaryAxis }
        let secondaryEntries = plotEntries.filter { $0.usesSecondaryAxis }
        let scale = ValueScale.merged(primaryEntries.map(\.rawScale))
            ?? ValueScale(series: series, catCount: catCount,
                          grouping: plot?.firstChild(named: "c:grouping")?[attribute: "val"] ?? "clustered",
                          axis: axis?.firstChild(named: "c:scaling"))
        let secondaryScale = ValueScale.merged(secondaryEntries.map(\.rawScale))

        out += chartAxisTitle(horizontal ? categoryAxis : axis, chartText: chartText,
                              measure: measure, content: &content, vertical: true)
        if let secondaryAxis, secondaryScale != nil {
            out += chartAxisTitle(secondaryAxis, chartText: chartText,
                                  measure: measure, content: &content, vertical: true, rightSide: true)
        }
        out += chartAxisTitle(horizontal ? axis : categoryAxis, chartText: chartText,
                              measure: measure, content: &content, vertical: false)
        let ticks = chartTicks(scale: scale, axis: axis,
            style: chartTextStyle([chartText, axis?.firstChild(named: "c:txPr")], color: "#666666"),
            measure: measure, width: content.width * 0.35)
        let secondaryTicks: [ChartTick] = if let secondaryAxis, let secondaryScale {
            chartTicks(scale: secondaryScale, axis: secondaryAxis,
                style: chartTextStyle([chartText, secondaryAxis.firstChild(named: "c:txPr")], color: "#666666"),
                measure: measure, width: content.width * 0.35)
        } else { [] }
        let tickWidth = ticks.compactMap(\.text).map { $0.block.width }.max() ?? 0
        let tickHeight = ticks.compactMap(\.text).map { $0.block.height }.max() ?? 0
        let secTickWidth = secondaryTicks.compactMap(\.text).map { $0.block.width }.max() ?? 0
        let secTickHeight = secondaryTicks.compactMap(\.text).map { $0.block.height }.max() ?? 0
        let categoryStyle = chartTextStyle([chartText, categoryAxis?.firstChild(named: "c:txPr")], color: "#808080")
        let categoriesVisible = !["1", "true"].contains(categoryAxis?.firstChild(named: "c:delete")?[attribute: "val"] ?? "0")
            && categoryAxis?.firstChild(named: "c:tickLblPos")?[attribute: "val"] != "none"
        let flattened = labels.flatMap { $0.values }
        let outside = flattened.filter { !["ctr", "inEnd", "inBase"].contains($0.position) }
        let labelWidth = outside.map { $0.text.block.width }.max() ?? 0
        let labelHeight = outside.map { $0.text.block.height }.max() ?? 0
        let hasPositive = series.contains { $0.values.prefix(catCount).contains { ($0 ?? 0) >= 0 } }
        let hasNegative = series.contains { $0.values.prefix(catCount).contains { ($0 ?? 0) < 0 } }
        let hasLinePlot = allPlotKinds.contains { ["lineChart", "line3DChart", "stockChart"].contains($0) }
        let outsideX = horizontal && labelWidth > 0 ? labelWidth + gap : hasLinePlot && labelWidth > 0 ? labelWidth + gap : 0
        let outsideTop = !horizontal && labelHeight > 0 && hasPositive ? labelHeight + gap * 2 : 0
        let outsideBottom = !horizontal && labelHeight > 0 && (hasNegative || hasLinePlot) ? labelHeight + gap * 2 : 0
        let leftOutside = horizontal ? (hasNegative ? outsideX : 0) : outsideX
        let rightOutside = horizontal ? (hasPositive ? outsideX : 0) : outsideX
        let leftTick = horizontal ? tickWidth / 2 : tickWidth + (tickWidth > 0 ? gap : 0)
        let rightTick = horizontal ? tickWidth / 2 : secTickWidth + (secTickWidth > 0 ? gap : 0)
        let topTick = horizontal ? 0 : max(tickHeight / 2, secTickHeight / 2)
        let bottomTick = horizontal ? tickHeight + (tickHeight > 0 ? gap : 0) : max(tickHeight / 2, secTickHeight / 2)
        var categoryTexts: [(Int, ChartPreparedText)] = []
        var categoryWidth = 0.0, categoryHeight = 0.0
        // Each trial reuses measured strings; only the available label slot changes.
        // Dense axes sample labels in source order instead of overlapping them.
        if categoriesVisible && !categories.isEmpty {
            let authoredStride = max(1, categoryAxis?.firstChild(named: "c:tickLblSkip")?.boundedInt("val", in: 1...512) ?? 1)
            var stride = authoredStride
            while stride <= 512 {
                let labelLimit = horizontal ? content.width * 0.30
                    : max(0, content.width - leftTick - rightTick - leftOutside - rightOutside) / Double(catCount) * Double(stride) - gap
                var trial: [(Int, ChartPreparedText)] = []
                var fits = true
                for index in Swift.stride(from: 0, to: min(catCount, categories.count), by: stride) {
                    guard let text = prepareChartText(categories[index], style: categoryStyle,
                        measure: measure, width: labelLimit, lines: 3) else { fits = false; continue }
                    if horizontal && text.block.height + gap > max(0, content.height - bottomTick) / Double(catCount) * Double(stride) { fits = false }
                    trial.append((index, text))
                }
                categoryTexts = trial
                if fits || stride >= catCount { break }
                stride = min(512, max(stride + 1, stride * 2))
            }
            let requestedCount = (min(catCount, categories.count) + authoredStride - 1) / authoredStride
            if categoryTexts.count < requestedCount { chartOmission("category labels") }
            categoryWidth = horizontal ? (categoryTexts.map { $0.1.block.width }.max() ?? 0) + gap : 0
            categoryHeight = horizontal ? 0 : (categoryTexts.map { $0.1.block.height }.max() ?? 0) + gap
        }
        let left = max(leftTick, categoryWidth) + leftOutside
        let right = rightTick + rightOutside
        let top = max(topTick, outsideTop)
        let bottom = max(bottomTick, categoryHeight) + outsideBottom
        var area = ChartTextRect(x: content.x + left, y: content.y + top,
            width: content.width - left - right, height: content.height - top - bottom)
        // An authored inner plot rectangle is exact; the measured one is a guess.
        if let authored = Self.manualPlotArea(plotArea, frame: ChartTextRect(x: Double(x), y: Double(y), width: Double(w), height: Double(h))) {
            area = authored
        }
        guard area.width >= Double(emuPerPoint), area.height >= Double(emuPerPoint) else {
            chartOmission("the plot because its measured labels leave no plotting area")
            return out
        }
        let labelBounds = ChartTextRect(x: area.x - leftOutside, y: area.y - outsideTop,
            width: area.width + leftOutside + rightOutside, height: area.height + outsideTop + outsideBottom)
        let placements = ChartLabelPlacement(bounds: labelBounds)
        out += measuredAxes(area: area, scale: scale, axis: axis, ticks: ticks, horizontal: horizontal,
                            labelX: area.x - leftOutside - gap, labelY: area.bottom + outsideBottom + gap, bounds: content)
        if let secondaryAxis, let secondaryScale {
            out += measuredAxes(area: area, scale: secondaryScale, axis: secondaryAxis, ticks: secondaryTicks,
                                horizontal: false, labelX: area.right + rightOutside + gap,
                                labelY: area.bottom + outsideBottom + gap, bounds: content, rightSide: true)
        }
        for entry in plotEntries {
            let axisScale = entry.usesSecondaryAxis ? (secondaryScale ?? scale) : scale
            let plotScale = entry.rawScale.withDomain(of: axisScale)
            let groupSeries = entry.seriesIndices.map { series[$0] }
            let groupStyles = entry.seriesIndices.map { styles[$0] }
            if ["barChart", "bar3DChart"].contains(entry.kind) {
                var seriesPts: [[(x: Double, y: Double, val: Double)]] = Array(repeating: [], count: groupSeries.count)
                out += barBody(groupSeries, catCount: catCount, scale: plotScale, horizontal: horizontal,
                    gapWidth: entry.element.firstChild(named: "c:gapWidth")?.boundedInt("val", in: 0...500) ?? 150,
                    overlap: entry.element.firstChild(named: "c:overlap")?.boundedInt("val", in: -100...100),
                    plotX: area.x, plotY: area.y, plotW: area.width, plotH: area.height,
                    color: { localS, pt in color(entry.seriesIndices[localS], pt) },
                    label: { localS, index, rect in
                        let globalS = entry.seriesIndices[localS]
                        let val = Self.finite(series[globalS], index) ?? 0
                        let px = horizontal ? (val >= 0 ? rect.x + rect.width : rect.x) : rect.x + rect.width / 2
                        let py = horizontal ? rect.y + rect.height / 2 : (val >= 0 ? rect.y : rect.y + rect.height)
                        seriesPts[localS].append((px, py, val))
                        return renderBarLabel(labels[globalS][index], value: val,
                            rect: rect, horizontal: horizontal, placements: placements)
                    })
                for (localS, serEl) in groupStyles.enumerated() {
                    out += renderSeriesOverlays(serEl, points: seriesPts[localS], scale: plotScale, area: area,
                                                horizontal: horizontal, defaultColor: color(entry.seriesIndices[localS], nil))
                }
            } else {
                var decorations = ""
                var seriesPts: [[(x: Double, y: Double, val: Double)]] = Array(repeating: [], count: groupSeries.count)
                var body = lineBody(groupSeries, catCount: catCount, scale: plotScale,
                    filled: ["areaChart", "area3DChart", "surfaceChart", "surface3DChart"].contains(entry.kind),
                    plotX: area.x, plotY: area.y, plotW: area.width, plotH: area.height,
                    styles: groupStyles, color: { localS in color(entry.seriesIndices[localS], nil) },
                    decoration: { localS, index, px, py, marker in
                        let globalS = entry.seriesIndices[localS]
                        if let val = Self.finite(series[globalS], index) {
                            seriesPts[localS].append((px, py, val))
                        }
                        guard py >= area.y - 0.01 && py <= area.bottom + 0.01 else { return }
                        decorations += marker
                        decorations += renderPointLabel(labels[globalS][index], x: px, y: py, placements: placements)
                    })
                for (localS, serEl) in groupStyles.enumerated() {
                    body += renderSeriesOverlays(serEl, points: seriesPts[localS], scale: plotScale, area: area,
                                                 horizontal: false, defaultColor: color(entry.seriesIndices[localS], nil))
                }
                out += "<svg x=\"\(area.x)\" y=\"\(area.y)\" width=\"\(area.width)\" height=\"\(area.height)\" viewBox=\"\(area.x) \(area.y) \(area.width) \(area.height)\" overflow=\"hidden\">\(body)</svg>" + decorations
            }
        }
        let categoryPlacements = ChartLabelPlacement(bounds: content)
        for (index, text) in categoryTexts {
            let center = horizontal ? area.y + area.height / Double(catCount) * (Double(catCount - index) - 0.5)
                : area.x + area.width / Double(catCount) * (Double(index) + 0.5)
            let desired = horizontal
                ? ChartTextRect(x: area.x - leftOutside - gap - text.block.width, y: center - text.block.height / 2,
                                width: text.block.width, height: text.block.height)
                : ChartTextRect(x: center - text.block.width / 2, y: area.bottom + outsideBottom + gap,
                                width: text.block.width, height: text.block.height)
            guard let rect = categoryPlacements.place([desired]) else { chartOmission("category labels"); continue }
            out += chartTextBlock(text, in: rect, anchor: horizontal ? "end" : "middle", role: "category")
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

        init(minimum: Double, range: Double, stacked: Bool, percent: Bool) {
            self.minimum = minimum
            self.range = range
            self.stacked = stacked
            self.percent = percent
        }

        init(series: [ChartData.Series], catCount: Int, grouping: String, axis: XML.Element? = nil) {
            percent = grouping == "percentStacked"
            stacked = percent || grouping == "stacked"
            var high = 0.0, low = 0.0
            if percent {
                high = 1
                if series.contains(where: { $0.values.prefix(catCount).contains { ($0 ?? 0) < 0 } }) { low = -1 }
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

        static func merged(_ scales: [ValueScale]) -> ValueScale? {
            guard let first = scales.first else { return nil }
            if scales.count == 1 { return first }
            let low = scales.map(\.minimum).min() ?? first.minimum
            let high = scales.map { $0.minimum + $0.range }.max() ?? (first.minimum + first.range)
            let range = high - low
            guard low.isFinite, high.isFinite, range.isFinite, range > 0 else { return first }
            return ValueScale(minimum: low, range: range, stacked: first.stacked, percent: first.percent)
        }

        func withDomain(of domain: ValueScale) -> ValueScale {
            ValueScale(minimum: domain.minimum, range: domain.range, stacked: stacked, percent: percent)
        }

        /// Where `value` sits in the plot, 0 at the bottom edge and 1 at the top.
        func fraction(_ value: Double) -> Double {
            guard value.isFinite else { return 0 }
            return (value - minimum) / range
        }
        var zeroFraction: Double { fraction(Swift.max(Swift.min(0, minimum + range), minimum)) }
    }

    private func measuredAxes(area: ChartTextRect, scale: ValueScale, axis: XML.Element?, ticks: [ChartTick],
                              horizontal: Bool, labelX: Double, labelY: Double, bounds: ChartTextRect,
                              rightSide: Bool = false) -> String {
        guard !["1", "true"].contains(axis?.firstChild(named: "c:delete")?[attribute: "val"] ?? "0") else { return "" }
        let zero = horizontal ? area.x + area.width * scale.zeroFraction : area.y + area.height * (1 - scale.zeroFraction)
        var out = horizontal
            ? "<line x1=\"\(coord(zero))\" y1=\"\(coord(area.y))\" x2=\"\(coord(zero))\" y2=\"\(coord(area.bottom))\" stroke=\"#BFBFBF\" stroke-width=\"6350\"/>"
            : "<line x1=\"\(coord(area.x))\" y1=\"\(coord(zero))\" x2=\"\(coord(area.right))\" y2=\"\(coord(zero))\" stroke=\"#BFBFBF\" stroke-width=\"6350\"/>"
        let grid = axis?.firstChild(named: "c:majorGridlines")
        let gridLine = grid?.firstChild(named: "c:spPr")?.firstChild(named: "a:ln")
        let color = gridLine?.firstChild(named: "a:noFill") != nil ? "none" : colorHex(in: gridLine?.firstChild(named: "a:solidFill")) ?? "#D9D9D9"
        let width = max(0, gridLine?.coordinate("w") ?? 6350)
        let stroke = " stroke=\"\(color)\" stroke-width=\"\(width)\"" + dashAttributes(gridLine, width: width)
        let placements = ChartLabelPlacement(bounds: bounds)
        for tick in ticks {
            let fraction = scale.fraction(tick.value)
            let position = horizontal ? area.x + fraction * area.width : area.y + (1 - fraction) * area.height
            if grid != nil {
                out += horizontal
                    ? "<line x1=\"\(coord(position))\" y1=\"\(coord(area.y))\" x2=\"\(coord(position))\" y2=\"\(coord(area.bottom))\"\(stroke)/>"
                    : "<line x1=\"\(coord(area.x))\" y1=\"\(coord(position))\" x2=\"\(coord(area.right))\" y2=\"\(coord(position))\"\(stroke)/>"
            }
            if let text = tick.text {
                let xPos = horizontal ? position - text.block.width / 2 : rightSide ? labelX : labelX - text.block.width
                let desired = ChartTextRect(x: xPos,
                    y: horizontal ? labelY : position - text.block.height / 2, width: text.block.width, height: text.block.height)
                if let rect = placements.place([desired]) {
                    out += chartTextBlock(text, in: rect, anchor: horizontal ? "middle" : rightSide ? "start" : "end", role: "value-axis")
                } else { chartOmission("value-axis labels") }
            }
        }
        return out
    }

    /// `c:plotArea/c:layout/c:manualLayout` when it pins the inner plot
    /// rectangle (the axes box) by its edges, as fractions of the chart space.
    /// Other forms — outer targets, which include tick labels, and offsets
    /// from an automatic position — still use the measured layout.
    private static func manualPlotArea(_ plotArea: XML.Element?, frame: ChartTextRect) -> ChartTextRect? {
        guard let manual = plotArea?.firstChild(named: "c:layout")?.firstChild(named: "c:manualLayout") else { return nil }
        func value(_ name: String) -> String? { manual.firstChild(named: name)?[attribute: "val"] }
        guard value("c:layoutTarget") == "inner", value("c:xMode") == "edge", value("c:yMode") == "edge",
              let left = value("c:x").flatMap(Double.init), let top = value("c:y").flatMap(Double.init),
              let width = value("c:w").flatMap(Double.init), let height = value("c:h").flatMap(Double.init),
              (0...1).contains(left), (0...1).contains(top), width > 0, height > 0 else { return nil }
        // In edge mode the size values are the far edges rather than extents.
        let right = value("c:wMode") == "edge" ? width : left + width
        let bottom = value("c:hMode") == "edge" ? height : top + height
        guard right > left, bottom > top, right <= 1.0001, bottom <= 1.0001 else { return nil }
        return ChartTextRect(x: frame.x + frame.width * left, y: frame.y + frame.height * top,
                             width: frame.width * (min(1, right) - left), height: frame.height * (min(1, bottom) - top))
    }

    /// Bars in one category slot, sized as DrawingML charts define them:
    /// `gapWidth` is the space between category clusters as a percentage of
    /// one bar's width, and `overlap` is how far each series slides over the
    /// previous one (100 for stacked groupings, where bars share one column).
    private func barBody(_ series: [ChartData.Series], catCount: Int, scale: ValueScale,
                         horizontal: Bool, gapWidth: Int = 150, overlap: Int? = nil,
                         plotX: Double, plotY: Double,
                         plotW: Double, plotH: Double, color: (Int, Int?) -> String,
                         label: (Int, Int, ChartBarRect) -> String) -> String {
        let along = horizontal ? plotH : plotW
        let slot = along / Double(catCount)
        let seriesStep = scale.stacked ? 0 : 1 - Double(overlap ?? 0) / 100
        let barsAcross = 1 + Double(Swift.max(0, series.count - 1)) * seriesStep
        let barWidth = Swift.max(1, slot / (barsAcross + Double(gapWidth) / 100))
        let inset = (slot - barWidth * barsAcross) / 2
        let zero = scale.zeroFraction
        var out = ""
        var labels = ""
        var positiveTops = [Double](repeating: 0, count: catCount)
        var negativeTops = [Double](repeating: 0, count: catCount)

        for index in 0..<catCount {
            let bandStart = (horizontal ? plotY : plotX) + Double(horizontal ? catCount - index - 1 : index) * slot + inset
            // Normalize once per category; a finite input near Double.max must
            // not overflow the percent denominator or erase every segment.
            let largest = scale.percent ? (series.compactMap { Self.finite($0, index).map(abs) }.max() ?? 0) : 0
            let total = largest > 0 ? series.reduce(0.0) { $0 + abs(Self.finite($1, index) ?? 0) / largest } : 0
            for (s, entry) in series.enumerated() {
                guard var value = Self.finite(entry, index) else { continue }
                if scale.percent {
                    value = total > 0 ? (value / largest) / total : 0
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
                let offset = Double(s) * barWidth * seriesStep
                let fill = color(s, index)
                if horizontal {
                    out += box(coord(plotX + plotW * lo), coord(bandStart + offset),
                               coord(plotW * (hi - lo)), coord(barWidth), fill: fill)
                    labels += label(s, index, ChartBarRect(x: plotX + plotW * lo, y: bandStart + offset,
                        width: plotW * (hi - lo), height: barWidth))
                } else {
                    out += box(coord(bandStart + offset), coord(plotY + plotH * (1 - hi)),
                               coord(barWidth), coord(plotH * (hi - lo)), fill: fill)
                    labels += label(s, index, ChartBarRect(x: bandStart + offset, y: plotY + plotH * (1 - hi),
                        width: barWidth, height: plotH * (hi - lo)))
                }
            }
        }
        return out + labels
    }

    private func lineBody(_ series: [ChartData.Series], catCount: Int, scale: ValueScale,
                          filled: Bool, plotX: Double, plotY: Double,
                          plotW: Double, plotH: Double, styles: [XML.Element], color: (Int) -> String,
                          decoration: (Int, Int, Double, Double, String) -> Void) -> String {
        // Points sit at category centers, matching where bars are drawn.
        let step = plotW / Double(catCount)
        var out = ""
        for (s, entry) in series.enumerated() {
            var points: [(Double, Double)] = []
            let seriesMarker = styles[s].firstChild(named: "c:marker")
            var pointMarkers: [Int: XML.Element] = [:]
            for point in styles[s].children(named: "c:dPt") {
                if let index = point.firstChild(named: "c:idx")?.boundedInt("val", in: 0...511),
                   let marker = point.firstChild(named: "c:marker") { pointMarkers[index] = marker }
            }
            for index in 0..<catCount {
                guard let value = Self.finite(entry, index) else { continue }
                let point = (plotX + step * (Double(index) + 0.5),
                             plotY + plotH * (1 - scale.fraction(value)))
                points.append(point)
                decoration(s, index, point.0, point.1,
                    chartMarker(pointMarkers[index], inherited: seriesMarker, x: point.0, y: point.1, defaultColor: color(s)))
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

    private func pieBody(_ entry: ChartData.Series, kind: String, plot: XML.Element?,
                         cx: Double, cy: Double, radius: Double, color: (Int) -> String,
                         label: (Int, Double, Double) -> Void) -> String {
        guard radius > 0 else { return "" }
        let values = entry.values.prefix(512).enumerated().compactMap { index, value -> (Int, Double)? in
            guard let value, value.isFinite, value > 0 else { return nil }; return (index, value)
        }
        let largest = values.map(\.1).max() ?? 1
        let total = values.reduce(0) { $0 + $1.1 / largest }
        guard total.isFinite, total > 0 else { return "" }
        let doughnut = kind == "doughnutChart"
        // Doughnuts are stroked arcs rather than a pie with a punched hole, so
        // they don't need to know the slide background color.
        let hole = Double(plot?.firstChild(named: "c:holeSize")?.boundedInt("val", in: 10...90) ?? 58) / 100
        let ringWidth = radius * (1 - hole)
        let ringRadius = radius - ringWidth / 2
        var out = ""
        var angle = -Double.pi / 2 + Double(plot?.firstChild(named: "c:firstSliceAng")?.boundedInt("val", in: 0...360) ?? 0) * Double.pi / 180
        for (index, value) in values {
            let sweep = (value / largest) / total * 2 * Double.pi
            label(index, angle + sweep / 2, radius)
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
        var decodedBorders = TableBorderPaintCache<BorderPaint>()
        func decodeBorderPaint(_ line: XML.Element) -> BorderPaint? {
            guard line.firstChild(named: "a:noFill") == nil,
                  let color = colorHex(in: line.firstChild(named: "a:solidFill")) else { return nil }
            let width = max(0, line.coordinate("w") ?? 12700)
            guard width > 0 else { return nil }
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
        func borderPaint(_ line: XML.Element?) -> BorderPaint? {
            let paint = decodedBorders.value(for: line, canReuse: styles.ownsSharedBorder, decode: decodeBorderPaint)
            if let paint { maximumBorderWidth = max(maximumBorderWidth, paint.width) }
            return paint
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
                            insets: insets, verticalAnchor: anchor, context: .tableCell) + "</g>"
                    } else {
                        textContent += renderText(body, box: frame, inheriting: effective.text,
                            insets: insets, verticalAnchor: anchor, context: .tableCell)
                    }
                }
            }
        }
        let segments = borders.resolved()
        // The pinned Office v3 vector reference establishes this geometry and
        // paint order for uniform-width, opaque solid grids. Keep the previous
        // path for dashes, alpha and diagonals. The bounded mixed-width
        // path below has a separate native reference.
        let uniformWidth = segments.first?.paint.width
        let joinedGrid = topology != nil && widths.allSatisfy { $0 > 0 } && heights.allSatisfy { $0 > 0 }
            && diagonals.isEmpty && !segments.isEmpty && segments.allSatisfy {
            $0.paint.width == uniformWidth && $0.paint.simpleSolid && $0.paint.color.hasPrefix("#")
        }
        // Native mixed-width profiles share the same signed donor extensions.
        // Keep uniform geometry and uncaptured combinations on their old paths.
        func admittedMixedProfile() -> Bool {
            guard let topology else { return false }
            let oneColor = segments.allSatisfy { $0.paint.color == segments.first?.paint.color }
            if !topology.regions.isEmpty {
                // Captured LTR merges share one orientation and one stroke color.
                return !rtl && oneColor
                    && (topology.regions.allSatisfy { $0.rowSpan == 1 }
                        || topology.regions.allSatisfy { $0.columnSpan == 1 })
            }
            if oneColor { return true } // Both LTR and RTL are captured.
            guard !rtl else { return false }
            // The native transition corpus covers both axes, multiple
            // junctions and noFill donors in unmerged opaque LTR grids.
            // Existing outer guards bound paint and segment dimensions;
            // donor ownership and the four paint groups remain unchanged.
            return true
        }
        let mixedJoinedGrid = !joinedGrid
            // A segment cannot contract past its opposite endpoint: each
            // physical cell dimension exceeds the largest admitted stroke.
            && widths.allSatisfy { $0 > maximumBorderWidth }
            && heights.allSatisfy { $0 > maximumBorderWidth }
            && grid.cells.allSatisfy { $0.count == widths.count }
            && diagonals.isEmpty && !segments.isEmpty && segments.allSatisfy {
                $0.paint.simpleSolid && $0.paint.color.hasPrefix("#")
            }
            && admittedMixedProfile()
        let orderedGrid = joinedGrid || mixedJoinedGrid
        func paintGroup(_ segment: TableBorderSegments<BorderPaint>.Segment) -> Int {
            let edge = segment.edge
            let outer = edge.boundary == 0 || edge.boundary == (edge.axis == .vertical ? widths.count : heights.count)
            return (outer ? 2 : 0) + (edge.axis == .vertical ? 0 : 1)
        }
        // Linear passes avoid sorting the potentially large grid. Interior
        // verticals precede horizontals, then the outer vertical/horizontal rim.
        for group in 0..<(orderedGrid ? 4 : 1) {
          for segment in segments where !orderedGrid || paintGroup(segment) == group {
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
            if mixedJoinedGrid {
                let extensions = borders.mixedWidthExtensions(segment, width: { $0.width })
                startExtension = edge.axis == .horizontal && rtl ? extensions.upper : extensions.lower
                endExtension = edge.axis == .horizontal && rtl ? extensions.lower : extensions.upper
            }
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
            defs += "<radialGradient id=\"\(id)\"\(SVGPaint.radialGradientAttributes(gradient))>\(stops)</radialGradient>"
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

    private func effectiveFill(_ properties: XML.Element, reference: XML.Element?, ownedBy owner: Part, groupFill: (properties: XML.Element, owner: Part)? = nil)
        -> (properties: XML.Element, owner: Part) {
        if properties.firstChild(named: "a:grpFill") != nil, let groupFill {
            return groupFill
        }
        let fills = ["a:solidFill", "a:gradFill", "a:blipFill", "a:pattFill", "a:grpFill", "a:noFill"]
        guard !properties.childElements.contains(where: { fills.contains($0.name) }),
              let fill = styleEntry(reference, list: "a:fillStyleLst", backgroundList: "a:bgFillStyleLst") else { return (properties, owner) }
        return (XML.Element("p:spPr", children: [.element(fill)]), theme.part)
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

    private func paint(for pr: XML.Element, box f: (Int, Int, Int, Int), defs: inout SVGDefinitions, ownedBy owner: Part? = nil, shapeRotation: Double = 0) -> String? {
        if let solid = pr.firstChild(named: "a:solidFill") { return colorHex(in: solid) }
        if let grad = pr.firstChild(named: "a:gradFill") { return gradientRef(grad, box: f, defs: &defs) }
        if let blip = pr.firstChild(named: "a:blipFill") { return imagePattern(blip, ownedBy: owner ?? slidePart, box: f, defs: &defs, shapeRotation: shapeRotation) }
        if let patt = pr.firstChild(named: "a:pattFill") {
            let id = defs.nextID("pat")
            if let svg = SVGPaint.patternSVG(id: id, element: patt, theme: theme) {
                defs += svg
                return "url(#\(id))"
            }
            return nil
        }
        if pr.firstChild(named: "a:noFill") != nil { return nil }
        return nil
    }

    private func gradientRef(_ grad: XML.Element, box f: (Int, Int, Int, Int), defs: inout SVGDefinitions) -> String {
        let id = defs.nextID("g")
        let isRadial = grad.firstChild(named: "a:path") != nil
        let stopSVG = GradientStops.svg(grad, theme: theme)
        if isRadial {
            defs += "<radialGradient id=\"\(id)\"\(SVGPaint.radialGradientAttributes(grad))>\(stopSVG)</radialGradient>"
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

    static let supportedArrowheadTypes: Set<String> = ["triangle", "stealth", "arrow", "diamond", "oval"]
    static let presetDashMultipliers: [String: [Int]] = [
        "dot": [1, 3],
        "sysDot": [1, 1],
        "dash": [4, 3],
        "sysDash": [3, 1],
        "lgDash": [8, 3],
        "dashDot": [4, 3, 1, 3],
        "lgDashDot": [8, 3, 1, 3],
        "lgDashDotDot": [8, 3, 1, 3, 1, 3],
        "sysDashDot": [3, 1, 1, 1],
        "sysDashDotDot": [3, 1, 1, 1, 1, 1],
    ]

    static func isSupportedPresetDash(_ name: String?) -> Bool {
        guard let name else { return true }
        return name == "solid" || presetDashMultipliers[name] != nil
    }

    static func customDashValues(_ custDash: XML.Element, width: Int) -> [Double]? {
        let stops = custDash.children(named: "a:ds")
        guard !stops.isEmpty, stops.count <= 64,
              custDash.childElements.allSatisfy({ $0.name == "a:ds" || $0.name == "a:extLst" }) else { return nil }
        let unit = Double(max(1, width))
        var values: [Double] = []
        values.reserveCapacity(stops.count * 2)
        for stop in stops {
            guard let d = DrawingColor.percentage(stop[attribute: "d"]),
                  let sp = DrawingColor.percentage(stop[attribute: "sp"]),
                  d >= 0, sp >= 0, d > 0 || sp > 0 else { return nil }
            let dashLen = d * unit, spaceLen = sp * unit
            guard dashLen.isFinite, spaceLen.isFinite, dashLen <= 1e12, spaceLen <= 1e12 else { return nil }
            values.append(dashLen)
            values.append(spaceLen)
        }
        return values
    }

    private func strokeAttrs(_ spPr: XML.Element) -> String {
        guard let ln = spPr.firstChild(named: "a:ln"), ln.firstChild(named: "a:noFill") == nil,
              let color = colorHex(in: ln.firstChild(named: "a:solidFill")) else { return "" }
        let width = ln.coordinate("w") ?? 12700
        return " stroke=\"\(color)\" stroke-width=\"\(max(0, width))\"" + dashAttributes(ln, width: width)
    }

    private func dashAttributes(_ line: XML.Element?, width: Int, problems: inout SlideRenderProblems?) -> String {
        if let custDash = line?.firstChild(named: "a:custDash") {
            if let values = Self.customDashValues(custDash, width: width) {
                return " stroke-dasharray=\"" + values.map { SVGNumber.decimal($0) }.joined(separator: " ") + "\""
            }
            problems?.record("Preview approximates an unsupported custom dash pattern.")
            return ""
        }
        guard let name = line?.firstChild(named: "a:prstDash")?[attribute: "val"], name != "solid" else { return "" }
        if let pattern = Self.presetDashMultipliers[name] {
            return " stroke-dasharray=\"" + pattern.map { String($0 * max(1, width)) }.joined(separator: " ") + "\""
        }
        problems?.record("Preview approximates an unsupported connector dash pattern.")
        return " stroke-dasharray=\"\(max(1, width) * 4) \(max(1, width) * 3)\""
    }

    private func dashAttributes(_ line: XML.Element?, width: Int) -> String {
        var ignored: SlideRenderProblems? = nil
        return dashAttributes(line, width: width, problems: &ignored)
    }

    private func lineEndMarkers(_ line: XML.Element?, color: String, defs: inout SVGDefinitions,
                                problems: inout SlideRenderProblems) -> String {
        var attrs = ""
        for (element, attribute, start) in [("a:headEnd", "marker-start", true), ("a:tailEnd", "marker-end", false)] {
            guard let end = line?.firstChild(named: element), let type = end[attribute: "type"], type != "none" else { continue }
            guard Self.supportedArrowheadTypes.contains(type) else {
                problems.record("Preview omitted an unsupported line arrowhead."); continue
            }
            let id = defs.nextID("arrow")
            func size(_ value: String?) -> Int { value == "lg" ? 5 : value == "sm" ? 2 : 3 }
            let markerWidth = size(end[attribute: "len"]), markerHeight = size(end[attribute: "w"])
            let shape: String
            switch type {
            case "oval": shape = "<ellipse cx=\"5\" cy=\"5\" rx=\"5\" ry=\"5\" fill=\"\(color)\"/>"
            case "diamond": shape = "<path d=\"M0 5 L5 0 L10 5 L5 10 Z\" fill=\"\(color)\"/>"
            case "arrow": shape = "<path d=\"M0 0 L10 5 L0 10\" fill=\"none\" stroke=\"\(color)\" stroke-width=\"2\"/>"
            case "stealth": shape = "<path d=\"M0 0 L10 5 L0 10 L3 5 Z\" fill=\"\(color)\"/>"
            default: shape = "<path d=\"M0 0 L10 5 L0 10 Z\" fill=\"\(color)\"/>"
            }
            // Explicitly reverse the start marker rather than relying on SVG 2
            // auto-start-reverse, which older viewers may not implement.
            let marker = start ? "<g transform=\"rotate(180 5 5)\">\(shape)</g>" : shape
            defs += "<marker id=\"\(id)\" viewBox=\"0 0 10 10\" refX=\"\(start ? 0 : 10)\" refY=\"5\" markerWidth=\"\(markerWidth)\" markerHeight=\"\(markerHeight)\" orient=\"auto\" overflow=\"visible\">\(marker)</marker>"
            attrs += " \(attribute)=\"url(#\(id))\""
        }
        return attrs
    }

    private func doubleShapeSVG(preset: String, frame f: (Int, Int, Int, Int), fill: String?, lineProperties: XML.Element) -> String? {
        guard let ln = lineProperties.firstChild(named: "a:ln"),
              TableDoubleBorder.supports(ln),
              let color = colorHex(in: ln.firstChild(named: "a:solidFill")) else { return nil }
        let width = ln.coordinate("w") ?? 12700
        guard width > 0 else { return nil }
        switch preset {
        case "line", "straightConnector1":
            return TableDoubleBorder.svg(color: color, width: width,
                endpoints: (f.0, f.1, f.0 + max(0, f.2), f.1 + max(0, f.3)))
        case "rect" where f.2 > width && f.3 > width:
            let component = Double(width) / 3
            var svg = ""
            if let fill {
                svg += "<rect x=\"\(f.0)\" y=\"\(f.1)\" width=\"\(f.2)\" height=\"\(f.3)\" fill=\"\(fill)\"/>"
            }
            for delta in [-component, component] {
                let rx = SVGNumber.decimal(Double(f.0) + delta)
                let ry = SVGNumber.decimal(Double(f.1) + delta)
                let rw = SVGNumber.decimal(Double(f.2) - 2 * delta)
                let rh = SVGNumber.decimal(Double(f.3) - 2 * delta)
                svg += "<rect x=\"\(rx)\" y=\"\(ry)\" width=\"\(rw)\" height=\"\(rh)\" fill=\"none\" stroke=\"\(color)\" stroke-width=\"\(SVGNumber.decimal(component))\"/>"
            }
            return svg
        default:
            return nil
        }
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
