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
// near, not exactly where, PowerPoint puts them — but recognizable, complete
// (no text is dropped short of a hostile-input bound) and byte-deterministic.
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
    private let diagnostics = RenderDiagnosticCollector()

    func render(pixelWidth: Int) throws -> (svg: String, problems: SlideRenderProblems) {
        // Not for the value: this is the one call that surfaces a malformed
        // slide part as a thrown error. Everything below reaches the tree
        // through `existingSpTree`, which swallows the parse with `try?` and
        // would render a silently blank slide instead.
        _ = try slidePart.dom()
        diagnostics.reset()
        diagnostics.location = FidelityLocation(slideIndex: slideNumber - 1,
            partURI: slidePart.uri.description, path: "/p:sld")
        // p:sldSz comes from the file too, and the aspect-ratio conversion below
        // goes through Int(_: Double), which traps when the double is out of
        // range — so bound the dimensions before dividing by them.
        let bound = OOXMLBounds.coordinate
        let w = bound.contains(slideSize.width.rawValue) ? slideSize.width.rawValue : 0
        let h = bound.contains(slideSize.height.rawValue) ? slideSize.height.rawValue : 0
        let pxH = w > 0 ? Int((Double(pixelWidth) * Double(h) / Double(w)).rounded()) : pixelWidth
        var defs = ""
        var body = ""

        // A slide inherits its background and its furniture. Rendering only the
        // slide's own shapes on the slide's own background makes every deck
        // look like whatever it was before a template was applied: the logo,
        // the photo panel, the coloured field a brand puts on its layouts all
        // live on the layout and the master, not on the slide.
        let (chain, inheritedProblems) = inheritanceChain()
        if inheritedProblems.layoutUnresolved || inheritedProblems.masterUnresolved {
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
            body += renderInherited(master, defs: &defs)
        }
        if let layout = chain.layout {
            body += renderInherited(layout, defs: &defs)
        }

        if let spTree = Slide.existingSpTree(of: slidePart) {
            for (index, child) in spTree.childElements.enumerated() {
                diagnostics.inspect(child, owner: slidePart, slideIndex: slideNumber - 1,
                    path: "/p:cSld/p:spTree/\(child.name)[\(index + 1)]", package: package)
                switch child.name {
                case "p:sp": body += renderShape(child, ownedBy: slidePart, defs: &defs)
                case "p:pic": body += renderPicture(child, ownedBy: slidePart, defs: &defs)
                case "p:graphicFrame": body += renderGraphicFrame(child, ownedBy: slidePart, defs: &defs)
                default: break
                }
            }
        }

        defs += diagnostics.fontDefinitions
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(pixelWidth)\" height=\"\(pxH)\" "
            + "viewBox=\"0 0 \(w) \(h)\"><defs>\(defs)</defs>\(body)</svg>"
        var problems = inheritedProblems
        problems.fidelityIssues = diagnostics.issues
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
                                box f: (Int, Int, Int, Int), defs: inout String) -> String? {
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
            if (try? part.dom())?[attribute: "showMasterSp"] == "0" { return false }
        }
        return true
    }

    /// A layout's or master's own decoration, beneath the slide's shapes.
    ///
    /// Placeholders are skipped: on a layout or a master they are prompts
    /// ("Click to add title"), and PowerPoint never draws them on a slide.
    private func renderInherited(_ part: Part, defs: inout String) -> String {
        guard let tree = Slide.existingSpTree(of: part) else { return "" }
        var out = ""
        for (index, child) in tree.childElements.enumerated() {
            if Placeholders.phElement(of: child) != nil { continue }
            diagnostics.inspect(child, owner: part, slideIndex: slideNumber - 1,
                path: "/p:cSld/p:spTree/\(child.name)[\(index + 1)]", package: package)
            switch child.name {
            case "p:sp": out += renderShape(child, ownedBy: part, defs: &defs)
            case "p:pic": out += renderPicture(child, ownedBy: part, defs: &defs)
            case "p:graphicFrame": out += renderGraphicFrame(child, ownedBy: part, defs: &defs)
            default: break
            }
        }
        return out
    }

    // MARK: - Shapes

    private func renderShape(_ sp: XML.Element, ownedBy owner: Part,
                             defs: inout String) -> String {
        guard let spPr = sp.firstChild(named: "p:spPr") else { return "" }
        let f = resolvedFrame(of: sp, spPr: spPr, ownedBy: owner)
        var out = ""
        let prst = spPr.firstChild(named: "a:prstGeom")?[attribute: "prst"] ?? "rect"
        let fill = paint(for: spPr, box: f, defs: &defs, ownedBy: owner)
        let stroke = strokeAttrs(spPr)
        if let fill { out += geometry(prst, f, fill: fill, stroke: stroke) }
        else if !stroke.isEmpty { out += geometry(prst, f, fill: "none", stroke: stroke) }
        if let txBody = sp.firstChild(named: "p:txBody") {
            out += renderText(txBody, box: f,
                              inheriting: inheritedRunDefaults(for: sp, ownedBy: owner))
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
        let styles = RichTextLayout.inheritedStyles(for: sp, owner: owner, package: package)
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
                            inheriting defaults: XML.Element? = nil) -> String {
        let layout = RichTextLayout(textBody: txBody,
            width: Double(f.2) / Double(emuPerPoint), height: Double(f.3) / Double(emuPerPoint),
            fonts: fonts, theme: theme, inheritedStyles: defaults.map {
                $0.name == "rostrum:inheritedStyles" ? $0.childElements : [$0]
            } ?? [],
            slideNumber: slideNumber, maxLines: 64)
        diagnostics.text(layout)
        let decimal = SVGNumber.decimal
        return layout.lines.map { line in
            let baseline = Double(f.1) + line.baseline * Double(emuPerPoint)
            var result = "<text transform=\"translate(\(f.0),\(decimal(baseline))) scale(\(emuPerPoint))\" xml:space=\"preserve\">"
            for span in line.spans {
                let run = span.run
                let embedded = run.fontFamily.flatMap {
                    diagnostics.embeddedFamily(for: FontFaceKey(family: $0, bold: run.bold, italic: run.italic), fonts: fonts)
                }
                result += "<tspan x=\"\(decimal(span.x))\" font-size=\"\(decimal(run.fontSize))\" fill=\"\(run.color)\""
                    + fontFamilyAttr(embedded ?? run.fontFamily)
                    + (run.bold ? " font-weight=\"bold\"" : "")
                    + (run.italic ? " font-style=\"italic\"" : "")
                    + (run.tracking == 0 ? "" : " letter-spacing=\"\(decimal(run.tracking))\"")
                if span.width > 0 { result += " textLength=\"\(decimal(span.width))\" lengthAdjust=\"spacingAndGlyphs\"" }
                result += ">" + escape(run.text) + "</tspan>"
            }
            return result + "</text>"
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
        guard let typeface, !typeface.isEmpty else { return "" }
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
            return nil
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

    private func renderPicture(_ pic: XML.Element, ownedBy owner: Part, defs: inout String) -> String {
        guard let spPr = pic.firstChild(named: "p:spPr"),
              let fill = pic.firstChild(named: "p:blipFill") else { return "" }
        let frame = resolvedFrame(of: pic, spPr: spPr, ownedBy: owner)
        guard let pattern = imagePattern(fill, ownedBy: owner, box: frame, defs: &defs) else { return "" }
        let preset = spPr.firstChild(named: "a:prstGeom")?[attribute: "prst"] ?? "rect"
        let shape = geometry(preset, frame, fill: pattern, stroke: strokeAttrs(spPr))
        let transform = spPr.firstChild(named: "a:xfrm")
        let angle = Double(transform?.boundedInt("rot", in: Int(Int32.min)...Int(Int32.max)) ?? 0) / 60000
        let flipH = transform?[attribute: "flipH"] == "1" || transform?[attribute: "flipH"] == "true"
        let flipV = transform?[attribute: "flipV"] == "1" || transform?[attribute: "flipV"] == "true"
        guard angle != 0 || flipH || flipV else { return shape }
        let centerX = Double(frame.0) + Double(frame.2) / 2
        let centerY = Double(frame.1) + Double(frame.3) / 2
        return "<g transform=\"translate(\(centerX) \(centerY)) rotate(\(angle)) scale(\(flipH ? -1 : 1) \(flipV ? -1 : 1)) translate(\(-centerX) \(-centerY))\">\(shape)</g>"
    }

    /// Read supported embedded raster bytes without recoding. Unsupported
    /// formats remain preserved in the package, but are not mislabeled PNGs.
    private func imageResource(rId: String, ownedBy owner: Part) -> (url: String, info: ImageInfo)? {
        guard let resource = diagnostics.images.resolve(rId, owner: owner, package: package),
              let info = resource.info, let url = diagnostics.images.url(for: resource) else { return nil }
        return (url, info)
    }

    /// Crop and stretch share ImagePlacement with picture editing. Tile uses
    /// the image's physical native size, percentage scale, alignment, offsets
    /// and optional alternating mirror tiles. SVG preserves intrinsic alpha.
    private func imagePattern(_ blip: XML.Element, ownedBy owner: Part,
                              box frame: (Int, Int, Int, Int), defs: inout String) -> String? {
        guard let rId = blip.firstChild(named: "a:blip")?[attribute: "r:embed"],
              let resource = imageResource(rId: rId, ownedBy: owner), frame.2 > 0, frame.3 > 0 else { return nil }
        // Definitions only grow; byte count gives unique IDs without rescanning
        // all preceding base64 image data for extended grapheme clusters.
        let id = "image\(defs.utf8.count)"
        if let tile = blip.firstChild(named: "a:tile") {
            let crop = PictureCrop.read(blip.firstChild(named: "a:srcRect"))
            guard crop.valid else { return nil }
            let sx = Double(tile.boundedInt("sx", in: 1...Int(Int32.max)) ?? 100000) / 100000
            let sy = Double(tile.boundedInt("sy", in: 1...Int(Int32.max)) ?? 100000) / 100000
            let width = Double(resource.info.nativeSize.width.rawValue) * sx * (1 - crop.left - crop.right)
            let height = Double(resource.info.nativeSize.height.rawValue) * sy * (1 - crop.top - crop.bottom)
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
                                    defs: inout String) -> String {
        guard let xfrm = gf.firstChild(named: "p:xfrm"),
              let off = xfrm.firstChild(named: "a:off"), let ext = xfrm.firstChild(named: "a:ext") else { return "" }
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
        // Anything still unplotted — SmartArt, OLE, a chart kind with no plot
        // here — keeps the labeled placeholder. Named rather than "[object]"
        // so a thumbnail says which thing it could not draw.
        let label: String
        if uri.hasSuffix("/chart") { label = "[chart]" }
        else if uri == GraphicDataURI.diagram { label = "[SmartArt]" }
        else if uri == GraphicDataURI.ole { label = "[embedded object]" }
        else { label = "[object]" }
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
        let series = Array(chart.series.filter { !$0.values.isEmpty }.prefix(32))
        guard !series.isEmpty else { return nil }
        let categories = chart.categories
        let pointCount = series.map(\.values.count).max() ?? 0
        let catCount = Swift.min(Swift.max(categories.count, pointCount), 512)
        guard catCount > 0 else { return nil }

        let fx = Double(x), fy = Double(y), fw = Double(w), fh = Double(h)
        let title = chart.title
        let hasLegend = series.count > 1
        let padX = fw * 0.06
        let padTop = fh * (title == nil ? 0.07 : 0.17)
        let padBottom = fh * (hasLegend ? 0.22 : 0.13)
        let plotX = fx + padX
        let plotY = fy + padTop
        let plotW = Swift.max(1, fw - padX * 2)
        let plotH = Swift.max(1, fh - padTop - padBottom)

        var out = ""
        if let title {
            out += textElement(clipLabel(title, width: w, sizeEMU: 13 * emuPerPoint),
                               x: coord(fx + fw / 2), baseline: coord(fy + fh * 0.11),
                               sizeEMU: 13 * emuPerPoint, fill: "#666666", anchor: "middle",
                               bold: false, typeface: nil)
        }

        switch kind {
        case "pieChart", "doughnutChart":
            out += pieBody(series[0], kind: kind, cx: fx + fw / 2, cy: plotY + plotH / 2,
                           radius: Swift.min(fw, plotH) / 2 * 0.88)
            out += legend(series, x: fx, y: plotY + plotH, width: fw, height: fh, labels: categories)
        case "barChart", "lineChart", "areaChart":
            let plot = chart.plots.first
            let grouping = plot?.firstChild(named: "c:grouping")?[attribute: "val"] ?? "clustered"
            let scale = ValueScale(series: series, catCount: catCount, grouping: grouping)
            out += axes(plotX: plotX, plotY: plotY, plotW: plotW, plotH: plotH, scale: scale)
            let horizontal = kind == "barChart"
                && plot?.firstChild(named: "c:barDir")?[attribute: "val"] == "bar"
            if kind == "barChart" {
                out += barBody(series, catCount: catCount, scale: scale, horizontal: horizontal,
                               plotX: plotX, plotY: plotY, plotW: plotW, plotH: plotH)
            } else {
                out += lineBody(series, catCount: catCount, scale: scale, filled: kind == "areaChart",
                                plotX: plotX, plotY: plotY, plotW: plotW, plotH: plotH)
            }
            out += categoryLabels(categories, catCount: catCount, plotX: plotX, plotW: plotW,
                                  baseY: plotY + plotH, height: fh)
            if hasLegend {
                out += legend(series, x: fx, y: plotY + plotH + fh * 0.08, width: fw, height: fh, labels: nil)
            }
        default:
            return nil          // radar/scatter/bubble/surface → placeholder
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

        init(series: [ChartData.Series], catCount: Int, grouping: String) {
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
            guard high.isFinite, low.isFinite, high - low > 0 else {
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
                      scale: ValueScale) -> String {
        let zeroY = plotY + plotH * (1 - scale.zeroFraction)
        return "<line x1=\"\(coord(plotX))\" y1=\"\(coord(zeroY))\" x2=\"\(coord(plotX + plotW))\" "
            + "y2=\"\(coord(zeroY))\" stroke=\"#BFBFBF\" stroke-width=\"6350\"/>"
    }

    private func barBody(_ series: [ChartData.Series], catCount: Int, scale: ValueScale,
                         horizontal: Bool, plotX: Double, plotY: Double,
                         plotW: Double, plotH: Double) -> String {
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
            let bandStart = (horizontal ? plotY : plotX) + Double(index) * slot + inset
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
                let lo = Swift.min(startFraction, endFraction), hi = Swift.max(startFraction, endFraction)
                let offset = scale.stacked ? 0 : Double(s) * barWidth
                let fill = seriesColor(s)
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
                          plotW: Double, plotH: Double) -> String {
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
            let color = seriesColor(s)
            if filled {
                let baseY = plotY + plotH * (1 - scale.zeroFraction)
                out += "<polygon points=\"\(coord(points[0].0)),\(coord(baseY)) \(path) "
                    + "\(coord(points[points.count - 1].0)),\(coord(baseY))\" fill=\"\(color)\" "
                    + "fill-opacity=\"0.55\"/>"
            }
            out += "<polyline points=\"\(path)\" fill=\"none\" stroke=\"\(color)\" "
                + "stroke-width=\"25400\" stroke-linejoin=\"round\"/>"
        }
        return out
    }

    private func pieBody(_ entry: ChartData.Series, kind: String,
                         cx: Double, cy: Double, radius: Double) -> String {
        guard radius > 0 else { return "" }
        let values = entry.values.compactMap { $0 }.filter { $0.isFinite && $0 > 0 }
        let total = values.reduce(0, +)
        guard total > 0 else { return "" }
        let doughnut = kind == "doughnutChart"
        // Doughnuts are stroked arcs rather than a pie with a punched hole, so
        // they don't need to know the slide background color.
        let ringWidth = radius * 0.42
        let ringRadius = radius - ringWidth / 2
        var out = ""
        var angle = -Double.pi / 2
        for (index, value) in values.enumerated() {
            let sweep = value / total * 2 * Double.pi
            let end = angle + sweep
            let color = seriesColor(index)
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
                                plotW: Double, baseY: Double, height: Double) -> String {
        guard !categories.isEmpty, catCount <= 12 else { return "" }
        let step = plotW / Double(catCount)
        let size = 10 * emuPerPoint
        var out = ""
        for (index, label) in categories.prefix(catCount).enumerated() {
            out += textElement(clipLabel(label, width: coord(step), sizeEMU: size),
                               x: coord(plotX + step * (Double(index) + 0.5)),
                               baseline: coord(baseY + height * 0.06),
                               sizeEMU: size, fill: "#808080", anchor: "middle",
                               bold: false, typeface: nil)
        }
        return out
    }

    private func legend(_ series: [ChartData.Series], x: Double, y: Double, width: Double,
                        height: Double, labels: [String]?) -> String {
        let names = labels ?? series.map(\.name)
        let entries = Array(names.prefix(6)).enumerated().filter { !$0.element.isEmpty }
        guard !entries.isEmpty else { return "" }
        let size = 10 * emuPerPoint
        let slot = width / Double(entries.count)
        let swatch = height * 0.035
        var out = ""
        for (slotIndex, entry) in entries.enumerated() {
            let left = x + slot * Double(slotIndex) + slot * 0.1
            out += box(coord(left), coord(y + height * 0.02), coord(swatch), coord(swatch),
                       fill: seriesColor(entry.offset))
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

    private func renderTable(_ tbl: XML.Element, ownedBy owner: Part, x: Int, y: Int, defs: inout String) -> String {
        let table = Table(tbl: tbl, part: owner, package: package)
        let grid = TableGridSnapshot(tbl)
        let topology = try? grid.topology()
        let resolver = TableStyleResolver(table: table, theme: theme)
        var styles = TableStyleResolver.RenderSession(resolver)
        if let definition = resolver.activeDefinition() {
            let location = diagnostics.location
            diagnostics.inspect(definition, owner: resolver.stylePart ?? owner, slideIndex: slideNumber - 1,
                path: "/a:tblStyleLst/a:tblStyle[@styleId='\(table.styleID ?? "default")']", package: package)
            for reference in resolver.themeReferences(in: definition) {
                diagnostics.inspect(reference.root, owner: theme.part, slideIndex: slideNumber - 1,
                    path: reference.path, package: package, tableStyleReference: true)
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
        var out = ""
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
                // Borders are independent authored edges, never a synthetic
                // grid. Use the far physical cell for a merge's outer edge,
                // unless the origin explicitly overrides that edge.
                for edge in TableCellBorder.allCases {
                    let edgeRow = edge == .bottom ? rowEnd - 1 : r
                    let edgeColumn = edge == .left ? (rtl ? columnEnd - 1 : c) : edge == .right ? (rtl ? c : columnEnd - 1) : c
                    let direct = grid.cells[r][c].firstChild(named: "a:tcPr")?.firstChild(named: edge.rawValue)
                    let edgeProperties = direct != nil || (edgeRow == r && edgeColumn == c) ? properties : styles.effective(row: edgeRow, column: edgeColumn).properties
                    guard let line = edgeProperties.firstChild(named: edge.rawValue),
                          line.firstChild(named: "a:noFill") == nil,
                          let color = colorHex(in: line.firstChild(named: "a:solidFill")) else { continue }
                    let width = max(0, line.coordinate("w") ?? 12700)
                    if width == 0 { continue }
                    let endpoints: (Int, Int, Int, Int)
                    switch edge {
                    case .left: endpoints = (cx, cy, cx, cy + rh)
                    case .right: endpoints = (cx + cw, cy, cx + cw, cy + rh)
                    case .top: endpoints = (cx, cy, cx + cw, cy)
                    case .bottom: endpoints = (cx, cy + rh, cx + cw, cy + rh)
                    case .diagonalDown: endpoints = (cx, cy, cx + cw, cy + rh)
                    case .diagonalUp: endpoints = (cx, cy + rh, cx + cw, cy)
                    }
                    let dash = line.firstChild(named: "a:prstDash")?[attribute: "val"]
                    let pattern: String
                    switch dash {
                    case "dot", "sysDot": pattern = "\(width) \(width * 2)"
                    case "dash", "sysDash": pattern = "\(width * 3) \(width * 2)"
                    case "lgDash": pattern = "\(width * 6) \(width * 2)"
                    case "dashDot", "sysDashDot": pattern = "\(width * 3) \(width * 2) \(width) \(width * 2)"
                    default: pattern = ""
                    }
                    let dashAttribute = pattern.isEmpty ? "" : " stroke-dasharray=\"\(pattern)\""
                    out += "<line x1=\"\(endpoints.0)\" y1=\"\(endpoints.1)\" x2=\"\(endpoints.2)\" y2=\"\(endpoints.3)\" stroke=\"\(color)\" stroke-width=\"\(width)\"\(dashAttribute)/>"
                }
                if let body = grid.cells[r][c].firstChild(named: "a:txBody") {
                    // Layout reads paragraphs without modifying them. Only
                    // bodyPr needs a private copy for the cell overrides.
                    let text = XML.Element(body.name, attributes: body.attributes, children: body.children)
                    if let index = text.children.firstIndex(where: {
                        if case .element(let node) = $0 { return node.name == "a:bodyPr" }
                        return false
                    }), case .element(let original) = text.children[index] {
                        text.children[index] = .element(original.deepCopy())
                    }
                    let bodyPr = text.getOrAddChild("a:bodyPr", beforeAnyOf: ["a:lstStyle", "a:p"])
                    for (margin, inset, fallback) in [("marL", "lIns", 91440), ("marR", "rIns", 91440), ("marT", "tIns", 45720), ("marB", "bIns", 45720)] {
                        bodyPr[attribute: inset] = String(properties.coordinate(margin) ?? fallback)
                    }
                    bodyPr[attribute: "anchor"] = properties[attribute: "anchor"] ?? "t"
                    let direction = properties[attribute: "vert"] ?? "horz"
                    // Rotation belongs to the cell, while text layout uses a
                    // horizontal box with swapped dimensions.
                    if direction == "vert" || direction == "vert270" {
                        bodyPr[attribute: "vert"] = "horz"
                        let transform = direction == "vert" ? "translate(\(cx + cw) \(cy)) rotate(90)" : "translate(\(cx) \(cy + rh)) rotate(-90)"
                        out += "<g transform=\"\(transform)\">" + renderText(text, box: (0, 0, rh, cw), inheriting: effective.text) + "</g>"
                    } else {
                        bodyPr[attribute: "vert"] = direction
                        out += renderText(text, box: frame, inheriting: effective.text)
                    }
                }
            }
        }
        return out
    }

    private func tableGradient(_ gradient: XML.Element, box frame: (Int, Int, Int, Int), defs: inout String) -> String {
        let id = "tg\(defs.utf8.count)"
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

    private func paint(for pr: XML.Element, box f: (Int, Int, Int, Int), defs: inout String, ownedBy owner: Part? = nil) -> String? {
        if let solid = pr.firstChild(named: "a:solidFill") { return colorHex(in: solid) }
        if let grad = pr.firstChild(named: "a:gradFill") { return gradientRef(grad, box: f, defs: &defs) }
        if let blip = pr.firstChild(named: "a:blipFill") { return imagePattern(blip, ownedBy: owner ?? slidePart, box: f, defs: &defs) }
        if pr.firstChild(named: "a:noFill") != nil { return nil }
        return nil
    }

    private func gradientRef(_ grad: XML.Element, box f: (Int, Int, Int, Int), defs: inout String) -> String {
        let id = "g\(f.0)_\(f.1)_\(defs.utf8.count)"
        let isRadial = grad.firstChild(named: "a:path") != nil
        let stopSVG = GradientStops.svg(grad, theme: theme)
        if isRadial {
            defs += "<radialGradient id=\"\(id)\">\(stopSVG)</radialGradient>"
        } else {
            defs += "<linearGradient id=\"\(id)\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">\(stopSVG)</linearGradient>"
        }
        return "url(#\(id))"
    }

    private func colorHex(in container: XML.Element?) -> String? {
        guard let container, let resolved = DrawingColor.resolve(in: container, theme: theme) else { return nil }
        if resolved.alpha < 1 {
            return "rgba(\(resolved.color.red),\(resolved.color.green),\(resolved.color.blue),\(resolved.alpha))"
        }
        return "#" + resolved.color.hex
    }

    private func strokeAttrs(_ spPr: XML.Element) -> String {
        guard let ln = spPr.firstChild(named: "a:ln"), ln.firstChild(named: "a:noFill") == nil,
              let color = colorHex(in: ln.firstChild(named: "a:solidFill")) else { return "" }
        let width = ln.coordinate("w") ?? 12700
        return " stroke=\"\(color)\" stroke-width=\"\(width)\""
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
            case "\"": out += "&quot;"
            default: out.append(c)
            }
        }
        return out
    }
}

/// What a slide could not resolve while rendering it to SVG.
///
/// `renderSVG(slideAt:pixelWidth:)` always produces an SVG, even from a deck
/// whose inheritance is broken — but a broken link means everything the slide
/// inherits (its background, its placeholder positions, its theme colours) is
/// missing from that SVG, with nothing in the output to say so. To a viewer the
/// slide then looks like Rostrum rendered it wrong, when really the deck is
/// damaged. These flags let a caller tell the two apart. An empty value
/// (`isEmpty`) means no known issue was detected in the covered paths.
public struct SlideRenderProblems: Sendable, Equatable {
    /// The slide names no layout, or the layout part it names could not be
    /// loaded. Nothing the layout would have contributed was drawn.
    public var layoutUnresolved: Bool

    /// The layout loaded, but it names no master, or the master part it names
    /// could not be loaded. Nothing the master would have contributed was drawn.
    public var masterUnresolved: Bool

    /// Actual content that the current preview approximated, omitted or lacked.
    public var fidelityIssues: [FidelityIssue]

    /// No known issues were detected by the covered renderer paths. This is
    /// not a universal fidelity guarantee or an Office conformance certificate.
    public var isEmpty: Bool { !layoutUnresolved && !masterUnresolved && fidelityIssues.isEmpty }

    public init(layoutUnresolved: Bool = false, masterUnresolved: Bool = false,
                fidelityIssues: [FidelityIssue] = []) {
        self.layoutUnresolved = layoutUnresolved
        self.masterUnresolved = masterUnresolved
        self.fidelityIssues = fidelityIssues
    }
}

public extension Presentation {
    /// Render one slide to a self-contained SVG string (thumbnails / visual diff).
    func renderSVG(slideAt index: Int, pixelWidth: Int = 1280, strictRendering: Bool = false) throws -> String {
        try renderSVGReportingProblems(slideAt: index, pixelWidth: pixelWidth, strictRendering: strictRendering).svg
    }

    /// Render one slide, and report anything its inheritance chain could not
    /// resolve, along with known fidelity gaps in the content it rendered.
    /// Set `strictRendering` to refuse known approximations, omissions and missing fonts.
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
