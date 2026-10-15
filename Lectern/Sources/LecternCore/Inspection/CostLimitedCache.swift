/// A synchronous LRU cache bounded by both entry count and caller-supplied cost.
/// The owner provides isolation (the bitmap host uses MainActor). Costs account
/// for retained resources; they are not a measurement of total process memory.
public final class CostLimitedCache<Key: Hashable, Value> {
    public let capacity: Int
    public let costLimit: Int
    public private(set) var totalCost = 0
    public var count: Int { entries.count }

    private final class Entry {
        let key: Key
        let value: Value
        let cost: Int
        weak var previous: Entry?
        var next: Entry?
        init(key: Key, value: Value, cost: Int) {
            self.key = key; self.value = value; self.cost = cost
        }
    }
    private var entries: [Key: Entry] = [:]
    private var oldest: Entry?
    private var newest: Entry?

    public init(capacity: Int, costLimit: Int) {
        precondition(capacity >= 0 && costLimit >= 0)
        self.capacity = capacity
        self.costLimit = costLimit
    }

    public func value(forKey key: Key) -> Value? {
        guard let entry = entries[key] else { return nil }
        unlink(entry)
        append(entry)
        return entry.value
    }

    /// Oversized/invalid entries are not admitted and leave existing entries
    /// intact. Evict before adding so even Int.max costs cannot overflow.
    @discardableResult
    public func insert(_ value: Value, forKey key: Key, cost: Int) -> Bool {
        guard capacity > 0, cost >= 0, cost <= costLimit else { return false }
        if let previous = entries.removeValue(forKey: key) {
            unlink(previous)
            totalCost -= previous.cost
        }
        while count >= capacity || totalCost > costLimit - cost, let entry = oldest {
            unlink(entry)
            entries.removeValue(forKey: entry.key)
            totalCost -= entry.cost
        }
        let entry = Entry(key: key, value: value, cost: cost)
        entries[key] = entry
        append(entry)
        totalCost += cost
        return true
    }

    private func unlink(_ entry: Entry) {
        if let previous = entry.previous { previous.next = entry.next }
        else { oldest = entry.next }
        if let next = entry.next { next.previous = entry.previous }
        else { newest = entry.previous }
        entry.previous = nil
        entry.next = nil
    }

    private func append(_ entry: Entry) {
        entry.previous = newest
        newest?.next = entry
        if oldest == nil { oldest = entry }
        newest = entry
    }
}
