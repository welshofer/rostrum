import Foundation
import Rostrum

/// One editable native table. Row zero is repeated; bodyRows indexes the
/// original TemplateTableContent.rows and excludes that header.
public struct TemplateTablePagePlan {
    public let slide: TemplateSlidePlan
    public let bodyRows: Range<Int>
}

/// A read-only plan for one table continued across a single template layout.
/// Titles and captions repeat verbatim. Callers own notes, sections and source
/// metadata; returned row ranges let them associate pages with their content.
public struct TemplateTablePaginationPlan {
    public let pages: [TemplateTablePagePlan]
    public let title: String
    public let caption: String
    fileprivate let content: TemplateTableContent
}

extension TemplateLayoutEngine {
    /// Measures full-size plain cells with bounded reuse across candidate layouts,
    /// then partitions at row boundaries. Reserves caption space on every page.
    /// The first row is the repeated header; even a header-only grid makes one
    /// page. A body row that cannot fit beside its header throws before mutation.
    /// Band/edge text styles use a conservative height envelope, so a custom
    /// style can leave extra space. Columns keep identical widths on every page.
    public func planTablePages(title: String, table: TemplateTableContent,
                               caption: String = "", preferredTypes: [String] = ["obj"],
                               masterURI: String? = nil, layoutURI: String? = nil) throws -> TemplateTablePaginationPlan {
        _ = try table.widths(for: presentation.bounds.width)
        struct Key: Hashable { let width: EMU; let font: Data; let theme: PackURI; let availableHeight: EMU? }
        var measured: [Key: TableLayoutPlan] = [:], remainingCells = 8192
        var best: TemplateTablePaginationPlan?, bestScore = Double.infinity
        var failures: [String] = []
        for layout in presentation.allLayouts where
            (masterURI == nil || layout.master?.part.uri.value == masterURI)
                && (layoutURI == nil || layout.part.uri.value == layoutURI) {
            do {
                let base = try plan(title: title, columns: [], preferredTypes: preferredTypes,
                    object: "tbl", objectCaption: caption, minimumObjectHeight: 0,
                    layoutURI: layout.part.uri.value)
                guard let frame = base.objectFrame else { continue }
                let style = objectStyle(layout: layout, slot: base.objectSlot?.index)
                let theme = layout.master?.theme ?? presentation.theme
                let key = Key(width: frame.width, font: Data(style.bodyFont.utf8), theme: theme.part.uri,
                    availableHeight: table.measuresColumns ? frame.height : nil)
                let geometry: TableLayoutPlan
                if let cached = measured[key] { geometry = cached }
                else {
                    geometry = try table.planned(in: presentation, width: frame.width, font: style.bodyFont,
                        size: 18 * objectScale, theme: theme, pagination: true, availableHeight: key.availableHeight)
                    if measured.count < 64, geometry.cells.count <= remainingCells {
                        measured[key] = geometry; remainingCells -= geometry.cells.count
                    }
                }
                guard geometry.fits else {
                    let cell = geometry.cells.first { !$0.issues.isEmpty }
                    throw LayoutError.cannotFit(cell.map { "Unsupported or overflowing table cell at row \($0.row), column \($0.column): \($0.issues)." }
                        ?? "Table geometry exceeds the supported dimensions.")
                }
                let ranges = try Self.tablePageRanges(heights: geometry.rowHeights, available: frame.height)
                let columns = geometry.columnWidths.count
                let pages = ranges.map { range -> TemplateTablePagePlan in
                    let indices = [0] + Array(range)
                    let heights = indices.map { geometry.rowHeights[$0] }
                    let cells = indices.enumerated().flatMap { localRow, sourceRow in
                        geometry.cells[(sourceRow * columns)..<((sourceRow + 1) * columns)].map {
                            TableCellLayout(row: localRow, column: $0.column, requiredHeight: $0.requiredHeight,
                                issues: $0.issues, diagnostics: $0.diagnostics)
                        }
                    }
                    var page = base
                    page.tableContent = TemplateTableContent(rows: indices.map { table.rows[$0] },
                        columnWeights: geometry.columnWidths.map { Double($0.rawValue) })
                    page.tableLayout = TableLayoutPlan(columnWidths: geometry.columnWidths, rowHeights: heights,
                        cells: cells, totalHeight: heights.reduce(.zero, +), fits: true, columnSearch: geometry.columnSearch)
                    return TemplateTablePagePlan(slide: page, bodyRows: range)
                }
                if best == nil || pages.count < best!.pages.count
                    || (pages.count == best!.pages.count && base.score.penalty < bestScore) {
                    best = TemplateTablePaginationPlan(pages: pages, title: title, caption: caption, content: table)
                    bestScore = base.score.penalty
                }
            } catch { if failures.count < 4 { failures.append("\(layout.name): \(error)") } }
        }
        guard let best else { throw LayoutError.cannotFit("No template layout can paginate the table. " + failures.joined(separator: "; ")) }
        return best
    }

    /// Freshly checks all cells, fonts, styles, title and caption before adding
    /// any slides. Changed page boundaries or geometry require a new plan.
    /// Writes the repeated title, native table and caption on each returned page.
    public func composeTablePages(_ plan: TemplateTablePaginationPlan) throws -> [Slide] {
        guard let first = plan.pages.first else { throw LayoutError.cannotFit("The table plan has no pages.") }
        let current = try planTablePages(title: plan.title, table: plan.content, caption: plan.caption,
            layoutURI: first.slide.layout.part.uri.value)
        guard current.pages.count == plan.pages.count,
              zip(current.pages, plan.pages).allSatisfy({ a, b in
                  a.bodyRows == b.bodyRows && a.slide.objectFrame == b.slide.objectFrame
                      && a.slide.captionFrame == b.slide.captionFrame
                      && a.slide.title.frame == b.slide.title.frame
                      && a.slide.tableLayout?.columnWidths == b.slide.tableLayout?.columnWidths
                      && a.slide.tableLayout?.rowHeights == b.slide.tableLayout?.rowHeights
              }) else { throw LayoutError.cannotFit("The table pagination geometry changed. Plan again before composing.") }
        let prepared = try current.pages.map {
            try prepare($0.slide, title: current.title, columns: [], measuredTable: $0.slide.tableLayout)
        }
        return try zip(current.pages, prepared).map { page, prepared in
            let slide = try write(page.slide, prepared: prepared)
            if let frame = page.slide.captionFrame {
                try slide.addText(current.caption, in: frame, role: .caption,
                    style: objectStyle(layout: page.slide.layout, slot: page.slide.objectSlot?.index))
            }
            return slide
        }
    }

    // Integer EMU arithmetic accepts exact fits without a floating-point epsilon.
    // Each source row is visited once; no prefix copying or candidate reshaping.
    static func tablePageRanges(heights: [EMU], available: EMU) throws -> [Range<Int>] {
        guard let header = heights.first, header > .zero, header <= available else {
            throw LayoutError.cannotFit("The repeated header is taller than the available table area.")
        }
        var ranges: [Range<Int>] = [], start = 1, used = header
        for row in 1..<heights.count {
            let height = heights[row]
            guard height > .zero, height <= available - header else {
                throw LayoutError.cannotFit("Table row \(row) cannot fit with its repeated header at full text size.")
            }
            if height > available - used {
                ranges.append(start..<row); start = row; used = header
            }
            used += height
        }
        ranges.append(start..<heights.count)
        return ranges
    }
}
