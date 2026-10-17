import Foundation
import Rostrum
import RostrumLayout

// Build against the current Release modules; arguments: caller font manifest, new output directory.
// Manifest keys: family, regular, bold, italic, boldItalic (font paths absolute).
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: String]
let family = manifest["family"]!
func face(_ role: String) throws -> Data { try Data(contentsOf: URL(fileURLWithPath: manifest[role]!)) }
let faces = try FontFaces(regular: face("regular"), bold: face("bold"), italic: face("italic"), boldItalic: face("boldItalic"))
let output = URL(fileURLWithPath: CommandLine.arguments[2])
precondition(!FileManager.default.fileExists(atPath: output.path), "Use a new output directory")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (name, width) in [("4x3", 720.0), ("16x9", 960.0)] {
    let source = try Presentation()
    source.slideSize = (.points(width), .points(540))
    source.theme.majorFont = family; source.theme.minorFont = family
    try source.embedFont(family, faces: faces)
    let layout = source.layout(type: "obj")!
    let tree = try layout.part.dom().firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!
    for shape in tree.children(named: "p:sp") {
        guard let placeholder = shape.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph") else { continue }
        let index = Int(placeholder[attribute: "idx"] ?? "0") ?? 0
        guard index == 0 || index == 1 else { continue }
        let properties = shape.firstChild(named: "p:spPr")!
        properties.children.removeAll { if case .element(let e) = $0 { return e.name == "a:xfrm" }; return false }
        properties.appendElement(XML.Element("a:xfrm", children: [
            .element(XML.Element("a:off", attributes: [("x", String(EMU.points(44).rawValue)), ("y", String(EMU.points(index == 0 ? 28 : 125).rawValue))])),
            .element(XML.Element("a:ext", attributes: [("cx", String(EMU.points(width - 88).rawValue)), ("cy", String(EMU.points(index == 0 ? 72 : 355).rawValue))]))]))
        if index == 0 {
            shape.firstChild(named: "p:txBody")!.firstChild(named: "a:lstStyle")!.appendElement(
                XML.Element("a:lvl1pPr", children: [.element(XML.Element("a:defRPr", attributes: [("sz", "3000")]))]))
        }
    }
    layout.part.markDirty()
    source.documentKind = .template
    let deck = try Presentation.fromTemplate(data: source.serializedData())
    _ = deck.registerEmbeddedFonts()
    let engine = TemplateLayoutEngine(presentation: deck)
    for headerCount in [2, 3] {
        var directions: [TableCellTextDirection] = []
        var rows: [[String]]
        var merges: [TableMergeRegion]
        if headerCount == 2 {
            rows = [["Source", "Evidence", ""], ["", "Observation", "State"]]
            directions = [.init(row: 0, column: 0, direction: .vertical)]
            merges = [.init(row: 0, column: 0, rowSpan: 2, columnSpan: 1), .init(row: 0, column: 1, rowSpan: 1, columnSpan: 2)]
        } else {
            rows = [["Grouped source evidence", "", "State"], ["", "", ""], ["Source", "Observation", ""]]
            directions = [.init(row: 0, column: 2, direction: .vertical270)]
            merges = [.init(row: 0, column: 0, rowSpan: 2, columnSpan: 2), .init(row: 0, column: 2, rowSpan: 3, columnSpan: 1)]
        }
        for group in 1...8 {
            let row = rows.count
            rows += [["Group \(group)", "The first observation for source \(group).", "Ready"],
                     ["", "Every original word remains editable.", "Saved"]]
            merges.append(.init(row: row, column: 0, rowSpan: 2, columnSpan: 1))
            directions.append(.init(row: row, column: 0, direction: group % 2 == 0 ? .vertical : .vertical270))
        }
        let plan = try engine.planTablePages(title: "Rotated labels: \(headerCount)-row headers", table: .init(rows: rows,
            columnWeights: [1, 3, 1], columnSizing: .measured(), merges: merges, headerRowCount: headerCount, textDirections: directions),
            caption: "Labels rotate at full size. Complete headers and source groups stay together.")
        let slides = try engine.composeTablePages(plan)
        for slide in slides { try slide.setNotes("New rotated table-text regression case. Caller-selected faces embedded. Native slide-view and PDF-export acceptance pending.") }
    }
    let file = output.appendingPathComponent("Rotated-Tables-\(name).pptx")
    let bytes = try deck.serializedData()
    try bytes.write(to: file)
    let reopened = try Presentation(data: bytes)
    _ = reopened.registerEmbeddedFonts()
    for index in 0..<reopened.slides.count {
        let frame = try reopened.slides[index].shapes.all.compactMap { $0 as? TableFrame }.first!
        let table = frame.table!
        let measured = try TableLayoutEngine(presentation: reopened).plan(table)
        precondition(measured.fits && frame.frame.maxY <= reopened.bounds.height)
        let heights = try (0..<table.rowCount).map { try table.rowHeight($0) }
        for cell in measured.cells where !cell.isMergeContinuation {
            let height = heights[cell.row..<(cell.row + cell.rowSpan)].reduce(.zero, +)
            precondition(cell.requiredHeight <= height)
            let text = try table.cell(cell.row, cell.column).existingTextFrame!
            let width = measured.columnWidths[cell.column..<(cell.column + cell.columnSpan)].reduce(.zero, +)
            precondition(text.fitText(in: Rect(x: .zero, y: .zero, width: width, height: height),
                fonts: reopened.fonts, theme: reopened.theme).fits)
        }
        let beforeSVG = try deck.renderSVG(slideAt: index), afterSVG = try reopened.renderSVG(slideAt: index)
        precondition(beforeSVG == afterSVG)
        try Data(reopened.renderSVG(slideAt: index).utf8).write(to: output.appendingPathComponent("\(name)-slide-\(index + 1).svg"))
    }
    print("\(file.lastPathComponent): \(reopened.slides.count) slides")
}
