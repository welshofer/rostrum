import Foundation

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

    func render(pixelWidth: Int) throws -> (svg: String, problems: SlideRenderProblems) {
        let dom = try slidePart.dom()
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
        let (chain, problems) = inheritanceChain()
        body += box(0, 0, w, h,
                    fill: backgroundFill(chain: chain, box: (0, 0, w, h), defs: &defs) ?? "#FFFFFF")

        if showsMasterShapes(chain: chain), let master = chain.master {
            body += renderInherited(master, defs: &defs)
        }
        if let layout = chain.layout {
            body += renderInherited(layout, defs: &defs)
        }

        if let spTree = Slide.existingSpTree(of: slidePart) {
            for child in spTree.childElements {
                switch child.name {
                case "p:sp": body += renderShape(child, ownedBy: slidePart, defs: &defs)
                case "p:pic": body += renderPicture(child, ownedBy: slidePart)
                case "p:graphicFrame": body += renderGraphicFrame(child, ownedBy: slidePart, defs: &defs)
                default: break
                }
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
                                box f: (Int, Int, Int, Int), defs: inout String) -> String? {
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
    private func renderInherited(_ part: Part, defs: inout String) -> String {
        guard let tree = Slide.existingSpTree(of: part) else { return "" }
        var out = ""
        for child in tree.childElements {
            if Placeholders.phElement(of: child) != nil { continue }
            switch child.name {
            case "p:sp": out += renderShape(child, ownedBy: part, defs: &defs)
            case "p:pic": out += renderPicture(child, ownedBy: part)
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
        let fill = paint(for: spPr, box: f, defs: &defs)
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
        guard owner === slidePart, let ph = Placeholders.phElement(of: sp) else { return nil }
        let idx = ph[attribute: "idx"].flatMap { Int($0) } ?? 0
        let chain = inheritanceChain().chain

        func level1(_ lstStyle: XML.Element?) -> XML.Element? {
            lstStyle?.firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr")
        }

        var layoutType = ph[attribute: "type"] ?? "obj"
        if let layout = chain.layout, let tree = Slide.existingSpTree(of: layout) {
            for element in tree.childElements {
                guard let lph = Placeholders.phElement(of: element),
                      (lph[attribute: "idx"].flatMap { Int($0) } ?? 0) == idx else { continue }
                layoutType = lph[attribute: "type"] ?? layoutType
                if let defaults = level1(element.firstChild(named: "p:txBody")?
                    .firstChild(named: "a:lstStyle")) {
                    return defaults
                }
                break
            }
        }

        guard let master = chain.master, let dom = try? master.dom(),
              let styles = dom.firstChild(named: "p:txStyles") else { return nil }
        let bucket: String
        switch Slide.masterTypeReduction[layoutType] ?? "body" {
        case "title": bucket = "p:titleStyle"
        case "body": bucket = "p:bodyStyle"
        default: bucket = "p:otherStyle"
        }
        return level1(styles.firstChild(named: bucket))
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
            let rPr = pieces.first?.firstChild(named: "a:rPr")
            // ST_TextFontSize is 1pt–4000pt in hundredths. The file can say
            // anything, and `sz * 12700` on a large Int is an overflow crash.
            let sizeHundredths = min(max(rPr?[attribute: "sz"].flatMap { Int($0) }
                ?? defaults?[attribute: "sz"].flatMap { Int($0) } ?? 1800, 100),
                                     400_000)
            let sizeEMU = sizeHundredths * emuPerPoint / 100
            let bold = rPr?[attribute: "b"] == "1"
                || (rPr?[attribute: "b"] == nil && defaults?[attribute: "b"] == "1")
            let color = rPr.flatMap { colorHex(in: $0.firstChild(named: "a:solidFill")) }
                ?? defaults.flatMap { colorHex(in: $0.firstChild(named: "a:solidFill")) } ?? "#1A1A1A"
            let align = p.firstChild(named: "a:pPr")?[attribute: "algn"] ?? "l"
            let (anchorX, textAnchor) = align == "ctr" ? (x + w / 2, "middle")
                : align == "r" ? (x + w, "end") : (x, "start")

            // A run usually inherits its typeface from the theme rather than
            // naming one, and `+mj-lt`/`+mn-lt` name it indirectly. Resolving
            // both is what lets a deck with registered fonts take the measured
            // path for the text it actually renders, not just for runs that
            // happen to carry an explicit `a:latin`.
            let typeface = resolvedTypeface(rPr) ?? resolvedTypeface(defaults)
            if pieces.count == 1, let typeface, let metrics = fonts.metrics(for: typeface) {
                // Measured path: real word wrap and baseline placement —
                // single-run paragraphs only, since a mixed-size/font
                // paragraph measured at the first run's metrics would wrap
                // wrong; those keep the estimated path below.
                // (Left-aligned text starts at the body inset; the estimated
                // branch below keeps its historical `x` so existing output is
                // byte-identical for decks without registered fonts.)
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
                // a character width from the font size and wrap on it. Line
                // advance stays exactly as the estimated path always had it, so
                // a paragraph that already fit emits byte-identical markup.
                for line in wrapEstimated(text, width: w, sizeEMU: sizeEMU) {
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

    private func renderPicture(_ pic: XML.Element, ownedBy owner: Part) -> String {
        guard let spPr = pic.firstChild(named: "p:spPr") else { return "" }
        let (x, y, w, h) = frame(of: spPr)
        guard let rId = pic.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"],
              let data = imageData(rId: rId, ownedBy: owner) else { return "" }
        return "<image x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" "
            + "preserveAspectRatio=\"xMidYMid slice\" href=\"\(data)\"/>"
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
                              box f: (Int, Int, Int, Int), defs: inout String) -> String? {
        guard let rId = blip.firstChild(named: "a:blip")?[attribute: "r:embed"],
              let data = imageData(rId: rId, ownedBy: owner), f.2 > 0, f.3 > 0 else { return nil }
        let id = "bg\(defs.count)"
        defs += "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" "
            + "x=\"\(f.0)\" y=\"\(f.1)\" width=\"\(f.2)\" height=\"\(f.3)\">"
            + "<image width=\"\(f.2)\" height=\"\(f.3)\" preserveAspectRatio=\"xMidYMid slice\" "
            + "href=\"\(data)\"/></pattern>"
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
            return renderTable(tbl, x: x, y: y, defs: &defs)
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

    private func renderTable(_ tbl: XML.Element, x: Int, y: Int, defs: inout String) -> String {
        let cols = tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol").map { intAttr($0, "w") } ?? []
        let rows = tbl.children(named: "a:tr")
        var out = ""
        var cy = y
        for tr in rows {
            let rh = intAttr(tr, "h")
            var cx = x
            for (c, tc) in tr.children(named: "a:tc").enumerated() {
                let cw = c < cols.count ? cols[c] : 0
                let fill = colorHex(in: tc.firstChild(named: "a:tcPr")?.firstChild(named: "a:solidFill")) ?? "#FFFFFF"
                out += box(cx, cy, cw, rh, fill: fill, stroke: " stroke=\"#DDDDDD\" stroke-width=\"3175\"")
                if let txBody = tc.firstChild(named: "a:txBody") {
                    out += renderText(txBody, box: (cx + cw / 20, cy, cw, rh))
                }
                cx += cw
            }
            cy += rh
        }
        return out
    }

    // MARK: - Paint / helpers

    private func paint(for pr: XML.Element, box f: (Int, Int, Int, Int), defs: inout String) -> String? {
        if let solid = pr.firstChild(named: "a:solidFill") { return colorHex(in: solid) }
        if let grad = pr.firstChild(named: "a:gradFill") { return gradientRef(grad, box: f, defs: &defs) }
        if pr.firstChild(named: "a:blipFill") != nil { return "#DDDDDD" }   // image fill → neutral
        if pr.firstChild(named: "a:noFill") != nil { return nil }
        return nil
    }

    private func gradientRef(_ grad: XML.Element, box f: (Int, Int, Int, Int), defs: inout String) -> String {
        let stops = grad.firstChild(named: "a:gsLst")?.children(named: "a:gs") ?? []
        let id = "g\(f.0)_\(f.1)_\(defs.count)"
        let isRadial = grad.firstChild(named: "a:path") != nil
        var stopSVG = ""
        for gs in stops {
            let pos = (Double(gs.boundedInt("pos", in: 0...100_000) ?? 0) / 1000).rounded() / 100
            let color = colorHex(in: gs) ?? "#000000"
            stopSVG += "<stop offset=\"\(pos)\" stop-color=\"\(color)\"/>"
        }
        if isRadial {
            defs += "<radialGradient id=\"\(id)\">\(stopSVG)</radialGradient>"
        } else {
            defs += "<linearGradient id=\"\(id)\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">\(stopSVG)</linearGradient>"
        }
        return "url(#\(id))"
    }

    private func colorHex(in container: XML.Element?) -> String? {
        guard let container else { return nil }
        // Validated, not interpolated raw: this string lands unescaped inside
        // an SVG attribute, so a file-supplied `val="x&quot; onload=…"` would
        // otherwise inject markup into the rendered output.
        if let srgb = container.firstChild(named: "a:srgbClr")?[attribute: "val"],
           let color = Color(validating: srgb) { return "#" + color.hex }
        if let raw = container.firstChild(named: "a:schemeClr")?[attribute: "val"],
           let scheme = SchemeColor(rawValue: raw), let color = theme.resolve(scheme) { return "#" + color.hex }
        return nil
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
/// (`isEmpty`) means every link resolved and nothing was left out.
public struct SlideRenderProblems: Sendable, Equatable {
    /// The slide names no layout, or the layout part it names could not be
    /// loaded. Nothing the layout would have contributed was drawn.
    public var layoutUnresolved: Bool

    /// The layout loaded, but it names no master, or the master part it names
    /// could not be loaded. Nothing the master would have contributed was drawn.
    public var masterUnresolved: Bool

    /// No link in the slide → layout → master chain was broken.
    public var isEmpty: Bool { !layoutUnresolved && !masterUnresolved }

    public init(layoutUnresolved: Bool = false, masterUnresolved: Bool = false) {
        self.layoutUnresolved = layoutUnresolved
        self.masterUnresolved = masterUnresolved
    }
}

public extension Presentation {
    /// Render one slide to a self-contained SVG string (thumbnails / visual diff).
    func renderSVG(slideAt index: Int, pixelWidth: Int = 1280) throws -> String {
        try renderSVGReportingProblems(slideAt: index, pixelWidth: pixelWidth).svg
    }

    /// Render one slide, and report anything its inheritance chain could not
    /// resolve.
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
                        theme: theme, package: package, fonts: fonts,
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
