import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct InspectionFontsTests {
    @Test func discoversInheritedFamiliesWithoutRewritingSource() throws {
        let deck = try Presentation()
        let layout = try #require(deck.package.parts.values.first { $0.contentType == ContentType.slideLayout })
        let root = try layout.dom()
        root.appendElement(try XML.parse(Data("""
            <a:txBody xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:p><a:pPr><a:defRPr><a:latin typeface="Inherited Typeface"/></a:defRPr></a:pPr></a:p>
            </a:txBody>
            """.utf8)))
        layout.markDirty()
        let before = try deck.serializedData()
        let families = try InspectionFonts.families(in: deck, explicit: ["Slide Typeface"])
        #expect(families.contains("Inherited Typeface"))
        #expect(families.contains("Slide Typeface"))
        #expect(families.contains(deck.theme.majorFont ?? ""))
        #expect(try deck.serializedData() == before)
    }

    #if canImport(CoreText)
    @Test func inspectionMeasuresInstalledStylesAndStillReportsUnknownFonts() throws {
        let available = try Presentation()
        guard InstalledFonts.register(in: available, families: ["Arial"]).isEmpty else { return }
        let deck = try Presentation()
        let slide = try deck.slides[0]
        for (index, style) in InstalledFonts.styles.enumerated() {
            let shape = try slide.shapes.addTextBox(Rect(x: .zero, y: .inches(Double(index)),
                                                       width: .inches(8), height: .inches(1)))
            shape.textFrame?.text = "Measured Arial face"
            let run = try #require(shape.textFrame?.paragraphs[0].runs[0])
            run.fontName = "Arial"; run.bold = style.bold; run.italic = style.italic
        }
        let unknown = try slide.shapes.addTextBox(Rect(x: .zero, y: .inches(5),
                                                     width: .inches(8), height: .inches(1)))
        unknown.textFrame?.text = "Unknown face"
        unknown.textFrame?.paragraphs[0].runs[0].fontName = "Missing QZX Test Typeface"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("faces.pptx"), bytes = try deck.serializedData()
        try bytes.write(to: url)
        let inspection = try DeckInspector.inspect(deckAt: url)
        let missing = inspection.previewDiagnostics.flatMap(\.issues).filter { $0.code == "missingFont" }
        #expect(missing.count == 1)
        #expect(missing.first?.message.contains("Missing QZX Test Typeface") == true)
        #expect(inspection.previews.count == 1)
        #expect(try Data(contentsOf: url) == bytes)
    }
    #endif
}
