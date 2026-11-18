import Foundation

public struct KeyxSlide: Sendable, Equatable {
    public var node: KeyxNode
    public init(node: KeyxNode) { self.node = node }
    public init(identifier: String, layout: String? = nil, contents: [KeyxSlideObject] = []) {
        node = KeyxNode(type: "slide", fields: [
            "identifier": .string(identifier), "contents": .array(contents.map { $0.node.value })
        ])
        if let layout { node["layout"] = .string(layout) }
    }
    public var identifier: String? {
        get { node["identifier"]?.string }
        set { node["identifier"] = newValue.map(KeyxValue.string) }
    }
    public var contents: [KeyxSlideObject] {
        get throws {
            guard let value = node["contents"] else { return [] }
            guard let array = value.array else { throw KeyxError.invalid("Slide contents must be an array") }
            return try array.map { KeyxSlideObject(node: try KeyxNode(value: $0)) }
        }
    }
    public mutating func setContents(_ objects: [KeyxSlideObject]) {
        node["contents"] = .array(objects.map { $0.node.value })
    }
    public var note: KeyxProperty<KeyxText> {
        get throws { try node.property("note").map { KeyxText(node: try KeyxNode(value: $0)) } }
    }
    public mutating func setNote(_ note: KeyxProperty<KeyxText>) { node.set("note", to: note.map { $0.node.value }) }
}

public struct KeyxSlideObject: Sendable, Equatable {
    public var node: KeyxNode
    public init(node: KeyxNode) { self.node = node }
    public init(canvas: KeyxCanvasObject) {
        node = KeyxNode(type: "slide-object", fields: ["source_kind": .string("user"), "object": canvas.node.value])
    }
    public var canvas: KeyxCanvasObject {
        get throws {
            guard let value = node["object"] else { throw KeyxError.invalid("Slide object has no canvas object") }
            return try KeyxCanvasObject(node: KeyxNode(value: value))
        }
    }
    public mutating func setCanvas(_ canvas: KeyxCanvasObject) { node["object"] = canvas.node.value }
}

public struct KeyxCanvasObject: Sendable, Equatable {
    public var node: KeyxNode
    public init(node: KeyxNode) { self.node = node }
    public init(kind: String, properties: KeyxNode) {
        node = KeyxNode(type: "canvas-object", fields: [kind: properties.value])
    }
    public static let kinds: Set<String> = [
        "textbox", "shape", "image", "table", "chart", "group", "connectionLine", "movie", "audio"
    ]
    public var kind: String {
        get throws {
            let keys = node.fields.keys.filter { Self.kinds.contains($0) }
            guard keys.count == 1, let key = keys.first else {
                throw KeyxError.unsupported("Unrecognized or ambiguous canvas object; original JSON is preserved")
            }
            return key
        }
    }
    public var properties: KeyxNode {
        get throws {
            let kind = try self.kind
            guard let value = node[kind] else { throw KeyxError.invalid("Missing canvas properties") }
            return try KeyxNode(value: value)
        }
    }
    public mutating func editProperties(_ edit: (inout KeyxNode) throws -> Void) throws {
        let kind = try self.kind
        var properties = try self.properties
        try edit(&properties)
        node[kind] = properties.value
    }
}

public struct KeyxText: Sendable, Equatable {
    public var node: KeyxNode
    public init(node: KeyxNode) { self.node = node }
    public init(_ string: String) { node = KeyxNode(type: "text", fields: ["string": .string(string)]) }
    public init(runs: [KeyxTextRun]) {
        node = KeyxNode(type: "text", fields: ["text_runs": .array(runs.map { $0.node.value })])
    }
    public init(paragraphs: [KeyxNode]) {
        node = KeyxNode(type: "text", fields: ["paragraphs": .array(paragraphs.map(\.value))])
    }
    public var plainText: String {
        get throws {
            if let string = node["string"]?.string { return string }
            if let runs = node["text_runs"]?.array {
                return try runs.map { try Self.runString($0) }.joined()
            }
            if let paragraphs = node["paragraphs"]?.array {
                return try paragraphs.map { paragraph in
                    guard let members = paragraph.object else { throw KeyxError.invalid("Invalid text paragraph") }
                    guard let content = members["contents"] else { return "" }
                    guard let contents = content.array else { throw KeyxError.invalid("Invalid paragraph contents") }
                    return try contents.map { constituent in
                        if let run = constituent["run"] { return try Self.runString(run) }
                        if let run = constituent["hyperlink"]?["run"] { return try Self.runString(run) }
                        if constituent["inline_object"] != nil {
                            throw KeyxError.unsupported("Inline text objects are preserved but cannot be extracted as plain text")
                        }
                        throw KeyxError.unsupported("Unknown paragraph constituent")
                    }.joined()
                }.joined(separator: "\n")
            }
            throw KeyxError.invalid("Text must contain string, text_runs or paragraphs")
        }
    }
    private static func runString(_ value: KeyxValue) throws -> String {
        guard let string = value["string"]?.string else { throw KeyxError.invalid("Text run has no string") }
        return string
    }
}

public struct KeyxTextRun: Sendable, Equatable {
    public var node: KeyxNode
    public init(node: KeyxNode) { self.node = node }
    public init(_ text: String, style: KeyxNode? = nil) {
        node = KeyxNode(type: "text-run", fields: ["string": .string(text)])
        if let style { node["style"] = style.value }
    }
    public var style: KeyxProperty<KeyxNode> {
        get throws { try node.property("style").map { try KeyxNode(value: $0) } }
    }
    public mutating func setStyle(_ style: KeyxProperty<KeyxNode>) { node.set("style", to: style.map(\.value)) }
}

/// Coordinates are points. Position is the post-rotation bounding box's
/// top-left; size is pre-rotation. Group children remain slide-absolute.
public struct KeyxGeometry: Sendable, Equatable {
    public private(set) var node: KeyxNode
    public init(x: Double, y: Double, width: Double, height: Double, angle: Double = 0) {
        node = KeyxNode(type: "geometry", fields: [
            "position": KeyxNode(type: "position", fields: ["x": .decimal(x), "y": .decimal(y)]).value,
            "size": KeyxNode(type: "size", fields: ["width": .decimal(width), "height": .decimal(height)]).value,
            "angle": .decimal(angle)
        ])
    }
    public init(node: KeyxNode) throws {
        guard let x = node["position"]?["x"]?.double, let y = node["position"]?["y"]?.double,
              let width = node["size"]?["width"]?.double, let height = node["size"]?["height"]?.double,
              width >= 0, height >= 0, [x, y, width, height].allSatisfy({ abs($0) <= 50_000_000 }),
              node["angle"] == nil || node["angle"]?.double != nil else {
            throw KeyxError.invalid("Invalid or unbounded geometry")
        }
        for flag in ["flip_horizontally", "width_valid", "height_valid"] {
            if node[flag] != nil, node[flag]?.bool == nil { throw KeyxError.invalid("Invalid geometry flag: \(flag)") }
        }
        self.node = node
    }
    public var x: Double { node["position"]?["x"]?.double ?? 0 }
    public var y: Double { node["position"]?["y"]?.double ?? 0 }
    public var width: Double { node["size"]?["width"]?.double ?? 0 }
    public var height: Double { node["size"]?["height"]?.double ?? 0 }
    public var angle: Double { node["angle"]?.double ?? 0 }
    var previewAngle: Double { angle.truncatingRemainder(dividingBy: 360) }
    public var flipped: Bool { node["flip_horizontally"]?.bool ?? false }
    public var rotatedWidth: Double {
        let radians = previewAngle * .pi / 180
        return abs(width * cos(radians)) + abs(height * sin(radians))
    }
    public var rotatedHeight: Double {
        let radians = previewAngle * .pi / 180
        return abs(width * sin(radians)) + abs(height * cos(radians))
    }
    public var centerX: Double { x + rotatedWidth / 2 }
    public var centerY: Double { y + rotatedHeight / 2 }
}

public extension KeyxNode {
    static func color(hex: String) throws -> KeyxNode {
        let hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else { throw KeyxError.invalid("Expected six-digit RGB color") }
        return KeyxNode(type: "color", fields: [
            "rgba": KeyxNode(type: "color.rgba", fields: [
                "color_space": .string("srgb"),
                "red": .decimal(Double((rgb >> 16) & 255) / 255),
                "green": .decimal(Double((rgb >> 8) & 255) / 255),
                "blue": .decimal(Double(rgb & 255) / 255), "alpha": .integer(1)
            ]).value
        ])
    }
    static func fill(hex: String) throws -> KeyxNode {
        KeyxNode(type: "fill", fields: ["color": try color(hex: hex).value])
    }
}
