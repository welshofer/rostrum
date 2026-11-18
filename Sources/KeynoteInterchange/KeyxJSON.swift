import Foundation

/// JSON numbers retain their original spelling, including integers beyond
/// Double's precision. Editing a known field must not round an unknown one.
public indirect enum KeyxValue: Sendable, Equatable {
    case object([String: KeyxValue])
    case array([KeyxValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    public static func integer(_ value: Int) -> Self { .number(String(value)) }
    public static func decimal(_ value: Double) -> Self { .number(String(value)) }

    public var object: [String: KeyxValue]? {
        guard case .object(let value) = self else { return nil }; return value
    }
    public var array: [KeyxValue]? {
        guard case .array(let value) = self else { return nil }; return value
    }
    public var string: String? {
        guard case .string(let value) = self else { return nil }; return value
    }
    public var double: Double? {
        guard case .number(let value) = self, let number = Double(value), number.isFinite else { return nil }
        return number
    }
    public var integer: Int? {
        guard case .number(let spelling) = self else { return nil }
        if let integer = Int(spelling) { return integer }
        let parts = spelling.lowercased().split(separator: "e", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count) else { return nil }
        let exponent = parts.count == 2 ? Int(parts[1]) : 0
        guard let exponent else { return nil }
        let negative = parts[0].hasPrefix("-")
        let significand = negative ? parts[0].dropFirst() : parts[0][...]
        let decimal = significand.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(decimal.count), decimal.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        var digits = String(decimal.joined().drop(while: { $0 == "0" }))
        if digits.isEmpty { return 0 }
        let fractionCount = decimal.count == 2 ? decimal[1].count : 0
        let (shift, overflow) = exponent.subtractingReportingOverflow(fractionCount)
        guard !overflow else { return nil }
        if shift < 0 {
            guard shift >= -digits.count, digits.suffix(-shift).allSatisfy({ $0 == "0" }) else { return nil }
            digits.removeLast(-shift)
        } else {
            guard shift <= 19 - digits.count else { return nil }
            digits += String(repeating: "0", count: shift)
        }
        return Int((negative ? "-" : "") + digits)
    }
    public var bool: Bool? {
        guard case .bool(let value) = self else { return nil }; return value
    }
    public subscript(_ key: String) -> KeyxValue? { object?[key] }

    public static func parse(_ data: Data, limits: KeyxLimits = .default) throws -> KeyxValue {
        try limits.check()
        guard data.count <= limits.jsonBytes else { throw KeyxError.limit("JSON byte limit exceeded") }
        guard String(data: data, encoding: .utf8) != nil else { throw KeyxError.invalid("JSON is not UTF-8") }
        var parser = KeyxJSONParser(bytes: Array(data), limits: limits)
        let value = try parser.value(depth: 0)
        parser.whitespace()
        guard parser.offset == parser.bytes.count else { throw KeyxError.invalid("Trailing JSON content") }
        return value
    }

    /// Stable key ordering. Untouched JSON archive entries use their original
    /// bytes instead; this encoder is only needed for new or edited entries.
    public func data(limits: KeyxLimits = .default) throws -> Data {
        try limits.check()
        var output = Data()
        var nodes = 0
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        func append(_ value: KeyxValue, depth: Int) throws {
            nodes += 1
            guard depth <= limits.jsonDepth, nodes <= limits.jsonNodes else {
                throw KeyxError.limit("JSON nesting or node limit exceeded")
            }
            switch value {
            case .object(let members):
                output.append(123)
                for (index, key) in members.keys.sorted().enumerated() {
                    if index > 0 { output.append(44) }
                    output.append(try encoder.encode(key)); output.append(58)
                    if let member = members[key] { try append(member, depth: depth + 1) }
                }
                output.append(125)
            case .array(let values):
                output.append(91)
                for (index, item) in values.enumerated() {
                    if index > 0 { output.append(44) }
                    try append(item, depth: depth + 1)
                }
                output.append(93)
            case .string(let text): output.append(try encoder.encode(text))
            case .number(let spelling):
                guard spelling.utf8.count <= limits.jsonBytes else { throw KeyxError.limit("Number too long") }
                var parser = KeyxJSONParser(bytes: Array(spelling.utf8), limits: limits)
                _ = try parser.number()
                guard parser.offset == parser.bytes.count else { throw KeyxError.invalid("Invalid JSON number") }
                output.append(contentsOf: spelling.utf8)
            case .bool(let flag): output.append(contentsOf: (flag ? "true" : "false").utf8)
            case .null: output.append(contentsOf: "null".utf8)
            }
            guard output.count <= limits.jsonBytes else { throw KeyxError.limit("JSON byte limit exceeded") }
        }
        try append(self, depth: 0)
        return output
    }
}

/// Absence inherits; null explicitly clears. Neither is a concrete value.
public enum KeyxProperty<Value: Sendable>: Sendable {
    case inherited
    case cleared
    case value(Value)

    public var value: Value? {
        guard case .value(let value) = self else { return nil }; return value
    }
    public func map<T: Sendable>(_ transform: (Value) throws -> T) rethrows -> KeyxProperty<T> {
        switch self {
        case .inherited: return .inherited
        case .cleared: return .cleared
        case .value(let value): return .value(try transform(value))
        }
    }
}

extension KeyxProperty: Equatable where Value: Equatable {}

/// A typed object's backing store. Unknown fields remain part of the object.
public struct KeyxNode: Sendable, Equatable {
    public var fields: [String: KeyxValue]

    public init(_ fields: [String: KeyxValue] = [:]) { self.fields = fields }
    public init(value: KeyxValue) throws {
        guard let fields = value.object else { throw KeyxError.invalid("Expected a JSON object") }
        self.fields = fields
    }
    public init(type: String, fields: [String: KeyxValue] = [:]) {
        self.fields = fields
        self.fields["type_identifier"] = .string(Self.typePrefix + type)
    }
    public static let typePrefix = "com.apple.apps.content-language."
    public var value: KeyxValue { .object(fields) }
    public var type: String? {
        guard let identifier = fields["type_identifier"]?.string else { return nil }
        return identifier.hasPrefix(Self.typePrefix) ? String(identifier.dropFirst(Self.typePrefix.count)) : identifier
    }
    public subscript(_ key: String) -> KeyxValue? {
        get { fields[key] }
        set { fields[key] = newValue }
    }
    public func property(_ key: String) -> KeyxProperty<KeyxValue> {
        guard let value = fields[key] else { return .inherited }
        return value == .null ? .cleared : .value(value)
    }
    public mutating func set(_ key: String, to property: KeyxProperty<KeyxValue>) {
        switch property {
        case .inherited: fields.removeValue(forKey: key)
        case .cleared: fields[key] = .null
        case .value(let value): fields[key] = value
        }
    }
}

private struct KeyxJSONParser {
    let bytes: [UInt8]
    let limits: KeyxLimits
    var offset = 0
    var nodes = 0

    mutating func whitespace() {
        while offset < bytes.count, [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 }
    }
    mutating func value(depth: Int) throws -> KeyxValue {
        nodes += 1
        guard depth <= limits.jsonDepth, nodes <= limits.jsonNodes else {
            throw KeyxError.limit("JSON nesting or node limit exceeded")
        }
        whitespace()
        guard offset < bytes.count else { throw KeyxError.invalid("Unexpected end of JSON") }
        switch bytes[offset] {
        case 123:
            offset += 1; whitespace()
            var members: [String: KeyxValue] = [:]
            if take(125) { return .object(members) }
            while true {
                whitespace()
                let key = try string()
                guard members[key] == nil else { throw KeyxError.invalid("Duplicate JSON member: \(key)") }
                whitespace()
                guard take(58) else { throw KeyxError.invalid("Missing JSON colon") }
                members[key] = try value(depth: depth + 1)
                whitespace()
                if take(125) { return .object(members) }
                guard take(44) else { throw KeyxError.invalid("Missing JSON comma") }
            }
        case 91:
            offset += 1; whitespace()
            var values: [KeyxValue] = []
            if take(93) { return .array(values) }
            while true {
                values.append(try value(depth: depth + 1)); whitespace()
                if take(93) { return .array(values) }
                guard take(44) else { throw KeyxError.invalid("Missing JSON comma") }
            }
        case 34: return .string(try string())
        case 116: try literal("true"); return .bool(true)
        case 102: try literal("false"); return .bool(false)
        case 110: try literal("null"); return .null
        default: return try number()
        }
    }
    mutating func take(_ byte: UInt8) -> Bool {
        guard offset < bytes.count, bytes[offset] == byte else { return false }
        offset += 1; return true
    }
    mutating func literal(_ text: String) throws {
        let expected = Array(text.utf8)
        guard bytes.count - offset >= expected.count,
              bytes[offset..<(offset + expected.count)].elementsEqual(expected) else {
            throw KeyxError.invalid("Invalid JSON literal")
        }
        offset += expected.count
    }
    mutating func string() throws -> String {
        let start = offset
        guard take(34) else { throw KeyxError.invalid("Expected JSON string") }
        while offset < bytes.count {
            let byte = bytes[offset]; offset += 1
            if byte == 34 {
                do { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<offset])) }
                catch { throw KeyxError.invalid("Invalid JSON string: \(error)") }
            }
            if byte == 92 {
                guard offset < bytes.count else { break }
                offset += 1
            }
        }
        throw KeyxError.invalid("Unterminated JSON string")
    }
    mutating func number() throws -> KeyxValue {
        let start = offset
        _ = take(45)
        if !take(48) {
            guard offset < bytes.count, (49...57).contains(bytes[offset]) else {
                throw KeyxError.invalid("Invalid JSON number")
            }
            digits()
        }
        if take(46) {
            let begin = offset; digits()
            guard offset > begin else { throw KeyxError.invalid("Invalid JSON fraction") }
        }
        if take(101) || take(69) {
            if !take(43) { _ = take(45) }
            let begin = offset; digits()
            guard offset > begin else { throw KeyxError.invalid("Invalid JSON exponent") }
        }
        return .number(String(decoding: bytes[start..<offset], as: UTF8.self))
    }
    mutating func digits() {
        while offset < bytes.count, (48...57).contains(bytes[offset]) { offset += 1 }
    }
}
