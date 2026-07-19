import Foundation

/// Deterministic post-model shaping — the Layer-1 quality floor. It runs AFTER
/// validation and BEFORE render, and its whole reason to exist is that a deck's
/// quality must not rest on the prompt being obeyed. Where `PromptTemplates`
/// *asks* the model for 3–5 bullets and few bands, the normalizer *enforces* the
/// same contract in code, so the demo can't degrade into a wall of bullets or a
/// deck of near-identical bands no matter what the model returns.
///
/// General rules only — no per-input tuning, and nothing here invents content:
///
///  1. **Split over-long lists.** A `bullets` slide with more than `maxBullets`
///     (or an `agenda` past `maxAgenda`) is split into consecutive slides sized
///     3–5 each, so no slide overflows. Agenda and bullets render identically, so
///     an over-long agenda simply becomes split bullet slides.
///  2. **Cap bands.** At most ⌈slides / 4⌉ may be `bands`; the earliest are kept
///     and every excess band becomes a process `diagram` of the same items, so a
///     band-happy model still yields a visually varied deck.
///  3. **Promote figures.** A `bullets` slide whose 2–4 bullets each *lead* with a
///     headline figure ("40% of…", "$2.3B in…", "3× faster…") becomes a `metrics`
///     slide — showing the numbers instead of listing them.
///
/// Every transform preserves the deck's words and its slide order; the caller
/// re-validates the result and keeps the un-normalized deck if anything here ever
/// produced something invalid (see `DeckGenerator.finish`). Pure and
/// deterministic: same input → same output (no clock, no randomness).
public struct DeckNormalizer: Sendable {
    public let maxBullets: Int
    public let maxAgenda: Int
    public let targetBullets: Int

    public init(maxBullets: Int = 6, maxAgenda: Int = 7, targetBullets: Int = 5) {
        self.maxBullets = maxBullets
        self.maxAgenda = maxAgenda
        self.targetBullets = targetBullets
    }

    /// What the normalizer changed, in human-readable form. Not surfaced to the
    /// user as warnings (these are improvements, not problems) — useful for tests
    /// and for deciding whether anything changed at all.
    public struct Report: Sendable, Equatable {
        public var notes: [String]
        public init(notes: [String] = []) { self.notes = notes }
        public var changed: Bool { !notes.isEmpty }
    }

    public func normalize(_ input: DeckIR) -> (deck: DeckIR, report: Report) {
        var report = Report()
        var slides = input.slides

        // Order matters: promote figures BEFORE splitting (so a numeric slide
        // becomes one metrics slide, not two bullet slides), then split, then the
        // count-based band cap (independent of the first two).
        slides = slides.map { promoteNumericBullets($0, into: &report) }
        slides = slides.flatMap { splitOverLongList($0, into: &report) }
        slides = capBands(slides, into: &report)

        var out = input
        out.slides = slides
        return (out, report)
    }

    // MARK: - Rule 1: split over-long lists

    /// Returns the slide unchanged, or two-plus `bullets` slides if it overflows.
    private func splitOverLongList(_ slide: IRSlide, into report: inout Report) -> [IRSlide] {
        let bullets: [Bullet]
        switch slide.kind {
        case .bullets:
            let b = slide.body?.bullets ?? []
            guard b.count > maxBullets else { return [slide] }
            bullets = b
        case .agenda:
            let items = slide.body?.items ?? []
            guard items.count > maxAgenda else { return [slide] }
            bullets = items.map { Bullet(text: $0) }
        default:
            return [slide]
        }

        let sizes = chunkSizes(bullets.count)
        var result: [IRSlide] = []
        var cursor = 0
        for (i, size) in sizes.enumerated() {
            let chunk = Array(bullets[cursor ..< cursor + size])
            cursor += size
            var body = slide.body ?? Body()
            body.bullets = chunk
            body.items = nil                       // was agenda-derived; now bullets
            let title = i == 0 ? slide.title : continuationTitle(slide.title)
            result.append(IRSlide(
                id: i == 0 ? slide.id : "\(slide.id)-\(i + 1)",
                sectionId: slide.sectionId,
                layout: "bullets",
                title: title,
                body: body,
                notes: i == 0 ? slide.notes : nil,  // don't duplicate speaker notes
                image: i == 0 ? slide.image : nil)) // or the image
        }
        report.notes.append("split \"\(label(slide))\" (\(bullets.count) items) into \(sizes.count) slides")
        return result
    }

    /// Sizes for `n` items, each 3–`maxBullets`, as even as possible, using the
    /// fewest slides that keeps every slide at or under `targetBullets`.
    func chunkSizes(_ n: Int) -> [Int] {
        guard n > maxBullets else { return [n] }
        let parts = Int((Double(n) / Double(targetBullets)).rounded(.up))
        let base = n / parts, remainder = n % parts
        return (0 ..< parts).map { base + ($0 < remainder ? 1 : 0) }
    }

    private func continuationTitle(_ title: String?) -> String? {
        guard let title, !title.isEmpty else { return title }
        return "\(title) (cont.)"
    }

    // MARK: - Rule 2: cap bands

    private func capBands(_ slides: [IRSlide], into report: inout Report) -> [IRSlide] {
        let bandIndices = slides.indices.filter { slides[$0].kind == .bands }
        let cap = max(1, Int((Double(slides.count) / 4.0).rounded(.up)))
        guard bandIndices.count > cap else { return slides }

        var out = slides
        for (rank, index) in bandIndices.enumerated() where rank >= cap {
            out[index] = bandsToDiagram(out[index])
        }
        report.notes.append("capped bands at \(cap)/\(slides.count) slides; "
            + "converted \(bandIndices.count - cap) to diagrams")
        return out
    }

    /// A `bands` slide → a process `diagram` carrying the same labeled items.
    private func bandsToDiagram(_ slide: IRSlide) -> IRSlide {
        let items = slide.body?.items ?? (slide.body?.bullets ?? []).map(\.text)
        var body = slide.body ?? Body()
        body.diagram = IRDiagram(kind: "process", items: items)
        body.items = nil
        var s = slide
        s.layout = "diagram"
        s.body = body
        return s
    }

    // MARK: - Rule 3: promote figures

    /// A `bullets` slide whose 2–4 bullets each lead with a headline figure →
    /// `metrics`. Conservative: fires only when EVERY bullet parses as a figure,
    /// so ordinary prose is never mangled into stat tiles.
    private func promoteNumericBullets(_ slide: IRSlide, into report: inout Report) -> IRSlide {
        guard slide.kind == .bullets, let bullets = slide.body?.bullets,
              (2 ... 4).contains(bullets.count) else { return slide }
        let stats = bullets.compactMap { leadingStat($0.text) }
        guard stats.count == bullets.count else { return slide }

        var body = slide.body ?? Body()
        body.stats = stats.map { IRStat(value: $0.value, label: $0.label) }
        body.bullets = nil
        var s = slide
        s.layout = "metrics"
        s.body = body
        report.notes.append("promoted \"\(label(slide))\" (\(stats.count) figures) to metrics")
        return s
    }

    /// Splits "40% of coastal homes are underinsured" into ("40%", "coastal homes
    /// are underinsured"): a leading numeric token, then the rest as the caption.
    /// Returns nil unless the first whitespace-delimited token is figure-shaped and
    /// a non-empty caption follows.
    func leadingStat(_ text: String) -> (value: String, label: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let space = trimmed.firstIndex(of: " ") else { return nil }  // a lone number isn't a metric
        let token = String(trimmed[trimmed.startIndex ..< space])
        guard let first = token.first, first.isNumber || "+-−$€£¥".contains(first),
              token.contains(where: \.isNumber),
              token.unicodeScalars.allSatisfy({ Self.figureScalars.contains(Character($0)) })
        else { return nil }

        var rest = String(trimmed[trimmed.index(after: space)...])
            .trimmingCharacters(in: CharacterSet(charactersIn: " —–-:"))
            .trimmingCharacters(in: .whitespaces)
        // Drop a leading "of "/"in " so labels read as noun phrases, not fragments.
        for prefix in ["of ", "in "] where rest.hasPrefix(prefix) {
            rest = String(rest.dropFirst(prefix.count)); break
        }
        guard !rest.isEmpty else { return nil }
        return (token, rest)
    }

    /// Characters a figure token may contain: digits, separators, currency,
    /// percent/multiplier, sign, and magnitude suffixes (K/M/B/bn).
    private static let figureScalars = Set("0123456789.,$€£¥%×xX+-−KMBkmbn")

    private func label(_ slide: IRSlide) -> String {
        let t = slide.title ?? ""
        return t.isEmpty ? slide.id : t
    }
}
