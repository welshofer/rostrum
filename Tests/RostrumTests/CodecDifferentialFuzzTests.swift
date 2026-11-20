import Foundation
import Testing
@testable import Rostrum

/// Differential and adversarial fuzz tests across `CRC32`, `Deflate`, `Inflate`,
/// and `Inflate.verify`, checked against Python's `zlib` in batched child runs.
@Suite struct CodecDifferentialFuzzTests {

    private struct PRNG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
        mutating func nextByte() -> UInt8 {
            UInt8(truncatingIfNeeded: next() >> 33)
        }
        mutating func int(in range: ClosedRange<Int>) -> Int {
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int(next() % span)
        }
        mutating func bytes(count: Int) -> Data {
            var out = [UInt8](repeating: 0, count: count)
            for i in 0..<count { out[i] = nextByte() }
            return Data(out)
        }
    }

    /// Run a single batched Python `zlib` verification pass over framed binary records
    /// (`[u32 count]`, then per item `[u32 origLen][orig][u32 defLen][rostrumDeflated]`),
    /// returning per-item `(zlibCRC, zlibEncodedVariants)` after asserting `zlib.decompress`
    /// recovers `orig` from `rostrumDeflated`.
    private func runBatchedZlibOracle(_ items: [(original: Data, deflated: Data)]) throws
        -> [(crc: UInt32, variants: [Data])] {
        let script = """
            import struct, sys, zlib
            buf = sys.stdin.buffer.read()
            pos = 0
            (n,) = struct.unpack_from('<I', buf, pos); pos += 4
            out = bytearray()
            strategies = [
                (0, zlib.Z_DEFAULT_STRATEGY),
                (1, zlib.Z_DEFAULT_STRATEGY),
                (6, zlib.Z_DEFAULT_STRATEGY),
                (9, zlib.Z_DEFAULT_STRATEGY),
                (6, zlib.Z_FIXED),
                (6, zlib.Z_HUFFMAN_ONLY),
                (6, zlib.Z_RLE),
            ]
            for idx in range(n):
                (olen,) = struct.unpack_from('<I', buf, pos); pos += 4
                orig = buf[pos:pos + olen]; pos += olen
                (dlen,) = struct.unpack_from('<I', buf, pos); pos += 4
                deflated = buf[pos:pos + dlen]; pos += dlen
                restored = zlib.decompress(deflated, -15)
                if restored != orig:
                    sys.stderr.write(f'item {idx}: zlib decompress mismatch ({len(restored)} vs {len(orig)})\\n')
                    sys.exit(2)
                crc = zlib.crc32(orig) & 0xFFFFFFFF
                # Emit all 7 strategy streams for compact inputs, and levels 0 + 9 for large ones.
                chosen = strategies if olen <= 16384 else [strategies[0], strategies[3]]
                out += struct.pack('<II', crc, len(chosen))
                for level, strat in chosen:
                    c = zlib.compressobj(level, zlib.DEFLATED, -15, 8, strat)
                    stream = c.compress(orig) + c.flush()
                    out += struct.pack('<I', len(stream)) + stream
            sys.stdout.buffer.write(out)
            """

        var payload = Data()
        func appendU32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { payload.append(contentsOf: $0) }
        }
        appendU32(UInt32(items.count))
        for item in items {
            appendU32(UInt32(item.original.count))
            payload.append(item.original)
            appendU32(UInt32(item.deflated.count))
            payload.append(item.deflated)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        proc.arguments = ["-c", script]
        let stdinPipe = Pipe(), stdoutPipe = Pipe(), stderrPipe = Pipe()
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        try proc.run()
        let stdinBytes = payload
        let writer = Thread {
            try? stdinPipe.fileHandleForWriting.write(contentsOf: stdinBytes)
            try? stdinPipe.fileHandleForWriting.close()
        }
        writer.start()
        let response = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            let msg = String(decoding: errData, as: UTF8.self)
            Issue.record("Python zlib oracle failed (\(proc.terminationStatus)): \(msg)")
            return []
        }

        var results: [(crc: UInt32, variants: [Data])] = []
        results.reserveCapacity(items.count)
        var pos = 0
        func readU32() -> UInt32 {
            let v = UInt32(response[pos])
                | (UInt32(response[pos + 1]) << 8)
                | (UInt32(response[pos + 2]) << 16)
                | (UInt32(response[pos + 3]) << 24)
            pos += 4
            return v
        }
        for _ in 0..<items.count {
            let crc = readU32()
            let count = Int(readU32())
            var variants: [Data] = []
            variants.reserveCapacity(count)
            for _ in 0..<count {
                let len = Int(readU32())
                variants.append(response.subdata(in: pos..<(pos + len)))
                pos += len
            }
            results.append((crc, variants))
        }
        return results
    }

    @Test func crc32SlicingBy8MatchesZlibAcrossAlignmentsAndRandomSplits() throws {
        var rng = PRNG(state: 0xC3C3_2026_1119)
        let lengths = Array(0...73) + [127, 128, 129, 255, 256, 257, 4095, 4096, 4097, 16385]
        var oracleInputs: [(original: Data, deflated: Data)] = []
        for len in lengths {
            let data = rng.bytes(count: len)
            oracleInputs.append((data, Deflate.deflate(data)))

            // Verify unaligned slices (start offsets 1...7 inside a padded buffer).
            let expected = CRC32.checksum(data)
            for padOffset in 1...7 {
                var padded = Data(repeating: 0xAA, count: padOffset)
                padded.append(data)
                padded.append(Data(repeating: 0x55, count: 8))
                let slice = padded[padOffset..<(padOffset + len)]
                #expect(CRC32.checksum(slice) == expected, "unaligned offset \(padOffset) len \(len)")
            }

            // Verify arbitrary random chunk boundaries in incremental CRC32.update.
            var chunkPadded = Data(repeating: 0xAA, count: 3)
            chunkPadded.append(data)
            chunkPadded.append(Data(repeating: 0x55, count: 5))
            var running = CRC32.initialValue
            var cursor = 0
            while cursor < len {
                let step = min(rng.int(in: 1...29), len - cursor)
                running = CRC32.update(running, with: chunkPadded[(3 + cursor)..<(3 + cursor + step)])
                cursor += step
            }
            #expect(CRC32.finalize(running) == expected, "chunked CRC len \(len)")
        }

        let oracle = try runBatchedZlibOracle(oracleInputs)
        #expect(oracle.count == oracleInputs.count)
        for (i, entry) in oracle.enumerated() {
            #expect(CRC32.checksum(oracleInputs[i].original) == entry.crc, "zlib CRC mismatch at \(i)")
        }
    }

    @Test func deflateStoredBlockFallbackAndWindowWraparoundBoundaries() throws {
        var rng = PRNG(state: 0xB000_65535_32768)

        // 1. Incompressible payloads across the 65,535-byte stored-block split boundary
        //    must emit BTYPE=00 stored blocks instead of expanding under Huffman coding.
        //    Each 65,536-token Deflate block emits at most two 65,535-byte stored sub-blocks.
        for size in [512, 65_534, 65_535, 65_536, 131_070, 131_071] {
            let randomBytes = rng.bytes(count: size)
            let deflated = Deflate.deflate(randomBytes)
            let maxStoredOverhead = 5 * 2 * ((size + 65_535) / 65_536)
            #expect(
                deflated.count <= size + maxStoredOverhead,
                "incompressible \(size) B expanded by \(deflated.count - size) B (expected <= \(maxStoredOverhead) B stored framing)"
            )
            #expect(deflated[0] & 0x06 == 0x00, "expected BTYPE=00 stored block header for incompressible \(size) B")
            #expect(try Inflate.inflate(deflated, expectedOutputSize: size) == randomBytes)
            let verified = try Inflate.verify(deflated, expectedOutputSize: size)
            #expect(verified.size == size && verified.crc32 == CRC32.checksum(randomBytes))
        }

        // 2. Mixed multi-block stream: dynamic Huffman XML -> non-byte-aligned BTYPE=00 stored
        //    sub-blocks -> dynamic Huffman XML -> final stored block, plus 32 KiB window wraparound
        //    and exact 258-byte max match & 32,768-byte max distance!
        let xmlPrefix = Data(String(repeating: "<p:sp><a:t>Repeatable slide text token</a:t></p:sp>", count: 900).utf8)
        let highEntropyMid = rng.bytes(count: 70_000)
        let exact258 = rng.bytes(count: 258)
        var distanceEdge = Data()
        distanceEdge.append(exact258)
        distanceEdge.append(Data(repeating: 0x3D, count: 32_768 - 258)) // total 32,768 bytes since exact258 start!
        distanceEdge.append(exact258) // exact distance == 32,768, exact length == 258!
        distanceEdge.append(Data(repeating: 0x2B, count: 40_000)) // wrap 32 KiB prev ring buffer multiple times
        distanceEdge.append(exact258)

        var stitched = Data()
        stitched.append(xmlPrefix)
        stitched.append(highEntropyMid)
        stitched.append(distanceEdge)
        stitched.append(rng.bytes(count: 66_000))

        // Exercise non-zero-based Data slice input as well.
        var wrapper = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x01])
        wrapper.append(stitched)
        let slicedInput = wrapper[5..<(5 + stitched.count)]
        #expect(slicedInput.startIndex == 5)

        let deflated = Deflate.deflate(slicedInput)
        #expect(Deflate.deflate(stitched) == deflated, "non-zero-based Data slice must deflate identically")
        #expect(try Inflate.inflate(deflated, expectedOutputSize: stitched.count) == stitched)
        let verified = try Inflate.verify(deflated, expectedOutputSize: stitched.count)
        #expect(verified.size == stitched.count)
        #expect(verified.crc32 == CRC32.checksum(stitched))

        let oracle = try runBatchedZlibOracle([(stitched, deflated)])
        #expect(oracle.first?.crc == verified.crc32)
    }

    @Test func seededDifferentialCodecFuzzAgainstZlibOracle() throws {
        var rng = PRNG(state: 0xF022_DEAD_BEEF_CAFE)
        var batch: [(original: Data, deflated: Data)] = []

        for caseIndex in 0..<80 {
            let mode = caseIndex % 5
            let original: Data
            switch mode {
            case 0:
                // Structured OOXML-like tags with varying attributes.
                let count = rng.int(in: 0...180)
                var s = ""
                for j in 0..<count {
                    s += "<a:r id=\"\(rng.int(in: 0...9999))\"><a:rPr sz=\"\(rng.int(in: 800...4400))\"/><a:t>Item \(j)</a:t></a:r>"
                }
                original = Data(s.utf8)
            case 1:
                // High-entropy incompressible bytes of varied sizes.
                original = rng.bytes(count: rng.int(in: 0...20_000))
            case 2:
                // RLE & short-period overlapping patterns (`distance < length`).
                var d = Data()
                for _ in 0..<rng.int(in: 1...25) {
                    let patLen = rng.int(in: 1...11)
                    let pat = rng.bytes(count: patLen)
                    for _ in 0..<rng.int(in: 1...120) { d.append(pat) }
                }
                original = d
            case 3:
                // Skewed small alphabet (1 to 6 unique symbols) testing deep & single-symbol Huffman trees.
                let alphabetSize = rng.int(in: 1...6)
                let len = rng.int(in: 1...12_000)
                var bytes = [UInt8](repeating: 0, count: len)
                for i in 0..<len {
                    // Geometric bias toward symbol 0 so tree depth hits 15-bit Kraft limit on larger alphabets.
                    var sym = 0
                    while sym + 1 < alphabetSize && (rng.next() & 3) == 0 { sym += 1 }
                    bytes[i] = UInt8(65 + sym)
                }
                original = Data(bytes)
            default:
                // Multi-window echoes straddling 32 KiB distances.
                let block = rng.bytes(count: rng.int(in: 64...2048))
                var d = Data()
                d.append(block)
                d.append(Data(repeating: rng.nextByte(), count: rng.int(in: 30_000...35_000)))
                d.append(block)
                original = d
            }

            let deflated = Deflate.deflate(original)
            let ownDecoded = try Inflate.inflate(deflated, expectedOutputSize: original.count)
            #expect(ownDecoded == original, "own round-trip failed on case \(caseIndex)")
            let ownVerified = try Inflate.verify(deflated, expectedOutputSize: original.count)
            #expect(ownVerified.size == original.count, "verify size failed on case \(caseIndex)")
            #expect(ownVerified.crc32 == CRC32.checksum(original), "verify crc failed on case \(caseIndex)")
            batch.append((original, deflated))
        }

        let oracleResults = try runBatchedZlibOracle(batch)
        #expect(oracleResults.count == batch.count)
        for (i, oracle) in oracleResults.enumerated() {
            let expected = batch[i].original
            #expect(CRC32.checksum(expected) == oracle.crc, "CRC mismatch on fuzz case \(i)")
            for (vIndex, stream) in oracle.variants.enumerated() {
                let decoded = try Inflate.inflate(stream, expectedOutputSize: expected.count)
                #expect(decoded == expected, "Inflate failed on zlib variant \(vIndex) of case \(i)")
                let verified = try Inflate.verify(stream, expectedOutputSize: expected.count)
                #expect(verified.size == expected.count && verified.crc32 == oracle.crc,
                        "Inflate.verify failed on zlib variant \(vIndex) of case \(i)")
            }
        }
    }

    @Test func corruptBitstreamFuzzNeverTrapsAndAgreesBetweenInflateAndVerify() {
        var rng = PRNG(state: 0xBAD0_DEFA_1234_5678)
        let seeds: [Data] = [
            Deflate.deflate(Data()),
            Deflate.deflate(Data("fixed huffman short seed".utf8)),
            Deflate.deflate(Data(String(repeating: "<p:sld><p:cSld/></p:sld>", count: 300).utf8)),
            Deflate.deflate(rng.bytes(count: 4096)),
        ]

        for iter in 0..<250 {
            var mutated: Data
            if iter % 4 == 0 {
                // Pure random bytes.
                mutated = rng.bytes(count: rng.int(in: 0...256))
            } else {
                mutated = seeds[iter % seeds.count]
                let op = iter % 3
                if op == 0, !mutated.isEmpty {
                    // Truncate at random prefix.
                    mutated = mutated.prefix(rng.int(in: 0...(mutated.count - 1)))
                } else if !mutated.isEmpty {
                    // Flip 1 to 4 random bytes.
                    for _ in 0..<rng.int(in: 1...4) {
                        let idx = rng.int(in: 0...(mutated.count - 1))
                        mutated[idx] ^= UInt8(truncatingIfNeeded: rng.int(in: 1...255))
                    }
                }
            }

            let ceiling = 262_144
            let inflateResult = Result { try Inflate.inflate(mutated, expectedOutputSize: ceiling) }
            let verifyResult = Result { try Inflate.verify(mutated, expectedOutputSize: ceiling) }

            switch (inflateResult, verifyResult) {
            case (.success(let bytes), .success(let verified)):
                #expect(verified.size == bytes.count, "iter \(iter): size disagreement")
                #expect(verified.crc32 == CRC32.checksum(bytes), "iter \(iter): crc disagreement")
            case (.failure(let e1), .failure(let e2)):
                guard let r1 = e1 as? RostrumError, case .deflateCorrupt = r1,
                      let r2 = e2 as? RostrumError, case .deflateCorrupt = r2 else {
                    Issue.record("iter \(iter): unexpected error types: \(e1) vs \(e2)")
                    continue
                }
            default:
                Issue.record("iter \(iter): Inflate and Inflate.verify disagreed: \(inflateResult) vs \(verifyResult)")
            }
        }
    }
}
