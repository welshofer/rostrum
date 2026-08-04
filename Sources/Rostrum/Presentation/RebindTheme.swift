import Foundation

/// What rebinding direct formatting to the theme changed.
public struct RebindReport: Sendable, Equatable {
    /// Literal colours replaced by a scheme reference.
    public var colors: Int = 0
    /// Typefaces replaced by the major/minor theme font reference.
    public var fonts: Int = 0
    /// Slides that changed at all.
    public var slides: Int = 0

    public var changed: Bool { colors > 0 || fonts > 0 }
}

extension Presentation {
    /// Rebind direct formatting that matches this deck's theme back to theme
    /// references, so a later theme change actually shows.
    ///
    /// This is the half of rebranding that makes the other half visible. A
    /// deck looks off-brand because it says `<a:srgbClr val="1F4E79"/>` and
    /// `typeface="Calibri"` on the shapes themselves, and direct formatting
    /// beats the theme — so dropping a new theme underneath changes nothing a
    /// user can see. It is exactly why "apply a template" in PowerPoint
    /// disappoints and finishes as an hour of manual recolouring.
    ///
    /// Only values that **provably came from the theme** are touched: a colour
    /// is rebound when it equals one of the twelve scheme colours exactly, and
    /// a typeface when it equals the major or minor font exactly. A colour the
    /// designer chose that is not in the palette is genuinely custom and is
    /// left alone. So the operation is a no-op on a deck that was already
    /// following its theme, and reversible in the sense that matters: the
    /// pixels do not move.
    ///
    /// **Order matters.** Run this *before* adopting a new theme, against the
    /// theme the deck currently has — that is the palette its literals came
    /// from. `applyTemplate(from:rebindingDirectFormatting:)` sequences it for
    /// you, which is the safer way to ask for it.
    ///
    /// Slides only. Masters, layouts and the theme part are either the
    /// template's already or about to be replaced, and rewriting a master's
    /// own colour definitions would be circular.
    ///
    /// One thing to know before turning it on: `dk1`/`lt1` are usually black
    /// and white, so most hard-coded black text in a deck rebinds to `tx1`.
    /// That is the point — it is what makes text follow a dark template — but
    /// it is also the change most likely to surprise, because anything drawn
    /// black on purpose will follow too.
    @discardableResult
    public func rebindDirectFormattingToTheme() throws -> RebindReport {
        try rebindDirectFormattingToTheme(includingNeutrals: true)
    }

    /// - Parameter includingNeutrals: when false, the `dk1`/`lt1`/`dk2`/`lt2`
    ///   slots are left as literals and only the accents and fonts rebind.
    ///
    ///   A caller that is about to swap this deck's theme for one of the
    ///   opposite polarity must pass false. A dark deck inverts the neutral
    ///   slots — Lectern's dark style writes `dk1=FFFFFF, lt1=000000` — so its
    ///   black backgrounds rebind to `bg1` and its white text to `tx1`, and
    ///   under a normally polarised template both flip: the deck turns white
    ///   and the text turns black. Every literal that did not match a theme
    ///   colour stays where it was, so a dark card keeps its dark fill and the
    ///   now-black text on it becomes unreadable.
    func rebindDirectFormattingToTheme(includingNeutrals: Bool) throws -> RebindReport {
        var report = RebindReport()

        // hex → the scheme token to write. Built from this deck's own theme,
        // routed back through the master's clrMap so the token written means
        // the slot intended even when the map is not the identity.
        var colorToken: [String: String] = [:]
        for slot in ThemeSlot.allCases {
            if !includingNeutrals, [.dk1, .lt1, .dk2, .lt2].contains(slot) { continue }
            guard let color = theme.color(slot) else { continue }
            let key = color.hex.uppercased()
            // First slot wins, and `ThemeSlot.allCases` puts dk1/lt1 before the
            // accents, so a palette that repeats a value prefers the
            // text/background reading over an accent one.
            if colorToken[key] == nil { colorToken[key] = schemeToken(for: slot) }
        }

        var fontToken: [String: String] = [:]
        if let major = theme.majorFont, !major.isEmpty { fontToken[major] = "+mj-lt" }
        if let minor = theme.minorFont, !minor.isEmpty, fontToken[minor] == nil {
            fontToken[minor] = "+mn-lt"
        }

        guard !colorToken.isEmpty || !fontToken.isEmpty else { return report }

        for index in 0..<slides.count {
            let slide = try slides.slide(at: index)
            guard let dom = try? slide.part.dom() else { continue }
            var colors = 0, fonts = 0

            var stack: [XML.Element] = [dom]
            while let element = stack.popLast() {
                switch element.name {
                case "a:srgbClr":
                    // The value is file-supplied, so it may be anything.
                    if let value = element[attribute: "val"]?.uppercased(),
                       let token = colorToken[value] {
                        // Rename in place and keep the children: a tint, shade
                        // or alpha on this colour still applies, now to the
                        // theme's value instead of a frozen one.
                        element.name = "a:schemeClr"
                        element[attribute: "val"] = token
                        colors += 1
                    }
                case "a:latin", "a:ea", "a:cs":
                    if let face = element[attribute: "typeface"], let token = fontToken[face] {
                        element[attribute: "typeface"] = token
                        fonts += 1
                    }
                default:
                    break
                }
                stack.append(contentsOf: element.childElements)
            }

            if colors > 0 || fonts > 0 {
                slide.part.markDirty()
                report.colors += colors
                report.fonts += fonts
                report.slides += 1
            }
        }
        return report
    }

    /// The scheme token a slide should use to name `slot`.
    ///
    /// Slides speak in `tx1`/`bg1`/`accent1`, which the master's `p:clrMap`
    /// routes to theme slots — and the map is not always the identity: an
    /// inverted master swaps `tx1` and `bg1`. Inverting the map here means the
    /// token written resolves to the slot intended rather than to whatever
    /// that name usually means.
    private func schemeToken(for slot: ThemeSlot) -> String {
        let master = try? presentationPart.related(by: RelType.slideMaster, in: package)
        if let clrMap = try? master?.dom().firstChild(named: "p:clrMap") {
            for candidate in ["tx1", "bg1", "tx2", "bg2",
                              "accent1", "accent2", "accent3", "accent4", "accent5", "accent6",
                              "hlink", "folHlink"]
            where clrMap[attribute: candidate] == slot.rawValue {
                return candidate
            }
        }
        // No master or no map: the conventional names, which are the identity
        // for accents and the usual pairing for text and background.
        switch slot {
        case .dk1: return "tx1"
        case .lt1: return "bg1"
        case .dk2: return "tx2"
        case .lt2: return "bg2"
        default: return slot.rawValue
        }
    }
}
