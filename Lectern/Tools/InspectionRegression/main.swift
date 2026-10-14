import Foundation
import LecternCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// Headless caller of the same public entry points the app uses. Keep fonts,
// preview policy and extraction in LecternCore; do not recreate them here.
struct Stamp {
    let elapsed = ProcessInfo.processInfo.systemUptime
    let cpu = Double(clock()) / Double(CLOCKS_PER_SEC)

    func since(_ start: Stamp) -> [String: Double] {
        ["elapsedSeconds": elapsed - start.elapsed, "cpuSeconds": cpu - start.cpu]
    }
}

func nullable<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }

func writeJSON(_ value: Any, to url: URL) throws {
    let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
    try (bytes + Data([10])).write(to: url)
}

func comment(_ value: CommentInspection) -> [String: Any] {
    ["index": value.index, "author": value.author, "text": value.text,
     "resolved": value.resolved, "kind": value.kind,
     "replies": value.replies.map { ["index": $0.index, "author": $0.author, "text": $0.text] }]
}

func snapshot(_ value: DeckInspection) -> [String: Any] {
    let properties = value.properties
    let dates = ISO8601DateFormatter()
    return [
        "schemaVersion": 1, "fileName": value.fileName, "byteCount": value.byteCount,
        "slideCount": value.slideCount, "layoutCount": value.layoutCount, "masterCount": value.masterCount,
        "mediaCount": value.mediaCount, "chartCount": value.chartCount, "embedCount": value.embedCount,
        "notesCount": value.notesCount, "partCount": value.partCount,
        "slideSize": value.slideSize, "documentKind": value.documentKind,
        "properties": ["title": nullable(properties.title), "author": nullable(properties.author),
            "subject": nullable(properties.subject), "comments": nullable(properties.comments),
            "keywords": nullable(properties.keywords), "category": nullable(properties.category),
            "company": nullable(properties.company), "application": nullable(properties.application),
            "created": nullable(properties.created.map(dates.string)),
            "modified": nullable(properties.modified.map(dates.string))],
        "sections": value.sections.map { ["id": $0.id, "name": $0.name, "slideIndices": $0.slideIndices] },
        "themeFonts": value.themeFonts, "explicitFonts": value.explicitFonts, "embeddedFonts": value.embeddedFonts,
        "masters": value.masters.map { ["index": $0.index, "name": $0.name, "layoutNames": $0.layoutNames,
            "majorFont": nullable($0.majorFont), "minorFont": nullable($0.minorFont)] },
        "charts": value.charts.map { chart -> [String: Any] in
            ["index": chart.index, "slideIndex": chart.slideIndex, "title": chart.title,
             "plotTypes": chart.plotTypes, "categories": chart.categories, "canReplaceData": chart.canReplaceData,
             "replacementProblem": nullable(chart.replacementProblem),
             "series": chart.series.map { ["index": $0.index, "name": $0.name, "values": $0.values.map(nullable)] }]
        },
        "schemaIssues": value.schemaIssues, "readWarnings": value.readWarnings, "outlineWarnings": value.outlineWarnings,
        "slides": value.slides.map { slide -> [String: Any] in
            ["number": slide.number, "title": nullable(slide.title), "subtitle": nullable(slide.subtitle),
             "bullets": slide.bullets, "tables": slide.tables.map { ["index": $0.index, "rows": $0.rows, "columnCount": $0.columnCount] },
             "chartTitles": slide.chartTitles, "assetNames": slide.assetNames, "notes": slide.notes,
             "hasNotesPage": slide.hasNotesPage, "layoutName": slide.layoutName, "masterName": slide.masterName,
             "shapeCounts": slide.shapeCounts, "comments": slide.comments.map(comment), "mediaCount": slide.mediaCount]
        },
        "previews": value.previewRecords.map { record -> [String: Any] in
            ["number": record.number, "title": record.title, "rendered": record.svg != nil,
             "width": record.geometry.width, "height": record.geometry.height, "warnings": record.warnings]
        },
        "previewDiagnostics": value.previewDiagnostics.map { diagnostic -> [String: Any] in
            ["slideNumber": diagnostic.slideNumber, "layoutUnresolved": diagnostic.layoutUnresolved,
             "masterUnresolved": diagnostic.masterUnresolved, "failure": nullable(diagnostic.failure),
             "messages": diagnostic.messages, "issues": diagnostic.issues.map {
                ["code": $0.code, "impact": $0.impact, "message": $0.message,
                 "partURI": $0.partURI, "shapeID": nullable($0.shapeID), "path": $0.path]
             }]
        }
    ]
}

func run() throws {
    guard CommandLine.arguments.count == 3 else {
        throw Failure("Usage: InspectionRegression DECK.pptx NEW_OUTPUT_DIRECTORY")
    }
    let input = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let output = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
    guard !FileManager.default.fileExists(atPath: output.path) else {
        throw Failure("Output already exists; choose a fresh directory")
    }
    guard FileManager.default.fileExists(atPath: input.path) else { throw Failure("Input deck does not exist") }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    var events: [[String: Any]] = []
    var firstPreview: [String: Double]?
    let inspectStart = Stamp()
    let inspection = try DeckInspector.inspect(deckAt: input) { event in
        let stamp = Stamp().since(inspectStart)
        var record: [String: Any] = stamp
        switch event {
        case .opening: record["event"] = "opening"
        case .validating: record["event"] = "validating"
        case .extracting: record["event"] = "extracting"
        case .rendering(let done, let total):
            record["event"] = "rendering"; record["done"] = done; record["total"] = total
            if done == 1 { firstPreview = stamp }
        case .finished: record["event"] = "finished"
        }
        events.append(record)
    }
    let inspectTime = Stamp().since(inspectStart)
    let exportStart = Stamp()
    let exported = try DeckExporter.export(deckAt: input, into: output.appendingPathComponent("export"))
    let exportTime = Stamp().since(exportStart)
    guard inspection.slideCount == exported.slideCount,
          inspection.previewRecords.map(\.number) == Array(1..<(inspection.slideCount + 1)) else {
        throw Failure("Inspection/export slide positions differ")
    }
    // Stable evidence is separate from timing. Failures keep an explicit SVG
    // slot and diagnostic; successful execution alone is not visual acceptance.
    for record in inspection.previewRecords {
        try record.displaySVG.write(to: output.appendingPathComponent("slide-\(record.number).svg"),
                                    atomically: true, encoding: .utf8)
    }
    var evidence = snapshot(inspection)
    evidence["export"] = ["slideCount": exported.slideCount, "assetsWritten": exported.assetsWritten,
                          "chartsWritten": exported.chartsWritten, "warnings": exported.warnings]
    try writeJSON(evidence, to: output.appendingPathComponent("inspection.json"))
    try writeJSON([
        "schemaVersion": 1, "inspection": inspectTime, "export": exportTime,
        "events": events, "firstPreviewSlotCompleted": nullable(firstPreview),
        "firstPreviewRendered": inspection.previewRecords.first?.svg != nil,
        "measurementScope": "Inspection includes file read, embedded and installed font registration, validation, extraction and SVGs. Export includes reopening, extraction and artifact writes. Event stamps are cumulative from inspection start; extracting to rendering(0) includes extraction and installed font setup. First preview is a completed SVG or failure slot, not a displayed thumbnail. Evidence serialization is outside operation timings. No WebKit or UI timing.",
        "nativeVisualAcceptance": "pending"
    ], to: output.appendingPathComponent("timings.json"))
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

do { try run() }
catch {
    FileHandle.standardError.write(Data("InspectionRegression: \(error)\n".utf8))
    exit(1)
}
