import Foundation

/// Pure-Swift raw DEFLATE (RFC 1951) decoder — no zlib/gzip wrapper, which is
/// exactly what zip entries contain.
///
/// Implementation notes for the implementer:
/// - Handle all three block types: stored (BTYPE=00), fixed Huffman (01),
///   dynamic Huffman (10). BTYPE=11 → throw `RostrumError.deflateCorrupt`.
/// - Model the canonical-Huffman decode tables the way puff.c does (count/symbol
///   arrays per code length); no need for anything fancier.
/// - Length/distance extra-bit tables per RFC 1951 §3.2.5; window is the output
///   buffer itself (distances may reference up to 32 KiB back; a distance past
///   the start of output → throw).
/// - Bits are read LSB-first within bytes; Huffman codes MSB-first per spec.
/// - `expectedOutputSize`, when provided (zip central directory knows it), should
///   be used to reserve capacity — and exceeding it means corruption.
/// - Throw `RostrumError.deflateCorrupt` with a precise message for every
///   malformed condition (oversubscribed code lengths, incomplete stream, …).
public enum Inflate {
    /// Decode a raw DEFLATE stream.
    public static func inflate(_ input: Data, expectedOutputSize: Int? = nil) throws -> Data {
        var decoder = InflateDecoder(input: [UInt8](input), expectedOutputSize: expectedOutputSize)
        return try decoder.run()
    }
}

/// Canonical Huffman decode table, modeled after puff.c: `count[len]` is the
/// number of codes of each bit length (1...15), `symbol` lists the symbols in
/// canonical order (sorted by code length, then by symbol value).
private struct HuffmanTable {
    let count: [Int]
    let symbol: [Int]
    /// Leftover code space after construction: 0 means the code is complete,
    /// > 0 means it is incomplete. Oversubscription throws at construction.
    let left: Int

    init(lengths: [Int]) throws {
        var count = [Int](repeating: 0, count: 16)
        for len in lengths {
            count[len] += 1
        }
        var left = 1
        for len in 1...15 {
            left <<= 1
            left -= count[len]
            if left < 0 {
                throw RostrumError.deflateCorrupt("oversubscribed Huffman code lengths")
            }
        }
        // Offsets into the symbol table for each code length.
        var offs = [Int](repeating: 0, count: 16)
        for len in 1..<15 {
            offs[len + 1] = offs[len] + count[len]
        }
        var symbol = [Int](repeating: 0, count: lengths.count)
        for (sym, len) in lengths.enumerated() where len != 0 {
            symbol[offs[len]] = sym
            offs[len] += 1
        }
        self.count = count
        self.symbol = symbol
        self.left = left
    }

    /// True when the code contains at most one symbol (all lengths 0 or 1),
    /// the only case in which an incomplete code is permitted.
    var hasAtMostOneCode: Bool {
        symbol.count == count[0] + count[1]
    }
}

private struct InflateDecoder {
    let input: [UInt8]
    let expectedOutputSize: Int?
    var pos = 0
    var bitBuffer: UInt32 = 0
    var bitCount = 0
    var output: [UInt8] = []

    init(input: [UInt8], expectedOutputSize: Int?) {
        self.input = input
        self.expectedOutputSize = expectedOutputSize
        if let size = expectedOutputSize, size > 0 {
            // The declared size comes straight from the archive being read —
            // attacker-controlled for untrusted files — so cap the up-front
            // reservation: a few-hundred-byte crafted zip must not force a
            // multi-gigabyte allocation. Larger honest outputs grow amortized,
            // and `reserveOutput` still rejects overruns of the declared size.
            output.reserveCapacity(Swift.min(size, 1 << 20))
        }
    }

    // MARK: - Bit reading (LSB-first within bytes)

    mutating func bits(_ n: Int) throws -> Int {
        while bitCount < n {
            guard pos < input.count else {
                throw RostrumError.deflateCorrupt("unexpected end of stream while reading bits")
            }
            bitBuffer |= UInt32(input[pos]) << bitCount
            pos += 1
            bitCount += 8
        }
        let value = Int(bitBuffer & UInt32((1 << n) - 1))
        bitBuffer >>= UInt32(n)
        bitCount -= n
        return value
    }

    /// Decode one symbol, reading Huffman code bits MSB-first (puff.c decode()).
    mutating func decode(_ table: HuffmanTable) throws -> Int {
        var code = 0
        var first = 0
        var index = 0
        for len in 1...15 {
            code |= try bits(1)
            let count = table.count[len]
            if code - count < first {
                return table.symbol[index + (code - first)]
            }
            index += count
            first += count
            first <<= 1
            code <<= 1
        }
        throw RostrumError.deflateCorrupt("invalid Huffman code (ran out of codes)")
    }

    // MARK: - Output

    /// Reject a write that WOULD pass the declared size, before making it.
    ///
    /// Checking after the append leaves the decoder holding up to 65535 bytes
    /// (a stored block) or 258 bytes (a match copy) it has already been told it
    /// may not produce. The overshoot is small and one entry at a time, but the
    /// read budget's contract says an entry cannot produce more than it
    /// declared, and a bound that is only observed after the fact does not say
    /// that.
    ///
    /// `count` is bounded, not trusted: on the stored-block path it IS a file
    /// field, but a 16-bit one (`len` <= 65535), and on the match path it is a
    /// table lookup <= 258. `output.count` is bounded by what has already been
    /// appended. So the sum cannot overflow — but the reason is the widths, not
    /// the provenance.
    mutating func reserveOutput(_ count: Int) throws {
        if let expected = expectedOutputSize, output.count + count > expected {
            throw RostrumError.deflateCorrupt(
                "output exceeds expected size \(expected)")
        }
    }

    // MARK: - Blocks

    mutating func run() throws -> Data {
        var isFinal = false
        repeat {
            isFinal = try bits(1) == 1
            let blockType = try bits(2)
            switch blockType {
            case 0:
                try storedBlock()
            case 1:
                try codes(literals: Self.fixedTables.0, distances: Self.fixedTables.1)
            case 2:
                let (literals, distances) = try dynamicTables()
                try codes(literals: literals, distances: distances)
            default:
                throw RostrumError.deflateCorrupt("invalid block type 3 (BTYPE=11)")
            }
        } while !isFinal
        return Data(output)
    }

    mutating func storedBlock() throws {
        // Discard bits up to the next byte boundary.
        bitBuffer = 0
        bitCount = 0
        guard pos + 4 <= input.count else {
            throw RostrumError.deflateCorrupt("truncated stored block header")
        }
        let len = Int(input[pos]) | Int(input[pos + 1]) << 8
        let nlen = Int(input[pos + 2]) | Int(input[pos + 3]) << 8
        pos += 4
        guard len == (~nlen & 0xFFFF) else {
            throw RostrumError.deflateCorrupt("stored block LEN/NLEN mismatch")
        }
        guard pos + len <= input.count else {
            throw RostrumError.deflateCorrupt("truncated stored block data")
        }
        try reserveOutput(len)
        output.append(contentsOf: input[pos..<pos + len])
        pos += len
    }

    /// Read the dynamic-block header and build its two Huffman tables (RFC 1951 §3.2.7).
    mutating func dynamicTables() throws -> (HuffmanTable, HuffmanTable) {
        let hlit = try bits(5) + 257
        let hdist = try bits(5) + 1
        let hclen = try bits(4) + 4
        guard hlit <= 286, hdist <= 30 else {
            throw RostrumError.deflateCorrupt("too many literal/length or distance codes")
        }

        // Code lengths for the code-length alphabet, in its permuted order.
        let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
        var clLengths = [Int](repeating: 0, count: 19)
        for i in 0..<hclen {
            clLengths[order[i]] = try bits(3)
        }
        let clTable = try HuffmanTable(lengths: clLengths)
        guard clTable.left == 0 else {
            throw RostrumError.deflateCorrupt("incomplete code-length Huffman code")
        }

        // Decode literal/length + distance code lengths as one sequence.
        var lengths: [Int] = []
        lengths.reserveCapacity(hlit + hdist)
        while lengths.count < hlit + hdist {
            let sym = try decode(clTable)
            if sym < 16 {
                lengths.append(sym)
            } else {
                let value: Int
                let repeatCount: Int
                switch sym {
                case 16:
                    guard let last = lengths.last else {
                        throw RostrumError.deflateCorrupt("length-repeat code with no previous length")
                    }
                    value = last
                    repeatCount = 3 + (try bits(2))
                case 17:
                    value = 0
                    repeatCount = 3 + (try bits(3))
                default: // 18
                    value = 0
                    repeatCount = 11 + (try bits(7))
                }
                guard lengths.count + repeatCount <= hlit + hdist else {
                    throw RostrumError.deflateCorrupt("code-length repeat overflows the length table")
                }
                lengths.append(contentsOf: repeatElement(value, count: repeatCount))
            }
        }

        guard lengths[256] != 0 else {
            throw RostrumError.deflateCorrupt("dynamic block has no end-of-block code")
        }

        let literals = try HuffmanTable(lengths: Array(lengths[0..<hlit]))
        if literals.left > 0 && !literals.hasAtMostOneCode {
            throw RostrumError.deflateCorrupt("incomplete literal/length Huffman code")
        }
        let distances = try HuffmanTable(lengths: Array(lengths[hlit...]))
        if distances.left > 0 && !distances.hasAtMostOneCode {
            throw RostrumError.deflateCorrupt("incomplete distance Huffman code")
        }
        return (literals, distances)
    }

    // MARK: - Length/distance tables (RFC 1951 §3.2.5)

    static let lengthBase = [
        3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
        35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
    ]
    static let lengthExtra = [
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
        3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
    ]
    static let distanceBase = [
        1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
        257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
    ]
    static let distanceExtra = [
        0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
        7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
    ]

    /// Fixed literal/length and distance tables (RFC 1951 §3.2.6), built once.
    static let fixedTables: (HuffmanTable, HuffmanTable) = {
        var litLengths = [Int](repeating: 8, count: 288)
        for i in 144...255 { litLengths[i] = 9 }
        for i in 256...279 { litLengths[i] = 7 }
        // These are well-formed by construction; failure is impossible.
        let literals = try! HuffmanTable(lengths: litLengths)
        let distances = try! HuffmanTable(lengths: [Int](repeating: 5, count: 30))
        return (literals, distances)
    }()

    /// Decode literals and length/distance pairs until end-of-block (symbol 256).
    mutating func codes(literals: HuffmanTable, distances: HuffmanTable) throws {
        while true {
            let sym = try decode(literals)
            if sym < 256 {
                try reserveOutput(1)
                output.append(UInt8(sym))
            } else if sym == 256 {
                return
            } else {
                guard sym <= 285 else {
                    throw RostrumError.deflateCorrupt("invalid literal/length symbol \(sym)")
                }
                let lenIndex = sym - 257
                let length = Self.lengthBase[lenIndex] + (try bits(Self.lengthExtra[lenIndex]))

                let distSym = try decode(distances)
                guard distSym <= 29 else {
                    throw RostrumError.deflateCorrupt("invalid distance symbol \(distSym)")
                }
                let distance = Self.distanceBase[distSym] + (try bits(Self.distanceExtra[distSym]))
                guard distance <= output.count else {
                    throw RostrumError.deflateCorrupt(
                        "distance \(distance) reaches before the start of output (\(output.count) bytes so far)")
                }
                try reserveOutput(length)
                var src = output.count - distance
                for _ in 0..<length {
                    output.append(output[src])
                    src += 1
                }
            }
        }
    }
}
