import Dispatch
import Foundation
import Testing
@testable import Rostrum

@Suite(.serialized) struct ViewportAndDeepCopySafetyTests {
    private final class ThreadResultBox: @unchecked Sendable {
        let source: XML.Element
        var cloned: XML.Element?
        init(_ source: XML.Element) { self.source = source }
    }

    @Test func extremeSlideAspectRatiosAndPixelWidthsClampWithoutOverflowing() throws {
        let tallDeck = try Presentation()
        let tallPresDOM = try tallDeck.presentationPart.dom()
        let tallSldSz = try #require(tallPresDOM.firstChild(named: "p:sldSz"))
        tallSldSz[attribute: "cx"] = "1"
        tallSldSz[attribute: "cy"] = "1099511627776" // 2^40 EMU
        tallDeck.presentationPart.markDirty()

        let tallSVG = try tallDeck.renderSVG(slideAt: 0, pixelWidth: 10_000_000)
        let tallRoot = try XML.parse(Data(tallSVG.utf8))
        #expect(tallRoot[attribute: "width"] == "32768")
        #expect(tallRoot[attribute: "height"] == "32768")
        #expect(tallRoot[attribute: "viewBox"] == "0 0 1 1099511627776")

        // Notes-page rendering accepts up to 100_000 px and delegates viewport clamping to SVGRenderer.
        try tallDeck.slides[0].setNotes("Speaker notes")
        let tallNotesSVG = try tallDeck.renderNotesSVG(slideAt: 0, pixelWidth: 100_000)
        let tallNotesRoot = try XML.parse(Data(tallNotesSVG.utf8))
        #expect(tallNotesRoot[attribute: "width"] == "32768")
        let notesHeight = try #require(tallNotesRoot[attribute: "height"].flatMap(Int.init))
        #expect((1...32_768).contains(notesHeight))

        let wideDeck = try Presentation()
        let wideSldSz = try #require(try wideDeck.presentationPart.dom().firstChild(named: "p:sldSz"))
        wideSldSz[attribute: "cx"] = "1099511627776"
        wideSldSz[attribute: "cy"] = "1"
        wideDeck.presentationPart.markDirty()

        let wideSVG = try wideDeck.renderSVG(slideAt: 0, pixelWidth: 1280)
        let wideRoot = try XML.parse(Data(wideSVG.utf8))
        #expect(wideRoot[attribute: "width"] == "1280")
        #expect(wideRoot[attribute: "height"] == "1")
        #expect(wideRoot[attribute: "viewBox"] == "0 0 1099511627776 1")

        // Non-positive pixelWidth and negative file extents clamp cleanly to >= 1 and >= 0 viewBox.
        let negativeDeck = try Presentation()
        let negSldSz = try #require(try negativeDeck.presentationPart.dom().firstChild(named: "p:sldSz"))
        negSldSz[attribute: "cx"] = "-914400"
        negSldSz[attribute: "cy"] = "-685800"
        negativeDeck.presentationPart.markDirty()

        let minWidthSVG = try negativeDeck.renderSVG(slideAt: 0, pixelWidth: Int.min)
        let minWidthRoot = try XML.parse(Data(minWidthSVG.utf8))
        #expect(minWidthRoot[attribute: "width"] == "1")
        #expect(minWidthRoot[attribute: "height"] == "1")
        #expect(minWidthRoot[attribute: "viewBox"] == "0 0 0 0")

        // Standard 16:9 aspect ratios and valid pixelWidth values in 1...32768 remain exact.
        let standardDeck = try Presentation()
        let std1280 = try XML.parse(Data(try standardDeck.renderSVG(slideAt: 0, pixelWidth: 1280).utf8))
        #expect(std1280[attribute: "width"] == "1280")
        #expect(std1280[attribute: "height"] == "720")
        #expect(std1280[attribute: "viewBox"] == "0 0 12192000 6858000")

        let std32k = try XML.parse(Data(try standardDeck.renderSVG(slideAt: 0, pixelWidth: 32_768).utf8))
        #expect(std32k[attribute: "width"] == "32768")
        #expect(std32k[attribute: "height"] == "18432")
    }

    @Test func deepCopyClonesFiveThousandLevelsOnSmallSecondaryStackWithIndependentNodes() throws {
        let depth = 5_000
        let root = XML.Element("n0", attributes: [("idx", "0"), ("role", "root")])
        root.append(.comment("header-comment"))
        root.append(.processingInstruction(target: "rostrum", data: "v=1"))
        root.append(.processingInstruction(target: "empty-pi", data: nil))

        var current = root
        for level in 1..<depth {
            let next = XML.Element("n\(level)", attributes: [("idx", "\(level)")])
            if level == depth / 2 {
                current.append(.text("mid-text"))
                current.append(.comment("mid-comment"))
            }
            current.appendElement(next)
            current = next
        }
        current.append(.text("leaf-payload"))

        let box = ThreadResultBox(root)
        let done = DispatchSemaphore(value: 0)
        let worker = Thread {
            box.cloned = box.source.deepCopy()
            done.signal()
        }
        worker.stackSize = 512 * 1024
        worker.start()
        done.wait()

        let clonedRoot = try #require(box.cloned)
        #expect(clonedRoot !== root)
        #expect(clonedRoot.children.count == 4)
        if case .comment(let c) = clonedRoot.children[0] {
            #expect(c == "header-comment")
        } else {
            Issue.record("Expected leading comment on cloned root")
        }
        if case .processingInstruction(let t1, let d1) = clonedRoot.children[1] {
            #expect(t1 == "rostrum" && d1 == "v=1")
        } else {
            Issue.record("Expected first PI on cloned root")
        }
        if case .processingInstruction(let t2, let d2) = clonedRoot.children[2] {
            #expect(t2 == "empty-pi" && d2 == nil)
        } else {
            Issue.record("Expected dataless PI on cloned root")
        }

        var origCursor: XML.Element? = root
        var copyCursor: XML.Element? = clonedRoot
        var visited = 0
        var copyLeaf: XML.Element?
        var origLeaf: XML.Element?
        while let o = origCursor, let c = copyCursor {
            #expect(o !== c)
            #expect(o.name == c.name)
            #expect(o.attributes.count == c.attributes.count)
            for (oa, ca) in zip(o.attributes, c.attributes) {
                #expect(oa.name == ca.name && oa.value == ca.value)
            }
            if visited == depth / 2 - 1 {
                #expect(c.children.count == 3)
                if case .text(let t) = c.children[0] { #expect(t == "mid-text") }
                else { Issue.record("Missing mid-text") }
                if case .comment(let cm) = c.children[1] { #expect(cm == "mid-comment") }
                else { Issue.record("Missing mid-comment") }
            }
            visited += 1
            let nextO = o.childElements.first
            let nextC = c.childElements.first
            if nextO == nil {
                origLeaf = o
                copyLeaf = c
            }
            origCursor = nextO
            copyCursor = nextC
        }
        #expect(visited == depth)

        let unwrappedOrigLeaf = try #require(origLeaf)
        let unwrappedCopyLeaf = try #require(copyLeaf)
        #expect(unwrappedCopyLeaf.textContent == "leaf-payload")
        unwrappedCopyLeaf.children = [.text("mutated-copy")]
        unwrappedCopyLeaf[attribute: "idx"] = "mutated"
        #expect(unwrappedOrigLeaf.textContent == "leaf-payload")
        #expect(unwrappedOrigLeaf[attribute: "idx"] == "\(depth - 1)")
    }
}
