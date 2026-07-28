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

    private let emuPerPoint = 12700

    func render(pixelWidth: Int) throws -> String {
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

    // MARK: - Text (wrapped on real metrics when the typeface is registered,
    // else on a character-width estimate)

    private func renderText(_ txBody: XML.Element, box f: (Int, Int, Int, Int)) -> String {
        let (x, y, w, h) = f
        let bodyPr = txBody.firstChild(named: "a:bodyPr")
        // Bounded like every other coordinate here: `x + inset(…)` traps.
        func inset(_ name: String, _ fallback: Int) -> Int {
            bodyPr?.coordinate(name) ?? fallback
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
            // ST_TextFontSize is 1pt–4000pt in hundredths. The file can say
            // anything, and `sz * 12700` on a large Int is an overflow crash.
            let sizeHundredths = min(max(rPr?[attribute: "sz"].flatMap { Int($0) } ?? 1800, 100),
                                     400_000)
            let sizeEMU = sizeHundredths * emuPerPoint / 100
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
                // wrong; those take the estimated wrap below.
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
                // No metrics for this typeface (or a mixed paragraph): estimate
                // a character width from the font size and wrap on it.
                //
                // Wrapping rather than truncating. This branch used to emit one
                // line and drop the rest behind an ellipsis, which silently
                // rewrote a headline — "Why Native Rendering Wins" came out
                // "Why Native Render…" — in a picture whose whole job is to
                // show what the deck says. The estimate is the same one; only
                // the overflow behaviour changed, so a paragraph that already
                // fit on one line emits byte-identical markup. That is a
                // per-paragraph guarantee, not per-shape: `cursorY` accumulates
                // down the body, so once any paragraph wraps, every paragraph
                // after it in the same shape shifts down.
                for line in wrapEstimated(text, width: w, sizeEMU: sizeEMU) {
                    cursorY += sizeEMU
                    out += "<text x=\"\(anchorX)\" y=\"\(cursorY)\" font-size=\"\(sizeEMU)\" "
                        + "fill=\"\(color)\" text-anchor=\"\(textAnchor)\"\(bold ? " font-weight=\"bold\"" : "")>"
                        + escape(line) + "</text>"
                    cursorY += sizeEMU / 3
                }
            }
            _ = h
        }
        return out
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
        if uri.hasSuffix("/chart"), let plot = renderChart(gf, x: x, y: y, w: w, h: h) {
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
            + "<text x=\"\(x + w / 2)\" y=\"\(y + h / 2)\" font-size=\"\(18 * emuPerPoint)\" fill=\"#999999\" "
            + "text-anchor=\"middle\">\(escape(label))</text>"
    }

    // MARK: - Charts

    /// Plot a chart frame, or nil when this chart is not one of the kinds
    /// drawn here (combo, scatter, radar…) and the placeholder should stand.
    ///
    /// The point is a thumbnail that shows the *shape* of the data — is it
    /// rising, is one bar dominant — not a second chart engine. PowerPoint
    /// owns the real rendering; a preview that pretended otherwise would
    /// invite comparisons it cannot win.
    private func renderChart(_ gf: XML.Element, x: Int, y: Int, w: Int, h: Int) -> String? {
        guard w > 0, h > 0,
              let rId = gf.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
                  .firstChild(named: "c:chart")?[attribute: "r:id"],
              let rel = slidePart.rels.relationship(withId: rId),
              let part = try? package.part(
                  at: PackURI.resolve(target: rel.target, relativeTo: slidePart.uri.baseURI))
        else { return nil }

        let chart = Chart(part: part, package: package)
        guard let kind = chart.plotType, !chart.isCombo else { return nil }
        let series = chart.series
        guard !series.isEmpty else { return nil }

        // Inset a margin so bars don't touch the frame edge.
        let pad = Swift.min(w, h) / 12
        let plotX = x + pad, plotY = y + pad
        let plotW = Swift.max(1, w - 2 * pad), plotH = Swift.max(1, h - 2 * pad)

        let palette = (1...6).map { theme.accent($0).map { "#" + $0.hex } ?? "#4472C4" }
        func color(_ index: Int) -> String { palette[index % palette.count] }

        switch kind {
        case "barChart": return bars(series, plotX, plotY, plotW, plotH, color)
        case "lineChart": return lines(series, plotX, plotY, plotW, plotH, color)
        case "pieChart", "doughnutChart":
            return pie(series[0], plotX, plotY, plotW, plotH, color)
        default: return nil
        }
    }

    /// The largest magnitude across every plotted value, or nil when nothing
    /// finite was plotted. Values come out of a file, so `NaN`, infinity and
    /// absurd magnitudes all have to survive being scaled against.
    private func plotScale(_ series: [ChartData.Series]) -> Double? {
        let peak = series.flatMap(\.values).compactMap { $0 }
            .filter { $0.isFinite }
            .map { Swift.abs($0) }
            .max()
        guard let peak, peak > 0, peak < 1e300 else { return nil }
        return peak
    }

    /// A value's height in EMU, clamped into the plot. `Int(_: Double)` traps
    /// on a non-finite or out-of-range double, and every value here came from
    /// a file.
    private func scaled(_ value: Double?, peak: Double, extent: Int) -> Int {
        guard let value, value.isFinite else { return 0 }
        let fraction = Swift.min(Swift.max(Swift.abs(value) / peak, 0), 1)
        return Int((fraction * Double(extent)).rounded())
    }

    private func bars(_ series: [ChartData.Series], _ x: Int, _ y: Int, _ w: Int, _ h: Int,
                      _ color: (Int) -> String) -> String? {
        guard let peak = plotScale(series) else { return nil }
        let categories = series.map(\.values.count).max() ?? 0
        guard categories > 0 else { return nil }

        let slot = Swift.max(1, w / categories)
        let barW = Swift.max(1, (slot * 4 / 5) / series.count)
        var out = ""
        for (s, one) in series.enumerated() {
            for (c, value) in one.values.enumerated() {
                let height = scaled(value, peak: peak, extent: h)
                guard height > 0 else { continue }
                let bx = x + c * slot + slot / 10 + s * barW
                out += box(bx, y + h - height, barW, height, fill: color(s))
            }
        }
        // The baseline, so an empty-looking plot still reads as a chart.
        return out + box(x, y + h, w, 6350, fill: "#BFBFBF")
    }

    private func lines(_ series: [ChartData.Series], _ x: Int, _ y: Int, _ w: Int, _ h: Int,
                       _ color: (Int) -> String) -> String? {
        guard let peak = plotScale(series) else { return nil }
        var out = box(x, y + h, w, 6350, fill: "#BFBFBF")
        for (s, one) in series.enumerated() {
            let points = one.values.count
            guard points > 1 else { continue }
            let step = w / (points - 1)
            let coordinates = one.values.enumerated().map { index, value in
                "\(x + index * step),\(y + h - scaled(value, peak: peak, extent: h))"
            }
            out += "<polyline points=\"\(coordinates.joined(separator: " "))\" fill=\"none\" "
                + "stroke=\"\(color(s))\" stroke-width=\"19050\"/>"
        }
        return out
    }

    /// Slices as SVG arcs. One series only — a pie plots categories, and a
    /// second series would be a second pie PowerPoint does not draw either.
    private func pie(_ series: ChartData.Series, _ x: Int, _ y: Int, _ w: Int, _ h: Int,
                     _ color: (Int) -> String) -> String? {
        let values = series.values.compactMap { $0 }.filter { $0.isFinite && $0 > 0 }
        let total = values.reduce(0, +)
        guard total > 0, total.isFinite else { return nil }

        let radius = Swift.min(w, h) / 2
        guard radius > 0 else { return nil }
        let cx = x + w / 2, cy = y + h / 2
        var out = ""
        var startAngle = -Double.pi / 2      // 12 o'clock, as PowerPoint starts
        for (index, value) in values.enumerated() {
            let sweep = value / total * 2 * Double.pi
            let end = startAngle + sweep
            // A full circle cannot be expressed as one arc — its start and end
            // points coincide, so the path degenerates to nothing.
            if values.count == 1 {
                out += "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(radius)\" fill=\"\(color(0))\"/>"
                break
            }
            let x1 = cx + Int((cos(startAngle) * Double(radius)).rounded())
            let y1 = cy + Int((sin(startAngle) * Double(radius)).rounded())
            let x2 = cx + Int((cos(end) * Double(radius)).rounded())
            let y2 = cy + Int((sin(end) * Double(radius)).rounded())
            let large = sweep > Double.pi ? 1 : 0
            out += "<path d=\"M \(cx) \(cy) L \(x1) \(y1) A \(radius) \(radius) 0 \(large) 1 "
                + "\(x2) \(y2) Z\" fill=\"\(color(index))\"/>"
            startAngle = end
        }
        return out
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
