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
}
