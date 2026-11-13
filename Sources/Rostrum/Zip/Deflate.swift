import Foundation

/// Pure-Swift raw DEFLATE (RFC 1951) encoder — the counterpart to `Inflate`.
///
/// LZ77 with hash chains and one-step lazy matching, emitted as blocks that
/// each use whichever of the fixed or a block-specific dynamic Huffman code is
/// smaller. Every choice (hash order, tie-breaks in code construction, block
/// boundaries) is a pure function of the input, so output is **deterministic**
/// across machines and OS versions — which the zip writer's byte-identical
/// guarantee depends on, and a platform compressor does not promise. Output is
/// decodable by `Inflate`, `unzip`, and every conforming DEFLATE reader.
public enum Deflate {
    static let minMatch = 3
    static let maxMatch = 258
    static let windowSize = 32768
    static let maxChain = 128          // bound the match search for speed
    /// A match at least this long is taken without checking the next position.
    static let lazyThreshold = 16
    /// With a match already this long, the lazy check searches a quarter of the chain.
    static let goodMatch = 8
    /// A match this long ends the search: a longer one would save almost nothing.
    static let niceMatch = 128
    /// Tokens per block. Each block gets its own Huffman code, so this bounds
    /// how far statistics from one region are applied to another.
    static let blockTokens = 1 << 16

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
        writer.reserve(n / 2 + 16)

        // Hash chains over 3-byte prefixes.
        // Small inputs get a smaller table: clearing 32,768 heads costs more
        // than compressing a relationships part.
        var hashBits = 9
        while hashBits < 15 && (1 << hashBits) < n { hashBits += 1 }
        let hashSize = 1 << hashBits
        let hashMask = hashSize - 1
        var head = [Int32](repeating: -1, count: hashSize)
        var prev = [Int32](repeating: -1, count: max(1, n))

        // One block's tokens: a literal is (byte, 0), a match is (length, distance).
        var tokenValues: [UInt16] = []
        var tokenDistances: [UInt16] = []
        tokenValues.reserveCapacity(Swift.min(n, blockTokens) + 1)
        tokenDistances.reserveCapacity(Swift.min(n, blockTokens) + 1)

        bytes.withUnsafeBufferPointer { bytes in
            head.withUnsafeMutableBufferPointer { head in
                prev.withUnsafeMutableBufferPointer { prev in
                    @inline(__always) func hash(_ i: Int) -> Int {
                        ((Int(bytes[i]) << 10 ^ Int(bytes[i + 1]) << 5 ^ Int(bytes[i + 2])) &* 0x9E3B) >> 1 & hashMask
                    }
                    @inline(__always) func insert(_ i: Int) {
                        guard i + 2 < n else { return }
                        let h = hash(i)
                        prev[i] = head[h]
                        head[h] = Int32(truncatingIfNeeded: i)
                    }
                    /// Longest match at `pos` that beats `floor` bytes.
                    @inline(__always) func longestMatch(_ pos: Int, floor: Int, chain maxSteps: Int) -> (length: Int, distance: Int) {
                        guard pos + 2 < n else { return (0, 0) }
                        var bestLen = floor
                        var bestDist = 0
                        let maxLen = Swift.min(maxMatch, n - pos)
                        guard bestLen < maxLen else { return (0, 0) }
                        var cand = Int(head[hash(pos)])
                        var chain = maxSteps
                        let minPos = pos - windowSize
                        while cand >= 0 && cand > minPos && chain > 0 {
                            // Quick reject: candidate must beat the current best at bestLen.
                            if bytes[cand + bestLen] == bytes[pos + bestLen] {
                                var len = 0
                                while len < maxLen && bytes[cand + len] == bytes[pos + len] { len += 1 }
                                if len > bestLen {
                                    bestLen = len
                                    bestDist = pos - cand
                                    if len >= maxLen || len >= niceMatch { break }
                                }
                            }
                            cand = Int(prev[cand])
                            chain -= 1
                        }
                        return bestDist == 0 ? (0, 0) : (bestLen, bestDist)
                    }

                    var pos = 0
                    // A match found one position early by the lazy check.
                    var pending: (length: Int, distance: Int)? = nil
                    while pos < n {
                        if tokenValues.count >= blockTokens {
                            writeBlock(tokenValues, tokenDistances, isFinal: false, into: &writer)
                            tokenValues.removeAll(keepingCapacity: true)
                            tokenDistances.removeAll(keepingCapacity: true)
                        }
                        let match = pending ?? longestMatch(pos, floor: minMatch - 1, chain: maxChain)
                        pending = nil
                        if match.length >= minMatch, match.length < lazyThreshold, pos + 1 < n {
                            // Lazy matching: prefer a strictly longer match that
                            // starts one byte later, paying one literal for it.
                            insert(pos)
                            let next = longestMatch(pos + 1, floor: match.length,
                                                    chain: match.length >= goodMatch ? maxChain / 4 : maxChain)
                            if next.length > match.length {
                                tokenValues.append(UInt16(bytes[pos]))
                                tokenDistances.append(0)
                                pos += 1
                                pending = next
                                continue
                            }
                            tokenValues.append(UInt16(match.length))
                            tokenDistances.append(UInt16(match.distance))
                            let end = pos + match.length
                            pos += 1                      // already inserted
                            while pos < end { insert(pos); pos += 1 }
                            continue
                        }
                        if match.length >= minMatch {
                            tokenValues.append(UInt16(match.length))
                            tokenDistances.append(UInt16(match.distance))
                            // Insert hashes for every covered position so later matches see them.
                            let end = pos + match.length
                            while pos < end { insert(pos); pos += 1 }
                        } else {
                            tokenValues.append(UInt16(bytes[pos]))
                            tokenDistances.append(0)
                            insert(pos)
                            pos += 1
                        }
                    }
                }
            }
        }
        writeBlock(tokenValues, tokenDistances, isFinal: true, into: &writer)
        return writer.finish()
    }

    // MARK: - Block emission

    /// distance (1…32768) → distance code. Distances up to 256 index directly;
    /// larger ones index by `(distance - 1) >> 7`, as in zlib's `d_code`.
    private static let distanceCodeIndex: [UInt8] = {
        var table = [UInt8](repeating: 0, count: 512)
        var code = 0
        for distance in 1...256 {
            while code < distBase.count - 1 && distance >= distBase[code + 1] { code += 1 }
            table[distance - 1] = UInt8(code)
        }
        code = 0
        for slot in 2..<256 {
            let distance = (slot << 7) + 1
            while code < distBase.count - 1 && distance >= distBase[code + 1] { code += 1 }
            table[256 + slot] = UInt8(code)
        }
        return table
    }()

    @inline(__always)
    private static func distanceCode(_ distance: Int) -> Int {
        distance <= 256 ? Int(distanceCodeIndex[distance - 1]) : Int(distanceCodeIndex[256 + ((distance - 1) >> 7)])
    }

    private static let fixedLiteralLengths: [UInt8] = {
        var lengths = [UInt8](repeating: 8, count: 288)
        for i in 144...255 { lengths[i] = 9 }
        for i in 256...279 { lengths[i] = 7 }
        return lengths
    }()
    private static let fixedDistanceLengths = [UInt8](repeating: 5, count: 30)
    /// RFC 1951 §3.2.7 transmission order of the code-length alphabet.
    private static let codeLengthOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    /// Emit one block holding `values`/`distances`, choosing the cheaper of
    /// the fixed code and a dynamic code built from this block's frequencies.
    private static func writeBlock(_ values: [UInt16], _ distances: [UInt16], isFinal: Bool,
                                   into writer: inout BitWriter) {
        var literalFrequency = [Int](repeating: 0, count: 286)
        var distanceFrequency = [Int](repeating: 0, count: 30)
        literalFrequency[256] = 1
        for i in values.indices {
            let distance = Int(distances[i])
            if distance == 0 {
                literalFrequency[Int(values[i])] += 1
            } else {
                literalFrequency[257 + lengthCodeIndex[Int(values[i])]] += 1
                distanceFrequency[distanceCode(distance)] += 1
            }
        }

        // Every decoder accepts a complete code; not all accept a one-symbol
        // one. Like zlib, make sure each tree has at least two symbols.
        var literalCounts = literalFrequency
        var distanceCounts = distanceFrequency
        ensureTwoSymbols(&literalCounts)
        ensureTwoSymbols(&distanceCounts)
        let literalLengths = codeLengths(literalCounts, limit: 15)
        let distanceLengths = codeLengths(distanceCounts, limit: 15)

        // The dynamic header: both length tables, run-length coded.
        var literalCount = 286
        while literalCount > 257 && literalLengths[literalCount - 1] == 0 { literalCount -= 1 }
        var distanceCount = 30
        while distanceCount > 1 && distanceLengths[distanceCount - 1] == 0 { distanceCount -= 1 }
        let header = runLengthCoded(Array(literalLengths[0..<literalCount]) + Array(distanceLengths[0..<distanceCount]))
        var headerFrequency = [Int](repeating: 0, count: 19)
        for item in header { headerFrequency[item.symbol] += 1 }
        ensureTwoSymbols(&headerFrequency)
        let headerLengths = codeLengths(headerFrequency, limit: 7)
        var headerCount = 19
        while headerCount > 4 && headerLengths[codeLengthOrder[headerCount - 1]] == 0 { headerCount -= 1 }

        var dynamicBits = 14 + 3 * headerCount
        for item in header { dynamicBits += Int(headerLengths[item.symbol]) + item.extraBits }
        var fixedBits = 0
        for symbol in 0..<286 where literalFrequency[symbol] != 0 {
            dynamicBits += literalFrequency[symbol] * Int(literalLengths[symbol])
            fixedBits += literalFrequency[symbol] * Int(fixedLiteralLengths[symbol])
        }
        for symbol in 0..<30 where distanceFrequency[symbol] != 0 {
            dynamicBits += distanceFrequency[symbol] * Int(distanceLengths[symbol])
            fixedBits += distanceFrequency[symbol] * 5
        }

        writer.writeBits(isFinal ? 1 : 0, 1)
        let literalCodes: [UInt32], distanceCodes: [UInt32]
        if dynamicBits < fixedBits {
            writer.writeBits(2, 2)   // BTYPE = 10 (dynamic Huffman)
            writer.writeBits(literalCount - 257, 5)
            writer.writeBits(distanceCount - 1, 5)
            writer.writeBits(headerCount - 4, 4)
            for i in 0..<headerCount { writer.writeBits(Int(headerLengths[codeLengthOrder[i]]), 3) }
            let headerCodes = reversedCodes(headerLengths)
            for item in header {
                writer.writeBits(Int(headerCodes[item.symbol] >> 4), Int(headerCodes[item.symbol] & 15))
                writer.writeBits(item.extra, item.extraBits)
            }
            literalCodes = reversedCodes(literalLengths)
            distanceCodes = reversedCodes(distanceLengths)
        } else {
            writer.writeBits(1, 2)   // BTYPE = 01 (fixed Huffman)
            literalCodes = fixedLiteralCodes
            distanceCodes = fixedDistanceCodes
        }

        for i in values.indices {
            let distance = Int(distances[i])
            if distance == 0 {
                let code = literalCodes[Int(values[i])]
                writer.writeBits(Int(code >> 4), Int(code & 15))
            } else {
                let length = Int(values[i])
                let li = lengthCodeIndex[length]
                let code = literalCodes[257 + li]
                writer.writeBits(Int(code >> 4), Int(code & 15))
                writer.writeBits(length - lengthBase[li], lengthExtra[li])
                let di = distanceCode(distance)
                let distanceCodeBits = distanceCodes[di]
                writer.writeBits(Int(distanceCodeBits >> 4), Int(distanceCodeBits & 15))
                writer.writeBits(distance - distBase[di], distExtra[di])
            }
        }
        let endOfBlock = literalCodes[256]
        writer.writeBits(Int(endOfBlock >> 4), Int(endOfBlock & 15))
    }

    private static let fixedLiteralCodes = reversedCodes(fixedLiteralLengths)
    private static let fixedDistanceCodes = reversedCodes(fixedDistanceLengths)

    private static func ensureTwoSymbols(_ frequency: inout [Int]) {
        var used = frequency.reduce(0) { $0 + ($1 != 0 ? 1 : 0) }
        var symbol = 0
        while used < 2 {
            if frequency[symbol] == 0 { frequency[symbol] = 1; used += 1 }
            symbol += 1
        }
    }

    /// Length-limited Huffman code lengths for `frequency` (zero-frequency
    /// symbols get length 0). Ties break on symbol index, so the result is a
    /// pure function of the frequencies.
    static func codeLengths(_ frequency: [Int], limit: Int) -> [UInt8] {
        var lengths = [UInt8](repeating: 0, count: frequency.count)
        // Leaves in ascending (frequency, symbol) order.
        // One integer per leaf — frequency above, symbol below — sorts both keys at once.
        var keys: [UInt64] = []
        keys.reserveCapacity(frequency.count)
        for (symbol, count) in frequency.enumerated() where count != 0 {
            keys.append(UInt64(count) << 16 | UInt64(symbol))
        }
        keys.sort()
        let leaves = keys.map { Int($0 & 0xFFFF) }
        guard leaves.count > 1 else {
            if let only = leaves.first { lengths[only] = 1 }
            return lengths
        }
        // Two-queue Huffman construction: leaves and internal nodes are each
        // already in ascending weight order, so the two smallest nodes are
        // always at the queue fronts. Leaves win ties.
        let count = leaves.count
        var weight = [Int](repeating: 0, count: 2 * count - 1)
        for i in 0..<count { weight[i] = Int(keys[i] >> 16) }
        var parent = [Int](repeating: -1, count: 2 * count - 1)
        var leaf = 0, internalNode = count, next = count
        func takeSmallest() -> Int {
            if leaf < count && (internalNode >= next || weight[leaf] <= weight[internalNode]) {
                leaf += 1
                return leaf - 1
            }
            internalNode += 1
            return internalNode - 1
        }
        while next < 2 * count - 1 {
            let a = takeSmallest(), b = takeSmallest()
            weight[next] = weight[a] + weight[b]
            parent[a] = next
            parent[b] = next
            next += 1
        }
        // Depths, root first (a parent always has a higher index than its children).
        var depth = [Int](repeating: 0, count: 2 * count - 1)
        var index = 2 * count - 3
        while index >= 0 {
            depth[index] = depth[parent[index]] + 1
            index -= 1
        }
        // Count codes per length, folding anything deeper than the limit into
        // it, then restore the Kraft equality by lengthening shorter codes.
        var perLength = [Int](repeating: 0, count: limit + 1)
        for i in 0..<count { perLength[Swift.min(depth[i], limit)] += 1 }
        var total = 0
        for length in 1...limit { total += perLength[length] << (limit - length) }
        while total > 1 << limit {
            perLength[limit] -= 1
            var length = limit - 1
            while length > 0 {
                if perLength[length] > 0 {
                    perLength[length] -= 1
                    perLength[length + 1] += 2
                    break
                }
                length -= 1
            }
            total -= 1
        }
        // Rarest symbols take the longest codes.
        var position = 0
        var length = limit
        while length >= 1 {
            for _ in 0..<perLength[length] {
                lengths[leaves[position]] = UInt8(length)
                position += 1
            }
            length -= 1
        }
        return lengths
    }

    /// Canonical codes for `lengths`, each bit-reversed so it can be written
    /// LSB-first in one call, packed as `code << 4 | length`.
    static func reversedCodes(_ lengths: [UInt8]) -> [UInt32] {
        var perLength = [Int](repeating: 0, count: 16)
        for length in lengths where length != 0 { perLength[Int(length)] += 1 }
        var nextCode = [Int](repeating: 0, count: 16)
        var code = 0
        for length in 1...15 {
            code = (code + perLength[length - 1]) << 1
            nextCode[length] = code
        }
        var codes = [UInt32](repeating: 0, count: lengths.count)
        for (symbol, length) in lengths.enumerated() where length != 0 {
            let canonical = nextCode[Int(length)]
            nextCode[Int(length)] += 1
            var reversed = 0
            for bit in 0..<Int(length) where canonical & (1 << bit) != 0 {
                reversed |= 1 << (Int(length) - 1 - bit)
            }
            codes[symbol] = UInt32(reversed << 4 | Int(length))
        }
        return codes
    }

    private struct HeaderItem {
        var symbol: Int
        var extra: Int
        var extraBits: Int
    }

    /// Run-length code a sequence of code lengths with symbols 16/17/18 (RFC 1951 §3.2.7).
    private static func runLengthCoded(_ lengths: [UInt8]) -> [HeaderItem] {
        var items: [HeaderItem] = []
        var i = 0
        while i < lengths.count {
            let value = lengths[i]
            var run = 1
            while i + run < lengths.count && lengths[i + run] == value { run += 1 }
            i += run
            if value == 0 {
                while run >= 11 {
                    let chunk = Swift.min(run, 138)
                    items.append(HeaderItem(symbol: 18, extra: chunk - 11, extraBits: 7))
                    run -= chunk
                }
                if run >= 3 {
                    items.append(HeaderItem(symbol: 17, extra: run - 3, extraBits: 3))
                    run = 0
                }
            } else {
                items.append(HeaderItem(symbol: Int(value), extra: 0, extraBits: 0))
                run -= 1
                while run >= 3 {
                    let chunk = Swift.min(run, 6)
                    items.append(HeaderItem(symbol: 16, extra: chunk - 3, extraBits: 2))
                    run -= chunk
                }
            }
            for _ in 0..<run { items.append(HeaderItem(symbol: Int(value), extra: 0, extraBits: 0)) }
        }
        return items
    }
}

/// A bit writer that packs into bytes LSB-first (RFC 1951 bit order).
struct BitWriter {
    private var out: [UInt8] = []
    private var bitBuffer: UInt64 = 0
    private var bitCount: Int = 0

    mutating func reserve(_ bytes: Int) { out.reserveCapacity(bytes) }

    /// Write the low `count` (0…32) bits of `value`, least-significant bit first.
    @inline(__always)
    mutating func writeBits(_ value: Int, _ count: Int) {
        guard count > 0 else { return }
        bitBuffer |= (UInt64(truncatingIfNeeded: value) & ((1 << UInt64(count)) - 1)) << UInt64(bitCount)
        bitCount += count
        while bitCount >= 8 {
            out.append(UInt8(truncatingIfNeeded: bitBuffer))
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
            out.append(UInt8(truncatingIfNeeded: bitBuffer))
            bitBuffer = 0
            bitCount = 0
        }
        return Data(out)
    }
}
