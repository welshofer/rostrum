import Foundation

/// An opt-in transport for the canonical font rules emitted by Rostrum's SVG
/// renderer. The caller owns isolation and lifetime. Exported SVGs never change.
/// Unknown rules and resources that exceed the budget remain inline.
public final class PreviewFontResources {
    public struct Resource: Sendable {
        public let url: String
        public let mimeType: String
        public let data: Data
    }

    public struct Document: Sendable {
        public let svg: String
        public let resources: [Resource]
    }

    public static let scheme = "lectern-preview-font"
    public static let defaultByteLimit = 32 * 1024 * 1024
    private let cache: CostLimitedCache<String, Resource>
    private let namespace = UUID().uuidString.lowercased()
    private var nextID: UInt64 = 0
    public private(set) var decodedResources = 0
    public var retainedBytes: Int { cache.totalCost }
    public var retainedCount: Int { cache.count }

    public init(capacity: Int = 32, byteLimit: Int = PreviewFontResources.defaultByteLimit) {
        cache = CostLimitedCache(capacity: capacity, costLimit: byteLimit)
    }

    // Match the small header only. Scanning megabytes of base64 through a regex
    // creates unnecessary UTF-16 storage and backtracking work.
    private static let header = try! NSRegularExpression(pattern:
        #"^@font-face\{font-family:'RostrumEmbeddedFace[1-9][0-9]*';font-style:(normal|italic);font-weight:(400|700);src:url\(data:font/(ttf|otf);base64,$"#)

    public func prepare(svg: String) -> Document {
        guard cache.capacity > 0, cache.costLimit > 0 else { return Document(svg: svg, resources: []) }
        // Native renderer strings have contiguous UTF-8. Unknown foreign storage
        // stays inline rather than copying a whole image-heavy slide just to scan.
        return svg.utf8.withContiguousStorageIfAvailable { prepare(svg: svg, bytes: $0) }
            ?? Document(svg: svg, resources: [])
    }

    private func prepare(svg: String, bytes: UnsafeBufferPointer<UInt8>) -> Document {
        func find(_ needle: [UInt8], from: Int, to: Int) -> Int? {
            guard !needle.isEmpty, from <= to - needle.count else { return nil }
            var index = from
            while index <= to - needle.count {
                if bytes[index] == needle[0] {
                    var offset = 1
                    while offset < needle.count && bytes[index + offset] == needle[offset] { offset += 1 }
                    if offset == needle.count { return index }
                }
                index += 1
            }
            return nil
        }
        let styleStart = Array("<style type=\"text/css\">".utf8), styleEnd = Array("</style>".utf8)
        let separator = Array(";base64,".utf8), dataStart = Array("data:font/".utf8)
        var replacements: [(Range<Int>, String)] = []
        var active: [String: Resource] = [:]
        var activeCost = 0
        var search = 0
        while let style = find(styleStart, from: search, to: bytes.count),
              let end = find(styleEnd, from: style + styleStart.count, to: bytes.count) {
            search = end + styleEnd.count
            var cursor = style + styleStart.count
            while cursor < end {
                guard let marker = find(separator, from: cursor, to: min(cursor + 180, end)) else { break }
                let payloadStart = marker + separator.count
                let header = String(decoding: bytes[cursor..<payloadStart], as: UTF8.self)
                guard Self.header.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)) != nil,
                      let payloadEnd = find([41], from: payloadStart, to: end),
                      let urlStart = find(dataStart, from: cursor, to: marker) else { break }
                let mime = header.hasSuffix("otf;base64,") ? "font/otf" : "font/ttf"
                let suffix = Array((mime == "font/otf" ? ") format('opentype');}" : ") format('truetype');}").utf8)
                guard find(suffix, from: payloadEnd, to: min(payloadEnd + suffix.count, end)) == payloadEnd else { break }
                cursor = payloadEnd + suffix.count
                let range = urlStart..<payloadEnd
                let encodedCount = payloadEnd - payloadStart
                // Bound both the retained encoded cache key and decoded bytes
                // before allocating or decoding an individual font.
                guard encodedCount > 0, encodedCount % 4 == 0,
                      encodedCount <= cache.costLimit / 2 else { continue }
                // Reject noncanonical trailing bits without re-encoding entire
                // fonts. This keeps replacement reversible byte for byte.
                func base64Value(_ byte: UInt8) -> UInt8? {
                    switch byte {
                    case 65...90: return byte - 65
                    case 97...122: return byte - 97 + 26
                    case 48...57: return byte - 48 + 52
                    case 43: return 62
                    case 47: return 63
                    default: return nil
                    }
                }
                if bytes[payloadEnd - 1] == 61 {
                    let doublePadding = bytes[payloadEnd - 2] == 61
                    guard let lastValue = base64Value(bytes[payloadEnd - (doublePadding ? 3 : 2)]),
                          lastValue & (doublePadding ? 15 : 3) == 0 else { continue }
                }
                let key = String(decoding: bytes[range], as: UTF8.self)
                if let hit = active[key] {
                    replacements.append((range, hit.url)); continue
                }
                guard active.count < cache.capacity else { continue }
                let upperCost = range.count + encodedCount / 4 * 3
                guard upperCost <= cache.costLimit - activeCost else { continue }
                let resource: Resource
                if let hit = cache.value(forKey: key) { resource = hit }
                else {
                    let encoded = String(decoding: bytes[payloadStart..<payloadEnd], as: UTF8.self)
                    guard let data = Data(base64Encoded: encoded), !data.isEmpty else { continue }
                    // Never reuse a URL for different bytes, including after an
                    // eviction. Font-family aliases can change between slides.
                    guard nextID < UInt64.max else { continue }
                    nextID += 1
                    resource = Resource(url: "\(Self.scheme)://\(namespace)/\(nextID)", mimeType: mime, data: data)
                    cache.insert(resource, forKey: key, cost: range.count + data.count)
                    decodedResources += 1
                }
                activeCost += range.count + resource.data.count
                active[key] = resource
                replacements.append((range, resource.url))
            }
        }
        guard !replacements.isEmpty else { return Document(svg: svg, resources: []) }
        var result = ""
        let removed = replacements.reduce(0) { $0 + $1.0.count - $1.1.utf8.count }
        result.reserveCapacity(max(0, bytes.count - removed))
        var cursor = 0
        for (range, url) in replacements {
            result.append(String(decoding: bytes[cursor..<range.lowerBound], as: UTF8.self))
            result.append(url)
            cursor = range.upperBound
        }
        result.append(String(decoding: bytes[cursor..<bytes.count], as: UTF8.self))
        return Document(svg: result, resources: active.values.sorted { $0.url < $1.url })
    }
}
