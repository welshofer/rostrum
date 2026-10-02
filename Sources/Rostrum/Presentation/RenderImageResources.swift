import Foundation

/// One render shares image resolution between diagnostics and paint emission.
/// Discarded before the next render: public relationships and blobs are mutable.
final class RenderImageResources {
    final class Resource {
        let data: Data
        let info: ImageInfo?
        fileprivate var encodedURL: String?

        init(_ data: Data) { self.data = data; info = ImageSniffer.sniff(data) }
    }
    private struct Reference: Hashable { let owner: ObjectIdentifier; let id: String }
    private enum Resolution { case missing, found(Resource) }
    private var references: [Reference: Resolution] = [:]
    private var media: [ObjectIdentifier: Resource] = [:]

    private enum OwnerRelationships {
        case observing(visited: Int), linear
        case indexed([String: Relationship])
    }
    private var ownerRelationships: [ObjectIdentifier: OwnerRelationships] = [:]
    private(set) var relationshipIndexEntryCount = 0
    private(set) var relationshipIndexBytes = 0
    var relationshipOwnerCount: Int { ownerRelationships.count }
    private let relationshipOwnerLimit = 16
    private let relationshipEntryLimit = 4096
    private let relationshipByteLimit = 512 * 1024

    private var encodedBytes = 0
    private let encodedByteLimit = 4 * 1024 * 1024

    func reset() {
        references.removeAll(); media.removeAll(); encodedBytes = 0
        ownerRelationships.removeAll(); relationshipIndexEntryCount = 0; relationshipIndexBytes = 0
    }

    private func relationship(_ id: String, owner: Part) -> Relationship? {
        let identity = ObjectIdentifier(owner)
        let previousVisits: Int
        if let cached = ownerRelationships[identity] {
            switch cached {
            case .indexed(let index): return index[id]
            case .linear: return owner.rels.relationship(withId: id)
            case .observing(let visited): previousVisits = visited
            }
        } else {
            guard ownerRelationships.count < relationshipOwnerLimit else {
                return owner.rels.relationship(withId: id)
            }
            previousVisits = 0
        }

        let relationships = owner.rels.items
        guard relationships.count >= 16,
              relationships.count <= relationshipEntryLimit - relationshipIndexEntryCount else {
            ownerRelationships[identity] = .linear
            return owner.rels.relationship(withId: id)
        }
        // Count only the work needed for this actual lookup, stopping at the
        // first match. A few early references in a large list must stay cheap.
        var visited = 0
        var found: Relationship?
        for relationship in relationships {
            visited += 1
            if relationship.rId == id { found = relationship; break }
        }
        // The entry bound also bounds this arithmetic. Build only after the
        // uncached searches have visited twice as many arcs as the whole list.
        let threshold = 2 * relationships.count
        let accumulatedVisits = min(threshold, previousVisits + visited)
        guard accumulatedVisits == threshold else {
            ownerRelationships[identity] = .observing(visited: accumulatedVisits)
            return found
        }

        // Remember refused admission too: later references must not repeatedly
        // scan the list trying to construct an index that exceeds its budget.
        ownerRelationships[identity] = .linear
        var index: [String: Relationship] = [:]
        var bytes = 0
        let availableBytes = relationshipByteLimit - relationshipIndexBytes
        for relationship in relationships where index[relationship.rId] == nil {
            // Include keys, values and an allowance for dictionary overhead.
            // This is an accounting bound, not a process-memory measurement.
            var cost = 128
            guard cost <= availableBytes - bytes else { return found }
            for size in [relationship.rId.utf8.count, relationship.type.utf8.count, relationship.target.utf8.count] {
                guard size <= availableBytes - bytes - cost else { return found }
                cost += size
            }
            bytes += cost
            // A malformed duplicate ID has always resolved to its first arc.
            // Retain that behavior rather than dictionary last-write wins.
            index[relationship.rId] = relationship
        }
        relationshipIndexEntryCount += index.count
        relationshipIndexBytes += bytes
        ownerRelationships[identity] = .indexed(index)
        return found
    }

    func url(for resource: Resource) -> String? {
        guard let info = resource.info else { return nil }
        if let cached = resource.encodedURL { return cached }
        let result = "data:\(info.format.contentType);base64,\(resource.data.base64EncodedString())"
        // Do not retain another unbounded copy of all unique image payloads.
        if result.utf8.count <= encodedByteLimit - encodedBytes {
            resource.encodedURL = result
            encodedBytes += result.utf8.count
        }
        return result
    }

    func resolve(_ id: String, owner: Part, package: OPCPackage) -> Resource? {
        let key = Reference(owner: ObjectIdentifier(owner), id: id)
        if let existing = references[key] {
            if case .found(let resource) = existing { return resource }
            return nil
        }
        guard let relationship = relationship(id, owner: owner), !relationship.isExternal,
              let part = package.parts[PackURI.resolve(target: relationship.target, relativeTo: owner.uri.baseURI)] else {
            references[key] = .missing
            return nil
        }
        let identity = ObjectIdentifier(part)
        let resource: Resource
        if let existing = media[identity] { resource = existing }
        else { resource = Resource(part.blob); media[identity] = resource }
        references[key] = .found(resource)
        return resource
    }
}
