import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct RenderContentCheckTests {
    @Test func comparisonLeadSurvivesAuthoredRendering() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let ir = DeckIR(meta: Meta(title: "Comparison"), slides: [IRSlide(id: "a", layout: "comparison", title: "Compare",
            body: Body(left: .init(heading: "First", bullets: ["A"]), right: .init(heading: "Second", bullets: ["B"]), lead: "Both choices share this important premise."))])
        let output = try await DeckRenderer().render(ir, designURL: nil, notesEnabled: true, into: root)
        #expect(try RenderContentCheck.inspect(output.url, expected: ir).issues.isEmpty)
    }

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func missingVisibleTextCannotHideInNotesOrAnotherSlide() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let ir = DeckIR(meta: Meta(title: "Read back"), slides: [
            IRSlide(id: "a", layout: "bullets", title: "First", body: Body(bullets: [.init(text: "An essential fact")]), notes: "An essential fact"),
            IRSlide(id: "b", layout: "bullets", title: "Second", body: Body(bullets: [.init(text: "An essential fact")]))])
        let result = try await DeckRenderer().render(ir, designURL: nil, notesEnabled: true, into: root)
        #expect(try RenderContentCheck.inspect(result.url, expected: ir).issues.isEmpty)
        let changed = try Presentation(contentsOf: result.url)
        let body = try #require(changed.slides[0].shapes.all.first { $0.textFrame?.text.contains("An essential fact") == true })
        body.textFrame?.text = "Different words"
        try changed.save(to: result.url)
        let check = try RenderContentCheck.inspect(result.url, expected: ir)
        #expect(check.issues == ["Slide a: missing or changed text at body.bullets[0].text."])
    }

    @Test func changedNativeDataAndMissingNotesFailReadBack() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let ir = DeckIR(meta: Meta(title: "Data"), slides: [
            IRSlide(id: "chart", layout: "chart", title: "Chart", body: Body(chart: .init(kind: "bar", categories: ["A", "B"], series: [.init(name: "Values", values: [1, 2])])), notes: "Keep notes"),
            IRSlide(id: "table", layout: "table", title: "Table", body: Body(table: .init(headers: ["A", "B"], rows: [["x", "y"]])))])
        let output = try await DeckRenderer().render(ir, designURL: nil, notesEnabled: true, into: root)
        #expect(try RenderContentCheck.inspect(output.url, expected: ir).issues.isEmpty)
        var expected = ir
        expected.slides[0].body?.chart?.series[0].values[1] = 3
        expected.slides[1].body?.table?.rows[0][1] = "changed"
        expected.slides[0].notes = "Different notes"
        let check = try RenderContentCheck.inspect(output.url, expected: expected)
        #expect(check.issues.contains { $0.contains("native chart") })
        #expect(check.issues.contains { $0.contains("native table") })
        #expect(check.issues.contains { $0.contains("speaker notes") })
    }

    @Test func continuationReadBackAndWholeDeckRecoveryPreserveContent() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let ir = DeckIR(meta: Meta(title: "Dense"), slides: [IRSlide(id: "a", layout: "bullets", title: "Evidence",
            body: Body(bullets: (0..<20).map { .init(text: "Fact \($0) includes the original wording and sufficient detail to require multiple readable pages.") }), notes: "Keep notes")])
        let renderer = DeckRenderer()
        let output = try await renderer.render(ir, designURL: nil, notesEnabled: true, into: root)
        let original = try Data(contentsOf: output.url)
        let snapshot = try RenderSnapshot(deck: ir).save(in: root)
        let rebuilt = try await renderer.retrySlide(snapshotURL: snapshot, sourceURL: nil, slideID: "a", variant: 1, into: root)
        #expect(rebuilt.url != output.url)
        #expect(try Data(contentsOf: output.url) == original)
        #expect(try RenderContentCheck.inspect(output.url, expected: ir).issues.isEmpty)
        // The alternative changes representation, not the accepted facts.
        #expect(try RenderContentCheck.inspect(rebuilt.url, expected: ir).issues.isEmpty)
    }
}
