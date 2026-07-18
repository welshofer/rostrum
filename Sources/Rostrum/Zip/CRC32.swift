import Foundation

/// CRC-32 (ISO 3309 / ITU-T V.42, polynomial 0xEDB88320) as used by the zip format.
///
/// Implementation notes for the implementer:
/// - Build the 256-entry lookup table once (lazily, as a `static let`).
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

    /// Feed `data` into a running checksum. Start with `CRC32.initialValue`,
    /// finish with `CRC32.finalize(_:)`.
    public static func update(_ crc: UInt32, with data: Data) -> UInt32 {
        var running = crc
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            for byte in buffer {
                running = table[Int((running ^ UInt32(byte)) & 0xFF)] ^ (running >> 8)
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
