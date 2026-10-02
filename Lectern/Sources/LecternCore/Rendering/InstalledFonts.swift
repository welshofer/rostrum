import Foundation
import Rostrum
#if canImport(CoreText)
import CoreText
#endif

/// Platform lookup belongs to Lectern, not Rostrum's deterministic registry.
/// A session validates the actual file's family and style before registration.
/// It never registers CoreText's fallback or a synthesized bold/italic face.
enum InstalledFonts {
    struct RegistrationReport: Equatable {
        var missing: [String] = []
        var approximations: [String] = []
    }

    static let styles: [(bold: Bool, italic: Bool)] = [(false, false), (true, false), (false, true), (true, true)]

    /// Exact family matching for imported decks. Existing registered faces,
    /// including embedded faces, take priority over machine-installed fonts.
    static func register(in presentation: Presentation, families: [String]) -> [String] {
        Session().register(in: presentation, families: families).missing
    }

    /// Only generation retains the older design-name foundry suffix fallback.
    /// Each alias is explicitly reported; inspection never opts into it.
    static func registerForGeneration(in presentation: Presentation, families: [String]) -> RegistrationReport {
        Session().register(in: presentation, families: families, allowFoundryAliases: true)
    }

    static func label(_ face: FontFaceKey) -> String {
        face.family + (face.bold ? " Bold" : "") + (face.italic ? " Italic" : "")
            + (!face.bold && !face.italic ? " Regular" : "")
    }

    struct Candidate {
        let url: URL
        let postScriptName: String?
        init(url: URL, postScriptName: String? = nil) { self.url = url; self.postScriptName = postScriptName }
    }

    final class Session {
        struct Limits {
            var files = 128
            var bytes = 128 * 1024 * 1024
            var bytesPerFile = 32 * 1024 * 1024
            var faces = 256
            var lookups = 1024
        }
        private struct ParsedFile {
            let data: Data
            let faces: [(index: Int, metrics: FontMetrics, postScriptNames: [String], styles: [String])]
        }
        private let candidates: ((FontFaceKey) -> [Candidate])?
        private let directories: [URL]
        private let limits: Limits
        private var listings: [URL: [URL]] = [:]
        private var parsedFiles: [URL: ParsedFile] = [:]
        private var rejected = Set<URL>()
        private var attemptedFiles = 0
        private var bytesRead = 0
        private var parsedFaces = 0
        private var lookupCount = 0

        /// Injectable paths exercise refusals without relying on installed fonts.
        init(candidates: ((FontFaceKey) -> [Candidate])? = nil,
             officeDirectories: [URL] = InstalledFonts.officeDirectories, limits: Limits = Limits()) {
            self.candidates = candidates; directories = officeDirectories; self.limits = limits
        }

        func register(in presentation: Presentation, families: [String],
                      allowFoundryAliases: Bool = false) -> RegistrationReport {
            var report = RegistrationReport()
            var owned: [FontFaceKey: (data: Data, index: Int)] = [:]
            let names = Set(families.filter { !$0.isEmpty }.map { $0.lowercased() }).sorted()
            for name in names {
                for style in InstalledFonts.styles {
                    let requested = FontFaceKey(family: name, bold: style.bold, italic: style.italic)
                    guard presentation.fonts.metrics(for: requested) == nil else { continue }
                    var registered = false
                    let families = allowFoundryAliases ? InstalledFonts.familyCandidates(for: name) : [name]
                    for family in families {
                        let face = FontFaceKey(family: family, bold: style.bold, italic: style.italic)
                        for candidate in candidateFiles(for: face) {
                            guard let file = parsed(candidate.url), let entry = file.faces.first(where: { entry in
                                entry.metrics.isBold == face.bold && entry.metrics.isItalic == face.italic
                                    && InstalledFonts.matchesStandardStyle(entry.styles, face: face)
                                    && (candidate.postScriptName.map { entry.postScriptNames.contains($0) } ?? true)
                                    && entry.metrics.familyNames.contains { $0.caseInsensitiveCompare(face.family) == .orderedSame }
                            }) else { continue }
                            // FontLibrary also installs the file's secondary names.
                            // Do not overwrite an embedded face through such an alias.
                            let keys = (entry.metrics.familyNames + [requested.family]).map {
                                FontFaceKey(family: $0, bold: face.bold, italic: face.italic)
                            }
                            guard keys.allSatisfy({ key in
                                presentation.fonts.metrics(for: key) == nil
                                    || (owned[key]?.data == file.data && owned[key]?.index == entry.index)
                            }), (try? presentation.fonts.register(file.data, aliases: [requested.family], fontIndex: entry.index)) != nil else { continue }
                            for key in keys { owned[key] = (file.data, entry.index) }
                            registered = true
                            if family != name {
                                report.approximations.append("Font substitution: \(InstalledFonts.label(requested)) uses \(InstalledFonts.label(face)); the requested family is unavailable.")
                            }
                            break
                        }
                        if registered { break }
                    }
                    if !registered { report.missing.append(InstalledFonts.label(requested)) }
                }
            }
            report.missing.sort(); report.approximations.sort()
            return report
        }

        private func candidateFiles(for face: FontFaceKey) -> [Candidate] {
            guard lookupCount < limits.lookups else { return [] }
            lookupCount += 1
            if let candidates { return Array(candidates(face).prefix(128)) }
            var result = InstalledFonts.systemFile(for: face).map { [$0] } ?? []
            let stem = face.family.replacingOccurrences(of: " ", with: "")
            for directory in directories {
                if listings[directory] == nil {
                    var files: [URL] = []
                    if let enumeration = FileManager.default.enumerator(at: directory,
                        includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
                        for _ in 0..<4096 {
                            guard let file = enumeration.nextObject() as? URL else { break }
                            if ["ttf", "otf", "ttc"].contains(file.pathExtension.lowercased()) { files.append(file) }
                        }
                    }
                    listings[directory] = files.sorted { $0.path < $1.path }
                }
                let ranked = listings[directory, default: []].sorted { a, b in
                    func rank(_ url: URL) -> Int {
                        let name = url.deletingPathExtension().lastPathComponent.lowercased()
                        return name == stem ? 0 : name.hasPrefix(stem) ? 1 : 2
                    }
                    let ar = rank(a), br = rank(b)
                    return ar == br ? a.path < b.path : ar < br
                }
                result.append(contentsOf: ranked.prefix(8).map { Candidate(url: $0) })
            }
            return result
        }

        private func parsed(_ source: URL) -> ParsedFile? {
            let url = source.standardizedFileURL
            if let cached = parsedFiles[url] { return cached }
            guard !rejected.contains(url), attemptedFiles < limits.files else { return nil }
            attemptedFiles += 1
            rejected.insert(url)
            let available = min(limits.bytesPerFile, limits.bytes - bytesRead)
            guard available > 0, let properties = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  properties.isRegularFile == true, let size = properties.fileSize, size > 0, size <= available,
                  let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            guard let data = try? handle.read(upToCount: available + 1), !data.isEmpty, data.count <= available else { return nil }
            bytesRead += data.count
            var faces: [(Int, FontMetrics, [String], [String])] = []
            for index in 0..<64 where parsedFaces < limits.faces {
                guard let metrics = try? FontMetrics(data: data, fontIndex: index) else { break }
                parsedFaces += 1
                let preferred = InstalledFonts.names(in: data, fontIndex: index, nameID: 17)
                let styles = preferred.isEmpty ? InstalledFonts.names(in: data, fontIndex: index, nameID: 2) : preferred
                faces.append((index, metrics, InstalledFonts.postScriptNames(in: data, fontIndex: index), styles))
            }
            guard !faces.isEmpty else { return nil }
            let file = ParsedFile(data: data, faces: faces)
            parsedFiles[url] = file
            return file
        }

        func firstFile(named name: String, system: Bool) -> URL? {
            for family in InstalledFonts.familyCandidates(for: name) {
                let face = FontFaceKey(family: family)
                let urls = system ? InstalledFonts.systemFile(for: face).map { [$0] } ?? [] : candidateFiles(for: face)
                for candidate in urls where parsed(candidate.url)?.faces.contains(where: {
                    !$0.metrics.isBold && !$0.metrics.isItalic
                        && $0.metrics.familyNames.contains { $0.caseInsensitiveCompare(family) == .orderedSame }
                }) == true { return candidate.url }
            }
            return nil
        }
    }

    private static func systemFile(for face: FontFaceKey) -> Candidate? {
        #if canImport(CoreText)
        let base = CTFontCreateWithName(face.family as CFString, 12, nil)
        let mask: CTFontSymbolicTraits = [.traitBold, .traitItalic]
        var traits: CTFontSymbolicTraits = []
        if face.bold { traits.insert(.traitBold) }
        if face.italic { traits.insert(.traitItalic) }
        guard let font = CTFontCreateCopyWithSymbolicTraits(base, 12, nil, traits, mask),
              (CTFontCopyFamilyName(font) as String).caseInsensitiveCompare(face.family) == .orderedSame else { return nil }
        guard let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL else { return nil }
        return Candidate(url: url, postScriptName: CTFontCopyPostScriptName(font) as String)
        #else
        return nil
        #endif
    }

    /// A bold flag also occurs on Black/ExtraBold. Only explicit standard
    /// subfamilies qualify, even with a resolved CoreText identity: registration
    /// also installs the typographic family alias, so a legacy Light/Regular
    /// family must not become the broader typographic family's Regular face.
    private static func matchesStandardStyle(_ names: [String], face: FontFaceKey) -> Bool {
        let accepted: Set<String>
        switch (face.bold, face.italic) {
        case (false, false): accepted = ["regular", "normal", "roman", "book"]
        case (true, false): accepted = ["bold"]
        case (false, true): accepted = ["italic", "oblique"]
        case (true, true): accepted = ["bolditalic", "boldoblique"]
        }
        return names.contains { accepted.contains($0.lowercased().filter { !$0.isWhitespace && $0 != "-" }) }
    }

    /// PostScript identity disambiguates faces in collections when Light/Book/
    /// Regular share family names and the same bold/italic bits. Offsets and
    /// record counts remain bounded independently of CoreText's descriptor.
    static func postScriptNames(in data: Data, fontIndex: Int) -> [String] {
        // OpenType recommends a 127-character maximum; name ID 6 uses printable
        // ASCII except [](){}<>/%. Bound decoding before allocating each string.
        // https://learn.microsoft.com/en-us/typography/opentype/spec/name
        names(in: data, fontIndex: fontIndex, nameID: 6).filter {
            $0.utf8.count <= 127 && $0.utf8.allSatisfy { byte in
                byte >= 33 && byte <= 126 && ![91, 93, 40, 41, 123, 125, 60, 62, 47, 37].contains(byte)
            }
        }
    }

    private static func names(in data: Data, fontIndex: Int, nameID: Int) -> [String] {
        func u16(_ p: Int) -> Int? {
            guard p >= 0, p <= data.count - 2 else { return nil }
            return Int(data[p]) << 8 | Int(data[p + 1])
        }
        func u32(_ p: Int) -> Int? {
            guard let high = u16(p), let low = u16(p + 2) else { return nil }
            return high << 16 | low
        }
        let base: Int
        if data.starts(with: [0x74, 0x74, 0x63, 0x66]) {
            guard let count = u32(8), fontIndex >= 0, fontIndex < min(count, 64),
                  let offset = u32(12 + fontIndex * 4) else { return [] }
            base = offset
        } else { guard fontIndex == 0 else { return [] }; base = 0 }
        guard let count = u16(base + 4), count <= 4096 else { return [] }
        for index in 0..<count {
            let record = base + 12 + index * 16
            guard record >= 0, record <= data.count - 16 else { return [] }
            guard data[record..<record + 4].elementsEqual([0x6E, 0x61, 0x6D, 0x65]) else { continue }
            guard let offset = u32(record + 8), let length = u32(record + 12),
                  length >= 6, offset <= data.count, length <= data.count - offset,
                  let records = u16(offset + 2), records <= 4096, records <= (length - 6) / 12,
                  let storage = u16(offset + 4), storage <= length else { return [] }
            var names: [String] = []
            for n in 0..<records {
                let p = offset + 6 + n * 12
                guard u16(p + 6) == nameID, let platform = u16(p),
                      let bytes = u16(p + 8), bytes <= (nameID == 6 ? 254 : 1024), let start = u16(p + 10),
                      start <= length - storage, bytes <= length - storage - start else { continue }
                let encoding: String.Encoding
                if platform == 0 || platform == 3 { encoding = .utf16BigEndian }
                else if platform == 1 { encoding = .macOSRoman }
                else { continue }
                let begin = offset + storage + start
                if let name = String(data: data[begin..<begin + bytes], encoding: encoding), !name.isEmpty, !names.contains(name) {
                    guard names.count < 32 else { return [] }
                    names.append(name)
                }
            }
            return names
        }
        return []
    }

    static func familyCandidates(for name: String) -> [String] {
        var candidates = [name], parts = name.split(separator: " ").map(String.init)
        while parts.count > 1, foundrySuffixes.contains(parts[parts.count - 1].uppercased()) {
            parts.removeLast(); candidates.append(parts.joined(separator: " "))
        }
        return candidates
    }

    private static let foundrySuffixes: Set<String> = ["LT", "MT", "ITC", "BT", "EF", "URW", "PS", "PT", "STD", "PRO", "COM", "W1G", "TT"]
    static var officeDirectories: [URL] {
        #if os(macOS)
        return ["/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts",
                "/Applications/Microsoft Word.app/Contents/Resources/DFonts",
                "/Applications/Microsoft Excel.app/Contents/Resources/DFonts", "/Library/Fonts/Microsoft"].map { URL(fileURLWithPath: $0) }
        #else
        return []
        #endif
    }
}
