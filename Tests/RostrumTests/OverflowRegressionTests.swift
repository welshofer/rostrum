import Foundation
import Testing
@testable import Rostrum

/// Regressions for the wrap/overprint class of bugs: PowerPoint renders bare
/// `normAutofit` text at full size until the box is edited, so every builder
/// must reserve real space for text that wraps — a wrapped title printed over
/// the cards below it, process captions ran off the slide, a long quote's
/// overflow landed on the attribution, and a callout caption crowded its stat.
@Suite struct OverflowRegressionTests {
    /// (x, y, cx, cy, text) for every shape on a slide, in document order.
    private func boxes(_ slide: Slide) throws -> [(x: Int, y: Int, cx: Int, cy: Int, text: String)] {
        let sld = try slide.part.dom()
        let spTree = sld.firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!
        func allText(_ e: XML.Element) -> String {
            e.name == "a:t" ? e.textContent : e.childElements.map(allText).joined()
        }
        return spTree.childElements.filter { $0.name == "p:sp" }.compactMap { sp in
            guard let xfrm = sp.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm"),
                  let off = xfrm.firstChild(named: "a:off"), let ext = xfrm.firstChild(named: "a:ext"),
                  let x = off[attribute: "x"].flatMap(Int.init), let y = off[attribute: "y"].flatMap(Int.init),
                  let cx = ext[attribute: "cx"].flatMap(Int.init), let cy = ext[attribute: "cy"].flatMap(Int.init)
            else { return nil }
            return (x, y, cx, cy, allText(sp))
        }
    }

    /// Every (fontSize-in-centipoints, lnSpc-percent-in-1/1000%) pair for runs in
    /// shapes whose text contains `needle`.
    private func runSpecs(_ slide: Slide, containing needle: String) throws -> [(sz: Int, lnSpc: Int?)] {
        let sld = try slide.part.dom()
        func descendants(_ e: XML.Element, named name: String) -> [XML.Element] {
            e.childElements.flatMap { c in
                (c.name == name ? [c] : []) + descendants(c, named: name)
            }
        }
        var out: [(Int, Int?)] = []
        for sp in descendants(sld, named: "p:sp") where sp.textContent.contains(needle) {
            for p in descendants(sp, named: "a:p") {
                let ln = p.firstChild(named: "a:pPr")?
                    .firstChild(named: "a:lnSpc")?
                    .firstChild(named: "a:spcPct")?[attribute: "val"].flatMap(Int.init)
                for r in descendants(p, named: "a:r") {
                    if let sz = r.firstChild(named: "a:rPr")?[attribute: "sz"].flatMap(Int.init) {
                        out.append((sz, ln))
                    }
                }
            }
        }
        return out
    }

    // MARK: Title band

    @Test func wrappedTitleStartsContentARowLower() throws {
        let deck = try Presentation()
        let short = try deck.comparisonSlide("Short title",
                                             leftHeader: "A", left: ["one"], rightHeader: "B", right: ["two"])
        let long = try deck.comparisonSlide(
            "Your move this quarter: build the habit, then show it",
            leftHeader: "Build the Habit",
            left: ["Delegate one real task to an agent daily",
                   "Keep a prompt-and-pattern notebook",
                   "Time-box verification — never skip it"],
            rightHeader: "Build the Career",
            right: ["Volunteer for agent-led pilots"])

        // The card (an empty-text rounded rect) must start lower when the title
        // wraps — the old fixed layout put a two-line title straight over it.
        //
        // Picked by area, not by document order: the title's hairline rule is
        // also an empty-text shape and is drawn first, so "the first box with
        // no text" stopped meaning "the card".
        func card(_ slide: Slide) throws -> (x: Int, y: Int, cx: Int, cy: Int, text: String)? {
            try boxes(slide).filter { $0.text.isEmpty }.max { $0.cx * $0.cy < $1.cx * $1.cy }
        }
        let shortCard = try #require(try card(short))
        let longCard = try #require(try card(long))
        #expect(longCard.y > shortCard.y)

        // And the long title is fitted below the full 40pt display size.
        let sizes = try runSpecs(long, containing: "Your move this quarter").map(\.sz)
        #expect(sizes.allSatisfy { $0 <= 3400 })
    }

    // MARK: Process captions

    @Test func processCaptionsAreFittedAndTightened() throws {
        let deck = try Presentation()
        let slide = try deck.processSlide(
            "Four moves separate frontier leaders from spectators",
            steps: ["Redesign — rebuild one workflow agent-first",
                    "Reskill — fund delegation and verification training",
                    "Reprice — measure outcomes per team, not hours",
                    "Reassure — state plainly what AI means for jobs"])
        let specs = try runSpecs(slide, containing: "Reskill")
        #expect(!specs.isEmpty)
        // Longest step is 51 chars → 20pt captions with leading capped at 120%.
        #expect(specs.allSatisfy { $0.sz <= 2000 })
        #expect(specs.allSatisfy { ($0.lnSpc ?? 100_000) <= 120_000 })
    }

    // MARK: Quote

    @Test func longQuoteIsFittedClearOfAttribution() throws {
        let deck = try Presentation()
        let quote = "Applying agents to yesterday's workflows is like wiring electric motors "
            + "into steam-era factory layouts — the gains arrive only when you redesign the floor."
        let slide = try deck.quoteSlide(quote, attribution: "Adapted from the report's electricity analogy")
        let specs = try runSpecs(slide, containing: "steam-era")
        #expect(specs.allSatisfy { $0.sz <= 3400 })   // fitted down from the 40pt quote size

        // Even with the estimated wrapped height (middle-anchored overflow grows
        // both ways), the quote's bottom stays above the attribution band.
        let all = try boxes(slide)
        let q = try #require(all.first { $0.text.contains("steam-era") })
        let attr = try #require(all.first { $0.text.contains("electricity analogy") })
        let sizePt = Double(specs.map(\.sz).max() ?? 0) / 100.0
        let charsPerLine = max(1.0, (Double(q.cx) / 12700.0) / (0.52 * sizePt))
        let lines = (Double(quote.count + 2) / charsPerLine).rounded(.up)
        let estHeight = lines * sizePt * 1.2 * 1.25 * 12700.0
        let overflow = max(0.0, estHeight - Double(q.cy)) / 2.0
        #expect(Double(q.y + q.cy) + overflow < Double(attr.y))
    }

    // MARK: Callout stat tile

    @Test func longCalloutCaptionStepsTheStatDownAndKeepsItsLastWordsTogether() throws {
        let deck = try Presentation()
        let slide = try deck.calloutSlide(
            stat: "~80%",
            caption: "of knowledge workers already use AI at work — most started before policy caught up",
            kicker: "Adoption already happened — from the bottom up")
        let statRuns = try runSpecs(slide, containing: "~80%")
        #expect(statRuns.map(\.sz).max().map { $0 <= 11_200 } == true)   // stepped down from 130pt

        // The widow guard glues the last two caption words with a no-break space.
        let sld = try slide.part.dom()
        #expect(sld.textContent.contains("caught\u{00A0}up"))
        #expect(!sld.textContent.contains("caught up"))
    }

    @Test func shortCalloutCaptionKeepsTheFullStatSize() throws {
        let deck = try Presentation()
        let slide = try deck.calloutSlide(stat: "10x", caption: "the leverage")
        let statRuns = try runSpecs(slide, containing: "10x")
        #expect(statRuns.map(\.sz).max() == 13_000)   // the full 130pt survives
    }
}
