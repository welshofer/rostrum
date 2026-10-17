import Foundation
import Rostrum

/// The SVG renderer and cell fitText use a horizontal text box with the cell's
/// dimensions swapped. Insets remain in that text coordinate system. Search
/// its inline extent (the physical row height), keeping full-size text and the
/// physical column width fixed. Every accepted extent has actually been laid out;
/// mixed run sizes need not have a globally monotonic wrapping-height function.
struct RotatedTableCellMeasurement {
    let height: EMU
    let occupiedWidth: EMU
    let issues: [TableLayoutIssue]
    let diagnostics: [ShapingDiagnostic]

    static func layout(_ input: TableCellInput, width: EMU, height: EMU,
                       fonts: FontLibrary, theme: Theme) -> RichTextLayout {
        RichTextLayout(textBody: input.body, width: height.points, height: width.points,
            fonts: fonts, theme: theme, inheritedStyles: [input.style], maxLines: 65,
            insets: input.insets, verticalAnchor: "t", context: .tableCell, preparation: input.preparation)
    }

    static func issues(_ geometry: RichTextLayout, input: TableCellInput,
                       width: EMU, height: EMU) -> [TableLayoutIssue] {
        var result: [TableLayoutIssue] = []
        if geometry.truncated || geometry.lines.count > 64 { result.append(.lineLimit) }
        if geometry.usedEmergencyLineBreak { result.append(.wordSplit) }
        if !geometry.fits || input.insets.top + input.insets.bottom >= width.points
            || input.insets.left + input.insets.right >= height.points {
            result.append(.horizontalOverflow)
        }
        return result
    }

    init(input: TableCellInput, width: EMU, fonts: FontLibrary, theme: Theme) {
        let limit = EMU.points(1_000_000)
        var input = input
        // One immutable preparation serves all local height trials, including
        // the baseline width candidate and callers without a column search.
        if input.preparation == nil { input.preparation = .init() }
        var upper = limit
        var accepted = Self.layout(input, width: width, height: upper, fonts: fonts, theme: theme)
        let initialIssues = Self.issues(accepted, input: input, width: width, height: upper)
        if !initialIssues.isEmpty {
            height = .zero; occupiedWidth = width; issues = initialIssues; diagnostics = accepted.diagnostics
            return
        }
        // Start near the unwrapped advance. Indents/tabs can require more than
        // this estimate; in that case retain the verified bounded upper extent.
        let estimate = (accepted.lines.map(\.width).max() ?? 0) + input.insets.left + input.insets.right + 1
        let guessed = EMU.points(min(limit.points, max(0.125, ceil(estimate * 8) / 8)))
        let probe = Self.layout(input, width: width, height: guessed, fonts: fonts, theme: theme)
        if Self.issues(probe, input: input, width: width, height: guessed).isEmpty {
            upper = guessed; accepted = probe
        }
        var lower = 0
        var upperTicks = Int(ceil(upper.points * 8))
        // Bounded search on the native eighth-point capacity grid. At most 22
        // layouts per style/width, including the two probes above. This is a
        // verified fit, not a global minimum or PowerPoint's native autofit.
        for _ in 0..<20 {
            guard upperTicks - lower > 1 else { break }
            let middle = lower + (upperTicks - lower) / 2
            let trial = EMU.points(Double(middle) / 8)
            let geometry = Self.layout(input, width: width, height: trial, fonts: fonts, theme: theme)
            if Self.issues(geometry, input: input, width: width, height: trial).isEmpty {
                upperTicks = middle; upper = trial; accepted = geometry
            } else { lower = middle }
        }
        height = upper
        occupiedWidth = .points(ceil(accepted.contentHeight + input.insets.top + input.insets.bottom))
        issues = []; diagnostics = accepted.diagnostics
    }
}
