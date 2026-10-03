import Foundation

/// What a slide's ground actually is, once inheritance has been followed.
///
/// PowerPoint resolves a background by walking slide → layout → master and
/// taking the first `p:bg` it finds. Almost nothing about a real deck's
/// appearance is where a naive reader looks for it: the theme's `lt1` is
/// usually the untouched Office `FFFFFF`, the slide usually carries no `p:bg`
/// at all, and the deck's actual near-black ground is sitting on a *layout*
/// as `<a:schemeClr val="tx1">` that only means near-black after the master's
/// `clrMap` has been applied to it.
///
/// So "what colour is this slide" cannot be answered by reading one element,
/// and code that tries gets white for decks that are emphatically not white.
public enum SlideBackground: Equatable, Sendable {
    /// A flat colour — the case a caller can paint with.
    case solid(Color)

    /// A gradient, reduced to its first stop. An approximation, and named as
    /// one so a caller can decide whether that is good enough.
    case gradient(Color)

    /// A picture fill. There is no single colour, and inventing one would be
    /// worse than admitting it.
    case picture

    /// Nothing anywhere in the chain sets a background.
    case none

    /// The one colour to paint with, when there is one.
    public var color: Color? {
        switch self {
        case .solid(let colour), .gradient(let colour): colour
        case .picture, .none: nil
        }
    }
}

/// The slide → layout → master walk, in one place.
///
/// Extracted so the SVG renderer and the public background API cannot drift
/// apart. They previously could not disagree only because one of them did not
/// exist; now that a caller can ask the same question the renderer asks, they
/// have to be the same code.
enum BackgroundResolver {
    /// The first background in the chain, in PowerPoint's own resolution order.
    ///
    /// `parts` is the chain, nearest first. `theme` resolves `a:schemeClr`
    /// through the master's colour map, which is what turns `tx1` into the
    /// deck's near-black rather than into a literal.
    static func resolve(chain parts: [Part], theme: Theme) -> SlideBackground {
        for part in parts {
            guard let bg = (try? part.dom())?
                .firstChild(named: "p:cSld")?
                .firstChild(named: "p:bg") else { continue }

            if let bgPr = bg.firstChild(named: "p:bgPr") {
                if bgPr.firstChild(named: "a:blipFill") != nil { return .picture }
                if let solid = bgPr.firstChild(named: "a:solidFill"),
                   let colour = colour(in: solid, theme: theme) {
                    return .solid(colour)
                }
                if let gradient = bgPr.firstChild(named: "a:gradFill"),
                   let first = gradient.firstChild(named: "a:gsLst")?
                       .children(named: "a:gs").first,
                   let colour = colour(in: first, theme: theme) {
                    return .gradient(colour)
                }
                // A `p:bgPr` that resolves to nothing usable is still an answer:
                // this part sets the background, so the chain stops here rather
                // than reporting something further up that PowerPoint would
                // never draw.
                if bgPr.firstChild(named: "a:noFill") != nil { return .none }
            }

            // `p:bgRef` names a fill in the theme's `bgFillStyleLst`; its own
            // colour child is what that fill is built from, which is far closer
            // than white and is what the SVG renderer has always used.
            if let bgRef = bg.firstChild(named: "p:bgRef"),
               let colour = colour(in: bgRef, theme: theme) {
                return .solid(colour)
            }
        }
        return .none
    }

    /// A DrawingML colour child, resolved. `a:schemeClr` goes through the
    /// theme so the master's `clrMap` is honoured — without that, `tx1` on a
    /// dark template reads as the Office black rather than the deck's own.
    static func colour(in container: XML.Element, theme: Theme) -> Color? {
        if let srgb = container.firstChild(named: "a:srgbClr")?[attribute: "val"] {
            return Color(validating: srgb)
        }
        if let raw = container.firstChild(named: "a:schemeClr")?[attribute: "val"],
           let scheme = SchemeColor(rawValue: raw) {
            return theme.resolve(scheme)
        }
        if let sys = container.firstChild(named: "a:sysClr")?[attribute: "lastClr"] {
            return Color(validating: sys)
        }
        return nil
    }
}

// MARK: - The public questions

public extension Slide {
    /// The background this slide actually shows, following inheritance.
    ///
    /// Unlike `solidBackground`, which answers only "does this slide set one
    /// itself", this answers "what will the audience see" — which is the
    /// question anyone drawing a slide, or matching one, is really asking.
    ///
    /// Most decks put their look on a layout or the master, so
    /// `solidBackground` is nil for them and this is not.
    var effectiveBackground: SlideBackground {
        BackgroundResolver.resolve(chain: inheritanceParts, theme: resolvedTheme)
    }

    /// `effectiveBackground` reduced to a colour, when it is one.
    var effectiveBackgroundColor: Color? { effectiveBackground.color }

    /// Slide, then its layout, then that layout's master.
    internal var inheritanceParts: [Part] {
        var chain = [part]
        guard let layoutRel = part.rels.first(ofType: RelType.slideLayout),
              let layout = try? package.part(
                at: PackURI.resolve(target: layoutRel.target, relativeTo: part.uri.baseURI))
        else { return chain }
        chain.append(layout)

        guard let masterRel = layout.rels.first(ofType: RelType.slideMaster),
              let master = try? package.part(
                at: PackURI.resolve(target: masterRel.target, relativeTo: layout.uri.baseURI))
        else { return chain }
        chain.append(master)
        return chain
    }

    /// The theme reached through this slide's own master, falling back to the
    /// package's first theme part. Needed because `a:schemeClr` means nothing
    /// without the `clrMap` of the master it is being read under.
    internal var resolvedTheme: Theme {
        let master = inheritanceParts.count > 2 ? inheritanceParts[2] : nil
        let themePart: Part? = {
            if let master, let rel = master.rels.first(ofType: RelType.theme) {
                return try? package.part(
                    at: PackURI.resolve(target: rel.target, relativeTo: master.uri.baseURI))
            }
            return package.parts[PackURI("/ppt/theme/theme1.xml")]
        }()
        return Theme(part: themePart ?? part, master: master)
    }
}

public extension SlideLayout {
    /// The background this layout paints, following inheritance to its master.
    ///
    /// The companion to `Slide.effectiveBackground`, and needed for the same
    /// reason from the other end: before binding a new slide to a layout, a
    /// caller has to know whether that layout is *representative* of the deck.
    /// Many decks paint their look on every slide while the layouts and theme
    /// stay at the Office defaults, and a slide bound to one of those comes out
    /// white in a deck that is emphatically not.
    var effectiveBackground: SlideBackground {
        BackgroundResolver.resolve(chain: inheritanceParts, theme: resolvedTheme)
    }

    var effectiveBackgroundColor: Color? { effectiveBackground.color }

    /// The layout, then its master.
    internal var inheritanceParts: [Part] {
        var chain = [part]
        if let rel = part.rels.first(ofType: RelType.slideMaster),
           let master = try? package.part(
            at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)) {
            chain.append(master)
        }
        return chain
    }

    internal var resolvedTheme: Theme {
        let master = inheritanceParts.count > 1 ? inheritanceParts[1] : nil
        let themePart: Part? = {
            if let master, let rel = master.rels.first(ofType: RelType.theme) {
                return try? package.part(
                    at: PackURI.resolve(target: rel.target, relativeTo: master.uri.baseURI))
            }
            return package.parts[PackURI("/ppt/theme/theme1.xml")]
        }()
        return Theme(part: themePart ?? part, master: master)
    }
}

public extension Presentation {
    /// The ground this deck mostly paints on.
    ///
    /// For "a new slide is being added to this deck, what should it look
    /// like?" — where there is no slide to inherit from, so the honest answer
    /// is whatever its neighbours do.
    ///
    /// The mode rather than the first slide's: a title slide is very often the
    /// one slide that breaks the pattern, and taking it would dress every added
    /// slide as a title. Nil when no colour reaches a majority, which is the
    /// deck telling you it has no single ground and that a caller should fall
    /// back to the theme.
    var prevailingBackground: Color? {
        var tally: [Color: Int] = [:]
        var counted = 0
        for index in 0..<slides.count {
            guard let slide = try? slides[index] else { continue }
            counted += 1
            if let colour = slide.effectiveBackgroundColor { tally[colour, default: 0] += 1 }
        }
        guard counted > 0, let (colour, hits) = tally.max(by: { $0.value < $1.value }),
              Double(hits) / Double(counted) > 0.5 else { return nil }
        return colour
    }
}
