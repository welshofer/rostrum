import Foundation
import Testing
@testable import Rostrum

@Suite struct PreparedFontTests {
    @Test func snapshotCanBeRegisteredInIndependentLibrariesWithoutChangingItsBytes() throws {
        var bytes = FontFaceTests.font(450, bold: true, italic: false)
        let original = bytes
        let prepared = try PreparedFont(data: bytes)
        bytes[0] = 0xFF
        let first = FontLibrary(), second = FontLibrary()
        #expect(try first.register(prepared, aliases: ["First"]) == "Family")
        #expect(try second.register(prepared, aliases: ["Second"]) == "Family")
        #expect(prepared.data == original && prepared.fontIndex == 0)
        for (library, alias) in [(first, "First"), (second, "Second")] {
            let face = FontFaceKey(family: alias, bold: true)
            #expect(library.data(for: face) == original)
            #expect(library.metrics(for: face)?.advance(of: "A") == 450)
            #expect(library.metrics(for: alias, bold: false, italic: false) == nil)
        }
        try first.register(FontFaceTests.font(800, bold: true, italic: false), aliases: ["First"])
        #expect(first.metrics(for: "First")?.advance(of: "A") == 800)
        #expect(second.metrics(for: "Second")?.advance(of: "A") == 450)
        #expect(prepared.metrics.advance(of: "A") == 450)
    }

    @Test func explicitStyleAndReplacementHaveTheSameSemanticsAsRawRegistration() throws {
        let library = FontLibrary(), regular = FontFaceKey(family: "Override")
        let source = FontFaceTests.font(500, bold: true, italic: true)
        try library.register(PreparedFont(data: source), face: regular, aliases: ["Alias"])
        #expect(library.metrics(for: regular)?.isBold == true)
        #expect(library.metrics(for: regular)?.advance(of: "A") == 500)
        #expect(library.metrics(for: "Override", bold: true, italic: true) == nil)
        #expect(library.encodedSource(for: regular) == source.base64EncodedString())
        let replacement = FontFaceTests.font(700, bold: false, italic: false)
        try library.register(PreparedFont(data: replacement), face: regular, aliases: ["Alias"])
        for family in ["Override", "Family", "Alias"] {
            let face = FontFaceKey(family: family)
            #expect(library.metrics(for: face)?.advance(of: "A") == 700)
            #expect(library.data(for: face) == replacement)
            #expect(library.encodedSource(for: face) == replacement.base64EncodedString())
        }
    }

    @Test func freshFilePreparationObservesReplacementWhileExistingSnapshotStaysStable() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ttf")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = FontFaceTests.font(400, bold: false, italic: false)
        let second = FontFaceTests.font(600, bold: false, italic: false)
        try first.write(to: url)
        let old = try PreparedFont(contentsOf: url)
        try second.write(to: url)
        let fresh = try PreparedFont(contentsOf: url)
        #expect(old.data == first && fresh.data == second)
        #expect(old.metrics.advance(of: "A") == 400 && fresh.metrics.advance(of: "A") == 600)
    }

    @Test func invalidOrNamelessPreparationCannotPartiallyReplaceRegisteredFaces() throws {
        let library = FontLibrary(), original = TestFont.standard(familyName: "Original")
        try library.register(original)
        #expect(throws: RostrumError.self) { try library.register(PreparedFont(data: Data())) }
        let nameless = try PreparedFont(data: TestFont.standard())
        #expect(throws: RostrumError.self) { try library.register(nameless) }
        #expect(library.data(for: .init(family: "Original")) == original)
        #expect(try library.register(nameless, aliases: ["Explicit"]) == "Explicit")
        #expect(library.metrics(for: "Explicit")?.advance(of: "W") == 900)
    }

    @Test func collectionSnapshotRetainsExactSourceAndValidatesTheSelectedIndex() throws {
        let data = TestFont.collection()
        let prepared = try PreparedFont(data: data)
        let library = FontLibrary()
        try library.register(prepared, aliases: ["Collection"])
        #expect(prepared.fontIndex == 0 && prepared.data == data)
        #expect(library.metrics(for: "Collection")?.advance(of: "W") == 900)
        #expect(library.data(for: .init(family: "Collection")) == data)
        for index in [-1, 1, Int.max] {
            #expect(throws: RostrumError.self) { try PreparedFont(data: data, fontIndex: index) }
        }
    }
}
