import Foundation
import Testing
import Rostrum
@testable import LecternCore

/// Layer-1 deterministic shaping. These lock the contract the normalizer
/// enforces in code, independent of any prompt: no over-full slides, a hard band
/// cap, and figures shown as metrics — plus the guarantee that its output always
/// re-validates and still renders.
@Suite struct DeckNormalizerTests {
    private let n = DeckNormalizer()

    private func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("normalizer-test-\(ProcessInfo.processInfo.globallyUniqueString)")
    }

    private func bullets(_ texts: [String]) -> [Bullet] { texts.map { Bullet(text: $0) } }
    private func words(_ n: Int) -> [String] { (1...n).map { "Point number \($0)" } }

    // MARK: - Rule 1: split over-long lists

    @Test func chunkSizesStayThreeToFive() {
        for count in 7...24 {
            let sizes = n.chunkSizes(count)
            #expect(sizes.reduce(0, +) == count)                 // lossless
            #expect(sizes.allSatisfy { (3...6).contains($0) })   // never overflow, never a stub
            #expect(sizes.max()! - sizes.min()! <= 1)            // evenly distributed
        }
        #expect(n.chunkSizes(6) == [6])                          // at the cap → untouched
        #expect(n.chunkSizes(8) == [4, 4])
        #expect(n.chunkSizes(7) == [4, 3])
        #expect(n.chunkSizes(12) == [4, 4, 4])
    }

    @Test func splitsOverLongBulletSlide() {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", sectionId: "sec", layout: "bullets", title: "Too Many",
                    body: Body(bullets: bullets(words(8))), notes: "speaker note"),
        ])
        let out = n.normalize(deck)
        #expect(out.report.changed)
        #expect(out.deck.slides.count == 3)                      // title + two halves

        let parts = out.deck.slides.filter { $0.kind == .bullets }
        #expect(parts.count == 2)
        #expect(parts.allSatisfy { ($0.body?.bullets?.count ?? 0) == 4 })
        #expect(parts[0].title == "Too Many")
        #expect(parts[1].title == "Too Many (cont.)")
        #expect(Set(parts.map(\.id)).count == 2)                 // ids stay unique
        #expect(parts.allSatisfy { $0.sectionId == "sec" })      // section preserved
        #expect(parts[0].notes == "speaker note")
        #expect(parts[1].notes == nil)                           // notes not duplicated
    }

    @Test func leavesShortBulletSlideAlone() {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "bullets", title: "Fine", body: Body(bullets: bullets(words(5)))),
        ])
        let out = n.normalize(deck)
        #expect(!out.report.changed)
        #expect(out.deck == deck)
    }

    @Test func splitsOverLongAgendaIntoBulletSlides() {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "agenda", title: "Agenda", body: Body(items: words(9))),
        ])
        let out = n.normalize(deck)
        #expect(out.deck.slides.filter { $0.kind == .agenda }.isEmpty)   // agenda ≡ bullets when rendered
        let parts = out.deck.slides.filter { $0.kind == .bullets }
        #expect(parts.count == 2)
        #expect(parts.flatMap { $0.body?.bullets ?? [] }.count == 9)     // no items lost
    }

    @Test func leavesSevenItemAgendaAlone() {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "agenda", title: "Agenda", body: Body(items: words(7))),
        ])
        #expect(!n.normalize(deck).report.changed)
    }

    // MARK: - Rule 2: cap bands

    @Test func capsExcessBandsToDiagrams() {
        var slides = [IRSlide(id: "s0", layout: "title", title: "Opener")]
        for i in 0..<8 {
            slides.append(IRSlide(id: "b\(i)", layout: "bands", title: "Band \(i)",
                                  body: Body(items: ["A — x", "B — y", "C — z"])))
        }
        for i in 0..<3 { slides.append(IRSlide(id: "h\(i)", layout: "sectionHeader", title: "Break \(i)")) }
        // 12 slides → cap = ceil(12/4) = 3 bands kept.
        let out = n.normalize(DeckIR(meta: Meta(title: "T"), slides: slides))

        let kinds = out.deck.slides.map(\.kind)
        #expect(kinds.filter { $0 == .bands }.count == 3)            // cap honored
        #expect(kinds.filter { $0 == .diagram }.count == 5)          // excess converted
        // The kept bands are the earliest three.
        let bandTitles = out.deck.slides.filter { $0.kind == .bands }.compactMap(\.title)
        #expect(bandTitles == ["Band 0", "Band 1", "Band 2"])
        // Converted diagrams keep their items as a process diagram.
        let converted = out.deck.slides.first { $0.kind == .diagram }
        #expect(converted?.body?.diagram?.kind == "process")
        #expect(converted?.body?.diagram?.items == ["A — x", "B — y", "C — z"])
    }

    @Test func leavesBandsWithinCapAlone() {
        var slides = [IRSlide(id: "s0", layout: "title", title: "Opener")]
        for i in 0..<2 { slides.append(IRSlide(id: "b\(i)", layout: "bands", body: Body(items: ["A", "B", "C"]))) }
        for i in 0..<9 { slides.append(IRSlide(id: "h\(i)", layout: "sectionHeader", title: "H\(i)")) }
        // 12 slides → cap 3, only 2 bands → untouched.
        #expect(!n.normalize(DeckIR(meta: Meta(title: "T"), slides: slides)).report.changed)
    }

    // MARK: - Rule 3: promote figures

    @Test func promotesNumericBulletsToMetrics() throws {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "bullets", title: "By the numbers", body: Body(bullets: bullets([
                "40% of coastal homes are underinsured",
                "$2.3B in annual losses",
                "3× faster claims processing",
            ]))),
        ])
        let out = n.normalize(deck)
        let metrics = try #require(out.deck.slides.first { $0.kind == .metrics })
        let stats = try #require(metrics.body?.stats)
        #expect(stats.count == 3)
        #expect(stats[0].value == "40%")
        #expect(stats[0].label == "coastal homes are underinsured")   // leading "of " dropped
        #expect(stats[1].value == "$2.3B")
        #expect(stats[1].label == "annual losses")                    // leading "in " dropped
        #expect(stats[2].value == "3×")
        #expect(stats[2].label == "faster claims processing")
    }

    @Test func leavesProseBulletsAlone() {
        let deck = DeckIR(meta: Meta(title: "T"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "bullets", title: "Ideas", body: Body(bullets: bullets([
                "Insurers are repricing risk", "$2.3B in losses", "Regulators are watching",
            ]))),
        ])
        // Not ALL bullets are figures → left as bullets, untouched.
        #expect(!n.normalize(deck).report.changed)
    }

    @Test func loneNumberIsNotAMetric() {
        #expect(n.leadingStat("100") == nil)                          // no caption
        #expect(n.leadingStat("Growth was strong") == nil)           // no leading figure
        #expect(n.leadingStat("1,200 homes affected")?.value == "1,200")
        #expect(n.leadingStat("12 states filed suit")?.label == "states filed suit")
    }

    // MARK: - Safety net + determinism

    @Test func normalizedDeckStillValidates() throws {
        let deck = DeckIR(meta: Meta(title: "T"),
                          sections: [IRSection(id: "sec", title: "Body", slideIds: ["s1", "s2"])],
                          slides: [
            IRSlide(id: "s1", sectionId: "sec", layout: "title", title: "Opener"),
            IRSlide(id: "s2", sectionId: "sec", layout: "bullets", title: "Too Many",
                    body: Body(bullets: bullets(words(10)))),
        ])
        let out = n.normalize(deck)
        // The unchanged validator must accept the normalizer's output.
        _ = try DeckValidator().validate(out.deck, requestedSlideCount: 12, notesRequired: false)
    }

    @Test func isDeterministic() {
        var slides = [IRSlide(id: "s0", layout: "title", title: "Opener")]
        for i in 0..<6 { slides.append(IRSlide(id: "b\(i)", layout: "bands", body: Body(items: ["A", "B", "C"]))) }
        slides.append(IRSlide(id: "big", layout: "bullets", title: "N", body: Body(bullets: bullets(words(9)))))
        let deck = DeckIR(meta: Meta(title: "T"), slides: slides)
        #expect(n.normalize(deck).deck == n.normalize(deck).deck)   // pure function
    }

    @Test func splitDeckRendersToAValidFile() async throws {
        let deck = DeckIR(meta: Meta(title: "Split Renders"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Opener"),
            IRSlide(id: "s2", layout: "bullets", title: "Too Many", body: Body(bullets: bullets(words(10)))),
            IRSlide(id: "s3", layout: "closing", title: "Act now"),
        ])
        let out = n.normalize(deck)
        #expect(out.deck.slides.count == 4)                         // s2 split into two

        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRenderer().render(out.deck, designURL: nil, notesEnabled: false, into: dir)
        #expect(result.slideCount == 4)
        #expect(FileManager.default.fileExists(atPath: result.url.path))
    }
}
