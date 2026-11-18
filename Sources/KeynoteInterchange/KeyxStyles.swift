import Foundation

/// A read-only resolution view. It never writes inherited values back into the
/// document, which would turn inheritance into accidental overrides.
public struct KeyxStyleResolver: Sendable {
    private let presets: [String: KeyxNode]
    private let stylesheet: KeyxNode?
    private let depthLimit: Int

    public init(document: KeyxDocument) throws {
        var presets: [String: KeyxNode] = [:]
        for preset in document.presets {
            guard let id = preset["identifier"]?.string, !id.isEmpty,
                  preset["properties"]?.object != nil else { throw KeyxError.invalid("Invalid preset declaration") }
            guard presets.updateValue(preset, forKey: id) == nil else {
                throw KeyxError.invalid("Ambiguous preset identifier: \(id)")
            }
        }
        self.presets = presets
        stylesheet = try document.presentation["stylesheet"].map { try KeyxNode(value: $0) }
        depthLimit = document.limits.jsonDepth
        for id in presets.keys { _ = try presetProperties(id, visited: []) }
        if let stylesheet {
            for collection in Self.collections.values {
                var ids: Set<String> = []
                for entry in stylesheet[collection]?.array ?? [] {
                    if let id = entry["preset_identifier"]?.string, !ids.insert(id).inserted {
                        throw KeyxError.invalid("Ambiguous stylesheet identifier \(id) in \(collection)")
                    }
                }
            }
        }
    }

    public func property(_ key: String, on node: KeyxNode) throws -> KeyxProperty<KeyxValue> {
        try resolved(node).property(key)
    }

    public func resolved(_ node: KeyxNode) throws -> KeyxNode {
        guard let id = node["preset_identifier"]?.string else { return node }
        var inherited = try presetProperties(id, visited: [])
        if let type = node.type, let collection = Self.collections[type],
           let entry = stylesheet?[collection]?.array?.first(where: { $0["preset_identifier"]?.string == id }) {
            // A stylesheet entry with preset_identifier is a reference. Its
            // properties field is not an inline override (Apple's schema).
            if let style = inherited["properties"]?.object { inherited = style }
            if entry["properties"] == nil { throw KeyxError.invalid("Stylesheet entry \(id) has no properties") }
        }
        return KeyxNode(inherited.merging(node.fields) { _, local in local })
    }

    public func containsPreset(_ id: String) -> Bool { presets[id] != nil }

    private func presetProperties(_ id: String, visited: Set<String>) throws -> [String: KeyxValue] {
        guard !visited.contains(id) else { throw KeyxError.invalid("Preset inheritance cycle at \(id)") }
        guard visited.count < depthLimit else { throw KeyxError.limit("Preset inheritance depth exceeded") }
        guard let preset = presets[id] else { return [:] }
        var visited = visited; visited.insert(id)
        let parent = try preset["parent_identifier"]?.string.map { try presetProperties($0, visited: visited) } ?? [:]
        return parent.merging(preset["properties"]?.object ?? [:]) { _, local in local }
    }

    private static let collections = [
        "character-properties": "character_styles", "paragraph-properties": "paragraph_styles",
        "list-properties": "list_styles", "shape": "shape_styles", "textbox": "textbox_styles",
        "image": "image_styles", "movie": "movie_styles", "connection-line": "line_styles"
    ]
}

public extension KeyxDocument {
    func styleResolver() throws -> KeyxStyleResolver { try KeyxStyleResolver(document: self) }
    func resolvedNode(_ node: KeyxNode) throws -> KeyxNode { try styleResolver().resolved(node) }
    func resolvedProperty(_ key: String, on node: KeyxNode) throws -> KeyxProperty<KeyxValue> {
        let local = node.property(key)
        if case .inherited = local { return try styleResolver().property(key, on: node) }
        return local
    }
}
