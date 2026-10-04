import Testing
@testable import Lectern

@Suite struct PreviewSlideNumberTests {
    @Test func accessibilityUsesOriginalDeckPositionsAfterAPreviewFailure() {
        #expect(slideLabel(0, of: 3, titles: ["Second", "Third"], slideNumbers: [2, 3])
                == "Slide 2 of 3: Second")
        #expect(slideLabel(1, of: 3, titles: ["Second", "Third"], slideNumbers: [2, 3])
                == "Slide 3 of 3: Third")
    }

    @Test func untitledAndExistingCallersKeepTheirPositionLabels() {
        #expect(slideLabel(0, of: 3, titles: [""], slideNumbers: [2]) == "Slide 2 of 3")
        #expect(slideLabel(1, of: 3, titles: []) == "Slide 2 of 3")
    }
}
