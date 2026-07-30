import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct LecternCoreTests {
    private func fixtureJSON() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "deck-mock", withExtension: "json", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }
    private func fixtureDeck() throws -> DeckIR {
        try JSONDecoder().decode(DeckIR.self, from: Data(fixtureJSON().utf8))
    }
    /// A minimal valid PNG. Rostrum never decodes image bytes, it only
    /// packages them, so a well-formed header is enough to exercise placement.
    private func png() -> Data {
        func be32(_ v: Int) -> [UInt8] {
            [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
        }
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        b += be32(13); b += Array("IHDR".utf8)
        b += be32(320); b += be32(180); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }

    private func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-test-\(ProcessInfo.processInfo.globallyUniqueString)")
    }

    // MARK: - IR + validation

    @Test func rendersDiagramSlides() async throws {
        let deck = DeckIR(meta: Meta(title: "Diagrams"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "diagram", title: "Process",
                    body: Body(diagram: IRDiagram(kind: "process", items: ["One", "Two", "Three"]))),
            IRSlide(id: "s3", layout: "diagram", title: "Pyramid",
                    body: Body(diagram: IRDiagram(kind: "pyramid", items: ["Base", "Middle", "Peak"]))),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil, notesEnabled: false, into: dir)
        #expect(result.slideCount == 3)
        #expect(try Presentation(contentsOf: result.url).validate().isEmpty)   // opens clean
    }

    @Test func rendersBandsSlide() async throws {
        let deck = DeckIR(meta: Meta(title: "Bands"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "bands", title: "Three waves",
                    body: Body(items: ["The Signal — repricing", "The Strain — food", "The Rupture — migration"])),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }

        // Default: styled shapes, no SmartArt (SmartArt is opt-in).
        let drawn = try await DeckRenderer().render(validated.deck, designURL: nil, notesEnabled: false, into: dir)
        #expect(drawn.slideCount == 2)
        let reopenedDrawn = try Presentation(contentsOf: drawn.url)
        #expect(try reopenedDrawn.validate().isEmpty)
        #expect(try reopenedDrawn.slides[reopenedDrawn.slides.count - 1].smartArtTexts.isEmpty)

        // Opt-in: native Basic Block List SmartArt (the flex "five layers" look).
        let smart = try await DeckRenderer().render(validated.deck, designURL: nil, notesEnabled: false,
                                                    into: dir, useSmartArt: true)
        let reopenedSmart = try Presentation(contentsOf: smart.url)
        #expect(try reopenedSmart.slides[reopenedSmart.slides.count - 1].smartArtTexts.first?.count == 3)
    }

    @Test func rendersChartAndMetricsSlides() async throws {
        let deck = DeckIR(meta: Meta(title: "Data"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener", body: Body(subtitle: "s")),
            IRSlide(id: "s2", layout: "metrics", title: "Three numbers",
                    body: Body(stats: [IRStat(value: "$300B", label: "losses"), IRStat(value: "1.2°C", label: "warming")])),
            IRSlide(id: "s3", layout: "chart", title: "Rising losses",
                    body: Body(chart: IRChart(kind: "bar", categories: ["2020", "2021", "2022"],
                                              series: [IRSeries(name: "US$B", values: [210, 280, 313])]))),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil, notesEnabled: false, into: dir)
        #expect(result.slideCount == 3)
        #expect(try Presentation(contentsOf: result.url).validate().isEmpty)   // opens clean, with a chart part
    }

    @Test func malformedChartFallsBackInsteadOfCrashing() async throws {
        // series length ≠ categories would trip ChartData's precondition — the
        // renderer must fall back to bullets, not crash.
        let deck = DeckIR(meta: Meta(title: "Data"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "chart", title: "Broken chart",
                    body: Body(bullets: [Bullet(text: "shown instead")],
                               chart: IRChart(kind: "bar", categories: ["a", "b", "c"],
                                              series: [IRSeries(name: "s", values: [1, 2])]))),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil, notesEnabled: false, into: dir)
        #expect(result.slideCount == 2)
    }

    /// The invariant is "a picture is never drawn over text". `.none` on
    /// bullets used to be how that was achieved — there was no way to make
    /// room, so the only safe answer was no image at all. The builders reserve
    /// `sideImagePanel()` now, so bullets and agendas can carry one safely and
    /// the policy changes shape while the invariant does not.
    ///
    /// Every case is listed. A new layout added to `SlideLayoutKind` without a
    /// deliberate decision here is the failure this guards.
    @Test func imagePlacementPolicyKeepsPicturesOffText() {
        // Full-bleed: the picture IS the background, scrimmed, with sparse
        // centred text over it by design.
        #expect(SlideLayoutKind.title.imagePlacement == .fullBleed)
        #expect(SlideLayoutKind.bigNumber.imagePlacement == .fullBleed)
        #expect(SlideLayoutKind.quote.imagePlacement == .fullBleed)
        #expect(SlideLayoutKind.closing.imagePlacement == .fullBleed)

        // Side panel: a single column of text, which the builder narrows to
        // the columns left of the panel. That the narrowing genuinely clears
        // it is pinned in Rostrum by `reservedTextNeverEntersTheSideImagePanel`;
        // this pins which layouts opt in.
        #expect(SlideLayoutKind.sectionHeader.imagePlacement == .sidePanel)
        #expect(SlideLayoutKind.bullets.imagePlacement == .sidePanel)
        #expect(SlideLayoutKind.agenda.imagePlacement == .sidePanel)

        // None: two columns of text, a plotted chart, a row of metrics,
        // stacked bands, a diagram. Narrowing these breaks the layout rather
        // than reflowing it, so there is nowhere for a picture to go that is
        // not on top of something.
        #expect(SlideLayoutKind.twoColumn.imagePlacement == .none)
        #expect(SlideLayoutKind.comparison.imagePlacement == .none)
        #expect(SlideLayoutKind.chart.imagePlacement == .none)
        #expect(SlideLayoutKind.metrics.imagePlacement == .none)
        #expect(SlideLayoutKind.bands.imagePlacement == .none)
        #expect(SlideLayoutKind.diagram.imagePlacement == .none)
        #expect(SlideLayoutKind.unknown("whatever").imagePlacement == .none)
    }

    @Test func qaPassAdoptsAValidRevision() async throws {
        // Draft is the 5-slide fixture; the QA pass returns a tighter 3-slide deck.
        let revised = DeckIR(meta: Meta(title: "Tighter"), slides: [
            IRSlide(id: "a", layout: "title", title: "A sharper opener", body: Body(subtitle: "s")),
            IRSlide(id: "b", layout: "bullets", title: "One clear idea", body: Body(bullets: [Bullet(text: "point")])),
            IRSlide(id: "c", layout: "closing", title: "Do this next", body: Body(callToAction: "Act")),
        ])
        let revisedJSON = String(decoding: try JSONEncoder().encode(revised), as: UTF8.self)
        let provider = FixtureProvider(validJSON: try fixtureJSON(), revisedJSON: revisedJSON)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let events = EventBox()
        let result = try await DeckGenerator(provider: provider)
            .generate(DeckRequest(prompt: "x", slideCount: 3), designURL: nil, into: dir) { events.record($0) }
        #expect(result.slideCount == 3)                     // adopted the revision, not the 5-slide draft
        #expect(events.stages.contains("auditing"))         // the QA pass ran
    }

    @Test func qaPassCanBeDisabled() async throws {
        let provider = FixtureProvider(validJSON: try fixtureJSON(), revisedJSON: "{ garbage")
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        // Even with a broken revision, quality:false skips it and the draft ships.
        let result = try await DeckGenerator(provider: provider, quality: false)
            .generate(DeckRequest(prompt: "x", slideCount: 5), designURL: nil, into: dir) { _ in }
        #expect(result.slideCount == 5)
    }

    @Test func decodesDeckMissingIrVersion() throws {
        // A real model often omits irVersion — it must default, not fail (the
        // deterministic cause of "couldn't parse").
        let json = """
        { "meta": { "title": "Q3" },
          "slides": [ { "id": "s1", "layout": "title", "title": "Q3", "body": { "subtitle": "Review" } } ] }
        """
        let deck = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        #expect(deck.irVersion == DeckIR.currentVersion)
        #expect(deck.slides.count == 1)
        // …and it validates (the renderer would accept it).
        let result = try DeckValidator().validate(deck, requestedSlideCount: 1, notesRequired: false)
        #expect(result.deck.slides.first?.kind == .title)
    }

    @Test func decodesTheExampleIR() throws {
        let deck = try fixtureDeck()
        #expect(deck.irVersion == DeckIR.currentVersion)
        #expect(deck.slides.count == 5)
        #expect(deck.slides.first?.kind == .title)
        #expect(deck.slides.last?.kind == .closing)
        #expect(deck.slides[3].body?.value == "0")
    }

    @Test func validatesACleanDeck() throws {
        let result = try DeckValidator().validate(fixtureDeck(), requestedSlideCount: 5, notesRequired: true)
        #expect(result.warnings.isEmpty)
    }

    @Test func rejectsStructuralViolations() throws {
        var deck = try fixtureDeck()
        deck.slides[1].id = "sl1"                 // duplicate id
        #expect(throws: ValidationError.self) {
            _ = try DeckValidator().validate(deck)
        }
    }

    @Test func downgradesUnknownLayoutWithBulletsBody() throws {
        var deck = try fixtureDeck()
        // Deliberately a layout we do not have. "timeline" used to stand in
        // here and became real, which is the hazard with naming a real-looking
        // one — "sankey" is not on the roadmap.
        deck.slides[1].layout = "sankey"          // unknown, but has a bullets body
        let result = try DeckValidator().validate(deck)
        #expect(result.deck.slides[1].layout == "bullets")
        #expect(result.warnings.contains { $0.contains("downgraded to bullets") })
    }

    @Test func failsUnknownLayoutWithoutBulletsBody() throws {
        var deck = try fixtureDeck()
        deck.slides[3].layout = "hologram"        // unknown, bigNumber body (no bullets)
        #expect(throws: ValidationError.self) { _ = try DeckValidator().validate(deck) }
    }

    // MARK: - Builder capacity

    /// Rostrum's diagram builders truncate past `SlideCapacity` and publish
    /// those ceilings so callers can decide rather than be surprised. Lectern
    /// read none of them: six metrics shipped four and said nothing.
    @Test func contentThatExceedsABuilderCapIsReportedNotSilentlyDropped() async throws {
        var deck = try fixtureDeck()
        // Six metrics against SlideCapacity.metrics == 4, and seven process
        // steps against SlideCapacity.process == 5.
        deck.slides[1].layout = "metrics"
        deck.slides[1].body = Body(stats: (1...6).map { IRStat(value: "\($0)", label: "m\($0)") })
        deck.slides[2].layout = "diagram"
        deck.slides[2].body = Body(diagram: IRDiagram(kind: "process",
                                                      items: (1...7).map { "step \($0)" }))

        let validated = try DeckValidator().validate(deck)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir,
                                                       useSmartArt: false)

        #expect(rendered.droppedContent.count == 2)
        #expect(rendered.droppedContent.contains { $0.contains("2 of 6 metrics") })
        #expect(rendered.droppedContent.contains { $0.contains("2 of 7 process steps") })
        // Reported, not conflated: this is neither a plan warning nor our bug.
        #expect(rendered.warnings.isEmpty)
        #expect(rendered.schemaIssues.isEmpty)
    }

    /// The caps the model stayed inside must stay quiet, or the report is noise.
    @Test func contentInsideEveryCapReportsNothing() async throws {
        var deck = try fixtureDeck()
        deck.slides[1].layout = "metrics"
        deck.slides[1].body = Body(stats: (1...4).map { IRStat(value: "\($0)", label: "m\($0)") })

        let validated = try DeckValidator().validate(deck)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir)
        #expect(rendered.droppedContent.isEmpty)
    }

    /// The validator accepts a `bands` slide whose `items` is `[]` as long as
    /// `bullets` isn't — which is what a model emits when it fills one field
    /// and leaves the other an empty array. The renderer coalesced on nil, not
    /// on empty, so the bullets were never consulted and the slide shipped
    /// with just a title.
    @Test func bandsWithEmptyItemsFallsBackToItsBulletsRatherThanRenderingBlank() async throws {
        var deck = try fixtureDeck()
        deck.slides[1].layout = "bands"
        deck.slides[1].body = Body(items: [],
                                   bullets: [Bullet(text: "first band"), Bullet(text: "second band")])

        let validated = try DeckValidator().validate(deck)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir)

        // The text is on the slide, not lost between validator and renderer.
        let reopened = try Presentation(contentsOf: rendered.url)
        let svg = try reopened.renderSVG(slideAt: 1)
        #expect(svg.contains("first band"))
        #expect(svg.contains("second band"))
    }

    /// Two series with no legend are two indistinguishable sets of bars. One
    /// series with a legend is a label repeating the title.
    @Test func onlyMultiSeriesChartsGetALegend() async throws {
        func render(seriesCount: Int) async throws -> String {
            var deck = try fixtureDeck()
            deck.slides[1].layout = "chart"
            deck.slides[1].body = Body(chart: IRChart(
                kind: "bar",
                categories: ["Q1", "Q2"],
                series: (1...seriesCount).map { IRSeries(name: "s\($0)", values: [1, 2]) }))
            let validated = try DeckValidator().validate(deck)
            let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
            let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                           notesEnabled: false, into: dir)
            #expect(rendered.droppedContent.isEmpty)   // the chart really built
            let deckOnDisk = try Presentation(contentsOf: rendered.url)
            let part = try #require(
                deckOnDisk.package.parts.first { $0.key.value.contains("charts/chart") }?.value)
            return String(decoding: part.blob, as: UTF8.self)
        }

        let multi = try await render(seriesCount: 2)
        let single = try await render(seriesCount: 1)
        #expect(multi.contains("<c:legend>"))
        #expect(!single.contains("<c:legend>"))
    }

    /// Falling back is right — a series whose length disagrees with the
    /// categories makes a chart PowerPoint has to repair. Doing it silently is
    /// not: a chart slide carries no bullets, so the user gets a title and
    /// nothing else, looking like a clean render.
    @Test func aMalformedChartSaysWhyItBecameSomethingElse() async throws {
        var deck = try fixtureDeck()
        deck.slides[1].layout = "chart"
        deck.slides[1].body = Body(chart: IRChart(
            kind: "bar",
            categories: ["Q1", "Q2", "Q3"],
            // Three categories, two values: exactly the mismatch the renderer
            // refuses to build.
            series: [IRSeries(name: "ARR", values: [1, 2])]))

        let validated = try DeckValidator().validate(deck)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir)

        #expect(rendered.droppedContent.contains { $0.contains("chart data was malformed") })
    }

    /// A generated image is the one thing on the slide a screen reader cannot
    /// infer, and the brief that produced it is already a description of it.
    @Test func generatedImagesCarryTheirBriefAsAltText() async throws {
        var deck = try fixtureDeck()
        // sectionHeader is the layout that places an image as a shape; the
        // full-bleed layouts set a background fill, which has no shape to
        // describe.
        deck.slides[1].layout = "sectionHeader"
        deck.slides[1].body = Body(kicker: "Part one")
        deck.slides[1].image = ImageBrief(prompt: "A wind turbine at dawn")
        let id = deck.slides[1].id

        let validated = try DeckValidator().validate(deck)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir,
                                                       images: [id: png()])

        let reopened = try Presentation(contentsOf: rendered.url)
        let described = reopened.slides.contains { slide in
            slide.shapes.contains { $0.altText == "A wind turbine at dawn" }
        }
        #expect(described)
        // It placed, so nothing is reported lost.
        #expect(rendered.droppedContent.isEmpty)
    }

    // MARK: - Sections (Rostrum enforces its contract with `precondition`)

    /// Two sections sharing a first slide used to **abort the process**.
    /// `Sections.set` requires strictly-increasing starts and enforces it with
    /// `precondition`, which `try?` cannot catch — and a model listing one
    /// slide under two headings is ordinary output, not misuse.
    @Test func sectionsSharingAFirstSlideDoNotAbortTheProcess() async throws {
        var deck = try fixtureDeck()
        let ids = deck.slides.map(\.id)
        // Slides carry `sectionId`, and the validator checks it resolves — so
        // reuse the fixture's section ids rather than inventing new ones.
        deck.sections = [
            IRSection(id: "s1", title: "One", slideIds: [ids[0], ids[1]]),
            // Also starts at slide 0: two sections, one equal startSlide, which
            // is what trips the strictly-increasing precondition.
            IRSection(id: "s2", title: "Two", slideIds: [ids[0], ids[2]]),
        ]
        let validated = try DeckValidator().validate(deck)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir)

        // Survived, and the duplicate start collapsed rather than being passed
        // on: both sections claim slide 0, so exactly one boundary remains.
        let reopened = try Presentation(contentsOf: rendered.url)
        #expect(reopened.sections.count == 1)
    }

    /// A model that leaves the title slide out of every section is the common
    /// shape. Rostrum requires the first section to start at slide 0, so
    /// Lectern used to drop *every* section rather than cover the gap.
    @Test func sectionsStartingAfterTheTitleSlideAreKeptNotDiscarded() async throws {
        var deck = try fixtureDeck()
        let ids = deck.slides.map(\.id)
        deck.sections = [
            IRSection(id: "s1", title: "Body", slideIds: [ids[1], ids[2]]),
            IRSection(id: "s2", title: "Close", slideIds: [ids[3], ids[4]]),
        ]
        let validated = try DeckValidator().validate(deck)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir)

        let reopened = try Presentation(contentsOf: rendered.url)
        // Both the model's sections, plus a synthesized opener for slide 0.
        #expect(reopened.sections.count == 3)
        #expect(reopened.sections.contains { $0.name == "Body" })
        #expect(reopened.sections.contains { $0.name == "Close" })
    }

    // MARK: - Deck identity and self-check

    /// A generated deck used to arrive anonymous: no title, no subject, nothing
    /// naming what wrote it. PowerPoint's info pane, Finder, Spotlight and
    /// SharePoint all read `docProps`.
    @Test func stampsDocumentPropertiesFromTheIR() async throws {
        let validated = try DeckValidator().validate(fixtureDeck(), notesRequired: true)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: true, into: dir)

        let properties = try Presentation(contentsOf: rendered.url).documentProperties
        #expect(properties.title == validated.deck.meta.title)
        #expect(properties.application == "Lectern (Rostrum)")
        if let subtitle = validated.deck.meta.subtitle, !subtitle.isEmpty {
            #expect(properties.subject == subtitle)
        }
    }

    /// Stamping `docProps` is exactly where a renderer is tempted to write
    /// `Date()` and quietly lose reproducibility. Rostrum never stamps
    /// wall-clock time of its own, and Lectern must not either: the same IR has
    /// to keep producing the same bytes.
    @Test func renderingTheSameIRTwiceProducesTheSameBytes() async throws {
        let validated = try DeckValidator().validate(fixtureDeck(), notesRequired: true)
        let first = tempDir(); defer { try? FileManager.default.removeItem(at: first) }
        let second = tempDir(); defer { try? FileManager.default.removeItem(at: second) }

        let a = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                notesEnabled: true, into: first)
        let b = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                notesEnabled: true, into: second)
        #expect(try Data(contentsOf: a.url) == Data(contentsOf: b.url))
    }

    /// Rostrum's schema lint, run by Lectern on the file it just wrote. An
    /// entry here is a defect in Lectern or Rostrum, never in the model's plan
    /// — which is why it is reported apart from `warnings`.
    @Test func theWrittenDeckPassesRostrumsOwnLint() async throws {
        let validated = try DeckValidator().validate(fixtureDeck(), notesRequired: true)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: true, into: dir)
        #expect(rendered.schemaIssues.isEmpty, "\(rendered.schemaIssues)")
    }

    // MARK: - Previews

    @Test func rendersOnePreviewPerSlideFromTheWrittenDeck() async throws {
        let validated = try DeckValidator().validate(fixtureDeck(), notesRequired: true)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                       notesEnabled: false, into: dir)

        #expect(rendered.previews.count == rendered.slideCount)
        #expect(rendered.previews.allSatisfy { $0.hasPrefix("<svg ") && $0.hasSuffix("</svg>") })

        // One render per slide, not one render repeated: distinct slides must
        // produce distinct SVG.
        #expect(Set(rendered.previews).count == rendered.previews.count)

        // Rendered from the written deck rather than redrawn from the IR, so
        // the first slide's title has to be in its own preview. Matched a word
        // at a time: the renderer line-breaks and XML-escapes, so the full
        // title may be split across `<text>` elements, but a word is never
        // split mid-way and a plain alphanumeric one is never escaped.
        let title = try #require(validated.deck.slides.first?.title)
        let word = try #require(
            title.split(separator: " ")
                .map(String.init)
                .filter { $0.allSatisfy(\.isLetter) }
                .max(by: { $0.count < $1.count }))
        #expect(rendered.previews.first?.contains(word) == true)
    }

    // MARK: - Font measurement

    #if canImport(CoreText)
    /// The substitution guard, which is the whole subtlety of resolving a
    /// typeface name to a file: CoreText answers *every* request, handing back
    /// the system fallback for a face that isn't installed. Registering that
    /// under the requested name would measure the wrong glyphs and report
    /// confidence — strictly worse than the estimate it replaced.
    @Test func resolvesInstalledFontsAndRefusesSubstitutes() throws {
        // Helvetica ships with every macOS/iOS install.
        let helvetica = try #require(DeckRenderer.installedFontFile(named: "Helvetica"))
        #expect(FileManager.default.fileExists(atPath: helvetica.path))

        // Nothing is named this, so CoreText substitutes — and we must decline.
        #expect(DeckRenderer.installedFontFile(named: "Nonexistent Face QZX") == nil)
    }
    #endif

    @Test func reportsWhichFontsWereEstimatedRatherThanMeasured() async throws {
        let result = try DeckValidator().validate(fixtureDeck(), notesRequired: true)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let rendered = try await DeckRenderer().render(result.deck, designURL: nil,
                                                       notesEnabled: false, into: dir)
        // Whether a given face is installed is a fact about the machine, so the
        // contract is the shape, not the contents: reported faces are real,
        // named, and never silently duplicated.
        #expect(Set(rendered.unmeasuredFonts).count == rendered.unmeasuredFonts.count)
        #expect(!rendered.unmeasuredFonts.contains(""))
        #expect(rendered.unmeasuredFonts == rendered.unmeasuredFonts.sorted())
        // And it stays out of `warnings`, which is about the deck.
        #expect(rendered.warnings.isEmpty)
    }

    // MARK: - Rendering (the Rostrum loop)

    @Test func rendersAValidPptxFromIR() async throws {
        let result = try DeckValidator().validate(fixtureDeck(), notesRequired: true)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let deckResult = try await DeckRenderer().render(result.deck, designURL: nil, notesEnabled: true,
                                                         into: dir, warnings: result.warnings)
        #expect(deckResult.slideCount == 5)                       // AT-11 (exact against fixture)
        // Opens as a real presentation with the expected structure (AT-10 core).
        let reopened = try Presentation(contentsOf: deckResult.url)
        #expect(reopened.slides.count == 5)
        #expect(try reopened.validate().isEmpty)
        #expect(reopened.sections.count == 2)                    // sections flow through
    }

    @Test func notesToggleControlsNotesParts() async throws {
        let result = try DeckValidator().validate(fixtureDeck())
        let onDir = tempDir(), offDir = tempDir()
        defer { try? FileManager.default.removeItem(at: onDir); try? FileManager.default.removeItem(at: offDir) }
        let on = try await DeckRenderer().render(result.deck, designURL: nil, notesEnabled: true, into: onDir)
        let off = try await DeckRenderer().render(result.deck, designURL: nil, notesEnabled: false, into: offDir)
        func notesParts(_ url: URL) throws -> Int {
            try Presentation(contentsOf: url).package.parts.keys.filter { $0.value.hasPrefix("/ppt/notesSlides/") }.count
        }
        #expect(try notesParts(on.url) > 0)                       // AT-12
        #expect(try notesParts(off.url) == 0)
    }

    // MARK: - Pipeline (Mock provider end-to-end)

    @Test func mockPipelineHappyPath() async throws {
        let provider = FixtureProvider(validJSON: try fixtureJSON())
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let events = EventBox()
        let request = DeckRequest(prompt: "why native rendering", slideCount: 5, notes: true)
        let result = try await DeckGenerator(provider: provider).generate(request, designURL: nil, into: dir) { events.record($0) }
        #expect(result.slideCount == 5)
        let stages = events.stages
        #expect(stages.contains("outlining") && stages.contains("rendering") && stages.contains("finished"))  // AT-09
        #expect(FileManager.default.fileExists(atPath: result.url.path))
    }

    @Test func repairLoopRecoversOnceThenFails() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        // invalidJSONOnce → exactly one repair → success (AT-14).
        let once = FixtureProvider(validJSON: try fixtureJSON(), failure: .invalidJSONOnce)
        let events = EventBox()
        let result = try await DeckGenerator(provider: once).generate(DeckRequest(prompt: "x", slideCount: 5), designURL: nil, into: dir) { events.record($0) }
        #expect(result.slideCount == 5)
        #expect(events.stages.contains("repairing"))

        // invalidJSONAlways → .schemaInvalid.
        let always = FixtureProvider(validJSON: try fixtureJSON(), failure: .invalidJSONAlways)
        await #expect(throws: LecternError.self) {
            _ = try await DeckGenerator(provider: always).generate(DeckRequest(prompt: "x"), designURL: nil, into: dir) { _ in }
        }
    }

    // MARK: - Style catalog

    @Test func loadsStylesFromADirectory() throws {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default
        for slug in ["sunflower", "midnight"] {
            let dir = root.appendingPathComponent(slug)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try "## Palette\n- Accent 1: #18A999".write(to: dir.appendingPathComponent("design.md"), atomically: true, encoding: .utf8)
        }
        let styles = try StyleCatalog().load(from: root)
        #expect(styles.count == 2)
        #expect(styles.map(\.slug).sorted() == ["midnight", "sunflower"])
        #expect(styles.first(where: { $0.slug == "sunflower" })?.name == "Sunflower")   // title-cased slug
    }

    @Test func promptTemplatesReflectGoalNotesAndLength() {
        let persuade = PromptTemplates.system(for: DeckRequest(prompt: "x", goal: "persuade"))
        #expect(persuade.contains("call to action"))
        #expect(persuade.contains(DeckIR.currentVersion))
        let noNotes = PromptTemplates.deck(for: DeckRequest(prompt: "x", slideCount: 8, notes: false))
        #expect(noNotes.contains("exactly 8 slides"))
        #expect(noNotes.contains("Omit the"))
        let grounded = PromptTemplates.deck(for: DeckRequest(prompt: "x", groundingText: "FACTS HERE"))
        #expect(grounded.contains("SOURCE MATERIAL") && grounded.contains("FACTS HERE"))
    }

    @Test func anthropicProviderWithoutKeyThrowsNoKey() async throws {
        let provider = AnthropicProvider(apiKey: "")
        await #expect(throws: LecternError.self) {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
        }
    }

    // MARK: - Provider selection (live-only, no keychain, no network)

    @Test func factoryThrowsWithoutAKey() throws {
        for key in [nil, "", "   ", "\n"] as [String?] {
            #expect(throws: LecternError.noKey) {
                _ = try ProviderFactory.make(id: .anthropic, apiKey: key, model: "claude-sonnet-5")
            }
        }
    }

    @Test func factoryBuildsAnthropicWithAKey() throws {
        let provider = try ProviderFactory.make(id: .anthropic, apiKey: "sk-ant-xyz", model: "claude-opus-4-8")
        #expect(provider.id == .anthropic)
        #expect(provider.displayName == "Anthropic")
        #expect(ProviderFactory.isWired(.anthropic))
    }

    @Test func factoryThrowsForUnwiredProviders() throws {
        // OpenAI/Gemini/Custom aren't wired yet — throw rather than fake a deck.
        for id in [ProviderID.openAI, .gemini, .custom] {
            #expect(!ProviderFactory.isWired(id))
            #expect(throws: LecternError.self) {
                _ = try ProviderFactory.make(id: id, apiKey: "some-key", model: "m")
            }
        }
    }

    // MARK: - Style catalog parsing (design.md header)

    @Test func parsesRichStyleMetadata() throws {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let md = """
        # Apricot

        **Category:** developer
        **Theme:** light
        **Vibe:** Editorial

        ## Color palette

        - `#f7f7f4`
        - `#26251e`
        - `#f54e00`

        ## Typography

        Families: "'CursorGothic', sans-serif", "'JetBrains Mono', monospace". Weights: 400, 500.
        """
        try md.write(to: root.appendingPathComponent("apricot.md"), atomically: true, encoding: .utf8)
        let style = try #require(try StyleCatalog().load(from: root).first)
        #expect(style.name == "Apricot")
        #expect(style.vibe == "Editorial")
        #expect(style.category == "developer")
        #expect(style.theme == .light)
        #expect(style.badge == "Editorial · Light")
        #expect(style.swatches == ["#f7f7f4", "#26251e", "#f54e00"])
        #expect(style.displayFont == "CursorGothic")           // quoted CSS stack unwrapped
        #expect(style.tags.contains("developer") && style.tags.contains("editorial"))
        // Theme rides along in tags so the picker's Light/Dark chips (and text
        // search for "light"/"dark") actually select styles.
        #expect(style.tags.contains("light"))
    }

    // MARK: - Optional image generation

    @Test func imageFactoryRequiresAKey() {
        #expect(throws: LecternError.noKey) { _ = try ImageProviderFactory.make(id: .gemini, apiKey: nil) }
        #expect(throws: LecternError.noKey) { _ = try ImageProviderFactory.make(id: .openAI, apiKey: "  ") }
    }

    @Test func imageFactoryBuildsEachProvider() throws {
        #expect(try ImageProviderFactory.make(id: .gemini, apiKey: "k").id == .gemini)
        #expect(try ImageProviderFactory.make(id: .openAI, apiKey: "k").id == .openAI)
    }

    @Test func styleDirectiveIsOnBrandAndTextFree() {
        let style = Style(slug: "aurora", name: "Aurora", vibe: "Technical", theme: .light,
                          swatches: ["#533afd", "#4434d4"], designURL: URL(fileURLWithPath: "/x"))
        let directive = ImageStyleDirective.from(style: style)
        #expect(directive.contains("#533afd"))
        #expect(directive.lowercased().contains("technical"))
        // Deck/UI prose is deliberately excluded now: typography guidance
        // fights the requirement that generated images carry no text.
        #expect(directive.lowercased().contains("no typography"))
    }

    @Test func rendersTableSlideAndOpensClean() async throws {
        let deck = DeckIR(meta: Meta(title: "Plans"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "table", title: "Plan comparison",
                    body: Body(table: IRTable(headers: ["Plan", "Seats", "Price"],
                                              rows: [["Starter", "5", "$29"],
                                                     ["Team", "25", "$99"],
                                                     ["Enterprise", "Unlimited"]]))),   // ragged on purpose
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                     notesEnabled: false, into: dir)
        #expect(result.slideCount == 2)
        #expect(try Presentation(contentsOf: result.url).validate().isEmpty)
    }

    @Test func tableWithNoBodyRowsIsRejectedLikeAnEmptyChart() throws {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "table", title: "Empty",
                    body: Body(table: IRTable(headers: ["A"], rows: []))),
        ])
        #expect(throws: (any Error).self) {
            _ = try DeckValidator().validate(deck, notesRequired: false)
        }
    }

    @Test func everyOfferedChartKindOpensWithoutRepair() async throws {
        // Each kind carries its own data-label position; a position that is not
        // legal for the kind is exactly what makes PowerPoint offer to repair.
        for kind in ["bar", "stackedBar", "percentStackedBar", "line", "area", "pie", "doughnut", "radar"] {
            let deck = DeckIR(meta: Meta(title: kind), slides: [
                IRSlide(id: "s1", layout: "title", title: "Opener"),
                IRSlide(id: "s2", layout: "chart", title: kind,
                        body: Body(chart: IRChart(kind: kind, categories: ["A", "B", "C"],
                                                  series: [IRSeries(name: "one", values: [3, 5, 4]),
                                                           IRSeries(name: "two", values: [2, 1, 6])]))),
            ])
            let validated = try DeckValidator().validate(deck, notesRequired: false)
            let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
            let result = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                         notesEnabled: false, into: dir)
            #expect(try Presentation(contentsOf: result.url).validate().isEmpty, "\(kind) needed repair")
        }
    }

    @Test func rendersTimelineAndQuadrantLayouts() async throws {
        let deck = DeckIR(meta: Meta(title: "Layouts"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "timeline", title: "Roadmap",
                    body: Body(milestones: [IRMilestone(label: "Q1", detail: "Zip core"),
                                            IRMilestone(label: "Q2", detail: "Charts"),
                                            IRMilestone(label: "Q3", detail: "Corpus")])),
            IRSlide(id: "s3", layout: "quadrant", title: "Where the work sits",
                    body: Body(quadrants: [IRQuadrant(heading: "Ship now", detail: "high value"),
                                           IRQuadrant(heading: "Plan", detail: "high effort"),
                                           IRQuadrant(heading: "Fill-in", detail: "low value"),
                                           IRQuadrant(heading: "Avoid", detail: "low effort")],
                               xAxis: "Effort", yAxis: "Value")),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                     notesEnabled: false, into: dir)
        #expect(result.slideCount == 3)
        #expect(try Presentation(contentsOf: result.url).validate().isEmpty)
    }

    @Test func aQuadrantThatIsNotFourCellsIsRejected() throws {
        let deck = DeckIR(meta: Meta(title: "Q"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "quadrant", title: "Three",
                    body: Body(quadrants: [IRQuadrant(heading: "a", detail: "1"),
                                           IRQuadrant(heading: "b", detail: "2"),
                                           IRQuadrant(heading: "c", detail: "3")])),
        ])
        #expect(throws: (any Error).self) {
            _ = try DeckValidator().validate(deck, notesRequired: false)
        }
    }

    @Test func slideDecodesOptionalImageBrief() throws {
        let withImage = #"{"id":"s1","layout":"title","image":{"prompt":"a lighthouse at dawn","aspect":"16:9"}}"#
        let slide = try JSONDecoder().decode(IRSlide.self, from: Data(withImage.utf8))
        #expect(slide.image?.prompt == "a lighthouse at dawn")
        #expect(slide.image?.aspect == "16:9")
        // A slide with no image still decodes (image is optional).
        let bare = try JSONDecoder().decode(IRSlide.self, from: Data(#"{"id":"s2","layout":"bullets"}"#.utf8))
        #expect(bare.image == nil)
    }

    // MARK: - Pricing (§10.3)

    @Test func costMatchesTheRateCard() {
        // 1M input @ $3 + 1M output @ $15 = $18.00 on sonnet.
        let usage = Usage(inputTokens: 1_000_000, outputTokens: 1_000_000)
        #expect(PriceTable.cost(model: "claude-sonnet-5", usage: usage) == Decimal(18))
        // 200k in @ $15 + 50k out @ $75 = $3.00 + $3.75 = $6.75 on opus.
        let opus = Usage(inputTokens: 200_000, outputTokens: 50_000)
        #expect(PriceTable.cost(model: "claude-opus-4-8", usage: opus) == Decimal(675) / 100)
    }

    @Test func unpricedModelYieldsNoNumber() {
        #expect(PriceTable.cost(model: "some-unknown-model", usage: Usage(inputTokens: 999, outputTokens: 999)) == nil)
        #expect(PriceTable.estimate(model: "some-unknown-model", slideCount: 10) == nil)
    }

    @Test func preflightEstimateScalesWithDeckSize() throws {
        let small = try #require(PriceTable.estimate(model: "claude-sonnet-5", slideCount: 5))
        let large = try #require(PriceTable.estimate(model: "claude-sonnet-5", slideCount: 30))
        #expect(large > small)                                    // more slides → more output → dearer
        #expect(small > 0)
    }

    @Test func costFormattingNeverReadsAsFree() {
        #expect(PriceTable.formatted(Decimal(0)) == "$0.00")
        #expect(PriceTable.formatted(Decimal(1) / 1000) == "<$0.01")   // tiny but non-zero
        #expect(PriceTable.formatted(Decimal(42) / 100) == "$0.42")
    }

}

/// Thread-safe event recorder for the async pipeline.
private final class EventBox: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []
    func record(_ e: GenerationEvent) {
        lock.lock(); defer { lock.unlock() }
        switch e {
        case .preparingSource: events.append("preparingSource")
        case .outlining: events.append("outlining")
        case .outlineReady: events.append("outlineReady")
        case .drafting: events.append("drafting")
        case .validating: events.append("validating")
        case .repairing: events.append("repairing")
        case .auditing: events.append("auditing")
        case .illustrating: events.append("illustrating")
        case .rendering: events.append("rendering")
        case .finished: events.append("finished")
        }
    }
    var stages: Set<String> { lock.lock(); defer { lock.unlock() }; return Set(events) }
}
