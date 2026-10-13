import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TableCellPreparationTests {
    private func fixture(rows: [[String]]) throws -> (Presentation, Table) {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        let fonts = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: fonts.appendingPathComponent(face + ".ttf"))
        }
        let table = try deck.slides[0].shapes.addTable(rows: rows.count, columns: rows[0].count, frame: deck.bounds)
        table.setLayoutContents(rows, font: "DejaVu Sans", size: 18)
        return (deck, table)
    }

    private func equal(_ actual: TableLayoutPlan, _ expected: TableLayoutPlan) {
        #expect(actual.columnWidths == expected.columnWidths)
        #expect(actual.rowHeights == expected.rowHeights)
        #expect(actual.totalHeight == expected.totalHeight && actual.fits == expected.fits)
        #expect(actual.cells.count == expected.cells.count)
        for (a, b) in zip(actual.cells, expected.cells) {
            #expect(a.row == b.row && a.column == b.column && a.requiredHeight == b.requiredHeight)
            #expect(a.issues == b.issues && a.diagnostics == b.diagnostics)
        }
    }

    @Test func preparedTrialsMatchFreshRichCellsAndNativeBandStyles() throws {
        let (deck, table) = try fixture(rows: [["Header", "Value"], ["é", "e\u{301}"],
            ["First\t12.34\nSecond", "مرحبا بالعالم"], ["Δοκιμή 日本語", "Missing face"],
            ["Repeated words with more wrapping", "Repeated words with more wrapping"]])
        try table.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(Table.defaultStyleGUID)" styleName="Different native bands">
          <a:wholeTbl><a:tcTxStyle b="off" i="off"/></a:wholeTbl>
          <a:band1H><a:tcTxStyle b="on"/></a:band1H>
          <a:band2H><a:tcTxStyle i="on"/></a:band2H>
          <a:firstRow><a:tcTxStyle b="on"/></a:firstRow>
        </a:tblStyle>
        """.utf8)))
        let rich = try table.cell(2, 0)
        rich.setPadding(left: .points(13), top: .points(8), right: .points(11), bottom: .points(7))
        let paragraph = try #require(rich.textFrame.paragraphs.first)
        paragraph.p.children.insert(.element(try XML.parse(Data("""
        <a:pPr><a:lnSpc><a:spcPts val="3200"/></a:lnSpc><a:spcAft><a:spcPts val="800"/></a:spcAft><a:tabLst><a:tab pos="500000" algn="dec"/></a:tabLst></a:pPr>
        """.utf8))), at: 0)
        let run = paragraph.addRun(" Italic tail")
        run.fontSize = 24; run.italic = true; run.fontName = "DejaVu Sans"
        try table.cell(3, 1).textFrame.paragraphs.first?.runs.first?.fontName = "Unregistered face"
        let before = try deck.serializedData()
        let engine = TableLayoutEngine(presentation: deck)
        for pagination in [false, true] {
            let reuse = try TableColumnMeasurements(table: table, theme: deck.theme)
            for width in [150.0, 60, 220, 150, 95] {
                let widths: [EMU] = [.points(width), .points(320 - width)]
                let expected = try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(30),
                    theme: deck.theme, pagination: pagination)
                let actual = try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(30),
                    theme: deck.theme, pagination: pagination, reuse: reuse)
                equal(actual, expected)
            }
            #expect(reuse.preparation.cellCount == 10 && reuse.preparation.textCount > 0)
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func unsupportedInputsRetainOrderedIssuesAcrossTrials() throws {
        let (deck, table) = try fixture(rows: [["Header", "Value"], ["Not supported", "42"]])
        try table.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2)
        let body = try #require(table.cell(1, 0).tc.firstChild(named: "a:txBody")?.firstChild(named: "a:bodyPr"))
        body[attribute: "vert"] = "vert"; body[attribute: "rot"] = "60000"; body[attribute: "numCol"] = "2"
        body.appendElement(XML.Element("a:normAutofit", attributes: [("lnSpcReduction", "10000")]))
        let engine = TableLayoutEngine(presentation: deck), reuse = try TableColumnMeasurements(table: table, theme: deck.theme)
        for width in [70.0, 170] {
            let widths: [EMU] = [.points(width), .points(300 - width)]
            let expected = try engine.plan(table, columnWidths: widths, minimumRowHeight: .zero)
            let actual = try engine.plan(table, columnWidths: widths, minimumRowHeight: .zero,
                theme: deck.theme, pagination: false, reuse: reuse)
            equal(actual, expected)
            #expect(!actual.fits)
        }
    }

    @Test func fullPreparationCacheFallsBackWithoutChangingGeometry() throws {
        let rows = (0..<1100).map { ["Unique \($0)", "Repeated observation wraps at narrow widths"] }
        let (deck, table) = try fixture(rows: rows)
        let engine = TableLayoutEngine(presentation: deck), reuse = try TableColumnMeasurements(table: table, theme: deck.theme)
        for width in [100.0, 130, 85] {
            let widths: [EMU] = [.points(width), .points(400 - width)]
            equal(try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(30),
                theme: deck.theme, pagination: true, reuse: reuse),
                try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(30), theme: deck.theme, pagination: true))
        }
        #expect(reuse.preparation.textCount == 1024)
        #expect(reuse.preparation.cellCount == rows.count * 2)
    }

    @Test func newOperationsObserveTextStyleAndFontChanges() throws {
        let (deck, table) = try fixture(rows: [["Header", "Value"], ["Words need wrapping", "42"]])
        table.setLayoutContents([["Header", "Value"], ["Words need wrapping", "42"]], font: "Registered later", size: 18)
        let engine = TableLayoutEngine(presentation: deck)
        func fresh() throws -> TableLayoutPlan {
            try engine.plan(table, columnWidths: [.points(110), .points(210)], minimumRowHeight: .points(30),
                theme: deck.theme, pagination: true, reuse: TableColumnMeasurements(table: table, theme: deck.theme))
        }
        let before = try fresh()
        let missing = ShapingDiagnostic.unsupportedLayoutFeature("Unregistered font face: Registered later")
        #expect(before.cells.contains { $0.diagnostics.contains(missing) })
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        try deck.fonts.register(contentsOf: font, aliases: ["Registered later"])
        let after = try fresh()
        #expect(!after.cells.contains { $0.diagnostics.contains(missing) })
        try table.cell(1, 0).text = "Many more exact words now need more room to wrap correctly"
        try table.cell(1, 0).textFrame.paragraphs.first?.runs.first?.fontSize = 28
        let changed = try fresh()
        #expect(changed.rowHeights[1] > after.rowHeights[1])
        equal(changed, try engine.plan(table, columnWidths: [.points(110), .points(210)],
            minimumRowHeight: .points(30), theme: deck.theme, pagination: true))
    }
}
