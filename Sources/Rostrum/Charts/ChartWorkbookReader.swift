import Foundation

/// Read-only fallback for classic chart references whose XML cache is absent.
/// Only local A1 cells and one-dimensional ranges are supported. Formula cells
/// contribute their stored result; no formula evaluation or external I/O occurs.
final class ChartWorkbookReader {
    struct Cell {
        let text: String
        let number: Double?
    }
    struct Address: Hashable {
        let column: Int
        let row: Int
        init?(_ reference: String) {
            guard reference.utf8.count <= 12,
                  reference.range(of: "^\\$?[A-Za-z]{1,3}\\$?[1-9][0-9]{0,6}$", options: .regularExpression) != nil else { return nil }
            let bytes = Array(reference.uppercased().utf8).filter { $0 != 36 }
            var column = 0, index = 0
            while index < bytes.count, (65...90).contains(bytes[index]) {
                column = column * 26 + Int(bytes[index] - 64); index += 1
            }
            guard column <= 16_384, let row = Int(String(decoding: bytes[index...], as: UTF8.self)), row <= 1_048_576 else { return nil }
            self.column = column; self.row = row
        }
        init(column: Int, row: Int) { self.column = column; self.row = row }
    }
    struct Range {
        let sheet: String
        let start: Address
        let end: Address
        var count: Int { max(end.row - start.row, end.column - start.column) + 1 }
        init?(_ formula: String) {
            guard formula.utf8.count <= 1024, !formula.contains("["), !formula.contains("]"),
                  let bang = formula.lastIndex(of: "!") else { return nil }
            var sheet = String(formula[..<bang])
            if sheet.hasPrefix("'") && sheet.hasSuffix("'") && sheet.count >= 2 {
                let inner = String(sheet.dropFirst().dropLast())
                guard !inner.replacingOccurrences(of: "''", with: "").contains("'") else { return nil }
                sheet = inner.replacingOccurrences(of: "''", with: "'")
            } else if !sheet.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "." }) { return nil }
            guard !sheet.isEmpty, !sheet.contains(":"), !sheet.contains("/") else { return nil }
            let cells = formula[formula.index(after: bang)...].split(separator: ":", omittingEmptySubsequences: false)
            guard (1...2).contains(cells.count), let start = Address(String(cells[0])),
                  let end = Address(String(cells.last!)), end.row >= start.row, end.column >= start.column,
                  end.row == start.row || end.column == start.column,
                  max(end.row - start.row, end.column - start.column) < 100_000 else { return nil }
            self.sheet = sheet; self.start = start; self.end = end
        }
    }

    private let sheets: [String: Part]
    private let sharedStrings: [String]
    private var sheetCache: [String: [Address: Cell]] = [:]
    private var unreadableSheets: Set<String> = []

    init(data: Data) throws {
        guard data.count <= 64 << 20 else { throw RostrumError.packageInvalid("chart workbook exceeds read budget") }
        let package = try OPCPackage.read(data: data, limits: .init(totalUncompressedBytes: 64 << 20))
        guard let rootRel = package.rels.first(ofType: RelType.officeDocument), !rootRel.isExternal else {
            throw RostrumError.packageInvalid("chart workbook has no internal workbook part")
        }
        let workbook = try package.mainDocumentPart()
        let dom = try workbook.dom()
        guard Self.localName(dom) == "workbook" else { throw RostrumError.packageInvalid("chart data is not a workbook") }
        var sheets: [String: Part] = [:]
        for sheet in Self.child(dom, "sheets")?.childElements ?? [] where Self.localName(sheet) == "sheet" {
            guard let name = sheet[attribute: "name"], let id = sheet[attribute: "r:id"],
                  let rel = workbook.rels.relationship(withId: id), !rel.isExternal,
                  rel.type.hasSuffix("/worksheet"),
                  let part = try? package.part(at: PackURI.resolve(target: rel.target, relativeTo: workbook.uri.baseURI)) else { continue }
            sheets[name.lowercased()] = part
        }
        self.sheets = sheets
        if let rel = workbook.rels.items.first(where: { $0.type.hasSuffix("/sharedStrings") && !$0.isExternal }),
           let part = try? package.part(at: PackURI.resolve(target: rel.target, relativeTo: workbook.uri.baseURI)),
           let strings = try? part.dom() {
            let items = strings.childElements.filter { Self.localName($0) == "si" }
            guard items.count <= 1_000_000 else { throw RostrumError.packageInvalid("too many shared chart strings") }
            sharedStrings = items.map(Self.stringContent)
        } else { sharedStrings = [] }
    }

    func cells(for formula: String) -> [Cell?]? {
        guard let range = Range(formula), let part = sheets[range.sheet.lowercased()] else { return nil }
        let name = range.sheet.lowercased()
        guard !unreadableSheets.contains(name) else { return nil }
        if sheetCache[name] == nil {
            guard let dom = try? part.dom(), Self.localName(dom) == "worksheet" else {
                unreadableSheets.insert(name)
                return nil
            }
            var values: [Address: Cell] = [:]
            var visited = 0
            for row in Self.child(dom, "sheetData")?.childElements ?? [] where Self.localName(row) == "row" {
                for cell in row.childElements where Self.localName(cell) == "c" {
                    visited += 1
                    guard visited <= 1_000_000 else {
                        unreadableSheets.insert(name)
                        return nil
                    }
                    guard let ref = cell[attribute: "r"], let address = Address(ref) else { continue }
                    let raw = Self.child(cell, "v")?.textContent
                    let result: Cell?
                    switch cell[attribute: "t"] ?? "n" {
                    case "s":
                        if let index = raw.flatMap(Int.init), sharedStrings.indices.contains(index) {
                            result = Cell(text: sharedStrings[index], number: nil)
                        } else { result = nil }
                    case "inlineStr": result = Self.child(cell, "is").map { Cell(text: Self.stringContent($0), number: nil) }
                    case "str", "d": result = raw.map { Cell(text: $0, number: nil) }
                    case "b": result = raw.flatMap { $0 == "1" ? Cell(text: "TRUE", number: nil) : $0 == "0" ? Cell(text: "FALSE", number: nil) : nil }
                    case "n":
                        if let raw, let number = Double(raw), number.isFinite { result = Cell(text: raw, number: number) }
                        else { result = nil }
                    default: result = nil // errors and unknown cell types remain gaps
                    }
                    values[address] = result
                }
            }
            sheetCache[name] = values
        }
        let values = sheetCache[name] ?? [:]
        return (0..<range.count).map { index in
            values[Address(column: range.start.column + (range.start.row == range.end.row ? index : 0),
                           row: range.start.row + (range.start.column == range.end.column ? index : 0))]
        }
    }

    private static func localName(_ element: XML.Element) -> String { String(element.name.split(separator: ":").last ?? "") }
    private static func child(_ element: XML.Element, _ name: String) -> XML.Element? {
        element.childElements.first { localName($0) == name }
    }
    private static func stringContent(_ element: XML.Element) -> String {
        element.childElements.map { part in
            if localName(part) == "t" { return part.textContent }
            if localName(part) == "r" { return child(part, "t")?.textContent ?? "" }
            return "" // exclude phonetic annotations
        }.joined()
    }
}
