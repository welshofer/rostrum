import Foundation
import KeynoteInterchange
import Rostrum
#if canImport(CoreText)
import CoreText
import CoreGraphics
#endif

/// The interchange backend owns format-specific authoring, extraction and
/// preview translation. Existing PowerPoint operations stay on their backend.
enum KeyxBackend {
    static var measurer: KeyxTextMeasurer? {
        #if canImport(CoreText)
        return { request in
            TemplateRendering.measuredTextHeight(text: request.text, font: request.font,
                size: request.size, bold: request.bold, tracking: 0, width: request.width)
        }

        #else
        return nil
        #endif
    }

    static func options(designURL: URL?, notesEnabled: Bool) throws -> KeyxAuthoringOptions {
        var options = KeyxAuthoringOptions()
        options.notesEnabled = notesEnabled
        if let designURL {
            let design = try Design(contentsOf: designURL)
            options.headingFont = design.headingFont ?? options.headingFont
            options.bodyFont = design.bodyFont ?? options.bodyFont
            options.background = design.colors["background"]?.hex ?? options.background
            options.foreground = (design.colors["ink"] ?? design.colors["text"])?.hex ?? options.foreground
            options.accent = (design.colors["accent 1"] ?? design.palette.first)?.hex ?? options.accent
        }
        return options
    }

    static func render(_ deck: DeckIR, designURL: URL?, notesEnabled: Bool, into directory: URL,
                       warnings: [String] = [], images: [String: Data] = [:],
                       template: DeckTemplate? = nil) throws -> DeckResult {
        try Task.checkCancellation()
        let authored = try KeyxAuthor.render(deck,
            options: options(designURL: template == nil ? designURL : nil, notesEnabled: notesEnabled),
            images: images, template: template?.interchangeDocument(), measure: measurer)
        let url = try outputURL(title: deck.meta.title, in: directory)
        try Task.checkCancellation()
        try authored.document.save(to: url)
        return try result(at: url, warnings: warnings + (template?.warnings ?? []) + authored.warnings)
    }

    static func outputURL(title: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let label = DeckLibrary.sanitizedName(title)
        var stem = ""
        for character in label.isEmpty ? "Deck" : label {
            guard stem.utf8.count + String(character).utf8.count <= 120 else { break }
            stem.append(character)
        }
        if stem.isEmpty { stem = "Deck" }
        var candidate = directory.appendingPathComponent(stem).appendingPathExtension(DeckFormat.keynoteInterchange.fileExtension)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)-\(suffix)").appendingPathExtension(DeckFormat.keynoteInterchange.fileExtension)
            suffix += 1
        }
        return candidate
    }

    static func result(at url: URL, recoveryURL: URL? = nil, warnings: [String]) throws -> DeckResult {
        let inspection = try inspect(at: url)
        return DeckResult(recoveryURL: recoveryURL, url: url, slideCount: inspection.slideCount,
            warnings: warnings + inspection.outlineWarnings, schemaIssues: inspection.schemaIssues, unmeasuredFonts: [],
            previewWarnings: inspection.previewWarnings, previewRecords: inspection.previewRecords,
            previewDiagnostics: inspection.previewDiagnostics, droppedContent: [])
    }

    static func slideCount(at url: URL) throws -> Int { try KeyxDocument(contentsOf: url).slides.count }

    static func inspect(at url: URL, renderPreviews: Bool = true, maximumUncompressedBytes: Int? = nil,
                        onEvent: (DeckInspector.Event) -> Void = { _ in }) throws -> DeckInspection {
        try Task.checkCancellation()
        onEvent(.opening)
        var limits = KeyxLimits()
        if let maximumUncompressedBytes { limits.uncompressedBytes = min(limits.uncompressedBytes, maximumUncompressedBytes) }
        let document = try KeyxDocument(contentsOf: url, limits: limits)
        let size = try document.slideSize
        let slides = try document.slides
        onEvent(.validating)
        let validation = document.validate()
        onEvent(.extracting)
        var digests: [SlideDigest] = [], charts: [ChartInspection] = []
        var fonts: Set<String> = [], extractionWarnings: [String] = []
        for index in slides.indices {
            try Task.checkCancellation()
            let summary: KeyxSlideSummary
            let layout: KeyxNode?
            do {
                summary = try document.inspectSlide(at: index)
                layout = try document.layout(for: slides[index])
            } catch is CancellationError { throw CancellationError() }
            catch {
                extractionWarnings.append("Slide \(index + 1) could not be inspected: \(error)")
                digests.append(SlideDigest(number: index + 1, title: "Inspection unavailable", subtitle: nil,
                    bullets: [], tableCount: 0, tables: [], chartTitles: [], assetNames: [], notes: [],
                    hasNotesPage: false, layoutName: "Unresolved interchange layout", masterName: "",
                    shapeCounts: [:], comments: [], mediaCount: 0))
                continue
            }
            fonts.formUnion(summary.fonts)
            extractionWarnings += summary.warnings.map { "Slide \(index + 1): \($0)" }
            digests.append(SlideDigest(number: index + 1, title: summary.title, subtitle: nil,
                bullets: summary.texts.filter { $0 != summary.title }, tableCount: summary.tables.count,
                tables: summary.tables.enumerated().map { TableInspection(index: $0.offset, rows: $0.element) },
                chartTitles: summary.charts.map { $0.kind.capitalized + " chart" }, assetNames: summary.assets.map(\.filename),
                notes: summary.notes.isEmpty ? [] : [summary.notes], hasNotesPage: false,
                layoutName: layout?["name"]?.string ?? "External Keynote layout",
                masterName: document.presentation["theme"]?["name"]?.string ?? "Keynote default theme",
                shapeCounts: summary.shapeCounts, comments: [], mediaCount: summary.assets.count))
            for chart in summary.charts {
                charts.append(ChartInspection(index: charts.count, slideIndex: index, title: chart.kind.capitalized + " chart",
                    plotTypes: [chart.kind], categories: chart.categories,
                    series: chart.values.enumerated().map { s, values in
                        ChartSeriesInspection(index: s, name: chart.seriesNames.indices.contains(s) ? chart.seriesNames[s] : "Series \(s + 1)", values: values)
                    }, canReplaceData: false, replacementProblem: "Edit native interchange chart JSON; PowerPoint chart editing does not apply."))
            }
        }
        var records: [SlidePreviewRecord] = [], diagnostics: [SlidePreviewDiagnostics] = []
        if renderPreviews {
            let fontLibrary = FontLibrary()
            PreviewFontMeasurement.install(on: fontLibrary)
            onEvent(.rendering(done: 0, total: slides.count))
            for index in slides.indices {
                try Task.checkCancellation()
                let geometry = SlidePreviewGeometry(width: size.width, height: size.height)
                do {
                    let preview = try KeyxPreviewRenderer.render(document, slideAt: index, fonts: fontLibrary)
                    records.append(.init(number: index + 1, title: digests[index].title ?? "", svg: preview.svg,
                                         geometry: geometry, warnings: preview.warnings))
                    diagnostics.append(.init(slideNumber: index + 1, interchangeWarnings: preview.warnings))
                } catch is CancellationError { throw CancellationError() }
                catch {
                    records.append(.init(number: index + 1, title: digests[index].title ?? "", svg: nil,
                                         geometry: geometry, warnings: ["Interchange preview unavailable: \(error)"]))
                    diagnostics.append(.init(slideNumber: index + 1, interchangeWarnings: [], failure: String(describing: error)))
                }
                onEvent(.rendering(done: index + 1, total: slides.count))
            }
        }
        let layouts = document.presentation["theme"]?["slide_layouts"]?.array ?? []
        onEvent(.finished)
        return DeckInspection(fileURL: url, fileName: url.lastPathComponent,
            byteCount: try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
            slideCount: slides.count, layoutCount: layouts.count, masterCount: 0,
            mediaCount: document.archiveEntryNames.filter { $0.hasPrefix("Data/") && !$0.hasSuffix("/") }.count,
            chartCount: charts.count, embedCount: 0, notesCount: digests.filter { !$0.notes.isEmpty }.count,
            partCount: document.archiveEntryNames.count,
            slideSize: String(format: "%.2fin × %.2fin", size.width / 72, size.height / 72),
            documentKind: "Keynote Interchange (1.0 beta)", sections: [],
            properties: DeckPropertyInspection(title: document.presentation["lectern_title"]?.string, author: nil,
                subject: nil, comments: nil, keywords: nil, category: nil, company: nil, application: nil, created: nil, modified: nil),
            themeFonts: [], explicitFonts: fonts.sorted(), embeddedFonts: [], masters: [], charts: charts,
            schemaIssues: validation.filter { $0.severity == .error }.map(\.description),
            readWarnings: validation.filter { $0.severity == .warning }.map(\.description)
                + ["Interchange checks cover semantic integrity, not the complete Apple JSON Schema. Native .key features outside interchange cannot be recovered."],
            outlineWarnings: extractionWarnings, slides: digests, previewRecords: records, previewDiagnostics: diagnostics)
    }

    static func export(at url: URL, into parent: URL) throws -> DeckExporter.Outcome {
        let document = try KeyxDocument(contentsOf: url)
        let name = DeckExporter.folderName(for: url)
        let directory = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var lines = ["# " + markdown(name), ""], warnings: [String] = []
        var assets = 0, charts = 0
        let slides = try document.slides
        for index in slides.indices {
            try Task.checkCancellation()
            let slide = try document.inspectSlide(at: index)
            warnings += slide.warnings.map { "Slide \(index + 1): \($0)" }
            lines += ["## Slide \(index + 1): \(markdown(slide.title))", ""]
            lines += slide.texts.map(markdown)
            for table in slide.tables {
                lines.append("")
                for (rowIndex, row) in table.enumerated() {
                    lines.append("| " + row.map { markdown($0).replacingOccurrences(of: "\n", with: "<br>") }.joined(separator: " | ") + " |")
                    if rowIndex == 0 { lines.append("| " + row.map { _ in "---" }.joined(separator: " | ") + " |") }
                }
            }
            if !slide.notes.isEmpty { lines += ["", "### Presenter notes", "", markdown(slide.notes)] }
            let folder = directory.appendingPathComponent(String(format: "slide-%02d", index + 1), isDirectory: true)
            if !slide.assets.isEmpty || !slide.charts.isEmpty {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            for (offset, asset) in slide.assets.enumerated() {
                let safe = DeckLibrary.sanitizedName(asset.filename)
                let filename = "asset-\(offset + 1)-" + (safe.isEmpty ? "resource.bin" : String(safe.prefix(120)))
                try asset.data.write(to: folder.appendingPathComponent(filename), options: .atomic)
                assets += 1
            }
            for (offset, chart) in slide.charts.enumerated() {
                var csvRows = [["Series"] + chart.categories]
                csvRows += chart.values.enumerated().map { s, values in
                    [chart.seriesNames.indices.contains(s) ? chart.seriesNames[s] : "Series \(s + 1)"] + values.map { $0.map { String($0) } ?? "" }
                }
                let csv = csvRows.map { $0.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }.joined(separator: "\n") + "\n"
                try Data(csv.utf8).write(to: folder.appendingPathComponent("chart-\(offset + 1).csv"), options: .atomic)
                charts += 1
            }
        }
        let markdownFile = directory.appendingPathComponent(name + ".md")
        try Data(lines.joined(separator: "\n").utf8).write(to: markdownFile, options: .atomic)
        return DeckExporter.Outcome(directory: directory, markdownFile: markdownFile, slideCount: slides.count,
                                    assetsWritten: assets, chartsWritten: charts, warnings: warnings)
    }

    private static func markdown(_ text: String) -> String {
        var result = text
        for character in ["\\", "`", "*", "_", "[", "]", "<", ">", "#", "|"] {
            result = result.replacingOccurrences(of: character, with: "\\" + character)
        }
        return result
    }
}

public extension DeckInspector {
    /// A single direct interchange preview for library covers. Unlike Quick
    /// Look, this path is available even when Keynote is not installed.
    static func previewInterchangeSlide(deckAt url: URL, slideNumber: Int = 1) throws -> SlidePreviewRecord {
        guard DeckFormat(url: url) == .keynoteInterchange, slideNumber > 0 else {
            throw DeckInspectionError.cannotOpen("Choose a Keynote Interchange slide.")
        }
        try Task.checkCancellation()
        let document = try KeyxDocument(contentsOf: url)
        let fonts = FontLibrary()
        PreviewFontMeasurement.install(on: fonts)
        let preview = try KeyxPreviewRenderer.render(document, slideAt: slideNumber - 1, fonts: fonts)
        let summary = try document.inspectSlide(at: slideNumber - 1)
        return SlidePreviewRecord(number: slideNumber, title: summary.title, svg: preview.svg,
            geometry: SlidePreviewGeometry(width: preview.width, height: preview.height), warnings: preview.warnings)
    }
}
