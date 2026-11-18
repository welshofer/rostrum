import Foundation
import Rostrum

public enum KeyxError: Error, Sendable, LocalizedError, CustomStringConvertible {
    case invalid(String)
    case limit(String)
    case unsupported(String)
    case validation([KeyxDiagnostic])

    public var description: String {
        switch self {
        case .invalid(let message), .limit(let message), .unsupported(let message): return message
        case .validation(let issues): return issues.map(\.description).joined(separator: "\n")
        }
    }
    public var errorDescription: String? { description }
}

public struct KeyxDiagnostic: Sendable, Equatable, CustomStringConvertible {
    public enum Severity: String, Sendable { case warning, error }
    public let severity: Severity
    public let path: String
    public let message: String
    public init(_ severity: Severity, path: String, message: String) {
        self.severity = severity; self.path = path; self.message = message
    }
    public var description: String { "\(path): \(message)" }
}

/// Limits apply on read AND write, including embedded Base64 resources.
public struct KeyxLimits: Sendable, Equatable {
    public var archiveBytes = 256 << 20
    public var uncompressedBytes = 512 << 20
    public var jsonBytes = 32 << 20
    public var resourceBytes = 128 << 20
    public var entries = 10_000
    public var jsonDepth = 96
    public var jsonNodes = 1_000_000
    public var tableCells = 100_000
    public init() {}
    public static let `default` = KeyxLimits()
    func check() throws {
        guard [archiveBytes, uncompressedBytes, jsonBytes, resourceBytes, entries,
               jsonDepth, jsonNodes, tableCells].allSatisfy({ $0 > 0 }) else {
            throw KeyxError.invalid("Keynote interchange limits must be positive")
        }
    }
}

/// A same-format document, never a DeckIR projection. It owns every archive
/// entry and all JSON fields, including content this library cannot preview.
public struct KeyxDocument: Sendable {
    public var presentation: KeyxNode
    public var manifest: KeyxNode
    public var presets: [KeyxNode]
    public let limits: KeyxLimits
    private var entries: [String: Data]
    private var originals: [String: KeyxValue]

    public init(presentation: KeyxNode, presets: [KeyxNode] = [], limits: KeyxLimits = .default) throws {
        try limits.check()
        self.presentation = presentation; self.presets = presets; self.limits = limits
        manifest = KeyxNode(["package_version": .string("1.0")])
        entries = [:]; originals = [:]
    }

    public init(contentsOf url: URL, limits: KeyxLimits = .default) throws {
        try limits.check()
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        if let size, size > limits.archiveBytes { throw KeyxError.limit("Archive byte limit exceeded") }
        try self.init(data: Data(contentsOf: url), limits: limits)
    }

    public init(data: Data, limits: KeyxLimits = .default) throws {
        try limits.check()
        guard data.count <= limits.archiveBytes else { throw KeyxError.limit("Archive byte limit exceeded") }
        let archive = try ZipReader(data: data, limits: .init(totalUncompressedBytes: limits.uncompressedBytes))
        guard archive.centralDirectoryRecords.count <= limits.entries else {
            throw KeyxError.limit("Archive entry limit exceeded")
        }
        var names: Set<String> = []
        for entry in archive.centralDirectoryRecords {
            guard names.insert(entry.name).inserted else { throw KeyxError.invalid("Duplicate ZIP entry: \(entry.name)") }
            try Self.checkEntryName(entry.name)
            let maximum = Self.jsonNames.contains(entry.name) ? limits.jsonBytes : limits.resourceBytes
            guard entry.uncompressedSize <= maximum else { throw KeyxError.limit("Entry is too large: \(entry.name)") }
        }
        guard names.contains("main.json") else { throw KeyxError.invalid("The archive has no main.json") }
        // Check the package version before inflating or parsing the document.
        let manifestData = try names.contains("manifest.json") ? archive.data(forEntry: "manifest.json") : nil
        let manifestValue = try manifestData.map { try KeyxValue.parse($0, limits: limits) }
            ?? KeyxValue.object(["package_version": .string("1.0")])
        let manifest = try KeyxNode(value: manifestValue)
        try Self.checkVersion(manifest["package_version"], maximum: "1.0", context: "package")
        let mainData = try archive.data(forEntry: "main.json")
        let mainValue = try KeyxValue.parse(mainData, limits: limits)
        let presentation = try KeyxNode(value: mainValue)
        guard let slides = presentation["slides"]?.array, !slides.isEmpty,
              slides.allSatisfy({ $0.object != nil }) else {
            throw KeyxError.invalid("main.json must contain a nonempty slides array of objects")
        }
        let presetData = try names.contains("presets.json") ? archive.data(forEntry: "presets.json") : nil
        let presetValue = try presetData.map { try KeyxValue.parse($0, limits: limits) } ?? .array([])
        guard let presetValues = presetValue.array else { throw KeyxError.invalid("presets.json must be an array") }
        self.presentation = presentation; self.manifest = manifest
        presets = try presetValues.map { try KeyxNode(value: $0) }
        self.limits = limits
        entries = ["main.json": mainData]
        if let manifestData { entries["manifest.json"] = manifestData }
        if let presetData { entries["presets.json"] = presetData }
        for name in archive.entryNames where !Self.jsonNames.contains(name) {
            entries[name] = try archive.data(forEntry: name)
        }
        originals = ["main.json": mainValue, "manifest.json": manifestValue, "presets.json": presetValue]
    }

    public var slides: [KeyxSlide] {
        get throws {
            guard let values = presentation["slides"]?.array else { throw KeyxError.invalid("Missing slides array") }
            return try values.map { KeyxSlide(node: try KeyxNode(value: $0)) }
        }
    }
    public mutating func replaceSlides(_ slides: [KeyxSlide]) {
        presentation["slides"] = .array(slides.map { $0.node.value })
    }
    public mutating func editSlide(at index: Int, _ edit: (inout KeyxSlide) throws -> Void) throws {
        var slides = try self.slides
        guard slides.indices.contains(index) else { throw KeyxError.invalid("Slide index out of bounds: \(index)") }
        try edit(&slides[index])
        replaceSlides(slides)
    }
    public var archiveEntryNames: [String] {
        Array(Set(entries.keys).union(Self.jsonNames)).sorted()
    }
    /// Unmodeled entries remain byte-for-byte intact. JSON entries are accessed
    /// through the document model, so raw writes cannot bypass its validation.
    public func entryData(named name: String) -> Data? { entries[name] }
    public mutating func setEntry(named name: String, data: Data) throws {
        try Self.checkEntryName(name)
        guard !Self.jsonNames.contains(name) else { throw KeyxError.invalid("Edit \(name) through the document model") }
        guard data.count <= limits.resourceBytes else { throw KeyxError.limit("Resource byte limit exceeded") }
        entries[name] = data
    }

    public func resourceData(_ resource: KeyxValue) throws -> Data {
        let resolved = try resolvedNode(KeyxNode(value: resource))
        if let indirect = resolved["indirect"] {
            let node = try resolvedNode(KeyxNode(value: indirect))
            guard let filename = node["filename"]?.string else { throw KeyxError.invalid("Resource filename is missing") }
            let name = node["identifier"]?.string ?? filename
            try Self.checkResourceName(name)
            guard let data = entries["Data/" + name] else { throw KeyxError.invalid("Missing resource Data/\(name) (case-sensitive)") }
            return data
        }
        if let encoded = resolved["base64_encoded"] {
            let node = try resolvedNode(KeyxNode(value: encoded))
            guard node["filename"]?.string != nil, let string = node["string"]?.string else {
                throw KeyxError.invalid("Base64 resource requires filename and string")
            }
            guard string.utf8.count / 4 <= limits.resourceBytes / 3 + 1 else {
                throw KeyxError.limit("Embedded resource byte limit exceeded")
            }
            guard let data = Data(base64Encoded: string), data.count <= limits.resourceBytes else {
                throw KeyxError.invalid("Invalid or oversized Base64 resource")
            }
            return data
        }
        throw KeyxError.unsupported("Unknown resource form; bytes remain preserved")
    }

    @discardableResult
    public mutating func addResource(_ data: Data, filename: String, identifier: String? = nil) throws -> KeyxValue {
        try Self.checkResourceName(filename)
        let name = identifier ?? filename
        try Self.checkResourceName(name)
        if let existing = entries["Data/" + name], existing != data {
            throw KeyxError.invalid("A different resource already uses \(name)")
        }
        try setEntry(named: "Data/" + name, data: data)
        var fields: [String: KeyxValue] = ["filename": .string(filename)]
        if let identifier { fields["identifier"] = .string(identifier) }
        return KeyxNode(type: "resource", fields: [
            "indirect": KeyxNode(type: "resource.indirect-resource", fields: fields).value
        ]).value
    }

    public func data() throws -> Data {
        let errors = validate().filter { $0.severity == .error }
        guard errors.isEmpty else { throw KeyxError.validation(errors) }
        let values = ["main.json": presentation.value, "manifest.json": manifest.value,
                      "presets.json": KeyxValue.array(presets.map(\.value))]
        var output = entries
        for (name, value) in values {
            if originals[name] != value || output[name] == nil { output[name] = try value.data(limits: limits) }
        }
        guard output.count <= limits.entries else { throw KeyxError.limit("Archive entry limit exceeded") }
        var total = 0
        for data in output.values {
            guard data.count <= limits.uncompressedBytes - total else { throw KeyxError.limit("Uncompressed byte limit exceeded") }
            total += data.count
        }
        var writer = ZipWriter()
        for name in output.keys.sorted() {
            if let data = output[name] { writer.addFile(name: name, data: data) }
        }
        let data = try writer.finalize()
        guard data.count <= limits.archiveBytes else { throw KeyxError.limit("Archive byte limit exceeded") }
        return data
    }

    public func save(to url: URL) throws { try data().write(to: url, options: .atomic) }

    static let jsonNames: Set<String> = ["main.json", "manifest.json", "presets.json"]
    static func checkResourceName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains("\\"), !name.utf8.contains(0) else {
            throw KeyxError.invalid("Resource names must be flat, nonempty filenames")
        }
    }
    static func checkEntryName(_ name: String) throws {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\"), !name.utf8.contains(0),
              !name.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." }) else {
            throw KeyxError.invalid("Unsafe archive entry name: \(name)")
        }
        if name.hasPrefix("Data/"), name != "Data/" { try checkResourceName(String(name.dropFirst(5))) }
    }
    static func checkVersion(_ value: KeyxValue?, maximum: String, context: String) throws {
        guard let value else { return }
        func components(_ value: String) -> [Int]? {
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
                  let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
            return [major, minor]
        }
        guard let spelling = value.string, let version = components(spelling),
              let supported = components(maximum) else { throw KeyxError.invalid("Malformed \(context) version") }
        guard !supported.lexicographicallyPrecedes(version) else {
            throw KeyxError.unsupported("\(context) version \(spelling) is newer than supported \(maximum); it will not be downgraded")
        }
    }
}
