import Foundation
import Rostrum

/// One slide, reduced to what an inspector view shows.
///
/// Deliberately plain types. Rostrum's `DeckOutline` is the real extraction
/// model, but LecternCore is the app's entire API surface — the app target
/// links this and nothing below it — so what crosses that line is `String` and
/// `Int`, not a type from a module the app does not import.
public struct SlideDigest: Sendable, Identifiable {
    /// 1-based, and the same number the export uses for `slide-NN`.
    public var id: Int { number }
    public let number: Int
    public let title: String?
    public let subtitle: String?
    /// Body text, one entry per paragraph, already indented to its outline
    /// level so the view can print it without knowing about levels.
    public let bullets: [String]
    public let tableCount: Int
    public let chartTitles: [String]
    /// Filenames the export would write into this slide's folder.
    public let assetNames: [String]
    public let notes: [String]

    public var hasAttachments: Bool { !assetNames.isEmpty || !chartTitles.isEmpty }
}

/// What a deck turns out to be made of.
///
/// The read-side counterpart to `DeckResult`: where that describes a deck
/// Lectern just wrote, this describes one it just opened.
///
/// Every field is a value. `Presentation` is not `Sendable` and must not leave
/// the actor that opened it, so the deck is taken apart where it is opened and
/// only this comes back.
public struct DeckInspection: Sendable {
    public let fileURL: URL
    public let fileName: String
    public let byteCount: Int

    public let slideCount: Int
    public let layoutCount: Int
    public let masterCount: Int
    public let mediaCount: Int
    public let chartCount: Int
    public let embedCount: Int
    public let notesCount: Int
    public let partCount: Int
    /// e.g. `13.33in × 7.50in`.
    public let slideSize: String
    /// Section names with their slide counts; empty when the deck has none.
    public let sections: [String]

    /// Rostrum's schema lint on a deck it did not write. Empty is the normal
    /// case, and an entry is a fact about the file rather than about Lectern.
    public let schemaIssues: [String]
    /// Parts the package carried that the reader could not place.
    public let readWarnings: [String]
    /// Slides the extraction could not read at all.
    public let outlineWarnings: [String]

    public let slides: [SlideDigest]

    /// One self-contained SVG per slide, index-aligned with `previewTitles`.
    /// Empty when previews were skipped or every slide failed to render; a
    /// missing picture is never a reason to fail an inspection.
    public let previews: [String]
    public let previewTitles: [String]

    public var hasFindings: Bool {
        !schemaIssues.isEmpty || !readWarnings.isEmpty || !outlineWarnings.isEmpty
    }

    /// A size a person can read, computed the same way every time.
    public var formattedSize: String {
        if byteCount < 1024 { return "\(byteCount) B" }
        let units = ["KB", "MB", "GB"]
        var value = Double(byteCount) / 1024
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        return String(format: "%.1f", value) + " " + units[unit]
    }
}

/// Open a deck and take it apart, reporting progress as it goes.
///
/// Opening a large deck, walking every shape for its text and rendering a
/// picture of every slide are all real work — on a sixty-slide deck with
/// photographic media that is seconds, not milliseconds. So this says what it
/// is doing rather than leaving a window frozen with no explanation, and it
/// checks for cancellation between slides.
public enum DeckInspector {
    public enum Event: Sendable, Equatable {
        case opening
        case validating
        case extracting
        /// Previews are the slow part and the only step with a real
        /// denominator, so it is the one that can drive a determinate bar.
        case rendering(done: Int, total: Int)
        case finished
    }

    /// Inspect the deck at `url`.
    ///
    /// Call this off the main actor — it is synchronous, CPU-bound, and opens
    /// a `Presentation`, which must not cross an actor boundary.
    ///
    /// - Parameter renderPreviews: pass `false` to skip the slowest step when
    ///   only the numbers and the text are wanted.
    public static func inspect(deckAt url: URL,
                               renderPreviews: Bool = true,
                               onEvent: (Event) -> Void = { _ in }) throws -> DeckInspection {
        onEvent(.opening)
        let data = try Data(contentsOf: url)
        let deck = try Presentation(data: data)

        onEvent(.validating)
        // A deck somebody else wrote is exactly the one whose lint might throw;
        // that is a finding, not a failure of the inspection.
        let issues = (try? deck.validate()) ?? []

        onEvent(.extracting)
        let outline = deck.outline()
        let digests = outline.slides.map(digest(of:))

        var previews: [String] = []
        var titles: [String] = []
        if renderPreviews {
            let total = deck.slides.count
            onEvent(.rendering(done: 0, total: total))
            for index in 0..<total {
                try Task.checkCancellation()
                // Best-effort per slide, matching the write side: a slide that
                // will not render costs its own thumbnail and nothing else.
                // Both arrays are appended together so they stay aligned.
                if let svg = try? deck.renderSVG(slideAt: index, pixelWidth: 640) {
                    previews.append(svg)
                    titles.append((try? deck.slides[index].title?.textFrame?.text) ?? "")
                }
                onEvent(.rendering(done: index + 1, total: total))
            }
        }

        onEvent(.finished)
        return DeckInspection(
            fileURL: url,
            fileName: url.lastPathComponent,
            byteCount: data.count,
            slideCount: deck.slides.count,
            layoutCount: deck.layouts.count,
            masterCount: partCount(deck, "/ppt/slideMasters/"),
            mediaCount: partCount(deck, "/ppt/media/"),
            chartCount: partCount(deck, "/ppt/charts/"),
            embedCount: partCount(deck, "/ppt/embeddings/"),
            notesCount: partCount(deck, "/ppt/notesSlides/"),
            partCount: deck.package.parts.count,
            slideSize: String(format: "%.2fin × %.2fin",
                              deck.slideSize.width.inches, deck.slideSize.height.inches),
            sections: Array(deck.sections).map { "\($0.name) (\($0.slideCount))" },
            schemaIssues: issues.map { "\($0)" },
            readWarnings: deck.package.readWarnings,
            outlineWarnings: outline.warnings,
            slides: digests,
            previews: previews,
            previewTitles: titles)
    }

    private static func digest(of slide: SlideOutline) -> SlideDigest {
        let bullets = slide.body.flatMap { block in
            block.paragraphs.map { paragraph in
                String(repeating: "    ", count: min(paragraph.level, 6))
                    + paragraph.text.replacingOccurrences(of: "\n", with: " ")
            }
        }
        return SlideDigest(number: slide.number,
                           title: slide.title,
                           subtitle: slide.subtitle,
                           bullets: bullets,
                           tableCount: slide.tables.count,
                           chartTitles: slide.charts.map { $0.title ?? "Untitled chart" },
                           assetNames: slide.assets.map(\.filename),
                           notes: slide.notes)
    }

    private static func partCount(_ deck: Presentation, _ prefix: String) -> Int {
        deck.package.parts.keys.filter { $0.value.hasPrefix(prefix) }.count
    }
}
