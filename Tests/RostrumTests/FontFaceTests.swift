import Foundation
import Testing
@testable import Rostrum

@Suite struct FontFaceTests {
    static func font(_ width: Int, bold: Bool, italic: Bool, os2: Bool = true) -> Data {
        var head = TestFont.head(upem: 1000)
        head.replaceSubrange(44..<46, with: TestFont.be16((bold ? 1 : 0) | (italic ? 2 : 0)))
        var tables: [(String, [UInt8])] = [
            ("head", head),
            ("hhea", TestFont.hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: 96)),
            ("maxp", TestFont.maxp(numGlyphs: 96)),
            ("hmtx", TestFont.hmtx(advances: Array(repeating: width, count: 96))),
            ("cmap", TestFont.cmapFormat4()), ("name", TestFont.nameTable(family: "Family"))
        ]
        if os2 {
            var selection = TestFont.os2(useTypoMetrics: false)
            selection.replaceSubrange(62..<64, with: TestFont.be16((bold ? 32 : 0) | (italic ? 1 : 0)))
            tables.append(("OS/2", selection))
        }
        return Data(TestFont.assemble(tables: tables))
    }

    @Test func allStylesResolveIndependentlyInEveryRegistrationOrder() throws {
        let faces = [(false, false, 400), (true, false, 500), (false, true, 600), (true, true, 700)]
        // Every permutation, with style inference both with and without OS/2.
        for os2 in [false, true] {
            for a in 0..<4 { for b in 0..<4 where b != a { for c in 0..<4 where c != a && c != b {
                let d = (0..<4).first { $0 != a && $0 != b && $0 != c }!
                let library = FontLibrary()
                for index in [a, b, c, d] {
                    let f = faces[index]
                    try library.register(Self.font(f.2, bold: f.0, italic: f.1, os2: os2), aliases: ["Alias"])
                }
                for f in faces {
                    #expect(library.metrics(for: "FAMILY", bold: f.0, italic: f.1)?.advance(of: "A") == f.2)
                    #expect(library.metrics(for: FontFaceKey(family: "alias", bold: f.0, italic: f.1))?.advance(of: "A") == f.2)
                }
                #expect(library.metrics(for: "family")?.advance(of: "A") == 400)
            } } }
        }
    }

    @Test func exactLookupDoesNotInventFallbackAndLegacyPreferenceIsStable() throws {
        let library = FontLibrary()
        try library.register(Self.font(600, bold: false, italic: true))
        try library.register(Self.font(500, bold: true, italic: false))
        #expect(library.metrics(for: "Family")?.advance(of: "A") == 500)
        #expect(library.metrics(for: "Family", bold: false, italic: false) == nil)
        try library.register(Self.font(400, bold: true, italic: true), face: FontFaceKey(family: "Family"))
        #expect(library.metrics(for: "Family")?.advance(of: "A") == 400)
    }

    @Test func embeddedVariantsHonorTagsAndPreserveBytes() throws {
        let deck = try Presentation()
        // Contradictory font flags deliberately verify that XML variant wins.
        try deck.embedFont("Embedded", faces: FontFaces(
            regular: Self.font(400, bold: true, italic: true),
            bold: Self.font(500, bold: false, italic: false),
            italic: Self.font(600, bold: false, italic: false),
            boldItalic: Self.font(700, bold: false, italic: false)))
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        #expect(reopened.registerEmbeddedFonts() == ["Embedded"])
        for (bold, italic, width) in [(false, false, 400), (true, false, 500), (false, true, 600), (true, true, 700)] {
            #expect(reopened.fonts.metrics(for: "Embedded", bold: bold, italic: italic)?.advance(of: "A") == width)
        }
        #expect(try reopened.serializedData() == bytes)
    }
    @Test func encodedPreviewResourcesInvalidateOnReregistration() throws {
        let library = FontLibrary(), regular = FontFaceKey(family: "Family")
        let first = Self.font(400, bold: false, italic: false)
        try library.register(first, aliases: ["Alias"])
        #expect(library.encodedSource(for: regular) == first.base64EncodedString())
        #expect(library.encodedSource(for: regular) == first.base64EncodedString())
        let replacement = Self.font(600, bold: false, italic: false)
        try library.register(replacement, aliases: ["Alias"])
        #expect(library.encodedSource(for: regular) == replacement.base64EncodedString())
        #expect(library.encodedSource(for: FontFaceKey(family: "Alias")) == replacement.base64EncodedString())
        #expect(library.previewFace(for: FontFaceKey(family: "Alias", bold: true)) == FontFaceKey(family: "Alias"))
        #expect(library.metrics(for: "Alias", bold: true, italic: false) == nil)
    }

}
