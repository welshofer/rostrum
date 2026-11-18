import Foundation
import LecternIR
import RostrumLayout

public struct KeyxTextMeasurement: Sendable {
    public let text: String
    public let font: String
    public let size: Double
    public let bold: Bool
    public let width: Double
}

public typealias KeyxTextMeasurer = @Sendable (KeyxTextMeasurement) -> Double

public struct KeyxAuthoringOptions: Sendable {
    public var width: Double = 960
    public var height: Double = 540
    public var headingFont = "Arial"
    public var bodyFont = "Arial"
    public var background = "FAFAF7"
    public var foreground = "172B3A"
    public var accent = "276D89"
    public var notesEnabled = true
    /// An identifier or name in a user-owned template. Without one, the author
    /// selects a matching layout name, then the template's first layout.
    public var templateLayout: String?
    public init() {}
}

public struct KeyxAuthoringResult: Sendable {
    public var document: KeyxDocument
    public let warnings: [String]
    /// One original intent slide can produce multiple measured pages.
    public let slideGroups: [String: [String]]
}

/// Direct DeckIR -> Keynote Interchange authoring. No PPTX or native IWA
/// document is constructed. Imported interchange editing uses KeyxDocument,
/// not this intentionally narrower authoring contract.
public enum KeyxAuthor {
    public static func render(_ deck: DeckIR, options: KeyxAuthoringOptions = .init(),
                              images: [String: Data] = [:], template: KeyxDocument? = nil,
                              measure: KeyxTextMeasurer? = nil) throws -> KeyxAuthoringResult {
        guard deck.irVersion == DeckIR.currentVersion, !deck.slides.isEmpty else {
            throw KeyxError.invalid("Unsupported or empty DeckIR")
        }
        guard Set(deck.slides.map(\.id)).count == deck.slides.count else { throw KeyxError.invalid("Duplicate DeckIR slide IDs") }
        var options = options
        if let template {
            let size = template.presentation["slide_size"]
            options.width = size?["width"]?.double ?? 1024
            options.height = size?["height"]?.double ?? 768
        }
        guard options.width.isFinite, options.height.isFinite,
              (200...50_000).contains(options.width), (150...50_000).contains(options.height) else {
            throw KeyxError.invalid("Invalid authoring canvas")
        }
        let _ = try KeyxNode.fill(hex: options.background)
        let _ = try KeyxNode.fill(hex: options.foreground)
        let _ = try KeyxNode.fill(hex: options.accent)
        let scale = options.height / 540
        var document = try template ?? newDocument(options)
        let existingIssues = document.validate().filter { $0.severity == .error }
        if template != nil, !existingIssues.isEmpty { throw KeyxError.validation(existingIssues) }
        var warnings: [String] = []
        if measure == nil {
            warnings.append("Text fitting uses portable estimates; native font shaping and Keynote visual acceptance remain separate checks.")
        }
        let measurer = measure ?? estimatedHeight
        let layouts = document.presentation["theme"]?["slide_layouts"]?.array ?? []
        guard !layouts.isEmpty else {
            throw KeyxError.unsupported("Interchange templates must carry their own slide layouts; external Apple themes are not bundled.")
        }
        let resolver = try document.styleResolver()
        var output: [KeyxSlide] = []
        var groups: [String: [String]] = [:]
        for (index, input) in deck.slides.enumerated() {
            try Task.checkCancellation()
            guard !input.id.isEmpty else { throw KeyxError.invalid("A slide ID is empty") }
            if case .unknown(let name) = input.kind { throw KeyxError.unsupported("Unsupported authoring layout: \(name)") }
            let layout = try chooseLayout(input, layouts: layouts, selected: options.templateLayout)
            let layoutNode = try KeyxNode(value: layout)
            guard let layoutID = layout["identifier"]?.string ?? layout["name"]?.string else {
                throw KeyxError.invalid("Template layout has no identifier or name")
            }
            let placeholders = try placeholderSlots(layoutNode, resolver: resolver)
            let margin = 48 * scale
            let titleFallback = KeyxGeometry(x: margin, y: 30 * scale, width: options.width - 2 * margin, height: 85 * scale)
            let bodyFallback = KeyxGeometry(x: margin, y: 135 * scale, width: options.width - 2 * margin, height: options.height - 185 * scale)
            let titleSlot = placeholders["title"]
            let bodySlot = placeholders["body"] ?? placeholders["object"]
            if template != nil, titleSlot == nil, input.title?.isEmpty == false {
                throw KeyxError.unsupported("Template layout \(layoutID) has no usable title placeholder")
            }
            if template != nil, bodySlot == nil {
                throw KeyxError.unsupported("Template layout \(layoutID) has no usable body or object placeholder")
            }
            let titleFrame = try frame(titleSlot, fallback: titleFallback, resolver: resolver)
            let contentFrame = try frame(bodySlot, fallback: bodyFallback, resolver: resolver)
            let titleStyle = try textStyle(titleSlot, fallbackFont: options.headingFont, size: 36 * scale,
                                          bold: true, options: options, resolver: resolver)
            let bodyStyle = try textStyle(bodySlot, fallbackFont: options.bodyFont, size: 22 * scale,
                                         bold: false, options: options, resolver: resolver)
            if let title = input.title, !title.isEmpty {
                try assertFits(title, frame: titleFrame, style: titleStyle, measure: measurer)
            }
            let text = bodyText(input.body)
            let image = images[input.id]
            if input.image != nil, image == nil { warnings.append("Slide \(index + 1): no image bytes were supplied for the requested image.") }
            let hasStructured = input.body?.table != nil || input.body?.chart != nil
            var textFrame = contentFrame
            var imageFrame: KeyxGeometry?
            if image != nil {
                let gap = 24 * scale
                let half = (contentFrame.width - gap) / 2
                let leftImage = input.kind == .imageLeft
                imageFrame = KeyxGeometry(x: contentFrame.x + (leftImage ? 0 : half + gap),
                    y: contentFrame.y, width: half, height: contentFrame.height)
                textFrame = KeyxGeometry(x: contentFrame.x + (leftImage ? half + gap : 0),
                    y: contentFrame.y, width: half, height: contentFrame.height)
            }
            // Structured objects occupy their own pages if accompanied by text
            // or an image. This retains every word instead of painting over it.
            var pages: [[KeyxSlideObject]] = []
            if !text.isEmpty || (!hasStructured && image == nil) {
                let chunks = try MeasuredPaginator.text(text) {
                    measured($0, style: bodyStyle, width: textFrame.width - 12 * scale, measure: measurer) <= textFrame.height - 12 * scale
                }
                for chunk in chunks {
                    let object = try textObject(chunk, frame: textFrame, style: bodyStyle, base: bodySlot,
                                                identifier: "lectern-\(index)-text-\(pages.count)")
                    pages.append([object])
                }
            }
            if let image, let imageFrame {
                let ext = try imageExtension(image)
                let resource = try document.addResource(image, filename: "image-\(index + 1).\(ext)",
                                                         identifier: uniqueResourceName(in: document, index: index, ext: ext))
                let canvas = KeyxCanvasObject(kind: "image", properties: KeyxNode(type: "image", fields: [
                    "identifier": .string("lectern-\(index)-image"), "geometry": imageFrame.node.value,
                    "resource": resource, "stroke": .string("empty")
                ]))
                if pages.isEmpty { pages = [[]] }
                pages[0].append(KeyxSlideObject(canvas: canvas))
                warnings.append("Slide \(index + 1): image placement uses the supplied canvas aspect; image cropping is not inferred.")
            }
            if let table = input.body?.table {
                let tablePages = try tableObjects(table, frame: contentFrame, style: bodyStyle, options: options,
                                                  identifier: "lectern-\(index)-table", measure: measurer)
                pages += tablePages.map { [$0] }
            }
            if let chart = input.body?.chart {
                pages.append([try chartObject(chart, frame: contentFrame, options: options, identifier: "lectern-\(index)-chart")])
            }
            if input.kind == .diagram || input.kind == .timeline || input.kind == .quadrant {
                warnings.append("Slide \(index + 1): \(input.layout) content is retained as editable text and vector framing, not a native diagram object.")
            }
            if [.twoColumn, .comparison, .cards, .threeColumn, .numberedSteps, .metrics].contains(input.kind) {
                warnings.append("Slide \(index + 1): \(input.layout) uses measured reading-order text rather than the PowerPoint layout.")
            }
            if pages.isEmpty { pages = [[]] }
            if pages.count > 1 { warnings.append("Slide \(index + 1) expanded to \(pages.count) pages without shortening its content.") }
            for (page, content) in pages.enumerated() {
                let id = "lectern-slide-\(index + 1)-\(page + 1)"
                var slide = KeyxSlide(identifier: id, layout: layoutID)
                // This is a hint, not an external identity guarantee. Keynote
                // may regenerate identifiers or discard extension metadata.
                slide.node["lectern_source_id"] = .string(input.id)
                slide.node["depth"] = .integer(input.kind == .sectionHeader || input.sectionId == nil ? 1 : 2)
                var contents: [KeyxSlideObject] = []
                if template == nil {
                    contents.append(KeyxSlideObject(canvas: KeyxCanvasObject(kind: "shape", properties: KeyxNode(type: "shape", fields: [
                        "identifier": .string("\(id)-accent"),
                        "geometry": KeyxGeometry(x: margin, y: 117 * scale, width: 64 * scale, height: 4 * scale).node.value,
                        "fill": try KeyxNode.fill(hex: options.accent).value, "stroke": .string("empty")
                    ]))))
                }
                if let title = input.title {
                    contents.append(try textObject(title, frame: titleFrame, style: titleStyle, base: titleSlot, identifier: "\(id)-title"))
                }
                contents += content
                slide.setContents(contents)
                if page == 0, options.notesEnabled, let notes = input.notes { slide.setNote(.value(KeyxText(notes))) }
                output.append(slide)
                groups[input.id, default: []].append(id)
            }
        }
        document.replaceSlides(output)
        document.presentation["lectern_title"] = .string(deck.meta.title)
        if deck.sections?.isEmpty == false {
            warnings.append("Section membership is represented by slide depth; named section metadata is not a native interchange feature.")
        }
        let errors = document.validate().filter { $0.severity == .error }
        guard errors.isEmpty else { throw KeyxError.validation(errors) }
        return KeyxAuthoringResult(document: document, warnings: warnings, slideGroups: groups)
    }

    private static func newDocument(_ options: KeyxAuthoringOptions) throws -> KeyxDocument {
        let background = KeyxNode(type: "slide-background", fields: ["standard": try KeyxNode.fill(hex: options.background).value])
        let layout = KeyxNode(type: "slide-layout", fields: [
            "identifier": .string("lectern-layout"), "name": .string("Lectern"),
            "version": .string("1.1"), "background": background.value, "contents": .array([])
        ])
        let presentation = KeyxNode(type: "presentation", fields: [
            "slide_size": KeyxNode(type: "size", fields: ["width": .decimal(options.width), "height": .decimal(options.height)]).value,
            "theme": KeyxNode(type: "keynote-theme", fields: ["name": .string("Lectern"), "slide_layouts": .array([layout.value])]).value,
            "slides": .array([KeyxSlide(identifier: "temporary").node.value])
        ])
        let presets = [KeyxNode([
            "identifier": .string("lectern-body"),
            "display_name": .string("Lectern body"),
            "properties": KeyxNode(type: "character-properties", fields: [
                "font_name": .string(options.bodyFont), "font_size": .decimal(22 * options.height / 540),
                "character_fill": try KeyxNode.fill(hex: options.foreground).value
            ]).value
        ])]
        return try KeyxDocument(presentation: presentation, presets: presets)
    }

    private static func chooseLayout(_ slide: IRSlide, layouts: [KeyxValue], selected: String?) throws -> KeyxValue {
        if let selected {
            guard let layout = layouts.first(where: { $0["identifier"]?.string == selected || $0["name"]?.string == selected }) else {
                throw KeyxError.invalid("The selected interchange layout no longer exists")
            }
            return layout
        }
        return layouts.first(where: { $0["name"]?.string?.caseInsensitiveCompare(slide.layout) == .orderedSame }) ?? layouts[0]
    }

    private static func placeholderSlots(_ layout: KeyxNode, resolver: KeyxStyleResolver) throws -> [String: KeyxSlideObject] {
        var slots: [String: KeyxSlideObject] = [:]
        for value in layout["contents"]?.array ?? [] {
            let node = try resolver.resolved(KeyxNode(value: value))
            guard let kind = node["placeholder_info"]?["defined"]?["kind"]?.string else { continue }
            guard slots[kind] == nil else { throw KeyxError.unsupported("Ambiguous \(kind) placeholders in template layout") }
            slots[kind] = KeyxSlideObject(node: node)
        }
        return slots
    }
    private static func frame(_ slot: KeyxSlideObject?, fallback: KeyxGeometry, resolver: KeyxStyleResolver) throws -> KeyxGeometry {
        guard let slot else { return fallback }
        let properties = try resolver.resolved(slot.canvas.properties)
        guard let geometry = properties["geometry"] else { throw KeyxError.unsupported("Template placeholder has no explicit geometry") }
        return try KeyxGeometry(node: resolver.resolved(KeyxNode(value: geometry)))
    }
    private static func textStyle(_ slot: KeyxSlideObject?, fallbackFont: String, size: Double, bold: Bool,
                                  options: KeyxAuthoringOptions, resolver: KeyxStyleResolver) throws -> KeyxNode {
        var style = KeyxNode(type: "character-properties", fields: [
            "font_name": .string(fallbackFont), "font_size": .decimal(size), "bold": .bool(bold),
            "character_fill": try KeyxNode.fill(hex: options.foreground).value
        ])
        if let slot {
            let properties = try resolver.resolved(slot.canvas.properties)
            if let paragraph = properties["paragraph_properties"] {
                let resolved = try resolver.resolved(KeyxNode(value: paragraph))
                if let characters = resolved["character_properties"] {
                    let inherited = try resolver.resolved(KeyxNode(value: characters))
                    style = KeyxNode(style.fields.merging(inherited.fields) { _, inherited in inherited })
                }
            }
        }
        return style
    }
    private static func measured(_ text: String, style: KeyxNode, width: Double, measure: KeyxTextMeasurer) -> Double {
        measure(KeyxTextMeasurement(text: text, font: style["font_name"]?.string ?? "Arial",
            size: style["font_size"]?.double ?? 22, bold: style["bold"]?.bool ?? false, width: max(1, width)))
    }
    private static func assertFits(_ text: String, frame: KeyxGeometry, style: KeyxNode, measure: KeyxTextMeasurer) throws {
        let height = measured(text, style: style, width: frame.width - 12, measure: measure)
        guard height.isFinite, height <= frame.height - 8 else {
            throw KeyxError.invalid("Text does not fit the template's readable area: \(text.prefix(80))")
        }
    }
    private static func textObject(_ text: String, frame: KeyxGeometry, style: KeyxNode,
                                   base: KeyxSlideObject?, identifier: String) throws -> KeyxSlideObject {
        var object = try base?.canvas ?? KeyxCanvasObject(kind: "textbox", properties: KeyxNode(type: "textbox"))
        let kind = try object.kind
        guard kind == "textbox" || kind == "shape" else {
            throw KeyxError.unsupported("The template's text placeholder is not a shape or text box")
        }
        try object.editProperties {
            $0["identifier"] = .string(identifier)
            $0["geometry"] = frame.node.value
            $0["text"] = KeyxText(runs: [KeyxTextRun(text, style: style)]).node.value
            if base == nil { $0["stroke"] = .string("empty") }
        }
        var result = base ?? KeyxSlideObject(canvas: object)
        result.setCanvas(object)
        if var info = result.node["placeholder_info"]?.object,
           var defined = info["defined"]?.object {
            defined["is_visible"] = .bool(true)
            info["defined"] = .object(defined); result.node["placeholder_info"] = .object(info)
            result.node["source_kind"] = .string("placeholder")
        }
        return result
    }

    /// All body fields are retained in reading order, including fields a model
    /// puts on an unusual layout. No layout switch may silently drop a field.
    public static func bodyText(_ body: Body?) -> String {
        guard let body else { return "" }
        var parts: [String] = []
        func add(_ text: String?) { if let text { parts.append(text) } }
        add(body.kicker); add(body.subtitle); add(body.lead); add(body.claim); add(body.band)
        parts += body.items ?? []
        for bullet in body.bullets ?? [] { parts.append(bullet.text); parts += bullet.subBullets ?? [] }
        for column in [body.left, body.right].compactMap({ $0 }) { parts.append(column.heading); parts += column.bullets }
        add(body.quote); add(body.attribution); add(body.value); add(body.label)
        for stat in body.stats ?? [] { parts += [stat.value, stat.label] }
        parts += body.diagram?.items ?? []
        for milestone in body.milestones ?? [] { parts += [milestone.label, milestone.detail] }
        for quadrant in body.quadrants ?? [] { parts += [quadrant.heading, quadrant.detail] }
        add(body.xAxis); add(body.yAxis)
        for panel in body.panels ?? [] { parts += [panel.heading, panel.detail] }
        add(body.callToAction); add(body.contact); add(body.source)
        return parts.joined(separator: "\n")
    }

    private static func tableObjects(_ table: IRTable, frame: KeyxGeometry, style: KeyxNode,
                                     options: KeyxAuthoringOptions, identifier: String,
                                     measure: KeyxTextMeasurer) throws -> [KeyxSlideObject] {
        let columns = table.headers.count
        guard columns > 0, table.grid.allSatisfy({ $0.count == columns }) else { throw KeyxError.invalid("A table must be rectangular") }
        guard !(table.textDirections ?? []).contains(where: { $0.direction != .horizontal }) else {
            throw KeyxError.unsupported("Rotated table-cell text authoring is not supported in interchange; no output was written")
        }
        let width = frame.width / Double(columns)
        let scale = options.height / 540
        var cellStyle = style; cellStyle["font_size"] = .decimal(16 * scale)
        func rowHeight(_ row: [String]) -> Double {
            max(28 * scale, row.map { measured($0, style: cellStyle, width: width - 16 * scale, measure: measure) }.max() ?? 0) + 10 * scale
        }
        let headers = [table.headers] + (table.additionalHeaders ?? [])
        let headerHeight = headers.map(rowHeight).reduce(0, +)
        let bodyPages: [[[String]]]
        if table.merges?.isEmpty == false {
            guard table.grid.map(rowHeight).reduce(0, +) <= frame.height else {
                throw KeyxError.unsupported("A merged table cannot be split across interchange slides; the original content is unchanged")
            }
            bodyPages = [table.rows]
        } else {
            bodyPages = table.rows.isEmpty ? [[]] : try MeasuredPaginator.pages(table.rows) {
                headerHeight + $0.map(rowHeight).reduce(0, +) <= frame.height
            }
        }
        return try bodyPages.enumerated().map { page, bodyRows in
            let grid = headers + bodyRows
            let height = grid.map(rowHeight).reduce(0, +)
            guard height.isFinite, height <= frame.height else { throw KeyxError.invalid("Table headers exceed the readable area") }
            let rows = try grid.enumerated().map { r, values -> KeyxValue in
                let header = r < headers.count
                var rowStyle = cellStyle
                rowStyle["bold"] = .bool(header)
                rowStyle["character_fill"] = try KeyxNode.fill(hex: header ? "FFFFFF" : options.foreground).value
                let paragraph = KeyxNode(type: "paragraph-properties", fields: ["character_properties": rowStyle.value])
                return KeyxNode(type: "table.row", fields: [
                    "row_identifier": .string("r\(r)"), "row_index": .integer(r),
                    "kind": .string("body"), "row_height": .decimal(rowHeight(values)),
                    "text_properties": paragraph.value,
                    "cell_properties": KeyxNode(type: "table.cell-properties", fields: [
                        "fill": try KeyxNode.fill(hex: header ? options.accent : options.background).value,
                        "text_wrap": .bool(true), "padding": KeyxNode(type: "insets", fields: [
                            "left": .decimal(8 * scale), "right": .decimal(8 * scale),
                            "top": .decimal(5 * scale), "bottom": .decimal(5 * scale)
                        ]).value
                    ]).value,
                    "cells": .array(values.enumerated().map { c, text in
                        KeyxNode(type: "table.cell", fields: ["column_index": .integer(c), "value": .string(text)]).value
                    })
                ]).value
            }
            let merges = try (table.merges ?? []).map { merge -> KeyxValue in
                guard merge.row >= 0, merge.column >= 0, merge.rowSpan > 0, merge.columnSpan > 0,
                      merge.row < grid.count, merge.rowSpan <= grid.count - merge.row,
                      merge.column < columns, merge.columnSpan <= columns - merge.column else { throw KeyxError.invalid("Invalid table merge") }
                for r in merge.row..<(merge.row + merge.rowSpan) {
                    for c in merge.column..<(merge.column + merge.columnSpan) where r != merge.row || c != merge.column {
                        guard grid[r][c].isEmpty else { throw KeyxError.invalid("A covered table merge cell contains text") }
                    }
                }
                return KeyxNode(type: "table.cell-range", fields: [
                    "row_column_id_range": KeyxNode(type: "table.cell-range.row-column-id-range", fields: [
                        "top_left_row_identifier": .string("r\(merge.row)"),
                        "top_left_column_identifier": .string("c\(merge.column)"),
                        "bottom_right_row_identifier": .string("r\(merge.row + merge.rowSpan - 1)"),
                        "bottom_right_column_identifier": .string("c\(merge.column + merge.columnSpan - 1)")
                    ]).value
                ]).value
            }
            return KeyxSlideObject(canvas: KeyxCanvasObject(kind: "table", properties: KeyxNode(type: "table", fields: [
                "identifier": .string("\(identifier)-\(page)"),
                "geometry": KeyxGeometry(x: frame.x, y: frame.y, width: frame.width, height: height).node.value,
                "number_of_columns": .integer(columns), "number_of_rows": .integer(grid.count),
                "number_of_header_rows": .integer(headers.count),
                "default_column_width": .decimal(width), "content": .array(rows), "merges": .array(merges),
                "column_headers": .array((0..<columns).map {
                    KeyxNode(type: "table.column-header", fields: ["column_identifier": .string("c\($0)"), "column_width": .decimal(width)]).value
                })
            ])))
        }
    }

    private static func chartObject(_ chart: IRChart, frame: KeyxGeometry, options: KeyxAuthoringOptions,
                                    identifier: String) throws -> KeyxSlideObject {
        guard ["bar", "line", "pie"].contains(chart.kind), !chart.categories.isEmpty, !chart.series.isEmpty,
              chart.series.allSatisfy({ $0.values.count == chart.categories.count && $0.values.allSatisfy(\.isFinite) }) else {
            throw KeyxError.invalid("Unsupported or inconsistent chart data")
        }
        if chart.kind == "pie", chart.series.count != 1 {
            throw KeyxError.unsupported("A pie chart requires exactly one series; extra series will not be discarded")
        }
        let data = KeyxNode(type: "chart-data", fields: [
            "chart_data_source": .string("chart_data_grid"), "plot_direction": .string("rows_as_series"),
            "column_labels": .array(chart.categories.map(KeyxValue.string)),
            "row_labels": .array(chart.series.map { .string($0.name) }),
            "rows": .array(chart.series.map { series in
                KeyxNode(type: "chart-data.chart-data-row", fields: ["values": .array(series.values.map {
                    KeyxNode(type: "chart-data.chart-data-value", fields: ["number": .decimal($0)]).value
                })]).value
            })
        ])
        let properties = KeyxNode(type: chart.kind + "-chart", fields: [
            "identifier": .string(identifier), "geometry": frame.node.value, "data": data.value, "show_legend": .bool(true)
        ])
        return KeyxSlideObject(canvas: KeyxCanvasObject(kind: "chart", properties:
            KeyxNode(type: "chart", fields: [chart.kind: properties.value])))
    }

    private static func imageExtension(_ data: Data) throws -> String {
        if data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) { return "png" }
        if data.starts(with: [255, 216, 255]) { return "jpg" }
        if data.starts(with: Array("GIF8".utf8)) { return "gif" }
        throw KeyxError.unsupported("Interchange authoring currently accepts PNG, JPEG or GIF image bytes")
    }
    private static func uniqueResourceName(in document: KeyxDocument, index: Int, ext: String) -> String {
        var suffix = 0
        var name = "lectern-image-\(index).\(ext)"
        while document.entryData(named: "Data/" + name) != nil {
            suffix += 1; name = "lectern-image-\(index)-\(suffix).\(ext)"
        }
        return name
    }
    private static func estimatedHeight(_ request: KeyxTextMeasurement) -> Double {
        guard request.width > 0, request.size > 0 else { return .infinity }
        let capacity = max(1, Int(request.width / (request.size * 0.6)))
        let lines = request.text.split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { $0 + max(1, Int(ceil(Double($1.count) / Double(capacity)))) }
        return Double(lines) * request.size * 1.3
    }
}
