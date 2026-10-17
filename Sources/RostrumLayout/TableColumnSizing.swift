import Foundation
import Rostrum

/// Hard width bounds and an optional soft preference, in native EMUs.
public struct TableColumnConstraint: Sendable {
    /// Positive lower bound; defaults to 24 points.
    public var minimum: EMU
    /// Optional upper bound. Nil permits the column to use the table slot width.
    public var maximum: EMU?
    /// Soft target inside the bounds, considered after fit, page count and height.
    public var preferred: EMU?
    public init(minimum: EMU = .points(24), maximum: EMU? = nil, preferred: EMU? = nil) {
        self.minimum = minimum; self.maximum = maximum; self.preferred = preferred
    }
}

public enum TableColumnSizing: Sendable {
    /// Preserve the existing text-length heuristic or explicit column weights.
    case estimated
    /// Search actual wrapped geometry. An empty constraint array uses defaults;
    /// otherwise supply one entry per column. Existing weights seed the search.
    case measured(constraints: [TableColumnConstraint] = [])
}

public struct TableColumnSearchSummary: Sendable {
    /// Includes the constrained starting allocation; never exceeds 24.
    public let evaluatedCandidates: Int
    /// Cell visits beyond the starting allocation; never exceeds 32,768.
    /// Pagination may measure up to four native style positions per visit.
    public let additionalCellMeasurements: Int
    /// Cell results reused from unchanged columns within this search.
    public let reusedCellMeasurements: Int
    /// A candidate or additional-cell limit stopped further exploration.
    public let budgetExhausted: Bool
}

/// Bounded local search, not a global optimum or PowerPoint native autofit.
/// All scratch caches expire before callers can edit the prospective document.
final class TableColumnOptimizer {
    private let presentation: Presentation
    private let table: Table
    private let theme: Theme
    private let pagination: Bool
    private let availableHeight: EMU?
    private let headerRowCount: Int
    init(presentation: Presentation, table: Table, theme: Theme, pagination: Bool, availableHeight: EMU?,
         headerRowCount: Int = 1) {
        self.presentation = presentation; self.table = table; self.theme = theme
        self.pagination = pagination; self.availableHeight = availableHeight
        self.headerRowCount = headerRowCount
    }

    func plan(initial: [EMU], constraints: [TableColumnConstraint]) throws -> TableLayoutPlan {
        let bounds = try Bounds(initial: initial, constraints: constraints)
        let seed = bounds.project(initial)
        let engine = TableLayoutEngine(presentation: presentation)
        let reuse = try TableColumnMeasurements(table: table, theme: theme)
        let groups = try (pagination ? TableRowGroups(merges: reuse.source.merges, headerRowCount: headerRowCount) : .empty)
        var best = try engine.plan(table, columnWidths: seed, minimumRowHeight: .points(30),
            theme: theme, pagination: pagination, reuse: reuse)
        let initialVisits = reuse.measuredCells
        var bestOccupied = reuse.occupiedWidths
        var bestScore = score(best, bounds: bounds, groups: groups)
        var tried: Set<[EMU]> = [seed], evaluated = 1, exhausted = false
        func evaluate(_ widths: [EMU]) throws {
            guard !tried.contains(widths) else { return }
            guard evaluated < 24, reuse.missingCells(for: widths) <= 32_768 - (reuse.measuredCells - initialVisits) else {
                exhausted = true; return
            }
            tried.insert(widths); evaluated += 1
            let candidate = try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(30),
                theme: theme, pagination: pagination, reuse: reuse)
            let candidateScore = score(candidate, bounds: bounds, groups: groups)
            if candidateScore.precedes(bestScore) {
                best = candidate; bestScore = candidateScore; bestOccupied = reuse.occupiedWidths
            }
        }
        if bounds.preferred.contains(where: { $0 != nil }) {
            try evaluate(bounds.project(seed.indices.map { bounds.preferred[$0] ?? seed[$0] },
                preferredRecipients: seed.indices.filter { bounds.preferred[$0] == nil }))
        }
        // Every row is already at its hard minimum and preferences are met:
        // no width change can improve height or page count.
        if best.fits, bestScore.preferenceDistance == 0, best.rowHeights.allSatisfy({ $0 == .points(30) }) {
            best.columnSearch = TableColumnSearchSummary(evaluatedCandidates: evaluated,
                additionalCellMeasurements: reuse.measuredCells - initialVisits,
                reusedCellMeasurements: reuse.reusedCells, budgetExhausted: exhausted)
            return best
        }

        // Actual occupied glyph widths identify spare space in short columns.
        // Give it to columns that use their current width, then verify wrapping.
        let compact = best.columnWidths.indices.map {
            max(bounds.minimum[$0], min(best.columnWidths[$0], bestOccupied[$0] + .points(1)))
        }
        let recipients = compact.indices.filter { best.columnWidths[$0] - compact[$0] <= .points(2) }
        if !recipients.isEmpty { try evaluate(bounds.project(compact, preferredRecipients: recipients)) }

        // Coarse-to-fine transfers keep the search deterministic and bounded.
        // Rank donors by spare measured width and recipients by wrapping height.
        for fraction in [0.08, 0.04, 0.02] where evaluated < 24 {
            let base = best.columnWidths
            var pressure = [Double](repeating: 0, count: base.count)
            for cell in best.cells where !cell.isMergeContinuation {
                if cell.columnSpan == 1 { pressure[cell.column] += cell.requiredHeight.points }
                else {
                    let columns = cell.column..<(cell.column + cell.columnSpan)
                    let total = base[columns].reduce(.zero, +).points
                    for column in columns {
                        pressure[column] += cell.requiredHeight.points * base[column].points / total
                    }
                }
            }
            let donors = base.indices.sorted {
                let a = base[$0] - bestOccupied[$0], b = base[$1] - bestOccupied[$1]
                return a == b ? $0 < $1 : a > b
            }.prefix(4)
            let receivers = base.indices.sorted {
                pressure[$0] == pressure[$1] ? $0 < $1 : pressure[$0] > pressure[$1]
            }.prefix(4)
            for donor in donors { for receiver in receivers where donor != receiver && evaluated < 24 {
                let amount = min(bounds.total * fraction, best.columnWidths[donor] - bounds.minimum[donor],
                    bounds.maximum[receiver] - best.columnWidths[receiver])
                guard amount > .zero else { continue }
                var trial = best.columnWidths
                trial[donor] -= amount; trial[receiver] += amount
                try evaluate(trial)
            } }
        }
        best.columnSearch = TableColumnSearchSummary(evaluatedCandidates: evaluated,
            additionalCellMeasurements: reuse.measuredCells - initialVisits,
            reusedCellMeasurements: reuse.reusedCells, budgetExhausted: exhausted || evaluated == 24)
        return best
    }

    private struct Score {
        let invalidCells: Int, unplaceableRows: Int, pages: Int
        let height: EMU
        let preferenceDistance: Double
        func precedes(_ other: Score) -> Bool {
            if invalidCells != other.invalidCells { return invalidCells < other.invalidCells }
            if unplaceableRows != other.unplaceableRows { return unplaceableRows < other.unplaceableRows }
            if pages != other.pages { return pages < other.pages }
            if height != other.height { return height < other.height }
            return preferenceDistance < other.preferenceDistance
        }
    }

    private func score(_ plan: TableLayoutPlan, bounds: Bounds, groups: TableRowGroups) -> Score {
        var unplaceable = 0, pages = 1
        if let availableHeight {
            if pagination {
                let header = groups.height(0..<headerRowCount, in: plan.rowHeights, capacity: availableHeight)
                let capacity = header.map { availableHeight - $0 } ?? .zero
                unplaceable = (header == nil ? 1 : 0)
                    + (groups.isEmpty ? plan.rowHeights.dropFirst(headerRowCount).filter { $0 > capacity }.count
                        : groups.unplaceableCount(heights: plan.rowHeights, capacity: capacity, startingAt: headerRowCount))
                pages = (try? TemplateLayoutEngine.tablePageRanges(heights: plan.rowHeights, available: availableHeight,
                    groups: groups, headerRowCount: headerRowCount).count) ?? Int.max
            } else { unplaceable = plan.totalHeight > availableHeight ? 1 : 0 }
        }
        return Score(invalidCells: plan.cells.filter { !$0.issues.isEmpty }.count + (plan.fits ? 0 : 1),
            unplaceableRows: unplaceable, pages: pages, height: plan.totalHeight,
            preferenceDistance: plan.columnWidths.indices.reduce(0) { result, index in
                result + (bounds.preferred[index].map { abs($0.points - plan.columnWidths[index].points) } ?? 0)
            })
    }

    struct Bounds {
        let total: EMU
        let minimum: [EMU], maximum: [EMU], preferred: [EMU?]
        init(initial: [EMU], constraints: [TableColumnConstraint]) throws {
            let limit = EMU.points(1_000_000)
            guard !initial.isEmpty, initial.allSatisfy({ $0 > .zero && $0 <= limit }),
                  initial.reduce(0.0, { $0 + $1.points }) <= limit.points,
                  constraints.isEmpty || constraints.count == initial.count else {
                throw LayoutError.cannotFit("Column constraints must match the grid and its bounded positive width.")
            }
            total = initial.reduce(.zero, +)
            let values = constraints.isEmpty ? initial.map { _ in TableColumnConstraint() } : constraints
            var lower: [EMU] = [], upper: [EMU] = [], wants: [EMU?] = []
            var minimumSum = EMU.zero, maximumSum = EMU.zero
            for value in values {
                let maximum = value.maximum ?? total
                guard value.minimum > .zero, value.minimum <= maximum, maximum <= limit,
                      value.minimum <= total - minimumSum,
                      value.preferred.map({ $0 >= value.minimum && $0 <= maximum }) ?? true else {
                    throw LayoutError.cannotFit("Column bounds must be positive, feasible, and contain their preferred widths.")
                }
                minimumSum += value.minimum
                maximumSum = min(total, maximumSum + min(total, maximum))
                lower.append(value.minimum); upper.append(min(total, maximum)); wants.append(value.preferred)
            }
            guard maximumSum >= total else { throw LayoutError.cannotFit("Column maximum widths cannot fill the table slot.") }
            minimum = lower; maximum = upper; preferred = wants
        }

        /// Integer water filling: preserve the exact slot width and hard bounds.
        /// Optional recipients absorb changes first; all columns provide fallback.
        func project(_ target: [EMU], preferredRecipients: [Int] = []) -> [EMU] {
            var result = target.indices.map { max(minimum[$0], min(maximum[$0], target[$0])) }
            var remaining = total - result.reduce(.zero, +)
            for group in [preferredRecipients, Array(target.indices)] {
                while remaining != .zero {
                    let eligible = group.filter { remaining > .zero ? result[$0] < maximum[$0] : result[$0] > minimum[$0] }
                    guard !eligible.isEmpty else { break }
                    let share = max(1, abs(remaining.rawValue) / eligible.count)
                    for index in eligible where remaining != .zero {
                        let room = remaining > .zero ? maximum[index] - result[index] : result[index] - minimum[index]
                        let change = EMU(min(share, abs(remaining.rawValue), room.rawValue))
                        if remaining > .zero { result[index] += change; remaining -= change }
                        else { result[index] -= change; remaining += change }
                    }
                }
                if remaining == .zero { break }
            }
            return result
        }
    }
}
