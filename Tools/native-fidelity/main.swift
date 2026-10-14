import Foundation
import Rostrum
import RostrumLayout
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// One profile per process. The Python collector owns hashes and process RSS;
// these clocks isolate library phases, excluding artifact writes and checks.
struct Failure: Error, CustomStringConvertible { let description: String }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure(description: message) }
}
func need<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw Failure(description: message) }; return value
}
struct FontInput: Decodable {
    let family: String
    let regular: String
    let bold: String
    let italic: String
    let boldItalic: String?
}
struct Face: Codable {
    let role: String
    let path: String
    let familyNames: [String]
    let bold: Bool
    let italic: Bool
}
struct Timing: Codable { let elapsedMS: Double; let cpuMS: Double }
final class Measurements {
    var phases: [String: Timing] = [:]
    func measure<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
        let cpu = clock(), start = DispatchTime.now().uptimeNanoseconds
        let value = try body()
        phases[name] = Timing(elapsedMS: Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6,
            cpuMS: Double(clock() - cpu) * 1000 / Double(CLOCKS_PER_SEC))
        return value
    }
}
struct Page: Codable {
    let slide: Int
    let sourceRows: [Int]
    let columnWidthsEMU: [Int]
    let rowHeightsEMU: [Int]
}
struct Problems: Codable, Equatable {
    let layoutUnresolved: Bool
    let masterUnresolved: Bool
    let unsupportedContent: [String]
    let fidelityIssues: [FidelityIssue]
    init(_ value: SlideRenderProblems) {
        layoutUnresolved = value.layoutUnresolved; masterUnresolved = value.masterUnresolved
        unsupportedContent = value.unsupportedContent; fidelityIssues = value.fidelityIssues
    }
}
struct Report: Encodable {
    let schemaVersion = 1
    let family: String
    let faces: [Face]
    let aspect: String
    let fontMode: String
    let slideCount: Int
    let pages: [Page]
    let phases: [String: Timing]
    let portableChecks: [String]
    let powerpointSlideView = "pending"
    let powerpointExport = "pending"
    let lecternInspect = "pending"
    let nativeMacPerformance = "pending"
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
func write<T: Encodable>(_ value: T, _ url: URL) throws { try encoder.encode(value).write(to: url) }
func descendants(_ root: XML.Element, _ name: String) -> [XML.Element] {
    (root.name == name ? [root] : []) + root.childElements.flatMap { descendants($0, name) }
}
func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Rect {
    Rect(x: .points(x), y: .points(y), width: .points(width), height: .points(height))
}

// This controlled template declares levels 0 and 1. Retain line geometry as
// review evidence, not as a claim that PowerPoint uses these exact baselines.
func textGeometry(_ deck: Presentation) throws -> Data {
    var records: [[String: Any]] = []
    for index in 0..<deck.slideCount {
        let slide = try deck.slides[index]
        for node in descendants(try slide.part.dom(), "p:sp") {
            guard let body = node.firstChild(named: "p:txBody"), !descendants(body, "a:t").isEmpty else { continue }
            let id = node.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"].flatMap(Int.init)
            let shape = try need(slide.shapes.all.first { $0.shapeID == id }, "Text shape missing")
            let frame = try need(slide.effectiveFrame(of: shape), "Text frame missing")
            var inherited: [XML.Element] = []
            if let ph = node.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph"),
               let layout = slide.layout {
                let slot = Int(ph[attribute: "idx"] ?? "0") ?? 0
                let list = XML.Element("a:lstStyle")
                for level in 0...1 {
                    let defaults = layout.textDefaults(for: slot, level: level).paragraph
                    list.appendElement(XML.Element("a:lvl\(level + 1)pPr", attributes: defaults.attributes, children: defaults.children))
                }
                inherited = [layout.textDefaults(for: slot).body, list]
            }
            let text = RichTextLayout(textBody: body, width: frame.width.points, height: frame.height.points,
                fonts: deck.fonts, theme: slide.master?.theme, inheritedStyles: inherited, maxLines: 256)
            try require(text.fits && !text.truncated, "Portable text layout overflows slide \(index + 1), shape \(shape.name)")
            let lines: [[String: Any]] = text.lines.map { line in
                let spans: [[String: Any]] = line.spans.map { span in
                    ["text": span.run.text, "family": span.run.fontFamily ?? "", "sizePt": span.run.fontSize,
                     "bold": span.run.bold, "italic": span.run.italic, "xPt": span.x, "widthPt": span.width]
                }
                return ["baselinePt": line.baseline, "heightPt": line.height, "widthPt": line.width,
                        "visibleWidthPt": line.visibleWidth, "spans": spans]
            }
            records.append(["slide": index + 1, "shapeID": shape.shapeID ?? -1,
                "frameEMU": [frame.x.rawValue, frame.y.rawValue, frame.width.rawValue, frame.height.rawValue],
                "contentHeightPt": text.contentHeight, "lines": lines])
        }
    }
    return try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys, .prettyPrinted])
}

// A synthetic POTX with explicit, inherited body settings. It is retained next
// to the output so native review can distinguish authoring from import behavior.
func makeTemplate(width: Double, family: String) throws -> Presentation {
    let deck = try Presentation()
    deck.slideSize = (.points(width), .points(540))
    deck.theme.majorFont = family; deck.theme.minorFont = family
    let layout = try need(deck.layout(type: "obj"), "Object layout missing")
    let tree = try need(layout.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Layout tree missing")
    for node in tree.children(named: "p:sp") {
        guard let ph = node.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph") else { continue }
        let index = Int(ph[attribute: "idx"] ?? "0") ?? 0
        guard index == 0 || index == 1 else { continue }
        let frame = rect(36, index == 0 ? 24 : 100, width - 72, index == 0 ? 60 : 340)
        let properties = try need(node.firstChild(named: "p:spPr"), "Layout properties missing")
        properties.removeChildren(named: "a:xfrm")
        properties.children.insert(.element(XML.Element("a:xfrm", children: [
            .element(XML.Element("a:off", attributes: [("x", String(frame.x.rawValue)), ("y", String(frame.y.rawValue))])),
            .element(XML.Element("a:ext", attributes: [("cx", String(frame.width.rawValue)), ("cy", String(frame.height.rawValue))]))])), at: 0)
        let body = try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0" vertOverflow="clip"><a:noAutofit/></a:bodyPr><a:lstStyle>
        <a:lvl1pPr marL="0" marR="0" indent="0" algn="l"><a:lnSpc><a:spcPct val="110000"/></a:lnSpc><a:spcBef><a:spcPts val="0"/></a:spcBef><a:spcAft><a:spcPts val="600"/></a:spcAft><a:buNone/><a:tabLst><a:tab pos="2540000" algn="r"/></a:tabLst><a:defRPr sz="\(index == 0 ? 2800 : 2000)" b="0" i="0" kern="0" spc="0"><a:solidFill><a:srgbClr val="172B2A"/></a:solidFill><a:latin/></a:defRPr></a:lvl1pPr>
        <a:lvl2pPr marL="304800" indent="-152400" algn="l"><a:lnSpc><a:spcPct val="110000"/></a:lnSpc><a:spcBef><a:spcPts val="0"/></a:spcBef><a:spcAft><a:spcPts val="0"/></a:spcAft><a:buFont/><a:buChar char="•"/><a:defRPr sz="2000" b="0" i="0"><a:latin/></a:defRPr></a:lvl2pPr>
        </a:lstStyle><a:p/></p:txBody>
        """.utf8))
        for font in descendants(body, "a:latin") + descendants(body, "a:buFont") { font[attribute: "typeface"] = family }
        node.removeChildren(named: "p:txBody"); node.appendElement(body)
    }
    layout.part.markDirty(); deck.documentKind = .template
    return deck
}

func run() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    try require(args.count == 4, "Usage: native-fidelity FONTS.json OUTPUT 4x3|16x9 external|embedded")
    let configURL = URL(fileURLWithPath: args[0]).standardizedFileURL
    let output = URL(fileURLWithPath: args[1], isDirectory: true)
    try require(["4x3", "16x9"].contains(args[2]) && ["external", "embedded"].contains(args[3]), "Invalid aspect or font mode")
    try require(!FileManager.default.fileExists(atPath: output.path), "Output already exists; use a fresh directory")
    let input = try JSONDecoder().decode(FontInput.self, from: Data(contentsOf: configURL))
    let timer = Measurements()
    var faceData: [String: Data] = [:], identities: [Face] = []
    try timer.measure("fontReadAndValidate") {
        for (role, path, bold, italic) in [("regular", Optional(input.regular), false, false),
            ("bold", Optional(input.bold), true, false), ("italic", Optional(input.italic), false, true),
            ("boldItalic", input.boldItalic, true, true)] {
            guard let path else { continue }
            let url = URL(fileURLWithPath: path, relativeTo: configURL.deletingLastPathComponent()).standardizedFileURL
            let data = try Data(contentsOf: url), metrics = try FontMetrics(data: data)
            try require(metrics.familyNames.contains(input.family) && metrics.isBold == bold && metrics.isItalic == italic,
                "\(role): expected exact family '\(input.family)' and style (bold=\(bold), italic=\(italic)); got \(metrics.familyNames), bold=\(metrics.isBold), italic=\(metrics.isItalic)")
            faceData[role] = data
            identities.append(Face(role: role, path: url.path, familyNames: metrics.familyNames, bold: bold, italic: italic))
        }
    }
    func register(_ deck: Presentation) throws {
        for face in identities { try deck.fonts.register(try need(faceData[face.role], "Font data missing")) }
    }
    let width = args[2] == "4x3" ? 720.0 : 960.0
    let template = try timer.measure("templateConstruction") { try makeTemplate(width: width, family: input.family) }
    if args[3] == "embedded" {
        try timer.measure("fontEmbedding") {
            try template.embedFont(input.family, faces: .init(regular: try need(faceData["regular"], "Regular face missing"),
                bold: faceData["bold"], italic: faceData["italic"], boldItalic: faceData["boldItalic"]))
        }
    }
    let templateData = try template.serializedData()
    let deck = try timer.measure("templateImport") { try Presentation.fromTemplate(data: templateData) }
    try timer.measure("fontRegistration") { try register(deck) }
    let protected = Dictionary(uniqueKeysWithValues: deck.package.parts.values.filter {
        $0.uri.value.hasPrefix("/ppt/slideLayouts/") || $0.uri.value.hasPrefix("/ppt/slideMasters/") || $0.uri.value.hasPrefix("/ppt/theme/")
    }.map { ($0.uri, $0.blob) })
    let engine = TemplateLayoutEngine(presentation: deck)
    let layoutURI = try need(deck.layout(type: "obj"), "Imported layout missing").part.uri.value
    let paragraphs = [LayoutParagraph("Inherited font, tabs and soft breaks"),
        LayoutParagraph("Alpha\t12.5\nBeta\t38.0\nGamma\t7.25"), LayoutParagraph("Indented line retained", level: 1)]
    let title = "Rostrum in Lectern"
    let textPlan = try timer.measure("textPlan") {
        try engine.plan(title: title, columns: [paragraphs], preferredTypes: ["obj"], layoutURI: layoutURI)
    }
    let textSlide = try timer.measure("textCompose") { try engine.compose(textPlan, title: title, columns: [paragraphs]) }
    let mixed = try textSlide.shapes.addTextBox(rect(36, 450, width - 72, 60)).textFrame!
    mixed.clear(); mixed.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
    let line = mixed.addParagraph()
    var mixedText = ""
    for (index, face) in identities.enumerated() {
        let text = "\(face.role): AV office café. "
        mixedText += text
        let run = line.addRun(text)
        run.fontName = input.family; run.fontSize = index == 0 ? 22 : 18
        run.bold = face.bold; run.italic = face.italic
    }
    var rows = [["Grouped evidence", "", "State"]]
    for index in 1...24 {
        rows.append(["Record \(index)", "Exact source evidence \(index) stays editable and wraps at full size.", "Reviewed"])
    }
    let table = TemplateTableContent(rows: rows, columnSizing: .measured(),
        merges: [.init(row: 0, column: 0, rowSpan: 1, columnSpan: 2)])
    let tablePlan = try timer.measure("tablePlan") {
        try engine.planTablePages(title: "Measured table continuations", table: table,
            caption: "Exact rows, repeated header, full-size cells.", preferredTypes: ["obj"], layoutURI: layoutURI)
    }
    let tableSlides = try timer.measure("tableComposeWithFreshChecks") { try engine.composeTablePages(tablePlan) }
    for index in 0..<deck.slideCount { try deck.slides[index].setNotes("Native fidelity fixture: slide \(index + 1). Preserve these exact notes.") }
    try deck.setSections([("Typography", 0), ("Tables", 1)])
    let pages = try tablePlan.pages.enumerated().map { index, page in
        let geometry = try need(page.slide.tableLayout, "Table geometry missing")
        return Page(slide: index + 2, sourceRows: Array(page.bodyRows),
            columnWidthsEMU: geometry.columnWidths.map(\.rawValue), rowHeightsEMU: geometry.rowHeights.map(\.rawValue))
    }
    let saved = try timer.measure("save") { try deck.serializedData() }
    let reopened = try timer.measure("reopen") { try Presentation(data: saved) }
    try timer.measure("reopenFontRegistration") {
        if args[3] == "embedded" { _ = reopened.registerEmbeddedFonts() } else { try register(reopened) }
        for face in identities {
            try require(reopened.fonts.metrics(for: input.family, bold: face.bold, italic: face.italic) != nil, "Reopened face missing: \(face.role)")
        }
    }
    let before = try (0..<deck.slideCount).map { try deck.renderSVGReportingProblems(slideAt: $0) }
    let after = try timer.measure("savedDeckSVG") {
        try (0..<reopened.slideCount).map { try reopened.renderSVGReportingProblems(slideAt: $0) }
    }
    let geometry = try textGeometry(reopened)
    try require(try geometry == textGeometry(deck), "Saved text line geometry changed")
    try require(before.map(\.svg) == after.map(\.svg) && before.map { Problems($0.problems) } == after.map { Problems($0.problems) }, "Saved SVG or ordered diagnostics changed")
    try require(try deck.serializedData() == saved && reopened.serializedData() == saved, "Save is nondeterministic or preview mutated the deck")
    try require(protected.allSatisfy { reopened.package.parts[$0.key]?.blob == $0.value }, "Template parts changed")
    try reopened.validateTemplateBindings()
    try require(try reopened.validate().isEmpty, "Saved deck failed required-attribute schema lint")
    let savedText = try reopened.slides[0]
    try require(savedText.placeholder(idx: 1)?.textFrame?.paragraphs.map(\.plainText) == paragraphs.map(\.text), "Inherited text changed")
    try require(savedText.placeholder(idx: 1)?.textFrame?.paragraphs.allSatisfy { $0.runs.allSatisfy { $0.fontSize == nil } } == true, "Template font size lost inheritance")
    try require(savedText.shapes.all.last?.textFrame?.text == mixedText, "Mixed run text changed")
    try require(descendants(try savedText.part.dom(), "a:br").count == 2, "Soft breaks changed")
    try require(tableSlides.count == pages.count && pages.flatMap(\.sourceRows) == Array(1...24), "Pagination lost or duplicated rows")
    for page in pages {
        let slide = try reopened.slides[page.slide - 1]
        let tbl = try need(descendants(try slide.part.dom(), "a:tbl").first, "Saved native table missing")
        let nativeRows = tbl.children(named: "a:tr")
        let values = nativeRows.map { $0.children(named: "a:tc").map { descendants($0, "a:t").map(\.textContent).joined() } }
        try require(values == [rows[0]] + page.sourceRows.map { rows[$0] }, "Saved table words changed")
        try require(nativeRows.compactMap { $0[attribute: "h"].flatMap(Int.init) } == page.rowHeightsEMU, "Row heights changed")
        try require(descendants(tbl, "a:gridCol").compactMap { $0[attribute: "w"].flatMap(Int.init) } == page.columnWidthsEMU, "Column widths changed")
    }
    for index in 0..<reopened.slideCount {
        let slide = try reopened.slides[index]
        try require(slide.notesText == "Native fidelity fixture: slide \(index + 1). Preserve these exact notes.", "Notes changed")
        for shape in slide.shapes.all {
            if let frame = slide.effectiveFrame(of: shape) {
                try require(frame.x >= .zero && frame.y >= .zero && frame.maxX <= reopened.bounds.width && frame.maxY <= reopened.bounds.height, "Shape outside canvas")
            }
        }
    }
    try require(reopened.sections.map(\.name) == ["Typography", "Tables"], "Sections changed")
    try require(reopened.sections.map(\.slideIndices) == [[0], Array(1..<reopened.slideCount)], "Section membership changed")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
    try templateData.write(to: output.appendingPathComponent("input.potx"))
    try saved.write(to: output.appendingPathComponent("deck.pptx"))
    try geometry.write(to: output.appendingPathComponent("text-geometry.json"))
    for (index, rendered) in after.enumerated() {
        try Data(rendered.svg.utf8).write(to: output.appendingPathComponent("slide-\(index + 1).svg"))
        try write(Problems(rendered.problems), output.appendingPathComponent("slide-\(index + 1)-diagnostics.json"))
    }
    let report = Report(family: input.family, faces: identities, aspect: args[2], fontMode: args[3], slideCount: reopened.slideCount,
        pages: pages, phases: timer.phases, portableChecks: ["deterministic-save", "saved-svg-and-ordered-diagnostics", "template-parts-unchanged",
            "template-bindings", "required-attribute-lint", "inherited-text-and-soft-breaks", "mixed-runs", "text-fit-and-line-geometry", "all-source-rows", "column-widths-and-row-heights", "notes-and-sections", "shape-bounds"])
    try write(report, output.appendingPathComponent("report.json"))
    print("\(args[2]) \(args[3]): \(reopened.slideCount) slides; portable checks passed; native review pending")
}
do { try run() } catch {
    FileHandle.standardError.write(Data("native-fidelity: \(error)\n".utf8)); exit(1)
}
