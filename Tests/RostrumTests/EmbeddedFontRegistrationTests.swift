import Foundation
import Testing
@testable import Rostrum

@Suite struct EmbeddedFontRegistrationTests {
    @Test func eotLiteRoundTripsThroughWrapAndUnwrap() throws {
        let sfnt = TestFont.standard(familyName: "Test Sans")
        let wrapped = EOTLite.wrap(sfnt, typeface: "Test Sans", style: "Regular",
                                   weight: 400, italic: false)
        #expect(wrapped.count > sfnt.count)
        #expect(EOTLite.unwrap(wrapped) == sfnt)
    }

    @Test func unwrapRejectsMalformedContainers() {
        #expect(EOTLite.unwrap(Data()) == nil)
        #expect(EOTLite.unwrap(Data(repeating: 0, count: 200)) == nil)   // no magic number

        // A valid container whose Flags are set (XOR-obfuscated / MTX-compressed
        // font data) must be refused rather than handed on as sfnt.
        let sfnt = TestFont.standard(familyName: "Test Sans")
        var flagged = [UInt8](EOTLite.wrap(sfnt, typeface: "T", style: "Regular",
                                           weight: 400, italic: false))
        flagged[12] = 0x01
        #expect(EOTLite.unwrap(Data(flagged)) == nil)

        // Truncations of a valid container must return nil, never trap.
        let good = EOTLite.wrap(sfnt, typeface: "T", style: "Regular", weight: 400, italic: false)
        for cut in stride(from: 0, to: good.count, by: 97) {
            _ = EOTLite.unwrap(good.prefix(cut))
        }
    }

    @Test func embeddedFontsRegisterForMeasurement() throws {
        let deck = try Presentation()
        try deck.embedFont("Test Sans", faces: FontFaces(regular: TestFont.standard(familyName: "Test Sans")))

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.fonts.metrics(for: "Test Sans") == nil)   // nothing happens implicitly

        let registered = reopened.registerEmbeddedFonts()
        #expect(registered == ["Test Sans"])
        let metrics = try #require(reopened.fonts.metrics(for: "Test Sans"))
        #expect(metrics.advance(of: "W") == 900)
        #expect(metrics.unitsPerEm == 1000)
    }

    @Test func registeringEmbeddedFontsOnAPlainDeckIsANoOp() throws {
        let deck = try Presentation()
        #expect(deck.registerEmbeddedFonts().isEmpty)
        #expect(deck.fonts.isEmpty)
    }

    @Test func registrationDoesNotDirtyThePackage() throws {
        let deck = try Presentation()
        try deck.embedFont("Test Sans", faces: FontFaces(regular: TestFont.standard(familyName: "Test Sans")))
        let original = try deck.serializedData()

        let reopened = try Presentation(data: original)
        reopened.registerEmbeddedFonts()
        // Reading fonts is a read: the deck must still re-emit its original bytes.
        #expect(try reopened.serializedData() == original)
    }

    @Test func embeddedFontInternalAliasesDoNotOverwriteRegisteredFamilies() throws {
        // Build a distinct "Calibri" face (advance of 'W' = 700 instead of 900).
        let calibriAdvances = [600] + (0x20...0x7E).map { $0 == 0x57 ? 700 : 500 }
        let calibriSFNT = Data(TestFont.assemble(tables: [
            ("head", TestFont.head(upem: 1000)),
            ("hhea", TestFont.hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: calibriAdvances.count)),
            ("maxp", TestFont.maxp(numGlyphs: calibriAdvances.count)),
            ("hmtx", TestFont.hmtx(advances: calibriAdvances)),
            ("cmap", TestFont.cmapFormat4()),
            ("name", TestFont.nameTable(family: "Calibri")),
        ]))
        // Hostile embedded font declared as "DeckCustom" whose internal name table
        // claims "Calibri" (with W = 900).
        let embeddedSFNT = TestFont.standard(familyName: "Calibri")

        let deck = try Presentation()
        try deck.embedFont("DeckCustom", faces: FontFaces(regular: embeddedSFNT))
        let reopened = try Presentation(data: try deck.serializedData())
        try reopened.fonts.register(calibriSFNT)

        let registered = reopened.registerEmbeddedFonts()
        #expect(registered == ["DeckCustom"])
        #expect(reopened.fonts.metrics(for: "DeckCustom")?.advance(of: "W") == 900)
        // Pre-registered Calibri must remain intact rather than being hijacked.
        #expect(reopened.fonts.metrics(for: "Calibri")?.advance(of: "W") == 700)
    }
}

@Suite struct SlideCapacityTests {
    @Test func buildersLayOutUpToTheirDocumentedCapacity() throws {
        let deck = try Presentation()
        let many = (1...12).map { "Item \($0)" }

        try deck.processSlide("Process", steps: many)
        let process = try deck.slides[deck.slides.count - 1]
        // One badge + one caption per step, plus arrows between them.
        let badges = process.shapes.all.filter { $0.name.hasPrefix("ellipse") }
        #expect(badges.count == SlideCapacity.process)

        try deck.bandsSlide("Bands", bands: many)
        let bands = try deck.slides[deck.slides.count - 1]
        #expect(bands.shapes.all.filter { $0.name.hasPrefix("roundRect") }.count == SlideCapacity.bands)

        try deck.pyramidSlide("Pyramid", levels: many)
        let pyramid = try deck.slides[deck.slides.count - 1]
        #expect(pyramid.shapes.all.filter { $0.name.hasPrefix("trapezoid") }.count == SlideCapacity.pyramid)
    }

    @Test func capacitiesAreTheDocumentedValues() {
        // Pinned so a layout change can't quietly shrink what callers may pass.
        #expect(SlideCapacity.process == 5)
        #expect(SlideCapacity.smartArt == 6)
        #expect(SlideCapacity.bands == 6)
        #expect(SlideCapacity.pyramid == 5)
        #expect(SlideCapacity.metrics == 4)
    }
}
