import Foundation
import Testing
@testable import Rostrum

@Suite("DeckExportTests")
struct DeckExportTests {

    @Test func formulaGuardCoversGraphemeClustersControlPrefixesWhitespaceAndNonFiniteNegatives() {
        let dangerous: [String] = [
            "\r\n=CMD()",
            "\n=SUM(A1)",
            "\u{000B}=1+1",
            "\u{000C}=1+1",
            "\t=1+1",
            "=\u{0300}1+1",
            "+\u{0301}SUM(A1)",
            "@\u{0302}SUM(A1)",
            "-\u{0300}5",
            "-inf",
            "-Infinity",
            "-NaN",
            "-nan(0x123)",
            "-0x1p2",
            "-1e9999",
            "-",
            "-.",
            "-1e",
            " =1+1",
            "   +SUM(A1)",
            "\u{00A0}@SUM(A1)",
            "\u{FEFF}=1+1",
            " -1+1",
        ]
        for input in dangerous {
            #expect(DeckExport.needsFormulaGuard(input), "expected guard for \(input.debugDescription)")
            let formatted = DeckExport.field(input)
            if formatted.hasPrefix("\"") {
                #expect(formatted.hasPrefix("\"'"), "quoted field must carry leading apostrophe for \(input.debugDescription): \(formatted)")
            } else {
                #expect(formatted.hasPrefix("'"), "unquoted field must carry leading apostrophe for \(input.debugDescription): \(formatted)")
            }
        }

        // Exact RFC 4180 + formula-guard encodings on multiline / comma / quote inputs,
        // including combining marks after CR, LF, comma, and quote.
        #expect(DeckExport.field("\r\n=CMD()") == "\"'\r\n=CMD()\"")
        #expect(DeckExport.field("\n=SUM(A1)") == "\"'\n=SUM(A1)\"")
        #expect(DeckExport.field("\n\u{0300}=SUM(A1)") == "\"'\n\u{0300}=SUM(A1)\"")
        #expect(DeckExport.field("\r\u{0300}=CMD()") == "\"'\r\u{0300}=CMD()\"")
        #expect(DeckExport.field("a,\u{0300}=CMD()") == "\"a,\u{0300}=CMD()\"")
        #expect(DeckExport.field("x\"\u{0300},=CMD(),\"y") == "\"x\"\"\u{0300},=CMD(),\"\"y\"")
        #expect(DeckExport.field("=1,\"\u{0300}\r\n=1+1,") == "\"'=1,\"\"\u{0300}\r\n=1+1,\"")
        #expect(DeckExport.field("=\u{0300}1+1") == "'=\u{0300}1+1")
        #expect(DeckExport.field("-inf") == "'-inf")
        #expect(DeckExport.field("-NaN") == "'-NaN")
        #expect(DeckExport.field(" =1+1") == "' =1+1")

        // Finite negative numbers and benign strings stay unprefixed.
        let safe: [String] = [
            "",
            "plain",
            "  Indented text",
            "\u{FEFF}Heading",
            "-5",
            "-42.5",
            "-3.14",
            "-1e4",
            "-2.5E-3",
            "-.5",
            "-0.0",
        ]
        for input in safe {
            #expect(!DeckExport.needsFormulaGuard(input), "unexpected guard on \(input.debugDescription)")
            #expect(DeckExport.field(input) == input)
        }
    }

    @Test func exportedChartCSVGuardsAdversarialLabelsWhilePreservingNegativeValues() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        _ = try slide.shapes.addChart(
            .barClustered,
            data: ChartData(
                categories: ["=\u{0300}1+1", "-inf", "-NaN", " =1+1", "\n=SUM(A1)", "Normal"],
                series: [.init(name: "\r\n=CMD()", values: [-42.5, -5, -3.14, -10000, 0, 12.25])]
            ),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(4))
        )

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-sec2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let summary = try DeckExport.write(deck, to: dir, named: "Deck")
        #expect(summary.chartsWritten == 1)
        #expect(summary.warnings.isEmpty)

        let csv = try String(
            contentsOf: dir.appendingPathComponent("slide-01/chart-1.csv"),
            encoding: .utf8
        )
        let expected = [
            "Category,\"'\r\n=CMD()\"",
            "'=\u{0300}1+1,-42.5",
            "'-inf,-5",
            "'-NaN,-3.14",
            "' =1+1,-10000",
            "\"'\n=SUM(A1)\",0",
            "Normal,12.25",
            "",
        ].joined(separator: "\r\n")
        #expect(csv == expected)
    }
}
