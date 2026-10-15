import Foundation
import Testing
@testable import LecternCore

@Suite struct PreviewFontResourcesTests {
    private func rule(_ data: Data, face: Int = 1, italic: Bool = false, bold: Bool = false, otf: Bool = false) -> String {
        "@font-face{font-family:'RostrumEmbeddedFace\(face)';font-style:\(italic ? "italic" : "normal");font-weight:\(bold ? 700 : 400);src:url(data:font/\(otf ? "otf" : "ttf");base64,\(data.base64EncodedString())) format('\(otf ? "opentype" : "truetype")');}"
    }
    private func svg(_ rules: String) -> String {
        "<svg viewBox=\"0 0 400 300\"><defs><style type=\"text/css\">\(rules)</style></defs><text font-family=\"RostrumEmbeddedFace1\">AVATAR é中 e\u{301}</text><image href=\"data:image/png;base64,AAEC\"/></svg>"
    }
    private func restore(_ document: PreviewFontResources.Document) -> String {
        document.resources.reduce(document.svg) { result, resource in
            result.replacingOccurrences(of: resource.url + ")",
                with: "data:\(resource.mimeType);base64,\(resource.data.base64EncodedString()))")
        }
    }

    @Test func onlyFontURLsChangeAndRepeatedFacesDecodeOnce() throws {
        let store = PreviewFontResources()
        let bytes = Data((0..<256).map(UInt8.init))
        let source = svg(rule(bytes) + rule(bytes, face: 2, italic: true, bold: true))
        let first = store.prepare(svg: source), second = store.prepare(svg: source)
        #expect(first.resources.count == 1)
        #expect(first.resources.first?.data == bytes)
        #expect(first.svg == second.svg && store.decodedResources == 1)
        #expect(Array(restore(first).utf8) == Array(source.utf8))
        #expect(first.svg.contains("font-style:italic;font-weight:700"))
        #expect(first.svg.contains("data:image/png;base64,AAEC"))
    }

    @Test func aliasesNeverIdentifyResourcesAndChangedContentIsFresh() throws {
        let store = PreviewFontResources()
        let a = store.prepare(svg: svg(rule(Data([1, 2, 3]))))
        let b = store.prepare(svg: svg(rule(Data([1, 2, 4]))))
        #expect(a.resources.first?.url != b.resources.first?.url)
        #expect(a.resources.first?.data == Data([1, 2, 3]))
        let c = store.prepare(svg: svg(rule(Data([1, 2, 3]), face: 7)))
        #expect(a.resources.first?.url == c.resources.first?.url)
        #expect(store.decodedResources == 2)
    }

    @Test func manyFacesReconstructWithoutMatchingURLPrefixes() {
        let store = PreviewFontResources()
        let source = svg((1...12).map { rule(Data([UInt8($0), 2, 3]), face: $0) }.joined())
        let prepared = store.prepare(svg: source)
        #expect(prepared.resources.count == 12)
        #expect(Array(restore(prepared).utf8) == Array(source.utf8))
    }

    @Test func formatsStayDistinctAndUnrecognizedMarkupStaysInline() {
        let store = PreviewFontResources()
        let bytes = Data([1, 2, 3])
        let source = svg(rule(bytes) + rule(bytes, face: 2, otf: true))
        let prepared = store.prepare(svg: source)
        #expect(Set(prepared.resources.map(\.mimeType)) == ["font/ttf", "font/otf"])
        #expect(restore(prepared) == source)
        for text in ["<svg/>", svg(rule(bytes).replacingOccurrences(of: "RostrumEmbeddedFace1", with: "Custom")),
                     svg(rule(bytes).replacingOccurrences(of: "AQID", with: "!!!!")),
                     svg(rule(bytes).replacingOccurrences(of: "AQID", with: "AB==")),
                     svg(rule(bytes).replacingOccurrences(of: "truetype", with: "woff")),
                     svg(rule(bytes)).replacingOccurrences(of: "<style type=\"text/css\">", with: "<style>")] {
            let result = store.prepare(svg: text)
            #expect(result.svg == text && result.resources.isEmpty)
        }
    }

    @Test func activeResourcesStayValidAfterEvictionAndURLsAreNeverRecycled() throws {
        let store = PreviewFontResources(capacity: 1, byteLimit: 100)
        let first = store.prepare(svg: svg(rule(Data([1, 2, 3]))))
        _ = store.prepare(svg: svg(rule(Data([4, 5, 6]))))
        let again = store.prepare(svg: svg(rule(Data([1, 2, 3]))))
        #expect(first.resources.first?.url != again.resources.first?.url)
        #expect(first.resources.first?.data == Data([1, 2, 3]))
        #expect(store.retainedCount == 1 && store.retainedBytes <= 100)
        let other = PreviewFontResources().prepare(svg: svg(rule(Data([1, 2, 3]))))
        #expect(other.resources.first?.url != again.resources.first?.url)
    }

    @Test func budgetsDoNotDropInlineFonts() {
        let bytes = Data(repeating: 42, count: 120)
        let source = svg(rule(bytes))
        for store in [PreviewFontResources(byteLimit: 0), PreviewFontResources(capacity: 0),
                      PreviewFontResources(byteLimit: 100)] {
            let result = store.prepare(svg: source)
            #expect(result.svg == source && result.resources.isEmpty)
            #expect(store.retainedCount == 0 && store.retainedBytes == 0)
        }
        let store = PreviewFontResources(capacity: 2, byteLimit: 60)
        let mixed = svg(rule(Data([1, 2, 3])) + rule(Data([4, 5, 6]), face: 2) + rule(bytes, face: 3))
        let result = store.prepare(svg: mixed)
        #expect(result.resources.count == 2)
        #expect(result.svg.contains(bytes.base64EncodedString()))
        #expect(restore(result) == mixed && store.retainedBytes <= 60)
    }
}
