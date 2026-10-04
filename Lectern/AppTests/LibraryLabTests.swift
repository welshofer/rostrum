import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryLabAppTests {
    @Test func filesReachInspectorAndExportWithoutAProvider() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabApp-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        let ids: [LibraryDemoID] = [.tableStructure, .tableAppearance, .notes, .comments]
        await model.run(ids, in: root).value
        #expect(!model.isRunning && model.failures.isEmpty && model.completed == 4)
        for id in ids {
            let result = try #require(model.results[id])
            #expect(result.passed)
            for url in [result.beforeURL, result.afterURL].compactMap({ $0 }) {
                await context.app.inspect(deckAt: url).value
                #expect(context.app.phase == .inspected)
                #expect(context.app.inspection?.fileURL == url)
                #expect(context.app.inspection?.previews.isEmpty == false)
                context.app.goHome()
            }
            await context.app.inspect(deckAt: result.afterURL).value
            let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export-" + id.rawValue)))
            await task.value
            #expect(context.app.exportProblem == nil)
            #expect(context.app.exportedDirectory != nil)
            if id == .tableAppearance {
                #expect(result.slideCount == 3 && context.app.inspection?.previews.count == 3)
                #expect(result.checks.contains { $0.name == "Saved table context and live fit persist" && $0.passed })
                let savedSVG = try String(contentsOf: result.directory.appendingPathComponent("previews/slide-03.svg"), encoding: .utf8)
                let deck = try Presentation(contentsOf: result.afterURL)
                #expect(deck.registerEmbeddedFonts().contains("DejaVu Sans"))
                // Compare the two real inspector runs: their viewport and
                // installed fallback registry differ from raw library defaults.
                let inspection = try #require(context.app.inspection)
                let previewIndex = try #require(inspection.previewSlideNumbers.firstIndex(of: 3))
                #expect(savedSVG == inspection.previews[previewIndex])
                #expect(savedSVG.contains("BBBBBBBBBBBBZ") && savedSVG.contains("font-size=\"20\""))
                #expect(result.findings.contains { $0.slideNumber == 3 && $0.message.contains("ignore stored fontScale") })
                let directory = try #require(context.app.exportedDirectory)
                let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                let markdown = try String(contentsOf: #require(files.first { $0.pathExtension == "md" }), encoding: .utf8)
                #expect(markdown.contains("Table cells measure full-size text") && markdown.contains("Stored scale: 50%"))
                #expect(context.app.exportSummary?.hasPrefix("3 slides") == true)
            }
            context.app.goHome()
        }
        #expect(model.results.count == 4)
    }

    @Test(arguments: [false, true])
    func paragraphDemoReachesInspectorAndExport(narrow: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabParagraph-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(text: "App paragraph demonstration", sampleSize: 6, alternative: narrow)
        await model.run([.paragraphLayout], in: root).value
        let result = try #require(model.results[.paragraphLayout])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.checks.contains { $0.name == "Paragraph positions survive reopening" && $0.passed })
        await context.app.inspect(deckAt: result.afterURL).value
        #expect(context.app.phase == .inspected)
        #expect(context.app.inspection?.previews.count == 7)
        let exportRoot = root.appendingPathComponent("Export")
        let task = try #require(context.app.exportInspected(into: exportRoot))
        await task.value
        #expect(context.app.exportProblem == nil)
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("App paragraph demonstration"))
        #expect(markdown.contains("The last line remains natural."))
        #expect(context.app.exportSummary == "7 slides · 0 media files · 0 chart CSVs")
        let deck = try Presentation(contentsOf: result.afterURL)
        #expect(deck.slides.count == 7)
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        let shape = try #require(deck.slides[0].shapes.all.first { $0.name == "Justified paragraph" })
        #expect(shape.textFrame?.paragraphs.first?.alignment == .justified)
        let tree = try #require(deck.slides[0].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        let node = try #require(tree.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == "Justified paragraph"
        })
        let body = try #require(node.firstChild(named: "p:txBody"))
        let layout = RichTextLayout(textBody: body, width: shape.frame.width.points,
                                    height: shape.frame.height.points, fonts: deck.fonts, theme: deck.theme)
        let metrics = try #require(deck.fonts.metrics(for: "DejaVu Sans"))
        #expect(layout.fits && layout.diagnostics.isEmpty)
        #expect(layout.lines.first?.spans.contains {
            $0.run.text == " " && $0.width > metrics.width(of: " ", pointSize: $0.run.fontSize) + 0.1
        } == true)
        #expect(markdown.contains("Small width changes move line breaks"))
        #expect(markdown.contains("Computed scale:"))
        for (stem, count) in [("dejavu-18-", narrow ? 11 : 12), ("dejavu-mixed-size-", narrow ? 7 : 8)] {
            let caseID = stem + (narrow ? "1" : "2")
            #expect(result.checks.contains { $0.name == "Saved native boundary: " + caseID && $0.passed })
            let boundaryTree = try #require(deck.slides[2].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
            var layouts: [RichTextLayout] = []
            for role in ["original", "shape fit", "frame fit"] {
                let name = caseID + " " + role
                let box = try #require(deck.slides[2].shapes.all.first { $0.name == name })
                let node = try #require(boundaryTree.children(named: "p:sp").first {
                    $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
                })
                let body = try #require(node.firstChild(named: "p:txBody"))
                let measured = RichTextLayout(textBody: body, width: box.frame.width.points,
                    height: box.frame.height.points, fonts: deck.fonts, theme: deck.theme)
                #expect(measured.fits && measured.diagnostics.isEmpty)
                layouts.append(measured)
                if stem.contains("mixed") { #expect(box.textFrame?.paragraphs.first?.runs.compactMap(\.fontSize) == [18, 10]) }
                if role != "original" {
                    let norm = try #require(body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
                    let scale = try #require(Double(norm[attribute: "fontScale"] ?? ""))
                    #expect(scale > 0 && scale < 100_000)
                }
            }
            #expect(layouts[0].lines.map { $0.spans.map(\.run.text).joined() } == [String(repeating: "m", count: count), narrow ? "mZ" : "Z"])
            #expect(layouts[1].lines == layouts[2].lines && layouts[1].lines.count == 1)
        }
        #expect(markdown.contains("Common Latin words at a native wrap boundary"))
        #expect(markdown.contains("officeZ"))
        let latinTree = try #require(deck.slides[3].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        for caseID in [narrow ? "office-edge-below" : "office-edge-above", "mixed-size-edge"] {
            #expect(result.checks.contains { $0.name == "Saved native Latin wrap: " + caseID && $0.passed })
            var layouts: [RichTextLayout] = []
            for role in ["original", "shape fit", "frame fit"] {
                let name = caseID + " " + role
                let box = try #require(deck.slides[3].shapes.all.first { $0.name == name })
                let node = try #require(latinTree.children(named: "p:sp").first {
                    $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
                })
                let body = try #require(node.firstChild(named: "p:txBody"))
                let layout = RichTextLayout(textBody: body, width: box.frame.width.points,
                    height: box.frame.height.points, fonts: deck.fonts, theme: deck.theme)
                #expect(layout.fits && layout.diagnostics.isEmpty)
                layouts.append(layout)
                #expect(box.textFrame?.paragraphs.first?.runs.compactMap(\.fontSize) == (caseID == "mixed-size-edge" ? [18, 12] : [18]))
                #expect(box.textFrame?.paragraphs.first?.runs.allSatisfy { $0.color == .black } == true)
                let norm = try #require(body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
                let scale = try #require(Double(norm[attribute: "fontScale"] ?? ""))
                if role == "original" { #expect(scale == 100_000) }
                else { #expect(scale > 0 && scale < 100_000) }
            }
            let nativeLines = caseID == "office-edge-below" ? ["offic", "eZ"] : ["office", "Z"]
            #expect(layouts[0].lines.map { $0.spans.map(\.run.text).joined() } == nativeLines)
            #expect(layouts[1].lines == layouts[2].lines)
            #expect(layouts[1].lines.map { $0.spans.map(\.run.text).joined() } == ["officeZ"])
        }
        #expect(markdown.contains("Empty lines keep their own typography"))
        #expect(markdown.contains("Empty-line formatting is preserved."))
        let breakTree = try #require(deck.slides[4].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        for caseID in [narrow ? "consecutive-6-36" : "consecutive-36-6", narrow ? "trailing-br36-end36" : "trailing-br36-end6"] {
            #expect(result.checks.contains { $0.name == "Saved native empty-line spacing: " + caseID && $0.passed })
            #expect(result.checks.contains { $0.name == "Saved break properties and fits: " + caseID && $0.passed })
            var layouts: [RichTextLayout] = []
            var paragraphs: [[String]] = []
            for role in ["original", "shape fit", "frame fit"] {
                let name = caseID + " " + role
                let box = try #require(deck.slides[4].shapes.all.first { $0.name == name })
                let node = try #require(breakTree.children(named: "p:sp").first {
                    $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
                })
                let body = try #require(node.firstChild(named: "p:txBody"))
                let layout = RichTextLayout(textBody: body, width: box.frame.width.points,
                    height: box.frame.height.points, fonts: deck.fonts, theme: deck.theme)
                #expect(layout.fits && layout.diagnostics.isEmpty && layout.lines.count == 3)
                #expect(layout.lines[1].spans.isEmpty)
                layouts.append(layout)
                paragraphs.append(body.children(named: "a:p").map { $0.serialized() })
            }
            #expect(layouts[0].lines.last?.baseline == (narrow ? 69 : 33))
            #expect(layouts[1].lines == layouts[2].lines && layouts[1].contentHeight <= 28)
            #expect(paragraphs[0] == paragraphs[1] && paragraphs[1] == paragraphs[2])
        }
        #expect(markdown.contains("Line spacing keeps its own baseline rules"))
        #expect(markdown.contains(narrow ? "150%; 75% font, 20% reduction" : "150%, Windows line height"))
        let spacingTree = try #require(deck.slides[5].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        let referenceData = try Data(contentsOf: result.directory.appendingPathComponent("native-spacing-reference.json"))
        let reference = try #require(JSONSerialization.jsonObject(with: referenceData) as? [String: Any])
        let allSpacingCases = try #require(reference["cases"] as? [[String: Any]])
        let spacingCases = allSpacingCases.filter { ($0["alternative"] as? Bool) == narrow }
        #expect(spacingCases.count == 6)
        for sample in spacingCases {
            let caseID = try #require(sample["id"] as? String)
            #expect(result.checks.contains { $0.name == "Saved native explicit spacing: " + caseID && $0.passed })
            let name = caseID + " spacing"
            let box = try #require(deck.slides[5].shapes.all.first { $0.name == name })
            #expect(box.frame.width == .points(290) && box.frame.height == .points(160))
            let node = try #require(spacingTree.children(named: "p:sp").first {
                $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
            })
            let body = try #require(node.firstChild(named: "p:txBody"))
            let sourceXML = try #require(sample["textBodyXML"] as? String)
            let source = try XML.parse(Data(sourceXML.utf8))
            #expect(body.childElements.map { $0.serialized() } == source.childElements.map { $0.serialized() })
            let layout = RichTextLayout(textBody: body, width: 290, height: 160, fonts: deck.fonts, theme: deck.theme)
            #expect(layout.fits && layout.diagnostics.isEmpty)
            let markers = try #require(sample["nativeMarkers"] as? [[String: Any]])
            #expect(layout.lines.count == markers.count)
            for (line, marker) in zip(layout.lines, markers) {
                let baseline = try #require(marker["baseline"] as? Double)
                let x = try #require(marker["x"] as? Double)
                let text = try #require(marker["text"] as? String)
                #expect(line.spans.map(\.run.text).joined() == text)
                #expect(abs(line.baseline - baseline) <= 0.121)
                #expect(abs((line.spans.first?.x ?? .infinity) - x) <= 0.121)
            }
        }
        #expect(try deck.renderSVGReportingProblems(slideAt: 5).problems.isEmpty)
        #expect(markdown.contains("Glyph size and placement follow native painting"))
        let paintData = try Data(contentsOf: result.directory.appendingPathComponent("native-glyph-reference.json"))
        let paintReference = try #require(JSONSerialization.jsonObject(with: paintData) as? [String: Any])
        let paintCases = try #require(paintReference["cases"] as? [[String: Any]]).filter { ($0["alternative"] as? Bool) == narrow }
        #expect(paintCases.count == 6)
        let paintSVG = try String(contentsOf: result.directory.appendingPathComponent("previews/slide-07.svg"), encoding: .utf8)
        let inspection = try #require(context.app.inspection)
        let paintIndex = try #require(inspection.previewSlideNumbers.firstIndex(of: 7))
        #expect(paintSVG == inspection.previews[paintIndex])
        let paintTree = try #require(deck.slides[6].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        let svgRoot = try XML.parse(Data(paintSVG.utf8))
        func textNodes(_ element: XML.Element) -> [XML.Element] {
            (element.name == "text" ? [element] : []) + element.childElements.flatMap(textNodes)
        }
        for sample in paintCases {
            let caseID = try #require(sample["id"] as? String)
            #expect(result.checks.contains { $0.name == "Saved native glyph painting: " + caseID && $0.passed })
            let name = caseID + " paint original"
            let box = try #require(deck.slides[6].shapes.all.first { $0.name == name })
            #expect(box.frame.width == .points(try #require(sample["widthPoints"] as? Double)))
            #expect(box.frame.height == .points(160))
            let node = try #require(paintTree.children(named: "p:sp").first {
                $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
            })
            let body = try #require(node.firstChild(named: "p:txBody"))
            let source = try XML.parse(Data(try #require(sample["textBodyXML"] as? String).utf8))
            #expect(body.childElements.map { $0.serialized() } == source.childElements.map { $0.serialized() })
            let lines = try #require(sample["nativeLines"] as? [[String: Any]])
            let expected = try lines.flatMap { try #require($0["characters"] as? [[String: Any]]) }
            var actual: [(text: String, x: Double, baseline: Double, size: Double)] = []
            for text in textNodes(svgRoot) {
                let transform = text[attribute: "transform"] ?? ""
                let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
                guard values.count == 3, values[2] == Double(EMU.perPoint), abs(values[0] - Double(box.frame.x.rawValue)) < 0.001 else { continue }
                let baseline = values[1] / Double(EMU.perPoint) - box.frame.y.points
                guard baseline >= 0 && baseline <= box.frame.height.points else { continue }
                for span in text.children(named: "tspan") {
                    #expect(span[attribute: "textLength"] == nil && span[attribute: "lengthAdjust"] == nil)
                    let size = try #require(span[attribute: "font-size"].flatMap(Double.init))
                    let positions = try #require(span[attribute: "x"]).split(whereSeparator: { $0.isWhitespace }).compactMap { Double($0) }
                    let scalars = Array(span.textContent.unicodeScalars)
                    #expect(positions.count == scalars.count)
                    for (scalar, x) in zip(scalars, positions) where scalar.value != 32 {
                        actual.append((String(scalar), x, baseline, size))
                    }
                }
            }
            #expect(actual.count == expected.count)
            for (glyph, native) in zip(actual, expected) {
                #expect(glyph.text == (native["text"] as? String))
                #expect(abs(glyph.x - (try #require(native["x"] as? Double))) <= 0.025)
                #expect(abs(glyph.baseline - (try #require(native["baseline"] as? Double))) <= 0.121)
                let matrix = try #require(native["rawPDFPaintScale"] as? [Double])
                #expect(matrix.count == 2 && matrix.allSatisfy { abs(glyph.size - $0) <= 0.002 })
                let bounds = try #require(native["sourceGlyphBounds"] as? [Double])
                let ink = try #require(native["geometricInkBounds"] as? [Double])
                let units = try #require(sample["unitsPerEm"] as? Double)
                #expect(abs((bounds[2] - bounds[0]) * glyph.size / units - (ink[2] - ink[0])) <= 0.002)
                #expect(abs((bounds[3] - bounds[1]) * glyph.size / units - (ink[3] - ink[1])) <= 0.002)
            }
        }
        #expect(try deck.renderSVGReportingProblems(slideAt: 6).problems.isEmpty)
        #expect(model.results[.paragraphLayout]?.directory == result.directory)
    }

    @Test(arguments: [false, true])
    func tabDemoReachesInspectorAndExport(moved: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabTabs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(text: "App tab demonstration", accentHex: "963D61", sampleSize: 12, alternative: moved)
        await model.run([.tabLayout], in: root).value
        let result = try #require(model.results[.tabLayout])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.checks.contains { $0.name == "Tab positions survive reopening" && $0.passed })
        await context.app.inspect(deckAt: result.afterURL).value
        #expect(context.app.phase == .inspected)
        #expect(context.app.inspection?.previews.count == 2)
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("App tab demonstration") && markdown.contains("314.16"))
        #expect(markdown.contains("The last line remains natural."))
        #expect(context.app.exportSummary == "2 slides · 0 media files · 0 chart CSVs")
        let deck = try Presentation(contentsOf: result.afterURL)
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        let shape = try #require(deck.slides[0].shapes.all.first { $0.name == "Decimal tab fields" })
        #expect(shape.textFrame?.paragraphs.count == 12)
        #expect(shape.textFrame?.paragraphs.first?.tabStops == [TextTabStop(position: .inches(moved ? 1.8 : 1.4), alignment: .decimal)])
        let paragraphShape = try #require(deck.slides[1].shapes.all.first { $0.name == "Justified tab paragraph" })
        #expect(paragraphShape.textFrame?.paragraphs.first?.alignment == .justified)
        #expect(paragraphShape.textFrame?.paragraphs.first?.tabStops == [TextTabStop(position: .inches(moved ? 1.25 : 0.75))])
        let tree = try #require(deck.slides[1].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        let node = try #require(tree.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == "Justified tab paragraph"
        })
        let body = try #require(node.firstChild(named: "p:txBody"))
        let layout = RichTextLayout(textBody: body, width: paragraphShape.frame.width.points,
                                    height: paragraphShape.frame.height.points, fonts: deck.fonts, theme: deck.theme)
        let metrics = try #require(deck.fonts.metrics(for: "DejaVu Sans"))
        #expect(layout.fits && layout.diagnostics.isEmpty)
        let first = try #require(layout.lines.first)
        let visible = try #require(first.spans.first { !$0.run.text.isEmpty && $0.run.text != "\t" })
        #expect(abs(visible.x - (moved ? 1.25 : 0.75) * 72) < 0.01)
        #expect(first.spans.contains { $0.run.text == " " && $0.width > metrics.width(of: " ", pointSize: 16) + 0.1 })
        context.app.goHome()
        #expect(model.results[.tabLayout]?.directory == result.directory)
    }

    @Test func aFailureDoesNotPreventRemainingDemos() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabFailure-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        await model.run([.slides, .tableStructure, .tableStructure], in: root) { id, options, root in
            if id == .slides { throw LabAppError.controlled }
            return try LibraryLab.run(id, options: options, in: root)
        }.value
        #expect(!model.isRunning && model.completed == 2 && model.total == 2)
        #expect(model.failures[.slides] != nil && model.results[.tableStructure]?.passed == true)
    }

    @Test(arguments: [false, true])
    func replacementAndCancellationRejectRetiredCompletion(fails: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabRetired-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try LibraryLab.run(.tableStructure, in: root)
        let model = LibraryLabModel()
        let old = ControlledLab(), live = ControlledLab()
        let oldTask = model.run([.tableStructure], in: root, using: old.run)
        await old.waitUntilStarted()
        let liveTask = model.run([.tableStructure], in: root, using: live.run)
        await live.waitUntilStarted()
        await old.finish(fails ? .failure(LabAppError.controlled) : .success(result))
        await oldTask.value
        #expect(model.isRunning && model.completed == 0 && model.failures.isEmpty && model.results.isEmpty)
        model.cancel()
        await live.finish(.success(result))
        await liveTask.value
        #expect(await live.observedCancellation)
        #expect(!model.isRunning && model.completed == 0 && model.failures.isEmpty && model.results.isEmpty)
    }

    @Test func returnedTaskCancellationRetiresProgress() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabCancel-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try LibraryLab.run(.tableStructure, in: root)
        let model = LibraryLabModel(), worker = ControlledLab()
        let task = model.run([.tableStructure], in: root, using: worker.run)
        await worker.waitUntilStarted()
        task.cancel()
        await worker.finish(.success(result))
        await task.value
        #expect(!model.isRunning && model.activeID == nil && model.results.isEmpty)
    }
}

private enum LabAppError: Error { case controlled }

private actor ControlledLab {
    private var completion: CheckedContinuation<LibraryLabResult, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var started = false
    private(set) var observedCancellation = false

    func run(_ id: LibraryDemoID, _ options: LibraryLabOptions, _ parent: URL) async throws -> LibraryLabResult {
        defer { observedCancellation = Task.isCancelled }
        return try await withCheckedThrowingContinuation { completion in
            self.completion = completion
            started = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func finish(_ result: Result<LibraryLabResult, Error>) {
        completion?.resume(with: result)
        completion = nil
    }
}
