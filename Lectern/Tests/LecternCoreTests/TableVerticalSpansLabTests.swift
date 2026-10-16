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
    }
}
