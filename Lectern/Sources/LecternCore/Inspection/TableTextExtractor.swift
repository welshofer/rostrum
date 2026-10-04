import Foundation
import Rostrum

/// A read-only projection of actual table payloads, independent of prefix spelling.
/// Matches DeckOutline's physical-cell policy: merge continuations keep their
/// stored text, absent grid cells are blank, and paragraphs retain line breaks.
enum TableTextExtractor {
    static let maximumTotalCells = 1_000_000
    struct Result {
        var tables: [TableInspection] = []
        var warnings: [String] = []
        var budgetExceeded = false
    }
    struct BudgetError: Swift.Error, CustomStringConvertible {
        var description: String { "Table text exceeds the \(maximumTotalCells)-cell inspection budget." }
    }
    private static let presentation = "http://schemas.openxmlformats.org/presentationml/2006/main"
    private static let drawing = "http://schemas.openxmlformats.org/drawingml/2006/main"

    private struct Node {
        let element: XML.Element
        let namespaces: [String: String]
        init(_ element: XML.Element, inherited: [String: String] = [:]) {
            self.element = element
            var scope = inherited
            for (name, value) in element.attributes {
                if name == "xmlns" { scope[""] = value }
                else if name.hasPrefix("xmlns:") { scope[String(name.dropFirst(6))] = value }
            }
            namespaces = scope
        }
        func matches(_ local: String, namespace: String) -> Bool {
            let pieces = element.name.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let prefix = pieces.count == 2 ? String(pieces[0]) : ""
            return pieces.last.map(String.init) == local && namespaces[prefix] == namespace
        }
        var children: [Node] { element.childElements.map { Node($0, inherited: namespaces) } }
        func children(_ local: String, namespace: String) -> [Node] {
            children.filter { $0.matches(local, namespace: namespace) }
        }
        func first(_ local: String, namespace: String) -> Node? {
            children.first { $0.matches(local, namespace: namespace) }
        }
    }

    /// Check before the legacy outline can materialize a ragged dense matrix.
    /// Its lexical readers may also recognize namespace lookalikes; conservatively
    /// bound that matrix independently, without treating it as semantic table text.
    static func preflight(_ deck: Presentation) throws {
        var semanticCells = maximumTotalCells, lexicalCells = maximumTotalCells
        for index in 0..<deck.slides.count {
            try Task.checkCancellation()
            guard let slide = try? deck.slides.slide(at: index) else { continue }
            if let root = try? slide.part.dom(),
               extract(in: root, remainingCells: &semanticCells, includeText: false).budgetExceeded {
                throw BudgetError()
            }
            for shape in DeckDetailExtractor.flatten(slide.shapes.all) {
                guard let table = (shape as? TableFrame)?.table else { continue }
                let rows = table.rowCount, columns = table.columnCount
                guard columns > 0 else { continue }
                guard rows <= lexicalCells / columns else { throw BudgetError() }
                lexicalCells -= rows * columns
            }
        }
    }

    static func extract(in root: XML.Element, remainingCells: inout Int, includeText: Bool = true) -> Result {
        var result = Result()
        let slide = Node(root)
        guard slide.matches("sld", namespace: presentation),
              let common = slide.first("cSld", namespace: presentation),
              let tree = common.first("spTree", namespace: presentation) else { return result }
        var pending = Array(tree.children.reversed())
        while let shape = pending.popLast() {
            if shape.matches("grpSp", namespace: presentation) {
                pending.append(contentsOf: shape.children.reversed())
                continue
            }
            guard shape.matches("graphicFrame", namespace: presentation),
                  let graphic = shape.first("graphic", namespace: drawing),
                  let data = graphic.first("graphicData", namespace: drawing),
                  data.element[attribute: "uri"] == GraphicDataURI.table,
                  let table = data.first("tbl", namespace: drawing) else { continue }
            let index = result.tables.count
            let rows = table.children("tr", namespace: drawing)
            let columns = table.first("tblGrid", namespace: drawing)?.children("gridCol", namespace: drawing).count ?? 0
            guard !rows.isEmpty, columns > 0 else {
                result.tables.append(TableInspection(index: index, rows: []))
                result.warnings.append("table \(index + 1): no readable rows or grid columns")
                continue
            }
            // A small ragged XML table can otherwise demand rows × grid-width
            // blank strings. Share this budget across all slides in an operation.
            guard remainingCells >= 0, rows.count <= remainingCells / columns else {
                result.budgetExceeded = true
                result.tables.append(TableInspection(index: index, rows: []))
                result.warnings.append("table \(index + 1): text omitted because the \(maximumTotalCells)-cell inspection budget was exceeded")
                continue
            }
            remainingCells -= rows.count * columns
            guard includeText else { continue }
            let values = rows.map { row -> [String] in
                let cells = row.children("tc", namespace: drawing)
                return (0..<columns).map { column in
                    guard column < cells.count,
                          let body = cells[column].first("txBody", namespace: drawing) else { return "" }
                    return body.children("p", namespace: drawing).map(paragraphText)
                        .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            result.tables.append(TableInspection(index: index, rows: values))
        }
        return result
    }

    private static func paragraphText(_ paragraph: Node) -> String {
        var result = ""
        for child in paragraph.children {
            if child.matches("r", namespace: drawing) || child.matches("fld", namespace: drawing) {
                result += child.first("t", namespace: drawing)?.element.textContent ?? ""
            } else if child.matches("br", namespace: drawing) { result += "\n" }
        }
        return result
    }
}
