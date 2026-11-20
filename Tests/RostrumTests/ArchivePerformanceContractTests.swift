import Foundation
import Testing
@testable import Rostrum

@Suite struct ArchivePerformanceContractTests {
    @Test func lazyCacheStaysBoundedAndMaterializesLosslessly() throws {
        let p = try Presentation(); _ = try p.slides.add()
        let data = try p.serializedData()
        let archive = try OPCArchive(data: data, validation: .onAccess, cacheBytes: 2000)
        #expect(archive.cacheStatistics.retainedBytes == 0)
        for uri in archive.partURIs {
            _ = try archive.data(forPart: uri)
            #expect(archive.cacheStatistics.retainedBytes <= 2000)
        }
        let uri = try #require(archive.mainPartURI)
        _ = try archive.xml(forPart: uri)
        _ = try archive.xml(forPart: uri)
        #expect(archive.cacheStatistics.hits > 0)
        #expect(try archive.presentation().serializedData() == data)
        archive.clearCache()
        #expect(archive.cacheStatistics.retainedBytes == 0)
    }
    @Test func budgetsApplyBeforeLazyDecoding() throws {
        let bytes = try Presentation().serializedData()
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess, maximumEntryBytes: 0) }
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess, limits: .init(totalUncompressedBytes: 0)) }
    }
    @Test func lazyBudgetAlsoBoundsCompressedInputWithTinyDecodedOutput() throws {
        let reader = try ZipReader(data: Presentation().serializedData())
        var zip = ZipWriter()
        for name in reader.entryNames { zip.addFile(name: name, data: try reader.data(forEntry: name)) }
        var emptyBlocks = Data()
        for _ in 0..<3000 { emptyBlocks.append(contentsOf: [0, 0, 0, 255, 255]) }
        emptyBlocks.append(contentsOf: [1, 0, 0, 255, 255])
        zip.addFile(name: "ppt/media/padded.bin", payload: .init(data: emptyBlocks, method: 8, size: 0, crc: 0))
        let bytes = try zip.finalize()
        #expect(try ZipReader(data: bytes).data(forEntry: "ppt/media/padded.bin").isEmpty)
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess, maximumEntryBytes: 10000) }
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .strict, maximumEntryBytes: 10000) }
    }
    @Test func lazyOpenRejectsNamesThatWouldNormalizeToAnotherPart() throws {
        let reader = try ZipReader(data: Presentation().serializedData())
        var zip = ZipWriter()
        for name in reader.entryNames { zip.addFile(name: name, data: try reader.data(forEntry: name)) }
        zip.addFile(name: "ppt//unexpected.xml", data: Data("<unexpected/>".utf8))
        let bytes = try zip.finalize()
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess) }
        #expect(throws: RostrumError.self) { try Presentation(data: bytes) }
    }
    @Test func deferredCRCFailuresAreExplicitWhileEagerOpenStillThrows() throws {
        let p = try Presentation()
        let uri = PackURI("/ppt/media/bad.png")
        p.package.addPart(uri: uri, contentType: "image/png", blob: Data([1,2,3,4]))
        var data = try p.serializedData()
        let entry = try #require(ZipReader(data: data).allEntries.first { $0.name == uri.memberName })
        let offset = entry.localHeaderOffset
        let nameLength = Int(data[offset + 26]) + (Int(data[offset + 27]) << 8)
        let extraLength = Int(data[offset + 28]) + (Int(data[offset + 29]) << 8)
        data[offset + 30 + nameLength + extraLength] ^= 255
        let archive = try OPCArchive(data: data, validation: .onAccess)
        #expect(throws: RostrumError.self) { try archive.data(forPart: uri) }
        #expect(throws: RostrumError.self) { try OPCArchive(data: data, validation: .strict) }
        #expect(throws: RostrumError.self) { try Presentation(data: data) }
    }
    @Test func streamingAndCachedSavesAreByteIdenticalAndInvalidate() throws {
        let p = try Presentation()
        let text = try p.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(2))).textFrame!
        text.text = String(repeating: "compressible text ", count: 100)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rostrum-stream-\(UUID()).pptx")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = try p.serializedData()
        try p.save(to: url)
        #expect(try Data(contentsOf: url) == original)
        text.text = "changed"
        try p.save(to: url)
        #expect(try Data(contentsOf: url) == p.serializedData())
        #expect(try Data(contentsOf: url) != original)
        let reopened = try Presentation(contentsOf: url)
        #expect(try reopened.serializedData() == p.serializedData())
        // A name the reader cannot preserve must be rejected before publishing.
        p.package.addPart(uri: PackURI("/invalid.rels"), contentType: "x", blob: Data())
        let beforeFailure = try Data(contentsOf: url)
        #expect(throws: RostrumError.self) { try p.save(to: url) }
        #expect(try Data(contentsOf: url) == beforeFailure)
    }

    @Test func replacingPartReleasesOldCompressionCacheOwnershipImmediately() throws {
        let p = try Presentation()
        let uri = PackURI("/ppt/media/replaced.png")
        weak var oldPart: Part?
        do {
            let part = p.package.addPart(uri: uri, contentType: "image/png", blob: Data(repeating: 1, count: 100000))
            oldPart = part
            _ = try p.serializedData()
        }
        #expect(oldPart != nil)
        p.package.addPart(uri: uri, contentType: "image/png", blob: Data([2]))
        #expect(oldPart == nil)
        let reopened = try Presentation(data: p.serializedData())
        #expect(reopened.package.parts[uri]?.blob == Data([2]))
    }

    @Test func saveCannotReplaceADirectoryAndPreservesExistingFilePermissions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("rostrum-atomic-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let child = folder.appendingPathComponent("keep.txt")
        let original = Data("keep nested data".utf8)
        try original.write(to: child)
        let deck = try Presentation()
        #expect(throws: (any Error).self) { try deck.save(to: folder) }
        #expect(try Data(contentsOf: child) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["keep.txt"])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: child.path)
        try deck.save(to: child)
        let mode = try FileManager.default.attributesOfItem(atPath: child.path)[.posixPermissions] as? NSNumber
        #expect(mode?.intValue == 0o600)
        #expect(try Presentation(contentsOf: child).slideCount == deck.slideCount)
    }

    @Test func strictOpenVerifiesWithoutMaterializingUntouchedDeflatePartsAcrossEditAndSave() throws {
        let builder = try Presentation()
        let slide1 = try builder.slides[0]
        try slide1.shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(2))).textFrame?.text =
            String(repeating: "Slide one initial content. ", count: 80)
        let slide2 = try builder.slides.add()
        try slide2.shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(2))).textFrame?.text =
            String(repeating: "Slide two untouched content. ", count: 120)
        // Add a compressible SVG/media part that uses DEFLATE (method 8).
        let deflateMediaURI = PackURI("/ppt/media/diagram.svg")
        let svgBytes = Data(String(repeating: "<svg xmlns='http://www.w3.org/2000/svg'><rect width='10' height='10'/></svg>", count: 40).utf8)
        builder.package.addPart(uri: deflateMediaURI, contentType: "image/svg+xml", blob: svgBytes)
        builder.package.contentTypes.setDefault(extension: "svg", contentType: "image/svg+xml")
        builder.package.contentTypes.removeOverride(partName: deflateMediaURI)

        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        try slide2.shapes.addPicture(png, frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)))

        let archiveBytes = try builder.serializedData()
        let originalReader = try ZipReader(data: archiveBytes)
        let slide2Member = "ppt/slides/slide2.xml"
        #expect(try originalReader.entryPayload(forEntry: slide2Member).entry.method == 8)
        #expect(try originalReader.entryPayload(forEntry: deflateMediaURI.memberName).entry.method == 8)

        let deck = try Presentation(data: archiveBytes)
        let slide2Part = try deck.package.part(at: PackURI("/ppt/slides/slide2.xml"))
        let themePart = try deck.package.part(at: PackURI("/ppt/theme/theme1.xml"))
        let svgPart = try deck.package.part(at: deflateMediaURI)
        #expect(!slide2Part.isBlobMaterialized, "untouched DEFLATE slide must not allocate uncompressed Data at open")
        #expect(!themePart.isBlobMaterialized, "untouched DEFLATE theme must not allocate uncompressed Data at open")
        #expect(!svgPart.isBlobMaterialized, "untouched DEFLATE media must not allocate uncompressed Data at open")

        // Edit Slide 1, insert a distinct picture (triggering matchingMedia index build),
        // duplicate untouched Slide 2, and save.
        var distinctPNG = png
        distinctPNG.append(contentsOf: "distinct".utf8)
        try deck.slides[0].shapes.addPicture(distinctPNG, frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)))
        _ = try deck.slides.duplicate(at: 1)

        #expect(!slide2Part.isBlobMaterialized, "untouched Slide 2 stays unmaterialized across Slide 1 edit + duplicate")
        #expect(!svgPart.isBlobMaterialized, "untouched DEFLATE media stays unmaterialized across matchingMedia index build")

        let resaved = try deck.serializedData()
        #expect(!slide2Part.isBlobMaterialized, "untouched Slide 2 stays unmaterialized across serializedData()")
        #expect(!svgPart.isBlobMaterialized, "untouched DEFLATE media stays unmaterialized across serializedData()")

        let afterReader = try ZipReader(data: resaved)
        #expect(try afterReader.entryPayload(forEntry: slide2Member).raw
            == originalReader.entryPayload(forEntry: slide2Member).raw)
        #expect(try afterReader.entryPayload(forEntry: "ppt/slides/slide3.xml").raw
            == originalReader.entryPayload(forEntry: slide2Member).raw,
            "duplicated clean slide also reuses original compressed bitstream")
        #expect(try afterReader.entryPayload(forEntry: deflateMediaURI.memberName).raw
            == originalReader.entryPayload(forEntry: deflateMediaURI.memberName).raw)
    }

    @Test func onAccessPresentationSkipsUntouchedCodecsAndSurfacesExplicitErrorsOnRead() throws {
        let seed = try Presentation()
        _ = try seed.slides.add()
        let seedReader = try ZipReader(data: try seed.serializedData())

        let invalidDeflateRaw = Data([0x07, 0xDE, 0xAD, 0xBE, 0xEF]) // BTYPE=11 invalid DEFLATE
        let opaqueMethodRaw = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x01, 0x02])

        var writer = ZipWriter()
        for name in seedReader.entryNames {
            if name == "ppt/slides/slide2.xml" {
                writer.addFile(
                    name: name,
                    payload: ZipWriter.Payload(data: invalidDeflateRaw, method: 8, size: 128, crc: 0x1234_5678)
                )
            } else {
                let loaded = try seedReader.entryPayload(forEntry: name)
                writer.addFile(
                    name: name,
                    payload: ZipWriter.Payload(
                        data: loaded.raw,
                        method: loaded.entry.method,
                        size: UInt32(loaded.entry.uncompressedSize),
                        crc: loaded.entry.crc32
                    )
                )
            }
        }
        // Untouched carried entry with an unsupported compression method (Zstandard = 93).
        writer.addFile(
            name: "[trash]/opaque.zst",
            payload: ZipWriter.Payload(data: opaqueMethodRaw, method: 93, size: 64, crc: 0xABCD_EF01)
        )
        let archiveBytes = try writer.finalize()

        // Default `.strict` mode MUST still reject the archive at open time.
        #expect(throws: RostrumError.self) {
            _ = try Presentation(data: archiveBytes)
        }

        // Opt-in `.onAccess` skips codecs on untouched parts and carried entries,
        // allowing Slide 1 edits and verbatim passthrough save.
        let deck = try Presentation(data: archiveBytes, validation: .onAccess)
        try deck.slides[0].shapes.addTextBox(
            Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(1))
        ).textFrame?.text = "Edited Slide 1"
        let savedBytes = try deck.serializedData()

        let savedReader = try ZipReader(data: savedBytes)
        let savedSlide2 = try savedReader.rawEntryPayload(forEntry: "ppt/slides/slide2.xml")
        #expect(savedSlide2.entry.method == 8)
        #expect(savedSlide2.raw == invalidDeflateRaw, "untouched Slide 2 raw bytes copied without touching codec")
        let savedCarried = try savedReader.rawEntryPayload(forEntry: "[trash]/opaque.zst")
        #expect(savedCarried.entry.method == 93)
        #expect(savedCarried.raw == opaqueMethodRaw, "untouched carried entry copied with method 93 intact")

        // Importing Slide 1 into another presentation succeeds without decoding Slide 2,
        // whereas importing or duplicating Slide 2, validating, or reading Slide 2 throws cleanly.
        let merged = try Presentation()
        _ = try merged.slides.import(from: deck, at: 0)
        #expect(merged.slideCount == 2)

        #expect(throws: RostrumError.self) { _ = try deck.slides[1].part.decodedData() }
        #expect(throws: RostrumError.self) { _ = try deck.slides[1].part.dom() }
        #expect(throws: RostrumError.self) { _ = try deck.slides.duplicate(at: 1) }
        #expect(throws: RostrumError.self) { _ = try merged.slides.import(from: deck, at: 1) }
        #expect(throws: RostrumError.self) { _ = try deck.validate() }

        // Reading non-throwing `.blob` records a diagnostic and, if subsequently marked dirty,
        // refuses `serializedData()` rather than silently overwriting the corrupt part.
        let fallbackDeck = try Presentation(data: archiveBytes, validation: .onAccess)
        let corruptPart = try fallbackDeck.slides[1].part
        #expect(corruptPart.blob.isEmpty)
        #expect(fallbackDeck.readWarnings.contains { $0.contains("/ppt/slides/slide2.xml") })
        corruptPart.markDirty()
        #expect(throws: RostrumError.self) { _ = try fallbackDeck.serializedData() }
    }

    @Test func rfc1951StoredBlockFramingPreservedWhileEmptyBlockPaddingNormalized() throws {
        // Synthesize an incompressible stream divided into 16 KiB stored DEFLATE blocks
        // (matching zlib Z_SYNC_FLUSH / small-window stored framing: +5 B per 16 KiB = +100 B on 320 KiB,
        // which exceeds a flat +64 B cap while staying well within u + u/512 + 64).
        var original = Data(capacity: 320_000)
        var state: UInt64 = 0xCAFE_BABE_1234_5678
        for _ in 0..<320_000 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            original.append(UInt8(truncatingIfNeeded: state >> 33))
        }
        var framedRaw = Data()
        let chunkSize = 16_000
        var offset = 0
        while offset < original.count {
            let end = min(offset + chunkSize, original.count)
            let isFinal = end == original.count
            let len = UInt16(end - offset)
            let nlen = ~len
            framedRaw.append(isFinal ? 0x01 : 0x00)
            framedRaw.append(UInt8(len & 0xFF))
            framedRaw.append(UInt8(len >> 8))
            framedRaw.append(UInt8(nlen & 0xFF))
            framedRaw.append(UInt8(nlen >> 8))
            framedRaw.append(original.subdata(in: offset..<end))
            offset = end
        }
        #expect(framedRaw.count == original.count + 100) // > +64 B flat cap!

        let seedReader = try ZipReader(data: Presentation().serializedData())
        var writer = ZipWriter()
        for name in seedReader.entryNames {
            if name == "[Content_Types].xml" {
                var ct = try ContentTypesMap.parse(seedReader.data(forEntry: name))
                ct.setDefault(extension: "jpeg", contentType: ContentType.jpeg)
                writer.addFile(name: name, data: ct.serialized())
            } else {
                writer.addFile(name: name, data: try seedReader.data(forEntry: name))
            }
        }
        writer.addFile(
            name: "ppt/media/framed.jpeg",
            payload: ZipWriter.Payload(
                data: framedRaw,
                method: 8,
                size: UInt32(original.count),
                crc: CRC32.checksum(original)
            )
        )
        let resaved = try Presentation(data: writer.finalize()).serializedData()
        let loaded = try ZipReader(data: resaved).entryPayload(forEntry: "ppt/media/framed.jpeg")
        #expect(loaded.entry.method == 8)
        #expect(loaded.raw == framedRaw, "legitimate RFC 1951 stored-block framing must survive verbatim")
        #expect(loaded.decoded == original)
    }
}
