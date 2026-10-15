import Foundation

/// Immutable preview markup with a process-local, prepared UTF-8 fingerprint.
/// Prepare alongside SVG generation, before handing records to the UI. Hashing
/// a cache/task key then costs constant time; equality still checks exact bytes.
/// The fingerprint is neither a persistent identifier nor proof of equality.
public struct PreviewContent: Hashable, Sendable {
    public let svg: String
    public let byteCount: Int
    private let fingerprint: Int

    public init(svg: String) { self.init(svg: svg, fingerprintOverride: nil) }

    // Internal collision injection for tests; production always hashes the bytes.
    init(svg: String, fingerprintOverride: Int?) {
        let span = PipelineTrace.begin("preview.identity")
        defer { span?.end() }
        var contiguous = svg
        var hasher = Hasher()
        byteCount = contiguous.withUTF8 { bytes in
            hasher.combine(bytes: UnsafeRawBufferPointer(bytes))
            return bytes.count
        }
        self.svg = contiguous
        fingerprint = fingerprintOverride ?? hasher.finalize()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fingerprint)
        hasher.combine(byteCount)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.fingerprint == rhs.fingerprint, lhs.byteCount == rhs.byteCount else { return false }
        // withUTF8 in init makes these native contiguous strings. Shared storage
        // is an immediate hit; independently regenerated SVGs get a byte check.
        if let equal = lhs.svg.utf8.withContiguousStorageIfAvailable({ left in
            rhs.svg.utf8.withContiguousStorageIfAvailable { right in
                if left.isEmpty || left.baseAddress == right.baseAddress { return true }
                return memcmp(left.baseAddress!, right.baseAddress!, left.count) == 0
            }
        }) ?? nil { return equal }
        return lhs.svg.utf8.elementsEqual(rhs.svg.utf8)
    }
}
