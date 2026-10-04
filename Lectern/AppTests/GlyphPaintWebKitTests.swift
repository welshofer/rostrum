#if os(macOS)
import AppKit
import CryptoKit
import Foundation
import PDFKit
import Testing
import LecternCore
import Rostrum
@testable import Lectern

/// These captures check actual WebKit drawing. Attribute-level checks remain
/// separate; independent PDF glyph extraction establishes paint/origin fidelity.
@MainActor
@Suite(.serialized) struct GlyphPaintWebKitTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func invalidEmbeddedFontFailsAndTheOwnedHostRecovers() async throws {
        let host = SnapshotHost()
        defer { host.close() }
        let invalid = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100">
          <defs><style>@font-face { font-family: 'InvalidEmbeddedFont'; src: url('data:font/ttf;base64,AAECAw==') format('truetype'); }</style></defs>
          <text x="10" y="50" font-family="InvalidEmbeddedFont" font-size="24">AVATAR ToTo</text>
        </svg>
        """
        #expect(await host.vectorCapture(svg: invalid, size: CGSize(width: 400, height: 100)) == nil)
        let failure = try #require(host.lastCaptureFailure)
        #expect(failure.hasPrefix("Font readiness failed:"))

        let deck = try Presentation(contentsOf: Self.kerningFixture())
        #expect(deck.registerEmbeddedFonts().contains("DejaVu Sans"))
        let svg = try deck.renderSVG(slideAt: 1)
        let size = CGSize(width: deck.slideSize.width.points, height: deck.slideSize.height.points)
        let captured = try #require(await host.vectorCapture(svg: svg, size: size))
        #expect(host.lastCaptureFailure == nil)
        let readiness = try #require(JSONSerialization.jsonObject(with: Data(captured.fontReadinessJSON.utf8)) as? [String: Any])
        let faces = try #require(readiness["faces"] as? [[String: Any]])
        #expect(!faces.isEmpty && faces.allSatisfy { $0["status"] as? String == "loaded" })
        #expect(try #require(PDFDocument(data: captured.pdf)).page(at: 0)?.string?.contains("AVATAR") == true)
        // This invokes the actual bitmap host, not SlideRasterizer's test override.
        let bitmap = try #require(await host.snapshot(svg: svg, size: size))
        #expect(host.lastCaptureFailure == nil)
        #expect(bitmap.size == size && bitmap.tiffRepresentation != nil)
        try Self.expectGlyphPixels(bitmap, viewport: size,
                                   region: CGRect(x: 380, y: 270, width: 290, height: 160))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func cancelledNavigationCannotCompleteTheNextCapture() async throws {
        let host = SnapshotHost()
        defer { host.close() }
        let source = try Presentation(contentsOf: Self.kerningFixture())
        #expect(source.registerEmbeddedFonts().contains("DejaVu Sans"))
        let svg = try source.renderSVG(slideAt: 1)
        let size = CGSize(width: source.slideSize.width.points, height: source.slideSize.height.points)
        let pending = Task { await host.vectorCapture(svg: svg, size: size) }
        // Observe the actual owned WK navigation, with a deadline rather than
        // a delay that guesses when WebKit has started loading.
        let clock = ContinuousClock(), deadline = ContinuousClock.now + .seconds(2)
        while !host.isCapturing && clock.now < deadline { await Task.yield() }
        #expect(host.isCapturing)
        pending.cancel()
        #expect(await pending.value == nil)
        #expect(!host.isCapturing)
        let replacement = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100">
          <rect width="400" height="100" fill="white"/>
          <text x="10" y="50" font-family="Helvetica" font-size="24">Replacement capture</text>
        </svg>
        """
        let next = try #require(await host.vectorCapture(svg: replacement, size: CGSize(width: 400, height: 100)))
        let page = try #require(PDFDocument(data: next.pdf)?.page(at: 0))
        #expect(page.string?.contains("Replacement capture") == true)
        #expect(page.string?.contains("AVATAR") == false)
        #expect(next.viewport == CGSize(width: 400, height: 100))
        #expect(host.lastCaptureFailure == nil && !host.isCapturing)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func paragraphGlyphVariantsProduceFontReadyVectorEvidence() async throws {
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LECTERN_GLYPH_WEBKIT_OUTPUT"]
            ?? "/tmp/lectern-glyph-webkit-20261004", isDirectory: true)
        let directory = base.appendingPathComponent("paragraph-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let host = SnapshotHost()
        defer { host.close() }
        for alternative in [false, true] {
            let result = try LibraryLab.run(.paragraphLayout,
                options: .init(text: "Native glyph painting", sampleSize: 2, alternative: alternative),
                in: directory.appendingPathComponent("lab-\(alternative)", isDirectory: true))
            #expect(result.passed)
            let deck = try Presentation(contentsOf: result.afterURL)
            #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
            // Capture the exact preview emitted by the real inspector, including
            // its viewport metadata and installed-font fallback profile.
            let inspectorSVG = result.directory.appendingPathComponent("previews/slide-07.svg")
            let svg = try String(contentsOf: inspectorSVG, encoding: .utf8)
            let size = CGSize(width: deck.slideSize.width.points, height: deck.slideSize.height.points)
            let referenceURL = result.directory.appendingPathComponent("native-glyph-reference.json")
            let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any])
            let cases = try #require(reference["cases"] as? [[String: Any]]).filter { ($0["alternative"] as? Bool) == alternative }
            let specimens: [[String: Any]] = try cases.map { sample in
                let id = try #require(sample["id"] as? String)
                let shape = try #require(deck.slides[6].shapes.all.first { $0.name == id + " paint original" })
                let source = try #require(sample["source"] as? String)
                return ["sampleID": id, "frame": Self.frame(shape.frame),
                        "referenceGroup": URL(fileURLWithPath: source).deletingLastPathComponent().lastPathComponent,
                        "referenceID": id, "referenceSource": source, "referenceJSON": referenceURL.path]
            }
            try await capture(svg: svg, size: size, stem: "alternative-\(alternative)",
                              source: result.afterURL, slideIndex: 6, specimens: specimens,
                              expectedText: "Glyph size and placement", host: host, directory: directory,
                              inspectorSVG: inspectorSVG)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func nativeKerningThresholdPairProducesVectorEvidence() async throws {
        let source = Self.kerningFixture()
        let fixture = source.deletingLastPathComponent()
        let deck = try Presentation(contentsOf: source)
        #expect(deck.registerEmbeddedFonts().contains("DejaVu Sans"))
        let ids = ["kern-threshold14.6-scaled20x72p5", "kern-threshold15.1-scaled20x72p5"]
        let positions = [(380.0, 270.0), (30.0, 490.0)]
        let specimens: [[String: Any]] = try zip(ids, positions).map { id, position in
            let shape = try #require(deck.slides[1].shapes.all.first { $0.name == id })
            #expect(shape.frame == Rect(x: .points(position.0), y: .points(position.1), width: .points(290), height: .points(160)))
            #expect(shape.textFrame?.text == "AVATAR ToTo")
            return ["sampleID": id, "frame": Self.frame(shape.frame), "referenceGroup": "eligibility",
                    "referenceID": id, "referenceSource": source.path,
                    "referenceJSON": fixture.appendingPathComponent("native-paint-metrics.json").path]
        }
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LECTERN_GLYPH_WEBKIT_OUTPUT"]
            ?? "/tmp/lectern-glyph-webkit-20261004", isDirectory: true)
        let directory = base.appendingPathComponent("kerning-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let host = SnapshotHost()
        defer { host.close() }
        try await capture(svg: deck.renderSVG(slideAt: 1),
                          size: CGSize(width: deck.slideSize.width.points, height: deck.slideSize.height.points),
                          stem: "kerning-thresholds", source: source, slideIndex: 1, specimens: specimens,
                          expectedText: "AVATAR", host: host, directory: directory)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func listMarkerVariantsProduceFontReadyVectorEvidence() async throws {
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LECTERN_MARKER_WEBKIT_OUTPUT"]
            ?? "/tmp/lectern-marker-webkit-20261004", isDirectory: true)
        let directory = base.appendingPathComponent("markers-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let host = SnapshotHost()
        defer { host.close() }
        for alternative in [false, true] {
            let result = try LibraryLab.run(.listMarkers, options: .init(alternative: alternative),
                                           in: directory.appendingPathComponent("lab-\(alternative)", isDirectory: true))
            #expect(result.passed && result.slideCount == 5)
            let deck = try Presentation(contentsOf: result.afterURL)
            #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
            let size = CGSize(width: deck.slideSize.width.points, height: deck.slideSize.height.points)
            #expect(size == CGSize(width: 720, height: 720))
            let referenceURL = result.directory.appendingPathComponent("native-marker-reference.json")
            let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any])
            let cases = try #require(reference["cases"] as? [[String: Any]])
            #expect(cases.count == 24)
            // The fifth slide contains computed fits, not native-selected
            // fitting evidence. Capture only the four original native pages.
            for slideIndex in 0..<4 {
                let selected = cases.filter { ($0["slide"] as? Int) == slideIndex }
                #expect(selected.count == 6)
                let inspectorSVG = result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", slideIndex + 1))
                let svg = try String(contentsOf: inspectorSVG, encoding: .utf8)
                let specimens: [[String: Any]] = try selected.map { sample in
                    let id = try #require(sample["id"] as? String)
                    let shape = try #require(deck.slides[slideIndex].shapes.first { $0.name == id })
                    let source = try #require(sample["source"] as? String)
                    return ["sampleID": id, "frame": Self.frame(shape.frame),
                            "referenceGroup": slideIndex == 3 ? "NativeListMarkers/followup" : "NativeListMarkers",
                            "referenceID": id, "referenceSource": source, "referenceJSON": referenceURL.path]
                }
                let expectedText = try #require(selected.first?["id"] as? String)
                try await capture(svg: svg, size: size, stem: "markers-\(alternative)-slide-\(slideIndex + 1)",
                                  source: result.afterURL, slideIndex: slideIndex, specimens: specimens,
                                  expectedText: expectedText, host: host, directory: directory,
                                  inspectorSVG: inspectorSVG)
            }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func textAlignmentVariantsProduceFontReadyVectorEvidence() async throws {
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LECTERN_ALIGNMENT_WEBKIT_OUTPUT"]
            ?? "/tmp/lectern-alignment-webkit-20261004", isDirectory: true)
        let directory = base.appendingPathComponent("alignment-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let host = SnapshotHost()
        defer { host.close() }
        for alternative in [false, true] {
            let result = try LibraryLab.run(.textAlignment, options: .init(alternative: alternative),
                                           in: directory.appendingPathComponent("lab-\(alternative)", isDirectory: true))
            #expect(result.passed && result.slideCount == 5)
            let deck = try Presentation(contentsOf: result.afterURL)
            #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
            let size = CGSize(width: deck.slideSize.width.points, height: deck.slideSize.height.points)
            #expect(size == CGSize(width: 720, height: 720))
            let referenceURL = result.directory.appendingPathComponent("native-alignment-reference.json")
            let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any])
            let cases = try #require(reference["cases"] as? [[String: Any]])
            #expect(cases.count == 24)
            // The fifth slide contains computed fits, not native-selected
            // fitting evidence. Capture only the four original native pages.
            for slideIndex in 0..<4 {
                let selected = cases.filter { ($0["slide"] as? Int) == slideIndex }
                #expect(selected.count == 6)
                let inspectorSVG = result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", slideIndex + 1))
                let svg = try String(contentsOf: inspectorSVG, encoding: .utf8)
                let specimens: [[String: Any]] = try selected.map { sample in
                    let id = try #require(sample["id"] as? String)
                    let shape = try #require(deck.slides[slideIndex].shapes.first { $0.name == id })
                    let source = try #require(sample["source"] as? String)
                    return ["sampleID": id, "frame": Self.frame(shape.frame),
                            "referenceGroup": "NativeBodyAlignment",
                            "referenceID": id, "referenceSource": source, "referenceJSON": referenceURL.path]
                }
                let expectedText = try #require(selected.first?["id"] as? String)
                try await capture(svg: svg, size: size, stem: "alignment-\(alternative)-slide-\(slideIndex + 1)",
                                  source: result.afterURL, slideIndex: slideIndex, specimens: specimens,
                                  expectedText: expectedText, host: host, directory: directory,
                                  inspectorSVG: inspectorSVG)
            }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func mixedFaceSpacingVariantsProduceFontReadyVectorEvidence() async throws {
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LECTERN_MIXED_SPACING_WEBKIT_OUTPUT"]
            ?? "/tmp/lectern-mixed-spacing-webkit-20261004", isDirectory: true)
        let directory = base.appendingPathComponent("mixed-spacing-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let host = SnapshotHost()
        defer { host.close() }
        for alternative in [false, true] {
            let result = try LibraryLab.run(.mixedFaceSpacing, options: .init(alternative: alternative),
                                           in: directory.appendingPathComponent("lab-\(alternative)", isDirectory: true))
            #expect(result.passed && result.slideCount == 3)
            let deck = try Presentation(contentsOf: result.afterURL)
            #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
            let size = CGSize(width: deck.slideSize.width.points, height: deck.slideSize.height.points)
            #expect(size == CGSize(width: 720, height: 720))
            let referenceURL = result.directory.appendingPathComponent("native-mixed-spacing-reference.json")
            let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any])
            let cases = try #require(reference["cases"] as? [[String: Any]])
            #expect(cases.count == 12)
            // The third slide contains computed fits, not native-selected
            // fitting evidence. Capture only the two original native pages.
            for slideIndex in 0..<2 {
                let selected = cases.filter { ($0["slide"] as? Int) == slideIndex }
                #expect(selected.count == (slideIndex == 0 ? 4 : 8))
                let inspectorSVG = result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", slideIndex + 1))
                let svg = try String(contentsOf: inspectorSVG, encoding: .utf8)
                let specimens: [[String: Any]] = try selected.map { sample in
                    let id = try #require(sample["id"] as? String)
                    let shape = try #require(deck.slides[slideIndex].shapes.first { $0.name == id })
                    let source = try #require(sample["source"] as? String)
                    return ["sampleID": id, "frame": Self.frame(shape.frame),
                            "referenceGroup": slideIndex == 0 ? "NativeMixedFaceSpacing/base" : "NativeMixedFaceSpacing/anchors",
                            "referenceID": id, "referenceSource": source, "referenceJSON": referenceURL.path]
                }
                let expectedText = try #require(selected.first?["id"] as? String)
                try await capture(svg: svg, size: size, stem: "mixed-spacing-\(alternative)-slide-\(slideIndex + 1)",
                                  source: result.afterURL, slideIndex: slideIndex, specimens: specimens,
                                  expectedText: expectedText, host: host, directory: directory,
                                  inspectorSVG: inspectorSVG)
            }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func tableDefaultsVariantsProduceFontReadyVectorEvidence() async throws {
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LECTERN_TABLE_DEFAULTS_WEBKIT_OUTPUT"]
            ?? "/tmp/lectern-table-defaults-webkit-20261004", isDirectory: true)
        let directory = base.appendingPathComponent("table-defaults-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let host = SnapshotHost()
        defer { host.close() }
        for alternative in [false, true] {
            let result = try LibraryLab.run(.tableDefaults, options: .init(alternative: alternative),
                                           in: directory.appendingPathComponent("lab-\(alternative)", isDirectory: true))
            #expect(result.passed && result.slideCount == 4)
            let deck = try Presentation(contentsOf: result.afterURL)
            #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
            let size = CGSize(width: deck.slideSize.width.points, height: deck.slideSize.height.points)
            #expect(size == CGSize(width: 720, height: 720))
            let referenceURL = result.directory.appendingPathComponent("native-table-defaults-reference.json")
            let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any])
            let cases = try #require(reference["cases"] as? [[String: Any]])
            #expect(cases.count == 12)
            // The fourth public authoring page has no native paint oracle.
            for slideIndex in 0..<3 {
                let selected = cases.filter { ($0["slide"] as? Int) == slideIndex }
                #expect(selected.count == 4)
                let inspectorSVG = result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", slideIndex + 1))
                let svg = try String(contentsOf: inspectorSVG, encoding: .utf8)
                let groups = ["NativeTableDefault/builtin", "NativeTableDefault/custom", "NativeTableJoins"]
                let specimens: [[String: Any]] = try selected.map { sample in
                    let id = try #require(sample["id"] as? String)
                    let shape = try #require(deck.slides[slideIndex].shapes.first { $0.name == id })
                    return ["sampleID": id, "frame": Self.frame(shape.frame), "referenceGroup": groups[slideIndex],
                            "referenceID": id, "referenceSource": try #require(sample["source"] as? String),
                            "referenceJSON": referenceURL.path]
                }
                try await capture(svg: svg, size: size, stem: "table-defaults-\(alternative)-slide-\(slideIndex + 1)",
                                  source: result.afterURL, slideIndex: slideIndex, specimens: specimens,
                                  expectedText: try #require(selected.first?["id"] as? String), host: host, directory: directory,
                                  inspectorSVG: inspectorSVG)
            }
        }
    }

    private func capture(svg: String, size: CGSize, stem: String, source: URL, slideIndex: Int,
                         specimens: [[String: Any]], expectedText: String,
                         host: SnapshotHost, directory: URL, inspectorSVG: URL? = nil) async throws {
        let svgData = Data(svg.utf8)
        if let inspectorSVG {
            #expect(try Data(contentsOf: inspectorSVG) == svgData)
        }
        let svgURL = directory.appendingPathComponent(stem + ".svg")
        try svgData.write(to: svgURL)
        let result = await host.vectorCapture(svg: svg, size: size)
        guard let result else {
            let failure = host.lastCaptureFailure ?? "No vector capture was returned."
            try Data(failure.utf8).write(to: directory.appendingPathComponent(stem + "-failure.txt"))
            Issue.record("WebKit glyph capture failed: \(failure)")
            return
        }
        let pdfURL = directory.appendingPathComponent(stem + ".pdf")
        // Preserve WebKit bytes; the independent extractor reads raw matrices.
        try result.pdf.write(to: pdfURL)
        let readinessData = Data(result.fontReadinessJSON.utf8)
        let readiness = try #require(JSONSerialization.jsonObject(with: readinessData) as? [String: Any])
        let faces = try #require(readiness["faces"] as? [[String: Any]])
        #expect(readiness["status"] as? String == "loaded")
        #expect(!faces.isEmpty && faces.allSatisfy { $0["status"] as? String == "loaded" })
        let pdf = try #require(PDFDocument(data: result.pdf))
        #expect(pdf.pageCount == 1)
        let page = try #require(pdf.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        #expect(bounds.width > 0 && bounds.height > 0)
        #expect(abs(bounds.width / bounds.height - size.width / size.height) < 0.001)
        #expect(page.string?.contains(expectedText) == true)
        let records = specimens.map { specimen in
            specimen.merging(["svgFilename": svgURL.lastPathComponent, "pdfFilename": pdfURL.lastPathComponent]) { _, new in new }
        }
        var receipt: [String: Any] = [
            "renderingProfile": inspectorSVG == nil ? "raw library render with embedded fonts" : "saved DeckInspector preview",
            "source": source.path, "sourceSHA256": Self.sha(try Data(contentsOf: source)),
            "sourceSlideIndex": slideIndex,
            "svg": svgURL.path, "svgSHA256": Self.sha(svgData),
            "pdf": pdfURL.path, "pdfSHA256": Self.sha(result.pdf),
            "viewport": ["width": size.width, "height": size.height],
            "pdfMediaBox": ["x": bounds.minX, "y": bounds.minY, "width": bounds.width, "height": bounds.height],
            "pdfPointsPerSlidePoint": ["x": bounds.width / size.width, "y": bounds.height / size.height],
            "fontReadiness": readiness,
            "originalSpecimens": records,
            "independentGlyphComparison": "pending; capture success alone is not native paint parity"
        ]
        if let inspectorSVG {
            receipt["inputInspectorSVG"] = inspectorSVG.path
            receipt["inputInspectorSVGSHA256"] = Self.sha(try Data(contentsOf: inspectorSVG))
        }
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent(stem + "-capture.json"))
    }

    private static func expectGlyphPixels(_ image: NSImage, viewport: CGSize, region: CGRect) throws {
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let sx = Double(bitmap.pixelsWide) / viewport.width
        let sy = Double(bitmap.pixelsHigh) / viewport.height
        var dark = 0, light = 0
        for y in Int(region.minY * sy)..<min(bitmap.pixelsHigh, Int(region.maxY * sy)) {
            for x in Int(region.minX * sx)..<min(bitmap.pixelsWide, Int(region.maxX * sx)) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.9 else { continue }
                let components = [color.redComponent, color.greenComponent, color.blueComponent]
                if components.allSatisfy({ $0 < 0.35 }) { dark += 1 }
                if components.allSatisfy({ $0 > 0.9 }) { light += 1 }
            }
        }
        #expect(dark > 20, "The known AVATAR glyph region must contain drawn black ink.")
        #expect(light > 20, "The same region must retain its white background.")
    }

    private static func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func frame(_ rect: Rect) -> [String: Double] {
        ["x": rect.x.points, "y": rect.y.points, "width": rect.width.points, "height": rect.height.points]
    }

    private static func kerningFixture() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/native-paint-eligibility-v1.pptx")
    }
}
#endif
