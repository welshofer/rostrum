import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TableContextRecipeTests {
    @Test(arguments: [false, true])
    func liveCellContextSurvivesTheSavedFilePipeline(alternative: Bool) throws {
        let draft = try DrawingLabRecipes.make(.tableAppearance,
            options: .init(text: "Cell context", accentHex: "276D89", alternative: alternative))
        #expect(draft.deck.slides.count == 3)
        // The earlier custom-style comparison remains exactly three tables.
        #expect(try draft.deck.slides[1].shapes.all.compactMap { $0 as? TableFrame }.count == 3)
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_TABLE_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("tableAppearance.pptx"))
            try Data(draft.deck.renderSVG(slideAt: 2).utf8).write(to: directory.appendingPathComponent("slide-03.svg"))
        }
        for check in draft.checks + (try draft.verify(reopened)) {
            #expect(check.passed, "\(check.name): \(check.detail)")
        }
        let cell = try TableContextRecipe.cell(reopened)
        #expect(cell.text == TableContextRecipe.sample && cell.verticalAnchor == .middle)
        #expect(cell.textFrame.paragraphs.flatMap(\.runs).allSatisfy { $0.fontName == "DejaVu Sans" && $0.fontSize == 20 })
        let props = try TableContextRecipe.properties(reopened)
        #expect(props[attribute: "marL"] == String(EMU.points(alternative ? 32 : 18).rawValue))
        #expect(props[attribute: "marT"] == "152400" && props[attribute: "marR"] == "177800" && props[attribute: "marB"] == "127000")
        let norm = try #require(TableContextRecipe.body(reopened).firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
        #expect(norm[attribute: "fontScale"] == "50000")
        let full = try TableContextRecipe.geometry(reopened, context: .tableCell)
        let scaled = try TableContextRecipe.geometry(reopened, context: .shape)
        #expect(full.lines != scaled.lines && full.fits && scaled.fits)
        #expect(full.diagnostics == [TableContextRecipe.ignoredScale])
        #expect(try TableContextRecipe.matchesSVG(reopened, svg: reopened.renderSVG(slideAt: 2), layout: full))
        #expect(try reopened.serializedData() == bytes)
    }

    @Test func overflowAndUnverifiedReductionRefuseWithoutChangingTheCell() throws {
        let draft = try DrawingLabRecipes.make(.tableAppearance, options: .init())
        let cell = try TableContextRecipe.cell(draft.deck)
        let retained = cell.textFrame
        let bytes = try draft.deck.serializedData()
        let tiny = Rect(x: .zero, y: .zero, width: .points(20), height: .points(20))
        let overflow = retained.fitText(in: tiny, fonts: draft.deck.fonts, theme: draft.deck.theme)
        #expect(!overflow.fits && overflow.fontScale == 100 && overflow.lineSpacingReduction == 0)
        #expect(try draft.deck.serializedData() == bytes)
        // An owned input fixture supplies a property without a public setter;
        // production authoring and fitting never use a hidden XML workaround.
        let norm = try #require(TableContextRecipe.body(draft.deck).firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
        norm[attribute: "lnSpcReduction"] = "20000"
        try draft.deck.slides[2].part.markDirty()
        let unsupported = try draft.deck.serializedData()
        let reopened = try Presentation(data: unsupported)
        reopened.registerEmbeddedFonts()
        let layout = try TableContextRecipe.geometry(reopened, context: .tableCell)
        #expect(layout.diagnostics.contains(TableContextRecipe.unverifiedReduction))
        let fit = try TableContextRecipe.cell(reopened).textFrame.fitText(in: TableContextRecipe.frame(reopened), fonts: reopened.fonts, theme: reopened.theme)
        #expect(!fit.fits && fit.fontScale == 100 && fit.lineSpacingReduction == 0)
        #expect(try reopened.serializedData() == unsupported)
        #expect(try TableContextRecipe.body(reopened).firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")?[attribute: "lnSpcReduction"] == "20000")
    }
}
