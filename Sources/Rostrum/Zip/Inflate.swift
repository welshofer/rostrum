import Foundation

/// Pure-Swift raw DEFLATE (RFC 1951) decoder — no zlib/gzip wrapper, which is
/// exactly what zip entries contain.
///
/// Implementation notes for the implementer:
/// - Handle all three block types: stored (BTYPE=00), fixed Huffman (01),
///   dynamic Huffman (10). BTYPE=11 → throw `RostrumError.deflateCorrupt`.
/// - Canonical-Huffman tables keep puff.c's count/symbol arrays for validation
///   and for codes longer than `HuffmanTable.fastBits`; shorter codes (nearly
///   all of them) resolve through one lookup in a bit-reversed prefix table.
/// - Length/distance extra-bit tables per RFC 1951 §3.2.5; window is the output
///   buffer itself (distances may reference up to 32 KiB back; a distance past
///   the start of output → throw).
/// - Bits are read LSB-first within bytes; Huffman codes MSB-first per spec.
/// - `expectedOutputSize`, when provided (zip central directory knows it), should
///   be used to reserve capacity — and exceeding it means corruption.
/// - Throw `RostrumError.deflateCorrupt` with a precise message for every
///   malformed condition (oversubscribed code lengths, incomplete stream, …).
public enum Inflate {
    /// The output ceiling when no `expectedOutputSize` is given. DEFLATE
    /// expands by up to ~1032:1, so a bare `inflate(_:)` call with no declared
    /// size would otherwise let a few-KB crafted stream produce unbounded
    /// output. Callers with genuinely larger streams know the size and pass
    /// `expectedOutputSize` (as `ZipReader` always does).
    public static let defaultOutputCeiling = 1 << 30

    /// Decode a raw DEFLATE stream.
    public static func inflate(_ input: Data, expectedOutputSize: Int? = nil) throws -> Data {
        try input.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var decoder = InflateDecoder(input: bytes, expectedOutputSize: expectedOutputSize)
            return try decoder.run()
        }
    }

    /// Validate a raw DEFLATE stream and compute its decoded byte count and
    /// CRC-32 using a fixed ~64 KiB sliding window — without allocating or
    /// retaining the full uncompressed output buffer.
    public static func verify(
        _ input: Data,
        expectedOutputSize: Int? = nil
    ) throws -> (size: Int, crc32: UInt32) {
        try input.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var verifier = InflateVerifier(input: bytes, expectedOutputSize: expectedOutputSize)
            return try verifier.run()
        }
    }
}

/// Canonical Huffman decode table, modeled after puff.c: `count[len]` is the
/// number of codes of each bit length (1...15), `symbol` lists the symbols in
/// canonical order (sorted by code length, then by symbol value).
private struct HuffmanTable: Sendable {
    let count: [Int]
    let symbol: [Int]
    /// Leftover code space after construction: 0 means the code is complete,
    /// > 0 means it is incomplete. Oversubscription throws at construction.
    let left: Int
    /// Direct lookup for codes of at most `fastBits` bits, indexed by the next
    /// `fastBits` stream bits (LSB-first, i.e. the code bit-reversed). An entry
    /// is `symbol << 4 | length`; 0 means "longer code or no code — decode
    /// bit by bit".
    let fast: [UInt16]
    static let fastBits = 10

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

        // Assign canonical codes in the same order `decode` walks them and
        // replicate each short code across every index sharing its prefix.
        var fast = [UInt16](repeating: 0, count: 1 << Self.fastBits)
        var code = 0
        var index = 0
        for len in 1...Self.fastBits {
            for _ in 0..<count[len] {
                var reversed = 0
                for bit in 0..<len where code & (1 << bit) != 0 {
                    reversed |= 1 << (len - 1 - bit)
                }
                let entry = UInt16(symbol[index] << 4 | len)
                var slot = reversed
                while slot < fast.count {
                    fast[slot] = entry
                    slot += 1 << len
                }
                code += 1
                index += 1
            }
            code <<= 1
        }
        self.fast = fast
    }

    /// True when the code contains at most one symbol (all lengths 0 or 1),
    /// the only case in which an incomplete code is permitted.
    var hasAtMostOneCode: Bool {
        symbol.count == count[0] + count[1]
    }
}

/// Shared bit reader, block-header parser, and RFC 1951 tables used by both
/// `InflateDecoder` and `InflateVerifier` so validation rules never drift.
private struct BitStream {
    let input: UnsafeBufferPointer<UInt8>
    var pos = 0
    var bitBuffer: UInt64 = 0
    var bitCount = 0

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

    /// Top up the bit buffer to at least 56 bits, or to the end of input.
    @inline(__always)
    mutating func refill() {
        while bitCount <= 56, pos < input.count {
            bitBuffer |= UInt64(input[pos]) << UInt64(bitCount)
            pos += 1
            bitCount += 8
        }
    }

    /// Read `n` (0...16) bits.
    @inline(__always)
    mutating func bits(_ n: Int) throws -> Int {
        if bitCount < n {
            refill()
            guard bitCount >= n else {
                throw RostrumError.deflateCorrupt("unexpected end of stream while reading bits")
            }
        }
        let value = Int(bitBuffer & ((1 << UInt64(n)) - 1))
        bitBuffer >>= UInt64(n)
        bitCount -= n
        return value
    }

    /// Decode one symbol. Codes of at most `HuffmanTable.fastBits` bits take
    /// one table lookup; anything else — longer codes, unassigned prefixes and
    /// the last few bits of the stream — falls back to `decodeSlowly`, which
    /// also owns every error.
    @inline(__always)
    mutating func decode(_ table: HuffmanTable) throws -> Int {
        if bitCount < HuffmanTable.fastBits { refill() }
        let entry = Int(table.fast[Int(bitBuffer & UInt64((1 << HuffmanTable.fastBits) - 1))])
        let length = entry & 15
        if length != 0, length <= bitCount {
            bitBuffer >>= UInt64(length)
            bitCount -= length
            return entry >> 4
        }
        return try decodeSlowly(table)
    }

    /// Decode one symbol, reading Huffman code bits MSB-first (puff.c decode()).
    mutating func decodeSlowly(_ table: HuffmanTable) throws -> Int {
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

    /// Parse a stored block header, returning the payload's `(offset, length)`
    /// in `input` and advancing `pos` past the stored bytes.
    mutating func storedBlockSpan() throws -> (offset: Int, length: Int) {
        // Discard bits up to the next byte boundary, and hand back the whole
        // bytes the bit buffer read ahead: stored data is addressed by `pos`.
        pos -= bitCount / 8
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
        let start = pos
        pos += len
        return (start, len)
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
}

private struct InflateDecoder {
    var stream: BitStream
    let expectedOutputSize: Int?
    let ceiling: Int
    /// The output, a manually grown buffer: `run()` hands it to `Data`
    /// without a copy, and literals are stored without `Array.append`'s
    /// uniqueness and capacity checks. Owned by `run()`, which frees it on error.
    var output: UnsafeMutablePointer<UInt8>
    var outputCount = 0
    var outputCapacity: Int
    var fastLiteralLimit: Int

    init(input: UnsafeBufferPointer<UInt8>, expectedOutputSize: Int?) {
        self.stream = BitStream(input: input)
        self.expectedOutputSize = expectedOutputSize
        self.ceiling = Swift.max(0, expectedOutputSize ?? Inflate.defaultOutputCeiling)
        // The declared size comes straight from the archive being read —
        // attacker-controlled for untrusted files — so cap the up-front
        // reservation: a few-hundred-byte crafted zip must not force a
        // multi-gigabyte allocation. Larger honest outputs grow amortized,
        // and `reserveOutput` still rejects overruns of the declared size.
        outputCapacity = Swift.max(64, Swift.min(expectedOutputSize ?? 0, 1 << 20))
        fastLiteralLimit = Swift.min(outputCapacity, ceiling)
        output = UnsafeMutablePointer<UInt8>.allocate(capacity: outputCapacity)
    }

    /// Reject a write that WOULD pass the declared size, before making it.
    mutating func reserveOutput(_ count: Int) throws {
        if let expected = expectedOutputSize {
            if outputCount + count > expected {
                throw RostrumError.deflateCorrupt(
                    "output exceeds expected size \(expected)")
            }
        } else if outputCount + count > Inflate.defaultOutputCeiling {
            throw RostrumError.deflateCorrupt(
                "output exceeds \(Inflate.defaultOutputCeiling) bytes with no declared size; "
                    + "pass expectedOutputSize to raise the ceiling")
        }
        let needed = outputCount + count
        if needed > outputCapacity {
            // Never reserve past what the stream may legally produce.
            let capacity = Swift.max(needed, Swift.min(outputCapacity * 2, Swift.max(ceiling, needed)))
            let grown = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
            grown.update(from: output, count: outputCount)
            output.deallocate()
            output = grown
            outputCapacity = capacity
            fastLiteralLimit = Swift.min(outputCapacity, ceiling)
        }
    }

    mutating func run() throws -> Data {
        do {
            try decodeBlocks()
        } catch {
            output.deallocate()
            throw error
        }
        let buffer = output
        return Data(bytesNoCopy: buffer, count: outputCount, deallocator: .custom { _, _ in buffer.deallocate() })
    }

    private mutating func decodeBlocks() throws {
        var isFinal = false
        repeat {
            isFinal = try stream.bits(1) == 1
            let blockType = try stream.bits(2)
            switch blockType {
            case 0:
                let (offset, len) = try stream.storedBlockSpan()
                try reserveOutput(len)
                if len > 0, let base = stream.input.baseAddress {
                    (output + outputCount).update(from: base + offset, count: len)
                }
                outputCount += len
            case 1:
                try codes(literals: BitStream.fixedTables.0, distances: BitStream.fixedTables.1)
            case 2:
                let (literals, distances) = try stream.dynamicTables()
                try codes(literals: literals, distances: distances)
            default:
                throw RostrumError.deflateCorrupt("invalid block type 3 (BTYPE=11)")
            }
        } while !isFinal
    }

    /// Decode literals and length/distance pairs until end-of-block (symbol 256).
    mutating func codes(literals: HuffmanTable, distances: HuffmanTable) throws {
        while true {
            let sym = try stream.decode(literals)
            if sym < 256 {
                if outputCount == fastLiteralLimit { try reserveOutput(1) }
                output[outputCount] = UInt8(sym)
                outputCount += 1
            } else if sym == 256 {
                return
            } else {
                guard sym <= 285 else {
                    throw RostrumError.deflateCorrupt("invalid literal/length symbol \(sym)")
                }
                let lenIndex = sym - 257
                let length = BitStream.lengthBase[lenIndex] + (try stream.bits(BitStream.lengthExtra[lenIndex]))

                let distSym = try stream.decode(distances)
                guard distSym <= 29 else {
                    throw RostrumError.deflateCorrupt("invalid distance symbol \(distSym)")
                }
                let distance = BitStream.distanceBase[distSym] + (try stream.bits(BitStream.distanceExtra[distSym]))
                guard distance <= outputCount else {
                    throw RostrumError.deflateCorrupt(
                        "distance \(distance) reaches before the start of output (\(outputCount) bytes so far)")
                }
                try reserveOutput(length)
                // A non-overlapping match (the common case) collapses to one
                // memcpy. An overlapping match MUST copy sequentially — byte i
                // reads a byte this same match wrote.
                let destination = output + outputCount
                let source = destination - distance
                if distance >= length {
                    destination.update(from: source, count: length)
                } else {
                    for i in 0..<length { destination[i] = source[i] }
                }
                outputCount += length
            }
        }
    }
}

/// Sliding-window DEFLATE validator + CRC-32 calculator.
///
/// Holds a fixed `65536 + 258` byte linear window: flushing at `windowFill >= 65536`
/// guarantees `flushCount = windowFill - 32768 >= 32768`, so the 32 KiB history
/// copy `window[flushCount..<windowFill] -> window[0..<32768]` is strictly
/// non-overlapping, and every legal back-reference (`distance <= 32768`) lies
/// contiguously behind `window + windowFill` with no modulo indexing.
private struct InflateVerifier {
    static let historySize = 32_768
    static let flushThreshold = 65_536
    static let windowCapacity = flushThreshold + 258

    var stream: BitStream
    let expectedOutputSize: Int?
    let window: UnsafeMutablePointer<UInt8>
    var windowFill = 0
    var totalEmitted = 0
    var crc: UInt32 = CRC32.initialValue

    init(input: UnsafeBufferPointer<UInt8>, expectedOutputSize: Int?) {
        self.stream = BitStream(input: input)
        self.expectedOutputSize = expectedOutputSize
        self.window = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.windowCapacity)
    }

    @inline(__always)
    mutating func checkAllowance(_ count: Int) throws {
        if let expected = expectedOutputSize {
            if totalEmitted + count > expected {
                throw RostrumError.deflateCorrupt(
                    "output exceeds expected size \(expected)")
            }
        } else if totalEmitted + count > Inflate.defaultOutputCeiling {
            throw RostrumError.deflateCorrupt(
                "output exceeds \(Inflate.defaultOutputCeiling) bytes with no declared size; "
                    + "pass expectedOutputSize to raise the ceiling")
        }
    }

    @inline(__always)
    mutating func flushAtThreshold() {
        // Precondition: `windowFill >= flushThreshold` (65536), so
        // `flushCount >= 32768` and `[0..<32768]` is disjoint from
        // `[flushCount..<flushCount + 32768]`.
        let flushCount = windowFill - Self.historySize
        crc = CRC32.update(crc, bytes: window, count: flushCount)
        window.update(from: window + flushCount, count: Self.historySize)
        windowFill = Self.historySize
    }

    mutating func run() throws -> (size: Int, crc32: UInt32) {
        defer { window.deallocate() }
        var isFinal = false
        repeat {
            isFinal = try stream.bits(1) == 1
            let blockType = try stream.bits(2)
            switch blockType {
            case 0:
                let (offset, len) = try stream.storedBlockSpan()
                try checkAllowance(len)
                if len > 0, let base = stream.input.baseAddress {
                    let src = base + offset
                    if windowFill + len <= Self.flushThreshold {
                        (window + windowFill).update(from: src, count: len)
                        windowFill += len
                    } else if len >= Self.historySize {
                        if windowFill > 0 {
                            crc = CRC32.update(crc, bytes: window, count: windowFill)
                        }
                        let directCRC = len - Self.historySize
                        if directCRC > 0 {
                            crc = CRC32.update(crc, bytes: src, count: directCRC)
                        }
                        window.update(from: src + directCRC, count: Self.historySize)
                        windowFill = Self.historySize
                    } else {
                        // `0 < len < 32768` and `windowFill + len > 65536`:
                        // `keep = 32768 - len < 32768`, and
                        // `flushCount = windowFill - keep = (windowFill + len) - 32768 > 32768 > keep`,
                        // so `[0..<keep]` and `[flushCount..<flushCount + keep]` are disjoint.
                        let keep = Self.historySize - len
                        let flushCount = windowFill - keep
                        crc = CRC32.update(crc, bytes: window, count: flushCount)
                        window.update(from: window + flushCount, count: keep)
                        (window + keep).update(from: src, count: len)
                        windowFill = Self.historySize
                    }
                }
                totalEmitted += len
            case 1:
                try codes(literals: BitStream.fixedTables.0, distances: BitStream.fixedTables.1)
            case 2:
                let (literals, distances) = try stream.dynamicTables()
                try codes(literals: literals, distances: distances)
            default:
                throw RostrumError.deflateCorrupt("invalid block type 3 (BTYPE=11)")
            }
        } while !isFinal

        if windowFill > 0 {
            crc = CRC32.update(crc, bytes: window, count: windowFill)
        }
        return (size: totalEmitted, crc32: CRC32.finalize(crc))
    }

    mutating func codes(literals: HuffmanTable, distances: HuffmanTable) throws {
        let ceiling = expectedOutputSize ?? Inflate.defaultOutputCeiling
        while true {
            let sym = try stream.decode(literals)
            if sym < 256 {
                if totalEmitted >= ceiling { try checkAllowance(1) }
                if windowFill >= Self.flushThreshold { flushAtThreshold() }
                window[windowFill] = UInt8(sym)
                windowFill += 1
                totalEmitted += 1
            } else if sym == 256 {
                return
            } else {
                guard sym <= 285 else {
                    throw RostrumError.deflateCorrupt("invalid literal/length symbol \(sym)")
                }
                let lenIndex = sym - 257
                let length = BitStream.lengthBase[lenIndex] + (try stream.bits(BitStream.lengthExtra[lenIndex]))

                let distSym = try stream.decode(distances)
                guard distSym <= 29 else {
                    throw RostrumError.deflateCorrupt("invalid distance symbol \(distSym)")
                }
                let distance = BitStream.distanceBase[distSym] + (try stream.bits(BitStream.distanceExtra[distSym]))
                guard distance <= totalEmitted else {
                    throw RostrumError.deflateCorrupt(
                        "distance \(distance) reaches before the start of output (\(totalEmitted) bytes so far)")
                }
                try checkAllowance(length)
                if windowFill >= Self.flushThreshold { flushAtThreshold() }
                let destination = window + windowFill
                let source = destination - distance
                if distance >= length {
                    destination.update(from: source, count: length)
                } else {
                    for i in 0..<length { destination[i] = source[i] }
                }
                windowFill += length
                totalEmitted += length
            }
        }
    }
}
