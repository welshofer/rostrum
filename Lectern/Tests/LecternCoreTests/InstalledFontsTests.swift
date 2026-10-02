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

    private func replacingNames(_ original: Data, values: [Int: String]) throws -> Data {
        func u16(_ p: Int) -> Int { Int(original[p]) << 8 | Int(original[p + 1]) }
        func u32(_ p: Int) -> Int { u16(p) << 16 | u16(p + 2) }
        func put(_ value: Int, _ bytes: Int, _ p: Int, _ data: inout Data) {
            for n in 0..<bytes { data[p + n] = UInt8((value >> ((bytes - n - 1) * 8)) & 255) }
        }
        let record = try #require((0..<u16(4)).map { 12 + $0 * 16 }.first {
            String(data: original[$0..<$0 + 4], encoding: .ascii) == "name"
        })
        let offset = u32(record + 8), count = u16(offset + 2), storage = offset + u16(offset + 4)
        var table = Data(repeating: 0, count: 6 + count * 12)
        put(count, 2, 2, &table); put(table.count, 2, 4, &table)
        let header = table.count
        for n in 0..<count {
            let from = offset + 6 + n * 12, to = 6 + n * 12
            table.replaceSubrange(to..<to + 12, with: original[from..<from + 12])
            let bytes: Data
            if let replacement = values[u16(from + 6)] {
                bytes = try #require(replacement.data(using: u16(from) == 1 ? .macOSRoman : .utf16BigEndian))
            } else { bytes = original[storage + u16(from + 10)..<storage + u16(from + 10) + u16(from + 8)] }
            put(bytes.count, 2, to + 8, &table); put(table.count - header, 2, to + 10, &table)
            table.append(bytes)
        }
        var result = original
        put(result.count, 4, record + 8, &result); put(table.count, 4, record + 12, &result)
        result.append(table)
        return result
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
            let styleName = style.bold ? (style.italic ? "Bold Italic" : "Bold") : (style.italic ? "Italic" : "Regular")
            data = try replacingNames(data, values: [2: styleName, 17: styleName])
            let face = FontFaceKey(family: "DejaVu Sans", bold: style.bold, italic: style.italic)
            let url = directory.appendingPathComponent("\(style.bold)-\(style.italic).ttf")
            try data.write(to: url); files[face] = url
        }
        return try body(files, original)
    }

    @Test func validatesEachActualFaceAndLeavesPresentationBytesUnchanged() throws {
        try variants { files, _ in
            let deck = try Presentation(), before = try deck.serializedData()
            let session = InstalledFonts.Session(candidates: { face in files[face].map { [.init(url: $0)] } ?? [] })
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
        let session = InstalledFonts.Session(candidates: { _ in [.init(url: dejavu)] })
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
            let session = InstalledFonts.Session(candidates: { face in files[face].map { [.init(url: $0)] } ?? [] })
            #expect(session.register(in: deck, families: ["DejaVu Sans"]).missing.isEmpty)
            #expect(deck.fonts.data(for: regular) == embedded)
            #expect(deck.fonts.metrics(for: "DejaVu Sans", bold: true, italic: true) != nil)
        }
    }

    @Test func foundryAliasesRequireGenerationOptInAndCannotOverwriteEmbeddedNames() throws {
        let exact = try Presentation(), generated = try Presentation()
        let resolver = { (_: FontFaceKey) in [InstalledFonts.Candidate(url: dejavu)] }
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
            let session = InstalledFonts.Session(candidates: { _ in [.init(url: dejavu)] }, limits: limits)
            #expect(session.register(in: deck, families: ["DejaVu Sans"]).missing.count == 4)
            #expect(deck.fonts.isEmpty)
        }
    }

    @Test func collectionSelectionUsesTheResolvedPostScriptFaceNotTheFirstRegularFace() throws {
        let original = try Data(contentsOf: dejavu)
        func u16(_ data: Data, _ p: Int) -> Int { Int(data[p]) << 8 | Int(data[p + 1]) }
        func u32(_ data: Data, _ p: Int) -> Int { u16(data, p) << 16 | u16(data, p + 2) }
        func put32(_ value: Int, at p: Int, in data: inout Data) {
            for n in 0..<4 { data[p + n] = UInt8((value >> ((3 - n) * 8)) & 255) }
        }
        func table(_ tag: String, _ data: Data) throws -> Int {
            let record = try #require((0..<u16(data, 4)).map { 12 + $0 * 16 }.first {
                String(data: data[$0..<$0 + 4], encoding: .ascii) == tag
            })
            return u32(data, record + 8)
        }
        var wrong = original
        let head = try table("head", wrong)
        wrong[head + 18] = 4; wrong[head + 19] = 0 // 1024 UPEM identifies the wrong face.
        let name = try table("name", wrong), storage = u16(wrong, name + 4)
        for n in 0..<u16(wrong, name + 2) {
            let p = name + 6 + n * 12
            guard u16(wrong, p + 6) == 6, u16(wrong, p + 8) > 1 else { continue }
            let start = name + storage + u16(wrong, p + 10)
            wrong[start + (u16(wrong, p) == 1 ? 0 : 1)] = 88 // X replaces the first letter.
        }
        var collection = Data([0x74, 0x74, 0x63, 0x66, 0, 1, 0, 0, 0, 0, 0, 2] + Array(repeating: 0, count: 8))
        for (index, source) in [wrong, original].enumerated() {
            while collection.count % 4 != 0 { collection.append(0) }
            let base = collection.count
            put32(base, at: 12 + index * 4, in: &collection)
            var font = source
            for n in 0..<u16(font, 4) {
                let p = 12 + n * 16 + 8
                put32(u32(font, p) + base, at: p, in: &font)
            }
            collection.append(font)
        }
        #expect(!InstalledFonts.postScriptNames(in: collection, fontIndex: 0).contains("DejaVuSans"))
        #expect(InstalledFonts.postScriptNames(in: collection, fontIndex: 1).contains("DejaVuSans"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ttc")
        try collection.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let deck = try Presentation()
        let report = InstalledFonts.Session(candidates: { _ in [.init(url: url, postScriptName: "DejaVuSans")] })
            .register(in: deck, families: ["DejaVu Sans"])
        #expect(report.missing.count == 3)
        #expect(deck.fonts.metrics(for: "DejaVu Sans", bold: false, italic: false)?.unitsPerEm == 2048)
        let refused = try Presentation()
        #expect(InstalledFonts.Session(candidates: { _ in [.init(url: url, postScriptName: "AbsentFace")] })
            .register(in: refused, families: ["DejaVu Sans"]).missing.count == 4)
        #expect(refused.fonts.isEmpty)
        for data in [Data(), Data([0x74, 0x74, 0x63, 0x66]), collection.prefix(30)] {
            #expect(InstalledFonts.postScriptNames(in: data, fontIndex: 1).isEmpty)
        }
    }

    @Test func officeFallbackRejectsBlackFaceEvenWithMatchingFamilyAndBoldFlag() throws {
        try variants { files, _ in
            let bold = try #require(files[FontFaceKey(family: "DejaVu Sans", bold: true)])
            let black = bold.deletingLastPathComponent().appendingPathComponent("00-Black.ttf")
            try replacingNames(Data(contentsOf: bold), values: [2: "Black", 17: "Black"]).write(to: black)
            let deck = try Presentation()
            let report = InstalledFonts.Session(candidates: { _ in [.init(url: black), .init(url: bold)] })
                .register(in: deck, families: ["DejaVu Sans"])
            #expect(report.missing.count == 3)
            #expect(deck.fonts.data(for: FontFaceKey(family: "DejaVu Sans", bold: true)) == (try Data(contentsOf: bold)))
            let refused = try Presentation()
            #expect(InstalledFonts.Session(candidates: { _ in [.init(url: black, postScriptName: "DejaVuSans")] })
                .register(in: refused, families: ["DejaVu Sans"]).missing.count == 4)
        }
    }

    @Test func splitLegacyFamilyCannotPolluteTypographicRegularAlias() throws {
        let original = try Data(contentsOf: dejavu)
        let light = try replacingNames(original, values: [1: "DejaVu Sans Light", 2: "Regular", 16: "DejaVu Sans", 17: "Light"])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ttf")
        try light.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let deck = try Presentation()
        let report = InstalledFonts.Session(candidates: { _ in [.init(url: url, postScriptName: "DejaVuSans")] })
            .register(in: deck, families: ["DejaVu Sans Light", "DejaVu Sans"])
        #expect(report.missing.count == 8)
        #expect(deck.fonts.isEmpty)
    }

    @Test func postScriptMetadataRejectsOversizeAndInvalidNames() throws {
        let bytes = try Data(contentsOf: dejavu)
        for name in [String(repeating: "A", count: 128), "Bad Name", "Bad/Name", "", "Éclair"] {
            let changed = try replacingNames(bytes, values: [6: name])
            #expect(InstalledFonts.postScriptNames(in: changed, fontIndex: 0).isEmpty)
        }
        let maximum = String(repeating: "A", count: 127)
        #expect(InstalledFonts.postScriptNames(in: try replacingNames(bytes, values: [6: maximum]), fontIndex: 0) == [maximum])
    }

    #if canImport(CoreText)
    @Test func localArialAndOfficeCalibriResolveAllRealStylesWhenAvailable() throws {
        for (family, directory, names) in [
            ("Arial", "/System/Library/Fonts/Supplemental", ["Arial.ttf", "Arial Bold.ttf", "Arial Italic.ttf", "Arial Bold Italic.ttf"]),
            ("Calibri", "/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts", ["Calibri.ttf", "Calibrib.ttf", "Calibrii.ttf", "Calibriz.ttf"]),
            ("Aptos", "/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts", ["Aptos.ttf", "Aptos-Bold.ttf", "Aptos-Italic.ttf", "Aptos-Bold-Italic.ttf"])
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
