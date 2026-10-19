import Foundation

/// Read-only, operation-local chart text preparation. Coordinates are EMU.
/// Bounds are on complete labels and retained measurements, not source XML.
final class ChartTextMeasurer {
    struct Style: Hashable {
        let face: FontFaceKey
        let size: Int
        var kerning = true
    }
    struct Line {
        let text: String
        let width: Double
    }
    struct Block {
        let lines: [Line]
        let ascent: Double
        let lineHeight: Double
        let width: Double
        let height: Double
    }
    private struct Key: Hashable {
        let text: String
        let style: Style
    }
    private let fonts: FontLibrary
    private let report: (FidelityIssueCode, FidelityImpact, String) -> Void
    private var widths: [Key: Double] = [:]
    private var retainedBytes = 0

    init(fonts: FontLibrary, report: @escaping (FidelityIssueCode, FidelityImpact, String) -> Void) {
        self.fonts = fonts
        self.report = report
    }

    func width(_ text: String, style: Style) -> Double {
        let key = Key(text: text, style: style)
        if let value = widths[key] { return value }
        let selected = fonts.previewFace(for: style.face) ?? style.face
        let size = Double(style.size) / Double(EMU.perPoint)
        let value: Double
        if let metrics = fonts.metrics(for: selected) {
            let shaped = TextShaper(metrics).shape(text, pointSize: size, kerning: style.kerning)
            for issue in shaped.diagnostics {
                if case .missingGlyph(let scalar) = issue {
                    report(.missingGlyph, .missingResource,
                           "Chart font \(selected.family) has no glyph for U+\(String(scalar, radix: 16, uppercase: true)).")
                } else {
                    report(.unsupportedShaping, .approximation,
                           "Chart text shaping is approximated: \(issue).")
                }
            }
            let native = style.kerning ? fonts.previewAdvance?(text, selected.family, size, style.face.bold, style.face.italic) : nil
            let measured = native.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } ?? shaped.width
            value = max(0, measured) * Double(EMU.perPoint)
        } else {
            report(.missingFont, .missingResource,
                   "Chart text uses estimated metrics because \(style.face.family) is not registered.")
            value = Double(text.count) * Double(style.size) * 0.5
        }
        if widths.count < 2048, text.utf8.count <= 262_144 - retainedBytes {
            widths[key] = value
            retainedBytes += text.utf8.count
        }
        return value
    }

    /// Greedy word wrapping followed by grapheme-safe splitting of a long word.
    /// A label that cannot fit is omitted by its caller with a concrete finding;
    /// it is never silently ellipsized or written back into the presentation.
    func block(_ text: String, style: Style, width limit: Double, maxLines: Int = 3) -> Block? {
        guard limit > 0, maxLines > 0 else { return nil }
        let characters = Array(text.prefix(1025))
        guard characters.count <= 1024 else {
            report(.chartApproximation, .omission, "Chart preview omits a label above its 1,024-character bound.")
            return nil
        }
        let metrics = fonts.metrics(for: fonts.previewFace(for: style.face) ?? style.face)
        let size = Double(style.size)
        let ascent = max(0, metrics?.ascent(pointSize: size) ?? size * 0.8)
        let descent = max(0, metrics?.descent(pointSize: size) ?? size * 0.2)
        let lineHeight = max(size * 1.2, metrics?.lineHeight(pointSize: size) ?? 0, ascent + descent)
        var lines: [Line] = []
        func append(_ string: String) -> Bool {
            guard lines.count < maxLines else { return false }
            lines.append(Line(text: string, width: width(string, style: style)))
            return true
        }
        // Preserve explicit line breaks; ordinary inter-word spaces are normalized.
        for paragraph in String(characters).replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            var pending = ""
            for word in paragraph.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init) {
                let joined = pending.isEmpty ? word : pending + " " + word
                if width(joined, style: style) <= limit {
                    pending = joined
                    continue
                }
                if !pending.isEmpty {
                    guard append(pending) else { return nil }
                    pending = ""
                }
                var remainder = Array(word)
                while !remainder.isEmpty {
                    if width(String(remainder), style: style) <= limit {
                        pending = String(remainder)
                        break
                    }
                    var low = 0, high = remainder.count
                    while low < high {
                        let mid = (low + high + 1) / 2
                        if width(String(remainder.prefix(mid)), style: style) <= limit { low = mid }
                        else { high = mid - 1 }
                    }
                    // Prefer natural boundaries to an emergency grapheme break,
                    // including a dash in a long compound category name.
                    let opportunities = Set(TextShaper.lineBreaks(in: String(remainder)).map(\.scalarOffset))
                    var scalarOffset = 0, preferred = 0
                    for i in 0..<low {
                        scalarOffset += remainder[i].unicodeScalars.count
                        if opportunities.contains(scalarOffset) || ["–", "—", "/"].contains(remainder[i]) { preferred = i + 1 }
                    }
                    if preferred > 0 { low = preferred }
                    else if remainder.contains("\u{00A0}") || remainder.contains("\u{2060}") { return nil }
                    guard low > 0, append(String(remainder.prefix(low))) else { return nil }
                    remainder.removeFirst(low)
                }
            }
            guard append(pending) else { return nil }
        }
        return Block(lines: lines, ascent: ascent, lineHeight: lineHeight,
                     width: lines.map(\.width).max() ?? 0,
                     height: ascent + descent + Double(max(0, lines.count - 1)) * lineHeight)
    }
}

struct ChartTextRect {
    var x: Double, y: Double, width: Double, height: Double
    var right: Double { x + width }
    var bottom: Double { y + height }
    func contains(_ rect: ChartTextRect) -> Bool {
        rect.x >= x - 0.01 && rect.y >= y - 0.01 && rect.right <= right + 0.01 && rect.bottom <= bottom + 0.01
    }
    func intersects(_ rect: ChartTextRect, gap: Double = 0) -> Bool {
        x < rect.right + gap && right + gap > rect.x && y < rect.bottom + gap && bottom + gap > rect.y
    }
}

/// At most 512 placements per chart. The fixed grid bounds intersection work on
/// dense charts and stores indices, not repeated strings or font resources.
final class ChartLabelPlacement {
    private let bounds: ChartTextRect
    private var rectangles: [ChartTextRect] = []
    private var buckets: [Int: [Int]] = [:]
    init(bounds: ChartTextRect) { self.bounds = bounds }

    private func cells(_ rect: ChartTextRect) -> [Int] {
        let gap = Double(EMU.perPoint)
        func index(_ value: Double, origin: Double, length: Double) -> Int {
            Int(max(0, min(15, floor((value - origin) / max(1, length) * 16))))
        }
        let left = index(rect.x - gap, origin: bounds.x, length: bounds.width)
        let right = index(rect.right + gap, origin: bounds.x, length: bounds.width)
        let top = index(rect.y - gap, origin: bounds.y, length: bounds.height)
        let bottom = index(rect.bottom + gap, origin: bounds.y, length: bounds.height)
        return (top...bottom).flatMap { y in (left...right).map { y * 16 + $0 } }
    }

    func place(_ candidates: [ChartTextRect]) -> ChartTextRect? {
        guard rectangles.count < 512 else { return nil }
        for rect in candidates where bounds.contains(rect) {
            let keys = cells(rect)
            let seen = Set(keys.flatMap { buckets[$0] ?? [] })
            guard !seen.contains(where: { rectangles[$0].intersects(rect, gap: Double(EMU.perPoint)) }) else { continue }
            let index = rectangles.count
            rectangles.append(rect)
            for key in keys { buckets[key, default: []].append(index) }
            return rect
        }
        return nil
    }
}
