import Foundation

/// A media format Rostrum can embed. The extension drives the package's
/// content-type Default, which is how PowerPoint decides what decoder to use.
public struct MediaFormat: Sendable, Equatable {
    /// File extension, lowercased, no dot.
    public let fileExtension: String
    public let contentType: String
    /// True for audio, false for video — they use different `p:nvPr` children.
    public let isAudio: Bool

    public init(fileExtension: String, contentType: String, isAudio: Bool) {
        self.fileExtension = fileExtension.lowercased()
        self.contentType = contentType
        self.isAudio = isAudio
    }

    public static let mp4 = MediaFormat(fileExtension: "mp4", contentType: "video/mp4", isAudio: false)
    public static let m4v = MediaFormat(fileExtension: "m4v", contentType: "video/x-m4v", isAudio: false)
    public static let mov = MediaFormat(fileExtension: "mov", contentType: "video/quicktime", isAudio: false)
    public static let avi = MediaFormat(fileExtension: "avi", contentType: "video/avi", isAudio: false)
    public static let wmv = MediaFormat(fileExtension: "wmv", contentType: "video/x-ms-wmv", isAudio: false)
    public static let mp3 = MediaFormat(fileExtension: "mp3", contentType: "audio/mpeg", isAudio: true)
    public static let m4a = MediaFormat(fileExtension: "m4a", contentType: "audio/mp4", isAudio: true)
    public static let wav = MediaFormat(fileExtension: "wav", contentType: "audio/wav", isAudio: true)

    /// The format for a file extension, when Rostrum knows it.
    public static func forExtension(_ ext: String) -> MediaFormat? {
        let all: [MediaFormat] = [.mp4, .m4v, .mov, .avi, .wmv, .mp3, .m4a, .wav]
        return all.first { $0.fileExtension == ext.lowercased() }
    }
}

public extension ShapeCollection {
    /// Embed a video or audio clip and place it as a picture shape.
    ///
    /// The media rides in `/ppt/media/`, wired with the **two** relationships
    /// PowerPoint requires from the same part: the legacy `video`/`audio` link
    /// that older readers follow, and the modern `media` relationship
    /// referenced from the `p14:media` extension. Both point at the same part.
    ///
    /// `poster` is the still frame shown before playback — the shape is a
    /// `p:pic`, so it must have a `blipFill`. Without one, Rostrum embeds a
    /// 1×1 transparent PNG and PowerPoint renders the frame black, which is
    /// what it does for a poster-less clip anyway.
    ///
    /// The clip is playable from the media controls. Rostrum does not write a
    /// `p:timing` tree, so it does not auto-play on slide entry; set that in
    /// PowerPoint if you need it.
    @discardableResult
    func addMedia(_ data: Data, format: MediaFormat, frame: Rect,
                  poster: Data? = nil, name: String? = nil) throws -> Picture {
        guard let package else {
            throw RostrumError.packageInvalid("this shape collection has no package attached")
        }

        // The media part. Numbering spans every media clip regardless of
        // extension — PowerPoint numbers them sequentially, and a per-extension
        // counter would produce a confusing media1.mp4 next to a media1.mov.
        // Content type rides on an extension Default, the way PowerPoint
        // writes media.
        let used = package.parts.keys.compactMap { uri -> Int? in
            let name = uri.filename
            guard uri.value.hasPrefix("/ppt/media/media"), name.hasPrefix("media") else { return nil }
            let stem = name.prefix(while: { $0 != "." }).dropFirst("media".count)
            return Int(stem)
        }
        let n = (used.max() ?? 0) + 1
        let mediaURI = PackURI("/ppt/media/media\(n).\(format.fileExtension)")
        package.contentTypes.setDefault(extension: format.fileExtension,
                                        contentType: format.contentType)
        package.addPart(uri: mediaURI, contentType: format.contentType, blob: data)
        // A Default covers it; an Override would be redundant and is not what
        // PowerPoint writes.
        package.contentTypes.removeOverride(partName: mediaURI)

        let target = part.uri.relativeReference(to: mediaURI)
        let linkRelType = format.isAudio ? RelType.audio : RelType.video
        let linkID = part.rels.add(type: linkRelType, target: target)
        let mediaID = part.rels.add(type: RelType.media, target: target)

        // The poster frame: a real image when given, else a 1×1 transparent PNG.
        let posterData = poster ?? Self.transparentPixelPNG
        guard let info = ImageSniffer.sniff(posterData) else {
            throw RostrumError.packageInvalid("unrecognized poster image format")
        }
        let image = package.imagePart(for: posterData, info: info)
        let posterID = part.rels.add(
            type: RelType.image, target: part.uri.relativeReference(to: image.uri))

        let id = try Slide.nextShapeID(of: part)
        let pic = XML.Element("p:pic")

        let nvPicPr = XML.Element("p:nvPicPr")
        let cNvPr = XML.Element("p:cNvPr", attributes: [
            ("id", String(id)),
            ("name", name ?? (format.isAudio ? "Audio \(id)" : "Video \(id)")),
        ])
        // The legacy link lives on cNvPr as an hlinkClick with a play action.
        let hlink = XML.Element("a:hlinkClick", attributes: [
            ("r:id", ""), ("action", "ppaction://media"),
        ])
        cNvPr.appendElement(hlink)
        nvPicPr.appendElement(cNvPr)

        let cNvPicPr = XML.Element("p:cNvPicPr")
        cNvPicPr.appendElement(XML.Element("a:picLocks", attributes: [("noChangeAspect", "1")]))
        nvPicPr.appendElement(cNvPicPr)

        let nvPr = XML.Element("p:nvPr")
        nvPr.appendElement(XML.Element(format.isAudio ? "a:audioFile" : "a:videoFile",
                                       attributes: [("r:link", linkID)]))
        // p14:media is what modern PowerPoint actually reads; it lives in an
        // extension so older readers ignore it.
        let extLst = XML.Element("p:extLst")
        let ext = XML.Element("p:ext", attributes: [("uri", Self.mediaExtensionURI)])
        ext.appendElement(XML.Element("p14:media", attributes: [
            ("xmlns:p14", Self.p14Namespace), ("r:embed", mediaID),
        ]))
        extLst.appendElement(ext)
        nvPr.appendElement(extLst)
        nvPicPr.appendElement(nvPr)
        pic.appendElement(nvPicPr)

        let blipFill = XML.Element("p:blipFill")
        blipFill.appendElement(XML.Element("a:blip", attributes: [("r:embed", posterID)]))
        let stretch = XML.Element("a:stretch")
        stretch.appendElement(XML.Element("a:fillRect"))
        blipFill.appendElement(stretch)
        pic.appendElement(blipFill)

        let spPr = XML.Element("p:spPr")
        let xfrm = XML.Element("a:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [
            ("x", String(frame.x.rawValue)), ("y", String(frame.y.rawValue)),
        ]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [
            ("cx", String(Swift.max(0, frame.width.rawValue))),
            ("cy", String(Swift.max(0, frame.height.rawValue))),
        ]))
        spPr.appendElement(xfrm)
        let prstGeom = XML.Element("a:prstGeom", attributes: [("prst", "rect")])
        prstGeom.appendElement(XML.Element("a:avLst"))
        spPr.appendElement(prstGeom)
        pic.appendElement(spPr)

        try Slide.spTree(of: part).appendElement(pic)
        part.markDirty()
        return Picture(element: pic, part: part, package: package)
    }

    /// The `p:ext@uri` PowerPoint uses for the media extension.
    private static let mediaExtensionURI = "{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}"
    private static let p14Namespace = "http://schemas.microsoft.com/office/powerpoint/2010/main"

    /// 1×1 fully transparent PNG — the poster of last resort.
    private static let transparentPixelPNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
        0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54,
        0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
        0x0D, 0x0A, 0x2D, 0xB4,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ])
}

public extension Picture {
    /// The embedded media clip's part, when this picture is a video or audio
    /// placeholder rather than a still image.
    var mediaPart: Part? {
        guard let rId = mediaRelationshipID,
              let rel = part.rels.relationship(withId: rId),
              let package else { return nil }
        return try? package.part(
            at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
    }

    /// The clip's bytes, when this picture carries media.
    var mediaData: Data? { mediaPart?.blob }

    /// True when this picture is an audio clip rather than video or a still.
    var isAudio: Bool {
        element.firstChild(named: "p:nvPicPr")?
            .firstChild(named: "p:nvPr")?.firstChild(named: "a:audioFile") != nil
    }

    /// True when this picture carries a video or audio clip.
    var isMedia: Bool { mediaRelationshipID != nil }

    /// The `a:videoFile`/`a:audioFile` relationship id.
    private var mediaRelationshipID: String? {
        let nvPr = element.firstChild(named: "p:nvPicPr")?.firstChild(named: "p:nvPr")
        guard let file = nvPr?.firstChild(named: "a:videoFile")
            ?? nvPr?.firstChild(named: "a:audioFile") else { return nil }
        return file[attribute: "r:link"]
    }
}
