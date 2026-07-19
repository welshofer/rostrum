import Foundation
import Testing
@testable import Rostrum

/// The release-gate invariants proven at scale: reading a deck and re-serializing
/// it is byte-identical (lossless round-trip through inflate/deflate), and the
/// same build always yields the same bytes (determinism).
@Suite struct RoundTripCorpusTests {
    private var png: Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        b += be32(13); b += Array("IHDR".utf8); b += be32(8); b += be32(8); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }
    private let r = Rect(x: .inches(1), y: .inches(1), width: .inches(5), height: .inches(3))

    private var corpus: [(String, () throws -> Presentation)] {
        [
            ("plain", { try Presentation() }),
            ("builders", {
                let d = try Presentation()
                try d.titleSlide("Title", subtitle: "Sub", kicker: "Kick")
                try d.bulletSlide("Bullets", ["alpha", "beta", "gamma"])
                try d.sectionSlide("Section", number: 1)
                try d.twoColumnSlide("Two", left: ["l"], right: ["r"])
                return d
            }),
            ("designed", {
                let d = try Presentation()
                d.applyDesign(Design.parse("## Fonts\n- Heading: Georgia\n## Palette\n- Background: #0B1D33\n- Text: #F7F4EE\n- Accent 1: #18A999"))
                try d.titleSlide("Branded")
                try d.bulletSlide("On brand", ["x", "y"])
                return d
            }),
            ("table", {
                let d = try Presentation()
                let t = try d.slides[0].shapes.addTable(rows: 3, columns: 3,
                    frame: Rect(x: .inches(1), y: .inches(1), width: .inches(9), height: .inches(3)))
                t.setContents([["a", "b", "c"], ["1", "2", "3"], ["4", "5", "6"]])
                    .columnWidths([.inches(4), .inches(2.5), .inches(2.5)])
                    .styleBanded(style: d.style)
                return d
            }),
            ("chart", {
                let d = try Presentation()
                try d.chartSlide("Chart", .line, ChartData(categories: ["A", "B", "C"], name: "S", values: [1, 2, 3]))
                return d
            }),
            ("image+gradient", {
                let d = try Presentation()
                try d.slides[0].setBackground(.image(self.png))
                try d.slides[0].shapes.addShape(.rectangle, frame: self.r, fill: .gradient(.radial(from: Color("18A999"), to: Color("0B1D33"))))
                return d
            }),
            ("sections+footer+notes", {
                let d = try Presentation()
                try d.bulletSlide("One", ["a"])
                try d.bulletSlide("Two", ["b"])
                try d.setSections([("First", 0), ("Rest", 1)])
                try d.footer("Confidential").showSlideNumbers()
                try d.slides[0].setNotes(["talk track", "second beat"])
                return d
            }),
            ("merged", {
                let source = try Presentation()
                try source.bulletSlide("Imported", ["from another deck"])
                let dest = try Presentation()
                try dest.slides.importAll(from: source)
                return dest
            }),
        ]
    }

    @Test func reopenThenReserializeIsByteIdentical() throws {
        for (name, make) in corpus {
            let once = try make().serializedData()
            let twice = try Presentation(data: once).serializedData()
            #expect(once == twice, "\(name): reopen→reserialize is not byte-identical")
        }
    }

    @Test func buildingTheSameDeckTwiceIsByteIdentical() throws {
        for (name, make) in corpus {
            #expect(try make().serializedData() == make().serializedData(), "\(name): build is non-deterministic")
        }
    }

    @Test func everyCorpusDeckValidatesAndReopens() throws {
        for (name, make) in corpus {
            let deck = try make()
            #expect(try deck.validate().isEmpty, "\(name): validate() not empty")
            let reopened = try Presentation(data: try deck.serializedData())
            #expect(reopened.slides.count >= 1, "\(name)")
        }
    }
}
