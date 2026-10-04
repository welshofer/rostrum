import Foundation
import Rostrum

/// Owned, small integration fixture. Fixed IDs/dates make regeneration stable;
/// no network, system font lookup, GUI or provider credentials are involved.
enum FeaturePipelineFixture {
    static let pixels = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAG0lEQVR4nGP4z8DwH4SRIJoAlA8EDA0gjCEAAE9EIeGwsrFwAAAAAElFTkSuQmCC")!
    static let importedStyle = "{D7A44270-6C32-4D03-8B93-92DFA6319620}"

    static func make() throws -> Presentation {
        let deck = try Presentation()
        deck.documentProperties.title = "Lectern feature pipeline"
        deck.documentProperties.author = "Rostrum tests"
        deck.documentProperties.created = Date(timeIntervalSince1970: 0)
        deck.documentProperties.modified = Date(timeIntervalSince1970: 0)
        let tableSlide = try deck.slides[0]
        let table = try tableSlide.shapes.addTable(rows: 3, columns: 3,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(3)))
        table.applyBuiltInStyle(.mediumStyle2Accent1)
        table.firstRowHeader = true
        table.bandedRows = true
        for (row, values) in [["Quarter", "Plan", "Actual"], ["North", "12", "15"], ["Total", "27", ""]].enumerated() {
            for (column, value) in values.enumerated() { try table.cell(row, column).text = value }
        }
        try table.merge(row: 2, column: 1, rowSpan: 1, columnSpan: 2)
        try table.cell(0, 0).setBorder(.bottom, line: Line(color: Color("336699"), width: .points(4), compound: .double, dash: .solid))
        try table.cell(1, 0).setBorder(.bottom, line: Line(color: Color("336699"), width: .points(2), compound: .single, dash: .dash))
        try tableSlide.setNotes("Explain the quarterly table.\nThe merged total is intentional.")

        let mediaSlide = try deck.slides.add()
        let box = try mediaSlide.shapes.addTextBox(Rect(x: .inches(1), y: .inches(0.5), width: .inches(8), height: .inches(1)))
        guard let text = box.textFrame else { throw RostrumError.packageInvalid("text fixture has no text frame") }
        text.clear()
        let paragraph = text.addParagraph()
        let strong = paragraph.addRun("Revenue "); strong.bold = true; strong.fontSize = 24
        let emphasis = paragraph.addRun("grew 25%"); emphasis.italic = true; emphasis.fontSize = 24
        let picture = try mediaSlide.shapes.addPicture(pixels,
            frame: Rect(x: .inches(1), y: .inches(2), width: .inches(3), height: .inches(2)))
        try picture.setCrop(PictureCrop(left: 0.5, bottom: 0.25))
        try mediaSlide.setNotes("Discuss the cropped green and yellow quadrants.")
        let thread = try mediaSlide.addComment("Check the revenue source.", author: "Ada Lovelace", initials: "AL")
        try thread.addReply("Source verified against the ledger.", author: "Grace Hopper", initials: "GH")
        thread.resolve()
        try mediaSlide.addLegacyComment("Keep the original image bytes.", author: "Legacy Reviewer", initials: "LR")
        _ = try deck.slides.duplicate(at: 1)

        let source = try Presentation()
        let imported = try source.slides[0].shapes.addTable(rows: 1, columns: 2,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(1)))
        try imported.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(importedStyle)" styleName="Pipeline custom style"><a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val="DCF4E6"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl></a:tblStyle>
        """.utf8)))
        try imported.cell(0, 0).text = "Imported style"
        try imported.cell(0, 1).text = "Preserved graph"
        _ = try deck.slides.import(from: source, at: 0)
        try deck.setSections([("Tables", 0), ("Evidence and copies", 1), ("Imported", 3)])
        try fixIDsAndDates(deck)
        return deck
    }

    private static func fixIDsAndDates(_ deck: Presentation) throws {
        var identifiers: [String: String] = [:]
        var roots: [(Part, XML.Element)] = []
        for part in deck.package.parts.values.sorted(by: { $0.uri.value < $1.uri.value }) where part.contentType.contains("xml") {
            roots.append((part, try part.dom()))
        }
        for (_, root) in roots {
            var pending = [root]
            while let node = pending.popLast() {
                let local = node.name.split(separator: ":").last.map(String.init) ?? node.name
                if ["author", "cm", "reply", "section"].contains(local),
                   let id = node[attribute: "id"], id.hasPrefix("{"), identifiers[id] == nil {
                    identifiers[id] = String(format: "{00000000-0000-4000-8000-%012d}", identifiers.count + 1)
                }
                pending.append(contentsOf: node.childElements.reversed())
            }
        }
        for (part, root) in roots {
            var pending = [root], changed = false
            while let node = pending.popLast() {
                for key in ["id", "authorId"] {
                    if let old = node[attribute: key], let fixed = identifiers[old] { node[attribute: key] = fixed; changed = true }
                }
                let local = node.name.split(separator: ":").last.map(String.init) ?? node.name
                if ["cm", "reply"].contains(local) {
                    for key in ["created", "dt"] where node[attribute: key] != nil {
                        node[attribute: key] = "2026-10-02T12:00:00.000"; changed = true
                    }
                }
                pending.append(contentsOf: node.childElements)
            }
            if changed { part.markDirty() }
        }
    }
}
