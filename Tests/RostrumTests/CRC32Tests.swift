import Foundation
import Testing

@testable import Rostrum

@Suite("CRC32Tests")
struct CRC32Tests {

    @Test("Empty data checksums to 0x00000000")
    func emptyData() {
        #expect(CRC32.checksum(Data()) == 0x0000_0000)
    }

    @Test("Standard check vector: \"123456789\" -> 0xCBF43926")
    func standardCheckVector() {
        let data = Data("123456789".utf8)
        #expect(CRC32.checksum(data) == 0xCBF4_3926)
    }

    @Test("Additional known-answer vectors")
    func additionalVectors() {
        // Well-known reference values for IEEE CRC-32.
        #expect(CRC32.checksum(Data("a".utf8)) == 0xE8B7_BE43)
        #expect(CRC32.checksum(Data("abc".utf8)) == 0x3524_41C2)
        #expect(CRC32.checksum(Data("The quick brown fox jumps over the lazy dog".utf8)) == 0x414F_A339)
        #expect(CRC32.checksum(Data(repeating: 0x00, count: 32)) == 0x190A_55AD)
        #expect(CRC32.checksum(Data(repeating: 0xFF, count: 32)) == 0xFF6C_AB0B)
    }

    @Test("Incremental update equals one-shot checksum")
    func incrementalEqualsOneShot() {
        let whole = Data("The quick brown fox jumps over the lazy dog".utf8)
        let oneShot = CRC32.checksum(whole)

        // Split into several uneven chunks and feed them through update.
        let cuts = [0, 3, 4, 10, 25, whole.count]
        var running = CRC32.initialValue
        for i in 0..<(cuts.count - 1) {
            let chunk = whole.subdata(in: cuts[i]..<cuts[i + 1])
            running = CRC32.update(running, with: chunk)
        }
        #expect(CRC32.finalize(running) == oneShot)

        // Byte-at-a-time must agree too.
        var byteWise = CRC32.initialValue
        for byte in whole {
            byteWise = CRC32.update(byteWise, with: Data([byte]))
        }
        #expect(CRC32.finalize(byteWise) == oneShot)
    }

    @Test("Updating with empty data does not change the running value")
    func updateWithEmptyDataIsIdentity() {
        let running = CRC32.update(CRC32.initialValue, with: Data("123456789".utf8))
        #expect(CRC32.update(running, with: Data()) == running)
    }

    @Test("initialValue and finalize match the spec")
    func rawValueContract() {
        #expect(CRC32.initialValue == 0xFFFF_FFFF)
        #expect(CRC32.finalize(CRC32.initialValue) == 0x0000_0000)
        #expect(CRC32.finalize(0x0000_0000) == 0xFFFF_FFFF)
    }

    // MARK: - Slicing-by-8 coverage

    /// Deterministic pseudo-random bytes (SplitMix64) so failures reproduce.
    private static func pseudoRandomBytes(count: Int, seed: UInt64) -> Data {
        var state = seed
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        while bytes.count < count {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            for shift in stride(from: 0, to: 64, by: 8) where bytes.count < count {
                bytes.append(UInt8(truncatingIfNeeded: z >> UInt64(shift)))
            }
        }
        return Data(bytes)
    }

    /// Byte-at-a-time reference CRC, independent of the library's tables.
    private static func referenceCRC(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (0xEDB8_8320 ^ (crc >> 1)) : (crc >> 1)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }

    /// CRCs of consecutive `lengths`-sized pieces of `payload`, computed by
    /// Python's `zlib.crc32` as an external oracle.
    private static func zlibCRCs(of payload: Data, lengths: [Int]) throws -> [UInt32] {
        let script = """
            import sys, zlib
            data = sys.stdin.buffer.read()
            offset = 0
            for length in map(int, sys.argv[1:]):
                print(zlib.crc32(data[offset:offset + length]) & 0xFFFFFFFF)
                offset += length
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-c", script] + lengths.map(String.init)
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Feed stdin on another thread so a large payload cannot deadlock the pipes.
        let writer = Thread {
            try? stdinPipe.fileHandleForWriting.write(contentsOf: payload)
            try? stdinPipe.fileHandleForWriting.close()
        }
        writer.start()
        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.executableLoad)
        }
        return String(decoding: output, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { UInt32($0) }
    }

    @Test("Every length 0...64 plus multi-kilobyte inputs match Python's zlib.crc32")
    func matchesZlibOracleAcrossLengths() throws {
        let lengths = Array(0...64) + [1023, 4096, 4099, 65_543]
        let total = lengths.reduce(0, +)
        let payload = Self.pseudoRandomBytes(count: total, seed: 0xC0FF_EE00_1234_5678)
        let expected = try Self.zlibCRCs(of: payload, lengths: lengths)
        try #require(expected.count == lengths.count)

        var offset = 0
        for (index, length) in lengths.enumerated() {
            // Copy into a fresh Data so the buffer starts at index 0.
            let piece = Data(payload[offset..<(offset + length)])
            #expect(CRC32.checksum(piece) == expected[index], "length \(length)")
            #expect(Self.referenceCRC(piece) == expected[index], "reference, length \(length)")
            offset += length
        }
    }

    @Test("Unaligned Data slices checksum the same as copies (every base offset 0...15)")
    func unalignedSlicesMatchCopies() {
        let payload = Self.pseudoRandomBytes(count: 300, seed: 42)
        for start in 0..<16 {
            for length in [0, 1, 7, 8, 9, 15, 16, 17, 63, 64, 65, 200] {
                let slice = payload[start..<(start + length)]
                let copy = Data(slice)
                #expect(CRC32.checksum(slice) == Self.referenceCRC(copy), "start \(start), length \(length)")
                #expect(CRC32.checksum(slice) == CRC32.checksum(copy))
            }
        }
    }

    @Test("update over arbitrary splits equals one whole-buffer call")
    func chunkedUpdateEqualsWholeBuffer() {
        let payload = Self.pseudoRandomBytes(count: 5_000, seed: 7)
        let whole = CRC32.update(CRC32.initialValue, with: payload)
        #expect(CRC32.finalize(whole) == Self.referenceCRC(payload))

        // Every single split point across the first slice boundaries.
        for cut in 0...40 {
            var running = CRC32.update(CRC32.initialValue, with: payload[0..<cut])
            running = CRC32.update(running, with: payload[cut..<payload.count])
            #expect(running == whole, "cut at \(cut)")
        }

        // Pseudo-random multi-way splits with chunk sizes 0...23.
        var rng: UInt64 = 0x1234_5678_9ABC_DEF0
        for trial in 0..<50 {
            var running = CRC32.initialValue
            var offset = 0
            while offset < payload.count {
                rng = rng &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let size = min(Int(rng >> 59) % 24, payload.count - offset)
                running = CRC32.update(running, with: payload[offset..<(offset + size)])
                offset += size
            }
            #expect(running == whole, "trial \(trial)")
        }
    }
}
