import Foundation
import Testing
import KeynoteInterchange
import Rostrum
@testable import LecternCore

@Suite struct KeyxBackendTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("KeyxBackend-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private var deck: DeckIR {
        DeckIR(meta: Meta(title: "Interchange workflow"), slides: [
            IRSlide(id: "first", layout: "bullets", title: "Native interchange",
                    body: Body(bullets: [Bullet(text: "Keep every word")]), notes: "Original notes"),
            IRSlide(id: "second", layout: "table", title: "Data",
                    body: Body(table: IRTable(headers: ["A", "B"], rows: [["one", "two"]])))
        ])
    }

    @Test func renderInspectExportLibraryRenameAndCopyUseTheSameFormat() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let result = try await DeckRenderer().render(deck, designURL: nil, notesEnabled: true,
            into: root, outputFormat: .keynoteInterchange)
        #expect(result.format == .keynoteInterchange && result.url.pathExtension == "keyx")
        #expect(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
        #expect(result.previewRecords.count == result.slideCount && !result.previewWarnings.isEmpty)
        let original = try Data(contentsOf: result.url)
        let inspection = try DeckInspector.inspect(deckAt: result.url)
        #expect(inspection.format == .keynoteInterchange)
        #expect(inspection.slides[0].notes == ["Original notes"])
        #expect(inspection.slides[1].tables[0].rows == [["A", "B"], ["one", "two"]])
        #expect(inspection.previewSlideNumbers == [1, 2])
        #expect(inspection.previewDiagnostics.allSatisfy { $0.failure == nil })
        #expect(try DeckInspector.previewInterchangeSlide(deckAt: result.url).number == 1)
        #expect(try DeckInspector.inspect(deckAt: result.url, renderPreviews: false).previewRecords.isEmpty)
        #expect(throws: (any Error).self) {
            try DeckInspector.inspect(deckAt: result.url, limits: .init(totalUncompressedBytes: 10))
        }
        let exported = try DeckExporter.export(deckAt: result.url, into: root.appendingPathComponent("export"))
        let text = try String(contentsOf: exported.markdownFile, encoding: .utf8)
        #expect(text.contains("Keep every word") && text.contains("Original notes") && text.contains("| one | two |"))
        #expect(try Data(contentsOf: result.url) == original)
        let item = try #require(DeckLibrary.decks(in: root).first)
        #expect(await DeckCardIndex(directory: root.appendingPathComponent("cache")).card(for: item)?.slideCount == 2)
        let renamed = try DeckLibrary.rename(item, to: "Renamed")
        #expect(renamed.url.pathExtension == "keyx")
        let prepared = try DeckStorage.prepareDeckCopy(from: renamed.url, title: "Saved copy", into: root.appendingPathComponent("library"))
        let copy = try prepared.commit()
        #expect(copy.pathExtension == "keyx")
        #expect(try Data(contentsOf: copy) == original)
    }

    @Test func recoveryKeepsUntouchedSlidesUnknownFieldsAndCurrentNotes() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let renderer = DeckRenderer()
        let first = try await renderer.render(deck, designURL: nil, notesEnabled: true, into: root, outputFormat: .keynoteInterchange)
        var source = try KeyxDocument(contentsOf: first.url)
        try source.editSlide(at: 0) { $0.setNote(.value(KeyxText("Later note edit"))) }
        try source.editSlide(at: 1) { $0.node["external_extension"] = .number("9007199254740993123") }
        try source.save(to: first.url)
        let bytes = try Data(contentsOf: first.url)
        let snapshot = try RenderSnapshot(deck: deck, outputFormat: .keynoteInterchange).save(in: root)
        let revised = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: first.url, slideID: "first", variant: 0, into: root)
        let reopened = try KeyxDocument(contentsOf: revised.url)
        #expect(revised.url != first.url && revised.url.pathExtension == "keyx")
        #expect(try reopened.slides[1] == source.slides[1])
        #expect(try reopened.inspectSlide(at: 0).notes == "Later note edit")
        #expect(try Data(contentsOf: first.url) == bytes)
        #expect(revised.recoveryURL == snapshot)
    }

    @Test func externalIdentifierRegenerationRequiresExplicitWholeDeckRebuild() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let renderer = DeckRenderer()
        let first = try await renderer.render(deck, designURL: nil, notesEnabled: true, into: root, outputFormat: .keynoteInterchange)
        var source = try KeyxDocument(contentsOf: first.url)
        try source.editSlide(at: 0) { $0.identifier = "Keynote-regenerated-id" }
        try source.save(to: first.url)
        let bytes = try Data(contentsOf: first.url)
        let snapshot = try RenderSnapshot(deck: deck, outputFormat: .keynoteInterchange).save(in: root)
        await #expect(throws: RenderError.self) {
            try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: first.url, slideID: "first", variant: 0, into: root)
        }
        let rebuilt = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: nil, slideID: "first", variant: 0, into: root)
        #expect(rebuilt.format == .keynoteInterchange)
        #expect(try Data(contentsOf: first.url) == bytes)
    }

    @Test func oldSnapshotsRemainPowerPointAndNewSnapshotsRetainFormat() throws {
        let snapshot = RenderSnapshot(deck: deck, outputFormat: .keynoteInterchange)
        let bytes = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(RenderSnapshot.self, from: bytes).outputFormat == .keynoteInterchange)
        var old = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        old.removeValue(forKey: "outputFormat")
        #expect(try JSONDecoder().decode(RenderSnapshot.self, from: JSONSerialization.data(withJSONObject: old)).outputFormat == .powerPoint)
    }

    @Test func importedSemanticFailuresKeepEveryOriginalSlideSlot() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        var archive = ZipWriter()
        archive.addFile(name: "main.json", data: Data(#"{"slide_size":{"width":800,"height":600},"slides":[{},{}]}"#.utf8))
        archive.addFile(name: "presets.json", data: Data(#"[{"identifier":"cycle","parent_identifier":"cycle","properties":{}}]"#.utf8))
        let url = root.appendingPathComponent("invalid-styles.keyx")
        let bytes = try archive.finalize()
        try bytes.write(to: url)
        let inspection = try DeckInspector.inspect(deckAt: url)
        #expect(inspection.slideCount == 2 && inspection.slides.count == 2)
        #expect(inspection.previewSlideNumbers == [1, 2])
        #expect(inspection.previewRecords.allSatisfy { $0.svg == nil })
        #expect(inspection.previewDiagnostics.allSatisfy { $0.failure != nil })
        #expect(!inspection.schemaIssues.isEmpty && inspection.outlineWarnings.count == 2)
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func providerPipelineWritesInterchangeAndRecoverableMetadata() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        var intent = deck
        intent.slides[0].layout = "title"
        intent.slides[0].body = Body(subtitle: "Keep every word")
        let generator = DeckGenerator(provider: KeyxFixtureProvider(deck: intent), quality: false, outputFormat: .keynoteInterchange)
        let result = try await generator.generate(DeckRequest(prompt: "Local fixture", slideCount: 2, notes: false),
            designURL: nil, into: root, diagnostics: root.appendingPathComponent("diagnostics")) { _ in }
        #expect(result.format == .keynoteInterchange)
        let snapshot = try RenderSnapshot.load(#require(result.recoveryURL))
        #expect(snapshot.outputFormat == .keynoteInterchange)
        #expect(snapshot.deck.slides.count == 2)
        #expect(try KeyxDocument(contentsOf: result.url).slides.count == result.slideCount)
    }

    @Test func offlineLabRunsTheProductionInspectorAndExporter() throws {
        let retained = ProcessInfo.processInfo.environment["LECTERN_LAB_ARTIFACTS"].map { URL(fileURLWithPath: $0) }
        let root = try retained ?? folder()
        defer { if retained == nil { try? FileManager.default.removeItem(at: root) } }
        let result = try LibraryLab.run(.keynoteInterchange, in: root)
        #expect(result.passed, "\(result.checks.filter { !$0.passed })")
        #expect(result.afterURL.pathExtension == "keyx")
        #expect(result.findings.contains { $0.stage == "Interchange preview" })
        #expect(FileManager.default.fileExists(atPath: result.reportURL.path))
        #expect(result.artifacts.contains(result.afterURL))
        #expect(result.artifacts.contains(result.reportURL))
        #expect(result.artifacts.contains(result.markdownURL))
    }
}

private struct KeyxFixtureProvider: LLMProvider {
    let deck: DeckIR
    let id = ProviderID.openAI
    let displayName = "Offline interchange fixture"
    func draft(_ request: DeckRequest, repairing: RepairContext?,
               emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        RawDraft(json: String(decoding: try JSONEncoder().encode(deck), as: UTF8.self), usage: Usage())
    }
}
