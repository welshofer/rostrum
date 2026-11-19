import Foundation
import Testing
@testable import Rostrum

/// `.rels` parts and `[Content_Types].xml` used to be the one documented
/// exception to the byte-identity rule: they were parsed into models and
/// deterministically rebuilt, so a foreign package's own attribute order,
/// spacing and element order changed on every save. They are parts too, and
/// the rule now covers them.
@Suite struct PristinePackageStreamsTests {
    /// A relationships stream written the way another producer might:
    /// attribute order, indentation and the standalone declaration all vary
    /// freely between producers, and a rebuild would normalize every one.
    private let foreignRels = Data("""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml" Id="rId1"/>
    </Relationships>
    """.utf8)

    @Test func untouchedRelationshipsReEmitVerbatim() throws {
        let rels = try Relationships.parse(foreignRels)
        #expect(rels.items.count == 1)
        // Attribute order here is Type/Target/Id, and the file is indented —
        // a rebuild would normalize both.
        #expect(rels.serialized() == foreignRels)
    }

    @Test func mutatingRelationshipsRebuildsThem() throws {
        let rels = try Relationships.parse(foreignRels)
        rels.add(type: RelType.slide, target: "slides/slide1.xml")
        let rebuilt = rels.serialized()
        #expect(rebuilt != foreignRels)
        // …and the rebuild is still correct and deterministic.
        let reparsed = try Relationships.parse(rebuilt)
        #expect(reparsed.items.count == 2)
        #expect(reparsed.serialized() == rebuilt)
    }

    @Test func removingARelationshipAlsoRebuilds() throws {
        let rels = try Relationships.parse(foreignRels)
        rels.remove(rId: "rId1")
        #expect(rels.serialized() != foreignRels)
        #expect(try Relationships.parse(rels.serialized()).items.isEmpty)
    }

    private let foreignContentTypes = Data("""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
    </Types>
    """.utf8)

    @Test func untouchedContentTypesReEmitVerbatim() throws {
        let map = try ContentTypesMap.parse(foreignContentTypes)
        // Overrides before Defaults, and indented — a rebuild sorts and
        // reorders both.
        #expect(map.serialized() == foreignContentTypes)
        #expect(try map.contentType(for: PackURI("/ppt/presentation.xml"))
                == ContentType.presentationMain)
    }

    @Test func changingContentTypesRebuildsThem() throws {
        var map = try ContentTypesMap.parse(foreignContentTypes)
        map.setDefault(extension: "png", contentType: "image/png")
        #expect(map.serialized() != foreignContentTypes)

        // A no-op write must NOT dirty the map: setting a value it already
        // holds is how the writer re-asserts defaults on every save.
        var untouched = try ContentTypesMap.parse(foreignContentTypes)
        untouched.setDefault(extension: "xml", contentType: "application/xml")
        untouched.setOverride(partName: PackURI("/ppt/presentation.xml"),
                              contentType: ContentType.presentationMain)
        untouched.removeOverride(partName: PackURI("/ppt/nonexistent.xml"))
        #expect(untouched.serialized() == foreignContentTypes)
    }

    /// Rewrite a deck's `.rels` and `[Content_Types].xml` entries the way
    /// another producer formats them — indented, different attribute order,
    /// Overrides before Defaults — so the round trip is exercised on bytes
    /// Rostrum would never write itself. Without this, every "foreign deck"
    /// test is really a Rostrum-deck test, and rebuild-of-a-rebuild is
    /// trivially stable.
    private func reformattedLikeAnotherProducer(_ deck: Data) throws -> Data {
        let reader = try ZipReader(data: deck)
        var zip = ZipWriter()
        for name in reader.entryNames {
            var bytes = try reader.data(forEntry: name)
            if name.hasSuffix(".rels") {
                let rels = try Relationships.parse(bytes)
                var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                xml += "<Relationships xmlns=\"\(Relationships.namespace)\">\n"
                for rel in rels.items {
                    xml += "    <Relationship Type=\"\(rel.type)\" Target=\"\(rel.target)\""
                    if rel.isExternal { xml += " TargetMode=\"External\"" }
                    xml += " Id=\"\(rel.rId)\"/>\n"
                }
                xml += "</Relationships>\n"
                bytes = Data(xml.utf8)
            } else if name == "[Content_Types].xml" {
                let types = try ContentTypesMap.parse(bytes)
                var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                xml += "<Types xmlns=\"\(ContentTypesMap.namespace)\">\n"
                // Overrides first, reverse-sorted: the rebuild would emit
                // Defaults first, sorted.
                for (part, ct) in types.overrides.sorted(by: { $0.key.value > $1.key.value }) {
                    xml += "  <Override ContentType=\"\(ct)\" PartName=\"\(part.value)\"/>\n"
                }
                for (ext, ct) in types.defaults.sorted(by: { $0.key > $1.key }) {
                    xml += "  <Default ContentType=\"\(ct)\" Extension=\"\(ext)\"/>\n"
                }
                xml += "</Types>\n"
                bytes = Data(xml.utf8)
            }
            zip.addFile(name: name, data: bytes)
        }
        return try zip.finalize()
    }

    @Test func aForeignDeckKeepsItsOwnRelsAndContentTypesBytes() throws {
        // The test that would have caught the reader discarding pristine
        // bytes: it goes through OPCPackage.read, not Relationships.parse.
        let built = try Presentation()
        try built.bulletSlide("Title", ["one"])
        let foreign = try reformattedLikeAnotherProducer(try built.serializedData())

        let resaved = try Presentation(data: foreign).serializedData()
        let before = try ZipReader(data: foreign)
        let after = try ZipReader(data: resaved)
        for name in before.entryNames {
            #expect(try after.data(forEntry: name) == before.data(forEntry: name),
                    "\(name) was normalized on a read-only round trip")
        }
        // And the reformatting really was different from what we would write,
        // so the assertion above is not vacuous.
        let rostrumFormatted = try ZipReader(data: try built.serializedData())
        #expect(try before.data(forEntry: "_rels/.rels")
                != rostrumFormatted.data(forEntry: "_rels/.rels"))
        #expect(try before.data(forEntry: "[Content_Types].xml")
                != rostrumFormatted.data(forEntry: "[Content_Types].xml"))
    }

    @Test func editingAForeignDeckRebuildsOnlyWhatChanged() throws {
        let built = try Presentation()
        try built.bulletSlide("Title", ["one"])
        let foreign = try reformattedLikeAnotherProducer(try built.serializedData())

        let deck = try Presentation(data: foreign)
        // Adding a slide changes the presentation's rels, the package content
        // types (a new Override) — but no other .rels part.
        try deck.slides.add()
        let resaved = try deck.serializedData()

        let before = try ZipReader(data: foreign)
        let after = try ZipReader(data: resaved)
        #expect(try after.data(forEntry: "ppt/slideMasters/_rels/slideMaster1.xml.rels")
                == before.data(forEntry: "ppt/slideMasters/_rels/slideMaster1.xml.rels"),
                "an untouched .rels part must keep its foreign formatting")
        #expect(try after.data(forEntry: "ppt/_rels/presentation.xml.rels")
                != before.data(forEntry: "ppt/_rels/presentation.xml.rels"),
                "the part whose relationships changed must be rebuilt")
    }

    @Test func aChangeThatNetsOutStillReEmitsTheOriginal() throws {
        // Dirty-latch tracking would rebuild here; comparing against the
        // parsed state does not.
        let rels = try Relationships.parse(foreignRels)
        let rId = rels.add(type: RelType.slide, target: "slides/slide9.xml")
        rels.remove(rId: rId)
        #expect(rels.serialized() == foreignRels)

        var types = try ContentTypesMap.parse(foreignContentTypes)
        types.setOverride(partName: PackURI("/ppt/slides/slide9.xml"), contentType: ContentType.slide)
        types.removeOverride(partName: PackURI("/ppt/slides/slide9.xml"))
        #expect(types.serialized() == foreignContentTypes)
    }

    @Test func aDeckThatOnlyReadsKeepsEveryStreamByteIdentical() throws {
        // The end-to-end promise: open, read everything, save — identical
        // bytes for every zip entry including .rels and [Content_Types].xml.
        let deck = try Presentation()
        try deck.bulletSlide("Title", ["one", "two"])
        try deck.chartSlide("Chart", .line,
                            ChartData(categories: ["A", "B"], name: "S", values: [1, 2]))
        let original = try deck.serializedData()

        let reopened = try Presentation(data: original)
        for slide in reopened.slides {
            for shape in slide.shapes.all { _ = (shape.kind, shape.frame, shape.textFrame?.text) }
        }
        _ = reopened.charts.map(\.categories)
        _ = reopened.documentProperties.title
        _ = reopened.slideMasters.map(\.layouts)

        let resaved = try reopened.serializedData()
        let before = try ZipReader(data: original)
        let after = try ZipReader(data: resaved)
        #expect(Set(after.entryNames) == Set(before.entryNames))
        for name in before.entryNames {
            #expect(try after.data(forEntry: name) == before.data(forEntry: name),
                    "\(name) changed on a read-only round trip")
        }
    }

    @Test func editingOneSlideLeavesOtherStreamsUntouched() throws {
        let deck = try Presentation()
        try deck.bulletSlide("One", ["a"])
        try deck.bulletSlide("Two", ["b"])
        let original = try deck.serializedData()

        let reopened = try Presentation(data: original)
        try reopened.slides[1].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(1)))
            .textFrame?.text = "added"
        let resaved = try reopened.serializedData()

        let before = try ZipReader(data: original)
        let after = try ZipReader(data: resaved)
        // Adding a shape touches exactly one slide part. No new parts, so the
        // content-types stream and every .rels must be byte-identical.
        for name in before.entryNames where name != "ppt/slides/slide2.xml" {
            #expect(try after.data(forEntry: name) == before.data(forEntry: name),
                    "\(name) changed when only a slide body was edited")
        }
    }

    /// Wrap `uncompressed` (< 65535 bytes) in a single final RFC 1951 BTYPE=00
    /// stored DEFLATE block. Valid method-8 input (`+5` bytes, well within the
    /// `+64` anti-bloat guard) that `ZipWriter.prepare` / `Deflate.deflate`
    /// never emits — if these exact compressed bytes survive a save, `Deflate`
    /// did not run on that entry.
    private func foreignStoredDeflatePayload(_ uncompressed: Data) -> ZipWriter.Payload {
        precondition(uncompressed.count <= 0xFFFF)
        let len = UInt16(uncompressed.count)
        let nlen = ~len
        var raw = Data([
            0x01,
            UInt8(len & 0xFF), UInt8(len >> 8),
            UInt8(nlen & 0xFF), UInt8(nlen >> 8),
        ])
        raw.append(uncompressed)
        return ZipWriter.Payload(
            data: raw,
            method: 8,
            size: UInt32(uncompressed.count),
            crc: CRC32.checksum(uncompressed)
        )
    }

    @Test func untouchedEntriesCopyForeignDeflateBitstreamWithoutReencodingEvenAcrossCacheEviction() throws {
        let built = try Presentation()
        try built.bulletSlide("Slide One", ["alpha"])
        try built.bulletSlide("Slide Two", ["beta"])
        let seed = try ZipReader(data: built.serializedData())

        // Re-wrap every entry in a foreign BTYPE=00 stored DEFLATE block that
        // Rostrum's encoder would never produce.
        var foreignWriter = ZipWriter()
        var expectedRawByName: [String: Data] = [:]
        for name in seed.entryNames {
            let decoded = try seed.data(forEntry: name)
            let payload = foreignStoredDeflatePayload(decoded)
            expectedRawByName[name] = payload.data
            foreignWriter.addFile(name: name, payload: payload)
        }
        let foreignArchive = try foreignWriter.finalize()

        let deck = try Presentation(data: foreignArchive)

        // 1. Mutate slide2's body only, plus perform net-zero edits on
        //    contentTypes and package rels (which must still restore their
        //    original compressed payloads), and flood streamCache past 4 MiB on
        //    slide2's .rels so any cache-backed pristine stream would be evicted.
        try deck.slides[1].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(1))
        ).textFrame?.text = "mutated slide two"

        deck.package.contentTypes.setOverride(
            partName: PackURI("/ppt/slides/slide99.xml"), contentType: ContentType.slide)
        deck.package.contentTypes.removeOverride(partName: PackURI("/ppt/slides/slide99.xml"))

        let tempRel = deck.package.rels.add(type: RelType.hyperlink, target: "https://example.com", isExternal: true)
        deck.package.rels.remove(rId: tempRel)

        let slide2Part = try deck.package.part(at: PackURI("/ppt/slides/slide2.xml"))
        var tempSlide2Rels: [String] = []
        let padding = String(repeating: "x", count: 32_768)
        for i in 0..<140 {
            // > 4.5 MiB of serialized .rels XML on slide2, forcing streamCache eviction.
            tempSlide2Rels.append(slide2Part.rels.add(
                type: RelType.hyperlink,
                target: "https://example.com/\(i)/\(padding)",
                isExternal: true
            ))
        }
        _ = try deck.serializedData()  // populates and overflows the 4 MiB streamCache

        // Revert slide2's temporary relationships back to its parsed state too.
        for rId in tempSlide2Rels {
            slide2Part.rels.remove(rId: rId)
        }

        let resaved = try ZipReader(data: deck.serializedData())
        for name in seed.entryNames {
            let loaded = try resaved.entryPayload(forEntry: name)
            if name == "ppt/slides/slide2.xml" {
                // Edited part ran through Rostrum's Deflate and shrunk below its uncompressed size.
                #expect(loaded.raw != expectedRawByName[name])
                #expect(loaded.raw.count < loaded.decoded.count)
            } else {
                // Every untouched part, .rels stream (including reverted slide2.xml.rels
                // and package _rels/.rels), and [Content_Types].xml copied the foreign
                // compressed bitstream byte-for-byte without running Deflate.
                #expect(loaded.entry.method == 8, "\(name) changed compression method")
                #expect(loaded.raw == expectedRawByName[name],
                        "\(name) did not copy its foreign compressed payload verbatim")
            }
        }
    }
}
