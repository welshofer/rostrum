import Foundation
import Testing
@testable import Rostrum

@Suite struct GradientStopsTests {
    private func stop(_ position: Double, _ color: String, _ alpha: Double = 1) -> GradientStops.Stop {
        .init(position: position, color: Color(color), alpha: alpha)
    }

    @Test func endpointPairUsesChannelSpecificOfficeGammaAndLinearAlpha() {
        let values = GradientStops.interpolated([stop(0, "FF0040", 0.2), stop(1, "00FF40", 0.8)])
        #expect(values.count == 33)
        // Channels changing in opposite directions both favor the brighter end.
        #expect(values[16].position == 0.5)
        #expect(values[16].color == Color("B9B940"))
        #expect(abs(values[16].alpha - 0.5) < 0.000001)
        #expect(values.first?.color == Color("FF0040"))
        #expect(values.last?.color == Color("00FF40"))
    }

    @Test func mirroredThreeStopGradientHasIndependentIntervals() {
        let values = GradientStops.interpolated([stop(0, "000000"), stop(0.25, "FFFFFF"), stop(1, "000000")])
        #expect(values.count == 65)
        #expect(values[16].position == 0.125)
        #expect(values[32].position == 0.25 && values[32].color == .white)
        #expect(values[48].position == 0.625)
        #expect(values[16].color == values[48].color)
    }

    @Test func generalAndNonEndpointGradientsRetainStops() {
        for input in [
            [stop(0.2, "FF0000"), stop(1, "0000FF")],
            [stop(0, "FF0000"), stop(0.99, "0000FF")],
            [stop(0, "000000"), stop(0.5, "FFFFFF"), stop(1, "FF0000")],
            [stop(0, "000000", 0), stop(0.5, "FFFFFF"), stop(1, "000000", 1)],
            [stop(0, "000000"), stop(0, "FFFFFF"), stop(1, "000000")],
            [stop(0, "000000"), stop(0.25, "FFFFFF"), stop(0.75, "FFFFFF"), stop(1, "000000")]
        ] {
            let result = GradientStops.interpolated(input)
            #expect(result.count == input.count)
            #expect(result.map(\.position) == input.map(\.position))
            #expect(result.map(\.color) == input.map(\.color))
            #expect(result.map(\.alpha) == input.map(\.alpha))
        }
    }

    @Test func renderingUsesSharedInterpolationWithoutChangingXML() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        table.clearBuiltInStyle()
        try table.cell(0, 0).setFill(.gradient(GradientFill(from: .black, to: .white, angleDegrees: 0)))
        let shape = try deck.slides[0].shapes.addShape(.rectangle,
            frame: Rect(x: .zero, y: .inches(2), width: .inches(2), height: .inches(1)),
            fill: .gradient(GradientFill(from: .black, to: .white, angleDegrees: 0)))
        #expect(shape.fill != nil)
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.components(separatedBy: "<stop offset=\"0.5\" stop-color=\"#B9B9B9\"/>").count - 1 == 2)
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        #expect(try reopened.renderSVG(slideAt: 0) == svg)
    }
}
