import Foundation

/// Rich paragraph layout in points. Keeps run boundaries through wrapping rather
/// than flattening the paragraph to the first run's style. Font advances are
/// portable metrics when registered, otherwise a bounded half-em estimate.
struct SVGRichText {
    let theme: Theme
    let fonts: FontLibrary
    let slideNumber: Int

    static func needsLayout(_ body: XML.Element, inherited: [XML.Element]) -> Bool {
        let names: Set<String> = ["a:br", "a:buChar", "a:buAutoNum", "a:lnSpc", "a:spcBef", "a:spcAft", "a:normAutofit"]
        var nodes = [body] + inherited
        while let node = nodes.popLast() {
            if names.contains(node.name) { return true }
            if node.name == "a:p", node.children(named: "a:r").count + node.children(named: "a:fld").count > 1 { return true }
            if ["i", "u", "strike", "baseline", "spc", "marL", "indent"].contains(where: { node[attribute: $0] != nil }) { return true }
            nodes += node.childElements
        }
        return false
    }

    private struct Style: Equatable {
        var size: Double, face: String, color: String, bold: Bool, italic: Bool
        var decoration: String, shift: Double, tracking: Double
        var xml: String {
            "font-size=\"\(size)\" font-family=\"\(SVGRichText.escape(face)), sans-serif\" fill=\"\(color)\""
                + (bold ? " font-weight=\"bold\"" : "") + (italic ? " font-style=\"italic\"" : "")
                + (decoration.isEmpty ? "" : " text-decoration=\"\(decoration)\"")
                + (shift == 0 ? "" : " baseline-shift=\"\(shift)%\"")
                + (tracking == 0 ? "" : " letter-spacing=\"\(tracking)\"")
        }
    }
    private struct Piece { var text: String; var style: Style; var width: Double }
    private struct Line { var pieces: [Piece]; var x: Double; var baseline: Double; var bullet: String?; var bulletX: Double; var style: Style }

    func render(_ body: XML.Element, frame: (Int, Int, Int, Int), inherited: [XML.Element], reference: XML.Element?) -> String {
        let emu = 12_700.0
        let bp = body.firstChild(named: "a:bodyPr")
        let left = Double(bp?.coordinate("lIns") ?? 91_440) / emu
        let right = Double(bp?.coordinate("rIns") ?? 91_440) / emu
        let top = Double(bp?.coordinate("tIns") ?? 45_720) / emu
        let bottom = Double(bp?.coordinate("bIns") ?? 45_720) / emu
        let wraps = bp?[attribute: "wrap"] != "none"
        let width = max(0, Double(frame.2) / emu - left - right)
        let height = max(0, Double(frame.3) / emu - top - bottom)
        let scale = Double(bp?.firstChild(named: "a:normAutofit")?.boundedInt("fontScale", in: 1...100_000) ?? 100_000) / 100_000
        let reduction = Double(bp?.firstChild(named: "a:normAutofit")?.boundedInt("lnSpcReduction", in: 0...100_000) ?? 0) / 100_000
        var lines: [Line] = [], y = 0.0, counters: [Int: Int] = [:]
        for p in body.children(named: "a:p") {
            let direct = p.firstChild(named: "a:pPr")
            let level = direct?.boundedInt("lvl", in: 0...8) ?? 0
            let lists = inherited + [body.firstChild(named: "a:lstStyle")].compactMap { $0 }
            let paragraphSources = lists.flatMap { [$0.firstChild(named: "a:defPPr"), $0.firstChild(named: "a:lvl\(level + 1)pPr")] }
            let paragraph = Self.merge(paragraphSources + [direct])
            let inheritedRuns = inherited.flatMap { [$0.firstChild(named: "a:defPPr")?.firstChild(named: "a:defRPr"), $0.firstChild(named: "a:lvl\(level + 1)pPr")?.firstChild(named: "a:defRPr")] }
            let local = body.firstChild(named: "a:lstStyle")
            let ref = XML.Element("a:defRPr")
            if let color = reference?.childElements.first(where: { SVGPaint.colorElements.contains($0.name) }) {
                ref.appendElement(XML.Element("a:solidFill", children: [.element(color.deepCopy())]))
            }
            if let idx = reference?[attribute: "idx"], ["major", "minor"].contains(idx) {
                ref.appendElement(XML.Element("a:latin", attributes: [("typeface", idx == "major" ? "+mj-lt" : "+mn-lt")]))
            }
            let defaults = Self.merge(inheritedRuns + [ref, local?.firstChild(named: "a:defPPr")?.firstChild(named: "a:defRPr"), local?.firstChild(named: "a:lvl\(level + 1)pPr")?.firstChild(named: "a:defRPr"), direct?.firstChild(named: "a:defRPr")])
            let base = style(defaults, scale: scale)
            let margin = Double(paragraph.coordinate("marL") ?? 0) / emu
            let indent = Double(paragraph.coordinate("indent") ?? 0) / emu
            let marginR = Double(paragraph.coordinate("marR") ?? 0) / emu
            let available = max(0.1, width - margin - marginR)
            var bullet: String?
            if paragraph.firstChild(named: "a:buNone") == nil {
                bullet = paragraph.firstChild(named: "a:buChar")?[attribute: "char"]
                if let auto = paragraph.firstChild(named: "a:buAutoNum") {
                    let n = auto.boundedInt("startAt", in: 1...32767) ?? (counters[level] ?? 0) + 1
                    counters[level] = n
                    bullet = Self.number(n, type: auto[attribute: "type"] ?? "arabicPeriod")
                }
            }
            y += spacing(paragraph.firstChild(named: "a:spcBef"), default: 0, size: base.size)
            var chunks: [Piece?] = [], inputTruncated = false
            var word: [Piece] = []
            func flushWord() { chunks += word.map(Optional.some); word.removeAll(keepingCapacity: true) }
            // Nil marks a hard line break. Whitespace pieces delimit words; run
            // boundaries do not, so a bold fragment in a word stays attached.
            for child in p.childElements {
                if child.name == "a:br" { flushWord(); chunks.append(nil); continue }
                guard child.name == "a:r" || child.name == "a:fld" else { continue }
                let properties = Self.merge([defaults, child.firstChild(named: "a:rPr")])
                let format = style(properties, scale: scale)
                let text = child.name == "a:fld" && child[attribute: "type"] == "slidenum" ? String(slideNumber) : child.firstChild(named: "a:t")?.textContent ?? ""
                var token = ""
                func appendToken() { if !token.isEmpty { word.append(piece(token, format)); token = "" } }
                for (index, character) in text.prefix(100_001).enumerated() {
                    if index == 100_000 { inputTruncated = true; break }
                    if character == "\n" { appendToken(); flushWord(); chunks.append(nil) }
                    else if character.isWhitespace { appendToken(); flushWord(); chunks.append(piece(character == "\t" ? "    " : " ", format)) }
                    else { token.append(character) }
                }
                appendToken()
            }
            flushWord()
            var current: [Piece] = [], used = 0.0, paragraphLines = 0, truncated = false
            var firstLine = true
            func emit() {
                guard paragraphLines < 64 else { truncated = true; return }
                let size = max(base.size, current.map { $0.style.size * (1 + max(0, $0.style.shift) / 100) }.max() ?? base.size)
                let natural = max(size * 1.2, current.compactMap { fonts.metrics(for: $0.style.face)?.lineHeight(pointSize: $0.style.size) }.max() ?? 0)
                let advance = max(0.1, spacing(paragraph.firstChild(named: "a:lnSpc"), default: natural, size: natural) * (1 - reduction))
                let lead = firstLine && bullet == nil ? indent : 0
                let align = paragraph[attribute: "algn"] ?? "l"
                let remaining = wraps ? max(0, available - used) : available - used
                let delta = align == "ctr" ? remaining / 2 : align == "r" ? remaining : 0
                var merged: [Piece] = []
                for piece in current {
                    if let last = merged.last, last.style == piece.style {
                        merged[merged.count - 1].text += piece.text
                        merged[merged.count - 1].width += piece.width
                    } else { merged.append(piece) }
                }
                lines.append(Line(pieces: merged, x: left + margin + lead + delta, baseline: y + size,
                    bullet: firstLine ? bullet : nil, bulletX: left + margin + indent, style: base))
                y += advance; current = []; used = 0; firstLine = false; paragraphLines += 1
            }
            var i = 0
            while i < chunks.count && paragraphLines < 64 {
                guard let item = chunks[i] else { emit(); i += 1; continue }
                if item.text.allSatisfy(\.isWhitespace) {
                    if !current.isEmpty { current.append(item); used += item.width }
                    i += 1; continue
                }
                var end = i, wordWidth = 0.0
                while end < chunks.count, let next = chunks[end], !next.text.allSatisfy(\.isWhitespace) { wordWidth += next.width; end += 1 }
                var room = wraps ? max(0.1, available - (firstLine && bullet == nil ? indent : 0)) : Double.greatestFiniteMagnitude
                if used + wordWidth > room && !current.isEmpty { while current.last?.text.allSatisfy(\.isWhitespace) == true { used -= current.removeLast().width }; emit(); room = available }
                for j in i..<end {
                    guard let part = chunks[j] else { continue }
                    if wordWidth <= room { current.append(part); used += part.width }
                    else {
                        for char in part.text {
                            let one = piece(String(char), part.style)
                            if used + one.width > room && !current.isEmpty { emit(); room = available }
                            guard paragraphLines < 64 else { truncated = true; break }
                            current.append(one); used += one.width
                        }
                    }
                }
                i = end
            }
            if !current.isEmpty || paragraphLines == 0 { emit() }
            if i < chunks.count || truncated || inputTruncated, !lines.isEmpty { lines[lines.count - 1].pieces.append(piece("…", base)) }
            y += spacing(paragraph.firstChild(named: "a:spcAft"), default: 0, size: base.size)
        }
        let anchor = bp?[attribute: "anchor"] ?? "t"
        let shift = anchor == "ctr" ? (height - y) / 2 : anchor == "b" ? height - y : 0
        let originX = Double(frame.0), originY = Double(frame.1) + (top + shift) * emu
        return lines.map { line in
            let spans = line.pieces.map { "<tspan \($0.style.xml)>\(Self.escape($0.text))</tspan>" }.joined()
            let bullet = line.bullet.map { "<text x=\"\(line.bulletX)\" y=\"\(line.baseline)\" \(line.style.xml)>\(Self.escape($0))</text>" } ?? ""
            return "<g transform=\"translate(\(originX),\(originY)) scale(12700)\">\(bullet)<text x=\"\(line.x)\" y=\"\(line.baseline)\" xml:space=\"preserve\">\(spans)</text></g>"
        }.joined()
    }

    private func style(_ p: XML.Element, scale: Double) -> Style {
        let named = p.firstChild(named: "a:latin")?[attribute: "typeface"]
        let face = named == "+mj-lt" ? theme.majorFont : named == "+mn-lt" ? theme.minorFont : named
        let size = Double(p.boundedInt("sz", in: 100...400_000) ?? 1800) / 100 * scale
        var decoration: [String] = []
        if let u = p[attribute: "u"], u != "none" { decoration.append("underline") }
        if let s = p[attribute: "strike"], s != "noStrike" { decoration.append("line-through") }
        return Style(size: size, face: face ?? theme.minorFont ?? "sans-serif", color: SVGPaint.resolve(in: p.firstChild(named: "a:solidFill"), theme: theme)?.css ?? "#1A1A1A", bold: ["1", "true"].contains(p[attribute: "b"] ?? ""), italic: ["1", "true"].contains(p[attribute: "i"] ?? ""), decoration: decoration.joined(separator: " "), shift: Double(p.boundedInt("baseline", in: -100_000...100_000) ?? 0) / 1000, tracking: Double(p.boundedInt("spc", in: -400_000...400_000) ?? 0) / 100)
    }
    private func piece(_ text: String, _ s: Style) -> Piece {
        let native = fonts.previewAdvance?(text, s.face, s.size, s.bold, s.italic)
        let measured = native.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } ?? fonts.metrics(for: s.face)?.width(of: text, pointSize: s.size) ?? Double(text.count) * s.size / 2
        return Piece(text: text, style: s, width: max(0, measured + Double(max(0, text.count - 1)) * s.tracking))
    }
    private func spacing(_ p: XML.Element?, default fallback: Double, size: Double) -> Double {
        if let v = p?.firstChild(named: "a:spcPts")?.boundedInt("val", in: 0...20_000_000) { return Double(v) / 100 }
        if let v = p?.firstChild(named: "a:spcPct")?.boundedInt("val", in: 0...20_000_000) { return size * Double(v) / 100_000 }
        return fallback
    }
    private static func number(_ n: Int, type: String) -> String {
        var label = String(n)
        if type.hasPrefix("alpha") { var value = n; label = ""; while value > 0 { value -= 1; label = String(UnicodeScalar(97 + value % 26)!) + label; value /= 26 }; if type.contains("Uc") { label = label.uppercased() } }
        if type.contains("ParenBoth") { return "(\(label))" }
        return label + (type.contains("ParenR") ? ")" : ".")
    }
    private static func merge(_ sources: [XML.Element?]) -> XML.Element {
        let result = XML.Element("a:pPr")
        let bulletChoices = Set(["a:buNone", "a:buChar", "a:buAutoNum", "a:buBlip"])
        for source in sources.compactMap({ $0 }) {
            for a in source.attributes { result[attribute: a.name] = a.value }
            for child in source.childElements {
                result.children.removeAll { if case .element(let e) = $0 { return e.name == child.name || (bulletChoices.contains(child.name) && bulletChoices.contains(e.name)) }; return false }
                result.appendElement(child.deepCopy())
            }
        }
        return result
    }
    private static func escape(_ text: String) -> String { text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }
}
