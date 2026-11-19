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

    @Test func carriedEntriesCopyForeignCompressedPayloadsWithoutReencoding() throws {
        func foreignStoredDeflate(_ bytes: Data) -> ZipWriter.Payload {
            let len = UInt16(bytes.count)
            let nlen = ~len
            var raw = Data([
                0x01,
                UInt8(len & 0xFF), UInt8(len >> 8),
                UInt8(nlen & 0xFF), UInt8(nlen >> 8),
            ])
            raw.append(bytes)
            return ZipWriter.Payload(
                data: raw, method: 8, size: UInt32(bytes.count), crc: CRC32.checksum(bytes))
        }

        let seed = try ZipReader(data: MinimalTemplate.makePackage().serialize())
        var writer = ZipWriter()
        for name in seed.entryNames {
            writer.addFile(name: name, data: try seed.data(forEntry: name))
        }

        let trashPayload = foreignStoredDeflate(Data(repeating: 0xAB, count: 200))
        let orphanRelsPayload = foreignStoredDeflate(Data("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>".utf8))
        let dirPayload = foreignStoredDeflate(Data())

        // Also include a hostile bloated directory placeholder (> +64 B of empty stored DEFLATE headers)
        // to ensure the anti-bloat guard still declines it rather than copying bloat through.
        var bloatedRaw = Data()
        for _ in 0..<20 {
            bloatedRaw.append(contentsOf: [0x00, 0x00, 0x00, 0xFF, 0xFF])
        }
        bloatedRaw.append(contentsOf: [0x01, 0x00, 0x00, 0xFF, 0xFF])
        let bloatedDirPayload = ZipWriter.Payload(data: bloatedRaw, method: 8, size: 0, crc: 0)

        writer.addFile(name: "[trash]/0000.dat", payload: trashPayload)
        writer.addFile(name: "ppt/slides/_rels/slide99.xml.rels", payload: orphanRelsPayload)
        writer.addFile(name: "ppt/customDir/", payload: dirPayload)
        writer.addFile(name: "ppt/bloatedDir/", payload: bloatedDirPayload)

        let package = try OPCPackage.read(data: try writer.finalize())
        let resaved = try ZipReader(data: package.serialize())

        let trashAfter = try resaved.entryPayload(forEntry: "[trash]/0000.dat")
        #expect(trashAfter.entry.method == 8)
        #expect(trashAfter.raw == trashPayload.data)

        let orphanAfter = try resaved.entryPayload(forEntry: "ppt/slides/_rels/slide99.xml.rels")
        #expect(orphanAfter.entry.method == 8)
        #expect(orphanAfter.raw == orphanRelsPayload.data)

        let dirAfter = try resaved.entryPayload(forEntry: "ppt/customDir/")
        #expect(dirAfter.entry.method == 8)
        #expect(dirAfter.raw == dirPayload.data)

        let bloatedAfter = try resaved.entryPayload(forEntry: "ppt/bloatedDir/")
        #expect(bloatedAfter.decoded.isEmpty)
        #expect(bloatedAfter.raw.isEmpty, "bloated placeholder should be normalized rather than copied")
    }
}
