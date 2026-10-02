/// Operation-local ownership of a table's physical grid segments. Candidates
/// arrive in logical cell order; an eligible later edge replaces an earlier
/// merged edge even when its paint is nil. No XML is retained or modified.
struct TableBorderSegments<Paint> {
    enum Axis { case horizontal, vertical }
    struct Edge {
        let axis: Axis
        let boundary: Int
        let range: Range<Int>
        let paint: Paint?
    }
    struct Segment {
        let edge: Edge
        let range: Range<Int>
        let paint: Paint
    }
    private struct Key: Hashable {
        let vertical: Bool
        let boundary: Int
        let position: Int
    }
    private var edges: [Edge] = []
    private var owners: [Key: Int] = [:]

    mutating func append(axis: Axis, boundary: Int, range: Range<Int>, paint: Paint?) {
        guard let paint else {
            // Invisible edges still erase earlier merge candidates. The
            // common No Grid case retains no entries or candidate objects.
            if !owners.isEmpty {
                for position in range {
                    owners.removeValue(forKey: Key(vertical: axis == .vertical, boundary: boundary, position: position))
                }
            }
            return
        }
        let index = edges.count
        edges.append(Edge(axis: axis, boundary: boundary, range: range, paint: paint))
        for position in range {
            owners[Key(vertical: axis == .vertical, boundary: boundary, position: position)] = index
        }
    }

    /// Coalesce surviving portions of each original edge, preserving its dash
    /// origin. Work and storage are linear in physical cells, including merges.
    func resolved() -> [Segment] {
        var result: [Segment] = []
        for (index, edge) in edges.enumerated() {
            guard let paint = edge.paint else { continue }
            var start: Int?
            for position in edge.range {
                let key = Key(vertical: edge.axis == .vertical, boundary: edge.boundary, position: position)
                if owners[key] == index {
                    if start == nil { start = position }
                } else if let lower = start {
                    result.append(Segment(edge: edge, range: lower..<position, paint: paint))
                    start = nil
                }
            }
            if let start { result.append(Segment(edge: edge, range: start..<edge.range.upperBound, paint: paint)) }
        }
        return result
    }
}
