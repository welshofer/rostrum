import Foundation
import Testing
@testable import Rostrum

@Suite struct TableAuthoringAlignmentTests {
    private func table(in deck: Presentation) throws -> Table {
        try #require((deck.slides[0].shapes.all.first as? TableFrame)?.table)
    }

    @Test func newCellsAreExplicitlyCenteredAndSurviveSaving() throws {
        let deck = try Presentation()
        let original = try deck.slides[0].shapes.addTable(rows: 2, columns: 3,
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(2)))
        original.setContents([["Header", "Value", "Status"], ["Wrapped\ntext", "42", "Ready"]])
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        for candidate in [original, try table(in: reopened)] {
            for row in 0..<2 { for column in 0..<3 {
                let cell = try candidate.cell(row, column)
                #expect(cell.verticalAnchor == .middle)
                #expect(cell.tc.firstChild(named: "a:tcPr")?[attribute: "anchor"] == "ctr")
            } }
        }
        #expect(try reopened.serializedData() == bytes)
    }

    @Test func insertedCellsCenterWithoutChangingExistingOrImplicitImportedAnchors() throws {
        let deck = try Presentation()
        let authored = try deck.slides[0].shapes.addTable(rows: 1, columns: 3,
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(2)))
        try authored.cell(0, 0).verticalAnchor = .top
        try authored.cell(0, 1).verticalAnchor = .bottom
        let implicit = try authored.cell(0, 2)
        implicit.tcPr[attribute: "anchor"] = nil
        implicit.tcPr.appendElement(XML.Element("a:extLst", children: [.comment("retained unknown cell XML")]))
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        let imported = try table(in: reopened)
        let implicitBefore = try imported.cell(0, 2).tc.serialized()
        #expect(try imported.cell(0, 0).verticalAnchor == .top)
        #expect(try imported.cell(0, 1).verticalAnchor == .bottom)
        #expect(try imported.cell(0, 2).verticalAnchor == .top)
        #expect(try reopened.serializedData() == bytes)
        try imported.insertRow(at: 1)
        try imported.insertColumn(at: 3)
        #expect(try imported.cell(0, 0).verticalAnchor == .top)
        #expect(try imported.cell(0, 1).verticalAnchor == .bottom)
        #expect(try imported.cell(0, 2).tc.serialized() == implicitBefore)
        #expect(try imported.cell(0, 3).verticalAnchor == .middle)
        for column in 0..<4 { #expect(try imported.cell(1, column).verticalAnchor == .middle) }
        let saved = try Presentation(data: reopened.serializedData())
        #expect(try table(in: saved).cell(0, 2).tc.serialized() == implicitBefore)
    }

    @Test func defaultCenterRendersHalfwayBetweenExplicitTopAndBottom() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .points(200), height: .points(100)))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        cell.text = "Centered row"
        cell.textFrame.paragraphs[0].runs[0].fontSize = 12
        func baseline() throws -> Double {
            let xml = try XML.parse(Data(deck.renderSVG(slideAt: 0).utf8))
            var pending = [xml]
            while let node = pending.popLast() {
                if node.name == "text", let transform = node[attribute: "transform"] {
                    let pair = transform.components(separatedBy: "translate(").last?.components(separatedBy: ")").first
                    return try #require(pair?.split(separator: ",").last.flatMap { Double($0) })
                }
                pending.append(contentsOf: node.childElements)
            }
            throw RostrumError.packageInvalid("Rendered table text missing")
        }
        let centered = try baseline()
        cell.verticalAnchor = .top
        let top = try baseline()
        cell.verticalAnchor = .bottom
        let bottom = try baseline()
        #expect(top < centered && centered < bottom)
        #expect(abs(centered - (top + bottom) / 2) < 0.01)
    }
}
