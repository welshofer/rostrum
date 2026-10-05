import Foundation
import CoreText
import CoreGraphics
import Rostrum
import RostrumLayout

struct Source: Decodable { let title: String; let url: String }
struct Item: Decodable { let label: String; let text: String }
struct ChartSpec: Decodable { let categories: [String]; let values: [Double]; let label: String }
struct SlideSpec: Decodable {
    let title: String
    let layout: String
    let subtitle: String?
    let body: [String]?
    let items: [Item]?
    let image: String?
    let imageCaption: String?
    let table: [[String]]?
    let chart: ChartSpec?
    let notes: String
    let sources: [Source]
    let comment: String?
}
struct SectionSpec: Decodable { let name: String; let start: Int }
struct Content: Decodable { let slides: [SlideSpec]; let sections: [SectionSpec] }
struct PreviewRecord: Encodable {
    let slide: Int; let title: String; let layout: String
    let file: String; let fidelityIssues: [FidelityIssue]
}
struct Validation: Encodable {
    let authoringLibraries: [String]
    let slideCount: Int; let notesCount: Int; let commentsCount: Int
    let pictureCount: Int; let croppedPictureCount: Int
    let tableCount: Int; let chartCount: Int; let sectionCount: Int
    let layoutCount: Int; let allTemplateBindingsValid: Bool
    let nativePowerPointVerified: Bool
    let previews: [PreviewRecord]
}
struct BuildFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

enum Palette {
    static let paper = Color("F3EFE5")
    static let forest = Color("163831")
    static let rust = Color("B86542")
    static let gold = Color("CDA66E")
    static let ink = Color("172B2A")
    static let muted = Color("4C625D")
    static let pale = Color("E2E8DE")
}
let canvasW = 13.333333
let canvasH = 7.5
func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Rect {
    Rect(x: .inches(x), y: .inches(y), width: .inches(w), height: .inches(h))
}
func fontHeight(text: String, font: String, size: Double, bold: Bool = false,
                tracking: Double = 0, width: Double) -> Double {
    var face = CTFontCreateWithName(font as CFString, size, nil)
    if bold, let variant = CTFontCreateCopyWithSymbolicTraits(face, size, nil, .boldTrait, .boldTrait) {
        face = variant
    }
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): face,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking
    ])
    let setter = CTFramesetterCreateWithAttributedString(attributed)
    let measured = CTFramesetterSuggestFrameSizeWithConstraints(setter,
        CFRange(location: 0, length: 0), nil,
        CGSize(width: max(1, width), height: 1_000_000), nil)
    return ceil(measured.height)
}

@MainActor
final class Builder {
    let project: URL
    let deck: Presentation
    let content: Content
    let authored: AuthoredLayoutEngine
    let measure: TextHeightMeasurer
    let output: URL
    let previewDirectory: URL
    var imageCache: [String: Data] = [:]
    let heading = "Georgia"
    let bodyFont = "Arial"

    init(project: URL) throws {
        self.project = project
        self.content = try JSONDecoder().decode(Content.self,
            from: Data(contentsOf: project.appendingPathComponent("content.json")))
        guard content.slides.count == 28 else {
            throw BuildFailure("The demo contract requires 28 slides, received \(content.slides.count).")
        }
        deck = try Presentation()
        while deck.slides.count > 0 { try deck.slides.remove(at: 0) }
        deck.slideSize = (.inches(canvasW), .inches(canvasH))
        deck.applyDesign(Design(name: "Horseshoe Curve / Mountain, Iron, Memory",
            headingFont: "Georgia", bodyFont: "Arial",
            palette: [Palette.rust, Palette.forest, Palette.gold],
            colors: ["background": Palette.paper, "ink": Palette.ink,
                     "surface": Palette.pale],
            typeScale: [
                "title": .init(sizePt: 40, weight: 400, lineHeight: 1.05),
                "heading": .init(sizePt: 28, weight: 400, lineHeight: 1.1),
                "body": .init(sizePt: 23, lineHeight: 1.15),
                "caption": .init(sizePt: 13, lineHeight: 1.1)
            ]))
        try deck.compileThemeMaster()
        measure = { request in
            fontHeight(text: request.text, font: request.font, size: request.size,
                       bold: request.bold, tracking: request.tracking, width: request.width)
        }
        authored = AuthoredLayoutEngine(presentation: deck, measure: measure)
        output = project.appendingPathComponent("Horseshoe-Curve.pptx")
        previewDirectory = project.appendingPathComponent("previews", isDirectory: true)
        try registerFonts(in: deck)
    }

    func registerFonts(in deck: Presentation) throws {
        let directory = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental", isDirectory: true)
        for name in ["Georgia.ttf", "Georgia Bold.ttf", "Georgia Italic.ttf", "Georgia Bold Italic.ttf",
                     "Arial.ttf", "Arial Bold.ttf", "Arial Italic.ttf", "Arial Bold Italic.ttf"] {
            try deck.fonts.register(contentsOf: directory.appendingPathComponent(name))
        }
    }

    @discardableResult
    func text(_ s: Slide, _ value: String, _ frame: Rect, size: Double = 23,
              color: Color = Palette.ink, font: String? = nil, bold: Bool = false,
              align: TextAlignment = .left, anchor: VerticalAnchor = .top,
              line: Double = 1.08, tracking: Double = 0, title: Bool = false,
              fill: Color? = nil, inset: Double = 0, hyperlink: String? = nil) throws -> Shape {
        let shape = try s.shapes.addTextBox(frame)
        if let fill { try shape.setFill(.solid(fill)) }
        let tf = shape.textFrame!
        tf.clear()
        tf.setMargins(left: .inches(inset), top: .inches(inset),
                      right: .inches(inset), bottom: .inches(inset))
        tf.verticalAnchor = anchor
        // Separate lines remain separate paragraphs in the native deck.
        for value in value.components(separatedBy: "\n") {
            let paragraph = tf.addParagraph()
            paragraph.setNoBullet()
            paragraph.setIndentation(left: .zero, hanging: .zero)
            paragraph.alignment = align
            paragraph.setLineSpacing(line)
            paragraph.setSpacing(beforePoints: 0, afterPoints: 0)
            let run = paragraph.addRun(value)
            run.fontName = font ?? bodyFont
            run.fontSize = size
            run.bold = bold
            run.color = color
            if tracking != 0 { run.letterSpacing = tracking }
            if let hyperlink { run.setHyperlink(hyperlink) }
        }
        if title { shape.markAsPlaceholder(type: "title") }
        return shape
    }

    @discardableResult
    func block(_ s: Slide, _ values: [String], x: Double, y: Double, width: Double,
               bottom: Double = 6.65, size: Double = 23, color: Color = Palette.ink,
               gap: Double = 0.24) throws -> Double {
        var cursor = y
        for value in values where !value.isEmpty {
            let height = max(0.42, fontHeight(text: value, font: bodyFont,
                size: size, width: width * 72) * 1.18 / 72 + 0.07)
            guard cursor + height <= bottom + 0.01 else {
                throw BuildFailure("Body overflow at ‘\(value.prefix(65))’; needs \(String(format: "%.2f", cursor + height)) in, limit \(bottom).")
            }
            try text(s, value, rect(x, cursor, width, height), size: size, color: color, line: 1.12)
            cursor += height + gap
        }
        return cursor
    }

    func rule(_ s: Slide, x: Double, y: Double, width: Double,
              color: Color = Palette.rust, height: Double = 0.025) throws {
        try s.shapes.addShape(.rectangle, frame: rect(x, y, width, height), fill: .solid(color))
    }

    func image(_ s: Slide, spec: SlideSpec, frame: Rect) throws {
        guard let name = spec.image else { throw BuildFailure("Layout \(spec.layout) requires image: \(spec.title)") }
        let bytes: Data
        if let cached = imageCache[name] { bytes = cached }
        else {
            bytes = try Data(contentsOf: project.appendingPathComponent("images").appendingPathComponent(name))
            imageCache[name] = bytes
        }
        let p = try s.shapes.addPicture(bytes, frame: frame, fit: .fill)
        p.altText = spec.imageCaption ?? "AI-generated interpretive illustration for \(spec.title); not an archival photograph."
    }

    func kicker(_ s: Slide, index: Int, dark: Bool = false, x: Double = 0.65,
                y: Double = 0.38, width: Double = 11.5) throws {
        let section = content.sections.last(where: { $0.start <= index })?.name ?? "Horseshoe Curve"
        try text(s, section.uppercased(), rect(x, y, width, 0.28),
                 size: 12, color: dark ? Palette.gold : Palette.rust, bold: true, tracking: 1.8)
    }

    func footer(_ s: Slide, spec: SlideSpec, index: Int, dark: Bool = false,
                photo: Bool = false) throws {
        let color = dark ? Palette.paper : Palette.muted
        let source = spec.sources.first.map { "SOURCE  \($0.title)" } ?? "HORSESHOE CURVE · ALTOONA, PENNSYLVANIA"
        let label = source.count > 108 ? String(source.prefix(105)) + "…" : source
        try text(s, label, rect(0.65, 7.04, 10.9, 0.26), size: 10.8,
                 color: color, fill: photo ? Palette.forest : nil)
        try text(s, String(format: "%02d / %02d", index + 1, content.slides.count),
                 rect(11.82, 7.00, 0.87, 0.30), size: 11.5,
                 color: color, align: .right, fill: photo ? Palette.forest : nil)
    }

    func standardTitle(_ s: Slide, spec: SlideSpec, index: Int,
                       dark: Bool = false) throws {
        try kicker(s, index: index, dark: dark)
        try text(s, spec.title, rect(0.65, 0.94, 12.0, 1.12), size: 39,
                 color: dark ? Palette.paper : Palette.ink, font: heading, title: true)
        if let subtitle = spec.subtitle, !subtitle.isEmpty {
            try text(s, subtitle, rect(0.67, 2.08, 11.85, 0.65), size: 21,
                     color: dark ? Palette.pale : Palette.muted)
        }
    }

    func positiveAxis(for values: [Double]) -> (maximum: Double, majorUnit: Double) {
        let peak = max(values.max() ?? 0, 1)
        let targetUnit = peak / 6
        let magnitude = pow(10.0, floor(log10(targetUnit)))
        let fraction = targetUnit / magnitude
        let step: Double
        switch fraction {
        case ..<1.5: step = 1
        case ..<3.5: step = 2
        case ..<7.5: step = 5
        default: step = 10
        }
        let majorUnit = step * magnitude
        return (ceil(peak / majorUnit) * majorUnit, majorUnit)
    }

    func caption(_ s: Slide, spec: SlideSpec, frame: Rect,
                 dark: Bool = false) throws {
        if let caption = spec.imageCaption, !caption.isEmpty {
            try text(s, caption, frame, size: 12.5,
                     color: dark ? Palette.paper : Palette.muted, line: 1.04)
        }
    }

    func compose(_ spec: SlideSpec, index: Int) throws -> Slide {
        let s = try deck.slides.add(clonedFrom: deck.layout(type: "blank")!)
        try s.setBackground(.solid(Palette.paper))
        var publish = true
        var dark = false
        var photoFooter = false
        switch spec.layout {
        case "cover", "closing":
            dark = true; publish = false; photoFooter = true
            try s.setBackground(.solid(Palette.forest))
            if spec.image != nil {
                try image(s, spec: spec, frame: rect(0, 0, canvasW, canvasH))
                try text(s, spec.imageCaption ?? "AI-generated interpretive illustration; not an archival photograph.",
                         rect(0.65, 4.08, 12.03, 0.35), size: 12.5,
                         color: Palette.paper, line: 1.04, fill: Palette.forest, inset: 0.05)
            }
            // This panel remains slide-owned because finish is deliberately not called.
            try s.shapes.addShape(.rectangle, frame: rect(0, 4.45, canvasW, 3.05), fill: .solid(Palette.forest))
            try text(s, spec.layout == "cover" ? "ALTOONA, PENNSYLVANIA" : "MOUNTAIN · IRON · MEMORY",
                     rect(0.68, 4.70, 11.8, 0.28), size: 12, color: Palette.gold,
                     bold: true, tracking: 2.2)
            try text(s, spec.title, rect(0.65, 5.13, 12.0, 0.95), size: 45,
                     color: Palette.paper, font: heading, title: true)
            if let subtitle = spec.subtitle {
                try text(s, subtitle, rect(0.70, 6.20, 11.65, 0.55), size: 22, color: Palette.pale)
            }
            if let body = spec.body, !body.isEmpty {
                _ = try block(s, body, x: 0.7, y: 6.12, width: 11.8, bottom: 6.83, size: 22, color: Palette.pale)
            }
        case "imageRight", "imageLeft":
            let right = spec.layout == "imageRight"
            let textX = right ? 0.65 : 7.37
            let imageX = right ? 6.10 : 0.0
            let imageW = right ? canvasW - imageX : 6.75
            try image(s, spec: spec, frame: rect(imageX, 0, imageW, 6.22))
            try kicker(s, index: index, x: textX, y: 0.40, width: 5.25)
            try text(s, spec.title, rect(textX, 1.02, 5.28, 1.80), size: 38,
                     font: heading, title: true)
            var lines = spec.body ?? []
            if let subtitle = spec.subtitle { lines.insert(subtitle, at: 0) }
            _ = try block(s, lines, x: textX + 0.02, y: 3.02, width: 4.93,
                          bottom: 6.43, size: 22, gap: 0.23)
            try caption(s, spec: spec, frame: rect(imageX + 0.18, 6.34, imageW - 0.36, 0.43))
        case "imageWide":
            try kicker(s, index: index)
            try text(s, spec.title, rect(0.65, 0.90, 12.0, 0.95), size: 38, font: heading, title: true)
            try image(s, spec: spec, frame: rect(0.65, 2.0, 12.03, 3.35))
            try caption(s, spec: spec, frame: rect(0.69, 5.43, 11.94, 0.40))
            var lines = spec.body ?? []
            if let subtitle = spec.subtitle { lines.insert(subtitle, at: 0) }
            _ = try block(s, lines, x: 0.69, y: 5.86, width: 11.94, bottom: 6.82, size: 22, gap: 0.12)
        case "statement":
            dark = true
            try s.setBackground(.solid(Palette.forest))
            try kicker(s, index: index, dark: true)
            try rule(s, x: 0.70, y: 1.47, width: 1.05, color: Palette.gold, height: 0.045)
            try text(s, spec.title, rect(0.67, 1.96, 11.8, 2.5), size: 51,
                     color: Palette.paper, font: heading, line: 1.06, title: true)
            var lines = spec.body ?? []
            if let subtitle = spec.subtitle { lines.insert(subtitle, at: 0) }
            _ = try block(s, lines, x: 0.72, y: 5.00, width: 10.5, bottom: 6.55,
                          size: 23, color: Palette.pale, gap: 0.22)
        case "bigDate":
            try kicker(s, index: index)
            try text(s, spec.subtitle ?? "1854", rect(0.48, 1.69, 5.70, 2.42),
                     size: 111, color: Palette.rust, font: heading)
            try rule(s, x: 6.10, y: 1.55, width: 0.024, color: Palette.gold, height: 4.63)
            try text(s, spec.title, rect(6.52, 1.64, 6.05, 1.80), size: 38,
                     font: heading, title: true)
            _ = try block(s, spec.body ?? [], x: 6.57, y: 3.72, width: 5.63,
                          bottom: 6.48, size: 22)
        case "comparison":
            try standardTitle(s, spec: spec, index: index)
            let top = spec.subtitle == nil ? 2.50 : 3.00
            let items = spec.items ?? []
            guard items.count == 2 else { throw BuildFailure("Comparison needs exactly two items.") }
            for (i, item) in items.enumerated() {
                let x = 0.68 + Double(i) * 6.30
                try rule(s, x: x, y: top, width: 5.54, color: i == 0 ? Palette.rust : Palette.forest, height: 0.045)
                try text(s, item.label, rect(x, top + 0.26, 5.42, 0.80), size: 30,
                         color: i == 0 ? Palette.rust : Palette.forest, font: heading)
                _ = try block(s, [item.text], x: x + 0.02, y: top + 1.28,
                              width: 5.25, bottom: 6.63, size: 23)
            }
        case "timeline":
            try standardTitle(s, spec: spec, index: index)
            let items = spec.items ?? []
            guard (3...5).contains(items.count) else { throw BuildFailure("Timeline needs 3–5 events.") }
            let top = spec.subtitle == nil ? 2.63 : 3.05
            let region = rect(0.67, top, 12.0, 3.49)
            let cells = try StructuredLayout.frames(kind: .timeline, count: items.count, in: region)
            // Use RostrumLayout's row allocation for 3–4 events; five are intentionally one horizontal row.
            let width = 12.0 / Double(items.count)
            try rule(s, x: 0.75, y: top + 0.93, width: 11.55, color: Palette.gold, height: 0.035)
            for (i, item) in items.enumerated() {
                let x = items.count <= 4 ? cells[i].x.inches : 0.67 + Double(i) * width
                let cellW = items.count <= 4 ? cells[i].width.inches : width - 0.22
                try text(s, item.label, rect(x, top + 0.09, cellW, 0.61), size: 29,
                         color: Palette.rust, font: heading)
                try s.shapes.addShape(.ellipse, frame: rect(x + 0.04, top + 0.86, 0.17, 0.17), fill: .solid(Palette.rust))
                _ = try block(s, [item.text], x: x + 0.015, y: top + 1.28,
                              width: cellW - 0.16, bottom: 6.60, size: items.count == 5 ? 19.5 : 21,
                              gap: 0.1)
            }
        case "table":
            try standardTitle(s, spec: spec, index: index)
            guard let values = spec.table, !values.isEmpty,
                  let columns = values.first?.count, columns > 0,
                  values.allSatisfy({ $0.count == columns }) else {
                throw BuildFailure("Table requires a rectangular nonempty matrix.")
            }
            let top = spec.subtitle == nil ? 2.55 : 2.92
            let area = rect(0.67, top, 12.0, 6.55 - top)
            let table = try s.shapes.addTable(rows: values.count, columns: columns, frame: area)
            table.clearBuiltInStyle()
            let weights: [Double] = columns == 3 ? [0.19, 0.40, 0.41] : Array(repeating: 1.0 / Double(columns), count: columns)
            table.columnWidths(weights.map { .inches($0 * 12.0) })
            var heights: [Double] = []
            let tableSize = 18.5
            for (row, values) in values.enumerated() {
                let needed = zip(values, weights).map { value, weight in
                    fontHeight(text: value, font: bodyFont, size: tableSize,
                               bold: row == 0, width: (12.0 * weight - 0.33) * 72) * 1.12 / 72 + 0.25
                }.max() ?? 0.50
                heights.append(max(row == 0 ? 0.60 : 0.65, needed))
            }
            let available = area.height.inches
            guard heights.reduce(0, +) <= available else {
                throw BuildFailure("Table ‘\(spec.title)’ needs \(heights.reduce(0, +)) inches, only \(available) available.")
            }
            let extra = (available - heights.reduce(0, +)) / Double(heights.count)
            table.rowHeights(heights.map { .inches($0 + extra) })
            for (rowIndex, row) in values.enumerated() {
                for (colIndex, value) in row.enumerated() {
                    let cell = try table.cell(rowIndex, colIndex)
                    cell.verticalAnchor = .middle
                    try cell.setFill(.solid(rowIndex == 0 ? Palette.forest : (rowIndex % 2 == 0 ? Palette.pale : Palette.paper)))
                    let tf = cell.textFrame
                    tf.clear()
                    tf.setMargins(left: .inches(0.16), top: .zero, right: .inches(0.14), bottom: .zero)
                    let p = tf.addParagraph()
                    p.setNoBullet(); p.setLineSpacing(1.06)
                    let r = p.addRun(value)
                    r.fontName = bodyFont; r.fontSize = tableSize
                    r.bold = rowIndex == 0 || colIndex == 0
                    r.color = rowIndex == 0 ? Palette.paper : Palette.ink
                }
            }
        case "chart":
            try standardTitle(s, spec: spec, index: index)
            guard let chart = spec.chart,
                  chart.categories.count == chart.values.count else { throw BuildFailure("Chart data mismatch.") }
            let axis = positiveAxis(for: chart.values)
            try s.shapes.addChart(.barClustered,
                data: ChartData(categories: chart.categories, name: chart.label, values: chart.values),
                frame: rect(0.64, 2.58, 8.2, 3.94), colors: [Palette.rust],
                options: ChartOptions(title: chart.label,
                    dataLabels: DataLabelOptions(showValue: true),
                    valueAxis: AxisOptions(min: 0, max: axis.maximum,
                                           majorUnit: axis.majorUnit, gridlines: true),
                    text: ChartTextStyle(font: bodyFont, color: Palette.ink, sizePt: 17)))
            try rule(s, x: 9.12, y: 2.81, width: 0.025, color: Palette.gold, height: 3.55)
            _ = try block(s, spec.body ?? [], x: 9.48, y: 2.85, width: 3.00,
                          bottom: 6.42, size: 21)
        case "feature":
            try image(s, spec: spec, frame: rect(0, 0, 7.48, 6.22))
            try kicker(s, index: index, x: 7.88, y: 0.42, width: 4.71)
            try text(s, spec.title, rect(7.88, 1.15, 4.70, 2.20), size: 39,
                     font: heading, title: true)
            var lines = spec.body ?? []
            if let subtitle = spec.subtitle { lines.insert(subtitle, at: 0) }
            _ = try block(s, lines, x: 7.92, y: 3.77, width: 4.53, bottom: 6.36, size: 22)
            try caption(s, spec: spec, frame: rect(0.25, 6.34, 6.95, 0.43))
        case "sources":
            try standardTitle(s, spec: spec, index: index)
            let top = spec.subtitle == nil ? 2.28 : 2.92
            let sources = spec.sources
            let countPerColumn = Int(ceil(Double(sources.count) / 2))
            for (i, source) in sources.enumerated() {
                let col = i / max(1, countPerColumn)
                let row = i % max(1, countPerColumn)
                let gap = (6.58 - top) / Double(max(1, countPerColumn))
                let x = 0.68 + Double(col) * 6.24
                let y = top + Double(row) * gap
                try rule(s, x: x, y: y, width: 5.61, color: Palette.gold)
                try text(s, source.title, rect(x, y + 0.12, 5.55, gap * 0.53),
                         size: 19.5, color: Palette.ink, bold: true)
                let url = URL(string: source.url)
                let label = url?.host ?? source.url
                try text(s, label, rect(x, y + gap * 0.64, 5.55, gap * 0.27),
                         size: 12.5, color: Palette.rust, hyperlink: source.url)
            }
        default:
            throw BuildFailure("Unknown layout ‘\(spec.layout)’ on slide \(index + 1).")
        }
        try footer(s, spec: spec, index: index, dark: dark, photo: photoFooter)
        try addNotes(to: s, spec: spec)
        if let comment = spec.comment {
            try s.addComment(comment, author: "Rostrum Demo", initials: "RD",
                             at: (x: .inches(11.88), y: .inches(0.42)))
        }
        if publish {
            try authored.finish(s, layoutName: "Horseshoe Curve · \(spec.layout) · \(index + 1)")
        } else { try authored.fitText(in: s) }
        return s
    }

    func addNotes(to slide: Slide, spec: SlideSpec) throws {
        let frame = try slide.notesTextFrame()
        frame.clear()
        func paragraph(_ value: String, bold: Bool = false) {
            let p = frame.addParagraph()
            p.setNoBullet(); p.setSpacing(afterPoints: 8)
            let r = p.addRun(value)
            r.fontName = "Arial"; r.fontSize = 12; r.bold = bold
        }
        paragraph(spec.title, bold: true)
        for value in spec.notes.components(separatedBy: "\n\n") { paragraph(value) }
        if !spec.sources.isEmpty {
            paragraph("Sources", bold: true)
            for source in spec.sources { paragraph("\(source.title) — \(source.url)") }
        }
        if spec.image != nil {
            paragraph("Illustration disclosure", bold: true)
            paragraph(spec.imageCaption ?? "This image is an AI-generated interpretive illustration, not an archival photograph or exact engineering survey.")
        }
        paragraph("Created with Rostrum and RostrumLayout. Native editable shapes, text, tables, charts, speaker notes and comments are authored directly in Swift; generated raster imagery is embedded as pictures.")
    }

    func build() throws {
        for (index, spec) in content.slides.enumerated() {
            do { _ = try compose(spec, index: index) }
            catch { throw BuildFailure("Slide \(index + 1) [\(spec.layout)] ‘\(spec.title)’: \(error)") }
        }
        try deck.sections.set(content.sections.map { (name: $0.name, startSlide: $0.start) })
        try deck.validateTemplateBindings()
        try deck.save(to: output)
        let reopened = try Presentation(contentsOf: output)
        try reopened.validateTemplateBindings()
        try registerFonts(in: reopened)
        guard reopened.slides.count == 28,
              reopened.slides.allSatisfy({ !$0.notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw BuildFailure("Saved deck failed slide/notes count check.")
        }
        let comments = reopened.slides.reduce(0) { $0 + $1.comments.count }
        guard comments == content.slides.filter({ $0.comment != nil }).count else {
            throw BuildFailure("Saved deck comment count differs from content.")
        }
        for (index, spec) in content.slides.enumerated() {
            let saved = try reopened.slides[index]
            for paragraph in spec.notes.components(separatedBy: "\n\n") where !paragraph.isEmpty {
                guard saved.notesText.contains(paragraph) else {
                    throw BuildFailure("Saved speaker notes lost content on slide \(index + 1).")
                }
            }
            for source in spec.sources {
                guard saved.notesText.contains(source.url) else {
                    throw BuildFailure("Saved source URL missing from slide \(index + 1) notes.")
                }
            }
            if let comment = spec.comment {
                guard saved.comments.contains(where: { $0.text == comment }) else {
                    throw BuildFailure("Saved comment differs on slide \(index + 1).")
                }
            }
            if let imageName = spec.image {
                guard let picture = saved.shapes.all.compactMap({ $0 as? Picture }).first,
                      picture.imageData == imageCache[imageName] else {
                    throw BuildFailure("Saved image differs on slide \(index + 1).")
                }
                let authoredPicture = try deck.slides[index].shapes.all.compactMap { $0 as? Picture }.first
                guard picture.crop == authoredPicture?.crop else {
                    throw BuildFailure("Saved crop differs on slide \(index + 1).")
                }
            }
            if let values = spec.table {
                guard let table = saved.shapes.all.compactMap({ $0 as? TableFrame }).first?.table,
                      table.rowCount == values.count, table.columnCount == values[0].count else {
                    throw BuildFailure("Saved table dimensions differ on slide \(index + 1).")
                }
                for (rowIndex, row) in values.enumerated() {
                    for (columnIndex, value) in row.enumerated() {
                        let cell = try table.cell(rowIndex, columnIndex)
                        guard cell.text == value, cell.verticalAnchor == .middle else {
                            throw BuildFailure("Saved cell content or vertical centering differs on slide \(index + 1).")
                        }
                    }
                }
            }
            if let expected = spec.chart {
                guard let chart = saved.charts.first, chart.categories == expected.categories,
                      chart.series.first?.values == expected.values.map({ Optional($0) }),
                      chart.workbookPart != nil else {
                    throw BuildFailure("Saved native chart data/workbook differs on slide \(index + 1).")
                }
            }
        }
        let shapes = reopened.slides.flatMap { $0.shapes.all }
        let pictures = shapes.compactMap { $0 as? Picture }
        guard pictures.count == content.slides.filter({ $0.image != nil }).count else {
            throw BuildFailure("Saved picture count differs from content.")
        }
        let tables = shapes.filter { $0.kind == .table }
        let charts = shapes.filter { $0.kind == .chart }
        guard tables.count == content.slides.filter({ $0.table != nil }).count,
              charts.count == content.slides.filter({ $0.chart != nil }).count else {
            throw BuildFailure("Saved table/chart count differs from content.")
        }
        try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
        var previews: [PreviewRecord] = []
        for (index, spec) in content.slides.enumerated() {
            let rendered = try reopened.renderSVGReportingProblems(slideAt: index, pixelWidth: 1600)
            let file = String(format: "slide-%02d.svg", index + 1)
            try rendered.svg.write(to: previewDirectory.appendingPathComponent(file), atomically: true, encoding: .utf8)
            previews.append(PreviewRecord(slide: index + 1, title: spec.title,
                layout: spec.layout, file: file, fidelityIssues: rendered.problems.fidelityIssues))
        }
        let validation = Validation(authoringLibraries: ["Rostrum", "RostrumLayout"],
            slideCount: reopened.slides.count, notesCount: reopened.slides.filter(\.hasNotes).count,
            commentsCount: comments, pictureCount: pictures.count,
            croppedPictureCount: pictures.filter { $0.crop != nil }.count,
            tableCount: tables.count, chartCount: charts.count,
            sectionCount: reopened.sections.count, layoutCount: reopened.allLayouts.count,
            allTemplateBindingsValid: true, nativePowerPointVerified: false, previews: previews)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(validation).write(to: project.appendingPathComponent("validation.json"), options: .atomic)
        FileHandle.standardOutput.write(Data("Created \(output.path)\n28 slides · \(pictures.count) pictures · \(comments) comments · \(tables.count) tables · \(charts.count) charts\n".utf8))
    }
}

do {
    let defaultProject = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let project = CommandLine.arguments.count > 1
        ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true) : defaultProject
    try Builder(project: project).build()
} catch {
    FileHandle.standardError.write(Data("HorseshoeDeck: \(error)\n".utf8))
    exit(1)
}
