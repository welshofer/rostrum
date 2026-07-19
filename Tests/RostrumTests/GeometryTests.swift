import Testing
@testable import Rostrum

@Suite struct GeometryTests {
    // MARK: - Canonical sizes

    @Test func canonicalSlideSizeMatchesTemplate() throws {
        #expect(Rect.slide16x9.width == EMU.inches(13.333333))
        #expect(Rect.slide16x9.height == EMU.inches(7.5))
        #expect(Rect.slide16x9.width.rawValue == 12_192_000)
        #expect(Rect.slide16x9.height.rawValue == 6_858_000)
        #expect(Rect.slide4x3.width == EMU.inches(10))
    }

    @Test func deckBoundsTrackSlideSize() throws {
        let deck = try Presentation()
        #expect(deck.bounds == Rect.slide16x9)
        deck.slideSize = (width: .inches(10), height: .inches(7.5))
        #expect(deck.bounds == Rect.slide4x3)
    }

    // MARK: - Insets

    @Test func insetShrinksSymmetrically() {
        let r = Rect(x: .zero, y: .zero, width: .inches(10), height: .inches(6))
        let i = r.inset(by: .inches(1))
        #expect(i.x == EMU.inches(1))
        #expect(i.y == EMU.inches(1))
        #expect(i.width == EMU.inches(8))   // 10 − 1 − 1
        #expect(i.height == EMU.inches(4))  // 6 − 1 − 1
    }

    @Test func perEdgeInset() {
        let r = Rect(x: .inches(1), y: .inches(1), width: .inches(10), height: .inches(6))
        let i = r.inset(top: .inches(0.5), left: .inches(1),
                        bottom: .inches(0.25), right: .inches(2))
        #expect(i.x == EMU.inches(2))
        #expect(i.y == EMU.inches(1.5))
        #expect(i.width == EMU.inches(7))    // 10 − 1 − 2
        #expect(i.height == EMU.inches(5.25)) // 6 − 0.5 − 0.25
    }

    @Test func negativeInsetBleeds() {
        let r = Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4))
        let bleed = r.inset(by: .inches(-1))
        #expect(bleed.x == EMU.inches(0))
        #expect(bleed.width == EMU.inches(10))
    }

    // MARK: - Two-column split

    @Test func twoColumnSplitTilesExactly() {
        let r = Rect.slide16x9
        let (left, right) = r.split(.horizontal, ratio: 0.5)
        // No gutter, 50/50: the two halves reconstruct the whole with no gap.
        #expect(left.x == r.minX)
        #expect(left.maxX == right.minX)
        #expect(right.maxX == r.maxX)
        #expect(left.width + right.width == r.width)
        #expect(left.height == r.height && right.height == r.height)
    }

    @Test func splitRespectsRatioAndGutter() {
        let r = Rect(x: .zero, y: .zero, width: .inches(12), height: .inches(6))
        let (a, b) = r.split(.horizontal, ratio: 0.25, gutter: .inches(0.4))
        let usable = EMU.inches(12) - EMU.inches(0.4)   // 11.6"
        #expect(a.width == usable * 0.25)
        #expect(b.width == usable - a.width)            // exact remainder
        #expect(b.minX == a.maxX + EMU.inches(0.4))     // gutter between
        #expect(b.maxX == r.maxX)                        // reaches the edge
    }

    @Test func verticalSplitTopBottom() {
        let r = Rect(x: .zero, y: .zero, width: .inches(10), height: .inches(8))
        let (top, bottom) = r.split(.vertical, ratio: 0.75)
        #expect(top.height == EMU.inches(6))
        #expect(bottom.height == EMU.inches(2))
        #expect(top.maxY == bottom.minY)
        #expect(top.width == r.width && bottom.width == r.width)
    }

    // MARK: - rows / columns / thirds

    @Test func columnsAreEqualAndTile() {
        let r = Rect(x: .zero, y: .zero, width: .inches(12), height: .inches(6))
        let cols = r.columns(4, gutter: .inches(0.3))
        #expect(cols.count == 4)
        // Every track identical.
        #expect(Set(cols.map(\.width.rawValue)).count == 1)
        // Adjacent columns are exactly one gutter apart.
        for i in 1..<cols.count {
            #expect(cols[i].minX - cols[i - 1].maxX == EMU.inches(0.3))
        }
        #expect(cols[0].minX == r.minX)
    }

    @Test func thirdsSplitWidthInThree() {
        let r = Rect(x: .zero, y: .zero, width: .inches(9), height: .inches(6))
        let (l, c, right) = r.thirds
        #expect(l.width == EMU.inches(3))
        #expect(c.width == EMU.inches(3))
        #expect(right.width == EMU.inches(3))
        #expect(l.maxX == c.minX && c.maxX == right.minX)
    }

    // MARK: - Centering

    @Test func centeredPlacesInMiddle() {
        let r = Rect(x: .zero, y: .zero, width: .inches(10), height: .inches(8))
        let box = r.centered(width: .inches(4), height: .inches(2))
        #expect(box.x == EMU.inches(3))   // (10 − 4)/2
        #expect(box.y == EMU.inches(3))   // (8 − 2)/2
        #expect(box.center.x == r.center.x)
        #expect(box.center.y == r.center.y)
    }

    // MARK: - 12-column grid

    @Test func twelveColumnGridSpansAndTiles() {
        let grid = Grid(in: Rect.slide16x9, columns: 12, rows: 6,
                        gutter: .inches(0.2), margin: .inches(0.9))
        // Content = bounds inset by 0.9" all round.
        #expect(grid.content == Rect.slide16x9.inset(by: .inches(0.9)))

        // A single cell sits at the content origin.
        let first = grid.cell(column: 0, row: 0)
        #expect(first.minX == grid.content.minX)
        #expect(first.minY == grid.content.minY)
        #expect(first.width == grid.columnWidth)
        #expect(first.height == grid.rowHeight)

        // An 8-wide block spans 8 tracks + 7 interior gutters.
        let hero = grid.cell(column: 0, row: 0, columnSpan: 8, rowSpan: 4)
        #expect(hero.width == grid.columnWidth * 8.0 + grid.columnGutter * 7.0)
        #expect(hero.height == grid.rowHeight * 4.0 + grid.rowGutter * 3.0)

        // The block abutting it on the right starts one gutter past its edge.
        let side = grid.cell(column: 8, row: 0, columnSpan: 4, rowSpan: 6)
        #expect(side.minX == hero.maxX + grid.columnGutter)

        // Last column's right edge stays within the content box (rounding
        // remainder is absorbed by the trailing margin, never overflows).
        let last = grid.cell(column: 11, row: 5)
        #expect(last.maxX <= grid.content.maxX)
        #expect(last.maxY <= grid.content.maxY)
        #expect(grid.content.maxX - last.maxX < EMU(12))   // < columns EMU
    }

    @Test func gridWithoutGutterTilesPerfectly() {
        let grid = Grid(in: Rect(x: .zero, y: .zero,
                                 width: .inches(12), height: .inches(6)),
                        columns: 6, rows: 3)
        // Gutter-free adjacent cells share an exact edge.
        for c in 1..<6 {
            #expect(grid.cell(column: c, row: 0).minX
                    == grid.cell(column: c - 1, row: 0).maxX)
        }
        for rr in 1..<3 {
            #expect(grid.cell(column: 0, row: rr).minY
                    == grid.cell(column: 0, row: rr - 1).maxY)
        }
    }

    // MARK: - Determinism

    @Test func geometryIsDeterministic() {
        // Same inputs → byte-identical rects, every call.
        func build() -> [Rect] {
            let g = Grid(in: Rect.slide16x9, columns: 12, rows: 6,
                         gutter: .inches(0.15), margin: .inches(0.75))
            return (0..<12).flatMap { c in (0..<6).map { g.cell(column: c, row: $0) } }
        }
        #expect(build() == build())
    }
}
