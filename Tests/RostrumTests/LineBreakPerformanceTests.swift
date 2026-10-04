import Foundation
import Testing
@testable import Rostrum

@Suite struct LineBreakPerformanceTests {
    @Test func everyASCIIPairMatchesFrozenGeneralPath() throws {
        // Frozen cf1b8a0 release output, generated before the byte scan. Each
        // hex digit packs the two scalar positions: 0=no break, 1=optional,
        // 3=mandatory. This includes every control pair, particularly CR/LF.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/ascii-breaks-baseline.json")
        let rows = try JSONDecoder().decode([String].self, from: Data(contentsOf: url))
        #expect(rows.count == 128)
        for first in 0..<128 {
            let reference = Array(rows[first])
            #expect(reference.count == 128)
            for second in 0..<128 {
                let text = String(Unicode.Scalar(first)!) + String(Unicode.Scalar(second)!)
                let mask = try #require(Int(String(reference[second]), radix: 16))
                let expectedOffsets = (1...2).filter { mask & (1 << (($0 - 1) * 2)) != 0 }
                let expectedMandatory = expectedOffsets.map { mask & (2 << (($0 - 1) * 2)) != 0 }
                let breaks = TextShaper.lineBreaks(in: text)
                #expect(breaks.map(\.scalarOffset) == expectedOffsets, "ASCII \(first), \(second)")
                #expect(breaks.map(\.mandatory) == expectedMandatory, "ASCII \(first), \(second)")
            }
        }
    }

    @Test func chainedNewlinesAndNonASCIIGraphemesKeepTheirOffsets() {
        let cases: [(String, [Int], [Bool])] = [
            ("", [], []),
            ("\r\n\r\r\n\n- ", [2, 3, 5, 6, 7, 8], [true, true, true, true, false, false]),
            ("a\u{301} b\r\nc", [3, 6], [false, true]),
            ("\r\n中\u{A0}文", [2, 5], [true, false]),
            ("a\u{200B}b- ", [2, 4, 5], [false, false, false]),
            ("中文（测试）文本", [1, 2, 4, 6, 7, 8], Array(repeating: false, count: 6)),
        ]
        for (text, offsets, mandatory) in cases {
            let breaks = TextShaper.lineBreaks(in: text)
            #expect(breaks.map(\.scalarOffset) == offsets)
            #expect(breaks.map(\.mandatory) == mandatory)
        }
    }
}
