import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct InstalledFontsTests {
    private var dejavu: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
    }

    /// Owned test derivatives alter only style metadata, not glyphs. These
    /// exercise registration selection, not the visual accuracy of bold faces.
    private func variants<T>(_ body: ([FontFaceKey: URL], Data) throws -> T) throws -> T {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try Data(contentsOf: dejavu)
        func u16(_ data: Data, _ p: Int) -> Int { Int(data[p]) << 8 | Int(data[p + 1]) }
        func u32(_ data: Data, _ p: Int) -> Int { u16(data, p) << 16 | u16(data, p + 2) }
        let offset = try #require((0..<u16(original, 4)).map { 12 + 16 * $0 }.first {
            String(data: original[$0..<$0 + 4], encoding: .ascii) == "OS/2"
        }).advanced(by: 8)
        let selection = u32(original, offset) + 62
        var files: [FontFaceKey: URL] = [:]
        for style in InstalledFonts.styles {
            var data = original
            var flags = u16(data, selection) & ~0x261
            flags |= style.bold ? 0x20 : 0
            flags |= style.italic ? 1 : 0
            if !style.bold && !style.italic { flags |= 0x40 }
            data[selection] = UInt8(flags >> 8); data[selection + 1] = UInt8(flags & 255)
            let face = FontFaceKey(family: "DejaVu Sans", bold: style.bold, italic: style.italic)
            let url = directory.appendingPathComponent("\(style.bold)-\(style.italic).ttf")
            try data.write(to: url); files[face] = url
        }
        return try body(files, original)
    }

    @Test func validatesEachActualFaceAndLeavesPresentationBytesUnchanged() throws {
        try variants { files, _ in
            let deck = try Presentation(), before = try deck.serializedData()
            let session = InstalledFonts.Session(candidates: { face in files[face].map { [$0] } ?? [] })
            let result = session.register(in: deck, families: ["DejaVu Sans", "DEJAVU SANS"])
            #expect(result.missing.isEmpty && result.approximations.isEmpty)
            for style in InstalledFonts.styles {
                let metrics = try #require(deck.fonts.metrics(for: "DejaVu Sans", bold: style.bold, italic: style.italic))
                #expect(metrics.isBold == style.bold && metrics.isItalic == style.italic)
            }
            #expect(try deck.serializedData() == before)
        }
    }

    @Test func wrongFamilyAndWrongStyleNeverBecomeAliasesOrSyntheticFaces() throws {
        let deck = try Presentation()
        let session = InstalledFonts.Session(candidates: { _ in [dejavu] })
        let report = session.register(in: deck, families: ["A Font That Does Not Exist", "DejaVu Sans"])
        #expect(report.missing.count == 7)
        #expect(deck.fonts.metrics(for: "A Font That Does Not Exist") == nil)
        #expect(deck.fonts.metrics(for: "DejaVu Sans", bold: false, italic: false) != nil)
        #expect(deck.fonts.metrics(for: "DejaVu Sans", bold: true, italic: false) == nil)
        #expect(deck.fonts.metrics(for: "DejaVu Sans", bold: false, italic: true) == nil)
        #expect(report.approximations.isEmpty)
    }

    @Test func registeredEmbeddedFaceWinsAndMissingStylesCanStillBeAdded() throws {
        try variants { files, original in
            let deck = try Presentation()
            var embedded = original; embedded.append(contentsOf: [0x12, 0x34])
            try deck.fonts.register(embedded)
            let regular = FontFaceKey(family: "DejaVu Sans")
            let session = InstalledFonts.Session(candidates: { face in files[face].map { [$0] } ?? [] })
            #expect(session.register(in: deck, families: ["DejaVu Sans"]).missing.isEmpty)
            #expect(deck.fonts.data(for: regular) == embedded)
            #expect(deck.fonts.metrics(for: "DejaVu Sans", bold: true, italic: true) != nil)
        }
    }

    @Test func foundryAliasesRequireGenerationOptInAndCannotOverwriteEmbeddedNames() throws {
        let exact = try Presentation(), generated = try Presentation()
        let resolver = { (_: FontFaceKey) in [dejavu] }
        #expect(InstalledFonts.Session(candidates: resolver).register(in: exact, families: ["DejaVu Sans LT"]).missing.count == 4)
        #expect(exact.fonts.isEmpty)
        let report = InstalledFonts.Session(candidates: resolver).register(in: generated,
            families: ["DejaVu Sans", "DejaVu Sans LT"], allowFoundryAliases: true)
        #expect(generated.fonts.metrics(for: "DejaVu Sans LT", bold: false, italic: false) != nil)
        #expect(report.approximations.count == 1 && report.approximations[0].contains("Font substitution:"))
        #expect(report.missing.count == 6)

        let embedded = try Presentation(), bytes = try Data(contentsOf: dejavu)
        try embedded.fonts.register(bytes)
        let protected = InstalledFonts.Session(candidates: resolver).register(in: embedded,
            families: ["DejaVu Sans LT"], allowFoundryAliases: true)
        #expect(protected.missing.count == 4)
        #expect(embedded.fonts.metrics(for: "DejaVu Sans LT") == nil)
        #expect(embedded.fonts.data(for: FontFaceKey(family: "DejaVu Sans")) == bytes)
    }

    @Test func fileAndParseBudgetsRefuseWithoutMutatingRegistry() throws {
        for limits in [InstalledFonts.Session.Limits(files: 0), .init(bytes: 64), .init(bytesPerFile: 64), .init(faces: 0), .init(lookups: 0)] {
            let deck = try Presentation()
            let session = InstalledFonts.Session(candidates: { _ in [dejavu] }, limits: limits)
            #expect(session.register(in: deck, families: ["DejaVu Sans"]).missing.count == 4)
            #expect(deck.fonts.isEmpty)
        }
    }

    #if canImport(CoreText)
    @Test func localArialAndOfficeCalibriResolveAllRealStylesWhenAvailable() throws {
        for (family, directory, names) in [
            ("Arial", "/System/Library/Fonts/Supplemental", ["Arial.ttf", "Arial Bold.ttf", "Arial Italic.ttf", "Arial Bold Italic.ttf"]),
            ("Calibri", "/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts", ["Calibri.ttf", "Calibrib.ttf", "Calibrii.ttf", "Calibriz.ttf"])
        ] {
            let urls = names.map { URL(fileURLWithPath: directory).appendingPathComponent($0) }
            guard urls.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else { continue }
            let deck = try Presentation()
            #expect(InstalledFonts.register(in: deck, families: [family]).isEmpty)
            for (style, url) in zip(InstalledFonts.styles, urls) {
                let face = FontFaceKey(family: family, bold: style.bold, italic: style.italic)
                let metrics = try #require(deck.fonts.metrics(for: face))
                #expect(metrics.isBold == style.bold && metrics.isItalic == style.italic)
                #expect(deck.fonts.data(for: face) == (try Data(contentsOf: url)))
            }
        }
    }
    #endif
}
