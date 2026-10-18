import Foundation
import Rostrum

/// Headed cards, open columns, or ordered rows. These compositions keep text
/// editable and use caller typography; they never truncate or silently shrink.
public enum PanelKind: String, Sendable, CaseIterable { case cards, threeColumn, numberedSteps }

public enum PanelLayout {
    public static func frames(kind: PanelKind, count: Int, in region: Rect, scale: Double = 1) throws -> [Rect] {
        let allowed = kind == .threeColumn ? 3...3 : 2...4
        guard allowed.contains(count), scale.isFinite, scale > 0,
              region.width > .zero, region.height > .zero else {
            throw LayoutError.cannotFit("\(kind.rawValue) needs \(allowed.lowerBound)–\(allowed.upperBound) panels and a positive region.")
        }
        let gap = 18 * scale
        let columns = kind == .threeColumn ? 3 : (kind == .numberedSteps ? 1 : 2)
        let rows = (count + columns - 1) / columns
        let width = (region.width.points - Double(columns - 1) * gap) / Double(columns)
        let height = (region.height.points - Double(rows - 1) * gap) / Double(rows)
        guard width >= 96 * scale, height >= 48 * scale else {
            throw LayoutError.cannotFit("The content region is too small for readable panels.")
        }
        return (0..<count).map { index in
            Rect(x: region.x + .points(Double(index % columns) * (width + gap)),
                 y: region.y + .points(Double(index / columns) * (height + gap)),
                 width: .points(width), height: .points(height))
        }
    }

    private struct TextPlan {
        let cell: Rect
        let heading: Rect
        let detail: Rect
    }
    private static func typography(_ style: DeckStyle, scale: Double) -> DeckStyle {
        var result = style
        result.type = result.type.overriding(.heading) { $0.sizePt = 22 * scale; $0.lineHeight = 1.1 }
            .overriding(.body) { $0.sizePt = 18 * scale; $0.lineHeight = 1.1 }
        return result
    }
    private static func plan(kind: PanelKind, items: [StructuredItem], in region: Rect,
                             style: DeckStyle, engine: TemplateLayoutEngine) throws -> [TextPlan] {
        let scale = engine.objectScale, inset = (kind == .numberedSteps ? 8.0 : 12.0) * engine.objectScale
        let local = typography(style, scale: scale)
        let cells = try frames(kind: kind, count: items.count, in: region, scale: scale)
        return try zip(items, cells).map { item, cell in
            let numberSpace = kind == .numberedSteps ? 44 * scale : 0
            let width = cell.width.points - 2 * inset - numberSpace
            let sideBySide = kind == .numberedSteps && !item.detail.isEmpty
            let headingWidth = sideBySide ? width * 0.30 : width
            let detailWidth = sideBySide ? width - headingWidth - 16 * scale : width
            let hh = engine.measuredHeight(item.heading, style: local.type(.heading), width: headingWidth)
            let dh = item.detail.isEmpty ? 0 : engine.measuredHeight(item.detail, style: local.type(.body), width: detailWidth)
            let gap = dh > 0 ? 8 * scale : 0
            let needed = sideBySide ? max(hh, dh) : hh + gap + dh
            guard !item.heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  width > 0, hh.isFinite, dh.isFinite, needed <= cell.height.points - 2 * inset else {
                throw LayoutError.cannotFit("Panel ‘\(item.heading.prefix(80))’ needs a roomier layout or less content.")
            }
            let heading = Rect(x: cell.x + .points(inset + numberSpace),
                y: cell.y + .points(sideBySide ? (cell.height.points - hh) / 2 : inset),
                width: .points(headingWidth), height: .points(hh))
            let detail = Rect(x: sideBySide ? heading.maxX + .points(16 * scale) : heading.x,
                y: sideBySide ? cell.y + .points((cell.height.points - dh) / 2) : heading.maxY + .points(gap),
                width: .points(detailWidth), height: .points(dh))
            return TextPlan(cell: cell, heading: heading, detail: detail)
        }
    }

    public static func validate(kind: PanelKind, items: [StructuredItem], in region: Rect,
                                style: DeckStyle, engine: TemplateLayoutEngine) throws {
        _ = try plan(kind: kind, items: items, in: region, style: style, engine: engine)
    }

    @discardableResult
    public static func compose(kind: PanelKind, items: [StructuredItem], in region: Rect,
                               on slide: Slide, style: DeckStyle, engine: TemplateLayoutEngine) throws -> Shape {
        // Complete preflight before writing even the boundary shape.
        let plans = try plan(kind: kind, items: items, in: region, style: style, engine: engine)
        let scale = engine.objectScale, local = typography(style, scale: scale)
        let boundary = try slide.shapes.addShape(.rectangle, frame: region, fill: .none)
        for (index, pair) in zip(items, plans).enumerated() {
            let (item, plan) = pair, accent = style.accent(index + 1)
            if kind == .cards {
                _ = try slide.shapes.addShape(.rectangle, frame: plan.cell,
                    fill: .solid(style.background), line: Line(color: accent.lighten(0.6), width: .points(scale)))
            }
            if kind == .numberedSteps {
                let badge = Rect(x: plan.cell.x + .points(10 * scale), y: plan.cell.y + (plan.cell.height - .points(32 * scale)) / 2,
                    width: .points(32 * scale), height: .points(32 * scale))
                _ = try slide.shapes.addShape(.ellipse, frame: badge, fill: .solid(accent))
                _ = try slide.shapes.addText(String(index + 1), in: badge, role: .body, style: local,
                    color: Color.bestTextColor(on: accent), align: .center, anchor: .middle)
            } else {
                let rule = Rect(x: plan.cell.x, y: plan.cell.y, width: plan.cell.width, height: .points(3 * scale))
                _ = try slide.shapes.addShape(.rectangle, frame: rule, fill: .solid(accent))
            }
            _ = try slide.shapes.addText(item.heading, in: plan.heading, role: .heading, style: local, anchor: .top)
            if !item.detail.isEmpty {
                _ = try slide.shapes.addText(item.detail, in: plan.detail, role: .body, style: local, anchor: .top)
            }
        }
        return boundary
    }
}
