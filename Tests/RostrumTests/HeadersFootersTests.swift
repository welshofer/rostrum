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
        let slide0 = try reopened.slides[0]
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
    /// Furniture is added after the builders have painted backgrounds, so it
    /// has to read the slide it lands on. A footer coloured for the deck's
    /// canvas printed dark grey on a red section field and washed out over a
    /// photograph.
    @Test func furnitureTakesItsColourFromTheSlideItLandsOn() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse(
            "## Palette\n- Background: #FFFFFF\n- Text: #111111\n- Accent 1: #C8102E"))
        let s = deck.style

        let plain = try deck.slides[0]
        #expect(deck.furnitureColor(on: plain, style: s) == s.mutedInk)

        // A section field: the deck's muted ink was chosen against the canvas,
        // not against this.
        let section = try deck.slides.add()
        try section.setBackground(.solid(s.accent(1)))
        let onField = deck.furnitureColor(on: section, style: s)
        #expect(onField.contrastRatio(with: s.accent(1)) >= 4.5)

        // A photograph is texture, not a tone: quiet reads as washed out here
        // whatever the ratio against the average says.
        let photo = try deck.slides.add()
        try photo.setBackground(.image(Self.tinyPNG(), .stretch))
        #expect(deck.furnitureColor(on: photo, style: s) == s.textColor(on: s.background))
        #expect(deck.furnitureColor(on: photo, style: s) != s.mutedInk)
    }

    private static func tinyPNG() -> Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        b += be32(13); b += Array("IHDR".utf8); b += be32(8); b += be32(8); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }
}
