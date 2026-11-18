import Foundation
import Testing
import LecternIR
import Rostrum
@testable import KeynoteInterchange

@Suite struct KeyxAuthorTests {
    @Test func authorsEditableMixedContentAndReopensWithoutPPTX() throws {
        let deck = DeckIR(meta: Meta(title: "Interchange"),
            slides: [
                IRSlide(id: "text", layout: "bullets", title: "Native text",
                        body: Body(bullets: [Bullet(text: "Every word", subBullets: ["including detail"])], source: "Local fixture"),
                        notes: "Presenter notes"),
                IRSlide(id: "table", layout: "table", title: "Native table",
                        body: Body(table: IRTable(headers: ["A", "B"], rows: [["1", "2"]]))),
                IRSlide(id: "chart", layout: "chart", title: "Native chart",
                        body: Body(chart: IRChart(kind: "line", categories: ["Q1", "Q2"],
                                                series: [IRSeries(name: "Revenue", values: [2, 5])])))
            ])
        let authored = try KeyxAuthor.render(deck)
        let data = try authored.document.data()
        let archive = try ZipReader(data: data)
        #expect(Set(archive.entryNames) == ["main.json", "manifest.json", "presets.json"])
        #expect(!archive.entryNames.contains("[Content_Types].xml"))
        let reopened = try KeyxDocument(data: data)
        #expect(try reopened.slides.count == 3)
        let text = try reopened.inspectSlide(at: 0)
        #expect(text.texts.contains("Every word\nincluding detail\nLocal fixture"))
        #expect(text.notes == "Presenter notes")
        #expect(try reopened.inspectSlide(at: 1).tables == [[["A", "B"], ["1", "2"]]])
        #expect(try reopened.inspectSlide(at: 2).charts[0].values == [[2, 5]])
        #expect(try reopened.inspectSlide(at: 2).charts[0].categories == ["Q1", "Q2"])
        let preview = try KeyxPreviewRenderer.render(reopened, slideAt: 0)
        #expect(preview.svg.contains("Every "))
        #expect(!preview.warnings.isEmpty)
    }

    @Test func paginatesExactTextAndKeepsNotesInOriginalSlideGroup() throws {
        let words = String(repeating: "Preserve exact words and spacing. ", count: 40)
        let deck = DeckIR(meta: Meta(title: "Long"),
                          slides: [IRSlide(id: "long", layout: "bullets", title: "Long body",
                                           body: Body(bullets: [Bullet(text: words)]), notes: "Say this once")])
        let result = try KeyxAuthor.render(deck)
        #expect(try result.document.slides.count > 1)
        let summaries = try result.document.slides.indices.map { try result.document.inspectSlide(at: $0) }
        #expect(summaries.flatMap(\.texts).filter { $0 != "Long body" }.joined() == words)
        #expect(summaries.map(\.notes).joined() == "Say this once")
        #expect(result.slideGroups["long"]?.count == summaries.count)
        #expect(try KeyxDocument(data: result.document.data()).slides.count == summaries.count)
    }

    @Test func retainsUserTemplateLayoutsPresetsAndResources() throws {
        let geometry = KeyxGeometry(x: 40, y: 40, width: 800, height: 75)
        func slot(_ kind: String, frame: KeyxGeometry, id: String) -> KeyxValue {
            KeyxNode(type: "slide-object", fields: [
                "source_kind": .string("placeholder"),
                "placeholder_info": .object(["defined": .object(["kind": .string(kind), "is_visible": .bool(true)])]),
                "object": KeyxCanvasObject(kind: "textbox", properties: KeyxNode(type: "textbox", fields: [
                    "identifier": .string(id), "geometry": frame.node.value, "text": KeyxText("").node.value
                ])).node.value
            ]).value
        }
        var template = try KeyxAuthor.render(DeckIR(meta: Meta(title: "Template"),
            slides: [IRSlide(id: "starter", layout: "title", title: "Starter content")])).document
        var theme = try KeyxNode(value: #require(template.presentation["theme"]))
        var layout = try KeyxNode(value: #require(theme["slide_layouts"]?.array?.first))
        layout["contents"] = .array([
            slot("title", frame: geometry, id: "prototype-title"),
            slot("body", frame: KeyxGeometry(x: 40, y: 140, width: 800, height: 300), id: "prototype-body")
        ])
        theme["slide_layouts"] = .array([layout.value]); template.presentation["theme"] = theme.value
        try template.setEntry(named: "Data/user-art.bin", data: Data([4, 5, 6]))
        let originalTheme = template.presentation["theme"]
        let originalPresets = template.presets
        let result = try KeyxAuthor.render(DeckIR(meta: Meta(title: "New"),
            slides: [IRSlide(id: "new", layout: "bullets", title: "New title", body: Body(bullets: [Bullet(text: "New words")]))]),
            template: template)
        let reopened = try KeyxDocument(data: result.document.data())
        #expect(reopened.presentation["theme"] == originalTheme)
        #expect(reopened.presets == originalPresets)
        #expect(reopened.entryData(named: "Data/user-art.bin") == Data([4, 5, 6]))
        #expect(try reopened.inspectSlide(at: 0).title == "New title")
        #expect(try reopened.inspectSlide(at: 0).texts.contains("New words"))
        #expect(try !reopened.inspectSlide(at: 0).texts.contains("Starter content"))
    }

    @Test func unsupportedAuthoringFailsInsteadOfDiscardingData() throws {
        let chart = IRChart(kind: "pie", categories: ["A"], series: [
            IRSeries(name: "one", values: [1]), IRSeries(name: "two", values: [2])
        ])
        #expect(throws: KeyxError.self) {
            try KeyxAuthor.render(DeckIR(meta: Meta(title: "Bad"), slides: [
                IRSlide(id: "one", layout: "chart", body: Body(chart: chart))
            ]))
        }
        #expect(throws: KeyxError.self) {
            try KeyxAuthor.render(DeckIR(meta: Meta(title: "Bad"), slides: [
                IRSlide(id: "one", layout: "not-a-layout", title: "No omission")
            ]))
        }
    }

    @Test func generatedLayoutsAreReusableWithoutStarterWordsOrUnusedPlaceholders() throws {
        let first = try KeyxAuthor.render(DeckIR(meta: Meta(title: "Source"), slides: [
            IRSlide(id: "source", layout: "title", title: "Starter title", body: Body(subtitle: "Starter words"))
        ])).document
        let chart = IRChart(kind: "bar", categories: ["One"], series: [IRSeries(name: "Values", values: [3])])
        let result = try KeyxAuthor.render(DeckIR(meta: Meta(title: "New"), slides: [
            IRSlide(id: "new", layout: "chart", title: "New chart", body: Body(chart: chart))
        ]), template: first)
        let reopened = try KeyxDocument(data: result.document.data())
        #expect(reopened.presentation["theme"] == first.presentation["theme"])
        #expect(reopened.presets == first.presets)
        #expect(try reopened.inspectSlide(at: 0).texts == ["New chart"])
        #expect(try reopened.inspectSlide(at: 0).charts[0].values == [[3]])
        #expect(try reopened.slides[0].contents.contains {
            $0.node["placeholder_info"]?["defined"]?["kind"]?.string == "body"
                && $0.node["placeholder_info"]?["defined"]?["is_visible"]?.bool == false
        })
    }

    @Test func unsupportedPreviewContentRemainsSaved() throws {
        var doc = try KeyxDocument(presentation: KeyxNode(type: "presentation", fields: [
            "slides": .array([KeyxSlide(identifier: "one").node.value])
        ]))
        let unknown = KeyxSlideObject(node: KeyxNode(type: "slide-object", fields: [
            "object": .object(["future_widget": .object(["payload": .number("9007199254740993")])])
        ]))
        try doc.editSlide(at: 0) { $0.setContents([unknown]) }
        let bytes = try doc.data()
        let reopened = try KeyxDocument(data: bytes)
        let preview = try KeyxPreviewRenderer.render(reopened, slideAt: 0)
        #expect(preview.warnings.contains { $0.contains("Unrecognized") })
        #expect(try reopened.slides[0].contents[0] == unknown)
    }

    @Test func previewUsesAbsoluteGroupCoordinatesAndEscapesText() throws {
        let shape = KeyxCanvasObject(kind: "textbox", properties: KeyxNode(type: "textbox", fields: [
            "geometry": KeyxGeometry(x: 100, y: 200, width: 50, height: 30).node.value,
            "text": KeyxText("<script> & words").node.value
        ]))
        let group = KeyxCanvasObject(kind: "group", properties: KeyxNode(type: "group", fields: [
            "geometry": KeyxGeometry(x: 50, y: 150, width: 100, height: 100).node.value,
            "children": .array([shape.node.value])
        ]))
        let doc = try KeyxDocument(presentation: KeyxNode(type: "presentation", fields: [
            "slides": .array([KeyxSlide(identifier: "one", contents: [KeyxSlideObject(canvas: group)]).node.value])
        ]))
        let svg = try KeyxPreviewRenderer.render(doc, slideAt: 0).svg
        #expect(svg.contains("translate(125.0 215.0)"))
        #expect(!svg.contains("<script>"))
        #expect(svg.contains("&lt;script&gt;"))
    }

    @Test func estimatedPreviewAdvancesDoNotInsertGapsBetweenWords() throws {
        let canvas = KeyxCanvasObject(kind: "textbox", properties: KeyxNode(type: "textbox", fields: [
            "geometry": KeyxGeometry(x: 0, y: 0, width: 800, height: 100).node.value,
            "text": KeyxText(runs: [
                KeyxTextRun("Words stay "),
                KeyxTextRun("together", style: KeyxNode(type: "character-properties", fields: ["bold": .bool(true)]))
            ]).node.value
        ]))
        let document = try KeyxDocument(presentation: KeyxNode(type: "presentation", fields: [
            "slides": .array([KeyxSlide(identifier: "words", contents: [KeyxSlideObject(canvas: canvas)]).node.value])
        ]))
        let preview = try KeyxPreviewRenderer.render(document, slideAt: 0)
        #expect(preview.svg.components(separatedBy: "<text ").count == 2)
        #expect(preview.svg.contains("font-weight=\"700\""))
        #expect(preview.warnings.contains { $0.contains("estimated advances") })
    }
}
