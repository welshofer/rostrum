import Foundation

/// Decoded paint for immutable, admitted style-template nodes in one table
/// render. The caller's template budget reserves storage for these entries.
/// Direct and uncached style nodes must fail `canReuse`; public reads stay live.
struct TableBorderPaintCache<Paint> {
    private struct Entry {
        // Retain identity's owner: an allocator must not reuse an address while
        // its decoded result is present, even if caller ownership changes.
        let owner: XML.Element
        let paint: Paint?
    }
    private var entries: [ObjectIdentifier: Entry] = [:]
    private let limit: Int

    init(limit: Int = 216) { self.limit = max(0, limit) }

    mutating func value(for line: XML.Element?, canReuse: (XML.Element) -> Bool,
                        decode: (XML.Element) -> Paint?) -> Paint? {
        guard let line else { return nil }
        let identity = ObjectIdentifier(line)
        if let entry = entries[identity] { return entry.paint }
        let paint = decode(line)
        if entries.count < limit, canReuse(line) {
            // An entry with nil paint is distinct from an absent entry.
            entries[identity] = Entry(owner: line, paint: paint)
        }
        return paint
    }
}
