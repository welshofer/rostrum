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
    public private(set) var items: [Relationship]

    /// The bytes this collection was parsed from, and the items they encoded.
    /// An untouched `.rels` part re-emits verbatim — the same pristine-blob
    /// guarantee `Part` gives content parts, since relationship parts are
    /// parts too and a foreign package writes them with its own attribute
    /// order, spacing and declaration.
    ///
    /// Comparing items rather than latching a dirty flag means a change that
    /// is later undone (add a relationship, remove it again) still re-emits
    /// the original bytes.
    private var pristine: Data?
    private var pristineItems: [Relationship]?

    static let namespace = "http://schemas.openxmlformats.org/package/2006/relationships"

    public init() {
        items = []
    }

    /// Take on a parsed collection wholesale — its items **and** the bytes
    /// they came from. The package reader uses this; `setItems` deliberately
    /// does not, because its caller (slide duplication) copies items onto a
    /// different part, whose `.rels` must be written fresh.
    func adopt(_ parsed: Relationships) {
        items = parsed.items
        pristine = parsed.pristine
        pristineItems = parsed.pristineItems
    }

    public var isEmpty: Bool { items.isEmpty }

    /// Should `serialize()` write a `.rels` entry for this collection?
    ///
    /// The one definition of that question. It was spelled out at four sites —
    /// two deciding what to write and two deciding which carried entries would
    /// collide with it — and those four had to agree exactly or a carried entry
    /// gets wrongly kept (two members, one name) or wrongly dropped (silent
    /// loss). Four copies of a rule is how every previous defect in this area
    /// started; one definition cannot drift.
    var isWritten: Bool { !isEmpty || arrivedAsFile }

    /// Did this collection come from a `.rels` part that was in the file?
    ///
    /// Distinct from `!isEmpty`: a `<Relationships/>` with no children is legal
    /// OPC and several producers emit it. Writing is gated on this rather than
    /// on emptiness, so an arrived-empty stream is re-emitted while a freshly
    /// created part with no relationships still gets no `.rels` entry.
    var arrivedAsFile: Bool { pristine != nil }

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

    /// Move an existing relationship to the front of the list, keeping its rId
    /// and every other relationship's relative order.
    ///
    /// Order is not meaningful to OPC itself, but several PresentationML
    /// lookups take "the first relationship of this type" to mean the primary
    /// one — `Presentation.theme` resolves through the first `slideMaster`
    /// rel, for instance. Adopting a template has to make its master primary,
    /// and that is what this is for.
    func moveToFront(rId: String) {
        guard let index = items.firstIndex(where: { $0.rId == rId }), index != 0 else { return }
        let item = items.remove(at: index)
        items.insert(item, at: 0)
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
        rels.pristineItems = rels.items
        return rels
    }

    /// The original bytes when the relationships still match what was parsed;
    /// otherwise serialized in insertion order (stable, and matches how
    /// Office writes them).
    public func serialized() -> Data {
        if let pristine, let pristineItems, items == pristineItems { return pristine }
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
