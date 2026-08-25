import Foundation
import Testing
@testable import Rostrum

/// A part with no declared content type is malformed by OPC M1.2 — and
/// PowerPoint writes them anyway. Deleting content can leave a `/[trash]/…`
/// entry in the archive with neither an Override nor a matching Default, and
/// PowerPoint reopens its own file without complaint.
///
/// Rejecting the whole package over one cost 12 of 471 real decks in a single
/// library (2.5%), every one of which opens in PowerPoint and in python-pptx.
/// So they are carried rather than rejected — and carried means they survive a
/// resave, because losing them would trade one bug for a quieter one.
@Suite struct UntypedEntryTests {
    /// A minimal deck plus one entry nothing declares a type for.
    private func deckWithTrash(_ trashName: String = "[trash]/0000.dat",
                               payload: Data = Data([0xDE, 0xAD, 0xBE, 0xEF])) throws -> Data {
        let original = try MinimalTemplate.makePackage().serialize()
        let reader = try ZipReader(data: original)

        var zip = ZipWriter()
        for name in reader.entryNames {
            zip.addFile(name: name, data: try reader.data(forEntry: name))
        }
        zip.addFile(name: trashName, data: payload)
        return try zip.finalize()
    }

    @Test func aPartWithNoContentTypeDoesNotSinkThePackage() throws {
        let package = try OPCPackage.read(data: try deckWithTrash())

        #expect(package.parts[PackURI("/[trash]/0000.dat")] == nil,
                "an untyped entry must not become a Part — it has no legal serialization")
        #expect(package.untypedEntries.contains { $0.name == "[trash]/0000.dat" })
    }

    @Test func theDeckItselfOpensAndIsUsable() throws {
        let deck = try Presentation(data: try deckWithTrash())
        #expect(deck.slides.count == 1, "the real content survived the malformed entry")
    }

    /// Silence here would be the worse bug: the package is malformed, the
    /// reader coped, and a caller checking round-trip fidelity deserves to know.
    @Test func carryingIsRecordedNotSilent() throws {
        let deck = try Presentation(data: try deckWithTrash())
        #expect(deck.readWarnings.contains { $0.contains("[trash]/0000.dat") })
    }

    /// Lossless round-tripping is the library's standing rule, and a carried
    /// entry is exactly the kind of thing a resave quietly drops.
    @Test func aCarriedEntrySurvivesAResave() throws {
        let payload = Data("not a part".utf8)
        let package = try OPCPackage.read(data: try deckWithTrash(payload: payload))
        let resaved = try OPCPackage.read(data: try package.serialize())

        let carried = resaved.untypedEntries.first { $0.name == "[trash]/0000.dat" }
        #expect(carried?.data == payload, "the bytes came back changed or not at all")
    }

    @Test func resavingTwiceIsAFixedPoint() throws {
        let once = try OPCPackage.read(data: try deckWithTrash()).serialize()
        let twice = try OPCPackage.read(data: once).serialize()
        #expect(once == twice, "determinism must survive the carried entry")
    }

    /// The guard is "no declared content type", not "lives in [trash]" — the
    /// rule is about the declaration, and other producers leave other names.
    @Test func theRuleIsAboutTheDeclarationNotTheName() throws {
        let package = try OPCPackage.read(
            data: try deckWithTrash("ppt/leftovers/stray.bin"))
        #expect(package.untypedEntries.contains { $0.name == "ppt/leftovers/stray.bin" })
    }

    /// An entry whose extension *is* declared is still a real part; carrying
    /// must not become a way for content to go missing.
    @Test func aDeclaredExtensionIsStillAPart() throws {
        let package = try OPCPackage.read(data: try deckWithTrash("ppt/extra.xml"))

        #expect(package.parts[PackURI("/ppt/extra.xml")] != nil,
                "the Default for \"xml\" covers this — it is a part, not a stray")
        #expect(!package.untypedEntries.contains { $0.name == "ppt/extra.xml" })
    }
}
