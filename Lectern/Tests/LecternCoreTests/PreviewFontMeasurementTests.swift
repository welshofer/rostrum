import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PreviewFontMeasurementTests {
    @Test func nativeGlyphAdvancesDistinguishWideAndNarrowTextWithoutChangingFile() throws {
        let deck = try Presentation()
        let before = try deck.serializedData()
        PreviewFontMeasurement.install(on: deck.fonts)
        #if canImport(CoreText)
        let measure = try #require(deck.fonts.previewAdvance)
        let narrow = try #require(measure("iiii", "Arial", 24, false, false))
        let wide = try #require(measure("WWWW", "Arial", 24, false, false))
        #expect(wide > narrow * 2)
        #expect(wide == measure("WWWW", "Arial", 24, false, false))
        #endif
        #expect(try deck.serializedData() == before)
    }
}
