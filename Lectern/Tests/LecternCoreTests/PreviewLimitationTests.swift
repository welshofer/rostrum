import Testing
@testable import LecternCore

@Suite struct PreviewLimitationTests {
    @Test func perSlideWarningsCollapseIntoOneGroupPerMessage() {
        let groups = PreviewLimitation.grouped([
            "Slide 1: Spacing", "Slide 2: Connectors", "Slide 2: Spacing",
            "Slide 3: Spacing", "Slide 3: Connectors", "Slide 7: Chart", "Deck-level note",
        ])
        #expect(groups == [
            PreviewLimitation(message: "Spacing", slides: [1, 2, 3]),
            PreviewLimitation(message: "Connectors", slides: [2, 3]),
            PreviewLimitation(message: "Chart", slides: [7]),
            PreviewLimitation(message: "Deck-level note", slides: []),
        ])
    }

    @Test func messagesContainingColonsStayIntact() {
        let groups = PreviewLimitation.grouped(["Slide 12: Paragraph alignment 'dist': using left"])
        #expect(groups == [PreviewLimitation(message: "Paragraph alignment 'dist': using left", slides: [12])])
    }

    @Test func slideSummariesCompressRuns() {
        #expect(PreviewLimitation(message: "", slides: [4]).slideSummary() == "Slide 4")
        #expect(PreviewLimitation(message: "", slides: [2, 3, 14, 17, 18, 19, 30, 31]).slideSummary()
            == "Slides 2, 3, 14, 17–19, 30, 31")
        #expect(PreviewLimitation(message: "", slides: Array(1...33)).slideSummary(slideCount: 33) == "All 33 slides")
        #expect(PreviewLimitation(message: "", slides: Array(1...32)).slideSummary(slideCount: 33) == "Slides 1–32")
        #expect(PreviewLimitation(message: "", slides: []).slideSummary() == "Deck")
    }
}
