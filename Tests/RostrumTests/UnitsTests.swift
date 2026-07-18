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
