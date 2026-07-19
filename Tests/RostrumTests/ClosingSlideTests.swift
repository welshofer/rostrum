import Foundation
import Testing
@testable import Rostrum

/// The dedicated closing layout (regression for the cramped/overlapping closing
/// that reused `sectionSlide`): a near-full-width title and a contact line in its
/// own band, structurally clear of the call to action.
@Suite struct ClosingSlideTests {
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

    @Test func closingTitleIsFullWidthAndBandsDoNotOverlap() throws {
        let deck = try Presentation()
        let slide = try deck.closingSlide(
            "Ship one narrow agent this quarter",
            callToAction: "Pick one painful workflow, build it with ADK on Vertex AI, ground it "
                + "in your data, and put it in front of five real users within 30 days.",
            contact: "cloud.google.com/vertex-ai • google.github.io/adk-docs")

        let all = try boxes(slide)
        let title = try #require(all.first { $0.text.contains("Ship one narrow") })
        let cta = try #require(all.first { $0.text.contains("Pick one painful") })
        let contact = try #require(all.first { $0.text.contains("cloud.google.com") })

        // The bug: the title was pinned to the left half (columnSpan 6) to leave
        // room for a section image. A closing has none, so it now spans the width.
        let slideWidth = deck.slideSize.width.rawValue
        #expect(title.cx > slideWidth / 2)

        // Each element owns a separate vertical band, top → bottom, no overlap.
        #expect(cta.y >= title.y + title.cy)          // CTA starts below the title band
        #expect(contact.y >= cta.y + cta.cy)          // contact starts below the CTA band

        // No negative extents (would trip PowerPoint's repair).
        #expect(all.allSatisfy { $0.cx > 0 && $0.cy > 0 })
    }

    @Test func closingWithOnlyATitleRenders() throws {
        let deck = try Presentation()
        let slide = try deck.closingSlide("Thank you")
        let all = try boxes(slide)
        #expect(all.contains { $0.text.contains("Thank you") })
        // Round-trips cleanly (structurally valid).
        _ = try Presentation(data: try deck.serializedData())
    }
}
