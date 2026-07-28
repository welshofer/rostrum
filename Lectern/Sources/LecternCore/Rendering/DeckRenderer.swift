import Foundation
import Rostrum
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif
#if canImport(CoreText)
import CoreText
#endif

public struct DeckResult: Sendable, Equatable {
    public let url: URL
    public let slideCount: Int
    public let warnings: [String]
    /// Schema-rule violations Rostrum's lint found in the deck we just wrote —
    /// a missing required attribute somewhere in the XML. Distinct from
    /// `warnings`, which are about the model's plan: these are ours, and an
    /// empty list is the normal case.
    public let schemaIssues: [String]
    /// Typefaces this deck's style asks for that aren't installed here, so
    /// their text was laid out from Rostrum's calibrated estimates rather than
    /// real advance widths. Kept out of `warnings` on purpose: whether a font
    /// is present is a fact about this machine, not about the deck.
    public let unmeasuredFonts: [String]
    /// One self-contained SVG per slide, rendered by Rostrum from the deck it
    /// just wrote — not a reconstruction from the IR. Empty if rendering
    /// failed, which is never fatal: the `.pptx` on disk is the deliverable
    /// and a preview is a convenience.
    ///
    /// `String` rather than a view or an image so it crosses the actor
    /// boundary as a value; `Presentation` is not `Sendable` and must not
    /// leave.
    public let previews: [String]
}

public enum RenderError: Error {
    case renderFailed(underlying: String)
}

/// Turns a validated `DeckIR` into a native `.pptx` via Rostrum's builders. An
/// actor per invariant I2: the (non-`Sendable`) Rostrum presentation is created,
/// mutated, and saved entirely inside here — only a `DeckResult` (URLs + value
/// types) leaves.
public actor DeckRenderer {
    public init() {}

    // MARK: - Previews

    /// Render every slide to SVG with Rostrum's own renderer.
    ///
    /// This shows the deck Rostrum actually produced — same theme resolution,
    /// same placeholder inheritance, same text. A preview drawn from the IR
    /// instead would be a second implementation of layout, free to disagree
    /// with the file the user opens.
    ///
    /// A preview, not a proof. Paragraphs whose typeface is registered break
    /// exactly where the builders broke them; the rest break on a
    /// character-width estimate and can land elsewhere than PowerPoint puts
    /// them. `unmeasuredFonts` names the faces that fell back.
    ///
    /// Best-effort per slide: one slide that fails to render costs its own
    /// preview and nothing else, because a missing thumbnail is not a reason
    /// to fail a deck that saved correctly.
    private static func previews(of presentation: Presentation) -> [String] {
        (0..<presentation.slides.count).compactMap { index in
            try? presentation.renderSVG(slideAt: index, pixelWidth: 640)
        }
    }

    // MARK: - Document metadata

    /// Fill in `docProps` from the IR, so the deck arrives with an identity.
    /// PowerPoint's info pane, Finder's Get Info, Spotlight, SharePoint and
    /// every "recent documents" list read these; a deck with none of them
    /// shows up as an untitled file that nothing wrote.
    ///
    /// Timestamps are deliberately not stamped. Rostrum never sets them for
    /// you (see `DocumentProperties`) precisely so that building the same IR
    /// twice yields the same bytes, and Lectern has no reason to give that up.
    private static func stampProperties(of deck: DeckIR, on presentation: Presentation) {
        // A live view onto docProps, not a value to write back — every setter
        // goes straight to the part.
        let properties = presentation.documentProperties
        properties.title = deck.meta.title
        // The subtitle is the deck's one-line pitch; `subject` is where every
        // document inspector looks for exactly that.
        if let subtitle = deck.meta.subtitle, !subtitle.isEmpty {
            properties.subject = subtitle
        }
        if let audience = deck.meta.audience, !audience.isEmpty {
            properties.category = audience
        }
        properties.application = "Lectern (Rostrum)"
    }

    // MARK: - Text measurement

    /// Register the typefaces this deck's style actually uses, so Rostrum's
    /// builders measure text with real advance widths instead of falling back
    /// to their calibrated character-count estimates. Every builder Lectern
    /// calls — bullets, metrics, quotes, comparisons, bands, process — consults
    /// `presentation.fonts`, so this is the difference between text that is
    /// known to fit and text that is guessed to.
    ///
    /// Rostrum deliberately never looks in platform font directories: implicit
    /// lookup would make identical code emit different bytes on different
    /// machines, and its determinism is a library-level promise. Lectern is an
    /// app rendering for the machine in front of it and can make the opposite
    /// trade — measure with the fonts that are actually here, and estimate for
    /// the ones that aren't.
    ///
    /// - Returns: the requested typefaces that could not be registered, in
    ///   sorted order. Empty on platforms without CoreText, where nothing is
    ///   registered and every builder estimates exactly as it did before.
    private static func registerInstalledFonts(for presentation: Presentation) -> [String] {
        #if canImport(CoreText)
        let style = presentation.style
        var wanted: Set<String> = [style.headingFont, style.bodyFont]
        for role in TypeRole.allCases { wanted.insert(style.type(role).font) }

        var unmeasured: [String] = []
        for name in wanted.sorted() where !name.isEmpty {
            guard let url = installedFontFile(named: name),
                  let data = try? Data(contentsOf: url),
                  let face = faceIndex(named: name, in: data),
                  (try? presentation.fonts.register(data, aliases: [name], fontIndex: face)) != nil
            else {
                unmeasured.append(name)
                continue
            }
        }
        return unmeasured
        #else
        return []
        #endif
    }

    #if canImport(CoreText)
    /// The file backing an installed font family, or nil when it isn't here.
    ///
    /// CoreText substitutes silently — ask for a face that isn't installed and
    /// it hands back the system fallback. Registering *that* under the
    /// requested name would measure the wrong glyphs and report confidence,
    /// which is worse than estimating, so the family it resolved to has to be
    /// the family that was asked for.
    static func installedFontFile(named name: String) -> URL? {
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        let resolved = CTFontCopyFamilyName(font) as String
        guard resolved.caseInsensitiveCompare(name) == .orderedSame else { return nil }
        return CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL
    }

    /// Which face inside `data` calls itself `name`.
    ///
    /// `kCTFontURLAttribute` gives a path, not a face — and on macOS a `.ttc`
    /// routinely holds several *families*, not just several weights of one
    /// (PingFang SC/TC/HK, Songti SC/TC/STSong). Registering without an index
    /// parses face 0, so asking for a family that lives deeper in the
    /// collection would measure a different typeface's advance widths under
    /// the requested name — and, because parsing succeeded, leave it out of
    /// `unmeasuredFonts`. That is exactly the confidently-wrong outcome the
    /// family check above exists to prevent, one level further in: CoreText
    /// vouches for the file, this vouches for the face inside it.
    ///
    /// Returns nil when no face claims the name, so the caller estimates
    /// rather than measuring something else.
    static func faceIndex(named name: String, in data: Data) -> Int? {
        for index in 0..<Self.maxFacesPerCollection {
            guard let metrics = try? FontMetrics(data: data, fontIndex: index) else { return nil }
            if metrics.familyNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                return index
            }
        }
        return nil
    }

    /// Enough for any collection Apple ships; a bound because the loop's exit
    /// otherwise depends on a parse failing.
    private static let maxFacesPerCollection = 64
    #endif

    /// Render `deck` (styled by the `design.md` at `designURL`, if any) into
    /// `directory`. `warnings` from validation are passed through to the result.
    public func render(_ deck: DeckIR, designURL: URL?, notesEnabled: Bool,
                       into directory: URL, warnings: [String] = [],
                       images: [String: Data] = [:], useSmartArt: Bool = false) throws -> DeckResult {
        do {
            // Rendering is now the slowest phase — font registration, package
            // deflate, the schema lint, N SVG renders — so Cancel has to reach
            // it. Without these the user is returned to Compose and then, a few
            // seconds later, thrown into a Result screen for the deck they just
            // cancelled, with the file already written.
            try Task.checkCancellation()
            let presentation = try Presentation()
            if let designURL { _ = try presentation.applyDesign(contentsOf: designURL) }
            // After applyDesign: the style is what decides which typefaces the
            // builders will be measuring with.
            let unmeasured = Self.registerInstalledFonts(for: presentation)

            for slide in deck.slides {
                try Task.checkCancellation()
                let built = try build(slide, in: presentation, useSmartArt: useSmartArt)
                if let data = images[slide.id] {
                    switch slide.kind.imagePlacement {
                    case .fullBleed:
                        // Edge-to-edge background behind the text, dimmed so the
                        // slide's ink stays readable over any image.
                        let scrimmed = Self.scrimmed(data, dark: presentation.style.isDark)
                        try? built.setBackground(.image(scrimmed, .stretch))
                    case .sidePanel:
                        // A framed panel on the right (title/content sit left).
                        _ = try? built.shapes.addPicture(
                            data, frame: Self.imageFrame(in: presentation), fit: .fill)
                    case .none:
                        break
                    }
                }
                if notesEnabled, let notes = slide.notes, !notes.isEmpty {
                    try built.setNotes(notes)
                }
            }
            // Presentation() starts with one blank slide; the builders appended
            // after it. Drop the leading blank so the deck is exactly the IR.
            if presentation.slides.count > deck.slides.count {
                try presentation.slides.remove(at: 0)
            }
            applySections(deck, to: presentation)
            Self.stampProperties(of: deck, on: presentation)

            // Rostrum's schema lint, run on what we are about to write rather
            // than on a deck someone opens later. It reads the DOM and mutates
            // nothing, so it costs a pass and can only tell us something we
            // would otherwise ship. Failures here are ours, not the model's.
            let schemaIssues = ((try? presentation.validate()) ?? []).map(\.description)

            // Last chance before anything lands on disk: a cancel up to here
            // leaves no file behind at all.
            try Task.checkCancellation()
            let url = try outputURL(title: deck.meta.title, in: directory)
            try presentation.save(to: url)
            return DeckResult(url: url, slideCount: presentation.slides.count,
                              warnings: warnings, schemaIssues: schemaIssues,
                              unmeasuredFonts: unmeasured,
                              // Previews are the tail cost and pure
                              // convenience; the deck is already saved, so a
                              // cancel here skips them rather than undoing it.
                              previews: Task.isCancelled ? [] : Self.previews(of: presentation))
        } catch is CancellationError {
            // Must precede the generic catch. Wrapped, this becomes
            // RenderError.renderFailed("CancellationError()") and the user is
            // shown a failure screen for something they asked to stop.
            throw CancellationError()
        } catch let error as RenderError {
            throw error
        } catch {
            throw RenderError.renderFailed(underlying: "\(error)")
        }
    }

    // MARK: - IR layout → Rostrum builder

    private func build(_ slide: IRSlide, in deck: Presentation, useSmartArt: Bool) throws -> Slide {
        let title = slide.title ?? ""
        let body = slide.body
        switch slide.kind {
        case .title:
            return try deck.titleSlide(title, subtitle: body?.subtitle)
        case .sectionHeader:
            return try deck.sectionSlide(title, subtitle: body?.kicker)
        case .agenda:
            return try deck.bulletSlide(title.isEmpty ? "Agenda" : title, body?.items ?? [])
        case .bullets:
            return try deck.bulletSlide(title, flatten(body?.bullets ?? []))
        case .twoColumn, .comparison:
            let left = body?.left ?? Column(heading: "", bullets: [])
            let right = body?.right ?? Column(heading: "", bullets: [])
            return try deck.comparisonSlide(title, leftHeader: left.heading, left: left.bullets,
                                            rightHeader: right.heading, right: right.bullets)
        case .quote:
            return try deck.quoteSlide(body?.quote ?? title, attribution: body?.attribution)
        case .bigNumber:
            return try deck.calloutSlide(stat: body?.value ?? "", caption: body?.label ?? "", kicker: title.isEmpty ? nil : title)
        case .closing:
            return try deck.closingSlide(title.isEmpty ? "Thank you" : title,
                                         callToAction: body?.callToAction, contact: body?.contact)
        case .chart:
            // Only build a chart when the data is well-formed (matching series
            // lengths) — otherwise fall back to bullets rather than crash.
            if let c = body?.chart, !c.categories.isEmpty, !c.series.isEmpty,
               c.series.allSatisfy({ $0.values.count == c.categories.count }) {
                let kind: ChartKind = {
                    switch c.kind.lowercased() {
                    case "line": return .line
                    case "pie", "doughnut": return .pie
                    default: return .barClustered
                    }
                }()
                let data = ChartData(categories: c.categories,
                                     series: c.series.map { ChartData.Series(name: $0.name, values: $0.values) })
                // Make the chart carry its own values (positions kept valid per
                // kind so PowerPoint never repairs): bars/lines show values, pies
                // show a percentage with a legend.
                let options: ChartOptions
                switch kind {
                case .pie:
                    options = ChartOptions(legend: .right, dataLabels: DataLabelOptions(showPercent: true))
                case .line:
                    options = ChartOptions(dataLabels: DataLabelOptions(showValue: true, position: "t"))
                default:
                    options = ChartOptions(dataLabels: DataLabelOptions(showValue: true, position: "outEnd"))
                }
                return try deck.chartSlide(title, kind, data, options: options)
            }
            return try deck.bulletSlide(title, flatten(body?.bullets ?? []))
        case .metrics:
            if let stats = body?.stats, !stats.isEmpty {
                return try deck.metricsSlide(title, metrics: stats.map { (value: $0.value, label: $0.label) })
            }
            return try deck.bulletSlide(title, flatten(body?.bullets ?? []))
        case .bands:
            let items = body?.items ?? flatten(body?.bullets ?? [])
            guard !items.isEmpty else { return try deck.bulletSlide(title, []) }
            // Native Basic Block List SmartArt when opted in; styled shapes otherwise.
            return useSmartArt
                ? try deck.smartArtSlide(title, kind: .blockList, items: items)
                : try deck.bandsSlide(title, bands: items)
        case .diagram:
            if let d = body?.diagram, !d.items.isEmpty {
                switch d.kind.lowercased() {
                // pyramid is always drawn (native pyra isn't PowerPoint-faithful).
                case "pyramid":
                    return try deck.pyramidSlide(title, levels: d.items)
                case "cycle":
                    return useSmartArt
                        ? try deck.smartArtSlide(title, kind: .cycle, items: d.items)
                        : try deck.processSlide(title, steps: d.items)
                default:
                    return useSmartArt
                        ? try deck.smartArtSlide(title, kind: .process, items: d.items)
                        : try deck.processSlide(title, steps: d.items)
                }
            }
            return try deck.bulletSlide(title, flatten(body?.bullets ?? []))
        case .unknown:
            // Validation downgrades unknown → bullets, so this is unreachable for
            // a validated deck; render an empty bulleted slide defensively.
            return try deck.bulletSlide(title, [])
        }
    }

    /// Flatten a bullet tree to strings, sub-bullets prefixed with an en dash.
    private func flatten(_ bullets: [Bullet]) -> [String] {
        bullets.flatMap { [$0.text] + ($0.subBullets ?? []).map { "– \($0)" } }
    }

    /// Right-hand image panel: ~40% width, vertically centered, with a margin —
    /// mirrors the reference hero cards and clears left-aligned title/bullets.
    private static func imageFrame(in presentation: Presentation) -> Rect {
        let size = presentation.slideSize
        let w = Double(size.width.rawValue), h = Double(size.height.rawValue)
        return Rect(x: EMU(Int(w * 0.555)), y: EMU(Int(h * 0.21)),
                    width: EMU(Int(w * 0.40)), height: EMU(Int(h * 0.58)))
    }

    /// Darken (dark theme) or lighten (light theme) an image ~70% so the slide's
    /// ink stays legible over a full-bleed background. 55% left busy artwork
    /// fighting the stat caption on bigNumber slides; 70% keeps the image as
    /// texture while every text role clears it. No-op without CoreGraphics.
    private static func scrimmed(_ data: Data, dark: Bool) -> Data {
        #if canImport(CoreGraphics)
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
              img.width > 0, img.height > 0,
              let ctx = CGContext(data: nil, width: img.width, height: img.height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return data }
        let rect = CGRect(x: 0, y: 0, width: img.width, height: img.height)
        ctx.draw(img, in: rect)
        ctx.setFillColor(dark ? CGColor(red: 0, green: 0, blue: 0, alpha: 0.70)
                              : CGColor(red: 1, green: 1, blue: 1, alpha: 0.70))
        ctx.fill(rect)
        guard let out = ctx.makeImage() else { return data }
        let buffer = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(buffer as CFMutableData,
                                                          UTType.png.identifier as CFString, 1, nil) else { return data }
        CGImageDestinationAddImage(dest, out, nil)
        guard CGImageDestinationFinalize(dest) else { return data }
        return buffer as Data
        #else
        return data
        #endif
    }

    // MARK: - Sections

    private func applySections(_ deck: DeckIR, to presentation: Presentation) {
        guard let sections = deck.sections, !sections.isEmpty else { return }
        // `uniquingKeysWith` rather than `uniqueKeysWithValues`: the latter
        // traps on a duplicate id, and a trap here would abort the app over a
        // model that repeated one.
        let indexOfSlideId = Dictionary(
            deck.slides.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })

        var boundaries: [(name: String, startSlide: Int)] = []
        for section in sections {
            guard let first = section.slideIds.compactMap({ indexOfSlideId[$0] }).min() else { continue }
            boundaries.append((section.title ?? "Section", first))
        }
        boundaries.sort { $0.startSlide < $1.startSlide }

        // Rostrum enforces strictly-increasing starts with a `precondition`
        // (Sections.set), which **aborts the process** — `try?` cannot catch
        // it. Two sections whose slide sets share a first slide, which is all
        // it takes for a model to list one slide under two headings, would
        // otherwise take the whole app down. Keep the first of each run.
        var distinct: [(name: String, startSlide: Int)] = []
        for boundary in boundaries where distinct.last?.startSlide != boundary.startSlide {
            distinct.append(boundary)
        }
        guard let first = distinct.first else { return }

        // Rostrum also requires the first section to start at slide 0, again as
        // a precondition. A model that leaves the title slide out of every
        // section is ordinary output, not an error, so cover the gap rather
        // than silently discarding every section it asked for.
        if first.startSlide != 0 {
            let opening = deck.slides.first?.title
            distinct.insert((name: opening?.isEmpty == false ? opening! : "Opening", startSlide: 0),
                            at: 0)
        }

        // Starts must be inside the deck we actually wrote; out-of-range throws
        // rather than trapping, so `try?` is the right catch for that half.
        try? presentation.setSections(distinct)
    }

    // MARK: - Output path

    private func outputURL(title: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = slugify(title.isEmpty ? "deck" : title)
        var candidate = directory.appendingPathComponent("\(base).pptx")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base)-\(n).pptx")
            n += 1
        }
        return candidate
    }

    private func slugify(_ s: String) -> String {
        let lowered = s.lowercased()
        var out = ""
        var lastDash = false
        for scalar in lowered.unicodeScalars {
            if scalar.properties.isAlphabetic || ("0"..."9").contains(Character(scalar)) {
                out.unicodeScalars.append(scalar); lastDash = false
            } else if !lastDash {
                out.append("-"); lastDash = true
            }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "deck" : String(trimmed.prefix(60))
    }
}
