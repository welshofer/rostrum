import Foundation

public struct KeyxAsset: Sendable {
    public let filename: String
    public let data: Data
}

public struct KeyxChartSummary: Sendable {
    public let kind: String
    public let categories: [String]
    public let seriesNames: [String]
    public let values: [[Double?]]

    public init(node: KeyxNode) throws {
        let alternatives = node.fields.keys.filter { !["type_identifier", "version", "preset_identifier"].contains($0) }
        guard alternatives.count == 1, let kind = alternatives.first, let chart = node[kind]?.object,
              let data = chart["data"]?.object else { throw KeyxError.unsupported("Chart data could not be resolved") }
        self.kind = kind
        let rows = try (data["rows"]?.array ?? []).map { row -> [Double?] in
            guard let cells = row["values"]?.array else { throw KeyxError.invalid("Invalid chart data row") }
            return cells.map { $0["number"]?.double }
        }
        let rowLabels = data["row_labels"]?.array?.map { $0.string ?? "" } ?? []
        let columnLabels = data["column_labels"]?.array?.map { $0.string ?? "" } ?? []
        switch data["plot_direction"]?.string {
        case "rows_as_series":
            categories = columnLabels; seriesNames = rowLabels; values = rows
        case "columns_as_series":
            categories = rowLabels; seriesNames = columnLabels
            let count = rows.map(\.count).max() ?? 0
            values = (0..<count).map { column in rows.map { $0.indices.contains(column) ? $0[column] : nil } }
        default: throw KeyxError.unsupported("Chart plot direction is unspecified or unsupported")
        }
    }
}

public struct KeyxSlideSummary: Sendable {
    public let number: Int
    public var title: String = ""
    public var texts: [String] = []
    public var notes: String = ""
    public var tables: [[[String]]] = []
    public var charts: [KeyxChartSummary] = []
    public var assets: [KeyxAsset] = []
    public var shapeCounts: [String: Int] = [:]
    public var fonts: Set<String> = []
    public var warnings: [String] = []
}

public extension KeyxDocument {
    var slideSize: (width: Double, height: Double) {
        get throws {
            let size: KeyxValue
            switch try resolvedProperty("slide_size", on: presentation) {
            case .inherited: return (1024, 768)
            case .cleared: throw KeyxError.invalid("Slide size cannot be null")
            case .value(let value): size = value
            }
            let node = try KeyxNode(value: size)
            let width = try resolvedProperty("width", on: node).value?.double
            let height = try resolvedProperty("height", on: node).value?.double
            guard let width, let height,
                  width > 0, height > 0, width <= 50_000_000, height <= 50_000_000 else {
                throw KeyxError.invalid("Invalid slide size")
            }
            return (width, height)
        }
    }

    func layout(for slide: KeyxSlide) throws -> KeyxNode? {
        let layouts = presentation["theme"]?["slide_layouts"]?.array ?? []
        if let name = slide.node["layout"]?.string {
            return try layouts.first(where: { $0["identifier"]?.string == name || $0["name"]?.string == name })
                .map { try KeyxNode(value: $0) }
        }
        return try layouts.first.map { try KeyxNode(value: $0) }
    }

    /// A preview/extraction view. The document's own JSON is never flattened.
    func displayObjects(on slide: KeyxSlide) throws -> [KeyxSlideObject] {
        let resolver = try styleResolver()
        let layout = try self.layout(for: slide)
        let inherited = try (layout?["contents"]?.array ?? []).map { KeyxSlideObject(node: try KeyxNode(value: $0)) }
        let own = try slide.contents
        func placeholder(_ object: KeyxSlideObject) -> String? {
            object.node["placeholder_info"]?["defined"]?["kind"]?.string
                ?? object.node["placeholder_info"]?["tagged"]?.string
        }
        func visible(_ object: KeyxSlideObject) -> Bool {
            object.node["placeholder_info"]?["defined"]?["is_visible"]?.bool != false
        }
        let overridden = Set(own.compactMap(placeholder))
        var result = inherited.filter { item in
            visible(item) && placeholder(item).map { !overridden.contains($0) } != false
        }
        for item in own where visible(item) {
            guard let key = placeholder(item), let base = inherited.first(where: { placeholder($0) == key }) else {
                result.append(item); continue
            }
            var item = item
            var canvas = try item.canvas
            let baseCanvas = try base.canvas
            if try canvas.kind == baseCanvas.kind {
                let baseProperties = try resolver.resolved(baseCanvas.properties)
                try canvas.editProperties { properties in
                    properties = KeyxNode(baseProperties.fields.merging(properties.fields) { _, local in local })
                }
                item.setCanvas(canvas)
            }
            result.append(item)
        }
        return result
    }

    func inspectSlide(at index: Int) throws -> KeyxSlideSummary {
        let slides = try self.slides
        guard slides.indices.contains(index) else { throw KeyxError.invalid("Slide index out of bounds") }
        let slide = slides[index]
        var summary = KeyxSlideSummary(number: index + 1)
        let resolver = try styleResolver()
        if let note = try slide.note.value {
            do { summary.notes = try note.plainText }
            catch { summary.warnings.append("Presenter notes: \(error)") }
        }
        var remainingCells = limits.tableCells
        func collectFonts(_ value: KeyxValue, depth: Int = 0) {
            guard depth <= limits.jsonDepth else { return }
            if let font = value["font_name"]?.string { summary.fonts.insert(font) }
            for child in value.object?.values ?? [:].values { collectFonts(child, depth: depth + 1) }
            for child in value.array ?? [] { collectFonts(child, depth: depth + 1) }
        }
        func visit(_ canvas: KeyxCanvasObject, title: Bool = false, depth: Int = 0) {
            guard depth < limits.jsonDepth else { summary.warnings.append("Group nesting limit exceeded"); return }
            do {
                let kind = try canvas.kind
                let node = try resolver.resolved(canvas.properties)
                summary.shapeCounts[kind, default: 0] += 1
                collectFonts(node.value)
                if let text = node["text"] {
                    let string = try KeyxText(node: resolver.resolved(KeyxNode(value: text))).plainText
                    if title || summary.title.isEmpty { summary.title = string }
                    summary.texts.append(string)
                }
                if kind == "table" {
                    summary.tables.append(try Self.tableGrid(node, remainingCells: &remainingCells))
                }
                if kind == "chart" { summary.charts.append(try KeyxChartSummary(node: node)) }
                if kind == "image" || kind == "movie" || kind == "audio" {
                    if let resource = node["resource"] {
                        let filename = resource["indirect"]?["filename"]?.string
                            ?? resource["base64_encoded"]?["filename"]?.string ?? "resource"
                        summary.assets.append(KeyxAsset(filename: filename, data: try resourceData(resource)))
                    } else { summary.warnings.append("\(kind) resource could not be extracted") }
                }
                if kind == "group" {
                    for child in node["children"]?.array ?? [] {
                        visit(KeyxCanvasObject(node: try KeyxNode(value: child)), depth: depth + 1)
                    }
                }
            } catch { summary.warnings.append(String(describing: error)) }
        }
        for item in try displayObjects(on: slide) {
            do {
                visit(try item.canvas, title: item.node["placeholder_info"]?["defined"]?["kind"]?.string == "title")
            } catch { summary.warnings.append(String(describing: error)) }
        }
        return summary
    }

    static func tableGrid(_ node: KeyxNode, remainingCells: inout Int) throws -> [[String]] {
        guard let rows = node["number_of_rows"]?.integer, let columns = node["number_of_columns"]?.integer,
              rows > 0, columns > 0, rows <= remainingCells / columns else {
            throw KeyxError.limit("Invalid or oversized table")
        }
        remainingCells -= rows * columns
        var grid = Array(repeating: Array(repeating: "", count: columns), count: rows)
        var nextRow = 0
        for row in node["content"]?.array ?? [] {
            let r = row["row_index"]?.integer ?? nextRow
            guard grid.indices.contains(r) else { throw KeyxError.invalid("Table row index out of bounds") }
            nextRow = r + 1
            var nextColumn = 0
            for cell in row["cells"]?.array ?? [] {
                let c = cell["column_index"]?.integer ?? nextColumn
                guard grid[r].indices.contains(c) else { throw KeyxError.invalid("Table column index out of bounds") }
                nextColumn = c + 1
                grid[r][c] = cell["value"]?.string ?? ""
            }
        }
        return grid
    }
}
