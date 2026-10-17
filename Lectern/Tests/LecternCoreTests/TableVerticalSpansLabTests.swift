import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TableVerticalSpansLabTests {
    @Test(arguments: [false, true])
    func savedMergedTablesUseProductionInspectionAndExport(narrow: Bool) throws {
        let retained = ProcessInfo.processInfo.environment["ROSTRUM_VERTICAL_MERGE_ARTIFACTS"].map { URL(fileURLWithPath: $0) }
        let directory = retained ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: directory) } }
        let result = try LibraryLab.run(.templates, options: .init(alternative: narrow), in: directory)
        #expect(result.passed, "\(result.checks.filter { !$0.passed })")
        let standalone = result.directory.appendingPathComponent("vertical-spans-output.pptx")
        let deck = try Presentation(contentsOf: standalone)
        #expect(deck.slides.count == 1 && deck.slideSize.width < .points(1000))
        #expect(deck.slideSize.width / deck.slideSize.height == (narrow ? 4.0 / 3 : 16.0 / 9))
        let extracted = try String(contentsOf: result.markdownURL, encoding: .utf8)
        #expect(extracted.contains("One summary spans two rows and two columns without losing any original words."))
        #expect(extracted.contains("A second observation remains editable."))
        let previews = try FileManager.default.contentsOfDirectory(at: result.directory.appendingPathComponent("previews"),
            includingPropertiesForKeys: nil).filter { $0.pathExtension == "svg" && $0.lastPathComponent.hasPrefix("slide-") }
        #expect(previews.count == result.slideCount)
        #expect(result.checks.contains { $0.name == "Saved multi-row cells fit their combined area" && $0.passed })
        let continuations = try Presentation(contentsOf: result.directory.appendingPathComponent("vertical-pagination-output.pptx"))
        #expect(continuations.slides.count > 1)
        #expect(continuations.slideSize.width == deck.slideSize.width && continuations.slideSize.height == deck.slideSize.height)
        #expect(extracted.contains("A connected summary preserves the complete source for group 6."))
        #expect(result.checks.contains { $0.name == "Saved merged pages fit their combined cell areas" && $0.passed })
        let headers = try Presentation(contentsOf: result.directory.appendingPathComponent("repeated-headers-output.pptx"))
        #expect(headers.slides.count > 1 && headers.slideSize.width == deck.slideSize.width)
        #expect(extracted.contains("Observation 8.2"))
        #expect(result.checks.contains { $0.name == "Saved repeated headers and body groups fit" && $0.passed })
        let rotated = try Presentation(contentsOf: result.directory.appendingPathComponent("rotated-text-output.pptx"))
        #expect(rotated.slides.count > 1 && rotated.slideSize.width == deck.slideSize.width)
        #expect(extracted.contains("Rotated labels stay editable"))
        #expect(result.checks.contains { $0.name == "Saved rotated text fits its final cells" && $0.passed })
        for index in 0..<rotated.slides.count {
            let tables = try rotated.slides[index].shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let table = try #require(tables.first)
            #expect(try table.cell(0, 0).textDirection == .vertical)
            #expect(try table.cell(0, 3).textDirection == .vertical270)
        }
        for index in 0..<headers.slides.count {
            let tables = try headers.slides[index].shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let table = try #require(tables.first)
            #expect(try table.cell(0, 0).text == "Source" && table.cell(1, 1).text == "Observation")
            #expect(try table.mergedRegions.contains(.init(row: 0, column: 3, rowSpan: 2, columnSpan: 1)))
        }

    }
}
