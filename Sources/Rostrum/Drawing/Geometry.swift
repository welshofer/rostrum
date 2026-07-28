import Foundation

// Layout geometry — a deterministic, zero-dependency layer on top of `Rect`
// so decks stop hand-computing EMU. Everything here is pure integer/EMU math:
// no OOXML is produced, so there is zero round-trip risk. The rects returned
// flow into the existing `addShape(frame:)` / `addTextBox(frame:)` writers.

// MARK: - Source cropping

/// The `a:srcRect` edge insets that trim a source image before it is stretched
/// onto its destination, as fractions 0…1 of the image's own width/height.
///
/// One type for both fill paths on purpose. Pictures (`p:pic`) and fills
/// (`a:blipFill` on a shape or a slide background) crop through the identical
/// element, and when each computed its own insets they drifted: pictures got
/// aspect-preserving cover and fills silently did not, so every full-bleed
/// background image was scaled non-uniformly to the slide — a square
/// illustration on a 16:9 slide arrived 78% too wide.
public struct SrcCrop: Hashable, Sendable {
    public var left, top, right, bottom: Double

    public init(left: Double = 0, top: Double = 0, right: Double = 0, bottom: Double = 0) {
        self.left = left; self.top = top; self.right = right; self.bottom = bottom
    }

    /// The insets that let an image of `imageAspect` (width ÷ height) cover a
    /// region of `regionAspect` with no distortion, cropping the overflowing
    /// edges symmetrically about the center. `nil` when no crop is called for —
    /// the aspects agree, or either is not a usable positive ratio.
    public static func cover(imageAspect: Double, regionAspect: Double) -> SrcCrop? {
        guard imageAspect.isFinite, regionAspect.isFinite,
              imageAspect > 0, regionAspect > 0 else { return nil }
        // Below srcRect's own resolution (1/100000) the inset writes as "0", so
        // a matching pair one float ulp apart emits an all-zero element instead
        // of none — same picture, different bytes. Determinism is a feature.
        let c = imageAspect < regionAspect
            ? (1 - imageAspect / regionAspect) / 2
            : (1 - regionAspect / imageAspect) / 2
        guard (c * 100_000).rounded() >= 1 else { return nil }
        return imageAspect < regionAspect
            ? SrcCrop(top: c, bottom: c)          // relatively taller: crop top & bottom
            : SrcCrop(left: c, right: c)          // relatively wider: crop left & right
    }
}

public extension Rect {
    /// Width ÷ height, or nil for a degenerate rect — the ratio `SrcCrop.cover`
    /// needs, asked of the rect rather than recomputed at each call site.
    var aspect: Double? {
        guard width.rawValue > 0, height.rawValue > 0 else { return nil }
        return Double(width.rawValue) / Double(height.rawValue)
    }
}

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
