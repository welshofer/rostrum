import Foundation
import KeynoteInterchange
import Rostrum

enum KeynoteLabRecipe {
    static let catalog = LibraryLabRecipe(.keynoteInterchange,
        title: "Keynote Interchange",
        summary: "Author, edit, reopen, inspect and export a native .keyx document without PowerPoint or a provider.",
        operations: [
            "KeyxAuthor.render", "KeyxDocument.editSlide", "KeyxDocument.addResource",
            "KeyxDocument.save", "KeyxDocument.validate", "KeyxPreviewRenderer.render",
            "DeckInspector.inspect", "DeckExporter.export"
        ],
        limitations: [
            "Keynote Interchange 1.0 is beta; native .key builds, transitions, comments and other excluded features are not represented.",
            "Previews are direct but approximate, not Keynote rendering. Merged cells, effects and advanced chart styling have explicit preview limits.",
            "Semantic checks and reopened content checks are not complete JSON Schema or native visual acceptance.",
            "The authoring subset is narrower than same-format preservation; rich IR layouts may use measured reading-order text."
        ],
        inputs: [.text, .accent, .sampleSize])

    static func run(options: LibraryLabOptions, in parent: URL) throws -> LibraryLabResult {
        try LibraryLab.validate(options)
        try Task.checkCancellation()
        let start = Date()
        let location = parent.appendingPathComponent("keynoteInterchange-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let directory = location.resolvingSymlinksInPath()
        do {
            let deck = DeckIR(meta: Meta(title: options.text), slides: [
                IRSlide(id: "text", layout: "bullets", title: options.text,
                    body: Body(bullets: [Bullet(text: "Owned JSON and resource bytes stay local."),
                                        Bullet(text: "Text remains editable in Keynote.")]),
                    notes: "Original presenter note"),
                IRSlide(id: "table", layout: "table", title: "Native editable table",
                    body: Body(table: IRTable(headers: ["Item", "Value"],
                        rows: (1...options.sampleSize).map { ["Row \($0)", "\($0 * 3)"] }))),
                IRSlide(id: "chart", layout: "chart", title: "Native editable chart",
                    body: Body(chart: IRChart(kind: "line", categories: ["Read", "Edit", "Write"],
                        series: [IRSeries(name: "Example", values: [2, 5, 4])]))),
                IRSlide(id: "image", layout: "imageRight", title: "Owned image resource",
                    body: Body(bullets: [Bullet(text: "This offline fixture contains no Apple theme artwork.")]),
                    image: ImageBrief(prompt: "Local fixture"))
            ])
            var settings = KeyxAuthoringOptions(); settings.accent = options.accentHex
            var authored = try KeyxAuthor.render(deck, options: settings, images: ["image": LibraryLabSupport.pixels],
                                                 measure: KeyxBackend.measurer)
            try authored.document.setEntry(named: "vendor/preserved.bin", data: Data([0, 1, 2, 255]))
            try authored.document.editSlide(at: 0) { slide in
                slide.node["lab_extension"] = .object(["number": .number("900719925474099312345"), "cleared": .null])
                var contents = try slide.contents
                let path = KeyxNode(type: "path", fields: [
                    "bezier": KeyxNode(type: "path.bezier-path", fields: [
                        "path": .string("M 0 0 L 50 0 L 25 40 Z"),
                        "space": KeyxNode(type: "rect", fields: [
                            "position": KeyxNode(type: "position", fields: ["x": .integer(0), "y": .integer(0)]).value,
                            "size": KeyxNode(type: "size", fields: ["width": .integer(50), "height": .integer(40)]).value
                        ]).value
                    ]).value
                ])
                contents.append(KeyxSlideObject(canvas: KeyxCanvasObject(kind: "shape", properties: KeyxNode(type: "shape", fields: [
                    "identifier": .string("lab-triangle"), "geometry": KeyxGeometry(x: 800, y: 430, width: 50, height: 40).node.value,
                    "path": path.value, "fill": try KeyxNode.fill(hex: options.accentHex).value, "stroke": .string("empty")
                ]))))
                slide.setContents(contents)
            }
            let beforeURL = directory.appendingPathComponent("keynote-before.keyx")
            try authored.document.save(to: beforeURL)
            var edited = try KeyxDocument(contentsOf: beforeURL)
            try edited.editSlide(at: 0) { $0.setNote(.value(KeyxText(runs: [
                KeyxTextRun("Edited presenter note", style: KeyxNode(type: "character-properties", fields: ["bold": .bool(true)]))
            ]))) }
            let afterURL = directory.appendingPathComponent("keynote-interchange.keyx")
            try edited.save(to: afterURL)
            let bytes = try Data(contentsOf: afterURL)
            let reopened = try KeyxDocument(data: bytes)
            let preservedNumber = try reopened.slides[0].node["lab_extension"]?["number"]
            var checks = [
                LibraryLabCheck("Direct interchange archive", !reopened.archiveEntryNames.contains("[Content_Types].xml"),
                                "The output contains main.json, manifest.json and presets.json, not a disguised PowerPoint package."),
                .init("Deterministic save and reopen", try reopened.data() == bytes && edited.data() == bytes,
                      "Reopened and repeated saves produce identical bytes."),
                .init("Preserved extension payload", reopened.entryData(named: "vendor/preserved.bin") == Data([0, 1, 2, 255])
                      && preservedNumber == .number("900719925474099312345"),
                      "Unknown binary content, null and a beyond-Double integer survive a note-only edit."),
                .init("Presenter note edit", try reopened.inspectSlide(at: 0).notes == "Edited presenter note",
                      "Rich note text is read from the saved copy."),
                .init("Editable table", try reopened.inspectSlide(at: 1).tables.first?.last == ["Row \(options.sampleSize)", "\(options.sampleSize * 3)"],
                      "Native table cells retain the final source row."),
                .init("Editable chart", try reopened.inspectSlide(at: 2).charts.first?.values == [[2, 5, 4]],
                      "Native numeric chart data remains readable after reopening."),
                .init("Owned image", try reopened.inspectSlide(at: 3).assets.first?.data == LibraryLabSupport.pixels,
                      "The supplied image bytes are unchanged."),
                .init("Semantic integrity", reopened.validate().allSatisfy { $0.severity != .error },
                      "No known semantic integrity errors; this is not full Apple schema validation.")
            ]
            let inspection = try DeckInspector.inspect(deckAt: afterURL)
            let previews = directory.appendingPathComponent("previews", isDirectory: true)
            try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: false)
            for record in inspection.previewRecords {
                try Data(record.displaySVG.utf8).write(to: previews.appendingPathComponent(String(format: "slide-%02d.svg", record.number)), options: .atomic)
            }
            let export = try DeckExporter.export(deckAt: afterURL, into: directory.appendingPathComponent("extracted"))
            let markdown = try String(contentsOf: export.markdownFile, encoding: .utf8)
            checks.append(.init("Inspector and export", inspection.slideCount == 4 && export.chartsWritten == 1
                && export.assetsWritten == 1 && markdown.contains("Edited presenter note") && markdown.contains(options.text),
                "The production inspector and exporter read native interchange output."))
            checks.append(.init("Read-only preview", try Data(contentsOf: afterURL) == bytes,
                                "Inspection and preview do not rewrite the saved file."))
            var findings = inspection.previewRecords.flatMap { record in record.warnings.map {
                LibraryLabFinding(stage: "Interchange preview", slideNumber: record.number, code: "interchangeApproximation",
                                  message: $0, partURI: "main.json", shapeID: nil, path: "/slides/\(record.number - 1)")
            } }
            findings += (authored.warnings + inspection.outlineWarnings + export.warnings).map {
                .init(stage: "Interchange authoring/extraction", slideNumber: nil, code: "interchange", message: $0,
                      partURI: nil, shapeID: nil, path: nil)
            }
            let elapsed = Date().timeIntervalSince(start)
            let report = LibraryLabReport(recipe: .keynoteInterchange, title: catalog.title, options: options,
                operations: catalog.operations, limitations: catalog.limitations, slideCount: inspection.slideCount,
                checks: checks, findings: findings, elapsedSeconds: elapsed)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let reportURL = directory.appendingPathComponent("report.json")
            try encoder.encode(report).write(to: reportURL, options: .atomic)
            var artifacts: [URL] = []
            let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            while let url = enumerator?.nextObject() as? URL {
                if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                    artifacts.append(url.resolvingSymlinksInPath())
                }
            }
            try Task.checkCancellation()
            return LibraryLabResult(id: .keynoteInterchange, options: options, directory: directory,
                beforeURL: beforeURL, afterURL: afterURL, reportURL: reportURL, markdownURL: export.markdownFile,
                artifacts: artifacts.sorted { $0.path < $1.path }, coverSVG: inspection.previews.first,
                coverSlideNumber: 1, slideCount: inspection.slideCount, checks: checks, findings: findings, elapsedSeconds: elapsed)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}
