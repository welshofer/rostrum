import Foundation
import Testing
@testable import Rostrum

@Suite struct SlideBuildersTests {
    /// Every builder must produce a FREE-SHAPE slide: no placeholders, real
    /// shapes, and exactly ONE slideLayout relationship (the top blankCanvas risk).
    @Test func everyBuilderIsFreeShapeWithOneLayoutRel() throws {
        let builders: [(String, (Presentation) throws -> Slide)] = [
            ("title", { try $0.titleSlide("T", subtitle: "S", kicker: "K") }),
            ("section", { try $0.sectionSlide("Sec", subtitle: "sub", number: 1) }),
            ("bullet", { try $0.bulletSlide("B", ["a", "b", "c"], kicker: "K") }),
            ("twoColumn", { try $0.twoColumnSlide("Two", left: ["l1"], right: ["r1"]) }),
            ("comparison", { try $0.comparisonSlide("C", leftHeader: "L", left: ["a"], rightHeader: "R", right: ["b"]) }),
            ("chart", { try $0.chartSlide("Ch", .barClustered, ChartData(categories: ["A", "B"], name: "S", values: [1, 2])) }),
            ("callout", { try $0.calloutSlide(stat: "47", caption: "NPS") }),
            ("quote", { try $0.quoteSlide("Q", attribution: "me") }),
        ]
        for (name, make) in builders {
            let deck = try Presentation()
            let slide = try make(deck)
            #expect(slide.placeholders.isEmpty, "\(name) leaked a placeholder")
            #expect(!slide.shapes.all.isEmpty, "\(name) produced no shapes")
            #expect(slide.part.rels.items.filter { $0.type == RelType.slideLayout }.count == 1,
                    "\(name) has != 1 layout rel")
        }
    }

    @Test func buildsOneOfEachValidatesAndReopens() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            try deck.titleSlide("Q3 Business Review", subtitle: "Northwind", kicker: "FY26")
            try deck.sectionSlide("The Quarter", number: 1)
            try deck.bulletSlide("Highlights", ["ARR $18.4M", "Retention 91%"])
            try deck.twoColumnSlide("Growth", left: ["New logos"], right: ["Expansion"])
            try deck.comparisonSlide("Plan vs Actual", leftHeader: "Ahead", left: ["ARR"], rightHeader: "Behind", right: ["EMEA"])
            try deck.chartSlide("ARR", .line, ChartData(categories: ["Q1", "Q2", "Q3"], name: "ARR", values: [16, 17, 18]))
            try deck.calloutSlide(stat: "47", caption: "NPS, up from 31", kicker: "Sentiment")
            try deck.quoteSlide("Best quarter yet.", attribution: "The board")
            #expect(deck.slides.count == 9)          // 1 initial + 8 built
            #expect(try deck.validate().isEmpty)
            return try deck.serializedData()
        }
        let a = try build(), b = try build()
        #expect(a == b)                               // byte-deterministic
        _ = try Presentation(data: a)                 // reopens
    }

    @Test func bulletSlideReadsBack() throws {
        let deck = try Presentation()
        let slide = try deck.bulletSlide("Highlights", ["Alpha", "Beta", "Gamma"])
        let reopened = try Presentation(data: try deck.serializedData())
        let back = try reopened.slides[reopened.slides.count - 1]
        let text = back.shapes.compactMap { $0.textFrame?.text }.joined(separator: " ")
        #expect(text.contains("Alpha") && text.contains("Gamma"))
        // The bullet list carries real bullet chars.
        let hasBullet = try back.part.dom().firstChild(named: "p:cSld")!
            .firstChild(named: "p:spTree")!.children(named: "p:sp")
            .contains { $0.firstChild(named: "p:txBody")?.children(named: "a:p")
                .contains { $0.firstChild(named: "a:pPr")?.firstChild(named: "a:buChar") != nil } ?? false }
        #expect(hasBullet)
        #expect(slide.placeholders.isEmpty)
    }

    @Test func titleSlideUsesDisplayScaleAndLegibleColor() throws {
        let deck = try Presentation()
        try deck.titleSlide("Hello", subtitle: "World")
        let s = deck.style
        let reopened = try Presentation(data: try deck.serializedData())
        let slide = try reopened.slides[reopened.slides.count - 1]
        let dom = try slide.part.dom()
        let runs = allRuns(dom)
        // Some run is at the display size, and its color is legible on the bg.
        let sz = String(Int(s.type(.display).sizePt * 100))
        #expect(runs.contains { $0.firstChild(named: "a:rPr")?[attribute: "sz"] == sz })
        let titleColor = runs.first { $0.firstChild(named: "a:rPr")?[attribute: "sz"] == sz }
            .flatMap { $0.firstChild(named: "a:rPr")?.firstChild(named: "a:solidFill")?
                .firstChild(named: "a:srgbClr")?[attribute: "val"] }
        #expect(titleColor != nil)
        #expect(Color(titleColor!).contrastRatio(with: s.background) >= 4.5)
    }

    @Test func sectionSlideAutoContrastsOnLightAccent() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse("## Palette\n- Accent 1: #FFD02F"))   // light accent
        try deck.sectionSlide("Looking Ahead")
        let reopened = try Presentation(data: try deck.serializedData())
        let slide = try reopened.slides[reopened.slides.count - 1]
        let dom = try slide.part.dom()
        let bg = dom.firstChild(named: "p:cSld")!.firstChild(named: "p:bg")!
            .firstChild(named: "p:bgPr")!.firstChild(named: "a:solidFill")!
            .firstChild(named: "a:srgbClr")![attribute: "val"]!
        #expect(bg == "FFD02F")
        // Title text must clear AA against the yellow section field.
        let titleColor = allRuns(dom).first?.firstChild(named: "a:rPr")?
            .firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"]
        #expect(titleColor != nil)
        #expect(Color(titleColor!).contrastRatio(with: Color("FFD02F")) >= 4.5)
    }

    @Test func potxPlusDesignComesOutOnBrand() throws {
        // Synthesize a .potx, open it, apply a brand, and build a slide.
        let base = try Presentation()
        base.package.contentTypes.setOverride(
            partName: PackURI("/ppt/presentation.xml"), contentType: ContentType.presentationTemplateMain)
        let deck = try Presentation(data: try base.serializedData())
        deck.applyDesign(Design.parse("""
        ## Fonts
        - Heading: Georgia
        ## Palette
        - Background: #0B1D33
        - Text: #F7F4EE
        """))
        try deck.bulletSlide("On brand", ["one", "two"])
        let reopened = try Presentation(data: try deck.serializedData())
        let slide = try reopened.slides[reopened.slides.count - 1]
        let dom = try slide.part.dom()
        let bg = dom.firstChild(named: "p:cSld")!.firstChild(named: "p:bg")!
            .firstChild(named: "p:bgPr")!.firstChild(named: "a:solidFill")!
            .firstChild(named: "a:srgbClr")![attribute: "val"]!
        #expect(bg == "0B1D33")   // theme background flows through deck.style
        #expect(allRuns(dom).contains {
            $0.firstChild(named: "a:rPr")?.firstChild(named: "a:latin")?[attribute: "typeface"] == "Georgia"
        })
    }

    @Test func chartSlideEmbedsChartAndWorkbook() throws {
        let deck = try Presentation()
        try deck.chartSlide("ARR", .line, ChartData(categories: ["Q1", "Q2"], name: "ARR", values: [16, 18]))
        let reopened = try Presentation(data: try deck.serializedData())
        let charts = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/charts/") }
        let books = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/embeddings/") }
        #expect(charts.count == 1 && books.count == 1)
    }

    @Test func returnedSlideIsTweakable() throws {
        let deck = try Presentation()
        let slide = try deck.bulletSlide("T", ["a"])
        let before = slide.shapes.count
        try slide.shapes.addTextBox(Rect(x: .inches(1), y: .inches(6), width: .inches(3), height: .inches(1)))
        #expect(slide.shapes.count == before + 1)
    }

    private func allRuns(_ dom: XML.Element) -> [XML.Element] {
        (dom.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp") ?? [])
            .flatMap { $0.firstChild(named: "p:txBody")?.children(named: "a:p") ?? [] }
            .flatMap { $0.children(named: "a:r") }
    }
}
