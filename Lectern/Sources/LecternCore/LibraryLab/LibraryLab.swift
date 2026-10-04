import Foundation
import Rostrum

/// A completed, file-backed demonstration. Only values cross into the app.
public struct LibraryLabResult: Sendable {
    public let id: LibraryDemoID
    public let options: LibraryLabOptions
    public let directory: URL
    public let beforeURL: URL?
    public let afterURL: URL
    public let reportURL: URL
    public let markdownURL: URL
    public let artifacts: [URL]
    public let coverSVG: String?
    public let coverSlideNumber: Int?
    public let slideCount: Int
    public let checks: [LibraryLabCheck]
    public let findings: [LibraryLabFinding]
    public let elapsedSeconds: Double
    public var passed: Bool { !checks.isEmpty && checks.allSatisfy(\.passed) }
}

/// Preview limitations retain their source locations in the exported report.
public struct LibraryLabFinding: Sendable, Codable, Equatable {
    public let stage: String
    public let slideNumber: Int?
    public let code: String
    public let message: String
    public let partURI: String?
    public let shapeID: String?
    public let path: String?
}

public enum LibraryLabError: Error, LocalizedError {
    case invalidOptions(String)
    case invalidArtifactName(String)

    public var errorDescription: String? {
        switch self {
        case .invalidOptions(let message): message
        case .invalidArtifactName(let name): "Invalid demonstration artifact name: \(name)"
        }
    }
}

public enum LibraryLab {
    public static let catalog: [LibraryLabRecipe] = {
        let recipes = DrawingLabRecipes.catalog + DocumentLabRecipes.catalog + PlatformLabRecipes.catalog
        return LibraryDemoID.allCases.compactMap { id in recipes.first { $0.id == id } }
    }()

    /// Synchronous and CPU-bound; run off the main actor. Each invocation owns
    /// a fresh directory, and removes only that directory on error/cancellation.
    public static func run(_ id: LibraryDemoID, options: LibraryLabOptions = .init(),
                           in parent: URL) throws -> LibraryLabResult {
        // Hidden controls from another recipe must neither affect this example
        // nor prevent it running. Reports record only the effective inputs.
        let options = effectiveOptions(options, for: id)
        return try perform(id, options: options, in: parent) { try make(id, options: options) }
    }

    public static func effectiveOptions(_ options: LibraryLabOptions, for id: LibraryDemoID) -> LibraryLabOptions {
        let inputs = catalog.first { $0.id == id }!.inputs
        let defaults = LibraryLabOptions()
        return .init(text: inputs.contains(.text) ? options.text : defaults.text,
                     accentHex: inputs.contains(.accent) ? options.accentHex : defaults.accentHex,
                     sampleSize: inputs.contains(.sampleSize) ? options.sampleSize : defaults.sampleSize,
                     alternative: inputs.contains(.alternative) ? options.alternative : defaults.alternative)
    }

    static func perform(_ id: LibraryDemoID, options: LibraryLabOptions, in parent: URL,
                        build: () throws -> LibraryLabDraft) throws -> LibraryLabResult {
        try validate(options)
        try Task.checkCancellation()
        let start = Date()
        let draft = try build()
        try Task.checkCancellation()
        let location = parent.appendingPathComponent(id.rawValue + "-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        // Directory enumeration resolves /var to /private/var on macOS. Keep
        // every artifact URL in the same canonical form for identity/sharing.
        let directory = location.resolvingSymlinksInPath()
        do {
            var checks = draft.checks
            var beforeURL: URL?
            if let before = draft.before {
                let kind = try Presentation(data: before).documentKind
                let url = directory.appendingPathComponent(id.rawValue + "-before." + fileExtension(kind))
                try before.write(to: url, options: .atomic)
                beforeURL = url
            }
            let afterURL = directory.appendingPathComponent(id.rawValue + "." + fileExtension(draft.deck.documentKind))
            try draft.deck.save(to: afterURL)
            let data = try Data(contentsOf: afterURL)
            checks.append(.init("Repeated serialization", try draft.deck.serializedData() == data,
                                "Saving this document twice produces the same bytes."))
            let reopened = try Presentation(data: data,
                limits: .init(totalUncompressedBytes: DeckInspector.defaultReadLimit))
            checks.append(.init("Save and reopen", try reopened.serializedData() == data,
                                "The saved document reopens and survives a no-edit round trip byte for byte."))
            checks += try draft.verify(reopened)
            for (name, bytes) in draft.extraFiles.sorted(by: { $0.key < $1.key }) {
                guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
                      name != afterURL.lastPathComponent, name != beforeURL?.lastPathComponent,
                      name != "report.json", name != "previews", name != "extracted" else {
                    throw LibraryLabError.invalidArtifactName(name)
                }
                try Task.checkCancellation()
                try bytes.write(to: directory.appendingPathComponent(name), options: .atomic)
            }
            let lint = try reopened.validate().map { $0.description }
            let inspection = try DeckInspector.inspect(deckAt: afterURL)
            checks.append(.init("Required-attribute lint", lint.isEmpty,
                                lint.isEmpty ? "No missing required attributes. This is not full Office validation."
                                    : lint.joined(separator: "\n")))
            let previews = directory.appendingPathComponent("previews", isDirectory: true)
            try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: false)
            for (offset, svg) in inspection.previews.enumerated() {
                try Task.checkCancellation()
                let name = String(format: "slide-%02d.svg", inspection.previewSlideNumbers[offset])
                try svg.write(to: previews.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }
            var findings = inspection.previewDiagnostics.flatMap { self.findings(from: $0, stage: "Slide preview") }
            for message in inspection.readWarnings + inspection.outlineWarnings {
                findings.append(.init(stage: "Inspection", slideNumber: nil, code: "inspection", message: message,
                                      partURI: nil, shapeID: nil, path: nil))
            }
            for slide in inspection.slides where slide.hasNotesPage {
                try Task.checkCancellation()
                do {
                    let notes = try DeckInspector.inspectNotesPage(deckAt: afterURL, slideNumber: slide.number)
                    try notes.svg.write(to: previews.appendingPathComponent(String(format: "notes-%02d.svg", slide.number)),
                                        atomically: true, encoding: .utf8)
                    findings += self.findings(from: notes.diagnostics, stage: "Notes preview")
                } catch is CancellationError { throw CancellationError() }
                catch {
                    findings.append(.init(stage: "Notes preview", slideNumber: slide.number, code: "renderFailure",
                                          message: String(describing: error), partURI: nil, shapeID: nil, path: nil))
                }
            }
            let export = try DeckExporter.export(deckAt: afterURL, into: directory.appendingPathComponent("extracted"))
            for message in export.warnings {
                findings.append(.init(stage: "Export", slideNumber: nil, code: "export", message: message,
                                      partURI: nil, shapeID: nil, path: nil))
            }
            checks.append(.init("Extracted document", export.slideCount == inspection.slideCount,
                                "Exported \(export.slideCount) slides, \(export.assetsWritten) assets and \(export.chartsWritten) chart datasets."))
            try Task.checkCancellation()
            let elapsed = Date().timeIntervalSince(start)
            let recipe = catalog.first { $0.id == id }!
            let report = LibraryLabReport(recipe: id, title: recipe.title, options: options,
                operations: recipe.operations, limitations: recipe.limitations, slideCount: inspection.slideCount,
                checks: checks, findings: findings, elapsedSeconds: elapsed)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let reportURL = directory.appendingPathComponent("report.json")
            try encoder.encode(report).write(to: reportURL, options: .atomic)
            try Task.checkCancellation()
            let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            var artifacts: [URL] = []
            while let url = enumerator?.nextObject() as? URL {
                if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                    artifacts.append(url.resolvingSymlinksInPath())
                }
            }
            return LibraryLabResult(id: id, options: options, directory: directory, beforeURL: beforeURL, afterURL: afterURL,
                reportURL: reportURL, markdownURL: export.markdownFile, artifacts: artifacts.sorted { $0.path < $1.path }, coverSVG: inspection.previews.first,
                coverSlideNumber: inspection.previewSlideNumbers.first, slideCount: inspection.slideCount, checks: checks, findings: findings, elapsedSeconds: elapsed)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    static func validate(_ options: LibraryLabOptions) throws {
        guard !options.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, options.text.count <= 240 else {
            throw LibraryLabError.invalidOptions("Enter between 1 and 240 characters of sample text.")
        }
        guard options.accentHex.utf8.count == 6,
              options.accentHex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else {
            throw LibraryLabError.invalidOptions("Use six hexadecimal digits for the accent color, such as 276D89.")
        }
        guard (2...12).contains(options.sampleSize) else {
            throw LibraryLabError.invalidOptions("Choose a sample size between 2 and 12.")
        }
    }

    private static func make(_ id: LibraryDemoID, options: LibraryLabOptions) throws -> LibraryLabDraft {
        switch id {
        case .shapes, .fillsAndLines, .text, .pictures, .tableStructure, .tableStyles, .tableAppearance:
            try DrawingLabRecipes.make(id, options: options)
        case .slides, .charts, .chartEditing, .smartArt, .notes, .comments, .sections, .slideImport:
            try DocumentLabRecipes.make(id, options: options)
        case .layouts, .fontsAndFitting, .paragraphLayout, .tabLayout, .theme, .templates, .design, .mediaAndAttachments, .package, .extractionAndRendering:
            try PlatformLabRecipes.make(id, options: options)
        }
    }

    private static func fileExtension(_ kind: DocumentKind) -> String {
        switch kind { case .presentation: "pptx"; case .template: "potx"; case .slideShow: "ppsx" }
    }

    private static func findings(from diagnostics: SlidePreviewDiagnostics, stage: String) -> [LibraryLabFinding] {
        var result = diagnostics.issues.map {
            LibraryLabFinding(stage: stage, slideNumber: diagnostics.slideNumber, code: $0.code,
                              message: $0.message, partURI: $0.partURI, shapeID: $0.shapeID, path: $0.path)
        }
        if let failure = diagnostics.failure {
            result.append(.init(stage: stage, slideNumber: diagnostics.slideNumber, code: "renderFailure",
                                message: failure, partURI: nil, shapeID: nil, path: nil))
        }
        for (flag, code) in [(diagnostics.layoutUnresolved, "layoutUnresolved"), (diagnostics.masterUnresolved, "masterUnresolved")] where flag {
            result.append(.init(stage: stage, slideNumber: diagnostics.slideNumber, code: code,
                                message: "Inherited content could not be loaded.", partURI: nil, shapeID: nil, path: nil))
        }
        return result
    }
}

private struct LibraryLabReport: Codable {
    let recipe: LibraryDemoID
    let title: String
    let options: LibraryLabOptions
    let operations: [String]
    let limitations: [String]
    let slideCount: Int
    let checks: [LibraryLabCheck]
    let findings: [LibraryLabFinding]
    let elapsedSeconds: Double
}
