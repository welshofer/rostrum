import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryImageOwnersAppTests {
    @Test(arguments: [false, true])
    func selectedOwnersReachInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext(); defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabImageOwners-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel(); model.options = .init(alternative: alternative)
        await model.run([.imageOwners], in: root).value
        let result = try #require(model.results[.imageOwners])
        #expect(result.passed && model.failures.isEmpty && result.slideCount == 5 && result.findings.isEmpty)
        #expect(result.checks.filter { $0.name.hasPrefix("Saved Native image owner:") && $0.passed }.count == 4)
        #expect(result.checks.contains { $0.name == "Selected image owners export exact bytes" && $0.passed })
        let bytes = try Data(contentsOf: result.afterURL)
        await context.app.inspect(deckAt: try #require(result.beforeURL)).value
        #expect(context.app.phase == .inspected && context.app.inspection?.previews.count == 1)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 5)
        let fresh = try DeckInspector.inspect(deckAt: result.afterURL)
        let deck = try Presentation(data: bytes); deck.registerEmbeddedFonts()
        for index in 0..<5 {
            let slot = try #require(inspection.previewSlideNumbers.firstIndex(of: index + 1))
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", index + 1)), encoding: .utf8)
            #expect(saved == inspection.previews[slot] && saved == fresh.previews[slot])
            if index < 4 { #expect(try saved == deck.renderSVG(slideAt: index, pixelWidth: 640)) }
        }
        #expect(try Data(contentsOf: result.afterURL) == bytes)
        await (try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))).value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "5 slides · \(alternative ? 5 : 6) media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory), outline = deck.outline()
        let markdown = try String(contentsOf: directory.appendingPathComponent("imageOwners.md"), encoding: .utf8)
        #expect(markdown.contains(alternative ? "Public no-fill override" : "Public direct-image override"))
        var expected: Set<String> = ["imageOwners.md"]
        for slide in outline.slides { for asset in slide.assets {
            let relative = String(format: "slide-%02d/", slide.number) + asset.filename
            expected.insert(relative)
            #expect(try Data(contentsOf: directory.appendingPathComponent(relative)) == deck.package.part(at: PackURI(asset.partName)).blob)
            #expect(markdown.contains(relative))
        } }
        #expect(try files(in: directory) == expected)
        #expect(try deck.serializedData() == bytes)
        #expect(try Data(contentsOf: result.afterURL) == bytes)
    }

    private func files(in directory: URL) throws -> Set<String> {
        var actual: Set<String> = []
        let files = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
        for case let file as URL in files where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            actual.insert(file.resolvingSymlinksInPath().pathComponents.dropFirst(directory.resolvingSymlinksInPath().pathComponents.count).joined(separator: "/"))
        }
        return actual
    }
}
