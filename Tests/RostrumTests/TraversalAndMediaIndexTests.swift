import Foundation
import Testing
@testable import Rostrum

@Suite struct TraversalAndMediaIndexTests {
    @Test func iteratorSeesFreshDOMBetweenOperations() throws {
        let p = try Presentation(); _ = try p.slides.add()
        let iterator = p.slides.makeIterator()
        _ = try p.slides.add()
        #expect(Array(IteratorSequence(iterator)).count == 2)
        #expect(Array(p.slides).count == 3)
        let ids = try p.package.mainDocumentPart().dom().firstChild(named: "p:sldIdLst")!
        ids.removeChild(ids.childElements[0])
        #expect(Array(p.slides).count == 2)
    }
    @Test func mediaIndexInvalidatesOnEveryByteAndMembershipChange() throws {
        let p = OPCPackage()
        let a = Data([1,2,3]), b = Data([4,5,6])
        let high = p.addPart(uri: PackURI("/ppt/media/z.png"), contentType: "image/png", blob: a)
        #expect(p.matchingMedia(for: a) === high)
        let low = p.addPart(uri: PackURI("/ppt/media/a.png"), contentType: "image/png", blob: a)
        #expect(p.matchingMedia(for: a) === low)
        low.replaceBlob(b)
        #expect(p.matchingMedia(for: a) === high)
        #expect(p.matchingMedia(for: b) === low)
        p.removePart(at: high.uri)
        #expect(p.matchingMedia(for: a) == nil)
        let replacement = p.addPart(uri: low.uri, contentType: "image/png", blob: a)
        #expect(p.matchingMedia(for: b) == nil)
        #expect(p.matchingMedia(for: a) === replacement)
    }
    @Test func mediaIndexChecksBytesAfterFingerprintCollision() throws {
        // Deliberately equal CRC32 (the final four bytes compensate the prefix).
        let a = Data([0x70,0x6c,0x75,0x6d,0x6c,0x65,0x73,0x73])
        let b = Data([0x62,0x75,0x63,0x6b,0x65,0x72,0x6f,0x6f])
        #expect(a.count == b.count)
        #expect(CRC32.checksum(a) == CRC32.checksum(b))
        let p = OPCPackage()
        let first = p.addPart(uri: PackURI("/ppt/media/a.png"), contentType: "image/png", blob: a)
        let second = p.addPart(uri: PackURI("/ppt/media/b.png"), contentType: "image/png", blob: b)
        #expect(p.matchingMedia(for: a) === first)
        #expect(p.matchingMedia(for: b) === second)
    }
}
