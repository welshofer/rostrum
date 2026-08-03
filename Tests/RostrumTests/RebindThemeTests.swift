import Foundation
import Testing
@testable import Rostrum

/// Rebinding direct formatting back to the theme — the half of a rebrand that
/// makes the other half visible.
@Suite struct RebindThemeTests {
    /// A deck shaped the way PowerPoint writes one: the author picked a theme
    /// colour and font from the palette, and it landed on the run as a
    /// literal.
    private func deckWithLiteralThemeFormatting() throws -> (Presentation, Color, String) {
        let deck = try Presentation()
        let accent = try #require(deck.theme.color(.accent1))
        let body = try #require(deck.theme.minorFont)
        let slide = try deck.slides.add()
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(2)))
        let frame = try #require(box.textFrame)
        frame.text = "Quarterly results"
        let run = frame.paragraphs[0].runs[0]
        run.color = accent
        run.fontName = body
        return (deck, accent, body)
    }

    /// Every colour reference on the deck's slides, as "literal HEX" or
    /// "scheme token".
    private func slideColors(_ deck: Presentation) -> [String] {
        var found: [String] = []
        for index in 0..<deck.slides.count {
            guard let dom = try? deck.slides.slide(at: index).part.dom() else { continue }
            var stack = [dom]
            while let element = stack.popLast() {
                if element.name == "a:srgbClr", let value = element[attribute: "val"] {
                    found.append("literal \(value.uppercased())")
                }
                if element.name == "a:schemeClr", let value = element[attribute: "val"] {
                    found.append("scheme \(value)")
                }
                stack.append(contentsOf: element.childElements)
            }
        }
        return found
    }

    private func slideTypefaces(_ deck: Presentation) -> [String] {
        var found: [String] = []
        for index in 0..<deck.slides.count {
            guard let dom = try? deck.slides.slide(at: index).part.dom() else { continue }
            var stack = [dom]
            while let element = stack.popLast() {
                if ["a:latin", "a:ea", "a:cs"].contains(element.name),
                   let face = element[attribute: "typeface"] { found.append(face) }
                stack.append(contentsOf: element.childElements)
            }
        }
        return found
    }

    @Test func aLiteralThatCameFromTheThemeBecomesAReference() throws {
        let (deck, accent, body) = try deckWithLiteralThemeFormatting()
        #expect(slideColors(deck).contains("literal \(accent.hex.uppercased())"))

        let report = try deck.rebindDirectFormattingToTheme()

        #expect(report.colors == 1)
        #expect(report.fonts == 1)
        #expect(report.slides == 1)
        #expect(slideColors(deck).contains("scheme accent1"))
        #expect(!slideColors(deck).contains("literal \(accent.hex.uppercased())"))
        #expect(slideTypefaces(deck).contains("+mn-lt"))
        #expect(!slideTypefaces(deck).contains(body))
    }

    /// The conservative half of the bargain: a colour the designer chose that
    /// is not in the palette is genuinely theirs, and is left alone.
    @Test func aColourThatIsNotInThePaletteIsLeftAlone() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add()
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1)))
        let frame = try #require(box.textFrame)
        frame.text = "Brand red"
        // Not in the default palette, and deliberately nothing like it.
        frame.paragraphs[0].runs[0].color = Color("C4122F")

        let report = try deck.rebindDirectFormattingToTheme()

        #expect(report.colors == 0)
        #expect(slideColors(deck).contains("literal C4122F"))
    }

    /// A tint or alpha on a colour is a child of it. Renaming the element must
    /// keep those, or the rebind silently drops formatting.
    @Test func colourTransformsSurviveTheRebind() throws {
        let deck = try Presentation()
        let accent = try #require(deck.theme.color(.accent1))
        let slide = try deck.slides.add()
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1)))
        let frame = try #require(box.textFrame)
        frame.text = "Tinted"
        frame.paragraphs[0].runs[0].color = accent

        // Hang a tint on the literal, as a real deck would.
        let dom = try deck.slides.slide(at: 1).part.dom()
        var stack = [dom]
        var tinted = false
        while let element = stack.popLast() {
            if element.name == "a:srgbClr" {
                element.appendElement(XML.Element("a:lumMod", attributes: [("val", "60000")]))
                tinted = true
                break
            }
            stack.append(contentsOf: element.childElements)
        }
        #expect(tinted)
        try deck.slides.slide(at: 1).part.markDirty()

        _ = try deck.rebindDirectFormattingToTheme()

        let dom2 = try deck.slides.slide(at: 1).part.dom()
        var stack2 = [dom2]
        var keptTransform = false
        while let element = stack2.popLast() {
            if element.name == "a:schemeClr", element.firstChild(named: "a:lumMod") != nil {
                keptTransform = true
            }
            stack2.append(contentsOf: element.childElements)
        }
        #expect(keptTransform, "the tint was dropped when the colour was rebound")
    }

    /// Idempotent: once everything that came from the theme is a reference,
    /// there is nothing left to rebind.
    ///
    /// Worth pinning because Rostrum's own builders write literals — a deck
    /// from `titleSlide` carries the palette's black, white and accent1 as
    /// hard-coded values, so a Lectern-generated deck is exactly the kind this
    /// pass is for.
    @Test func rebindingTwiceChangesNothingTheSecondTime() throws {
        let deck = try Presentation()
        try deck.titleSlide("Built by Rostrum", subtitle: "with literal colours")

        let first = try deck.rebindDirectFormattingToTheme()
        #expect(first.changed, "the builders write literals; there should be work to do")
        let after = slideColors(deck)

        let second = try deck.rebindDirectFormattingToTheme()
        #expect(!second.changed)
        #expect(slideColors(deck) == after)
    }

    /// A colour that is not a theme colour survives any number of passes.
    @Test func aDeckWithNoThemeColoursOnItsSlidesIsUntouched() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add()
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1)))
        let frame = try #require(box.textFrame)
        frame.text = "Off-palette"
        frame.paragraphs[0].runs[0].color = Color("C4122F")
        let before = slideColors(deck)

        let report = try deck.rebindDirectFormattingToTheme()

        #expect(!report.changed)
        #expect(slideColors(deck) == before)
    }

    /// The end this exists for: with rebinding, the template's brand reaches
    /// text that was hard-coded; without it, the text stays frozen.
    @Test func rebindingIsWhatLetsANewTemplateReachHardCodedText() throws {
        let template = try Presentation()
        template.theme.setColor(.accent1, Color("0078D4"))

        let (source, oldAccent, _) = try deckWithLiteralThemeFormatting()
        let bytes = try source.serializedData()

        let plain = try Presentation(data: bytes)
        _ = try plain.applyTemplate(from: template)
        #expect(slideColors(plain).contains("literal \(oldAccent.hex.uppercased())"),
                "without rebinding the literal should survive untouched")

        let rebound = try Presentation(data: bytes)
        let report = try rebound.applyTemplate(from: template, rebindingDirectFormatting: true)
        #expect(report.rebind.colors == 1)
        #expect(slideColors(rebound).contains("scheme accent1"))
        #expect(!slideColors(rebound).contains("literal \(oldAccent.hex.uppercased())"),
                "the literal should now be a reference following the new brand")
    }

    /// Rebinding must not disturb the file's other promises.
    @Test func aReboundDeckStillOpensAndLintsClean() throws {
        let (deck, _, _) = try deckWithLiteralThemeFormatting()
        _ = try deck.rebindDirectFormattingToTheme()
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides.count == deck.slides.count)
        #expect(try reopened.validate().isEmpty)
    }
}
