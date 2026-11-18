import Foundation

public extension KeyxDocument {
    /// Semantic integrity checks, not a claim of full Draft 2020-12 validation
    /// or native Keynote rendering fidelity. Unknown content is never removed.
    func validate() -> [KeyxDiagnostic] {
        var issues: [KeyxDiagnostic] = []
        func error(_ path: String, _ message: String) { issues.append(.init(.error, path: path, message: message)) }
        func warning(_ path: String, _ message: String) { issues.append(.init(.warning, path: path, message: message)) }
        do { try Self.checkVersion(manifest["package_version"], maximum: "1.0", context: "package") }
        catch let failure { error("manifest.json", String(describing: failure)) }
        let resolver: KeyxStyleResolver
        do { resolver = try styleResolver() }
        catch let failure {
            error("presets.json", String(describing: failure))
            return issues
        }
        guard let slides = presentation["slides"]?.array, !slides.isEmpty else {
            error("main.json/slides", "A presentation requires at least one slide"); return issues
        }
        let layouts = presentation["theme"]?["slide_layouts"]?.array ?? []
        let layoutIDs = Set(layouts.compactMap { $0["identifier"]?.string })
        let layoutNames = Set(layouts.compactMap { $0["name"]?.string })
        var identifiers: [String: String] = [:]
        var visitedNodes = 0
        var tableCells = 0
        var base64Bytes = 0
        let versions = [
            "slide-layout": "1.1", "canvas-object": "1.2", "color.rgba": "1.1", "shadow": "1.1",
            "fill.gradient": "1.1", "fill.gradient.flavor.linear": "1.1",
            "resource.indirect-resource": "2.0", "resource.base64-encoded-resource": "2.0"
        ]
        let knownTypes: Set<String> = [
            "presentation", "keynote-theme", "slide", "slide-layout", "slide-object", "canvas-object",
            "geometry", "size", "position", "rect", "text", "text-run", "paragraph", "paragraph.constituent",
            "character-properties", "paragraph-properties", "layout-properties", "list-properties",
            "shape", "textbox", "image", "movie", "audio", "group", "connection-line", "chart", "table",
            "resource", "resource.indirect-resource", "resource.base64-encoded-resource", "color", "color.rgba",
            "fill", "fill.gradient", "fill.gradient.flavor.linear", "stroke", "stroke.line", "path", "path.bezier-path",
            "shadow", "slide-background", "stylesheet", "chart-data", "chart-data.chart-data-row",
            "chart-data.chart-data-value", "chart-series", "column-chart", "bar-chart", "line-chart", "pie-chart",
            "table.row", "table.cell", "table.column-header", "table.cell-properties", "table.cell-range",
            "table.cell-range.row-column-id-range", "insets"
        ]
        func walk(_ value: KeyxValue, path: String, expected: String? = nil, depth: Int = 0) {
            visitedNodes += 1
            guard visitedNodes <= limits.jsonNodes, depth <= limits.jsonDepth else {
                if visitedNodes == limits.jsonNodes + 1 || depth == limits.jsonDepth + 1 {
                    error(path, "JSON traversal limit exceeded")
                }
                return
            }
            if let array = value.array {
                for (index, item) in array.enumerated() {
                    walk(item, path: "\(path)/\(index)", expected: expected, depth: depth + 1)
                }
                return
            }
            guard let members = value.object else {
                if expected != nil { error(path, "Expected an object") }
                return
            }
            let raw = KeyxNode(members)
            let type = raw.type ?? expected
            if let version = raw["version"], let type {
                do { try Self.checkVersion(version, maximum: versions[type] ?? "1.0", context: type) }
                catch let failure { error(path, String(describing: failure)) }
            }
            if let declared = raw.type, let expected, declared != expected {
                error(path, "Expected \(expected), found \(declared)")
            }
            if let type, let id = raw["identifier"]?.string,
               !["resource.indirect-resource", "resource.base64-encoded-resource"].contains(type) {
                if let original = identifiers.updateValue(path, forKey: id) { error(path, "Duplicate identifier \(id), first used at \(original)") }
            }
            if let preset = raw["preset_identifier"]?.string, !resolver.containsPreset(preset) {
                warning(path, "Preset \(preset) was not found; the format falls back to defaults")
            }
            let node: KeyxNode
            do { node = try resolver.resolved(raw) }
            catch let failure { error(path, String(describing: failure)); return }
            switch type {
            case "slide":
                if let layout = node["layout"]?.string, !layoutIDs.contains(layout), !layoutNames.contains(layout) {
                    if layouts.isEmpty { warning(path, "Theme layout \(layout) is external; its appearance cannot be verified") }
                    else { error(path, "Unresolved slide layout: \(layout)") }
                }
            case "slide-layout":
                if node["name"]?.string == nil { error(path, "A slide layout requires a name") }
            case "slide-object":
                if node["object"]?.object == nil { error(path, "A slide object requires an object") }
            case "canvas-object":
                let count = KeyxCanvasObject.kinds.filter { node[$0] != nil }.count
                if count > 1 { error(path, "Canvas object has multiple alternatives") }
                if count == 0 { warning(path, "Unsupported canvas object is preserved but cannot be previewed") }
            case "geometry":
                do { _ = try KeyxGeometry(node: node) } catch let failure { error(path, String(describing: failure)) }
            case "size":
                if let width = node["width"]?.double, let height = node["height"]?.double,
                   width >= 0, height >= 0, width <= 50_000_000, height <= 50_000_000 {} else { error(path, "Invalid size") }
            case "text":
                let count = ["string", "paragraphs", "text_runs"].filter { node[$0] != nil }.count
                if count != 1 { error(path, "Text must have exactly one form") }
                if let text = node["string"], text.string == nil { error(path, "Text string is not a string") }
            case "text-run":
                if node["string"]?.string == nil { error(path, "A text run requires a string") }
            case "resource":
                if ["indirect", "base64_encoded"].filter({ node[$0] != nil }).count != 1 {
                    error(path, "Resource must have exactly one form")
                } else {
                    do {
                        let data = try resourceData(node.value)
                        if node["base64_encoded"] != nil {
                            guard data.count <= limits.uncompressedBytes - base64Bytes else {
                                error(path, "Aggregate embedded resource limit exceeded"); return
                            }
                            base64Bytes += data.count
                        }
                    } catch let failure { error(path, String(describing: failure)) }
                }
            case "image":
                if node["resource"] == nil { error(path, "An image requires a resource") }
            case "group":
                if node["children"]?.array?.isEmpty != false { error(path, "A group requires children") }
            case "table":
                guard let rows = node["number_of_rows"]?.integer, let columns = node["number_of_columns"]?.integer,
                      rows > 0, columns > 0, rows <= limits.tableCells / columns,
                      rows * columns <= limits.tableCells - tableCells else {
                    error(path, "Invalid or oversized table dimensions"); return
                }
                tableCells += rows * columns
                var rowIndices: Set<Int> = []
                var nextRow = 0
                for row in node["content"]?.array ?? [] {
                    let r = row["row_index"]?.integer ?? nextRow
                    if r < 0 || r >= rows || !rowIndices.insert(r).inserted { error(path, "Invalid or duplicate table row index") }
                    nextRow = r >= 0 && r < rows ? r + 1 : rows
                    var columnIndices: Set<Int> = []
                    var nextColumn = 0
                    for cell in row["cells"]?.array ?? [] {
                        let c = cell["column_index"]?.integer ?? nextColumn
                        if c < 0 || c >= columns || !columnIndices.insert(c).inserted { error(path, "Invalid or duplicate table column index") }
                        nextColumn = c >= 0 && c < columns ? c + 1 : columns
                    }
                }
                validateMerges(node, path: path, report: error)
            case "table.row", "table.column-header":
                if let kind = node["kind"]?.string, !["body", "grand_total", "group_subtotal"].contains(kind) {
                    error(path, "Invalid table structural kind: \(kind); header rows are declared by number_of_header_rows")
                }
            case "color.rgba":
                for key in ["red", "green", "blue", "alpha"] {
                    if let value = node[key], value.double.map({ (0...1).contains($0) }) != true { error(path, "Invalid \(key) color channel") }
                }
            default:
                if let type, !knownTypes.contains(type), !type.hasPrefix("table."),
                   !type.hasPrefix("stylesheet."), !type.hasPrefix("paragraph."),
                   !type.hasPrefix("slide-object."), !type.hasPrefix("chart") {
                    warning(path, "\(type) is preserved; full semantics are not implemented")
                }
            }
            let childTypes: [String: String] = [
                "slides": "slide", "theme": "keynote-theme", "slide_layouts": "slide-layout",
                "slide_size": "size", "geometry": "geometry", "position": "position", "size": "size",
                "object": "canvas-object", "children": "canvas-object", "text": "text", "note": "text",
                "text_runs": "text-run", "paragraphs": "paragraph", "run": "text-run",
                "resource": "resource", "indirect": "resource.indirect-resource", "base64_encoded": "resource.base64-encoded-resource",
                "shape": "shape", "textbox": "textbox", "image": "image", "table": "table", "group": "group",
                "chart": "chart", "character_properties": "character-properties", "paragraph_properties": "paragraph-properties",
                "layout_properties": "layout-properties", "rgba": "color.rgba"
            ]
            for key in members.keys.sorted() {
                guard let child = members[key] else { continue }
                var expected = type.map { knownTypes.contains($0) } == true ? childTypes[key] : nil
                if key == "contents" {
                    if type == "slide" || type == "slide-layout" { expected = "slide-object" }
                    else if type == "paragraph" { expected = "paragraph.constituent" }
                }
                if child == .null {
                    if type.map({ knownTypes.contains($0) }) == true,
                       ["slides", "object", "resource", "note", "geometry", "position", "size", "text",
                        "identifier", "layout", "contents", "children", "name", "version", "preset_identifier"].contains(key) {
                        error(path + "/" + key, "Null is not permitted for this property")
                    }
                    continue
                }
                walk(child, path: path + "/" + key, expected: expected, depth: depth + 1)
            }
        }
        walk(presentation.value, path: "main.json", expected: "presentation")
        for (index, preset) in presets.enumerated() {
            if let parent = preset["parent_identifier"]?.string, !resolver.containsPreset(parent) {
                warning("presets.json/\(index)", "Parent preset \(parent) was not found")
            }
            if let properties = preset["properties"] { walk(properties, path: "presets.json/\(index)/properties") }
        }
        return issues
    }

    private func validateMerges(_ table: KeyxNode, path: String, report: (String, String) -> Void) {
        guard let merges = table["merges"]?.array, !merges.isEmpty else { return }
        let rows = table["content"]?.array ?? []
        let columns = table["column_headers"]?.array ?? []
        var rowIDs: [String: Int] = [:], columnIDs: [String: Int] = [:]
        var nextRow = 0
        let height = table["number_of_rows"]?.integer ?? 0
        for row in rows {
            let index = row["row_index"]?.integer ?? nextRow
            guard index >= 0, index < height else { report(path, "Table merge row index out of bounds"); return }
            nextRow = index + 1
            if let id = row["row_identifier"]?.string {
                if rowIDs.updateValue(index, forKey: id) != nil { report(path, "Ambiguous table row identifier") }
            }
        }
        for (index, column) in columns.enumerated() {
            if let id = column["column_identifier"]?.string {
                if columnIDs.updateValue(index, forKey: id) != nil { report(path, "Ambiguous table column identifier") }
            }
        }
        var occupied: Set<Int> = []
        let width = table["number_of_columns"]?.integer ?? 0
        for merge in merges {
            guard let range = merge["row_column_id_range"],
                  let top = range["top_left_row_identifier"]?.string.flatMap({ rowIDs[$0] }),
                  let bottom = range["bottom_right_row_identifier"]?.string.flatMap({ rowIDs[$0] }),
                  let left = range["top_left_column_identifier"]?.string.flatMap({ columnIDs[$0] }),
                  let right = range["bottom_right_column_identifier"]?.string.flatMap({ columnIDs[$0] }),
                  top >= 0, bottom < height, left >= 0, right < width,
                  top <= bottom, left <= right else { report(path, "Unresolved or reversed table merge"); continue }
            let cells = (bottom - top + 1) * (right - left + 1)
            guard cells <= limits.tableCells - occupied.count else {
                report(path, "Table merge traversal limit exceeded"); return
            }
            for row in top...bottom {
                for column in left...right where !occupied.insert(row * width + column).inserted {
                    report(path, "Overlapping table merges")
                }
            }
        }
    }
}
