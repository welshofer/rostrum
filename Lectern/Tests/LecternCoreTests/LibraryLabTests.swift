import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite("Library Lab file pipeline", .serialized)
struct LibraryLabTests {
    @Test func catalogIsCompleteAndUnambiguous() {
        let recipes = [ImportedFidelityRecipe.catalog] + DrawingLabRecipes.catalog + DocumentLabRecipes.catalog + PlatformLabRecipes.catalog
        #expect(recipes.count == LibraryDemoID.allCases.count)
        #expect(Set(recipes.map(\.id)).count == recipes.count)
        #expect(LibraryLab.catalog.map(\.id) == LibraryDemoID.allCases)
        for recipe in recipes {
            #expect(!recipe.title.isEmpty && !recipe.summary.isEmpty && !recipe.operations.isEmpty)
            #expect(Set(recipe.operations).count == recipe.operations.count)
            #expect(recipe.inputs.contains(.alternative) == (recipe.alternativeLabel != nil))
        }
    }

    @Test("Every app demo saves, reopens, previews and extracts", arguments: LibraryDemoID.allCases)
    func everyDemo(_ id: LibraryDemoID) throws {
        // Opt-in artifact retention makes exactly the same test output available
        // for native PowerPoint review, without introducing a second demo path.
        let retained = ProcessInfo.processInfo.environment["LECTERN_LAB_ARTIFACTS"].map { URL(fileURLWithPath: $0) }
        let parent = retained ?? FileManager.default.temporaryDirectory.appendingPathComponent("LabTests-" + UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: parent) } }
        let result = try LibraryLab.run(id, in: parent)
        #expect(result.id == id)
        #expect(result.passed, "\(id): \(result.checks.filter { !$0.passed })")
        #expect(result.slideCount > 0)
        #expect(result.coverSVG?.contains("<svg") == true)
        #expect(FileManager.default.fileExists(atPath: result.markdownURL.path))
        #expect(result.artifacts.contains(result.afterURL) && result.artifacts.contains(result.reportURL))
        #expect(result.artifacts.contains(result.markdownURL))
        let report = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: result.reportURL)) as? [String: Any])
        #expect(report["recipe"] as? String == id.rawValue)
        #expect(report["operations"] as? [String] == LibraryLab.catalog.first { $0.id == id }?.operations)
        #expect((report["checks"] as? [[String: Any]])?.count == result.checks.count)
        #expect((report["findings"] as? [[String: Any]])?.count == result.findings.count)
        let reopened = try Presentation(contentsOf: result.afterURL)
        #expect(reopened.slides.count == result.slideCount)
        let svgs = try FileManager.default.contentsOfDirectory(at: result.directory.appendingPathComponent("previews"), includingPropertiesForKeys: nil)
        #expect(svgs.filter { $0.lastPathComponent.hasPrefix("slide-") }.count == result.slideCount)
        if let before = result.beforeURL { #expect(try Data(contentsOf: before) != Data(contentsOf: result.afterURL)) }
    }

    @Test func invalidInputDoesNotCreateFiles() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("InvalidLab-" + UUID().uuidString)
        for options in [LibraryLabOptions(text: " "), .init(text: String(repeating: "x", count: 241)),
                        .init(accentHex: "#12345"), .init(accentHex: "１２３４５６"),
                        .init(sampleSize: 1), .init(sampleSize: 13)] {
            #expect(throws: LibraryLabError.self) { try LibraryLab.run(.shapes, options: options, in: parent) }
            #expect(!FileManager.default.fileExists(atPath: parent.path))
        }
    }

    @Test func hiddenInputsCannotInvalidateADifferentRecipe() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("HiddenLab-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        let result = try LibraryLab.run(.tableStructure, options: .init(accentHex: "bad"), in: parent)
        #expect(result.passed)
        #expect(result.options.accentHex == LibraryLabOptions().accentHex)
    }

    @Test func cancellationDoesNotCreateFiles() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("CancelledLab-" + UUID().uuidString)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try LibraryLab.run(.tableStructure, in: parent)
        }
        do { _ = try await task.value; Issue.record("Cancelled run succeeded") }
        catch { #expect(error is CancellationError) }
        #expect(!FileManager.default.fileExists(atPath: parent.path))
    }

    @Test func repeatedRunsKeepIndependentArtifacts() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("RepeatedLab-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        let first = try LibraryLab.run(.tableStructure, options: .init(text: "First"), in: parent)
        let bytes = try Data(contentsOf: first.afterURL)
        let second = try LibraryLab.run(.tableStructure, options: .init(text: "Second", alternative: true), in: parent)
        #expect(first.directory != second.directory)
        #expect(first.passed && second.passed)
        #expect(try Data(contentsOf: first.afterURL) == bytes)
        #expect(try Data(contentsOf: second.afterURL) != bytes)
    }

    @Test func failedArtifactWriteRemovesOnlyItsOwnRun() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("FailedLab-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let sentinel = parent.appendingPathComponent("keep.txt")
        try Data("existing file".utf8).write(to: sentinel)
        #expect(throws: LibraryLabError.self) {
            try LibraryLab.perform(.slides, options: .init(), in: parent) {
                LibraryLabDraft(deck: try LibraryLabSupport.deck(title: "Failed draft"), extraFiles: ["../escape": Data()])
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path) == ["keep.txt"])
        #expect(try String(contentsOf: sentinel, encoding: .utf8) == "existing file")
    }
}
