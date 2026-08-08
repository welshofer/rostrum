import Testing
@testable import Rostrum

@Suite struct UnitsTests {
    @Test func conversionsAreExact() {
        // EMU's whole reason to exist: inches, centimeters, and points all
        // divide it exactly.
        #expect(EMU.inches(1).rawValue == 914_400)
        #expect(EMU.points(18).rawValue == 228_600)
        #expect(EMU.centimeters(2.54).rawValue == 914_400)
        #expect(EMU.millimeters(25.4).rawValue == 914_400)
        #expect(EMU.emu(914_400) == EMU.inches(1))
    }

    @Test func readbackIsUnitAgnostic() {
        let width = EMU.points(540)
        #expect(width.points == 540)
        #expect(width.inches == 7.5)
        let fromKeynote = EMU.inches(13.333333)
        #expect(abs(fromKeynote.points - 960) < 0.01)
    }

    @Test func negativeValuesRoundSymmetrically() {
        #expect(EMU.points(-18).rawValue == -228_600)
        #expect(-EMU.points(18) == EMU.points(-18))
    }

    @Test func scalarArithmetic() {
        let slideWidth = EMU.inches(12)
        #expect(slideWidth * 0.5 == EMU.inches(6))
        #expect(0.25 * slideWidth == EMU.inches(3))
        #expect(slideWidth / 3.0 == EMU.inches(4))
        #expect(slideWidth / EMU.inches(4) == 3.0)
        #expect(slideWidth + EMU.inches(1) - EMU.inches(1) == slideWidth)
    }

    @Test func nonFiniteInputsDegradeInsteadOfTrapping() {
        // `Int(Double)` aborts the process on NaN/infinity, and `width / 0.0`
        // is ordinary layout math gone slightly wrong — it must not be fatal.
        #expect(EMU.inches(.nan).rawValue == 0)
        #expect(EMU.points(.nan).rawValue == 0)
        #expect(EMU.inches(.infinity).rawValue == OOXMLBounds.coordinate.upperBound)
        #expect(EMU.points(-.infinity).rawValue == OOXMLBounds.coordinate.lowerBound)
        #expect((EMU.inches(1) / 0.0).rawValue == OOXMLBounds.coordinate.upperBound)
        #expect((EMU.inches(-1) / 0.0).rawValue == OOXMLBounds.coordinate.lowerBound)
        #expect((EMU.inches(1) * Double.nan).rawValue == 0)
    }

    @Test func outOfRangeMagnitudesSaturateToTheCoordinateBound() {
        // The same ceiling the read side imposes (`OOXMLBounds.coordinate`),
        // so a saturated value still survives downstream +/* without overflow.
        #expect(EMU.inches(1e300).rawValue == OOXMLBounds.coordinate.upperBound)
        #expect(EMU.inches(-1e300).rawValue == OOXMLBounds.coordinate.lowerBound)
        let saturated = EMU.inches(1e300)
        #expect((saturated + saturated).rawValue == 2 * OOXMLBounds.coordinate.upperBound)
    }

    @Test func staticMemberInferenceReadsCleanly() throws {
        // The blessed call shape: `.points(…)` / `.inches(…)` in assignment
        // position, no unit privileged over the other.
        let deck = try Presentation()
        // 960×540 pt is Keynote's 16:9 default — 13.333" × 7.5" in
        // PowerPoint's terms; both readbacks must agree.
        deck.slideSize = (width: .points(960), height: .points(540))
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slideSize.width.points == 960)
        #expect(reopened.slideSize.height == .inches(7.5))
    }
}
