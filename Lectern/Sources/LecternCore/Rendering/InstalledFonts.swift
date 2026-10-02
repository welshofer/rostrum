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
            let faces: [(index: Int, metrics: FontMetrics)]
        }
        private let candidates: ((FontFaceKey) -> [URL])?
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
        init(candidates: ((FontFaceKey) -> [URL])? = nil,
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
                        for url in candidateFiles(for: face) {
                            guard let file = parsed(url), let entry = file.faces.first(where: {
                                $0.metrics.isBold == face.bold && $0.metrics.isItalic == face.italic
                                    && $0.metrics.familyNames.contains { $0.caseInsensitiveCompare(face.family) == .orderedSame }
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

        private func candidateFiles(for face: FontFaceKey) -> [URL] {
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
                result.append(contentsOf: ranked.prefix(8))
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
            var faces: [(Int, FontMetrics)] = []
            for index in 0..<64 where parsedFaces < limits.faces {
                guard let metrics = try? FontMetrics(data: data, fontIndex: index) else { break }
                parsedFaces += 1
                faces.append((index, metrics))
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
                for url in urls where parsed(url)?.faces.contains(where: {
                    !$0.metrics.isBold && !$0.metrics.isItalic
                        && $0.metrics.familyNames.contains { $0.caseInsensitiveCompare(family) == .orderedSame }
                }) == true { return url }
            }
            return nil
        }
    }

    private static func systemFile(for face: FontFaceKey) -> URL? {
        #if canImport(CoreText)
        let base = CTFontCreateWithName(face.family as CFString, 12, nil)
        let mask: CTFontSymbolicTraits = [.traitBold, .traitItalic]
        var traits: CTFontSymbolicTraits = []
        if face.bold { traits.insert(.traitBold) }
        if face.italic { traits.insert(.traitItalic) }
        guard let font = CTFontCreateCopyWithSymbolicTraits(base, 12, nil, traits, mask),
              (CTFontCopyFamilyName(font) as String).caseInsensitiveCompare(face.family) == .orderedSame else { return nil }
        return CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL
        #else
        return nil
        #endif
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
