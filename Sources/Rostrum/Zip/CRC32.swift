import Foundation

/// CRC-32 (ISO 3309 / ITU-T V.42, polynomial 0xEDB88320) as used by the zip format.
///
/// Implementation notes for the implementer:
/// - Build the 256-entry lookup table once (lazily, as a `static let`), plus the
///   derived slicing-by-8 tables that let `update` consume 8 bytes per step.
/// - Running value starts at 0xFFFF_FFFF and is xor-finalized with 0xFFFF_FFFF.
/// - `update` lets callers checksum streams incrementally: pass the return value
///   of one call as `crc` of the next. `update` takes and returns the *raw*
///   (pre-finalization) running value; `checksum` wraps init/update/finalize.
public enum CRC32 {
    /// The 256-entry lookup table for the reflected polynomial 0xEDB88320.
    private static let table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
            }
            table[i] = c
        }
        return table
    }()

    /// The checksum of `data`, complete with initialization and finalization.
    public static func checksum(_ data: Data) -> UInt32 {
        finalize(update(initialValue, with: data))
    }

    /// Slicing-by-8 tables: eight 256-entry tables laid out flat (2048 entries).
    /// Table 0 is `table`; table k advances table k-1 by one zero byte, so
    /// eight input bytes fold into the running value with eight lookups.
    /// Table k starts at flat offset `k * 256` (1792 = 7 * 256, and so on).
    private static let slicingTables: [UInt32] = {
        var tables = [UInt32](repeating: 0, count: 8 * 256)
        for i in 0..<256 {
            tables[i] = table[i]
        }
        for k in 1..<8 {
            for i in 0..<256 {
                let previous = tables[(k - 1) * 256 + i]
                tables[k * 256 + i] = (previous >> 8) ^ table[Int(previous & 0xFF)]
            }
        }
        return tables
    }()

    /// Feed `data` into a running checksum. Start with `CRC32.initialValue`,
    /// finish with `CRC32.finalize(_:)`.
    public static func update(_ crc: UInt32, with data: Data) -> UInt32 {
        var running = crc
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            slicingTables.withUnsafeBufferPointer { t in
                let count = buffer.count
                var offset = 0
                // Body: 8 bytes per step, read little-endian so the result is
                // identical on any host byte order.
                while count - offset >= 8 {
                    let word = UInt64(littleEndian: buffer.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
                    let lo = UInt32(truncatingIfNeeded: word) ^ running
                    let hi = UInt32(truncatingIfNeeded: word >> 32)
                    let low: UInt32 = t[1792 + Int(lo & 0xFF)] ^ t[1536 + Int((lo >> 8) & 0xFF)]
                        ^ t[1280 + Int((lo >> 16) & 0xFF)] ^ t[1024 + Int(lo >> 24)]
                    let high: UInt32 = t[768 + Int(hi & 0xFF)] ^ t[512 + Int((hi >> 8) & 0xFF)]
                        ^ t[256 + Int((hi >> 16) & 0xFF)] ^ t[Int(hi >> 24)]
                    running = low ^ high
                    offset += 8
                }
                // Tail: the remaining 0-7 bytes go through the byte-wise table.
                while offset < count {
                    running = t[Int((running ^ UInt32(buffer[offset])) & 0xFF)] ^ (running >> 8)
                    offset += 1
                }
            }
        }
        return running
    }

    /// Raw initial value of the running checksum (0xFFFF_FFFF).
    public static let initialValue: UInt32 = 0xFFFF_FFFF

    /// Convert a raw running value into the final checksum.
    public static func finalize(_ crc: UInt32) -> UInt32 {
        crc ^ 0xFFFF_FFFF
    }
}
