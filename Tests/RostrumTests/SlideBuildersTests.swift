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
            ("table", { try $0.tableSlide("T", rows: [["A", "B"], ["1", "2"]]) }),
            ("timeline", { try $0.timelineSlide("T", milestones: [("Q1", "one"), ("Q2", "two")]) }),
            ("quadrant", { try $0.quadrantSlide("Q", quadrants: [("a", "1"), ("b", "2"),
                                                                 ("c", "3"), ("d", "4")]) }),
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

    // MARK: - Tables

    @Test func tableSlideBuildsARectangularGridWithProportionalColumns() throws {
        let deck = try Presentation()
        let slide = try deck.tableSlide("Plans", rows: [
            ["Plan", "Notes"],
            ["Starter", "a much longer cell than the first column ever holds"],
            ["Team"],                                    // ragged on purpose
        ])
        let tbl = try #require(slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:spTree")?.children(named: "p:graphicFrame").first?
            .firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
            .firstChild(named: "a:tbl"))
        let rows = tbl.children(named: "a:tr")
        #expect(rows.count == 3)
        // A short row is padded, so every row has a cell per grid column.
        #expect(rows.allSatisfy { $0.children(named: "a:tc").count == 2 })
        let widths = tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol")
            .compactMap { $0[attribute: "w"].flatMap(Int.init) } ?? []
        #expect(widths.count == 2)
        #expect(widths[1] > widths[0])          // the wordier column gets more room
        #expect(try deck.validate().isEmpty)
    }

    @Test func tableSlideColumnsSpanTheContentRectExactly() throws {
        let deck = try Presentation()
        let slide = try deck.tableSlide("W", rows: [["a", "bb", "ccc"], ["1", "2", "3"]])
        let frame = try #require(slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:spTree")?.children(named: "p:graphicFrame").first)
        let total = frame.firstChild(named: "p:xfrm")?.firstChild(named: "a:ext")?[attribute: "cx"]
            .flatMap(Int.init) ?? 0
        let widths = frame.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
            .firstChild(named: "a:tbl")?.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol")
            .compactMap { $0[attribute: "w"].flatMap(Int.init) } ?? []
        #expect(widths.reduce(0, +) == total)   // no rounding gap at the right edge
    }

    // MARK: - Internal links

    @Test func slideLinkPointsAtAnotherSlideInTheSameDeck() throws {
        let deck = try Presentation()
        let agenda = try deck.bulletSlide("Agenda", ["Results"])
        let target = try deck.sectionSlide("Results")
        let run = try #require(agenda.shapes.compactMap(\.textFrame)
            .flatMap(\.paragraphs).flatMap(\.runs).first { $0.text == "Results" })
        run.setSlideLink(to: target)

        let rel = try #require(agenda.part.rels.items.first { $0.type == RelType.slide })
        #expect(!rel.isExternal)                                  // internal, not a URL
        #expect(rel.target.contains(target.part.uri.filename))
        #expect(run.hyperlink?.contains("slide") == true)
        // The jump action is what makes PowerPoint navigate rather than browse.
        let hlink = try #require(agenda.part.dom()
            .firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?
            .children(named: "p:sp").compactMap { $0.firstChild(named: "p:txBody") }
            .flatMap { $0.children(named: "a:p") }
            .flatMap { $0.children(named: "a:r") }
            .compactMap { $0.firstChild(named: "a:rPr")?.firstChild(named: "a:hlinkClick") }
            .first)
        #expect(hlink[attribute: "action"] == "ppaction://hlinksldjump")
        #expect(try deck.validate().isEmpty)
    }

    @Test func numericTableColumnsAlignRightAndTextColumnsDoNot() throws {
        let deck = try Presentation()
        let slide = try deck.tableSlide("Plans", rows: [
            ["Plan", "Seats", "Price", "Support"],
            ["Starter", "5", "$29", "Community"],
            ["Team", "1,200", "$1,499", "Email"],
        ])
        let tbl = try #require(slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:spTree")?.children(named: "p:graphicFrame").first?
            .firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
            .firstChild(named: "a:tbl"))
        func alignments(ofColumn column: Int) -> [String?] {
            tbl.children(named: "a:tr").map { row in
                row.children(named: "a:tc")[column].firstChild(named: "a:txBody")?
                    .children(named: "a:p").first?.firstChild(named: "a:pPr")?[attribute: "algn"]
            }
        }
        // Figures only read as a column when their digits line up — header
        // included, or it floats away from what it labels.
        #expect(alignments(ofColumn: 1).allSatisfy { $0 == "r" })
        #expect(alignments(ofColumn: 2).allSatisfy { $0 == "r" })
        // Words stay left, and a column mixing words in is not numeric.
        #expect(alignments(ofColumn: 0).allSatisfy { $0 != "r" })
        #expect(alignments(ofColumn: 3).allSatisfy { $0 != "r" })
    }

    @Test func aColumnMixingWordsWithFiguresStaysLeftAligned() throws {
        let deck = try Presentation()
        let slide = try deck.tableSlide("Plans", rows: [
            ["Plan", "Seats"],
            ["Starter", "5"],
            ["Enterprise", "Unlimited"],       // one word makes the column non-numeric
        ])
        let tbl = try #require(slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:spTree")?.children(named: "p:graphicFrame").first?
            .firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
            .firstChild(named: "a:tbl"))
        let aligned = tbl.children(named: "a:tr").map { row in
            row.children(named: "a:tc")[1].firstChild(named: "a:txBody")?
                .children(named: "a:p").first?.firstChild(named: "a:pPr")?[attribute: "algn"]
        }
        #expect(aligned.allSatisfy { $0 != "r" })
    }

    // MARK: - Timeline and quadrant

    /// Preset geometries used on a slide, in document order.
    private func geometries(_ slide: Slide) throws -> [String] {
        (try slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:spTree")?.children(named: "p:sp") ?? [])
            .compactMap { $0.firstChild(named: "p:spPr")?.firstChild(named: "a:prstGeom")?[attribute: "prst"] }
    }

    private func text(_ slide: Slide) throws -> String {
        allRuns(try slide.part.dom()).compactMap { $0.firstChild(named: "a:t")?.textContent }
            .joined(separator: " ")
    }

    @Test func timelineDrawsAMarkerPerMilestoneOnOneRule() throws {
        let deck = try Presentation()
        let slide = try deck.timelineSlide("Roadmap", milestones: [
            ("Q1", "Zip core"), ("Q2", "Charts"), ("Q3", "Corpus"),
        ])
        #expect(try geometries(slide).filter { $0 == "ellipse" }.count == 3)
        #expect(try geometries(slide).contains("rect"))          // the rule they sit on
        let words = try text(slide)
        for word in ["Q1", "Q2", "Q3", "Zip core", "Charts", "Corpus"] {
            #expect(words.contains(word))
        }
        #expect(try deck.validate().isEmpty)
    }

    @Test func timelineDropsMilestonesPastItsCapacity() throws {
        let deck = try Presentation()
        let many = (1...9).map { (label: "M\($0)", detail: "d\($0)") }
        let slide = try deck.timelineSlide("Too many", milestones: many)
        #expect(try geometries(slide).filter { $0 == "ellipse" }.count == SlideCapacity.timeline)
    }

    @Test func quadrantNeedsExactlyFour() throws {
        let deck = try Presentation()
        // Three is a different diagram, so the builder declines to guess: the
        // slide keeps its title and draws no cells at all.
        let short = try deck.quadrantSlide("Priorities", quadrants: [
            ("Alpha", "1"), ("Beta", "2"), ("Gamma", "3"),
        ])
        let words = try text(short)
        #expect(words.contains("Priorities"))
        #expect(!words.contains("Alpha") && !words.contains("Beta") && !words.contains("Gamma"))
    }

    @Test func quadrantKeepsAxisCaptionsClearOfTheCards() throws {
        let deck = try Presentation()
        let slide = try deck.quadrantSlide("Q", quadrants: [
            ("Ship now", "high value"), ("Plan", "high effort"),
            ("Fill-in", "low value"), ("Avoid", "low effort"),
        ], xAxis: "Effort", yAxis: "Value")
        let words = try text(slide)
        for word in ["Ship now", "Plan", "Fill-in", "Avoid", "Effort", "Value"] {
            #expect(words.contains(word))
        }
        // The y caption used to print straight over the top row of cards: every
        // card has to start below it, and the x caption below every card.
        let boxes = slide.shapes.all.map(\.frame).filter { $0.height.rawValue > 0 }
        let cards = boxes.filter { $0.height.rawValue >= EMU.inches(0.8).rawValue }
        #expect(cards.count >= 4)
        let cardTop = cards.map(\.y.rawValue).min() ?? 0
        let cardBottom = cards.map(\.maxY.rawValue).max() ?? 0
        let captions = boxes.filter { $0.height.rawValue < EMU.inches(0.5).rawValue }
        #expect(captions.contains { $0.maxY.rawValue <= cardTop }, "no caption above the cards")
        #expect(captions.contains { $0.y.rawValue >= cardBottom }, "no caption below the cards")
        #expect(try deck.validate().isEmpty)
    }
    // MARK: - Overprint

    /// Nothing a builder draws may sit on top of its own title.
    ///
    /// `comparisonSlide` reached one row above the content row to buy its cards
    /// headroom, which was safe while `placeHeader` left a spare row and
    /// stopped being safe when that arithmetic tightened — the row above
    /// content became the title's own, and a 40pt headline had its descenders
    /// covered by 0.29in of card. The compensation and the thing it compensated
    /// for lived in different functions, so nothing caught it. This is the
    /// invariant that would have.
    /// Every builder, every pair of shapes it draws: text may not be printed
    /// over other text.
    ///
    /// The title-only version of this caught `comparisonSlide`. This is the
    /// same idea without the special case — the complaint that keeps coming
    /// back is "overprint", and it does not care which shape was on top.
    ///
    /// Filled shapes a text box deliberately sits on — a card, a band, a
    /// coloured tile — are excluded by only comparing shapes that *carry text*.
    @Test func noBuilderPrintsTextOverText() throws {
        let title = "The demand side is already straining"
        for (name, make) in titledBuilders {
            let deck = try Presentation()
            let slide = try make(deck, title)
            let texts = slide.shapes.all.filter { !($0.textFrame?.text ?? "").isEmpty }
            for i in texts.indices {
                for j in texts.indices where j > i {
                    let a = texts[i].frame, b = texts[j].frame
                    let overlapX = Swift.min(a.maxX.rawValue, b.maxX.rawValue)
                        - Swift.max(a.x.rawValue, b.x.rawValue)
                    let overlapY = Swift.min(a.maxY.rawValue, b.maxY.rawValue)
                        - Swift.max(a.y.rawValue, b.y.rawValue)
                    guard overlapX > 0, overlapY > 0 else { continue }
                    let smaller = Swift.min(a.width.rawValue * a.height.rawValue,
                                            b.width.rawValue * b.height.rawValue)
                    let fraction = Double(overlapX * overlapY) / Double(Swift.max(1, smaller))
                    let one = (texts[i].textFrame?.text ?? "").prefix(20)
                    let two = (texts[j].textFrame?.text ?? "").prefix(20)
                    #expect(fraction < 0.05,
                            "\(name): \"\(one)\" and \"\(two)\" overlap by \(Int(fraction * 100))%")
                }
            }
        }
    }

    /// The builders that draw a title, shared by the overprint checks.
    private var titledBuilders: [(String, (Presentation, String) throws -> Slide)] { [
        ("bullet", { try $0.bulletSlide($1, ["one", "two", "three"]) }),
        ("bulletLead", { try $0.bulletSlide($1, ["one", "two"], kicker: "Section",
                                            lead: "A single sector with N >= 2 symmetric firms, "
                                                + "each owned by an equity holder.") }),
        ("twoColumn", { try $0.twoColumnSlide($1, left: ["l"], right: ["r"]) }),
        ("comparison", { try $0.comparisonSlide($1, leftHeader: "Q1 2026 GDP growth",
                                                left: ["a"], rightHeader: "Household finances",
                                                right: ["b"]) }),
        ("chart", { try $0.chartSlide($1, .barClustered,
                                      ChartData(categories: ["A", "B"], name: "s", values: [1, 2])) }),
        ("metrics", { try $0.metricsSlide($1, metrics: [("2,000", "papers sampled"),
                                                        ("292", "test cases curated")]) }),
        ("bands", { try $0.bandsSlide($1, bands: ["one", "two", "three"]) }),
        ("process", { try $0.processSlide($1, steps: ["Sample — pull 2,000 papers from recent "
                                                      + "NeurIPS proceedings",
                                                      "Filter — keep only papers with a diagram",
                                                      "Restrict — require landscape aspect ratio",
                                                      "Categorize — tag each figure by type",
                                                      "Curate — annotators verify quality"]) }),
        ("pyramid", { try $0.pyramidSlide($1, levels: ["base", "middle", "peak"]) }),
        ("table", { try $0.tableSlide($1, rows: [["A", "B"], ["1", "2"]]) }),
        ("timeline", { try $0.timelineSlide($1, milestones: [("Q1", "one"), ("Q2", "two")]) }),
        ("quadrant", { try $0.quadrantSlide($1, quadrants: [("a", "1"), ("b", "2"),
                                                            ("c", "3"), ("d", "4")]) }),
    ] }

    @Test func noBuilderPrintsOverItsOwnTitle() throws {
        let title = "The demand side is already straining"
        let builders: [(String, (Presentation) throws -> Slide)] = [
            ("bullet", { try $0.bulletSlide(title, ["one", "two", "three"]) }),
            ("twoColumn", { try $0.twoColumnSlide(title, left: ["l"], right: ["r"]) }),
            ("comparison", { try $0.comparisonSlide(title, leftHeader: "Q1 2026 GDP growth",
                                                    left: ["a"], rightHeader: "Household finances",
                                                    right: ["b"]) }),
            ("chart", { try $0.chartSlide(title, .barClustered,
                                          ChartData(categories: ["A", "B"], name: "s", values: [1, 2])) }),
            ("metrics", { try $0.metricsSlide(title, metrics: [("2,000", "papers"), ("292", "cases")]) }),
            ("bands", { try $0.bandsSlide(title, bands: ["one", "two", "three"]) }),
            ("process", { try $0.processSlide(title, steps: ["one", "two", "three"]) }),
            ("pyramid", { try $0.pyramidSlide(title, levels: ["base", "middle", "peak"]) }),
            ("table", { try $0.tableSlide(title, rows: [["A", "B"], ["1", "2"]]) }),
            ("timeline", { try $0.timelineSlide(title, milestones: [("Q1", "one"), ("Q2", "two")]) }),
            ("quadrant", { try $0.quadrantSlide(title, quadrants: [("a", "1"), ("b", "2"),
                                                                   ("c", "3"), ("d", "4")]) }),
        ]
        for (name, make) in builders {
            let deck = try Presentation()
            let slide = try make(deck)
            guard let titleShape = slide.shapes.all.first(where: {
                ($0.textFrame?.text ?? "").contains("demand side")
            }) else {
                Issue.record(Comment(rawValue: "\(name) drew no title")); continue
            }
            let band = titleShape.frame
            for other in slide.shapes.all where other.frame != band {
                let f = other.frame
                let overlapY = Swift.min(f.maxY.rawValue, band.maxY.rawValue)
                    - Swift.max(f.y.rawValue, band.y.rawValue)
                let overlapX = Swift.min(f.maxX.rawValue, band.maxX.rawValue)
                    - Swift.max(f.x.rawValue, band.x.rawValue)
                let inches = Double(Swift.max(0, overlapY)) / 914_400
                #expect(overlapY <= 0 || overlapX <= 0,
                        "\(name): a shape overlaps the title by \(inches)in vertically")
            }
        }
    }
    /// Text may not run past the box it was given.
    ///
    /// The overprint people actually see is usually this, not two frames
    /// intersecting: a caption in a narrow column wraps to five lines, runs
    /// out of the bottom of its own tile, and lands on whatever is beneath.
    /// The frames never touch, so a box-overlap check finds nothing.
    ///
    /// Estimated at 0.52em average advance and 1.25 line height — the same
    /// arithmetic the builders fit against — with a generous tolerance, so
    /// this fails on genuine overflow rather than on a rounding disagreement.
    @Test func textFitsInsideTheBoxItWasGiven() throws {
        let title = "The demand side is already straining"
        for (name, make) in titledBuilders {
            let deck = try Presentation()
            let slide = try make(deck, title)
            for shape in slide.shapes.all {
                guard let frame = shape.textFrame else { continue }
                let text = frame.text
                guard !text.isEmpty else { continue }
                let widthPt = Double(shape.frame.width.rawValue) / Double(EMU.perPoint)
                let heightPt = Double(shape.frame.height.rawValue) / Double(EMU.perPoint)
                guard widthPt > 1, heightPt > 1 else { continue }

                var needed = 0.0
                for paragraph in frame.paragraphs {
                    let size = paragraph.runs.compactMap(\.fontSize).max() ?? 18
                    let body = paragraph.runs.map(\.text).joined()
                    guard !body.isEmpty else { needed += size * 1.25; continue }
                    let perLine = Swift.max(1.0, widthPt / (0.52 * size))
                    let lines = (Double(body.count) / perLine).rounded(.up)
                    needed += lines * size * 1.25
                }
                // 1.6x: autofit shrinks text the estimate does not know about,
                // so only a clear overflow should fail.
                #expect(needed <= heightPt * 1.6,
                        "\(name): \"\(text.prefix(28))\" needs ~\(Int(needed))pt in a \(Int(heightPt))pt box")
            }
        }
    }
}
