import Foundation
import Testing
@testable import Rostrum

/// R-REL-1: a slide inherits its background and furniture down the
/// slide → layout → master chain. When a link in that chain is broken the
/// slide still renders — just without what it would have inherited — so the
/// break leaves no trace in the SVG. `renderSVGReportingProblems` names which
/// link broke; `renderSVG` still returns the same string it always did.
@Suite struct SVGInheritanceProblemsTests {

    /// Resolve the layout part a slide points at, the way the renderer does,
    /// so a test can reach in and sever the layout's own links.
    private func layoutPart(of deck: Presentation, slideAt index: Int) throws -> Part {
        let slidePart = try deck.slides[index].part
        let rel = try #require(slidePart.rels.first(ofType: RelType.slideLayout))
        return try deck.package.part(
            at: PackURI.resolve(target: rel.target, relativeTo: slidePart.uri.baseURI))
    }

    /// A whole, healthy deck resolves every link and reports nothing missing,
    /// and the reporting call renders exactly what the plain call renders.
    @Test func healthyDeckReportsNoProblems() throws {
        let deck = try Presentation()

        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.isEmpty)
        #expect(!result.problems.layoutUnresolved)
        #expect(!result.problems.masterUnresolved)
        #expect(result.svg.hasPrefix("<svg"))
        _ = try XML.parse(Data(result.svg.utf8))   // well-formed

        // The wrapper returns the identical string, so a healthy render is
        // unchanged by the addition of the reporting path; and it is stable.
        #expect(try deck.renderSVG(slideAt: 0) == result.svg)
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).svg == result.svg)
    }

    /// The slide's link to its layout is gone. The old code folded this into a
    /// bare `(nil, nil)`; now it is named — and only it, not the master.
    @Test func missingLayoutRelationshipIsReported() throws {
        let deck = try Presentation()

        let slidePart = try deck.slides[0].part
        let rel = try #require(slidePart.rels.first(ofType: RelType.slideLayout))
        slidePart.rels.remove(rId: rel.rId)

        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.layoutUnresolved)
        #expect(!result.problems.masterUnresolved)
        #expect(!result.problems.isEmpty)

        // Rendering still succeeds and still yields a well-formed SVG.
        #expect(result.svg.hasPrefix("<svg"))
        #expect(result.svg.contains("viewBox="))
        _ = try XML.parse(Data(result.svg.utf8))

        // And the source-compatible wrapper still produces that same SVG.
        #expect(try deck.renderSVG(slideAt: 0) == result.svg)
    }

    /// The layout relationship survives, but the part it points at is gone —
    /// the "layout part cannot be resolved" half of the same failure. It is
    /// reported the same way, and rendering still degrades gracefully.
    @Test func unresolvableLayoutPartIsReported() throws {
        let deck = try Presentation()

        let layout = try layoutPart(of: deck, slideAt: 0)
        deck.package.removePart(at: layout.uri)

        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.layoutUnresolved)
        #expect(!result.problems.masterUnresolved)

        #expect(result.svg.hasPrefix("<svg"))
        #expect(result.svg.contains("viewBox="))
        _ = try XML.parse(Data(result.svg.utf8))
    }

    /// The layout resolves fine; its own link to the master is severed. This
    /// is the distinct second failure the old code flattened into the first —
    /// now the master is named and the layout is reported intact.
    @Test func missingMasterRelationshipIsReported() throws {
        let deck = try Presentation()

        let layout = try layoutPart(of: deck, slideAt: 0)
        let masterRel = try #require(layout.rels.first(ofType: RelType.slideMaster))
        layout.rels.remove(rId: masterRel.rId)

        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.masterUnresolved)
        #expect(!result.problems.layoutUnresolved)
        #expect(!result.problems.isEmpty)

        #expect(result.svg.hasPrefix("<svg"))
        #expect(result.svg.contains("viewBox="))
        _ = try XML.parse(Data(result.svg.utf8))

        #expect(try deck.renderSVG(slideAt: 0) == result.svg)
    }
}
