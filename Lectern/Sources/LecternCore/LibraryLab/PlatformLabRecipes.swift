import Foundation
import Rostrum

/// Offline recipes backed by concrete public library calls, not screenshots.
enum PlatformLabRecipes {
    static let catalog: [LibraryLabRecipe] = [
        .init(.layouts, title: "Layouts and placeholders", summary: "Compare cloned placeholders with a layout-bound canvas and inspect inherited geometry and master ordering.", operations: ["Presentation.layouts", "layout(type:)", "layout(named:)", "Slides.add(clonedFrom:)", "Presentation.titleSlide / bulletSlide (layout-bound builders)", "Shape.markAsPlaceholder", "Slide.effectiveFrame", "Presentation.slideMasters", "Presentation.theme"], inputs: [.text, .alternative], alternativeLabel: "Use title-and-content layout"),
        .init(.fontsAndFitting, title: "Fonts, shaping and fitting", summary: "Measure and fit text with a bundled licensed font, then embed and reopen it.", operations: ["FontLibrary.register", "FontLibrary.metrics(for:bold:italic:)", "TextMeasurer.width", "TextMeasurer.wrap", "TextShaper.shape", "TextFrame.fitText", "Presentation.embedFont", "Presentation.registerEmbeddedFonts"], limitations: ["Only the licensed regular DejaVu face is bundled; unavailable bold and italic faces are reported, never synthesized.", "Shaping supports a bounded script and positioning profile; diagnostics remain visible."], inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Use a narrower fitting box"),
        .init(.paragraphLayout, title: "Paragraph spacing and justification", summary: "Compare left and justified mixed-size paragraphs, fit both columns, and reopen their measured positions.", operations: ["Paragraph.alignment", "Paragraph.addRun", "Shape.fitText", "TextFrame.fitText", "RichTextLayout.init", "ShapeCollection.addTable", "TableCell.textFrame", "Presentation.embedFont", "Presentation.registerEmbeddedFonts", "Presentation.renderSVG", "DeckExport.write"], limitations: ["Justification expands interior spaces for bounded left-to-right Latin text; the final paragraph line stays natural. Explicit line breaks can expand.", "Tabs, right-to-left and non-Latin justification, distributed and low justification remain diagnosed limitations.", "The sample body uses fixed English text and a bundled regular DejaVu face. Your text changes the title; sample size changes sentence count. No general PowerPoint pixel-parity claim is made."], inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Use narrower paragraph columns"),
        .init(.theme, title: "Theme palette and fonts", summary: "Change a theme slot and watch scheme-colored shapes resolve to the new palette.", operations: ["Theme.setColor", "Theme.setAccent", "Theme.resolve", "Theme.majorFont", "Theme.minorFont", "Fill.themeColor"], inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Tint the scheme color"),
        .init(.templates, title: "Templates and document properties", summary: "Export real POTX and PPSX variants with core, extended and typed custom properties.", operations: ["Presentation.documentKind", "Presentation.slideSize", "DocumentProperties", "DocumentProperties.setCustomValue", "Presentation.serializedData"], limitations: ["Document-kind and schema checks are not an Office interoperability certificate."], inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Use a 4:3 canvas"),
        .init(.design, title: "Design system and slide builders", summary: "Run every shipped slide builder plus reusable components on a parsed design system.", operations: ["Design.parse", "Presentation.applyDesign", "DeckStyle", "Grid.cell", "Rect.split", "Color.bestTextColor", "titleSlide", "sectionSlide", "closingSlide", "bulletSlide", "twoColumnSlide", "comparisonSlide", "processSlide", "pyramidSlide", "smartArtSlide", "bandsSlide", "metricsSlide", "chartSlide", "calloutSlide", "quoteSlide", "timelineSlide", "quadrantSlide", "statementSlide", "calloutBandSlide", "tableSlide", "addText", "addParagraphs", "addBulletList", "addKicker", "addStatTile", "addAccentRule", "addCard", "addButton", "addChip", "sideImagePanel"], limitations: ["Builder capacities deliberately cap dense input; this recipe records the actual retained counts.", "SmartArt is packaged as editable diagram data; SVG preview fidelity is limited.", "Design spacing/type tokens are in-memory authoring inputs; their emitted geometry and text survive reopening."], inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Use a dark design"),
        .init(.mediaAndAttachments, title: "Media and foreign shape taxonomy", summary: "Embed valid owned audio/video, export their bytes, and inspect preserved group, connector and OLE XML.", operations: ["ShapeCollection.addMedia", "Picture.mediaData", "Picture.isAudio", "GroupShape.shapes", "GroupShape.convertToParentSpace", "Connector.startConnection", "GraphicFrame.graphicData", "Part.replaceBlob", "DeckExport.write"], limitations: ["SVG shows media posters, not playback; no animation is authored.", "Group, connector and OLE examples use owned low-level XML to demonstrate reading/preservation, not nonexistent high-level authoring APIs.", "The OLE frame carries an owned spreadsheet package; embedded-object activation is not implemented."], inputs: [.text, .alternative], alternativeLabel: "Omit the explicit video poster"),
        .init(.package, title: "ZIP, XML and package inspection", summary: "Inspect a bounded lazy OPC archive, demonstrate cache hits, promote it for editing, and preserve an unknown extension.", operations: ["OPCArchive.init", "OPCArchive.data(forPart:)", "OPCArchive.xml(forPart:)", "OPCArchive.clearCache", "OPCArchive.presentation", "OPCPackage.addPart", "Relationships.add", "ZipReader", "XML.parse", "Presentation.validate"], limitations: ["Validation checks required attributes; it is not complete XSD or Office conformance validation."], inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Validate payloads on access"),
        .init(.extractionAndRendering, title: "Extraction and honest previews", summary: "Extract Markdown, images and chart CSV, and compare ordinary, strict and notes SVG rendering.", operations: ["Presentation.outline", "DeckOutline.markdown", "DeckExport.write", "Presentation.renderSVG", "Presentation.renderSVGReportingProblems", "Presentation.renderNotesSVGReportingProblems"], limitations: ["Strict rendering refuses detected unsupported content; an empty report is not a universal fidelity guarantee.", "The diagnostic slide intentionally uses unregistered text or unsupported bidirectional geometry."], inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Use a bidirectional diagnostic sample")
    ]

    static func make(_ id: LibraryDemoID, options: LibraryLabOptions) throws -> LibraryLabDraft {
        guard (2...12).contains(options.sampleSize), Color(validating: options.accentHex) != nil else {
            throw RostrumError.packageInvalid("Library Lab expects a sample size from 2 to 12 and a six-digit accent color")
        }
        switch id {
        case .layouts: return try layouts(options)
        case .fontsAndFitting: return try fonts(options)
        case .paragraphLayout: return try paragraphLayout(options)
        case .theme: return try theme(options)
        case .templates: return try templates(options)
        case .design: return try design(options)
        case .mediaAndAttachments: return try media(options)
        case .package: return try package(options)
        case .extractionAndRendering: return try extraction(options)
        default: throw RostrumError.packageInvalid("Not a platform recipe: \(id.rawValue)")
        }
    }

    static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw RostrumError.packageInvalid(message) }
        return value
    }
    static func resource(_ name: String, _ ext: String) throws -> Data {
        let url = try require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "LibraryLab"), "Missing bundled Library Lab resource: \(name).\(ext)")
        return try Data(contentsOf: url)
    }
    static func label(_ options: LibraryLabOptions) -> String {
        let value = String(options.text.prefix(120))
        return value.isEmpty ? "Library Lab" : value
    }
    @discardableResult
    static func text(_ value: String, on slide: Slide, in frame: Rect = LibraryLabSupport.frame(0.6, 0.5, 11, 1), font: String = "DejaVu Sans") throws -> Shape {
        let box = try slide.shapes.addTextBox(frame)
        box.textFrame?.text = value
        for paragraph in box.textFrame?.paragraphs ?? [] {
            for run in paragraph.runs { run.fontName = font; run.fontSize = 24 }
        }
        return box
    }
    static func exportedFiles(_ deck: Presentation) throws -> (files: [String: Data], assets: Int, charts: Int) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PlatformLab-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let summary = try DeckExport.write(deck, to: directory, named: "library-lab")
        var files: [String: Data] = [:]
        let paths = try require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]), "Cannot enumerate owned extraction directory")
        for case let url as URL in paths {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                let rootPath = directory.resolvingSymlinksInPath().path + "/"
                let filePath = url.resolvingSymlinksInPath().path
                guard filePath.hasPrefix(rootPath) else { throw RostrumError.packageInvalid("Extraction escaped its owned directory") }
                files["extraction-" + String(filePath.dropFirst(rootPath.count)).replacingOccurrences(of: "/", with: "--")] = try Data(contentsOf: url)
            }
        }
        return (files, summary.assetsWritten, summary.chartsWritten)
    }
}
