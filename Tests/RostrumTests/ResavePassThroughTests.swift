import Foundation
import Testing
@testable import Rostrum

/// PERF-1: an open → save round trip streams every untouched entry back as
/// the archive stored it, instead of inflating and re-DEFLATEing it.
///
/// The structural claim is what these tests pin down: which path each part
/// takes (`Part.originalPayload`), that the two paths agree byte-for-byte on
/// Rostrum's own output, that an edit — and only an edit — forces a fresh
/// compression, and that the pass-through never skips the reader's
/// validation. `/usr/bin/unzip` is the external oracle for the archives.
@Suite struct ResavePassThroughTests {

    // MARK: - Helpers

    private static let realDecks: URL =
        (Bundle.module.resourceURL ?? Bundle.module.bundleURL)
        .appendingPathComponent("Fixtures/RealDecks", isDirectory: true)

    /// A deck every one of whose entries was DEFLATEd by Rostrum's own writer.
    ///
    /// `Presentation()` starts from a bundled template, and an untouched part
    /// of THAT would now pass through with whatever encoding the template
    /// carries. Re-preparing every part once gives a baseline whose bytes are
    /// Rostrum's compressor's, which is what makes "pass-through equals
    /// recompress" a byte-identity rather than a content-identity claim.
    private static func rostrumAuthoredDeck() throws -> Data {
        let authored = try Presentation()
        _ = try authored.slides.add()
        let box = try authored.slides[0].shapes.addTextBox(
            Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(2)))
        box.textFrame?.text = String(repeating: "pass-through baseline text ", count: 40)
        let reopened = try OPCPackage.read(data: try authored.serializedData())
        Self.forceRecompression(of: reopened)
        return try reopened.serialize()
    }

    /// Bump every part's blob revision without changing its bytes: the
    /// pass-through payload is dropped and the writer must compress afresh.
    private static func forceRecompression(of package: OPCPackage) {
        for part in package.parts.values { part.replaceBlob(part.blob) }
    }

    private static func writeTemp(_ data: Data, ext: String = "pptx") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-passthrough-\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        return url
    }

    private static func unzipTest(_ data: Data) throws -> Int32 {
        let url = try writeTemp(data)
        defer { try? FileManager.default.removeItem(at: url) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", url.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static func payloads(_ data: Data) throws -> [String: ZipReader.CompressedPayload?] {
        let zip = try ZipReader(data: data)
        var result: [String: ZipReader.CompressedPayload?] = [:]
        for name in zip.entryNames { result[name] = try zip.compressedPayload(forEntry: name) }
        return result
    }

    // MARK: - (a) Pass-through and recompression agree byte for byte

    @Test func untouchedDeckSavesByteIdenticallyWhetherPassedThroughOrRecompressed() throws {
        let baseline = try Self.rostrumAuthoredDeck()

        let passThrough = try OPCPackage.read(data: baseline)
        for (uri, part) in passThrough.parts {
            #expect(part.originalPayload != nil, "\(uri.value) was read without its stored entry")
        }
        let viaPassThrough = try passThrough.serialize()

        let recompressed = try OPCPackage.read(data: baseline)
        Self.forceRecompression(of: recompressed)
        for (uri, part) in recompressed.parts {
            #expect(part.originalPayload == nil, "\(uri.value) kept a pass-through payload after its blob changed")
        }
        let viaRecompression = try recompressed.serialize()

        #expect(viaPassThrough == viaRecompression, "the two writer paths disagree on an unmodified deck")
        #expect(viaPassThrough == baseline, "an unmodified resave is not a fixed point")
        #expect(try Self.unzipTest(viaPassThrough) == 0)
    }

    @Test func passThroughOutputIsDeterministicAcrossSavesAndOpens() throws {
        let baseline = try Self.rostrumAuthoredDeck()
        let package = try OPCPackage.read(data: baseline)
        let first = try package.serialize()
        let second = try package.serialize()
        let fresh = try OPCPackage.read(data: baseline).serialize()
        #expect(first == second)
        #expect(first == fresh)
    }

    @Test func streamingSaveUsesTheSamePassThroughBytes() throws {
        let baseline = try Self.rostrumAuthoredDeck()
        let package = try OPCPackage.read(data: baseline)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-passthrough-stream-\(UUID().uuidString).pptx")
        defer { try? FileManager.default.removeItem(at: url) }
        try package.writeAtomically(to: url)
        #expect(try Data(contentsOf: url) == baseline)
    }

    // MARK: - (b) An edited part is recompressed; its neighbours are not

    @Test func editedPartIsRecompressedWhileUntouchedPartsPassThrough() throws {
        let baseline = try Self.rostrumAuthoredDeck()
        let before = try Self.payloads(baseline)

        let deck = try Presentation(data: baseline)
        let slide = try deck.slides[0]
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(3), width: .inches(4), height: .inches(1)))
        box.textFrame?.text = "edited after reopening"
        let slidePart = slide.part
        #expect(slidePart.isDirty, "the facade edit must have flipped authority to the DOM")
        #expect(slidePart.originalPayload == nil, "markDirty() must drop the pass-through payload")

        let saved = try deck.serializedData()
        let after = try Self.payloads(saved)
        let slideName = slidePart.uri.memberName

        let originalSlide = try #require(before[slideName] ?? nil)
        let savedSlide = try #require(after[slideName] ?? nil)
        #expect(savedSlide.data != originalSlide.data, "the edited slide's entry was not re-compressed")
        #expect(savedSlide.crc32 != originalSlide.crc32)

        // Every entry that is not the edited slide, its rels, or the
        // presentation-level streams Rostrum re-serializes on save must be
        // the archive's own bytes again.
        var passedThrough = 0
        for (name, originalPayload) in before where name != slideName && name.hasSuffix(".xml")
            && !name.hasSuffix(".rels") && name != PackURI.contentTypes.memberName {
            let original = try #require(originalPayload)
            let resaved = try #require(after[name] ?? nil)
            #expect(resaved.data == original.data, "\(name) changed on resave though it was never edited")
            #expect(resaved.method == original.method)
            #expect(resaved.crc32 == original.crc32)
            passedThrough += 1
        }
        #expect(passedThrough > 0)
        #expect(try Self.unzipTest(saved) == 0)
        #expect(try Presentation(data: saved).slides[0].shapes.count == slide.shapes.count)
    }

    @Test func replacingABlobDropsThePassThroughPayload() throws {
        let baseline = try Self.rostrumAuthoredDeck()
        let package = try OPCPackage.read(data: baseline)
        let part = try package.mainDocumentPart()
        #expect(part.originalPayload != nil)
        part.replaceBlob(part.blob + Data(" ".utf8))
        #expect(part.originalPayload == nil)
        let saved = try package.serialize()
        let resaved = try #require(try ZipReader(data: saved).compressedPayload(forEntry: part.uri.memberName))
        let original = try #require(try ZipReader(data: baseline).compressedPayload(forEntry: part.uri.memberName))
        #expect(resaved.data != original.data)
    }

    // MARK: - Foreign archives keep their own encoding

    /// Keynote DEFLATEs its JPEGs; `storedExtensions` would STORE them. The
    /// pass-through keeps the archive's method and its exact stream.
    @Test func foreignDeckEntriesKeepTheirOriginalMethodAndStream() throws {
        let url = Self.realDecks.appendingPathComponent("FromKeynote.pptx")
        let original = try Data(contentsOf: url)
        let resaved = try Presentation(data: original).serializedData()
        let before = try Self.payloads(original)
        let after = try Self.payloads(resaved)

        var deflatedMedia = 0
        for (name, payload) in before where name.hasPrefix("ppt/media/") {
            let originalPayload = try #require(payload, "\(name): Keynote wrote no data descriptor, so it must pass through")
            let resavedPayload = try #require(after[name] ?? nil)
            #expect(resavedPayload.method == originalPayload.method, "\(name): method changed on resave")
            #expect(resavedPayload.data == originalPayload.data, "\(name): stream changed on resave")
            if originalPayload.method == 8 { deflatedMedia += 1 }
        }
        #expect(deflatedMedia > 0, "the fixture no longer exercises a DEFLATEd media entry")
        #expect(try Self.unzipTest(resaved) == 0)
    }

    /// Google Slides streams every entry with a data descriptor. The reader
    /// decodes them (the central directory is authoritative) but declines to
    /// vouch for them verbatim, so the writer compresses the decoded bytes.
    @Test func dataDescriptorEntriesFallBackToRecompression() throws {
        let url = Self.realDecks.appendingPathComponent("FromGoogleSlides.pptx")
        let original = try Data(contentsOf: url)
        let reader = try ZipReader(data: original)
        for name in reader.entryNames {
            #expect(try reader.compressedPayload(forEntry: name) == nil, "\(name) should not pass through")
            #expect(!(try reader.data(forEntry: name)).isEmpty || name.hasSuffix("/"))
        }
        let package = try OPCPackage.read(data: original)
        for (uri, part) in package.parts {
            #expect(part.originalPayload == nil, "\(uri.value) must take the recompression path")
        }
        let resaved = try package.serialize()
        #expect(try ZipReader(data: resaved).compressedPayload(forEntry: "ppt/presentation.xml") != nil)
        #expect(try Self.unzipTest(resaved) == 0)
        #expect(try Presentation(data: resaved).slides.count == (try Presentation(data: original)).slides.count)
    }

    // MARK: - Carried untyped entries

    @Test func carriedUntypedEntryPassesThroughVerbatim() throws {
        let deck = try Presentation()
        let reader = try ZipReader(data: try deck.serializedData())
        var zip = ZipWriter()
        for name in reader.entryNames { zip.addFile(name: name, data: try reader.data(forEntry: name)) }
        let trash = Data(String(repeating: "trash that compresses well ", count: 200).utf8)
        zip.addFile(name: "[trash]/0000.dat", data: trash)
        let archive = try zip.finalize()

        let package = try OPCPackage.read(data: archive)
        let carried = try #require(package.untypedEntries.first { $0.name == "[trash]/0000.dat" })
        let carriedPayload = try #require(carried.payload)
        #expect(carriedPayload.method == 8)
        let resaved = try package.serialize()
        let original = try #require(try ZipReader(data: archive).compressedPayload(forEntry: "[trash]/0000.dat"))
        let again = try #require(try ZipReader(data: resaved).compressedPayload(forEntry: "[trash]/0000.dat"))
        #expect(again.data == original.data)
        #expect(again.method == original.method)
        #expect(try ZipReader(data: resaved).data(forEntry: "[trash]/0000.dat") == trash)
    }

    // MARK: - The pass-through never skips validation

    @Test func compressedPayloadValidatesExactlyLikeData() throws {
        var zip = ZipWriter()
        let text = Data(String(repeating: "validated ", count: 500).utf8)
        zip.addFile(name: "note.txt", data: text)
        var archive = try zip.finalize()

        let intact = try ZipReader(data: archive)
        let payload = try #require(try intact.compressedPayload(forEntry: "note.txt"))
        #expect(payload.method == 8)
        #expect(payload.uncompressedSize == text.count)
        #expect(payload.crc32 == CRC32.checksum(text))
        #expect(payload.data == archive[30 + "note.txt".utf8.count..<30 + "note.txt".utf8.count + payload.data.count])
        #expect(try Inflate.inflate(payload.data, expectedOutputSize: text.count) == text)

        // Corrupt one byte of the DEFLATE stream: both reads must refuse it,
        // because a pass-through that handed back a stream the CRC rejects
        // would write corruption into the next file.
        archive[30 + "note.txt".utf8.count + 5] ^= 0xFF
        let corrupt = try ZipReader(data: archive)
        #expect(throws: RostrumError.self) { try corrupt.data(forEntry: "note.txt") }
        #expect(throws: RostrumError.self) { try corrupt.compressedPayload(forEntry: "note.txt") }
        #expect(throws: RostrumError.self) { try OPCPackage.read(data: archive) }
    }

    @Test func storedEntryPayloadSharesTheDecodedBytes() throws {
        var zip = ZipWriter()
        let bytes = Data((0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 2654435761) })
        zip.addFile(name: "ppt/media/image1.png", data: bytes, compress: false)
        let reader = try ZipReader(data: try zip.finalize())
        let payload = try #require(try reader.compressedPayload(forEntry: "ppt/media/image1.png"))
        #expect(payload.method == 0)
        #expect(payload.data == bytes)
        #expect(payload.uncompressedSize == bytes.count)
    }
}
