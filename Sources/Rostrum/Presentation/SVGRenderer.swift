import Foundation

// Headless slide → SVG rendering, for thumbnails and deterministic visual-diff
// tests. Glyphs are delegated to the SVG viewer (no rasterizer), so this stays
// zero-dependency. Coordinates are EMU (the viewBox is in EMU); font sizes are
// points × 12700 EMU/pt. Not pixel-perfect — text layout is approximate (one
// line per paragraph, positioned by font size) — but recognizable and byte-
// deterministic.
struct SVGRenderer {
    let slidePart: Part
    let slideSize: (width: EMU, height: EMU)
    let theme: Theme
    let package: OPCPackage
    /// Registered fonts: paragraphs whose typeface resolves here get real
    /// word wrap and baseline placement instead of the one-line approximation.
    let fonts: FontLibrary

    private let emuPerPoint = 12700

    func render(pixelWidth: Int) throws -> String {
        let dom = try slidePart.dom()
        let w = slideSize.width.rawValue, h = slideSize.height.rawValue
        let pxH = w > 0 ? Int((Double(pixelWidth) * Double(h) / Double(w)).rounded()) : pixelWidth
        var defs = ""
        var body = ""

        if let bgPr = dom.firstChild(named: "p:cSld")?.firstChild(named: "p:bg")?.firstChild(named: "p:bgPr"),
           let paint = paint(for: bgPr, box: (0, 0, w, h), defs: &defs) {
            body += box(0, 0, w, h, fill: paint)
        } else {
            body += box(0, 0, w, h, fill: "#FFFFFF")
        }

        if let spTree = Slide.existingSpTree(of: slidePart) {
            for child in spTree.childElements {
                switch child.name {
                case "p:sp": body += renderShape(child, defs: &defs)
                case "p:pic": body += renderPicture(child)
                case "p:graphicFrame": body += renderGraphicFrame(child, defs: &defs)
                default: break
                }
            }
        }

        return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(pixelWidth)\" height=\"\(pxH)\" "
            + "viewBox=\"0 0 \(w) \(h)\"><defs>\(defs)</defs>\(body)</svg>"
    }

    // MARK: - Shapes

    private func renderShape(_ sp: XML.Element, defs: inout String) -> String {
        guard let spPr = sp.firstChild(named: "p:spPr") else { return "" }
        let f = frame(of: spPr)
        var out = ""
        let prst = spPr.firstChild(named: "a:prstGeom")?[attribute: "prst"] ?? "rect"
        let fill = paint(for: spPr, box: f, defs: &defs)
        let stroke = strokeAttrs(spPr)
        if let fill { out += geometry(prst, f, fill: fill, stroke: stroke) }
        else if !stroke.isEmpty { out += geometry(prst, f, fill: "none", stroke: stroke) }
        if let txBody = sp.firstChild(named: "p:txBody") { out += renderText(txBody, box: f) }
        return out
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

    // MARK: - Text (measured when the typeface is registered; else
    // approximate: one line per paragraph)

    private func renderText(_ txBody: XML.Element, box f: (Int, Int, Int, Int)) -> String {
        let (x, y, w, h) = f
        let bodyPr = txBody.firstChild(named: "a:bodyPr")
        func inset(_ name: String, _ fallback: Int) -> Int {
            bodyPr?[attribute: name].flatMap { Int($0) } ?? fallback
        }
        let contentX = x + inset("lIns", 91_440)
        let contentW = Swift.max(0, w - inset("lIns", 91_440) - inset("rIns", 91_440))
        let paragraphs = txBody.children(named: "a:p")
        // Stack paragraphs from the top with a line height per font size.
        var out = ""
        var cursorY = y
        for p in paragraphs {
            let runs = p.children(named: "a:r")
            let text = runs.compactMap { $0.firstChild(named: "a:t")?.textContent }.joined()
            guard !text.isEmpty else { cursorY += emuPerPoint * 18; continue }
            let rPr = runs.first?.firstChild(named: "a:rPr")
            let sizeEMU = (rPr?[attribute: "sz"].flatMap { Int($0) } ?? 1800) * emuPerPoint / 100
            let bold = rPr?[attribute: "b"] == "1"
            let color = rPr.flatMap { colorHex(in: $0.firstChild(named: "a:solidFill")) } ?? "#1A1A1A"
            let align = p.firstChild(named: "a:pPr")?[attribute: "algn"] ?? "l"
            let (anchorX, textAnchor) = align == "ctr" ? (x + w / 2, "middle")
                : align == "r" ? (x + w, "end") : (x, "start")

            let typeface = rPr?.firstChild(named: "a:latin")?[attribute: "typeface"]
            if runs.count == 1, let typeface, let metrics = fonts.metrics(for: typeface) {
                // Measured path: real word wrap and baseline placement —
                // single-run paragraphs only, since a mixed-size/font
                // paragraph measured at the first run's metrics would wrap
                // wrong; those keep the one-line approximation below.
                // (Left-aligned text starts at the body inset; the unmeasured
                // branch below keeps its historical `x` so existing output is
                // byte-identical for decks without registered fonts.)
                let lineX = textAnchor == "start" ? contentX : anchorX
                let sizePt = Double(sizeEMU) / Double(emuPerPoint)
                let lines = TextMeasurer(metrics).wrap(
                    text, pointSize: sizePt, width: Double(contentW) / Double(emuPerPoint))
                let lineH = Int((metrics.lineHeight(pointSize: sizePt) * Double(emuPerPoint)).rounded())
                let ascent = Int((metrics.ascent(pointSize: sizePt) * Double(emuPerPoint)).rounded())
                for line in lines {
                    out += "<text x=\"\(lineX)\" y=\"\(cursorY + ascent)\" font-size=\"\(sizeEMU)\" "
                        + "fill=\"\(color)\" text-anchor=\"\(textAnchor)\"\(bold ? " font-weight=\"bold\"" : "")>"
                        + escape(line) + "</text>"
                    cursorY += lineH
                }
            } else {
                cursorY += sizeEMU
                out += "<text x=\"\(anchorX)\" y=\"\(cursorY)\" font-size=\"\(sizeEMU)\" "
                    + "fill=\"\(color)\" text-anchor=\"\(textAnchor)\"\(bold ? " font-weight=\"bold\"" : "")>"
                    + escape(clip(text, width: w, sizeEMU: sizeEMU)) + "</text>"
                cursorY += sizeEMU / 3
            }
            _ = h
        }
        return out
    }

    /// Rough character clip so a long line doesn't overflow the thumbnail.
    private func clip(_ text: String, width: Int, sizeEMU: Int) -> String {
        let approxCharWidth = sizeEMU / 2
        guard approxCharWidth > 0 else { return text }
        let maxChars = Swift.max(1, width / approxCharWidth)
        return text.count <= maxChars ? text : String(text.prefix(Swift.max(1, maxChars - 1))) + "…"
    }

    // MARK: - Pictures

    private func renderPicture(_ pic: XML.Element) -> String {
        guard let spPr = pic.firstChild(named: "p:spPr") else { return "" }
        let (x, y, w, h) = frame(of: spPr)
        guard let rId = pic.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"],
              let rel = slidePart.rels.relationship(withId: rId) else { return "" }
        let target = PackURI.resolve(target: rel.target, relativeTo: slidePart.uri.baseURI)
        guard let media = package.parts[target] else { return "" }
        let ext = target.ext.lowercased()
        let mime = ext == "jpg" || ext == "jpeg" ? "image/jpeg" : ext == "gif" ? "image/gif" : "image/png"
        let data = media.blob.base64EncodedString()
        return "<image x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" "
            + "preserveAspectRatio=\"xMidYMid slice\" href=\"data:\(mime);base64,\(data)\"/>"
    }

    // MARK: - Tables / charts

    private func renderGraphicFrame(_ gf: XML.Element, defs: inout String) -> String {
        guard let xfrm = gf.firstChild(named: "p:xfrm"),
              let off = xfrm.firstChild(named: "a:off"), let ext = xfrm.firstChild(named: "a:ext") else { return "" }
        let x = intAttr(off, "x"), y = intAttr(off, "y")
        let w = intAttr(ext, "cx"), h = intAttr(ext, "cy")
        let uri = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?[attribute: "uri"] ?? ""
        if uri.hasSuffix("/table"),
           let tbl = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?.firstChild(named: "a:tbl") {
            return renderTable(tbl, x: x, y: y, defs: &defs)
        }
        // Charts (and anything else) render as a labeled placeholder.
        return box(x, y, w, h, fill: "#F2F2F2", stroke: " stroke=\"#CCCCCC\" stroke-width=\"6350\"")
            + "<text x=\"\(x + w / 2)\" y=\"\(y + h / 2)\" font-size=\"\(18 * emuPerPoint)\" fill=\"#999999\" "
            + "text-anchor=\"middle\">\(uri.hasSuffix("/chart") ? "[chart]" : "[object]")</text>"
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
            let pos = (Double(gs[attribute: "pos"].flatMap { Int($0) } ?? 0) / 1000).rounded() / 100
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
        if let srgb = container.firstChild(named: "a:srgbClr")?[attribute: "val"] { return "#" + srgb }
        if let raw = container.firstChild(named: "a:schemeClr")?[attribute: "val"],
           let scheme = SchemeColor(rawValue: raw), let color = theme.resolve(scheme) { return "#" + color.hex }
        return nil
    }

    private func strokeAttrs(_ spPr: XML.Element) -> String {
        guard let ln = spPr.firstChild(named: "a:ln"), ln.firstChild(named: "a:noFill") == nil,
              let color = colorHex(in: ln.firstChild(named: "a:solidFill")) else { return "" }
        let width = ln[attribute: "w"].flatMap { Int($0) } ?? 12700
        return " stroke=\"\(color)\" stroke-width=\"\(width)\""
    }

    private func frame(of spPr: XML.Element) -> (Int, Int, Int, Int) {
        guard let xfrm = spPr.firstChild(named: "a:xfrm"),
              let off = xfrm.firstChild(named: "a:off"), let ext = xfrm.firstChild(named: "a:ext") else {
            return (0, 0, 0, 0)
        }
        return (intAttr(off, "x"), intAttr(off, "y"), intAttr(ext, "cx"), intAttr(ext, "cy"))
    }

    private func intAttr(_ e: XML.Element, _ name: String) -> Int { e[attribute: name].flatMap { Int($0) } ?? 0 }

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

public extension Presentation {
    /// Render one slide to a self-contained SVG string (thumbnails / visual diff).
    func renderSVG(slideAt index: Int, pixelWidth: Int = 1280) throws -> String {
        try SVGRenderer(slidePart: slides[index].part, slideSize: slideSize,
                        theme: theme, package: package, fonts: fonts).render(pixelWidth: pixelWidth)
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
