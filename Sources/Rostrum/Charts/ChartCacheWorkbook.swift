import Foundation

/// Strict, operation-scoped workbook reader for writes. The permissive preview
/// fallback deliberately remains separate: unreadable data must not turn into
/// a persisted blank cache. Workbook parts are never mutated or reserialized.
final class CacheRepairWorkbook {
    typealias Problem = Chart.CacheRepairProblem
    typealias Node = CacheRepairNode
    typealias Address = ChartWorkbookReader.Address
    private let sheets: [String: Part]
    private let strings: [String]
    private let generalStyles: [Bool]?
    private var cellsBySheet: [String: [Address: Node]] = [:]
    private var visitedCells = 0

    init(data: Data) throws {
        guard data.count <= 64 << 20 else { throw Problem.limitExceeded }
        let package = try OPCPackage.read(data: data, limits: .init(totalUncompressedBytes: 64 << 20))
        let rootLinks = package.rels.all(ofType: RelType.officeDocument)
        guard rootLinks.count == 1, !rootLinks[0].isExternal,
              package.rels.items.filter({ $0.rId == rootLinks[0].rId }).count == 1 else {
            throw Problem.invalidWorkbook("expected one internal workbook")
        }
        let workbook = try package.mainDocumentPart()
        let root = Node(try workbook.dom())
        guard root.isNamed("workbook", in: Node.sheet), root.children("sheets").count == 1 else {
            throw Problem.invalidWorkbook("invalid workbook/sheets namespace or structure")
        }
        var sheets: [String: Part] = [:]
        for sheet in root.children("sheets")[0].children {
            guard sheet.isNamed("sheet", in: Node.sheet), let name = sheet.element[attribute: "name"], !name.isEmpty,
                  sheets[name.lowercased()] == nil, let id = sheet.relationshipID,
                  workbook.rels.items.filter({ $0.rId == id }).count == 1,
                  let rel = workbook.rels.relationship(withId: id), !rel.isExternal,
                  rel.type == Node.relationships + "/worksheet" else {
                throw Problem.invalidWorkbook("ambiguous sheet name or worksheet relationship")
            }
            sheets[name.lowercased()] = try package.part(at: PackURI.resolve(target: rel.target, relativeTo: workbook.uri.baseURI))
        }
        self.sheets = sheets
        if let shared = try Self.related("sharedStrings", from: workbook, in: package) {
            let root = Node(try shared.dom())
            guard root.isNamed("sst", in: Node.sheet) else { throw Problem.invalidWorkbook("invalid shared strings namespace") }
            let entries = root.children("si")
            guard entries.count <= 250_000 else { throw Problem.limitExceeded }
            guard root.children.allSatisfy({ $0.uri == Node.sheet && ["si", "extLst"].contains($0.local) }) else {
                throw Problem.invalidWorkbook("invalid shared strings children")
            }
            strings = try entries.map(Self.text)
        } else { strings = [] }
        if let styles = try Self.related("styles", from: workbook, in: package) {
            let root = Node(try styles.dom())
            guard root.isNamed("styleSheet", in: Node.sheet), root.children("cellXfs").count == 1,
                  root.children("cellStyleXfs").count <= 1 else { throw Problem.invalidWorkbook("invalid workbook styles") }
            let bases = root.children("cellStyleXfs").first?.children("xf") ?? []
            generalStyles = root.children("cellXfs")[0].children.map { xf in
                guard xf.isNamed("xf", in: Node.sheet), (xf.element[attribute: "numFmtId"] ?? "0") == "0" else { return false }
                guard let base = xf.element[attribute: "xfId"] else { return true }
                guard let index = Int(base), bases.indices.contains(index) else { return false }
                return (bases[index].element[attribute: "numFmtId"] ?? "0") == "0"
            }
        } else { generalStyles = nil }
    }

    func values(for range: ChartWorkbookReader.Range, numeric: Bool) throws -> [String?] {
        let name = range.sheet.lowercased()
        guard let sheet = sheets[name] else { throw Problem.invalidWorkbook("sheet '\(range.sheet)' is missing") }
        if cellsBySheet[name] == nil { cellsBySheet[name] = try load(sheet) }
        let cells = cellsBySheet[name]!
        return try (0..<range.count).map { offset in
            let address = Address(column: range.start.column + (range.start.row == range.end.row ? offset : 0),
                                  row: range.start.row + (range.start.column == range.end.column ? offset : 0))
            guard let cell = cells[address] else { return nil }
            return try value(cell, numeric: numeric)
        }
    }

    private func load(_ part: Part) throws -> [Address: Node] {
        let root = Node(try part.dom())
        guard root.isNamed("worksheet", in: Node.sheet), root.children("sheetData").count == 1 else {
            throw Problem.invalidWorkbook("invalid worksheet/sheetData namespace or structure")
        }
        guard root.children("mergeCells").isEmpty,
              root.children("cols").flatMap({ $0.children("col") }).allSatisfy({ $0.element[attribute: "style"] == nil }) else {
            throw Problem.unsupportedCell("merged cells or inherited column styles")
        }
        var cells: [Address: Node] = [:]
        var rows: Set<Int> = []
        for row in root.children("sheetData")[0].children {
            guard row.isNamed("row", in: Node.sheet), row.element[attribute: "s"] == nil else {
                throw Problem.unsupportedCell("invalid row namespace or inherited row style")
            }
            if let raw = row.element[attribute: "r"] {
                guard let number = Int(raw), (1...1_048_576).contains(number), rows.insert(number).inserted else {
                    throw Problem.invalidWorkbook("duplicate or invalid worksheet row")
                }
            }
            for cell in row.children {
                visitedCells += 1
                guard visitedCells <= 250_000 else { throw Problem.limitExceeded }
                guard cell.isNamed("c", in: Node.sheet), let reference = cell.element[attribute: "r"],
                      let address = Address(reference), cells[address] == nil,
                      row.element[attribute: "r"].map({ Int($0) == address.row }) ?? true else {
                    throw Problem.invalidWorkbook("duplicate, misplaced or invalid worksheet cell")
                }
                cells[address] = cell
            }
        }
        return cells
    }

    private func value(_ cell: Node, numeric: Bool) throws -> String? {
        let label = cell.element[attribute: "r"] ?? "?"
        let children = cell.children
        guard children.allSatisfy({ $0.uri == Node.sheet && ["f", "v", "is", "extLst"].contains($0.local) }),
              cell.children("v").count <= 1, cell.children("f").count <= 1, cell.children("is").count <= 1,
              cell.children("v").first?.element.childElements.isEmpty ?? true else {
            throw Problem.unsupportedCell("\(label): ambiguous value or namespace")
        }
        let raw = cell.children("v").first?.element.textContent
        let type = cell.element[attribute: "t"] ?? "n"
        if !cell.children("f").isEmpty && (raw == nil || raw == "") {
            throw Problem.unsupportedCell("\(label): formula has no stored result")
        }
        if (raw == nil || raw == "") && cell.children("is").isEmpty && cell.children("f").isEmpty && type == "n" { return nil }
        if numeric {
            let style = cell.element[attribute: "s"]
            if let styles = generalStyles {
                guard let index = Int(style ?? "0"), styles.indices.contains(index), styles[index] else {
                    throw Problem.unsupportedCell("\(label): numeric formatting is not General")
                }
            } else if style != nil { throw Problem.unsupportedCell("\(label): missing style table") }
            // Double also accepts hexadecimal syntax, which SpreadsheetML does
            // not use for numeric cells. Keep the persisted cache decimal.
            guard type == "n", cell.children("is").isEmpty, let raw,
                  raw.utf8.allSatisfy({ (48...57).contains($0) || [43, 45, 46, 69, 101].contains($0) }),
                  let number = Double(raw), number.isFinite else {
                throw Problem.unsupportedCell("\(label): expected a finite numeric stored value")
            }
            return raw
        }
        switch type {
        case "s":
            guard cell.children("is").isEmpty, let index = raw.flatMap(Int.init), strings.indices.contains(index) else {
                throw Problem.unsupportedCell("\(label): invalid shared string index")
            }
            return strings[index]
        case "inlineStr":
            guard raw == nil, cell.children("f").isEmpty, let text = cell.children("is").first else {
                throw Problem.unsupportedCell("\(label): invalid inline string")
            }
            return try Self.text(text)
        case "str":
            guard cell.children("is").isEmpty, let raw else { throw Problem.unsupportedCell("\(label): missing string value") }
            return raw
        case "b":
            guard cell.children("is").isEmpty, raw == "0" || raw == "1" else { throw Problem.unsupportedCell("\(label): invalid boolean") }
            return raw == "1" ? "TRUE" : "FALSE"
        default:
            throw Problem.unsupportedCell("\(label): expected text; numeric/date/error label conversion is unsupported")
        }
    }

    private static func related(_ kind: String, from workbook: Part, in package: OPCPackage) throws -> Part? {
        let links = workbook.rels.all(ofType: Node.relationships + "/" + kind)
        guard !links.isEmpty else { return nil }
        guard links.count == 1, !links[0].isExternal,
              workbook.rels.items.filter({ $0.rId == links[0].rId }).count == 1 else {
            throw Problem.invalidWorkbook("ambiguous or external \(kind) relationship")
        }
        return try package.part(at: PackURI.resolve(target: links[0].target, relativeTo: workbook.uri.baseURI))
    }

    private static func text(_ node: Node) throws -> String {
        guard node.children("t").count <= 1,
              node.children("t").isEmpty || node.children("r").isEmpty else {
            throw Problem.unsupportedCell("ambiguous string representation")
        }
        var result = ""
        for child in node.children {
            guard child.uri == Node.sheet else { throw Problem.unsupportedCell("foreign string namespace") }
            switch child.local {
            case "t":
                guard child.element.childElements.isEmpty else { throw Problem.unsupportedCell("invalid string text") }
                result += child.element.textContent
            case "r":
                guard child.children.allSatisfy({ $0.uri == Node.sheet && ["rPr", "t"].contains($0.local) }),
                      child.children("t").count == 1, child.children("t")[0].element.childElements.isEmpty else {
                    throw Problem.unsupportedCell("invalid rich string run")
                }
                result += child.children("t")[0].element.textContent
            case "rPh", "phoneticPr": break // not displayed cell text
            default: throw Problem.unsupportedCell("unsupported string content")
            }
        }
        return result
    }
}
