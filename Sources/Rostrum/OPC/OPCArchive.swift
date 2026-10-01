import Foundation

/// Read-only, bounded access to a package before materializing its editable
/// object graph. Existing Presentation initializers remain fully eager.
/// Returned XML trees are independent inspection copies; edits to them are not
/// saved. Call `presentation()` to obtain the complete editable document.
public final class OPCArchive {
    public enum Validation: Sendable {
        /// Validate every payload at open, retaining at most the cache budget.
        case strict
        /// Validate CRC/decoded size when a payload is first requested. Archive
        /// structure and aggregate declared-byte limits are still checked at open.
        case onAccess
    }
    public struct CacheStatistics: Sendable, Equatable {
        public let retainedBytes: Int
        public let hits: Int
        public let misses: Int
    }
    private let source: Data
    private let reader: ZipReader
    private let limits: ZipReader.Limits
    private let maximumEntryBytes: Int
    private let cacheBudget: Int
    private var cache: [String: Data] = [:]
    private var recency: [String] = []
    private var retained = 0
    private var hits = 0
    private var misses = 0
    public let contentTypes: ContentTypesMap
    public let relationships: Relationships
    public let partURIs: [PackURI]

    public init(data: Data, validation: Validation = .strict,
                limits: ZipReader.Limits = .default,
                maximumEntryBytes: Int = 256 * 1024 * 1024,
                cacheBytes: Int = 16 * 1024 * 1024) throws {
        self.source = data
        self.limits = limits
        self.maximumEntryBytes = max(0, maximumEntryBytes)
        self.cacheBudget = max(0, cacheBytes)
        reader = try ZipReader(data: data, limits: limits)
        // Enforce per-entry working-set ceilings before decompression, including
        // the two metadata streams required to identify the package.
        for entry in reader.allEntries where entry.uncompressedSize > self.maximumEntryBytes {
            throw RostrumError.packageInvalid("entry \(entry.name) exceeds the lazy archive per-entry budget")
        }
        contentTypes = try ContentTypesMap.parse(reader.data(forEntry: PackURI.contentTypes.memberName))
        relationships = reader.contains(PackURI.packageRels.memberName)
            ? try Relationships.parse(reader.data(forEntry: PackURI.packageRels.memberName)) : Relationships()
        partURIs = reader.entryNames.filter {
            !$0.hasSuffix("/") && !$0.hasSuffix(".rels") && $0 != PackURI.contentTypes.memberName
        }.map { PackURI("/" + $0) }.sorted { $0.value < $1.value }
        if validation == .strict {
            for name in reader.entryNames { _ = try read(name) }
        }
    }

    public convenience init(contentsOf url: URL, validation: Validation = .strict,
                            limits: ZipReader.Limits = .default,
                            maximumEntryBytes: Int = 256 * 1024 * 1024,
                            cacheBytes: Int = 16 * 1024 * 1024) throws {
        try self.init(data: Data(contentsOf: url, options: .mappedIfSafe), validation: validation,
                      limits: limits, maximumEntryBytes: maximumEntryBytes, cacheBytes: cacheBytes)
    }

    public var cacheStatistics: CacheStatistics { .init(retainedBytes: retained, hits: hits, misses: misses) }
    public func clearCache() { cache.removeAll(); recency.removeAll(); retained = 0 }

    public func data(forPart uri: PackURI) throws -> Data { try read(uri.memberName) }
    public func xml(forPart uri: PackURI) throws -> XML.Element { try XML.parse(read(uri.memberName)) }

    /// Materialize an independent editable presentation with the original eager
    /// validation and error timing. All package entries remain present.
    public func presentation() throws -> Presentation { try Presentation(data: source, limits: limits) }

    public var mainPartURI: PackURI? {
        relationships.first(ofType: RelType.officeDocument).map { PackURI.resolve(target: $0.target, relativeTo: "/") }
    }

    private func read(_ name: String) throws -> Data {
        if let value = cache[name] {
            hits += 1; recency.removeAll { $0 == name }; recency.append(name)
            return value
        }
        misses += 1
        let value = try reader.data(forEntry: name)
        if value.count <= cacheBudget {
            while retained + value.count > cacheBudget, let oldest = recency.first {
                recency.removeFirst()
                retained -= cache.removeValue(forKey: oldest)?.count ?? 0
            }
            cache[name] = value; recency.append(name); retained += value.count
        }
        return value
    }
}
