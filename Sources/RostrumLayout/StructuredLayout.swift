import Foundation
import Rostrum

/// Semantic content stays editable. Coordinates are confined to a template's
/// content region; masters, layouts and their artwork are never rewritten.
public struct StructuredItem: Sendable, Equatable {
    public let heading: String
    public let detail: String
    public init(_ heading: String, detail: String = "") { self.heading = heading; self.detail = detail }
}

public enum StructuredKind: String, Sendable { case metrics, process, cycle, pyramid, timeline, quadrant, bands }

public enum StructuredLayout {
    public static func frames(kind: StructuredKind, count: Int, in region: Rect, scale: Double = 1) throws -> [Rect] {
        guard count > 0, count <= 12 else { throw LayoutError.cannotFit("Structured content needs 1–12 items.") }
        let gap = 16.0 * scale, w = region.width.points, h = region.height.points
        func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Rect {
            Rect(x: region.x + .points(x), y: region.y + .points(y), width: .points(width), height: .points(height))
        }
        if kind == .cycle {
            let columns = count == 4 ? 2 : min(3, count), rows = Int(ceil(Double(count) / Double(columns)))
            let cw = (w - Double(columns - 1) * gap) / Double(columns)
            let ch = (h - Double(rows - 1) * gap) / Double(rows)
            // A serpentine cycle remains legible with long labels and has explicit
            // ordered arrows; circular arrangements otherwise waste text width.
            return (0..<count).map { i in
                let row = i / columns, col = row % 2 == 0 ? i % columns : columns - 1 - i % columns
                return rect(Double(col) * (cw + gap), Double(row) * (ch + gap), cw, ch)
            }
        }
        if kind == .bands || kind == .pyramid {
            let ch = (h - Double(count - 1) * gap) / Double(count)
            return (0..<count).map { i in
                let width = kind == .pyramid ? w * (0.55 + 0.45 * Double(i + 1) / Double(count)) : w
                return rect((w - width) / 2, Double(i) * (ch + gap), width, ch)
            }
        }
        let columns = kind == .quadrant ? 2 : min(count, count > 4 ? 3 : count)
        let rows = Int(ceil(Double(count) / Double(columns)))
        let cw = (w - Double(columns - 1) * gap) / Double(columns)
        let ch = (h - Double(rows - 1) * gap) / Double(rows)
        guard cw >= 72 * scale, ch >= 48 * scale else { throw LayoutError.cannotFit("The template content region is too small for this structure.") }
        return (0..<count).map { i in
            let row = i / columns
            let col = [.process, .timeline].contains(kind) && row % 2 == 1 ? columns - 1 - i % columns : i % columns
            return rect(Double(col) * (cw + gap), Double(row) * (ch + gap), cw, ch)
        }
    }

    public static func validate(kind: StructuredKind, items: [StructuredItem], in region: Rect,
                                style: DeckStyle, engine: TemplateLayoutEngine) throws {
        _ = try preflight(kind: kind, items: items, in: region, style: style, engine: engine)
    }

    private static func preflight(kind: StructuredKind, items: [StructuredItem], in region: Rect,
                                  style: DeckStyle, engine: TemplateLayoutEngine) throws -> [(Double, Double, Double)] {
        let scale = engine.objectScale
        let availableRegion = Rect(x: region.x, y: region.y, width: region.width,
            height: region.height - .points(kind == .cycle ? 28 * scale : 0))
        let cells = try frames(kind: kind, count: items.count, in: availableRegion, scale: scale)
        // Preflight all text before mutating the slide. No truncation or silent
        // fallback to paragraphs when a semantic structure cannot fit.
        var typography: [(Double, Double, Double)] = []
        for (item, cell) in zip(items, cells) {
            let width = cell.width.points - 24 * scale, available = cell.height.points - 24 * scale
            var hs = style.type(kind == .metrics ? .stat : .heading)
            var ds = style.type(.body)
            hs.sizePt = (kind == .metrics ? 40 : 24) * engine.objectScale; hs.lineHeight = 1.05
            ds.sizePt = 18 * engine.objectScale; ds.lineHeight = 1.1
            var hh = engine.measuredHeight(item.heading, style: hs, width: width)
            let dh = item.detail.isEmpty ? 0 : engine.measuredHeight(item.detail, style: ds, width: width) + 10 * scale
            while hh + dh > available && hs.sizePt > 20 * engine.objectScale {
                hs.sizePt -= 1; hh = engine.measuredHeight(item.heading, style: hs, width: width)
            }
            guard width > 0, hh + dh <= available else { throw LayoutError.cannotFit("Structured item ‘\(item.heading)’ needs a roomier template layout.") }
            typography.append((hs.sizePt, hh, dh))
        }
        return typography
    }

    @discardableResult
    public static func compose(kind: StructuredKind, items: [StructuredItem], in region: Rect,
                               on slide: Slide, style: DeckStyle, engine: TemplateLayoutEngine) throws -> Shape {
        let scale = engine.objectScale
        let typography = try preflight(kind: kind, items: items, in: region, style: style, engine: engine)
        let originalCells = try frames(kind: kind, count: items.count, in: region, scale: scale)
        let rows = Set(originalCells.map { $0.y.points }).count
        let rowHeight = max(64 * scale, typography.map { $0.1 + $0.2 + 24 * scale }.max() ?? 64 * scale)
        let compactHeight = min(region.height.points, rowHeight * Double(rows) + 16 * scale * Double(rows - 1))
        let loopSpace = kind == .cycle ? 28.0 * scale : 0
        guard compactHeight + loopSpace <= region.height.points else {
            throw LayoutError.cannotFit("The cycle needs space for its return path.")
        }
        let compact = Rect(x: region.x, y: region.y + .points((region.height.points - compactHeight - loopSpace) / 2),
                           width: region.width, height: .points(compactHeight))
        let cells = try frames(kind: kind, count: items.count, in: compact, scale: scale)
        let boundary = try slide.shapes.addShape(.rectangle, frame: region, fill: .none)
        for (i, pair) in zip(items, cells).enumerated() {
            let (item, cell) = pair, (size, hh, dh) = typography[i]
            let fill = style.background
            _ = try slide.shapes.addShape(.rectangle, frame: cell, fill: .solid(fill),
                                          line: Line(color: style.accent(1).lighten(0.6), width: .points(0.5 * scale)))
            let stripe = Rect(x: cell.x, y: cell.y, width: .points(3 * scale), height: cell.height)
            _ = try slide.shapes.addShape(.rectangle, frame: stripe, fill: .solid(style.accent(1)))
            var local = style
            local.type = local.type.overriding(.heading) { $0.sizePt = size; $0.lineHeight = 1.05 }
                .overriding(.body) { $0.sizePt = 18 * engine.objectScale; $0.lineHeight = 1.1 }
            let head = Rect(x: cell.x + .points(12 * scale), y: cell.y + .points(12 * scale), width: cell.width - .points(24 * scale), height: .points(hh))
            _ = try slide.shapes.addText(item.heading, in: head, role: .heading, style: local)
            if dh > 0 {
                let detail = Rect(x: head.x, y: head.maxY + .points(10 * scale), width: head.width, height: .points(dh - 10 * scale))
                _ = try slide.shapes.addText(item.detail, in: detail, role: .body, style: local)
            }
            if [.process, .timeline, .cycle].contains(kind), i + 1 < cells.count {
                let next = cells[(i + 1) % cells.count]
                let arrow = next.y == cell.y ? (next.x > cell.x ? "→" : "←") : (next.y > cell.y ? "↓" : "↑")
                let x = next.y == cell.y ? min(cell.maxX.points, next.maxX.points) : cell.x.points + cell.width.points / 2 - 8 * scale
                let y = next.y == cell.y ? cell.y.points + cell.height.points / 2 - 12 * scale : min(cell.maxY.points, next.maxY.points)
                let box = Rect(x: .points(x), y: .points(y), width: .points(16 * scale), height: .points(next.y == cell.y ? 24 * scale : 16 * scale))
                var arrows = style; arrows.type = arrows.type.overriding(.body) { $0.sizePt = 12 * scale; $0.lineHeight = 1 }
                _ = try slide.shapes.addText(arrow, in: box, role: .body, style: arrows, align: .center)
            }
        }
        if kind == .cycle, let first = cells.first, let last = cells.last, cells.count > 1,
           first.x == last.x, first.y < last.y {
            var arrows = style
            arrows.type = arrows.type.overriding(.body) { $0.sizePt = 12 * scale; $0.lineHeight = 1 }
            _ = try slide.shapes.addText("↑", in: Rect(x: first.x + first.width / 2 - .points(8 * scale),
                y: first.maxY, width: .points(16 * scale), height: .points(16 * scale)), role: .body, style: arrows, align: .center)
        }
        if kind == .cycle {
            var local = style
            local.type = local.type.overriding(.body) { $0.sizePt = 14 * scale }
            _ = try slide.shapes.addText("Repeat cycle",
                in: Rect(x: compact.x, y: compact.maxY + .points(6 * scale), width: compact.width, height: .points(22 * scale)),
                role: .body, style: local, align: .center)
        }
        return boundary
    }
}
