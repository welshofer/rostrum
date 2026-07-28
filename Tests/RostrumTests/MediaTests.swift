import Foundation
import Testing
@testable import Rostrum

@Suite struct MediaTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(3.5))
    /// Not a real MP4 — Rostrum never decodes media, it only packages it.
    private let clip = Data("fake mp4 bytes for packaging".utf8)

    private func png() -> Data {
        func be32(_ v: Int) -> [UInt8] {
            [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
        }
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        b += be32(13); b += Array("IHDR".utf8)
        b += be32(320); b += be32(180); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }

    @Test func videoWiresBothRelationshipsToOnePart() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addMedia(clip, format: .mp4, frame: frame, poster: png())

        let reopened = try Presentation(data: try deck.serializedData())
        let slide = try reopened.slides[0]
        let picture = try #require(slide.shapes.all.first as? Picture)
        #expect(picture.isMedia)
        #expect(!picture.isAudio)
        #expect(picture.mediaData == clip)
        #expect(picture.mediaPart?.uri.value == "/ppt/media/media1.mp4")

        // PowerPoint needs both the legacy link and the modern media rel, and
        // they must point at the same part.
        // Assert the XML's OWN references resolve to the media part — not
        // that two rels built from the same local string are equal, which
        // cannot fail.
        let rels = slide.part.rels
        let nvPr = try #require(picture.element.firstChild(named: "p:nvPicPr")?
            .firstChild(named: "p:nvPr"))
        let linkID = try #require(nvPr.firstChild(named: "a:videoFile")?[attribute: "r:link"])
        let embedID = try #require(nvPr.firstChild(named: "p:extLst")?
            .firstChild(named: "p:ext")?.firstChild(named: "p14:media")?[attribute: "r:embed"])
        #expect(linkID != embedID, "the two references are distinct relationships")
        let linkRel = try #require(rels.relationship(withId: linkID))
        let embedRel = try #require(rels.relationship(withId: embedID))
        #expect(linkRel.type == RelType.video)
        #expect(embedRel.type == RelType.media)
        #expect(linkRel.target == embedRel.target, "both must resolve to the same media part")
        // The poster still has to be a real image relationship.
        #expect(rels.first(ofType: RelType.image) != nil)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func audioUsesTheAudioElementAndRelationship() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addMedia(Data("fake mp3".utf8), format: .mp3, frame: frame)

        let reopened = try Presentation(data: try deck.serializedData())
        let slide = try reopened.slides[0]
        let picture = try #require(slide.shapes.all.first as? Picture)
        #expect(picture.isAudio)
        #expect(picture.isMedia)
        #expect(slide.part.rels.first(ofType: RelType.audio) != nil)
        #expect(slide.part.rels.first(ofType: RelType.video) == nil)

        let nvPr = try #require(picture.element.firstChild(named: "p:nvPicPr")?
            .firstChild(named: "p:nvPr"))
        #expect(nvPr.firstChild(named: "a:audioFile") != nil)
        #expect(nvPr.firstChild(named: "a:videoFile") == nil)
    }

    @Test func mediaRidesOnAnExtensionDefaultNotAnOverride() throws {
        // PowerPoint writes media content types as extension Defaults; an
        // Override alongside is redundant and unlike what it produces.
        let deck = try Presentation()
        try deck.slides[0].shapes.addMedia(clip, format: .mp4, frame: frame)
        #expect(deck.package.contentTypes.defaults["mp4"] == "video/mp4")
        #expect(deck.package.contentTypes.overrides[PackURI("/ppt/media/media1.mp4")] == nil)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.package.contentTypes.contentType(for: PackURI("/ppt/media/media1.mp4"))
                == "video/mp4")
    }

    @Test func aPosterlessClipStillHasABlipFill() throws {
        // p:pic requires a blipFill; without a poster we embed a 1×1
        // transparent PNG rather than emit an invalid shape.
        let deck = try Presentation()
        let picture = try deck.slides[0].shapes.addMedia(clip, format: .mp4, frame: frame)
        let blip = try #require(picture.element.firstChild(named: "p:blipFill")?
            .firstChild(named: "a:blip"))
        let rId = try #require(blip[attribute: "r:embed"])
        #expect(try deck.slides[0].part.rels.relationship(withId: rId)?.type == RelType.image)
        #expect(try deck.validate().isEmpty)
    }

    @Test func severalClipsGetDistinctParts() throws {
        let deck = try Presentation()
        let shapes = try deck.slides[0].shapes
        try shapes.addMedia(clip, format: .mp4, frame: frame)
        try shapes.addMedia(Data("second clip".utf8), format: .mov, frame: frame)
        #expect(deck.package.parts[PackURI("/ppt/media/media1.mp4")] != nil)
        #expect(deck.package.parts[PackURI("/ppt/media/media2.mov")] != nil)
        #expect(deck.package.contentTypes.defaults["mov"] == "video/quicktime")
    }

    @Test func theSameClipEmbeddedTwiceIsStoredOnce() throws {
        let deck = try Presentation()
        let shapes = try deck.slides[0].shapes
        try shapes.addMedia(clip, format: .mp4, frame: frame)
        try shapes.addMedia(clip, format: .mp4, frame: frame)
        let mediaParts = deck.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/media") }
        #expect(mediaParts.count == 1, "an identical clip must not be stored twice")
    }

    @Test func clipsGetTimingNodesSoTheyHavePlayControls() throws {
        // Without a p:timing node naming the shape, PowerPoint renders the
        // clip as a still picture with no controls at all.
        let deck = try Presentation()
        let shapes = try deck.slides[0].shapes
        let video = try shapes.addMedia(clip, format: .mp4, frame: frame)
        let audio = try shapes.addMedia(Data("mp3".utf8), format: .mp3, frame: frame)

        let reopened = try Presentation(data: try deck.serializedData())
        let dom = try reopened.slides[0].part.dom()
        let timing = try #require(dom.firstChild(named: "p:timing"))
        let root = try #require(timing.firstChild(named: "p:tnLst")?.firstChild(named: "p:par")?
            .firstChild(named: "p:cTn"))
        #expect(root[attribute: "nodeType"] == "tmRoot")
        let children = try #require(root.firstChild(named: "p:childTnLst"))
        #expect(children.children(named: "p:video").count == 1)
        #expect(children.children(named: "p:audio").count == 1)

        // Each node must target its own shape by id, or the controls attach
        // to the wrong picture.
        func targetedShapeID(_ node: XML.Element) -> String? {
            node.firstChild(named: "p:cMediaNode")?.firstChild(named: "p:tgtEl")?
                .firstChild(named: "p:spTgt")?[attribute: "spid"]
        }
        let videoID = try #require(video.shapeID).description
        let audioID = try #require(audio.shapeID).description
        #expect(targetedShapeID(children.children(named: "p:video")[0]) == videoID)
        #expect(targetedShapeID(children.children(named: "p:audio")[0]) == audioID)

        // Timing node ids must be unique within the slide.
        let ids = ShapeCollection.timingIDsForTesting(in: timing)
        #expect(Set(ids).count == ids.count, "duplicate p:cTn ids: \(ids)")
        #expect(try reopened.validate().isEmpty)
    }

    @Test func aRejectedPosterLeavesNoOrphanPart() throws {
        // Validation must happen before the package is touched, or a caller
        // that retries ships every failed attempt's clip.
        let deck = try Presentation()
        #expect(throws: RostrumError.self) {
            try deck.slides[0].shapes.addMedia(
                clip, format: .mp4, frame: frame, poster: Data("not an image".utf8))
        }
        #expect(deck.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/") }.isEmpty)
        #expect(try deck.slides[0].part.rels.all(ofType: RelType.video).isEmpty)
        #expect(try deck.slides[0].part.rels.all(ofType: RelType.media).isEmpty)
    }

    @Test func mediaIsStoredNotDeflated() throws {
        // Re-DEFLATEing an already-compressed container is a full pass over
        // the largest payload in the deck for nothing.
        let deck = try Presentation()
        try deck.slides[0].shapes.addMedia(clip, format: .mp4, frame: frame)
        let reader = try ZipReader(data: try deck.serializedData())
        #expect(try reader.data(forEntry: "ppt/media/media1.mp4") == clip)
    }

    @Test func mediaSurvivesRoundTripByteIdentically() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addMedia(clip, format: .mp4, frame: frame, poster: png())
        let original = try deck.serializedData()
        let reopened = try Presentation(data: original)
        _ = try reopened.slides[0].shapes.all.compactMap { ($0 as? Picture)?.mediaData }
        #expect(try reopened.serializedData() == original)
    }

    @Test func formatLookupByExtension() throws {
        #expect(MediaFormat.forExtension("MP4") == .mp4)
        #expect(MediaFormat.forExtension("wav")?.isAudio == true)
        #expect(MediaFormat.forExtension("xyz") == nil)
    }
}

/// What PowerPoint actually writes for a video, measured against what Rostrum
/// writes — with `Fixtures/RealDecks/MovieAndComments.pptx` as the oracle.
///
/// Rostrum's media timing was built from the spec and never checked against a
/// real file. Now that one is in the corpus, the difference is measurable, and
/// pinning it is what stops "Rostrum writes PowerPoint's timing" from quietly
/// becoming true-sounding. It is a documented subset, and this says by how much.
@Suite struct MediaTimingGroundTruthTests {
    private static let realDeck: URL? = {
        guard let base = Bundle.module.resourceURL?
            .appendingPathComponent("Fixtures/RealDecks/MovieAndComments.pptx") else { return nil }
        return FileManager.default.fileExists(atPath: base.path) ? base : nil
    }()

    /// Every `p:timing` subtree in a deck, flattened to its XML text.
    private func timingXML(of deck: Presentation) throws -> String {
        var out = ""
        for index in 0..<deck.slides.count {
            let dom = try deck.slides[index].part.dom()
            guard let timing = dom.firstChild(named: "p:timing") else { continue }
            out += String(decoding: XML.document(timing), as: UTF8.self)
        }
        return out
    }

    @Test(.enabled(if: realDeck != nil))
    func powerPointDrivesAVideoWithMoreThanACMediaNode() throws {
        let deck = try Presentation(data: try Data(contentsOf: Self.realDeck!))
        let timing = try timingXML(of: deck)

        // The part Rostrum also writes.
        #expect(timing.contains("<p:video>"))
        #expect(timing.contains("<p:cMediaNode"))

        // The parts it does not. PowerPoint drives click-to-play from a
        // `mainSeq` effect issuing `playFrom(0.0)` at the clip, and makes a
        // click on the clip toggle pause via a second, interactive sequence.
        #expect(timing.contains("nodeType=\"mainSeq\""))
        #expect(timing.contains("playFrom(0.0)"))
        #expect(timing.contains("nodeType=\"interactiveSeq\""))
        #expect(timing.contains("togglePause"))
        #expect(timing.contains("presetClass=\"mediacall\""))

        // And it does NOT put an end condition on the media node itself,
        // where Rostrum writes `evt="onStopped"`.
        #expect(!timing.contains("onStopped"))
    }

    @Test func rostrumWritesTheMediaNodeAndNotTheEffectSequences() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addMedia(
            Data("clip".utf8), format: .mp4,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(3.5)))
        let timing = try timingXML(of: deck)

        // What we do write: the node that gives the clip transport controls.
        #expect(timing.contains("<p:video>"))
        #expect(timing.contains("<p:cMediaNode"))
        #expect(timing.contains("nodeType=\"tmRoot\""))

        // What we deliberately do not, pending a PowerPoint check. Change these
        // to `contains` in the same commit that starts emitting them — not
        // before, and not to make something else pass.
        #expect(!timing.contains("mainSeq"))
        #expect(!timing.contains("playFrom"))
        #expect(!timing.contains("interactiveSeq"))
        #expect(!timing.contains("togglePause"))

        // Ours carries an end condition PowerPoint's does not.
        #expect(timing.contains("onStopped"))
    }
}
