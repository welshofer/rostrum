import Foundation

// Layout geometry — a deterministic, zero-dependency layer on top of `Rect`
// so decks stop hand-computing EMU. Everything here is pure integer/EMU math:
// no OOXML is produced, so there is zero round-trip risk. The rects returned
// flow into the existing `addShape(frame:)` / `addTextBox(frame:)` writers.

// MARK: - Canonical slide sizes

public extension Rect {
    /// The default 16:9 PowerPoint canvas, 13.333" × 7.5" (12,192,000 ×
    /// 6,858,000 EMU), anchored at the slide origin. Equals
    /// `EMU.inches(13.333333)` × `EMU.inches(7.5)`, matching the deck template.
    static let slide16x9 = Rect(x: .zero, y: .zero,
                                width: EMU(12_192_000), height: EMU(6_858_000))

    /// The legacy 4:3 canvas, 10" × 7.5", anchored at the slide origin.
    static let slide4x3 = Rect(x: .zero, y: .zero,
                               width: EMU(9_144_000), height: EMU(6_858_000))
}

public extension Presentation {
    /// The slide canvas as an origin-anchored `Rect`, using the deck's actual
    /// `slideSize`. Prefer this over `Rect.slide16x9` when the deck might be
    /// 4:3 or custom: `Grid(in: deck.bounds, columns: 12, margin: .inches(0.9))`.
    var bounds: Rect {
        let size = slideSize
        return Rect(x: .zero, y: .zero, width: size.width, height: size.height)
    }

    /// The content area after trimming a uniform safe-area margin off every
    /// edge of `bounds` — the region title-safe from projector overscan and a
    /// natural `in:` for a `Grid`. Defaults to a 5% inset (~0.67" at 16:9).
    func safeArea(margin: EMU) -> Rect { bounds.inset(by: margin) }
    func safeArea(fraction: Double = 0.05) -> Rect {
        bounds.inset(by: EMU(Int((Double(bounds.width.rawValue) * fraction).rounded())))
    }
}

// MARK: - Rect accessors

public extension Rect {
    /// Arrangement axis, matching SwiftUI's HStack/VStack intuition:
    /// `.horizontal` lays pieces out left→right (dividing width), `.vertical`
    /// lays them top→bottom (dividing height).
    enum Axis: Sendable, Hashable { case horizontal, vertical }

    var minX: EMU { x }
    var minY: EMU { y }
    var maxX: EMU { x + width }
    var maxY: EMU { y + height }
    var midX: EMU { x + width / 2.0 }
    var midY: EMU { y + height / 2.0 }

    /// The rect's center point as an (x, y) pair.
    var center: (x: EMU, y: EMU) { (midX, midY) }
}

// MARK: - Insets

public extension Rect {
    /// Shrink on all four sides by `amount`. Negative bleeds outward.
    func inset(by amount: EMU) -> Rect {
        inset(top: amount, left: amount, bottom: amount, right: amount)
    }

    /// Symmetric inset: `dx` off left and right, `dy` off top and bottom.
    func inset(dx: EMU = .zero, dy: EMU = .zero) -> Rect {
        inset(top: dy, left: dx, bottom: dy, right: dx)
    }

    /// Per-edge inset. Positive values shrink inward; the width/height are
    /// reduced by the sum of the two opposing edges.
    func inset(top: EMU = .zero, left: EMU = .zero,
               bottom: EMU = .zero, right: EMU = .zero) -> Rect {
        Rect(x: x + left, y: y + top,
             width: width - left - right, height: height - top - bottom)
    }
}

// MARK: - Splits

public extension Rect {
    /// Two adjacent rects along `axis`. The first takes `ratio` (0…1) of the
    /// length remaining after one `gutter` is removed; the second takes the
    /// exact remainder, so the pair tiles `self` with no drift.
    /// `.horizontal` → (left, right); `.vertical` → (top, bottom).
    func split(_ axis: Axis, ratio: Double, gutter: EMU = .zero) -> (Rect, Rect) {
        switch axis {
        case .horizontal:
            let usable = width - gutter
            let firstW = usable * ratio
            let secondW = usable - firstW
            return (Rect(x: x, y: y, width: firstW, height: height),
                    Rect(x: x + firstW + gutter, y: y, width: secondW, height: height))
        case .vertical:
            let usable = height - gutter
            let firstH = usable * ratio
            let secondH = usable - firstH
            return (Rect(x: x, y: y, width: width, height: firstH),
                    Rect(x: x, y: y + firstH + gutter, width: width, height: secondH))
        }
    }

    /// `count` equal rects along `axis`, separated by `gutter`. Tracks are a
    /// single rounded EMU size positioned at `i·(track+gutter)`, so adjacent
    /// cells share an exact edge and never gap or overlap. Any sub-EMU
    /// remainder (≤ `count−1` EMU, < 0.00001") is absorbed by the trailing edge.
    func split(_ axis: Axis, count: Int, gutter: EMU = .zero) -> [Rect] {
        precondition(count >= 1, "split count must be >= 1, got \(count)")
        switch axis {
        case .horizontal:
            let track = (width - gutter * Double(count - 1)) / Double(count)
            return (0..<count).map { i in
                Rect(x: x + (track + gutter) * Double(i), y: y,
                     width: track, height: height)
            }
        case .vertical:
            let track = (height - gutter * Double(count - 1)) / Double(count)
            return (0..<count).map { i in
                Rect(x: x, y: y + (track + gutter) * Double(i),
                     width: width, height: track)
            }
        }
    }

    /// `count` equal-height rows, top to bottom. `rows(3)` ==
    /// `split(.vertical, count: 3)`.
    func rows(_ count: Int, gutter: EMU = .zero) -> [Rect] {
        split(.vertical, count: count, gutter: gutter)
    }

    /// `count` equal-width columns, left to right. `columns(3)` ==
    /// `split(.horizontal, count: 3)`.
    func columns(_ count: Int, gutter: EMU = .zero) -> [Rect] {
        split(.horizontal, count: count, gutter: gutter)
    }

    /// Three equal columns as a destructurable tuple (left, center, right).
    /// For horizontal bands use `rows(3)`.
    var thirds: (Rect, Rect, Rect) {
        let c = columns(3)
        return (c[0], c[1], c[2])
    }
}

// MARK: - Centering

public extension Rect {
    /// A rect of the given size centered within `self`. May overflow if larger
    /// than `self`.
    func centered(width: EMU, height: EMU) -> Rect {
        Rect(x: x + (self.width - width) / 2.0,
             y: y + (self.height - height) / 2.0,
             width: width, height: height)
    }

    /// A centered square of side `side`.
    func centered(side: EMU) -> Rect {
        centered(width: side, height: side)
    }
}

// MARK: - Grid

/// A fixed column/row grid over a rect: name a cell (or a block spanning
/// several) by index and get its `Rect` back — no EMU arithmetic at the call
/// site. Tracks are uniform and deterministic; see `split(_:count:)`.
///
/// ```swift
/// let grid = Grid(in: deck.bounds, columns: 12, rows: 6,
///                 gutter: .inches(0.2), margin: .inches(0.9))
/// let hero = grid.cell(column: 0, row: 0, columnSpan: 8, rowSpan: 4)
/// let side = grid.cell(column: 8, row: 0, columnSpan: 4, rowSpan: 6)
/// ```
public struct Grid: Hashable, Sendable {
    /// The outer rect passed as `in:`.
    public let bounds: Rect
    /// `bounds` inset by the margins — the region the tracks tile.
    public let content: Rect
    public let columns: Int
    public let rows: Int
    public let columnGutter: EMU
    public let rowGutter: EMU
    /// Uniform track width (every column) and height (every row).
    public let columnWidth: EMU
    public let rowHeight: EMU

    /// A grid with a uniform gutter and margin.
    public init(in bounds: Rect, columns: Int, rows: Int = 1,
                gutter: EMU = .zero, margin: EMU = .zero) {
        self.init(in: bounds, columns: columns, rows: rows,
                  columnGutter: gutter, rowGutter: gutter, margin: margin)
    }

    /// A grid with independent horizontal/vertical gutters.
    public init(in bounds: Rect, columns: Int, rows: Int,
                columnGutter: EMU, rowGutter: EMU, margin: EMU) {
        precondition(columns >= 1 && rows >= 1,
                     "Grid needs >= 1 column and row, got \(columns)×\(rows)")
        let content = bounds.inset(by: margin)
        precondition(content.width.rawValue >= 0 && content.height.rawValue >= 0,
                     "Grid margin \(margin) exceeds half the bounds")
        self.bounds = bounds
        self.content = content
        self.columns = columns
        self.rows = rows
        self.columnGutter = columnGutter
        self.rowGutter = rowGutter
        self.columnWidth =
            (content.width - columnGutter * Double(columns - 1)) / Double(columns)
        self.rowHeight =
            (content.height - rowGutter * Double(rows - 1)) / Double(rows)
    }

    /// The rect of a cell, or of a block spanning `columnSpan × rowSpan` cells
    /// with its top-left at (`column`, `row`). All indices are zero-based.
    public func cell(column: Int, row: Int = 0,
                     columnSpan: Int = 1, rowSpan: Int = 1) -> Rect {
        precondition(column >= 0 && row >= 0 && columnSpan >= 1 && rowSpan >= 1,
                     "Grid.cell indices/spans must be non-negative and spans >= 1")
        precondition(column + columnSpan <= columns && row + rowSpan <= rows,
                     "Grid.cell block (\(column)+\(columnSpan), \(row)+\(rowSpan)) "
                     + "exceeds \(columns)×\(rows)")
        let cx = content.minX + (columnWidth + columnGutter) * Double(column)
        let cy = content.minY + (rowHeight + rowGutter) * Double(row)
        let w = columnWidth * Double(columnSpan) + columnGutter * Double(columnSpan - 1)
        let h = rowHeight * Double(rowSpan) + rowGutter * Double(rowSpan - 1)
        return Rect(x: cx, y: cy, width: w, height: h)
    }
}

// MARK: - Freeform custom geometry

/// A DrawingML custom-geometry path (`a:custGeom` / `a:pathLst` / `a:path`).
///
/// Coordinates are expressed in the path's own `coordinateSize` when supplied
/// (scaled onto the shape's `frame`), or directly in local EMU relative to the
/// shape's top-left corner (`0...frame.width`, `0...frame.height`) when `nil`.
public struct FreeformPath: Hashable, Sendable {
    public enum Command: Hashable, Sendable {
        case moveTo(x: EMU, y: EMU)
        case lineTo(x: EMU, y: EMU)
        case quadCurveTo(controlX: EMU, controlY: EMU, toX: EMU, toY: EMU)
        case cubicCurveTo(control1X: EMU, control1Y: EMU, control2X: EMU, control2Y: EMU, toX: EMU, toY: EMU)
        case arcTo(radiusX: EMU, radiusY: EMU, startAngleDegrees: Double, sweepAngleDegrees: Double)
        case close
    }

    public var commands: [Command]
    public var coordinateSize: (width: EMU, height: EMU)? {
        get {
            guard let w = coordinateWidth, let h = coordinateHeight else { return nil }
            return (w, h)
        }
        set {
            coordinateWidth = newValue?.width
            coordinateHeight = newValue?.height
        }
    }

    private var coordinateWidth: EMU?
    private var coordinateHeight: EMU?

    public init(commands: [Command] = [], coordinateSize: (width: EMU, height: EMU)? = nil) {
        self.commands = commands
        self.coordinateWidth = coordinateSize?.width
        self.coordinateHeight = coordinateSize?.height
    }

    /// Build a polyline or closed polygon from local points.
    public static func polygon(_ points: [(x: EMU, y: EMU)], closed: Bool = true,
                               coordinateSize: (width: EMU, height: EMU)? = nil) -> FreeformPath {
        var path = FreeformPath(coordinateSize: coordinateSize)
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        if closed {
            path.closeSubpath()
        }
        return path
    }

    public mutating func move(to point: (x: EMU, y: EMU)) {
        commands.append(.moveTo(x: point.x, y: point.y))
    }

    public mutating func addLine(to point: (x: EMU, y: EMU)) {
        commands.append(.lineTo(x: point.x, y: point.y))
    }

    public mutating func addQuadCurve(to end: (x: EMU, y: EMU), control: (x: EMU, y: EMU)) {
        commands.append(.quadCurveTo(controlX: control.x, controlY: control.y, toX: end.x, toY: end.y))
    }

    public mutating func addCubicCurve(to end: (x: EMU, y: EMU),
                                       control1: (x: EMU, y: EMU),
                                       control2: (x: EMU, y: EMU)) {
        commands.append(.cubicCurveTo(
            control1X: control1.x, control1Y: control1.y,
            control2X: control2.x, control2Y: control2.y,
            toX: end.x, toY: end.y))
    }

    public mutating func addArc(radiusX: EMU, radiusY: EMU,
                                startAngleDegrees: Double, sweepAngleDegrees: Double) {
        commands.append(.arcTo(
            radiusX: radiusX, radiusY: radiusY,
            startAngleDegrees: startAngleDegrees, sweepAngleDegrees: sweepAngleDegrees))
    }

    public mutating func closeSubpath() {
        commands.append(.close)
    }

    func makeCustGeomElement() -> XML.Element {
        let custGeom = XML.Element("a:custGeom")
        custGeom.appendElement(XML.Element("a:avLst"))
        custGeom.appendElement(XML.Element("a:gdLst"))
        custGeom.appendElement(XML.Element("a:ahLst"))
        custGeom.appendElement(XML.Element("a:cxnLst"))
        custGeom.appendElement(XML.Element("a:rect", attributes: [
            ("l", "l"), ("t", "t"), ("r", "r"), ("b", "b"),
        ]))
        let pathLst = XML.Element("a:pathLst")
        var pathAttrs: [(String, String)] = []
        if let size = coordinateSize, size.width.rawValue > 0, size.height.rawValue > 0 {
            pathAttrs.append(("w", String(size.width.rawValue)))
            pathAttrs.append(("h", String(size.height.rawValue)))
        }
        let pathEl = XML.Element("a:path", attributes: pathAttrs)
        func pt(_ x: EMU, _ y: EMU) -> XML.Element {
            XML.Element("a:pt", attributes: [("x", String(x.rawValue)), ("y", String(y.rawValue))])
        }
        for command in commands {
            switch command {
            case .moveTo(let x, let y):
                pathEl.appendElement(XML.Element("a:moveTo", children: [.element(pt(x, y))]))
            case .lineTo(let x, let y):
                pathEl.appendElement(XML.Element("a:lnTo", children: [.element(pt(x, y))]))
            case .quadCurveTo(let cx, let cy, let x, let y):
                pathEl.appendElement(XML.Element("a:quadBezTo", children: [.element(pt(cx, cy)), .element(pt(x, y))]))
            case .cubicCurveTo(let c1x, let c1y, let c2x, let c2y, let x, let y):
                pathEl.appendElement(XML.Element("a:cubicBezTo", children: [
                    .element(pt(c1x, c1y)), .element(pt(c2x, c2y)), .element(pt(x, y)),
                ]))
            case .arcTo(let rx, let ry, let stDeg, let swDeg):
                let st = stDeg.isFinite ? Int((stDeg * 60_000).rounded()) : 0
                let sw = swDeg.isFinite ? Swift.max(-21_600_000, Swift.min(21_600_000, Int((swDeg * 60_000).rounded()))) : 0
                pathEl.appendElement(XML.Element("a:arcTo", attributes: [
                    ("wR", String(Swift.max(1, rx.rawValue))),
                    ("hR", String(Swift.max(1, ry.rawValue))),
                    ("stAng", String(st)),
                    ("swAng", String(sw)),
                ]))
            case .close:
                pathEl.appendElement(XML.Element("a:close"))
            }
        }
        pathLst.appendElement(pathEl)
        custGeom.appendElement(pathLst)
        return custGeom
    }
}

