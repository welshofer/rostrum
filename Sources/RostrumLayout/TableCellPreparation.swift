import Foundation
import Rostrum

/// Width-independent inputs. Keep exact XML bytes in the measurement identity:
/// Swift String equality would alias canonically equivalent source text.
struct TableCellInput {
    struct Key: Hashable {
        let body: Data, style: Data
        let left: Double, top: Double, right: Double, bottom: Double
    }
    var body: XML.Element
    var style: XML.Element
    let insets: (left: Double, top: Double, right: Double, bottom: Double)
    let issues: [TableLayoutIssue]
    let key: Key?
    var preparation: RichTextLayout.Preparation?

    static func resolve(source: inout TableLayoutSource, row: Int, column: Int,
                        pagination: Bool) -> [TableCellInput] {
        let positions: [(Int, Int)] = pagination
            ? (row == 0 ? [(0, source.rowCount == 1 ? 1 : 2)] : [(1, 3), (2, 4), (1, 2), (2, 3)])
            : [(row, source.rowCount)]
        var seenStyles = Set<Data>(), result: [TableCellInput] = []
        var bodyBytes: Data?
        for (styleRow, count) in positions {
            let cell = source.cell(row: row, column: column, styleRow: styleRow, styleRowCount: count)
            let style = Data(cell.textStyle.serialized().utf8)
            guard seenStyles.insert(style).inserted else { continue }
            let body = cell.body.firstChild(named: "a:bodyPr"), margins = cell.insets
            var issues: [TableLayoutIssue] = []
            if cell.merged { issues.append(.mergedCell) }
            if cell.direction != "horz" || (body?[attribute: "vert"].map { $0 != "horz" } ?? false) { issues.append(.verticalText) }
            if Double(body?[attribute: "rot"] ?? "0") != 0 { issues.append(.rotatedText) }
            if Int(body?[attribute: "numCol"] ?? "1") != 1 { issues.append(.multipleTextColumns) }
            if cell.body.children(named: "a:p").contains(where: { !$0.children(named: "a:fld").isEmpty }) { issues.append(.dynamicField) }
            if (body?.firstChild(named: "a:normAutofit")?[attribute: "lnSpcReduction"].flatMap(Double.init) ?? 0) != 0 {
                issues.append(.lineSpacingReduction)
            }
            if [margins.left, margins.top, margins.right, margins.bottom].contains(where: { !$0.isFinite || $0 < 0 }) {
                issues.append(.invalidInsets)
            }
            var key: Key?
            if issues.isEmpty {
                if bodyBytes == nil { bodyBytes = Data(cell.body.serialized().utf8) }
                key = Key(body: bodyBytes!, style: style, left: margins.left, top: margins.top,
                    right: margins.right, bottom: margins.bottom)
            }
            result.append(TableCellInput(body: cell.body, style: cell.textStyle, insets: margins,
                issues: issues, key: key))
        }
        return result
    }
}

/// Belongs to one immutable table/search, never to the engine or presentation.
/// These payload budgets complement the entry limits; they are not heap sizes.
final class TableCellPreparation {
    private struct Position: Hashable { let row: Int, column: Int; let pagination: Bool }
    private struct Text {
        let body: XML.Element, style: XML.Element
        let preparation = RichTextLayout.Preparation()
    }
    private struct Cell { let inputs: [TableCellInput]; let prepared: Bool }
    private var cells: [Position: Cell] = [:]
    private var texts: [TableCellInput.Key: Text] = [:]
    private var remainingCells = 2_097_152, remainingText = 1_048_576
    var cellCount: Int { cells.count }
    var textCount: Int { texts.count }

    func inputs(source: inout TableLayoutSource, row: Int, column: Int, pagination: Bool,
                prepareText: Bool) -> [TableCellInput] {
        let position = Position(row: row, column: column, pagination: pagination)
        let cached = cells[position]
        if let cached, cached.prepared || !prepareText { return cached.inputs }
        var inputs = cached?.inputs ?? TableCellInput.resolve(source: &source, row: row, column: column, pagination: pagination)
        if prepareText {
            for index in inputs.indices {
                guard let text = text(for: inputs[index]) else { continue }
                inputs[index].body = text.body
                inputs[index].style = text.style
                inputs[index].preparation = text.preparation
            }
        }
        if cached != nil { cells[position] = Cell(inputs: inputs, prepared: prepareText) }
        else {
            let cost = inputs.reduce(0) { $0 + ($1.key.map { $0.body.count + $0.style.count } ?? 0) + 256 }
            if cells.count < 8192, cost <= remainingCells {
                cells[position] = Cell(inputs: inputs, prepared: prepareText); remainingCells -= cost
            }
        }
        return inputs
    }

    /// Text preparation begins after the baseline. Retained cells hold the
    /// resolved context, so later trials need no canonical-text dictionary lookup.
    private func text(for input: TableCellInput) -> Text? {
        guard let key = input.key else { return nil }
        if let cached = texts[key] { return cached }
        let bytes = key.body.count + key.style.count + 256
        guard texts.count < 1024, bytes <= remainingText else { return nil }
        // Equal bytes share one canonical read-only body. Preparation keys
        // paragraphs by identity, and each inherited style has its own Text.
        let text = Text(body: input.body, style: input.style)
        texts[key] = text; remainingText -= bytes
        return text
    }
}
