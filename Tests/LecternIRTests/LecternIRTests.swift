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
