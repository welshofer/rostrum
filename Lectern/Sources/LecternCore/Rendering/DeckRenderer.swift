import Foundation
import Rostrum
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif

public struct DeckResult: Sendable, Equatable {
    public let url: URL
    public let slideCount: Int
    public let warnings: [String]
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

    /// Render `deck` (styled by the `design.md` at `designURL`, if any) into
    /// `directory`. `warnings` from validation are passed through to the result.
    public func render(_ deck: DeckIR, designURL: URL?, notesEnabled: Bool,
                       into directory: URL, warnings: [String] = [],
                       images: [String: Data] = [:]) throws -> DeckResult {
        do {
            let presentation = try Presentation()
            if let designURL { _ = try presentation.applyDesign(contentsOf: designURL) }

            for slide in deck.slides {
                let built = try build(slide, in: presentation)
                if let data = images[slide.id] {
                    switch slide.kind.imagePlacement {
                    case .fullBleed:
                        // Edge-to-edge background behind the text, dimmed so the
                        // slide's ink stays readable over any image.
                        let scrimmed = Self.scrimmed(data, dark: presentation.style.isDark)
                        try? built.setBackground(.image(scrimmed, .stretch))
                    case .sidePanel:
                        // A framed panel on the right (title/content sit left).
                        try? built.shapes.addPicture(data, frame: Self.imageFrame(in: presentation), fit: .fill)
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

            let url = try outputURL(title: deck.meta.title, in: directory)
            try presentation.save(to: url)
            return DeckResult(url: url, slideCount: presentation.slides.count, warnings: warnings)
        } catch let error as RenderError {
            throw error
        } catch {
            throw RenderError.renderFailed(underlying: "\(error)")
        }
    }

    // MARK: - IR layout → Rostrum builder

    private func build(_ slide: IRSlide, in deck: Presentation) throws -> Slide {
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
            // The "five layers" look — now a native Basic Block List SmartArt
            // (editable, PowerPoint-verified), not drawn bands. Same stacked,
            // brand-colored blocks as flex slide 3.
            let items = body?.items ?? flatten(body?.bullets ?? [])
            if !items.isEmpty { return try deck.smartArtSlide(title, kind: .blockList, items: items) }
            return try deck.bulletSlide(title, [])
        case .diagram:
            if let d = body?.diagram, !d.items.isEmpty {
                switch d.kind.lowercased() {
                // process + cycle are native SmartArt (PowerPoint-verified). pyramid's
                // native pyra algorithm isn't PowerPoint-faithful yet, so it uses the
                // proven drawn builder until a correct pyra layoutDef lands.
                case "pyramid": return try deck.pyramidSlide(title, levels: d.items)
                case "cycle":   return try deck.smartArtSlide(title, kind: .cycle, items: d.items)
                default:        return try deck.smartArtSlide(title, kind: .process, items: d.items)
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

    /// Darken (dark theme) or lighten (light theme) an image ~55% so the slide's
    /// ink stays legible over a full-bleed background. No-op without CoreGraphics.
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
        ctx.setFillColor(dark ? CGColor(red: 0, green: 0, blue: 0, alpha: 0.55)
                              : CGColor(red: 1, green: 1, blue: 1, alpha: 0.55))
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
        let indexOfSlideId = Dictionary(uniqueKeysWithValues: deck.slides.enumerated().map { ($1.id, $0) })
        var boundaries: [(name: String, startSlide: Int)] = []
        for section in sections {
            guard let first = section.slideIds.compactMap({ indexOfSlideId[$0] }).min() else { continue }
            boundaries.append((section.title ?? "Section", first))
        }
        boundaries.sort { $0.startSlide < $1.startSlide }
        guard let firstBoundary = boundaries.first, firstBoundary.startSlide == 0 else { return }
        try? presentation.setSections(boundaries)
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
