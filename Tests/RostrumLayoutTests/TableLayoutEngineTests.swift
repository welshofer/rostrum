import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TableLayoutEngineTests {
    private func fixture(rows: [[String]] = [["Wrapped header", "Value"], ["Some longer cell text wraps on narrow columns", "42"]]) throws -> (Presentation, Table) {
        let deck = try Presentation()
        let fonts = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: fonts.appendingPathComponent(face + ".ttf"))
        }
        deck.theme.minorFont = "DejaVu Sans"
        let slide = try deck.slides[0]
        let table = try slide.shapes.addTable(rows: rows.count, columns: rows[0].count,
            frame: Rect(x: .points(30), y: .points(40), width: .points(300), height: .points(60)))
        table.setLayoutContents(rows, font: "DejaVu Sans", size: 18)
        return (deck, table)
    }

    private func assertSavedCellsFit(_ table: Table, plan: TableLayoutPlan, deck: Presentation) throws {
        table.columnWidths(plan.columnWidths).rowHeights(plan.rowHeights)
        let reopened = try Presentation(data: deck.serializedData())
        // Fonts remain operation-local; the fixture deliberately does not embed them.
        let saved = try #require((reopened.slides[0].shapes.all.first { $0 is TableFrame } as? TableFrame)?.table)
        for row in plan.rowHeights.indices { for column in plan.columnWidths.indices {
            let cell = try saved.cell(row, column)
            let result = try #require(cell.existingTextFrame).fitText(in: Rect(x: .zero, y: .zero,
                width: plan.columnWidths[column], height: plan.rowHeights[row]), fonts: deck.fonts, theme: reopened.theme)
            #expect(result.fits)
            #expect(result.fontScale == 100)
        } }
    }

    @Test func resolvedStylesMarginsAndRichTextFitAfterReopening() throws {
        let (deck, table) = try fixture()
        let cell = try table.cell(1, 0)
        cell.setPadding(left: .points(20), top: .points(12), right: .points(15), bottom: .points(9))
        let paragraph = try #require(cell.textFrame.paragraphs.first)
        paragraph.p.appendElement(XML.Element("a:br"))
        let run = paragraph.addRun("Italic tail")
        run.italic = true; run.fontSize = 24; run.fontName = "DejaVu Sans"
        let before = try deck.serializedData()
        let plan = try TableLayoutEngine(presentation: deck).plan(table)
        #expect(plan.fits)
        #expect(plan.rowHeights[1] > plan.rowHeights[0])
        #expect(try deck.serializedData() == before)
        try assertSavedCellsFit(table, plan: plan, deck: deck)
    }

    @Test func mutationsAndWidthChangesAreMeasuredAgain() throws {
        let (deck, table) = try fixture()
        let engine = TableLayoutEngine(presentation: deck)
        let original = try engine.plan(table)
        let narrower = try engine.plan(table, columnWidths: [.points(80), .points(220)])
        #expect(narrower.rowHeights[1] > original.rowHeights[1])
        try table.cell(1, 0).textFrame.paragraphs.first?.runs.first?.fontSize = 42
        let changed = try engine.plan(table)
        #expect(changed.rowHeights[1] > original.rowHeights[1])
        #expect(try !engine.plan(table, maximumHeight: .points(10)).fits)
    }

    @Test func unsupportedCellsHaveCoordinatesAndDoNotMutate() throws {
        let (deck, table) = try fixture()
        try table.merge(row: 0, column: 1, rowSpan: 2, columnSpan: 1)
        let cell = try table.cell(1, 0)
        cell.tc.getOrAddChild("a:tcPr")[attribute: "vert"] = "eaVert"
        let before = try deck.serializedData()
        let plan = try TableLayoutEngine(presentation: deck).plan(table)
        #expect(!plan.fits)
        #expect(plan.cells.first { $0.row == 0 && $0.column == 1 }?.rowSpan == 2)
        #expect(plan.cells.first { $0.row == 0 && $0.column == 1 }?.issues.isEmpty == true)
        #expect(plan.cells.first { $0.row == 1 && $0.column == 0 }?.issues == [.verticalText])
        #expect(try deck.serializedData() == before)
    }

    @Test func overwideTextAndLineLimitCannotBeApproved() throws {
        let (deck, table) = try fixture(rows: [["No wrap cannot fit", "Value"], [Array(repeating: "Line", count: 65).joined(separator: "\n"), "42"]])
        try table.cell(0, 0).tc.firstChild(named: "a:txBody")?.firstChild(named: "a:bodyPr")?[attribute: "wrap"] = "none"
        let plan = try TableLayoutEngine(presentation: deck).plan(table, columnWidths: [.points(50), .points(250)])
        #expect(!plan.fits)
        #expect(plan.cells[0].issues.contains(.horizontalOverflow))
        #expect(plan.cells[2].issues.contains(.lineLimit))
    }

    @Test func tableScaleIsIgnoredAndUnverifiedReductionIsRejected() throws {
        let (deck, table) = try fixture()
        let engine = TableLayoutEngine(presentation: deck)
        let original = try engine.plan(table)
        let body = try #require(table.cell(1, 0).tc.firstChild(named: "a:txBody")?.firstChild(named: "a:bodyPr"))
        let autofit = XML.Element("a:normAutofit", attributes: [("fontScale", "50000")])
        body.appendElement(autofit)
        let scaled = try engine.plan(table)
        #expect(scaled.rowHeights == original.rowHeights)
        #expect(!scaled.cells[2].diagnostics.isEmpty)
        autofit[attribute: "lnSpcReduction"] = "10000"
        #expect(try engine.plan(table).cells[2].issues == [.lineSpacingReduction])
    }

    @Test func malformedInputFailsBeforeComposition() throws {
        let (deck, table) = try fixture()
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) { try TableLayoutEngine(presentation: deck).plan(table, columnWidths: [.zero]) }
        #expect(throws: LayoutError.self) {
            try TemplateLayoutEngine(presentation: deck).plan(title: "Table", columns: [], preferredTypes: ["obj"],
                object: "tbl", table: TemplateTableContent(rows: [["Header"], ["Too", "many"]]))
        }
        #expect(try deck.serializedData() == before)
        table.tbl.children(named: "a:tr")[1].removeChildren(named: "a:tc")
        #expect(throws: RostrumError.self) { try TableLayoutEngine(presentation: deck).plan(table) }
    }

    @Test func existingTrailingValidationClosuresRemainSourceCompatible() throws {
        let (deck, _) = try fixture()
        var validated = false
        _ = try TemplateLayoutEngine(presentation: deck).plan(title: "Table", columns: [],
            preferredTypes: ["obj"], object: "tbl", measureObjectHeight: nil) { frame, _ in
                validated = true
                #expect(frame.width > .zero)
            }
        #expect(validated)
    }

    @Test func changedTableTypographyCannotLeaveAPartialSlide() throws {
        let (deck, _) = try fixture()
        let engine = TemplateLayoutEngine(presentation: deck)
        let content = TemplateTableContent(rows: (0..<7).map { ["Row \($0)", "Wrapped table content with several words"] })
        let plan = try engine.plan(title: "Table", columns: [], preferredTypes: ["obj"], object: "tbl", table: content)
        deck.slideSize = (width: deck.slideSize.width, height: .points(2160))
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) { try engine.compose(plan, title: "Table", columns: []) }
        #expect(try deck.serializedData() == before)
    }

    @Test func paragraphSpacingBreaksAndByteDistinctCellsMatchIndependentFits() throws {
        let (deck, table) = try fixture(rows: [["é", "e\u{301}"], ["First\nSecond\t3\n", "Last"]])
        table.clearBuiltInStyle()
        let cell = try table.cell(1, 0)
        let paragraph = try #require(cell.textFrame.paragraphs.first)
        let properties = XML.Element("a:pPr", children: [
            .element(XML.Element("a:lnSpc", children: [.element(XML.Element("a:spcPts", attributes: [("val", "3200")]))])),
            .element(XML.Element("a:spcAft", children: [.element(XML.Element("a:spcPts", attributes: [("val", "800")]))]))])
        paragraph.p.children.insert(.element(properties), at: 0)
        let plan = try TableLayoutEngine(presentation: deck).plan(table)
        #expect(plan.fits)
        try assertSavedCellsFit(table, plan: plan, deck: deck)
    }

    @Test func newlyRegisteredFontsInvalidateEarlierMeasurements() throws {
        let (deck, table) = try fixture()
        table.setLayoutContents([["Header", "Value"], ["Long words need measured line wrapping", "42"]], font: "Registered later", size: 18)
        let engine = TableLayoutEngine(presentation: deck)
        let before = try engine.plan(table)
        let missing = ShapingDiagnostic.unsupportedLayoutFeature("Unregistered font face: Registered later")
        #expect(before.cells[2].diagnostics.contains(missing))
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        try deck.fonts.register(contentsOf: font, aliases: ["Registered later"])
        let after = try engine.plan(table)
        #expect(!after.cells[2].diagnostics.contains(missing))
        #expect(after.rowHeights == (try TableLayoutEngine(presentation: deck).plan(table)).rowHeights)
    }

    @Test(arguments: ["vert", "rot", "numCol", "field"])
    func unsupportedBodyGeometryIsExplicit(property: String) throws {
        let (deck, table) = try fixture()
        let text = try #require(table.cell(1, 0).tc.firstChild(named: "a:txBody"))
        let body = try #require(text.firstChild(named: "a:bodyPr"))
        let expected: TableLayoutIssue
        switch property {
        case "vert": body[attribute: property] = "vert270"; expected = .verticalText
        case "rot": body[attribute: property] = "60000"; expected = .rotatedText
        case "numCol": body[attribute: property] = "2"; expected = .multipleTextColumns
        default:
            text.firstChild(named: "a:p")?.appendElement(XML.Element("a:fld", attributes: [("type", "slidenum")]))
            expected = .dynamicField
        }
        let plan = try TableLayoutEngine(presentation: deck).plan(table)
        #expect(!plan.fits && plan.cells[2].issues.contains(expected))
    }

    @Test func templateTableCaptionAndSourcePartsSurviveReopening() throws {
        let (deck, _) = try fixture()
        let engine = TemplateLayoutEngine(presentation: deck)
        let content = TemplateTableContent(rows: [["Term", "Definition"], ["Shared geometry", "Measure the actual native table cell styles"]])
        _ = try deck.serializedData()
        let before = Dictionary(uniqueKeysWithValues: deck.package.parts.values.filter {
            $0.uri.value.hasPrefix("/ppt/slideLayouts/") || $0.uri.value.hasPrefix("/ppt/slideMasters/") || $0.uri.value.hasPrefix("/ppt/theme/")
        }.map { ($0.uri, $0.blob) })
        let plan = try engine.plan(title: "Table", columns: [], preferredTypes: ["obj"], object: "tbl",
            objectCaption: "The caption retains its own space.", table: content)
        let measured = try #require(plan.tableLayout)
        #expect(measured.fits)
        let slide = try engine.compose(plan, title: "Table", columns: [])
        let shape = try #require(slide.shapes.all.first { $0 is TableFrame })
        #expect(shape.frame.height == measured.totalHeight)
        #expect(try #require(plan.captionFrame).y >= shape.frame.maxY + .points(8))
        let reopened = try Presentation(data: deck.serializedData())
        for (uri, bytes) in before { #expect(reopened.package.parts[uri]?.blob == bytes) }
        let saved = try #require((reopened.slides[1].shapes.all.first { $0 is TableFrame } as? TableFrame)?.table)
        #expect(try saved.cell(1, 1).text == content.rows[1][1])
        #expect(try TableLayoutEngine(presentation: deck).plan(saved, minimumRowHeight: .points(30)).rowHeights == measured.rowHeights)
    }
}
