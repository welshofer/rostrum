import Foundation

/// One arc in the package's relationship graph.
public struct Relationship: Sendable, Equatable {
    public let rId: String
    /// Relationship type URI (see `RelType`).
    public let type: String
    /// Target as written in the XML — relative to the source part's base URI,
    /// or an absolute URL for external targets.
    public let target: String
    public let isExternal: Bool
}

/// The relationships of one source (the package root or a part) — the contents
/// of a `.rels` part.
///
/// Reference semantics on purpose: a part and the package hold onto the same
/// live collection while the object model mutates it.
public final class Relationships {
    public private(set) var items: [Relationship] {
        didSet { isDirty = true }
    }

    /// The bytes this collection was parsed from, kept so an untouched
    /// `.rels` part re-emits verbatim — the same pristine-blob guarantee
    /// `Part` gives content parts. Relationship parts are parts too, and a
    /// foreign package writes them with its own attribute order, spacing and
    /// declaration.
    private var pristine: Data?
    private var isDirty = false

    static let namespace = "http://schemas.openxmlformats.org/package/2006/relationships"

    public init() {
        items = []
        isDirty = false
    }

    public var isEmpty: Bool { items.isEmpty }

    public func relationship(withId rId: String) -> Relationship? {
        items.first { $0.rId == rId }
    }

    public func first(ofType type: String) -> Relationship? {
        items.first { $0.type == type }
    }

    public func all(ofType type: String) -> [Relationship] {
        items.filter { $0.type == type }
    }

    /// Add a relationship with the next free `rId N`, returning its rId.
    @discardableResult
    public func add(type: String, target: String, isExternal: Bool = false) -> String {
        var n = items.count + 1
        while relationship(withId: "rId\(n)") != nil { n += 1 }
        let rId = "rId\(n)"
        items.append(Relationship(rId: rId, type: type, target: target, isExternal: isExternal))
        return rId
    }

    /// Append a relationship with an explicit rId. Used by deck merge to
    /// preserve a copied part's rId tokens so its XML body never changes.
    func add(rId: String, type: String, target: String, isExternal: Bool = false) {
        items.append(Relationship(rId: rId, type: type, target: target, isExternal: isExternal))
    }

    public func remove(rId: String) {
        items.removeAll { $0.rId == rId }
    }

    /// Replace the collection's contents wholesale, preserving rIds exactly.
    /// Used by the package reader: rIds parsed from a file MUST survive
    /// untouched, because part XML references them by value (`r:id="rId5"`).
    func setItems(_ items: [Relationship]) {
        self.items = items
    }

    public static func parse(_ data: Data) throws -> Relationships {
        let root = try XML.parse(data)
        guard root.name == "Relationships" else {
            throw RostrumError.packageInvalid(".rels root is <\(root.name)>, expected <Relationships>")
        }
        let rels = Relationships()
        for child in root.children(named: "Relationship") {
            guard let rId = child[attribute: "Id"],
                  let type = child[attribute: "Type"],
                  let target = child[attribute: "Target"] else {
                throw RostrumError.packageInvalid("<Relationship> missing Id, Type or Target")
            }
            let external = child[attribute: "TargetMode"] == "External"
            rels.items.append(Relationship(rId: rId, type: type, target: target, isExternal: external))
        }
        rels.pristine = data
        rels.isDirty = false
        return rels
    }

    /// The original bytes when nothing was added or removed; otherwise
    /// serialized in insertion order (stable, and matches how Office writes
    /// them).
    public func serialized() -> Data {
        if !isDirty, let pristine { return pristine }
        return rebuilt()
    }

    private func rebuilt() -> Data {
        let root = XML.Element("Relationships", attributes: [("xmlns", Self.namespace)])
        for rel in items {
            var attrs = [("Id", rel.rId), ("Type", rel.type), ("Target", rel.target)]
            if rel.isExternal { attrs.append(("TargetMode", "External")) }
            root.appendElement(XML.Element("Relationship", attributes: attrs))
        }
        return XML.document(root)
    }
}
