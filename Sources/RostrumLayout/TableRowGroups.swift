import Foundation
import Rostrum

/// Indivisible body-row intervals. Intersecting spans in different columns
/// connect rows even when their native merge rectangles do not overlap.
/// Only merged groups are stored; ordinary rows require no per-row allocation.
struct TableRowGroups: Sendable {
    private let ends: [Int: Int]
    static let empty = TableRowGroups(ends: [:])
    var isEmpty: Bool { ends.isEmpty }

    private init(ends: [Int: Int]) { self.ends = ends }

    // Call after validating native topology or TemplateTableContent.
    init(merges: [TableMergeRegion], headerRowCount: Int = 1) throws {
        let spans = merges.filter { $0.rowSpan > 1 }.sorted { $0.row < $1.row }
        var ends: [Int: Int] = [:], start = -1, end = -1
        for span in spans {
            if span.row < headerRowCount {
                guard span.rowSpan <= headerRowCount - span.row else {
                    throw LayoutError.cannotFit("A vertical merge cannot cross the repeated header/body boundary. Use single-slide composition or keep the complete merge inside the header or body.")
                }
                continue
            }
            if span.row < end { end = max(end, span.row + span.rowSpan) }
            else {
                if start >= 0 { ends[start] = end }
                start = span.row; end = span.row + span.rowSpan
            }
        }
        if start >= 0 { ends[start] = end }
        self.ends = ends
    }

    func end(startingAt row: Int) -> Int { ends[row] ?? row + 1 }

    /// Bounded integer addition avoids overflow and accepts exact fits.
    func height(_ rows: Range<Int>, in heights: [EMU], capacity: EMU) -> EMU? {
        var total = EMU.zero
        for row in rows {
            let height = heights[row]
            guard height > .zero, height <= capacity - total else { return nil }
            total += height
        }
        return total
    }

    func unplaceableCount(heights: [EMU], capacity: EMU, startingAt: Int = 1) -> Int {
        var row = startingAt, count = 0
        while row < heights.count {
            let end = end(startingAt: row)
            if height(row..<end, in: heights, capacity: capacity) == nil { count += 1 }
            row = end
        }
        return count
    }
}
