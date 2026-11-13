import Foundation
import Testing
@testable import Rostrum

@Suite struct GeneratedPresetShapeTests {
    @Test func everySchemaPresetHasAnOutline() {
        let missing = ShapeGeometry.allCases.map(\.rawValue).filter { !SVGPresetGeometry.supported.contains($0) }
        #expect(missing.isEmpty, "presets without an outline: \(missing)")
        #expect(SVGPresetGeometry.analytic.isDisjoint(with: GeneratedPresetShapes.definitions.keys))
    }

    @Test func everyGeneratedDefinitionResolvesAtSeveralAspectRatios() throws {
        #expect(GeneratedPresetShapes.definitions.count == 81)
        for preset in GeneratedPresetShapes.definitions.keys.sorted() {
            let definition = try #require(SVGPresetGeometry.definition(preset, adjustments: nil), "\(preset)")
            for (width, height) in [(914_400.0, 914_400.0), (3_657_600.0, 457_200.0), (457_200.0, 3_657_600.0)] {
                guard let resolved = SVGCustomGeometry.resolve(definition, width: width, height: height) else {
                    Issue.record("\(preset) does not resolve at \(width)x\(height)")
                    continue
                }
                #expect(!resolved.paths.isEmpty, "\(preset)")
                #expect(resolved.paths.allSatisfy { !$0.data.contains("nan") && !$0.data.contains("inf") }, "\(preset)")
                if let rect = resolved.textRect {
                    #expect(rect.left >= -1 && rect.top >= -1 && rect.right <= width + 1 && rect.bottom <= height + 1,
                            "\(preset) text rectangle leaves the shape")
                }
            }
        }
    }

    @Test func star5MatchesItsClosedFormVertices() throws {
        // ECMA star5 at a square size: the top point is (hc, t) and the two
        // lower points sit at 18° past the horizontal axis.
        let definition = try #require(SVGPresetGeometry.definition("star5", adjustments: nil))
        let paths = try #require(SVGCustomGeometry.paths(definition, width: 1000, height: 1000))
        #expect(paths.count == 1 && paths[0].closed && paths[0].fill)
        let numbers = paths[0].data.split(whereSeparator: { !"0123456789.-".contains($0) }).compactMap { Double($0) }
        #expect(numbers.count == 20)   // ten vertices
        // hf 105146, vf 110557 scale the circumscribed circle so the star fills its box.
        let xs = stride(from: 0, to: 20, by: 2).map { numbers[$0] }
        let ys = stride(from: 1, to: 20, by: 2).map { numbers[$0] }
        #expect(abs(xs.min()!) < 0.5 && abs(xs.max()! - 1000) < 0.5)
        #expect(abs(ys.min()!) < 0.5 && abs(ys.max()! - 1000) < 0.5)
    }

    @Test func literalAdjustmentsReplaceDefaultsAndRenderWithoutRectangleFallback() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addShape(.smileyFace,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(2)), fill: .solid(Color("FFCC00")))
        _ = shape
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(!result.problems.fidelityIssues.contains { $0.code == .unsupportedGeometry })
        // The mouth and eyes are darker overlays on the face fill.
        #expect(result.svg.contains("fill-opacity=\"0.2\""))

        let frown = XML.Element("a:avLst", children: [.element(XML.Element("a:gd", attributes: [("name", "adj"), ("fmla", "val -4653")]))])
        let smile = try #require(SVGPresetGeometry.definition("smileyFace", adjustments: nil))
        let frowning = try #require(SVGPresetGeometry.definition("smileyFace", adjustments: frown))
        #expect(SVGCustomGeometry.paths(smile, width: 1000, height: 1000)?.map(\.data)
            != SVGCustomGeometry.paths(frowning, width: 1000, height: 1000)?.map(\.data))
        // Overrides build a new element; the shared default stays untouched.
        #expect(smile.firstChild(named: "a:avLst")?.firstChild(named: "a:gd")?[attribute: "fmla"] == "val 4653")
    }

    @Test func textRectangleInsetsLabelsInsideGeneratedOutlines() {
        let frame = (0, 0, 2_000_000, 1_000_000)
        let inset = SVGPresetGeometry.textFrame("cloud", adjustments: nil, frame: frame)
        #expect(inset.0 > frame.0 && inset.1 > frame.1 && inset.2 < frame.2 && inset.3 < frame.3)
    }
}
