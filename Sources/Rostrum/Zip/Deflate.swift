import Foundation

/// Pure-Swift raw DEFLATE (RFC 1951) encoder — the counterpart to `Inflate`.
///
/// Emits a single fixed-Huffman block with greedy LZ77 matching. This is not
/// zlib-optimal (no dynamic Huffman, no lazy matching), but it is real
/// compression, correct, and — unlike a platform compressor — **deterministic**
/// across machines and OS versions, which the zip writer's byte-identical
/// guarantee depends on. Output is decodable by `Inflate`, `unzip`, and every
/// conforming DEFLATE reader.
public enum Deflate {
    static let minMatch = 3
    static let maxMatch = 258
    static let windowSize = 32768
    static let maxChain = 128          // bound the match search for speed

    // RFC 1951 §3.2.5 length codes (257…285) and distance codes (0…29).
    static let lengthBase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
                             35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    static let lengthExtra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                              3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    static let distBase = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
                           257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
                           8193, 12289, 16385, 24577]
    static let distExtra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
                            7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]

    /// length (3…258) → index into lengthBase, precomputed.
    static let lengthCodeIndex: [Int] = {
        var t = [Int](repeating: 0, count: maxMatch + 1)
        var idx = 0
        for len in minMatch...maxMatch {
            while idx < lengthBase.count - 1 && len >= lengthBase[idx + 1] { idx += 1 }
            t[len] = idx
        }
        return t
    }()

    public static func deflate(_ input: Data) -> Data {
        let bytes = [UInt8](input)
        let n = bytes.count
        var writer = BitWriter()
        // Single final fixed-Huffman block.
        writer.writeBits(1, 1)   // BFINAL = 1
        writer.writeBits(1, 2)   // BTYPE = 01 (fixed Huffman)

        // Hash chains over 3-byte prefixes.
        let hashBits = 15
        let hashSize = 1 << hashBits
        let hashMask = hashSize - 1
        var head = [Int](repeating: -1, count: hashSize)
        var prev = [Int](repeating: -1, count: max(1, n))

        func hash(_ i: Int) -> Int {
            (Int(bytes[i]) << 10 ^ Int(bytes[i + 1]) << 5 ^ Int(bytes[i + 2])) & hashMask
        }
        func insert(_ i: Int) {
            guard i + 2 < n else { return }
            let h = hash(i)
            prev[i] = head[h]
            head[h] = i
        }

        var pos = 0
        while pos < n {
            var bestLen = 0
            var bestDist = 0
            if pos + minMatch <= n, pos + 2 < n {
                let h = hash(pos)
                var cand = head[h]
                var chain = maxChain
                let maxLen = Swift.min(maxMatch, n - pos)
                let minPos = pos - windowSize
                while cand >= 0 && cand > minPos && chain > 0 {
                    // Quick reject: candidate must beat the current best at bestLen.
                    if bestLen == 0 || bytes[cand + bestLen] == bytes[pos + bestLen] {
                        var len = 0
                        while len < maxLen && bytes[cand + len] == bytes[pos + len] { len += 1 }
                        if len > bestLen {
                            bestLen = len
                            bestDist = pos - cand
                            if len >= maxLen { break }
                        }
                    }
                    cand = prev[cand]
                    chain -= 1
                }
            }

            if bestLen >= minMatch {
                emitMatch(length: bestLen, distance: bestDist, into: &writer)
                // Insert hashes for every covered position so later matches see them.
                let end = pos + bestLen
                while pos < end { insert(pos); pos += 1 }
            } else {
                emitLiteral(bytes[pos], into: &writer)
                insert(pos)
                pos += 1
            }
        }

        emitSymbol(256, into: &writer)   // end of block
        return writer.finish()
    }

    // MARK: - Fixed-Huffman symbol emission

    /// The fixed literal/length code for `sym` (0…287): (code, bit count),
    /// with `code` in MSB-first order per RFC 1951 §3.2.6.
    private static func fixedLitCode(_ sym: Int) -> (code: Int, bits: Int) {
        switch sym {
        case 0...143: return (0x30 + sym, 8)
        case 144...255: return (0x190 + (sym - 144), 9)
        case 256...279: return (sym - 256, 7)
        default: return (0xC0 + (sym - 280), 8)   // 280…287
        }
    }

    private static func emitSymbol(_ sym: Int, into writer: inout BitWriter) {
        let (code, bits) = fixedLitCode(sym)
        writer.writeHuffman(code, bits)
    }

    private static func emitLiteral(_ byte: UInt8, into writer: inout BitWriter) {
        emitSymbol(Int(byte), into: &writer)
    }

    private static func emitMatch(length: Int, distance: Int, into writer: inout BitWriter) {
        let li = lengthCodeIndex[length]
        emitSymbol(257 + li, into: &writer)                       // length code (Huffman)
        writer.writeBits(length - lengthBase[li], lengthExtra[li]) // length extra (LSB-first)

        var di = distBase.count - 1
        while di > 0 && distance < distBase[di] { di -= 1 }
        writer.writeHuffman(di, 5)                                // fixed 5-bit distance code
        writer.writeBits(distance - distBase[di], distExtra[di])  // distance extra
    }
}

/// A bit writer that packs into bytes LSB-first (RFC 1951 bit order).
struct BitWriter {
    private var out: [UInt8] = []
    private var bitBuffer: UInt32 = 0
    private var bitCount: Int = 0

    /// Write the low `count` bits of `value`, least-significant bit first.
    mutating func writeBits(_ value: Int, _ count: Int) {
        guard count > 0 else { return }
        bitBuffer |= UInt32(value & ((1 << count) - 1)) << bitCount
        bitCount += count
        while bitCount >= 8 {
            out.append(UInt8(bitBuffer & 0xFF))
            bitBuffer >>= 8
            bitCount -= 8
        }
    }

    /// Write a Huffman code of `count` bits, most-significant bit first (the
    /// codes themselves are MSB-first, but each bit still enters the byte
    /// stream LSB-first).
    mutating func writeHuffman(_ code: Int, _ count: Int) {
        var i = count - 1
        while i >= 0 {
            writeBits((code >> i) & 1, 1)
            i -= 1
        }
    }

    /// Flush any partial byte and return the stream.
    mutating func finish() -> Data {
        if bitCount > 0 {
            out.append(UInt8(bitBuffer & 0xFF))
            bitBuffer = 0
            bitCount = 0
        }
        return Data(out)
    }
}
