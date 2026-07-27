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
        let rels = slide.part.rels
        let video = try #require(rels.first(ofType: RelType.video))
        let media = try #require(rels.first(ofType: RelType.media))
        #expect(video.target == media.target)
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
