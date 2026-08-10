import Foundation
import Testing
// URLRequest, URLResponse and HTTPURLResponse live in FoundationNetworking on
// Linux, not in core Foundation — the same guard the providers under test use.
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif
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
        #expect(SlideLayoutKind.sectionHeader.imagePlacement == .sidePanel(.right))
        #expect(SlideLayoutKind.bullets.imagePlacement == .sidePanel(.right))
        #expect(SlideLayoutKind.agenda.imagePlacement == .sidePanel(.right))
        // Asked for explicitly, so a deck can alternate rather than leaning on
        // one composition.
        #expect(SlideLayoutKind.imageLeft.imagePlacement == .sidePanel(.left))
        #expect(SlideLayoutKind.imageRight.imagePlacement == .sidePanel(.right))

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

    /// Image requests must respect the ceiling the provider declares.
    ///
    /// Every briefed slide used to get a task at once, so a long deck opened
    /// dozens of simultaneous requests — at Gemini, the default, which sets its
    /// ceiling to one because its quotas are burst-sensitive. The rate limiting
    /// that followed was self-inflicted and surfaced to the user as images that
    /// "couldn't be generated".
    @Test func imageRequestsRespectTheProvidersBurstCeiling() async throws {
        // Ten briefs: comfortably above both ceilings, so an unbounded fan-out
        // is unmistakable against either one.
        let briefCount = 10
        var deck = try fixtureDeck()
        let sectionId = deck.slides[1].sectionId
        let illustrated = (0..<briefCount).map { i in
            IRSlide(id: "illustrated-\(i)", sectionId: sectionId, layout: "sectionHeader",
                    title: "Part \(i)", body: Body(kicker: "Part \(i)"),
                    image: ImageBrief(prompt: "a wind turbine at dawn, take \(i)"))
        }
        deck.slides.insert(contentsOf: illustrated, at: 1)
        if var sections = deck.sections, let idx = sections.firstIndex(where: { $0.id == sectionId }) {
            sections[idx].slideIds.insert(contentsOf: illustrated.map(\.id), at: 0)
            deck.sections = sections
        }
        let json = String(decoding: try JSONEncoder().encode(deck), as: UTF8.self)

        for providerID in ImageProviderID.allCases {
            let probe = ConcurrencyProbe()
            let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
            let request = DeckRequest(prompt: "turbines", slideCount: deck.slides.count, notes: false)
            _ = try await DeckGenerator(
                provider: FixtureProvider(validJSON: json),
                imageProvider: ProbeImageProvider(id: providerID, probe: probe),
                quality: false
            ).generate(request, designURL: nil, into: dir) { _ in }

            let ceiling = providerID.maximumConcurrentRequests
            let peak = await probe.peak
            #expect(await probe.total == briefCount,
                    "\(providerID): every briefed slide should still be requested")
            #expect(peak <= ceiling,
                    "\(providerID): \(peak) requests in flight against a ceiling of \(ceiling)")
            // And it uses the allowance rather than quietly serialising, which
            // would trade the 429s for a needlessly slow illustration pass.
            #expect(peak == ceiling,
                    "\(providerID): peaked at \(peak), never reaching its ceiling of \(ceiling)")
        }
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
        // Fenced and labelled as data now, rather than pasted under a plain
        // "--- SOURCE MATERIAL ---" heading a document could imitate.
        #expect(grounded.contains("never instructions") && grounded.contains("FACTS HERE"))
    }

    @Test func promptImageLayoutListsComeFromTheRenderer() throws {
        // The QA editor once hand-listed five image-eligible layouts and told
        // the model to move briefs off the rest — quietly stripping imagery
        // from the picture-beside-bullets slides `imagePlacement` was built
        // to illustrate. The lists are now derived from `imagePlacement`;
        // this pins the derivation, the interpolation into both prompts and
        // the tool schema, and the name round-trip that keeps `knownCases`
        // honest when a layout is added.
        #expect(SlideLayoutKind.panelImageLayoutNames.contains("bullets"))
        #expect(SlideLayoutKind.fullBleedImageLayoutNames.contains("statement"))
        for name in SlideLayoutKind.imageEligibleLayoutNames {
            #expect(SlideLayoutKind(name).imagePlacement != .none)
        }
        for kind in SlideLayoutKind.knownCases {
            #expect(SlideLayoutKind(kind.name) == kind)
        }
        let request = DeckRequest(prompt: "x")
        let qa = PromptTemplates.editorSystem(for: request)
        let draft = PromptTemplates.system(for: request)
        for name in SlideLayoutKind.imageEligibleLayoutNames {
            #expect(qa.contains("\"\(name)\""), "QA prompt is missing \(name)")
            #expect(draft.contains("\"\(name)\""), "draft prompt is missing \(name)")
        }
        let schemaJSON = try JSONSerialization.data(
            withJSONObject: DeckSchema.inputSchema(), options: [.withoutEscapingSlashes])
        let schemaText = String(decoding: schemaJSON, as: UTF8.self)
        #expect(schemaText.contains(
            SlideLayoutKind.imageEligibleLayoutNames.joined(separator: "/")))
    }

    @Test func anthropicProviderWithoutKeyThrowsNoKey() async throws {
        let provider = AnthropicProvider(apiKey: "")
        await #expect(throws: LecternError.self) {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
        }
    }

    // MARK: - Output budget and truncation

    /// A response the model stopped writing still decodes, so a short deck used
    /// to be indistinguishable from a finished one.
    @Test func aTruncatedDraftIsReportedNotReturnedShort() async throws {
        // A well-formed tool_use answer that happens to be cut off: exactly what
        // the API returns when the deck outgrows the output ceiling.
        let body = anthropicResponse(stopReason: "max_tokens",
                                     deck: #"{"meta":{"title":"T"},"slides":[]}"#)
        let provider = AnthropicProvider(apiKey: "k", send: stubSender(200, body))
        let request = DeckRequest(prompt: "x", slideCount: 40, notes: true)

        await #expect(throws: LecternError.responseTruncated(slideCount: 40)) {
            _ = try await provider.draft(request, repairing: nil) { _ in }
        }
        // The same body with a normal stop reason must still come back fine —
        // otherwise this is just rejecting everything.
        let ok = AnthropicProvider(apiKey: "k",
                                   send: stubSender(200, anthropicResponse(stopReason: "tool_use",
                                                                           deck: #"{"meta":{"title":"T"},"slides":[]}"#)))
        let draft = try await ok.draft(request, repairing: nil) { _ in }
        #expect(draft.json.contains("\"title\""))
    }

    @Test func theOutputBudgetGrowsWithTheDeckAndStaysInBounds() {
        let floor = AnthropicProvider.floorOutputTokens
        // A small deck must never get *less* room than the old constant.
        #expect(AnthropicProvider.outputTokenBudget(
            for: DeckRequest(prompt: "x", slideCount: 3, notes: false)) == floor)
        // The old constant was a flat 8,192, so a 40-slide deck with notes —
        // what the UI's stepper allows — asked for the same room as a 3-slide
        // one and came back short. It has to ask for more now.
        let big = AnthropicProvider.outputTokenBudget(
            for: DeckRequest(prompt: "x", slideCount: 40, notes: true))
        #expect(big > floor, "a 40-slide deck with notes still asks for only \(big)")
        #expect(big <= AnthropicProvider.maxOutputTokens)
        // Notes are extra writing, so they cost extra room.
        #expect(AnthropicProvider.outputTokenBudget(for: DeckRequest(prompt: "x", slideCount: 40, notes: true))
                > AnthropicProvider.outputTokenBudget(for: DeckRequest(prompt: "x", slideCount: 40, notes: false)))
    }

    /// A model whose ceiling is below the budget rejects the whole call, so
    /// asking for more room must not become a new way to fail.
    @Test func aRefusedOutputBudgetRetriesAtTheFloorInsteadOfFailing() async throws {
        let sent = SentBox()
        let good = anthropicResponse(stopReason: "tool_use", deck: #"{"meta":{"title":"T"},"slides":[]}"#)
        let provider = AnthropicProvider(apiKey: "k", send: { request in
            let budget = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()))
                .flatMap { ($0 as? [String: Any])?["max_tokens"] as? Int } ?? 0
            sent.record(budget)
            if budget > AnthropicProvider.floorOutputTokens {
                let error = #"{"error":{"message":"max_tokens: 19200 > 8192, which is the maximum for this model"}}"#
                return (Data(error.utf8), Self.http(400))
            }
            return (Data(good.utf8), Self.http(200))
        })

        let draft = try await provider.draft(
            DeckRequest(prompt: "x", slideCount: 40, notes: true), repairing: nil) { _ in }
        #expect(draft.json.contains("\"title\""))
        // It asked for the larger budget first, then dropped to the floor —
        // rather than giving up, or never trying for more in the first place.
        let budgets = sent.values
        #expect(budgets.count == 2, "expected one retry, saw budgets \(budgets)")
        #expect(budgets.first! > AnthropicProvider.floorOutputTokens)
        #expect(budgets.last == AnthropicProvider.floorOutputTokens)
    }

    // MARK: - Retry policy

    @Test func backoffIsExponentialCappedAndDefersToRetryAfter() {
        // Exponential from two seconds, not a flat wait.
        #expect(HTTPRetry.backoff(attempt: 0, retryAfter: nil) == 2)
        #expect(HTTPRetry.backoff(attempt: 1, retryAfter: nil) == 4)
        #expect(HTTPRetry.backoff(attempt: 2, retryAfter: nil) == 8)
        // Capped, so a 5xx spike cannot park the UI for minutes.
        #expect(HTTPRetry.backoff(attempt: 20, retryAfter: nil) == HTTPRetry.maxBackoffSeconds)
        // The server knows more than we do.
        #expect(HTTPRetry.backoff(attempt: 0, retryAfter: 17) == 17)
        #expect(HTTPRetry.backoff(attempt: 0, retryAfter: 9_999) == HTTPRetry.maxBackoffSeconds)
        // Google-style durations and junk.
        #expect(HTTPRetry.seconds("3s") == 3)
        #expect(HTTPRetry.seconds("1.2") == 2)
        #expect(HTTPRetry.seconds("soon") == nil)
    }

    /// Retrying without a ceiling turned a stalled network into six minutes of
    /// a UI that looks frozen. The deadline bounds when a retry may start.
    @Test func retryingStopsAtTheOverallDeadline() {
        let start = Date()
        let deadline = HTTPRetry.overallDeadline
        // Early on there is plenty of room.
        #expect(HTTPRetry.hasTimeToRetry(startedAt: start, nextWait: 4, now: start))
        // Just inside: the wait still lands before the deadline.
        #expect(HTTPRetry.hasTimeToRetry(
            startedAt: start, nextWait: 4, now: start.addingTimeInterval(deadline - 10)))
        // Just outside: elapsed plus the wait crosses it, so no new attempt starts.
        #expect(!HTTPRetry.hasTimeToRetry(
            startedAt: start, nextWait: 4, now: start.addingTimeInterval(deadline - 2)))
        // The wait itself counts, rather than being checked after sleeping.
        #expect(!HTTPRetry.hasTimeToRetry(
            startedAt: start, nextWait: 30, now: start.addingTimeInterval(deadline - 10)))
        // Well past it, nothing is retried at all.
        #expect(!HTTPRetry.hasTimeToRetry(
            startedAt: start, nextWait: 0, now: start.addingTimeInterval(deadline + 60)))
    }

    /// The Validate button's own network call was the one HTTPRetry did not
    /// reach, so a dropped connection reported a good key as broken.
    @Test func listingModelsRetriesADroppedConnection() async throws {
        let attempts = SentBox()
        let models = #"{"data":[{"id":"claude-sonnet-5"},{"id":"claude-opus-5"}]}"#
        let ids = try await AnthropicModels.list(apiKey: "k", send: { _ in
            attempts.record(1)
            if attempts.values.count < 3 { throw URLError(.networkConnectionLost) }
            return (Data(models.utf8), Self.http(200))
        })
        #expect(ids == ["claude-sonnet-5", "claude-opus-5"])
        #expect(attempts.values.count == 3, "expected three attempts, saw \(attempts.values.count)")
    }

    @Test func listingModelsStillFailsFastOnARejectedKey() async throws {
        let attempts = SentBox()
        await #expect(throws: LecternError.authFailed(provider: "Anthropic")) {
            _ = try await AnthropicModels.list(apiKey: "k", send: { _ in
                attempts.record(1)
                return (Data(#"{"error":{"message":"invalid"}}"#.utf8), Self.http(401))
            })
        }
        #expect(attempts.values.count == 1, "auth failures must not be retried")
    }

    @Test func transientTransportFailuresAreRetriableAndOfflineIsNot() {        for code in [URLError.timedOut, .networkConnectionLost, .cannotConnectToHost,
                     .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed] {
            #expect(HTTPRetry.isRetriable(URLError(code)), "\(code) should be worth retrying")
        }
        // No radio: waiting and asking again is theatre, and the user has a
        // different thing to do about it.
        #expect(!HTTPRetry.isRetriable(URLError(.notConnectedToInternet)))
        #expect(!HTTPRetry.isRetriable(URLError(.badURL)))
        #expect(HTTPRetry.isRetriable(status: 429))
        #expect(HTTPRetry.isRetriable(status: 503))
        #expect(!HTTPRetry.isRetriable(status: 400))
        #expect(!HTTPRetry.isRetriable(status: 401))
    }

    /// A dropped connection used to end the run. This is the longest and most
    /// expensive call in the product, so one dead socket threw away a paid
    /// generation without ever asking again.
    @Test func aDroppedConnectionIsRetriedRatherThanEndingTheDraft() async throws {
        let attempts = SentBox()
        let good = anthropicResponse(stopReason: "tool_use", deck: #"{"meta":{"title":"T"},"slides":[]}"#)
        let provider = AnthropicProvider(apiKey: "k", send: { _ in
            attempts.record(1)
            if attempts.values.count < 3 { throw URLError(.networkConnectionLost) }
            return (Data(good.utf8), Self.http(200))
        })
        let draft = try await provider.draft(DeckRequest(prompt: "x", slideCount: 5), repairing: nil) { _ in }
        #expect(draft.json.contains("\"title\""))
        #expect(attempts.values.count == 3, "expected three attempts, saw \(attempts.values.count)")
    }

    /// Offline is different: there is nothing to wait for, and the user gets a
    /// message they can act on instead of three silent retries.
    @Test func beingOfflineFailsImmediatelyWithoutRetrying() async throws {
        let attempts = SentBox()
        let provider = AnthropicProvider(apiKey: "k", send: { _ in
            attempts.record(1)
            throw URLError(.notConnectedToInternet)
        })
        await #expect(throws: LecternError.networkOffline) {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
        }
        #expect(attempts.values.count == 1, "offline should not be retried")
    }

    /// Auth is final — asking again cannot change the answer, and each retry
    /// is another round-trip the user waits through.
    @Test func aRejectedKeyIsNotRetried() async throws {
        let attempts = SentBox()
        let provider = AnthropicProvider(apiKey: "k", send: { _ in
            attempts.record(1)
            return (Data(#"{"error":{"message":"invalid x-api-key"}}"#.utf8), Self.http(401))
        })
        await #expect(throws: LecternError.authFailed(provider: "Anthropic")) {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
        }
        #expect(attempts.values.count == 1)
    }

    // MARK: Anthropic stub helpers

    private static func http(_ status: Int) -> HTTPURLResponse {        HTTPURLResponse(url: URL(string: "https://api.anthropic.com/v1/messages")!,
                        statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func stubSender(_ status: Int, _ body: String) -> @Sendable (URLRequest) async throws -> (Data, URLResponse) {
        { _ in (Data(body.utf8), Self.http(status)) }
    }

    /// A Messages API response carrying `deck` in a forced `tool_use` block.
    private func anthropicResponse(stopReason: String, deck: String) -> String {
        let input = (try? JSONSerialization.jsonObject(with: Data(deck.utf8))) ?? [:]
        let obj: [String: Any] = [
            "stop_reason": stopReason,
            "usage": ["input_tokens": 10, "output_tokens": 20],
            "content": [["type": "tool_use", "name": "emit_deck", "input": input]],
        ]
        return String(decoding: try! JSONSerialization.data(withJSONObject: obj), as: UTF8.self)
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
        let provider = try ProviderFactory.make(id: .anthropic, apiKey: "sk-ant-xyz", model: "claude-opus-5")
        #expect(provider.id == .anthropic)
        #expect(provider.displayName == "Anthropic")
        #expect(ProviderFactory.isWired(.anthropic))
    }

    @Test func factoryThrowsForUnwiredProviders() throws {
        // Gemini and Custom aren't wired for text — throw rather than fake a
        // deck. OpenAI is wired now and has its own suite.
        for id in [ProviderID.gemini, .custom] {
            #expect(!ProviderFactory.isWired(id))
            #expect(throws: LecternError.self) {
                _ = try ProviderFactory.make(id: id, apiKey: "some-key", model: "m")
            }
        }
        #expect(ProviderFactory.isWired(.openAI))
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

    @Test func aQuadrantWithNothingToSalvageIsStillRejected() throws {
        // A lone cell is not a 2x2 and is not a set of bands either, and there
        // are no bullets to fall back to — so this one still has to fail and
        // let the repair loop try again. (Three cells become bands instead:
        // see aQuadrantWithoutFourCellsBecomesBandsInsteadOfFailing.)
        let deck = DeckIR(meta: Meta(title: "Q"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "quadrant", title: "One",
                    body: Body(quadrants: [IRQuadrant(heading: "a", detail: "1")])),
        ])
        #expect(throws: (any Error).self) {
            _ = try DeckValidator().validate(deck, notesRequired: false)
        }
    }

    @Test func agendaRowsLinkToTheirSection() async throws {
        let deck = DeckIR(
            meta: Meta(title: "Quarterly review"),
            sections: [IRSection(id: "one", title: "Results", slideIds: ["s3"]),
                       IRSection(id: "two", title: "Outlook", slideIds: ["s4"])],
            slides: [
                IRSlide(id: "s1", layout: "title", title: "Quarterly review"),
                IRSlide(id: "s2", layout: "agenda", title: "Agenda",
                        body: Body(items: ["Results", "Outlook"])),
                IRSlide(id: "s3", layout: "sectionHeader", title: "Results"),
                IRSlide(id: "s4", layout: "sectionHeader", title: "Outlook"),
            ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                     notesEnabled: false, into: dir)
        let reopened = try Presentation(contentsOf: result.url)
        #expect(try reopened.validate().isEmpty)

        // Internal jumps, not external URLs: the relationship points at a
        // slide part and survives the file being moved.
        let agenda = try reopened.slides[1]
        let links = agenda.part.rels.items.filter { $0.type == RelType.slide }
        #expect(links.count == 2)
        #expect(links.allSatisfy { !$0.isExternal && $0.target.contains("slide") })
    }

    // MARK: - Salvaging a mis-shaped structured layout

    /// A 2x2 the model gave three cells used to fail the entire deck — twelve
    /// good slides and two model round trips lost to one slide.
    @Test func aQuadrantWithoutFourCellsBecomesBandsInsteadOfFailing() throws {
        let deck = DeckIR(meta: Meta(title: "Q"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "quadrant", title: "Three things",
                    body: Body(quadrants: [IRQuadrant(heading: "Alpha", detail: "first"),
                                           IRQuadrant(heading: "Beta", detail: "second"),
                                           IRQuadrant(heading: "Gamma", detail: "third")])),
        ])
        let result = try DeckValidator().validate(deck, notesRequired: false)
        #expect(result.deck.slides[1].layout == "bands")
        #expect(result.deck.slides[1].body?.items == ["Alpha — first", "Beta — second", "Gamma — third"])
        #expect(result.warnings.contains { $0.contains("not a 2x2") })
    }

    @Test func aTimelineWithoutMilestonesFallsBackToItsBullets() throws {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "timeline", title: "Roadmap",
                    body: Body(bullets: [Bullet(text: "Q1 core"), Bullet(text: "Q2 charts")])),
        ])
        let result = try DeckValidator().validate(deck, notesRequired: false)
        #expect(result.deck.slides[1].layout == "bullets")
        #expect(result.warnings.contains { $0.contains("downgraded to bullets") })
    }

    @Test func aStructuredLayoutWithNothingToSalvageStillFails() throws {
        // Salvage is not silence: a slide with no usable content at all is
        // still a hard error, so the repair loop gets a chance at it.
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "timeline", title: "Empty"),
        ])
        #expect(throws: (any Error).self) {
            _ = try DeckValidator().validate(deck, notesRequired: false)
        }
    }

    // MARK: - Image weight

    /// A scrimmed backdrop used to be re-encoded losslessly, which turned a
    /// 2.7 MB photograph into a 5.3 MB part and a 13-image deck into 49 MB.
    ///
    /// Both halves of this need CoreGraphics: the scrim is applied there, and
    /// `photographJPEG()` builds its fixture there too, returning nil where it
    /// cannot. Where there is no CoreGraphics the image is passed through
    /// untouched, so there is no re-encode to measure.
    #if canImport(CoreGraphics)
    @Test func scrimmingAPhotographDoesNotInflateIt() async throws {
        let source = try #require(Self.photographJPEG())
        let deck = DeckIR(meta: Meta(title: "Images"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener",
                    image: ImageBrief(prompt: "a lighthouse")),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                     notesEnabled: false, into: dir,
                                                     images: ["s1": source])
        let reopened = try Presentation(contentsOf: result.url)
        let media = reopened.package.parts.filter { $0.key.value.contains("/media/") }
        #expect(media.count == 1)
        let stored = try #require(media.first?.value.blob)
        // The scrim is opaque, so the backdrop stays a photograph rather than
        // becoming a lossless copy several times its size.
        #expect(stored.count <= source.count,
                "scrimming grew the image from \(source.count) to \(stored.count) bytes")
        #expect(Array(stored.prefix(2)) == [0xFF, 0xD8], "expected JPEG, got a lossless re-encode")
    }
    #endif

    /// A photographic JPEG: gradient noise, which is exactly what PNG cannot
    /// compress and JPEG can.
    private static func photographJPEG() -> Data? {
        #if canImport(CoreGraphics)
        let w = 900, h = 600
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        var seed: UInt64 = 42
        for y in stride(from: 0, to: h, by: 2) {
            for x in stride(from: 0, to: w, by: 2) {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let n = Double((seed >> 33) % 255) / 255
                ctx.setFillColor(CGColor(red: n, green: Double(x) / Double(w), blue: Double(y) / Double(h), alpha: 1))
                ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }
        }
        guard let image = ctx.makeImage() else { return nil }
        let buffer = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            buffer as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return buffer as Data
        #else
        return nil
        #endif
    }

    /// Office keeps Calibri, Cambria and Aptos inside its own app bundles
    /// rather than installing them, so macOS reports them missing and CoreText
    /// substitutes. A deck in Calibri was measured as an estimate and reported
    /// as "not installed", when PowerPoint renders it in Calibri every time.
    ///
    /// CoreText-gated like the resolver it exercises: `officeFontFile`,
    /// `familyCandidates` and `faceIndex` are only declared where CoreText is.
    #if canImport(CoreText)
    @Test func officeCoreFontsAreMeasuredNotReportedMissing() throws {
        // Skipped rather than failed where Office is not installed: this is a
        // fact about the machine, not about the code.
        try withKnownIssue(isIntermittent: true) {
            let found = DeckRenderer.officeFontFile(named: "Calibri")
            try #require(found != nil, "Office not installed on this machine")
            let data = try Data(contentsOf: found!)
            // The file really holds Calibri — not a neighbour that sorted first.
            #expect(DeckRenderer.faceIndex(named: "Calibri", in: data) != nil)
            // And it measures: real advance widths, not the estimate.
            let library = FontLibrary()
            let index = try #require(DeckRenderer.faceIndex(named: "Calibri", in: data))
            try library.register(data, aliases: ["Calibri"], fontIndex: index)
            let metrics = try #require(library.metrics(for: "Calibri"))
            #expect(metrics.advance(of: "M") > 0)
        } when: {
            DeckRenderer.officeFontFile(named: "Calibri") == nil
        }
    }

    /// Designs name faces the way a foundry licenses them — "Helvetica Neue
    /// LT" — while the copy installed on a Mac is plain "Helvetica Neue".
    /// Matching only the exact string declared a font sitting in Font Book
    /// missing and fitted its text by estimate.
    @Test func aFoundrySuffixDoesNotHideAnInstalledFamily() throws {
        #expect(DeckRenderer.familyCandidates(for: "Helvetica Neue LT")
                == ["Helvetica Neue LT", "Helvetica Neue"])
        // Design words are not suffixes: stripping these would hand back a
        // different face than the one asked for.
        #expect(DeckRenderer.familyCandidates(for: "Helvetica Neue") == ["Helvetica Neue"])
        #expect(DeckRenderer.familyCandidates(for: "Gill Sans Condensed")
                == ["Gill Sans Condensed"])
        // Stacked tags peel one at a time.
        #expect(DeckRenderer.familyCandidates(for: "Futura PT Std").last == "Futura")

        try withKnownIssue(isIntermittent: true) {
            let url = try #require(DeckRenderer.installedFontFile(named: "Helvetica Neue LT"),
                                   "Helvetica Neue not installed on this machine")
            let data = try Data(contentsOf: url)
            let face = try #require(DeckRenderer.familyCandidates(for: "Helvetica Neue LT")
                .lazy.compactMap { DeckRenderer.faceIndex(named: $0, in: data) }.first)
            let library = FontLibrary()
            try library.register(data, aliases: ["Helvetica Neue LT"], fontIndex: face)
            // Registered under the design's own name, measuring real widths.
            let metrics = try #require(library.metrics(for: "Helvetica Neue LT"))
            #expect(metrics.advance(of: "M") > 0)
        } when: {
            DeckRenderer.installedFontFile(named: "Helvetica Neue") == nil
        }
    }
    #endif

    /// The classic pairing, both ways round. A deck that can only put the
    /// picture on the right reads as the same slide repeated.
    @Test func imageLeftAndImageRightMirrorEachOther() async throws {
        func render(_ layout: String) async throws -> (text: Rect, panel: Rect) {
            let deck = DeckIR(meta: Meta(title: "Mirror"), slides: [
                IRSlide(id: "s1", layout: "title", title: "Opener"),
                IRSlide(id: "s2", layout: layout, title: "Findings",
                        body: Body(bullets: [Bullet(text: "one"), Bullet(text: "two")]),
                        image: ImageBrief(prompt: "a lighthouse")),
            ])
            let validated = try DeckValidator().validate(deck, notesRequired: false)
            let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
            let result = try await DeckRenderer().render(
                validated.deck, designURL: nil, notesEnabled: false, into: dir,
                images: ["s2": Self.smallPNG()])
            let reopened = try Presentation(contentsOf: result.url)
            let slide = try reopened.slides[1]
            let picture = try #require(slide.shapes.all.first { $0.altText != nil })
            let title = try #require(slide.shapes.all.first {
                ($0.textFrame?.text ?? "").contains("Findings")
            })
            return (title.frame, picture.frame)
        }

        let right = try await render("imageRight")
        let left = try await render("imageLeft")
        // Text left of the picture one way, right of it the other.
        #expect(right.text.maxX.rawValue <= right.panel.x.rawValue)
        #expect(left.panel.maxX.rawValue <= left.text.x.rawValue)
        // And the panel really did swap sides.
        #expect(left.panel.x.rawValue < right.panel.x.rawValue)
    }

    /// An 8x8 PNG: enough for `addPicture` to sniff and place.
    private static func smallPNG() -> Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        func be32(_ v: Int) -> [UInt8] {
            [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
        }
        b += be32(13); b += Array("IHDR".utf8); b += be32(8); b += be32(8)
        b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }

    /// Tool-calling models double-encode a nested array often enough to be a
    /// failure mode rather than a curiosity. One 29-slide draft arrived with
    /// `meta` and `sections` as proper JSON and `slides` as an 11,649-character
    /// string; both attempts of the repair loop came back the same way, so a
    /// whole deck was lost to a quoting mistake in one field.
    @Test func aStringifiedSlidesArrayStillDecodes() throws {
        let inner = #"[{"id":"s1","layout":"title","title":"Opener"},"#
            + #"{"id":"s2","layout":"bullets","title":"Points",""#
            + #"body":{"bullets":[{"text":"one"}]}}]"#
        let escaped = String(data: try JSONEncoder().encode(inner), encoding: .utf8)!
        let json = #"{"meta":{"title":"Trap"},"slides":"# + escaped + "}"

        let deck = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        #expect(deck.slides.count == 2)
        #expect(deck.slides[1].kind == .bullets)
        #expect(deck.meta.title == "Trap")
        // And it still validates end to end, which is the point.
        #expect(throws: Never.self) {
            _ = try DeckValidator().validate(deck, notesRequired: false)
        }
    }

    @Test func aProperSlidesArrayIsUnaffected() throws {
        let json = #"{"meta":{"title":"T"},"slides":[{"id":"s1","layout":"title","title":"O"}]}"#
        let deck = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        #expect(deck.slides.count == 1)
    }

    @Test func aStringThatIsNotSlidesJSONStillFails() throws {
        // Rescue, not guesswork: nonsense inside the string is still an error,
        // and the message says both things that went wrong.
        let json = #"{"meta":{"title":"T"},"slides":"not json at all"}"#
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        }
    }

    /// `localizedDescription` on a DecodingError is "The data couldn't be read
    /// because it isn't in the correct format" — true, and useless as the only
    /// thing a repair attempt is told. A 29-slide draft was lost because the
    /// repair was handed that sentence and repeated the same mistake.
    @Test func aDecodeFailureTellsTheRepairWhereToLook() throws {
        // Two objects with the separator missing, inside a stringified array —
        // the shape of the draft that lost a deck.
        let broken = #"[{"id":"s1","layout":"title","title":"A"} {"id":"s2","layout":"bullets"}]"#
        let escaped = String(data: try JSONEncoder().encode(broken), encoding: .utf8)!
        let json = #"{"meta":{"title":"T"},"slides":"# + escaped + "}"

        var message = ""
        do {
            _ = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        } catch {
            message = DeckGenerator.describeDecodingFailure(error)
        }
        #expect(message.contains("slides"), "does not say which field")
        // The syntax detail Foundation buries two errors deep — "unexpected
        // character ... around line N" — is the part a repair can act on.
        // Apple's Foundation puts it in NSDebugDescription; swift-corelibs
        // words the same failure differently and has no equivalent to pull
        // out, so this is asserted where the detail exists. What Lectern
        // itself contributes — the field, and what to send instead — is
        // checked on every platform.
        #if canImport(Darwin)
        #expect(message.lowercased().contains("unexpected"), "no syntax detail: \(message)")
        #endif
        #expect(message.contains("real JSON array"), "does not say what to send instead")
        #expect(!message.contains("isn't in the correct format"))
    }

    @Test func aMissingKeyNamesTheKeyAndThePath() throws {
        // `meta` is required; the message has to name it rather than shrug.
        let json = #"{"slides":[]}"#
        var message = ""
        do {
            _ = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        } catch {
            message = DeckGenerator.describeDecodingFailure(error)
        }
        #expect(message.contains("meta"))
    }

    @Test func statementAndCalloutRenderAndOpenClean() async throws {
        let deck = DeckIR(meta: Meta(title: "Layouts"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "statement",
                    body: Body(claim: "The trap, in one sentence",
                               lead: "Each firm captures the full saving but bears a fraction of the loss.")),
            IRSlide(id: "s3", layout: "callout", title: "Proposition 1",
                    body: Body(bullets: [Bullet(text: "dominant strategy")],
                               band: "a = min[(s - l/N) / k, 1]",
                               source: "The frictionless case is treated separately")),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                     notesEnabled: false, into: dir)
        #expect(result.slideCount == 3)
        #expect(try Presentation(contentsOf: result.url).validate().isEmpty)
    }

    @Test func statementWithoutAClaimIsRejected() throws {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "statement", title: "No claim"),
        ])
        #expect(throws: (any Error).self) {
            _ = try DeckValidator().validate(deck, notesRequired: false)
        }
    }

    /// Variety asked for is not variety enforced. A model that likes a layout
    /// will use it eight times, and the deck reads as one slide repeated.
    @Test func aLayoutUsedPastItsShareIsThinnedToBullets() throws {
        // Twelve slides, seven of them the five-circle diagram.
        var slides = [IRSlide(id: "s1", layout: "title", title: "Opener")]
        for i in 2...8 {
            slides.append(IRSlide(id: "s\(i)", layout: "diagram", title: "Step set \(i)",
                                  body: Body(diagram: IRDiagram(kind: "process",
                                                                items: ["one", "two", "three"]))))
        }
        for i in 9...12 {
            slides.append(IRSlide(id: "s\(i)", layout: "quote", title: "Q",
                                  body: Body(quote: "a quote")))
        }
        let result = try DeckValidator().validate(DeckIR(meta: Meta(title: "Repeats"),
                                                         slides: slides), notesRequired: false)
        let diagrams = result.deck.slides.filter { $0.layout == "diagram" }
        // 17% of twelve slides is two; the rest become bullets.
        #expect(diagrams.count == 2)
        #expect(result.deck.slides.filter { $0.layout == "bullets" }.count == 5)
        #expect(result.warnings.contains { $0.contains("laid out as bullets") })
        // Nothing is lost: the steps survive as the bullets.
        let thinned = try #require(result.deck.slides.first { $0.id == "s8" })
        #expect(thinned.body?.bullets?.map(\.text) == ["one", "two", "three"])
    }

    @Test func aLayoutWithinItsShareIsUntouched() throws {
        var slides = [IRSlide(id: "s1", layout: "title", title: "Opener")]
        for i in 2...12 {
            slides.append(IRSlide(id: "s\(i)", layout: i <= 3 ? "diagram" : "quote",
                                  title: "S\(i)",
                                  body: i <= 3
                                      ? Body(diagram: IRDiagram(kind: "process", items: ["a", "b"]))
                                      : Body(quote: "q")))
        }
        let result = try DeckValidator().validate(DeckIR(meta: Meta(title: "Fine"),
                                                         slides: slides), notesRequired: false)
        #expect(result.deck.slides.filter { $0.layout == "diagram" }.count == 2)
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
        #expect(PriceTable.cost(model: "claude-opus-5", usage: opus) == Decimal(675) / 100)
    }

    @Test func imageProviderEndpointsSurviveHostileModelIdentifiers() throws {
        // `model` is public API surface headed for user-editability; a space
        // or `#` in a raw interpolation made `URL(string:)` nil — and the
        // force-unwrap on it a crash.
        #expect(try GeminiImageProvider.endpoint(model: "gemini-3.1-flash-image").absoluteString
            == "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image")
        #expect(try OpenAIImageProvider.endpoint(model: "weird model#1").absoluteString
            == "https://api.openai.com/v1/models/weird%20model%231")
        #expect(throws: LecternError.self) {
            _ = try OpenAIImageProvider.endpoint(model: "")
        }
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

    @Test func preflightEstimateCountsThePromptAndTheQAPass() throws {
        // A 30k-character brief is real input the user pays for; so is the QA
        // pass, which re-sends the whole draft. Ignoring both under-read real
        // spend by ~2.5–3× exactly when the number mattered most.
        let bare = try #require(PriceTable.estimate(model: "claude-sonnet-5", slideCount: 12,
                                                    promptChars: 0, qualityPass: false))
        let longPrompt = try #require(PriceTable.estimate(model: "claude-sonnet-5", slideCount: 12,
                                                          promptChars: 30_000, qualityPass: false))
        #expect(longPrompt > bare)
        let withQA = try #require(PriceTable.estimate(model: "claude-sonnet-5", slideCount: 12,
                                                      promptChars: 0, qualityPass: true))
        #expect(withQA > bare * 2)      // second call + the draft re-sent as input
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

/// Records how many image requests are in flight at once, and the high-water
/// mark. An actor so the counter is safe under real concurrency.
private actor ConcurrencyProbe {
    private(set) var peak = 0
    private var inFlight = 0
    private(set) var total = 0

    func enter() {
        inFlight += 1
        total += 1
        peak = max(peak, inFlight)
    }
    func leave() { inFlight -= 1 }
}

/// A test-only image provider that does no I/O but stays "in flight" long
/// enough that anything allowed to overlap will overlap — so the peak the probe
/// records is the fan-out the pipeline actually chose.
private struct ProbeImageProvider: ImageProvider {
    let id: ImageProviderID
    let probe: ConcurrencyProbe

    func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        await probe.enter()
        try? await Task.sleep(nanoseconds: 20_000_000)
        await probe.leave()
        return Data("image-bytes".utf8)
    }
}

/// Records the `max_tokens` each outgoing request asked for.
private final class SentBox: @unchecked Sendable {
    private let lock = NSLock()
    private var budgets: [Int] = []
    func record(_ budget: Int) { lock.lock(); defer { lock.unlock() }; budgets.append(budget) }
    var values: [Int] { lock.lock(); defer { lock.unlock() }; return budgets }
}
