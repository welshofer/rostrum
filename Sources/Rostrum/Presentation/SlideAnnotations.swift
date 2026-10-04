import Foundation

/// Plans contain detached parts/relationship values. All throwing work happens
/// before Slides commits the plan, so refused lifecycle operations are atomic.
extension Slides {

    private static func isAnnotation(_ relationship: Relationship) -> Bool {
        relationship.type == RelType.notesSlide
            || relationship.type == ModernComments.commentsRelType
            || relationship.type == LegacyComments.commentsRelType
    }

    func copySlideAnnotations(from source: Part, to destination: PackURI, slideID: Int) throws
        -> (relationships: [Relationship], parts: [Part], legacyAuthors: LegacyAnnotationAuthorImport?) {
        var reserved = Set(package.parts.keys)
        var clones: [PackURI: Part] = [:]
        var parts: [Part] = []
        var legacyAuthors: LegacyAnnotationAuthorImport?
        var commentIDs: Set<String> = []
        if source.rels.items.contains(where: { $0.type == ModernComments.commentsRelType }) {
            for part in package.parts.values.sorted(by: { $0.uri.value < $1.uri.value })
                where part.contentType == ModernComments.commentsContentType {
                try ModernComments.visit(in: part.dom()) { element, namespace, localName in
                    if namespace == ModernComments.ns, localName == "cm" || localName == "reply",
                       let id = element[attribute: "id"] { commentIDs.insert(id.uppercased()) }
                }
            }
        }
        var relationships: [Relationship] = []
        for relationship in source.rels.items {
            guard !relationship.isExternal else {
                guard !Self.isAnnotation(relationship) else {
                    throw RostrumError.packageInvalid("slide annotation relationship must be internal")
                }
                relationships.append(relationship)
                continue
            }
            let originalURI = PackURI.resolve(target: relationship.target, relativeTo: source.uri.baseURI)
            var targetURI = originalURI
            if Self.isAnnotation(relationship) {
                if let clone = clones[originalURI] {
                    targetURI = clone.uri
                } else {
                    let original = try package.part(at: originalURI)
                    original.flushIfDirty()
                    var n = 1
                    let prefix: String
                    if relationship.type == RelType.notesSlide { prefix = "/ppt/notesSlides/notesSlide" }
                    else if relationship.type == ModernComments.commentsRelType { prefix = "/ppt/comments/modernComment_" }
                    else { prefix = "/ppt/comments/comment" }
                    while reserved.contains(PackURI("\(prefix)\(n).xml")) { n += 1 }
                    let uri = PackURI("\(prefix)\(n).xml")
                    reserved.insert(uri)
                    let clone = Part(uri: uri, contentType: original.contentType, blob: original.blob)
                    // Parse even notes/legacy comments during staging, without
                    // rebuilding their XML: preserve pristine unknown markup.
                    _ = try clone.dom()
                    clone.rels.setItems(original.rels.items.map { rel in
                        guard !rel.isExternal else { return rel }
                        let target = relationship.type == RelType.notesSlide && rel.type == RelType.slide
                            ? destination : PackURI.resolve(target: rel.target, relativeTo: original.uri.baseURI)
                        return Relationship(rId: rel.rId, type: rel.type,
                            target: uri.relativeReference(to: target), isExternal: false)
                    })
                    if relationship.type == ModernComments.commentsRelType {
                        try ModernComments.retargetCopy(clone, slideID: slideID, avoiding: &commentIDs)
                        clone.flushIfDirty()
                    }
                    if relationship.type == LegacyComments.commentsRelType {
                        if legacyAuthors == nil {
                            legacyAuthors = try LegacyAnnotationAuthorImport(source: package, dest: package,
                                                                            presentation: presentationPart)
                        }
                        try legacyAuthors?.remapAuthors(in: clone)
                        clone.flushIfDirty()
                    }
                    clones[originalURI] = clone
                    parts.append(clone)
                    targetURI = uri
                }
            }
            relationships.append(Relationship(rId: relationship.rId, type: relationship.type,
                target: destination.relativeReference(to: targetURI), isExternal: false))
        }
        return (relationships, parts, legacyAuthors)
    }

    func annotationRemovalPlan(for slide: Part) throws
        -> (removed: [PackURI], retained: [(Part, [Relationship])]) {
        var removed: [PackURI] = []
        var retained: [(Part, [Relationship])] = []
        let targets = Set(slide.rels.items.filter { Self.isAnnotation($0) && !$0.isExternal }.map {
            PackURI.resolve(target: $0.target, relativeTo: slide.uri.baseURI)
        })
        for uri in targets.sorted(by: { $0.value < $1.value }) {
            let annotation = try package.part(at: uri)
            let incoming = package.parts.values.filter { part in
                part.uri != slide.uri && part.uri != uri && part.rels.items.contains {
                    !$0.isExternal && PackURI.resolve(target: $0.target, relativeTo: part.uri.baseURI) == uri
                }
            }.sorted(by: { $0.uri.value < $1.uri.value })
            if incoming.isEmpty {
                removed.append(uri)
            } else {
                // Older decks can share notes. Keep the part and move its
                // backlink to a remaining owner instead of leaving it dangling.
                let survivor = incoming.first { $0.contentType == ContentType.slide }
                let rels = annotation.rels.items.compactMap { rel -> Relationship? in
                    guard !rel.isExternal, rel.type == RelType.slide,
                          PackURI.resolve(target: rel.target, relativeTo: uri.baseURI) == slide.uri
                    else { return rel }
                    guard let survivor else { return nil }
                    return Relationship(rId: rel.rId, type: rel.type,
                        target: uri.relativeReference(to: survivor.uri), isExternal: false)
                }
                retained.append((annotation, rels))
            }
        }
        return (removed, retained)
    }
}
