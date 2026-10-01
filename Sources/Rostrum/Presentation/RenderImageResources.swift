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

    private var encodedBytes = 0
    private let encodedByteLimit = 4 * 1024 * 1024

    func reset() { references.removeAll(); media.removeAll(); encodedBytes = 0 }

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
        guard let relationship = owner.rels.relationship(withId: id), !relationship.isExternal,
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
