import Foundation

/// What rebuilding a deck on a template's layouts did, slide by slide.
public struct RecomposeReport: Sendable, Equatable {
    /// Slides rebuilt from the template's own placeholders.
    public var rebuilt: [Int] = []

    /// Slides left exactly as they were, with the reason.
    ///
    /// A slide carrying a chart, a table or a picture the layout has nowhere
    /// to put cannot be rebuilt without losing something, and losing content
    /// is worse than staying off-brand.
    public var leftAlone: [(slide: Int, why: String)] = []

    public var changed: Bool { !rebuilt.isEmpty }

    public static func == (a: RecomposeReport, b: RecomposeReport) -> Bool {
        a.rebuilt == b.rebuilt && a.leftAlone.map(\.slide) == b.leftAlone.map(\.slide)
            && a.leftAlone.map(\.why) == b.leftAlone.map(\.why)
    }
}

extension Presentation {
    /// Rebuild each slide on the layout it now uses, moving its words into that
    /// layout's placeholders.
    ///
    /// `applyTemplate` adopts a template's theme and points each slide at one
    /// of its layouts, but a slide assembled from freeform boxes keeps drawing
    /// its own text at its own coordinates — on top of whatever the layout puts
    /// there. Against a real designer template that is not a rebrand, it is a
    /// collision: the template's photo panel lands over the deck's headline and
    /// the deck's full-bleed background hides the template underneath.
    ///
    /// Rebuilding removes the old boxes and puts the text in the placeholders
    /// the template designed for it, so the type, position and artwork are the
    /// template's. That is the whole point of applying one.
    ///
    /// Only slides that can be rebuilt *without losing anything* are touched —
    /// see `RecomposeReport.leftAlone`.
    @discardableResult
    public func recomposeOntoLayouts() throws -> RecomposeReport {
        var report = RecomposeReport()
        let area = Double(slideSize.width.rawValue) * Double(slideSize.height.rawValue)
        let height = Double(slideSize.height.rawValue)

        for index in 0..<slides.count {
            let slide = try slides.slide(at: index)
            guard let layout = slide.layout else {
                report.leftAlone.append((index, "no layout"))
                continue
            }
            let offered = Set(layout.placeholders.compactMap { $0.placeholder?.type })

            switch Self.content(of: slide, slideArea: area, slideHeight: height,
                                layoutOffers: offered) {
            case .failure(let why):
                report.leftAlone.append((index, why))
            case .success(let content):
                try rebuild(slide, from: content, on: layout)
                report.rebuilt.append(index)
            }
        }
        return report
    }

    /// Either the words and pictures a slide is made of, or why it cannot be
    /// rebuilt without losing some of them.
    private enum Either {
        case success(SlideContent)
        case failure(String)
    }

    /// The words and pictures a slide is actually made of.
    private struct SlideContent {
        var headline: String
        var body: [String]
        /// Pictures that are not full-bleed decoration, with the placeholder
        /// index they will be dropped into.
        var pictures: [XML.Element]
    }

    private static func content(of slide: Slide, slideArea: Double, slideHeight: Double,
                                layoutOffers offered: Set<String>) -> Either {
        var texts: [(size: Double, paragraphs: [String])] = []
        var pictures: [XML.Element] = []

        for shape in slide.shapes.all {
            switch shape.kind {
            case .table, .chart, .diagram, .graphicFrame:
                // A table, chart or diagram has no counterpart in a text
                // placeholder, and these are distinct ShapeKind cases — matching
                // only the generic `.graphicFrame` silently destroyed them.
                return .failure("carries a table, chart or diagram")
            case .group:
                // A group can hold anything, including the above.
                return .failure("carries a group")
            case .picture:
                // A picture covering the slide is the deck's own backdrop, and
                // the template brings its own; anything smaller is content.
                let frame = slide.effectiveFrame(of: shape)
                let covers = frame.map {
                    Double($0.width.rawValue) * Double($0.height.rawValue) / slideArea
                } ?? 0
                if covers < 0.85 { pictures.append(shape.element) }
            default:
                break
            }
            guard let frame = shape.textFrame else { continue }
            // A running footer or a slide number is furniture, not content, and
            // the template supplies its own — sweeping it into the body is how
            // "PaperBanana: Automating Academic Illustration for AI Scientists"
            // ends up as the last bullet on every slide.
            if let box = slide.effectiveFrame(of: shape), slideHeight > 0,
               Double(box.y.rawValue) / slideHeight > 0.86 { continue }
            let paragraphs = frame.paragraphs
                .map { $0.runs.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !paragraphs.isEmpty else { continue }
            let size = frame.paragraphs.flatMap(\.runs).compactMap(\.fontSize).max() ?? 18
            texts.append((size, paragraphs))
        }

        guard !texts.isEmpty else { return .failure("no text to place") }
        if !pictures.isEmpty && !offered.contains("pic") {
            return .failure("has a picture the layout cannot hold")
        }
        if pictures.count > 1 { return .failure("has more pictures than the layout can hold") }

        // The headline is the largest type on the slide; everything else, in
        // reading order, is the body.
        let headlineIndex = texts.indices.max {
            (texts[$0].size, texts[$0].paragraphs.count) < (texts[$1].size, texts[$1].paragraphs.count)
        }!
        let headline = texts[headlineIndex].paragraphs.joined(separator: " ")
        guard offered.contains(where: { $0 == "title" || $0 == "ctrTitle" }) else {
            return .failure("layout has nowhere to put a title")
        }
        var body = texts.enumerated().filter { $0.offset != headlineIndex }.flatMap(\.element.paragraphs)
        if body.isEmpty == false,
           !offered.contains(where: { ["body", "subTitle", "obj"].contains($0) }) {
            // Nowhere for the supporting words — dropping them would lose
            // content, so leave the whole slide alone.
            return .failure("layout has nowhere to put the body")
        }
        if body.count > 12 { body = Array(body.prefix(12)) }
        return .success(SlideContent(headline: headline, body: body, pictures: pictures))
    }

    /// Replace the slide's shapes with the layout's placeholders, filled.
    private func rebuild(_ slide: Slide, from content: SlideContent, on layout: SlideLayout) throws {
        let tree = try Slide.spTree(of: slide.part)
        // Everything after the group's own non-visual properties is the old
        // deck's composition, and it is exactly what must not survive.
        for child in tree.childElements
        where !["p:nvGrpSpPr", "p:grpSpPr"].contains(child.name) {
            tree.removeChild(child)
        }
        // A background the deck painted would hide the template's. Dropping it
        // is safe precisely here and nowhere else: every shape that was drawn
        // for that background has just been removed, and the text is about to
        // be placed in the template's own placeholders, which carry the text
        // colour the template's background expects. A slide that is *not*
        // rebuilt keeps both, which is why the polarity guard in
        // `applyTemplate` leaves those alone.
        if let cSld = try slide.part.dom().firstChild(named: "p:cSld"),
           let bg = cSld.firstChild(named: "p:bg") {
            cSld.removeChild(bg)
        }
        slide.part.markDirty()

        try Placeholders.clone(from: layout.part, to: slide.part)

        if let title = slide.placeholders.first(where: {
            $0.placeholder.map { ["title", "ctrTitle"].contains($0.type) } ?? false
        }), let frame = title.textFrame {
            frame.clear()
            _ = frame.addParagraph().addRun(content.headline)
        }

        if !content.body.isEmpty, let body = slide.placeholders.first(where: {
            $0.placeholder.map { ["body", "subTitle", "obj"].contains($0.type) } ?? false
        }), let frame = body.textFrame {
            frame.clear()
            for line in content.body { _ = frame.addParagraph().addRun(line) }
        }

        if let picture = content.pictures.first,
           let slot = slide.placeholders.first(where: { $0.placeholder?.type == "pic" }) {
            // Keep the picture's own fill, take the placeholder's identity, so
            // it lands where the template wants a picture.
            if let blipFill = picture.firstChild(named: "p:blipFill"),
               let spPr = slot.element.firstChild(named: "p:spPr") {
                spPr.insertChild(blipFill, beforeAnyOf: ["a:ln", "a:effectLst", "a:extLst"])
            }
        }
        slide.part.markDirty()
    }
}
