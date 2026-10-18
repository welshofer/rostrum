import Foundation
import Testing
import LecternIR

@Suite("LecternIR")
struct LecternIRTests {
    @Test("a lectern.deck/1 document decodes, and round-trips through Codable")
    func decode() throws {
        let json = #"""
        {"meta": {"title": "Q3"}, "slides": [
          {"id": "s1", "layout": "title", "title": "Q3 Review", "body": {"subtitle": "Numbers"}},
          {"id": "s2", "layout": "bullets", "title": "Wins", "body": {"bullets": [{"text": "Revenue", "subBullets": ["up 12%"]}]}}
        ]}
        """#
        let deck = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        #expect(deck.irVersion == DeckIR.currentVersion)
        #expect(deck.slides.map(\.kind) == [.title, .bullets])
        #expect(deck.slides[1].body?.bullets?.first?.subBullets == ["up 12%"])
        let again = try JSONDecoder().decode(DeckIR.self, from: JSONEncoder().encode(deck))
        #expect(again == deck)
    }

    @Test("slides sent as a string holding JSON still decode")
    func doubleEncoded() throws {
        let json = #"{"meta": {"title": "x"}, "slides": "[{\"id\": \"a\", \"layout\": \"quote\"}]"}"#
        let deck = try JSONDecoder().decode(DeckIR.self, from: Data(json.utf8))
        #expect(deck.slides.first?.kind == .quote)
    }

    @Test("every known layout name round-trips")
    func vocabulary() {
        for kind in SlideLayoutKind.knownCases { #expect(SlideLayoutKind(kind.name) == kind) }
        #expect(SlideLayoutKind("novel") == .unknown("novel"))
    }
}

@Suite struct AdvancedTableIRTests {
    @Test func additiveFieldsRoundTripAndOldPayloadStaysSmall() throws {
        let old = Data(#"{"headers":["ID","Value"],"rows":[["A","1"]]}"#.utf8)
        let plain = try JSONDecoder().decode(IRTable.self, from: old)
        #expect(plain.headerRowCount == 1 && plain.grid == [["ID", "Value"], ["A", "1"]])
        let keys = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as? [String: Any])
        #expect(Set(keys.keys) == ["headers", "rows"])
        let table = IRTable(headers: ["Group", "Measures", ""], rows: [["A", "1", "2"]],
            additionalHeaders: [["", "Before", "After"]],
            merges: [.init(row: 0, column: 0, rowSpan: 2, columnSpan: 1), .init(row: 0, column: 1, rowSpan: 1, columnSpan: 2)],
            textDirections: [.init(row: 0, column: 0, direction: .vertical270)])
        let copy = try JSONDecoder().decode(IRTable.self, from: JSONEncoder().encode(table))
        #expect(copy == table && copy.headerRowCount == 2 && copy.grid.count == 3)
        let body = Body(panels: [.init(heading: "First", detail: "Words")])
        #expect(try JSONDecoder().decode(Body.self, from: JSONEncoder().encode(body)) == body)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(IRTableTextDirection.self, from: Data(#"{"row":0,"column":0,"direction":"arbitrary"}"#.utf8))
        }
    }
}
