import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite struct TemplateRenderingTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func wrappedTableRowsReserveSpaceBeforeTheCaption() async throws {
        let source = try Presentation()
        source.documentKind = .template
        let template = try PowerPointTemplate(data: source.serializedData(), name: "Corporate")
        let table = IRTable(headers: ["Term", "Plain meaning", "Example"], rows: [
            ["Anomaly", "Difference from a baseline", "Temperature above reference"],
            ["CO₂-equivalent", "Common warming-impact scale", "Methane in CO₂ units"],
            ["Mitigation", "Limit climate-change drivers", "Replace coal power"],
            ["Adaptation", "Reduce harm from impacts", "Heat-health action plans"],
            ["Net zero CO₂", "CO₂ emissions = removals", "Balance residual emissions"],
            ["Tipping point", "Threshold for system change", "Ice-sheet instability"]])
        let input = DeckIR(meta: Meta(title: "Wrapped table"), slides: [IRSlide(id: "table", layout: "table",
            title: "Shared vocabulary", body: Body(table: table, source: "Six terms distinguish measurements, responses and long-term risks."))])
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: false, into: dir, template: template)
        let deck = try Presentation(contentsOf: result.url)
        let slide = try deck.slides[0]
        let shape = try #require(slide.shapes.all.first { $0 is TableFrame })
        let frame = try #require(slide.effectiveFrame(of: shape))
        let caption = try #require(slide.shapes.all.first { $0.textFrame?.text == input.slides[0].body?.source })
        #expect(slide.effectiveFrame(of: caption)!.y.points >= frame.maxY.points + 7.9)
        let heights = TemplateRendering.tableRowHeights(table, width: frame.width.points,
            style: DeckStyle(theme: slide.master!.theme!), engine: TemplateLayoutEngine(presentation: deck, measure: TemplateRendering.measurer))
        #expect(frame.height.points >= heights.reduce(0, +) - 0.01)
        #expect(result.schemaIssues.isEmpty)
    }

    @Test func generatedDiagramKeepsItsWholeAspectInsideThePlaceholder() {
        var bytes: [UInt8] = [137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]
        bytes += [0,0,1,64,0,0,0,180,8,6,0,0,0,0,0,0,0]
        let region = Rect(x: .points(20), y: .points(30), width: .points(480), height: .points(540))
        let fit = TemplateRendering.containedImageFrame(Data(bytes), in: region)
        #expect(abs(fit.width.points / fit.height.points - 16.0 / 9.0) < 0.001)
        #expect(fit.x >= region.x && fit.maxX <= region.maxX)
        #expect(fit.y > region.y && fit.maxY < region.maxY)
    }

    @Test func longObjectCaptionsAreMeasuredBeforeAllocatingChartAndTable() async throws {
        let source = try Presentation()
        source.documentKind = .template
        let template = try PowerPointTemplate(data: source.serializedData(), name: "Corporate")
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let lead = "NASA’s annual global temperatures are shown relative to 1951–1980, rounded for this layout regression."
        let citation = Array(repeating: "Source details must wrap, remain readable and stay on the slide.", count: 9).joined(separator: "\n")
        let caption = lead + "\n" + citation
        let input = DeckIR(meta: Meta(title: "Long captions"), slides: [
            IRSlide(id: "chart", layout: "chart", title: "Temperature trends", body: Body(
                chart: IRChart(kind: "line", categories: ["A", "B", "C"], series: [IRSeries(name: "Test", values: [1, 2, 3])]),
                lead: lead, source: citation)),
            IRSlide(id: "table", layout: "table", title: "Test observations", body: Body(
                table: IRTable(headers: ["Period", "Value"], rows: [["A", "1"], ["B", "2"]]), lead: lead, source: citation))
        ])
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: false, into: dir, template: template)
        let deck = try Presentation(contentsOf: result.url)
        #expect(deck.slides.count == 2)
        for slide in deck.slides {
            let text = try #require(slide.shapes.all.first { $0.textFrame?.text == caption })
            let frame = try #require(slide.effectiveFrame(of: text))
            let object = try #require(slide.shapes.all.first { $0 is GraphicFrame })
            let objectFrame = try #require(slide.effectiveFrame(of: object))
            #expect(frame.height.points > 72)
            #expect(frame.y.points >= objectFrame.maxY.points + 8)
            #expect(frame.maxY <= deck.bounds.maxY)
            #expect(objectFrame.height.points >= 144)
            #expect(text.textFrame?.paragraphs.first?.runs.first?.fontSize == 13)
        }
        #expect(result.schemaIssues.isEmpty)
    }

    @Test func oversizedCaptionContinuesWithoutLosingTextOrSectionMembership() async throws {
        let source = try Presentation()
        source.documentKind = .template
        let template = try PowerPointTemplate(data: source.serializedData(), name: "Corporate")
        let text = (1...60).map { "Source paragraph \($0): this explanation must stay visible at a readable size and retain every supplied word." }.joined(separator: "\n")
        let input = DeckIR(meta: Meta(title: "Caption continuation"), sections: [IRSection(id: "evidence", title: "Evidence", slideIds: ["chart"])], slides: [
            IRSlide(id: "chart", sectionId: "evidence", layout: "chart", title: "Evidence", body: Body(
                chart: IRChart(kind: "line", categories: ["A", "B"], series: [IRSeries(name: "Test", values: [1, 2])]), source: text), notes: "Original speaker notes")
        ])
        var warnings: [String] = []
        let expanded = try TemplateRendering.prepare(input, in: source, template: template, warnings: &warnings)
        #expect(expanded.slides.count > 2)
        let recovered = expanded.slides.dropFirst().flatMap { ($0.body?.bullets ?? []).map(\.text) }.joined(separator: " ")
        #expect(recovered == text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
        #expect(expanded.sections?.first?.slideIds == expanded.slides.map(\.id))
        #expect(expanded.slides.allSatisfy { $0.sectionId == "evidence" })
        #expect(expanded.slides.first?.notes == "Original speaker notes")
        #expect(!warnings.isEmpty)
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: true, into: dir, template: template)
        let deck = try Presentation(contentsOf: result.url)
        #expect(deck.slides.count == expanded.slides.count)
        #expect(result.schemaIssues.isEmpty)
        try deck.validateTemplateBindings()
    }

    @Test func templateSurvivesEndToEndAndDoesNotReceiveThemeOverrides() async throws {
        let source = try Presentation()
        source.theme.majorFont = "Georgia"
        source.theme.setAccent(1, Color("006699"))
        source.documentKind = .template
        let template = try PowerPointTemplate(data: source.serializedData(), name: "Corporate")
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = DeckIR(meta: Meta(title: "Template acceptance"), slides: [
            IRSlide(id: "title", layout: "title", title: "Template acceptance", body: Body(subtitle: "Native inheritance")),
            IRSlide(id: "body", layout: "bullets", title: "Preserved design", body: Body(bullets: [Bullet(text: "A concise point")]))
        ])
        let result = try await DeckRenderer().render(input, designURL: URL(fileURLWithPath: "/does-not-exist.md"), notesEnabled: false, into: dir, template: template)
        let deck = try Presentation(contentsOf: result.url)
        #expect(deck.documentKind == .presentation)
        #expect(deck.slides.count == 2)
        #expect(deck.theme.majorFont == "Georgia")
        #expect(deck.theme.accent(1) == Color("006699"))
        #expect(deck.allLayouts.count == source.allLayouts.count)
        #expect(try deck.slides[1].title?.explicitFrame == nil)
        #expect(try deck.slides[1].shapes.all.count == 2)
        try deck.validateTemplateBindings()
        #expect(result.schemaIssues.isEmpty)
    }

    @Test func themedDeckPublishesLayoutsAndNativeObjects() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = DeckIR(meta: Meta(title: "Own theme"), slides: [
            IRSlide(id: "title", layout: "title", title: "Own theme"),
            IRSlide(id: "body", layout: "bullets", title: "Useful content", body: Body(bullets: [Bullet(text: "One point")]))
        ])
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: false, into: dir)
        let deck = try Presentation(contentsOf: result.url)
        for slide in deck.slides {
            #expect(slide.layout?.name.hasPrefix("Lectern —") == true)
            #expect(slide.title?.explicitFrame == nil)
            #expect(slide.master?.name == "Lectern Theme")
        }
        try deck.validateTemplateBindings()
        #expect(result.schemaIssues.isEmpty)
    }
}
