import Foundation
import Testing
@testable import Rostrum

@Suite struct HeadersFootersTests {
    private func descendants(_ e: XML.Element) -> [XML.Element] {
        [e] + e.childElements.flatMap(descendants)
    }

    @Test func slideNumbersAddALiveFieldToEverySlide() throws {
        let deck = try Presentation()
        try deck.titleSlide("T")
        try deck.bulletSlide("B", ["x"])
        try deck.showSlideNumbers()
        for i in 0..<deck.slides.count {
            let hasField = descendants(try deck.slides[i].part.dom())
                .contains { $0.name == "a:fld" && $0[attribute: "type"] == "slidenum" }
            #expect(hasField, "slide \(i) missing number field")
        }
        #expect(try deck.validate().isEmpty)
        _ = try Presentation(data: try deck.serializedData())
    }

    @Test func footerAndDateAppearAndRoundTrip() throws {
        let deck = try Presentation()
        try deck.bulletSlide("B", ["x"])
        try deck.footer("Confidential — Northwind")
        try deck.showDate()
        let reopened = try Presentation(data: try deck.serializedData())
        let slide0 = reopened.slides[0]
        let text = slide0.shapes.compactMap { $0.textFrame?.text }.joined(separator: " ")
        #expect(text.contains("Confidential"))
        let hasDate = descendants(try slide0.part.dom())
            .contains { $0.name == "a:fld" && $0[attribute: "type"] == "datetime" }
        #expect(hasDate)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func fieldsAreDeterministic() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            try deck.bulletSlide("B", ["x"])
            try deck.footer("Confidential").showSlideNumbers()
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }
}
