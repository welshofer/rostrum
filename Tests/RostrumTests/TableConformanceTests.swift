import Foundation
import Testing
@testable import Rostrum

/// Independent python-pptx producer fixture, rather than round-tripping our own writer.
@Suite struct TableConformanceTests {
    private func fixture() throws -> Presentation {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try Presentation(contentsOf: root.appendingPathComponent("Conformance/python-tables.pptx"))
    }
    private func table(_ deck: Presentation, _ index: Int = 0) throws -> Table {
        let tables = try deck.slides[index].shapes.compactMap { ($0 as? TableFrame)?.table }
        return try #require(tables.first)
    }
    @Test func independentTableReadEditAndReopen() throws {
        let deck = try fixture()
        let t = try table(deck)
        #expect(t.rowCount == 4 && t.columnCount == 4)
        #expect(try t.cell(0, 0).text == "Merged origin")
        #expect(try t.cell(0, 0).tc[attribute: "rowSpan"] == "2")
        #expect(try t.cell(0, 1).tc[attribute: "hMerge"] == "1")
        let pr = try #require(t.cell(2, 1).tc.firstChild(named: "a:tcPr"))
        #expect(pr[attribute: "marR"] == "210312")
        #expect(pr.firstChild(named: "a:lnL")?[attribute: "w"] == "25400")
        #expect(try t.cell(2, 1).textFrame.paragraphs[0].runs.map(\.fontSize) == [18, 24, 14])
        try t.cell(3, 3).text = "Edited through Rostrum"
        let reopened = try Presentation(data: deck.serializedData())
        #expect(try table(reopened).cell(3, 3).text == "Edited through Rostrum")
        #expect(try table(reopened).cell(0, 0).tc[attribute: "gridSpan"] == "2")
        #expect(try table(reopened).cell(2, 1).tc.firstChild(named: "a:tcPr")?[attribute: "marR"] == "210312")
        #expect(try reopened.serializedData() == Presentation(data: reopened.serializedData()).serializedData())
    }
    @Test func tableSurvivesDuplicateAndImport() throws {
        let source = try fixture()
        _ = try source.slides.duplicate(at: 0)
        let destination = try Presentation()
        try destination.slides.importAll(from: source)
        let reopened = try Presentation(data: destination.serializedData())
        for index in 1...2 {
            let t = try table(reopened, index)
            #expect(try t.cell(0, 0).text == "Merged origin")
            #expect(try t.cell(2, 1).textFrame.paragraphs[0].runs.count == 3)
        }
    }
}
