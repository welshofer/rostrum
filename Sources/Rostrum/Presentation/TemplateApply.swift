import Foundation

/// What applying a template did, slide by slide.
///
/// Rebranding is a heuristic — a deck's layouts and a template's layouts are
/// two people's idea of the same thing — so the operation reports what it
/// matched and what it left alone rather than claiming a clean sweep.
public struct TemplateReport: Sendable, Equatable {
    /// How a slide's new layout was chosen, strongest first.
    public enum Match: String, Sendable, Equatable {
        /// The layouts offer the same placeholders. This is the match to
        /// trust: it is written in the schema's own vocabulary, so it means
        /// the same thing whoever produced the file, and it is the property
        /// that decides whether the slide's content lands in the right boxes.
        ///
        /// Measured on this project's real-deck corpus — a PowerPoint deck, a
        /// Keynote export and a Google Slides export against a real corporate
        /// `.potx` — signature matching re-lays 17 of 23 slides where `type`
        /// and `name` together match none.
        case signature
        /// The `p:sldLayout@type` tokens matched ("title", "secHead", "obj").
        /// Reliable between two PowerPoint decks; absent from most designer
        /// templates and from every Google Slides export.
        case type
        /// The layout names matched, case- and whitespace-insensitively.
        /// The weakest signal, and the only one a `cust` layout carries.
        case name
        /// No exact counterpart existed, so the closest layout the template
        /// does offer was chosen — scored on how many of the placeholder roles
        /// the slide needs it can serve, with `ctrTitle` counted as a title and
        /// `obj`/`tbl`/`chart` counted as a body.
        ///
        /// This is what makes a real designer template usable. Such templates
        /// routinely omit `@type`, suffix their layout names ("Section Header
        /// 1", not "Section Header") and offer a title-only section layout
        /// where the source deck had title+body — so all three exact signals
        /// miss, and without this the slide keeps its old layout and adopts
        /// nothing.
        case nearest
    }

    public struct Relaid: Sendable, Equatable {
        public var slide: Int
        public var from: String
        public var to: String
        public var by: Match
    }

    /// Slides now using one of the template's layouts.
    public var relaid: [Relaid] = []

    /// Slides whose layout had no counterpart in the template, left exactly as
    /// they were, with the index and the layout they kept.
    ///
    /// Dropping these onto a generic layout would be how a rebrand mangles a
    /// deck: the text would land in the wrong placeholders, or in none. Better
    /// to leave the slide correct and off-brand, and say so.
    public var kept: [(slide: Int, layout: String)] = []

    /// Masters adopted from the template.
    public var mastersAdopted: Int = 0

    /// Slides that gave up their own flat background so the template's shows.
    ///
    /// This is the difference between a rebrand you can see and one you cannot.
    /// A deck that paints every slide a solid colour hides whatever the
    /// template's layouts put behind them — adopt a brand whose section layout
    /// is a solid orange field and, with the deck's own fill still on top, the
    /// result is the original deck in a slightly different colour.
    public var backgroundsAdopted: Int = 0

    /// What rebinding direct formatting changed, when it was asked for.
    public var rebind: RebindReport = RebindReport()

    /// The deck's original masters, which stay in the package.
    ///
    /// They are not removed even when nothing references them any more, for
    /// two reasons: any slide in `kept` still needs its own master, and
    /// `OPCPackage` serializes a stored content-type map, so dropping a part
    /// would leave an Override pointing at nothing. Removing dead masters is a
    /// separate piece of work that needs part removal to clean up after
    /// itself.
    public var mastersKept: Int = 0

    /// Whether anything at all changed.
    public var changed: Bool { !relaid.isEmpty || mastersAdopted > 0 }

    public static func == (a: TemplateReport, b: TemplateReport) -> Bool {
        a.relaid == b.relaid && a.mastersAdopted == b.mastersAdopted
            && a.mastersKept == b.mastersKept
            && a.kept.map(\.slide) == b.kept.map(\.slide)
            && a.kept.map(\.layout) == b.kept.map(\.layout)
    }
}

extension Presentation {
    /// Adopt `template`'s masters, layouts and theme, and re-point this deck's
    /// slides at the matching layouts.
    ///
    /// This is the operation PowerPoint does badly. Its own "change template"
    /// leaves a deck's direct formatting — hard-coded fills, explicit fonts —
    /// sitting on top of the new theme, so the deck barely changes and the
    /// user finishes the job by hand. Rostrum does the structural half
    /// correctly and reports the rest; stripping direct formatting back to
    /// theme references is a separate pass, and deliberately not smuggled in
    /// here, because it rewrites slide content and this does not.
    ///
    /// What this does change: the package gains the template's masters,
    /// layouts and theme; the template's first master becomes the deck's
    /// primary one, so `theme` and `layouts` answer from it; and every slide
    /// whose layout has a counterpart is re-pointed at it. Slide *content* is
    /// untouched — same shapes, same text, same order.
    ///
    /// `.potx`, `.pptx` and `.ppsx` all work as the template: what is read are
    /// its masters, and every kind has them.
    ///
    /// - Parameter rebindingDirectFormatting: when true, rebind the deck's
    ///   hard-coded colours and fonts to theme references *before* the new
    ///   theme lands, so the new brand actually shows. Off by default, because
    ///   it rewrites slide content and the rest of this operation does not —
    ///   see `rebindDirectFormattingToTheme()` for what it does and does not
    ///   touch. Sequenced here because the rebind has to read the *old* theme,
    ///   which is the one thing easy to get wrong when calling both by hand.
    /// - Returns: what matched, and what was left alone.
    @discardableResult
    public func applyTemplate(from template: Presentation,
                              rebindingDirectFormatting: Bool = false) throws -> TemplateReport {
        var report = TemplateReport()

        // Before anything is adopted: the deck's literals came from the theme
        // it has now, so that is the palette they have to be matched against.
        if rebindingDirectFormatting {
            report.rebind = try rebindDirectFormattingToTheme()
        }

        let templateMasters = template.slideMasters
        guard !templateMasters.isEmpty else {
            throw RostrumError.packageInvalid("the template has no slide master to adopt")
        }

        // What each slide uses now, read before anything moves.
        let count = slides.count
        var currentLayout: [Int: SlideLayout] = [:]
        for index in 0..<count {
            let slide = try slides.slide(at: index)
            guard let part = try? slide.part.related(by: RelType.slideLayout, in: package) else { continue }
            currentLayout[index] = SlideLayout(part: part, package: package)
        }
        report.mastersKept = slideMasters.count

        // Copy the template's masters. The copier brings each one's whole
        // reachable graph — layouts, theme, images — deduping media by content
        // and renumbering the layout ids that would otherwise collide.
        let copier = SlideCopier(source: template.package, dest: package,
                                 destPresentation: presentationPart)
        for master in templateMasters {
            _ = try copier.copy(master.part.uri)
        }
        try slides.wireNewMasters(copier.newMasters, copier)
        report.mastersAdopted = copier.newMasters.count

        // Make the template's first master primary. Without this the deck
        // keeps answering `theme` and `layouts` from its old master, and the
        // rebrand is invisible: `related(by:)` takes the first relationship of
        // a type, and a newly added one is last.
        if let adopted = copier.newMasters.first {
            try makePrimaryMaster(adopted)
        }

        // Index the adopted layouts. Type first because it is the format's own
        // identity; name as the fallback, which is all a `cust` layout has.
        let adoptedLayouts = copier.newMasters
            .compactMap { try? package.part(at: $0) }
            .flatMap { SlideMaster(part: $0, package: package).layouts }
        var bySignature: [[String]: SlideLayout] = [:]
        var byType: [String: SlideLayout] = [:]
        var byName: [String: SlideLayout] = [:]
        for layout in adoptedLayouts {
            let signature = layout.placeholderSignature
            if bySignature[signature] == nil { bySignature[signature] = layout }
            if let type = layout.type, byType[type] == nil { byType[type] = layout }
            let key = Self.layoutKey(layout.name)
            if !key.isEmpty, byName[key] == nil { byName[key] = layout }
        }

        for index in 0..<count {
            guard let old = currentLayout[index] else { continue }
            let match: (SlideLayout, TemplateReport.Match)? = {
                if let hit = bySignature[old.placeholderSignature] { return (hit, .signature) }
                // "cust" is not an identity — every custom layout claims it —
                // so it must not match another deck's custom layout by type.
                if let type = old.type, type != "cust", let hit = byType[type] { return (hit, .type) }
                if let hit = byName[Self.layoutKey(old.name)] { return (hit, .name) }
                if let hit = Self.nearest(to: old, among: adoptedLayouts) { return (hit, .nearest) }
                return nil
            }()
            guard let (layout, by) = match else {
                report.kept.append((slide: index, layout: old.name))
                continue
            }
            try repoint(slideAt: index, to: layout)
            if try adoptBackground(slideAt: index, from: layout) {
                report.backgroundsAdopted += 1
            }
            report.relaid.append(.init(slide: index, from: old.name, to: layout.name, by: by))
        }

        presentationPart.markDirty()
        return report
    }

    /// Normalized layout name for matching: case- and space-insensitive, so
    /// "Title and Content" finds "Title And Content".
    private static func layoutKey(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace }
    }

    /// The placeholder role a type serves when re-laying. A template that
    /// offers `ctrTitle` where the deck had `title` is offering a title; one
    /// that offers `obj` where the deck had `body` is offering somewhere for
    /// the content to go. Matching on the raw tokens misses both.
    private static func role(of type: String) -> String {
        switch type {
        case "ctrTitle": "title"
        case "obj", "tbl", "chart", "dgm", "clipArt", "media": "body"
        default: type
        }
    }

    /// The template layout that best serves `old`'s placeholder roles.
    ///
    /// Scores each candidate on the roles it covers, penalises roles the slide
    /// needs that it lacks, and mildly penalises extra placeholders the slide
    /// will not fill — an unfilled slot is clutter, not a benefit. A name that
    /// extends the source's ("Section Header" → "Section Header 1") breaks
    /// ties, which is exactly how designer templates enumerate variants.
    /// Returns nil when nothing shares a single role, so an unrelated layout
    /// is never forced on a slide.
    private static func nearest(to old: SlideLayout, among candidates: [SlideLayout]) -> SlideLayout? {
        let wanted = Set(old.placeholderSignature.map(role(of:)))
        guard !wanted.isEmpty else { return nil }
        let oldKey = layoutKey(old.name)

        var best: (layout: SlideLayout, score: Int)?
        for candidate in candidates {
            let offered = Set(candidate.placeholderSignature.map(role(of:)))
            let covered = wanted.intersection(offered)
            guard !covered.isEmpty else { continue }

            var score = covered.count * 4
            score -= wanted.subtracting(offered).count * 2
            score -= offered.subtracting(wanted).count
            let key = layoutKey(candidate.name)
            // A name that extends the source's is the designer saying these are
            // variants of one idea, which outranks a layout that merely happens
            // to carry a spare body slot — without it a section divider lands
            // on "Agenda" because Agenda offers title+body and "Section Header
            // 1" offers only a title.
            if key.hasPrefix(oldKey) || oldKey.hasPrefix(key) { score += 8 }

            // Strictly greater keeps the first of equals, and layouts arrive in
            // sldLayoutIdLst order, so the choice is deterministic.
            if best == nil || score > best!.score { best = (candidate, score) }
        }
        return best.map(\.layout)
    }

    /// Let the template's background through on a slide that was painting its
    /// own flat colour over it.
    ///
    /// Only a plain `solidFill` is given up, and only when the adopted layout
    /// actually defines a background of its own. A picture or gradient the
    /// author put on a specific slide is content and is left alone; so is a
    /// slide whose new layout has nothing to show underneath, which would
    /// otherwise fall through to a master background that was never designed
    /// for it.
    ///
    /// Returns whether the slide gave one up.
    @discardableResult
    private func adoptBackground(slideAt index: Int, from layout: SlideLayout) throws -> Bool {
        guard let layoutBg = (try? layout.part.dom())?
            .firstChild(named: "p:cSld")?.firstChild(named: "p:bg"),
            !layoutBg.childElements.isEmpty
        else { return false }

        let slide = try slides.slide(at: index)
        guard let cSld = try slide.part.dom().firstChild(named: "p:cSld"),
              let bg = cSld.firstChild(named: "p:bg"),
              bg.firstChild(named: "p:bgPr")?.firstChild(named: "a:solidFill") != nil
        else { return false }

        cSld.removeChild(bg)
        slide.part.markDirty()
        return true
    }

    /// Point a slide's `slideLayout` relationship at `layout`, leaving the
    /// slide's own XML untouched — the relationship is the only thing that
    /// says which layout a slide uses.
    private func repoint(slideAt index: Int, to layout: SlideLayout) throws {
        let slide = try slides.slide(at: index)
        for rel in slide.part.rels.all(ofType: RelType.slideLayout) {
            slide.part.rels.remove(rId: rel.rId)
        }
        _ = slide.part.rels.add(type: RelType.slideLayout,
                                target: slide.part.uri.relativeReference(to: layout.part.uri))
        slide.part.markDirty()
    }

    /// Make `masterURI` the deck's primary master, in both orders that matter:
    /// `p:sldMasterIdLst` (what PresentationML calls first) and the
    /// relationship list (what `related(by:)` returns).
    private func makePrimaryMaster(_ masterURI: PackURI) throws {
        let dom = try presentationPart.dom()
        guard let list = dom.firstChild(named: "p:sldMasterIdLst") else { return }
        let entries = list.childElements
        guard let index = entries.firstIndex(where: { entry in
            guard let rId = entry[attribute: "r:id"],
                  let rel = presentationPart.rels.relationship(withId: rId) else { return false }
            return PackURI.resolve(target: rel.target,
                                   relativeTo: presentationPart.uri.baseURI) == masterURI
        }) else { return }

        if index != 0 {
            var reordered = entries
            let entry = reordered.remove(at: index)
            reordered.insert(entry, at: 0)
            list.replaceChildElements(with: reordered)
        }
        if let rId = entries[index][attribute: "r:id"] {
            presentationPart.rels.moveToFront(rId: rId)
        }
        presentationPart.markDirty()
    }
}
