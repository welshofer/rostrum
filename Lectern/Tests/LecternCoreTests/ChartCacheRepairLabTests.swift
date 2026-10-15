import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ChartCacheRepairLabTests {
    @Test(arguments: [false, true])
    func savedRepairSurvivesProductionInspectionAndExport(scatter: Bool) throws {
        let retained = ProcessInfo.processInfo.environment["LECTERN_LAB_ARTIFACTS"].map { URL(fileURLWithPath: $0) }
        let parent = retained ?? FileManager.default.temporaryDirectory.appendingPathComponent("CacheRepair-" + UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: parent) } }
        let result = try LibraryLab.run(.chartCacheRepair,
            options: .init(text: "Revenue", sampleSize: 3, alternative: scatter), in: parent)
        #expect(result.passed, "\(result.checks.filter { !$0.passed })")
        let beforeURL = try #require(result.beforeURL)
        let source = try Data(contentsOf: beforeURL), repaired = try Data(contentsOf: result.afterURL)
        let original = try DeckInspector.inspect(deckAt: beforeURL)
        let inspection = try DeckInspector.inspect(deckAt: result.afterURL)
        #expect(inspection.chartCount == 1 && inspection.slideCount == 1)
        #expect(inspection.charts.first?.series.first?.name == "Revenue")
        #expect(inspection.previews == original.previews)
        #expect(inspection.previewDiagnostics == original.previewDiagnostics)
        if !scatter {
            #expect(inspection.charts.first?.categories == ["Item 1", "Item 2", "Item 3"])
            #expect(inspection.charts.first?.series.first?.values == [7, nil, 21])
        }
        let beforeExport = try DeckExporter.export(deckAt: beforeURL, into: result.directory.appendingPathComponent("before-export"))
        let afterExport = try DeckExporter.export(deckAt: result.afterURL, into: result.directory.appendingPathComponent("after-export"))
        #expect(beforeExport.chartsWritten == 1 && afterExport.chartsWritten == 1)
        #expect(beforeExport.warnings.isEmpty && afterExport.warnings.isEmpty)
        let name = "slide-01/chart-1.csv"
        let csv = try String(contentsOf: afterExport.directory.appendingPathComponent(name), encoding: .utf8)
        let expected = scatter ? "Series,X,Y\r\nRevenue,1,7\r\nRevenue,2,14\r\nRevenue,3,21\r\n"
            : "Category,Revenue\r\nItem 1,7\r\nItem 2,\r\nItem 3,21\r\n"
        #expect(csv == expected)
        #expect(try String(contentsOf: beforeExport.directory.appendingPathComponent(name), encoding: .utf8) == csv)
        let markdown = try String(contentsOf: afterExport.markdownFile, encoding: .utf8)
        #expect(markdown.contains("Keep these chart notes.") && markdown.contains("Chart cache repair"))
        #expect(try Data(contentsOf: beforeURL) == source)
        #expect(try Data(contentsOf: result.afterURL) == repaired)
        let rerun = try ChartCacheRepairRecipe.make(.init(text: "Revenue", sampleSize: 3, alternative: scatter))
        #expect(try rerun.deck.serializedData() == repaired)
        #expect(rerun.before == source)
    }
}
