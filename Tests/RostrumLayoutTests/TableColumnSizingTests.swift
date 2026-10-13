import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TableColumnSizingTests {
    private func fixture() throws -> Presentation {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: folder.appendingPathComponent(face + ".ttf"))
        }
        return deck
    }

    private var rows: [[String]] {
        [["ID", "Description", "Value"]] + (1...24).map {
            ["R\($0)", "A detailed observation preserves every original word and needs room to wrap naturally.", "1,234"]
        }
    }

    @Test func actualWrappedGeometryReducesPagesWithoutLosingRows() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let before = try deck.serializedData()
        let baseline = try engine.planTablePages(title: "Evidence", table: .init(rows: rows), caption: "Original source.")
        let plan = try engine.planTablePages(title: "Evidence", table: .init(rows: rows, columnSizing: .measured()), caption: "Original source.")
        #expect(plan.pages.count < baseline.pages.count)
        #expect(try deck.serializedData() == before)
        let grid = try #require(plan.pages.first?.slide.tableLayout)
        #expect(grid.columnWidths[1] > (try #require(baseline.pages.first?.slide.tableLayout)).columnWidths[1])
        let search = try #require(grid.columnSearch)
        #expect(search.evaluatedCandidates <= 24 && search.additionalCellMeasurements <= 32_768)
        #expect(search.reusedCellMeasurements > 0)
        let slides = try engine.composeTablePages(plan)
        let reopened = try Presentation(data: deck.serializedData())
        var saved: [[String]] = []
        for (index, page) in plan.pages.enumerated() {
            let slide = try reopened.slides[index + 1]
            let frames = slide.shapes.all.compactMap { $0 as? TableFrame }
            let frame = try #require(frames.first), table = try #require(frame.table)
            let measured = try TableLayoutEngine(presentation: deck).plan(table, minimumRowHeight: .points(30))
            let accepted = try #require(page.slide.tableLayout)
            #expect(measured.fits && measured.columnWidths == grid.columnWidths)
            #expect(zip(measured.rowHeights, accepted.rowHeights).allSatisfy { $0 <= $1 })
            #expect(frame.frame.maxY + .points(8) <= (try #require(page.slide.captionFrame)).y)
            for row in 1..<table.rowCount {
                saved.append(try (0..<table.columnCount).map { try table.cell(row, $0).text })
            }
        }
        #expect(slides.count == plan.pages.count && saved == Array(rows.dropFirst()))
    }

    @Test func fixedBoundsAndEMUResidualSurviveSingleSlideComposition() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let original = try engine.plan(title: "Bounds", columns: [], preferredTypes: ["obj"], object: "tbl")
        let width = try #require(original.objectFrame).width
        let first = EMU(width.rawValue / 4 + 1), second = width - first
        let content = TemplateTableContent(rows: [["Header", "Description"], ["A", "Wrapped evidence retained"]], columnSizing: .measured(constraints: [
            .init(minimum: first, maximum: first, preferred: first), .init(minimum: second, maximum: second)
        ]))
        let plan = try engine.plan(title: "Bounds", columns: [], preferredTypes: ["obj"], object: "tbl",
            objectCaption: "Reserved caption", layoutURI: original.layout.part.uri.value, table: content)
        let grid = try #require(plan.tableLayout)
        #expect(grid.columnWidths == [first, second] && grid.columnWidths.reduce(.zero, +) == width)
        let slide = try engine.compose(plan, title: "Bounds", columns: [])
        let frames = slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }
        let native = try #require(frames.first)
        #expect(try TableLayoutEngine(presentation: deck).plan(native).columnWidths == grid.columnWidths)
    }

    @Test func softPreferencesBreakFitTiesAndEstimatedSizingStaysUnchanged() throws {
        let deck = try fixture()
        let values = [["A", "B"], ["C", "D"]]
        let estimated = TemplateTableContent(rows: values)
        let baseline = try estimated.planned(in: deck, width: .points(400), font: "DejaVu Sans", size: 18, theme: deck.theme)
        let preferred = TemplateTableContent(rows: values, columnSizing: .measured(constraints: [
            .init(preferred: .points(120)), .init(preferred: .points(280))
        ]))
        let measured = try preferred.planned(in: deck, width: .points(400), font: "DejaVu Sans", size: 18, theme: deck.theme)
        #expect(measured.columnWidths == [.points(120), .points(280)])
        #expect(measured.totalHeight == baseline.totalHeight)
        #expect(baseline.columnSearch == nil && baseline.columnWidths == [.points(200), .points(200)])
        let unchanged = try TemplateTableContent(rows: values, columnSizing: .measured()).planned(in: deck,
            width: .points(400), font: "DejaVu Sans", size: 18, theme: deck.theme)
        #expect(unchanged.columnWidths == baseline.columnWidths)
    }

    @Test func infeasibleAndInvalidConstraintsDoNotMutate() throws {
        let deck = try fixture()
        let before = try deck.serializedData()
        let variants: [[TableColumnConstraint]] = [
            [.init()], [.init(minimum: .zero), .init()], [.init(minimum: .points(-1)), .init()],
            [.init(minimum: .points(250)), .init(minimum: .points(250))],
            [.init(maximum: .points(100)), .init(maximum: .points(100))],
            [.init(minimum: .points(100), maximum: .points(50)), .init()],
            [.init(maximum: .points(100), preferred: .points(200)), .init()]
        ]
        for constraints in variants {
            #expect(throws: LayoutError.self) {
                try TemplateTableContent(rows: [["A", "B"]], columnSizing: .measured(constraints: constraints))
                    .planned(in: deck, width: .points(400), font: "DejaVu Sans", size: 18, theme: deck.theme)
            }
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func boundedSearchStillReturnsACompleteLargeGrid() throws {
        let deck = try fixture()
        let values = [["ID", "Evidence", "Value"]] + (0..<4000).map { _ in ["ID", "A longer repeated observation needs room", "42"] }
        let content = TemplateTableContent(rows: values, columnSizing: .measured())
        let plan = try content.planned(in: deck, width: .points(700), font: "DejaVu Sans", size: 18,
            theme: deck.theme, pagination: true, availableHeight: .points(350))
        let summary = try #require(plan.columnSearch)
        #expect(summary.evaluatedCandidates <= 24 && summary.additionalCellMeasurements <= 32_768)
        #expect(summary.budgetExhausted)
        #expect(plan.fits && plan.cells.count == values.count * 3 && plan.rowHeights.count == values.count)
        #expect(plan.columnWidths.reduce(.zero, +) == .points(700))
    }

    @Test func unicodeBytesAndFreshFontMeasurementsSurviveWidthSearch() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let values = [["Script", "Original text"], ["Greek", "Δοκιμή κειμένου"], ["Cyrillic", "Проверка текста"],
            ["Arabic", "مرحبا بالعالم"], ["CJK", "日本語の文章"], ["Combining", "é e\u{301}\t42\nExact words"]]
        let content = TemplateTableContent(rows: values, columnSizing: .measured())
        let plan = try engine.planTablePages(title: "Scripts", table: content)
        _ = try engine.composeTablePages(plan)
        let reopened = try Presentation(data: deck.serializedData())
        var saved: [[Data]] = []
        for index in plan.pages.indices {
            let tables = try reopened.slides[index + 1].shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let table = try #require(tables.first)
            for row in 1..<table.rowCount { saved.append(try (0..<2).map { Data(try table.cell(row, $0).text.utf8) }) }
        }
        #expect(saved == values.dropFirst().map { $0.map { Data($0.utf8) } })
        let before = try content.planned(in: deck, width: .points(500), font: "Registered later", size: 18, theme: deck.theme)
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        try deck.fonts.register(contentsOf: font, aliases: ["Registered later"])
        let after = try content.planned(in: deck, width: .points(500), font: "Registered later", size: 18, theme: deck.theme)
        let missing = ShapingDiagnostic.unsupportedLayoutFeature("Unregistered font face: Registered later")
        #expect(before.cells.contains { $0.diagnostics.contains(missing) })
        #expect(!after.cells.contains { $0.diagnostics.contains(missing) })
    }

    @Test func nativeBandStylesAndDeterministicSearchSurviveReopening() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: deck.bounds)
        let definition = try XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(Table.defaultStyleGUID)" styleName="Measured band fonts">
          <a:wholeTbl><a:tcTxStyle b="off" i="off"/></a:wholeTbl>
          <a:band1H><a:tcTxStyle b="on"/></a:band1H>
          <a:band2H><a:tcTxStyle i="on"/></a:band2H>
          <a:firstRow><a:tcTxStyle b="on"/></a:firstRow>
        </a:tblStyle>
        """.utf8))
        try table.setStyleDefinition(definition)
        let content = TemplateTableContent(rows: rows, columnSizing: .measured())
        let first = try engine.planTablePages(title: "Native bands", table: content)
        let second = try engine.planTablePages(title: "Native bands", table: content)
        #expect(first.pages.map(\.bodyRows) == second.pages.map(\.bodyRows))
        #expect(first.pages.map { $0.slide.tableLayout?.columnWidths } == second.pages.map { $0.slide.tableLayout?.columnWidths })
        _ = try engine.composeTablePages(first)
        let bytes = try deck.serializedData()
        #expect(try deck.serializedData() == bytes)
        let reopened = try Presentation(data: bytes)
        for (index, page) in first.pages.enumerated() {
            let tables = try reopened.slides[index + 1].shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let native = try #require(tables.first)
            let saved = try TableLayoutEngine(presentation: deck).plan(native, minimumRowHeight: .points(30))
            let accepted = try #require(page.slide.tableLayout)
            #expect(saved.fits && zip(saved.rowHeights, accepted.rowHeights).allSatisfy { $0 <= $1 })
            #expect(saved.columnWidths == accepted.columnWidths)
        }
    }
}
