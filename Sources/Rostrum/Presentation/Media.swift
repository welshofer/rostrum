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
    /// `p:pic`, so it must have a `blipFill`. Without one Rostrum embeds a
    /// transparent pixel over a dark solid fill, so the clip is a visible,
    /// clickable rectangle rather than nothing at all. Pass a real poster
    /// when you have one; for audio, PowerPoint's speaker icon is not
    /// synthesized.
    ///
    /// A `p:timing` node is written so the clip has play controls and starts
    /// on click — PowerPoint's own default for an inserted clip. Auto-play on
    /// slide entry is a different start condition and is not written.
    @discardableResult
    func addMedia(_ data: Data, format: MediaFormat, frame: Rect,
                  poster: Data? = nil, name: String? = nil) throws -> Picture {
        guard let package else {
            throw RostrumError.packageInvalid("this shape collection has no package attached")
        }

        // Validate the poster BEFORE touching the package. Sniffing after the
        // clip is already embedded would leave an orphan media part and two
        // dangling relationships behind on every rejected poster.
        let posterData = poster ?? Self.transparentPixelPNG
        guard let posterInfo = ImageSniffer.sniff(posterData) else {
            throw RostrumError.packageInvalid(
                "unrecognized poster image format (PNG, JPEG and GIF are supported)")
        }

        // The media part. Numbering spans every media clip regardless of
        // extension — PowerPoint numbers them sequentially, and a per-extension
        // counter would produce a confusing media1.mp4 next to a media1.mov.
        // Content type rides on an extension Default, the way PowerPoint
        // writes media.
        // Reuse an identical clip already in the package, the way image parts
        // dedup — embedding the same video twice should not double the file.
        let existing = package.parts.first {
            $0.key.value.hasPrefix("/ppt/media/") && $0.value.blob == data
        }?.key
        let mediaURI: PackURI
        if let existing {
            mediaURI = existing
        } else {
            let used = package.parts.keys.compactMap { uri -> Int? in
                let name = uri.filename
                guard uri.value.hasPrefix("/ppt/media/media"), name.hasPrefix("media") else { return nil }
                // Bounded: the stem comes from a zip entry name in the opened
                // file, and `(used.max() ?? 0) + 1` below traps on Int.max.
                guard let n = Int(stem), n >= 0, n < 1_000_000 else { return nil }
                return n
            }
            mediaURI = PackURI("/ppt/media/media\((used.max() ?? 0) + 1).\(format.fileExtension)")
            package.addPart(uri: mediaURI, contentType: format.contentType, blob: data)
            // A Default covers it; an Override would be redundant and is not
            // what PowerPoint writes.
            package.contentTypes.removeOverride(partName: mediaURI)
        }
        package.contentTypes.setDefault(extension: format.fileExtension,
                                        contentType: format.contentType)

        let target = part.uri.relativeReference(to: mediaURI)
        let linkRelType = format.isAudio ? RelType.audio : RelType.video
        let linkID = part.rels.add(type: linkRelType, target: target)
        let mediaID = part.rels.add(type: RelType.media, target: target)

        // The poster frame: a real image when given, else a 1×1 transparent PNG.
        let image = package.imagePart(for: posterData, info: posterInfo)
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
        // With no poster the blip is a transparent pixel, which would render
        // as nothing at all — an invisible shape the user cannot click. A
        // solid fill behind it keeps the clip visible and clickable.
        if poster == nil {
            let fill = XML.Element("a:solidFill")
            fill.appendElement(Color("3C3C3C").srgbElement())
            spPr.appendElement(fill)
        }
        pic.appendElement(spPr)

        try Slide.spTree(of: part).appendElement(pic)
        try registerMediaTiming(shapeID: id, isAudio: format.isAudio)
        part.markDirty()
        return Picture(element: pic, part: part, package: package)
    }

    /// Give the clip play controls.
    ///
    /// PowerPoint drives media from the slide's `p:timing` tree: without a
    /// `p:video`/`p:audio` node naming the shape, the clip renders as a still
    /// picture with **no** controls. The node is written with an indefinite
    /// start condition — click to play, which is PowerPoint's own default for
    /// an inserted clip — and appended to the timing root so several clips on
    /// one slide each get their own.
    private func registerMediaTiming(shapeID: Int, isAudio: Bool) throws {
        let slide = try part.dom()
        // p:timing is the last child of p:sld.
        let timing = slide.getOrAddChild("p:timing")
        let tnLst = timing.getOrAddChild("p:tnLst")

        // The timing root: one p:par > p:cTn[nodeType=tmRoot] per slide.
        let par: XML.Element
        if let existing = tnLst.firstChild(named: "p:par") {
            par = existing
        } else {
            par = XML.Element("p:par")
            let root = XML.Element("p:cTn", attributes: [
                ("id", "1"), ("dur", "indefinite"), ("restart", "never"), ("nodeType", "tmRoot"),
            ])
            root.appendElement(XML.Element("p:childTnLst"))
            par.appendElement(root)
            tnLst.appendElement(par)
        }
        guard let root = par.firstChild(named: "p:cTn") else { return }
        let childTnLst = root.getOrAddChild("p:childTnLst")

        // Timing node ids must be unique within the slide; 1 is the root.
        // Bounded on the way in: a p:cTn@id of Int.max would overflow the +1.
        let usedIDs = Self.timingIDs(in: timing).filter { OOXMLBounds.drawingElementID.contains($0) }
        let nodeID = Swift.min(usedIDs.max() ?? 1, OOXMLBounds.drawingElementID.upperBound - 1) + 1

        let media = XML.Element(isAudio ? "p:audio" : "p:video")
        let cMediaNode = XML.Element("p:cMediaNode", attributes: [("vol", "80000")])
        let cTn = XML.Element("p:cTn", attributes: [
            ("id", String(nodeID)), ("fill", "hold"), ("display", "0"),
        ])
        let stCondLst = XML.Element("p:stCondLst")
        stCondLst.appendElement(XML.Element("p:cond", attributes: [("delay", "indefinite")]))
        cTn.appendElement(stCondLst)
        let endCondLst = XML.Element("p:endCondLst")
        let endCond = XML.Element("p:cond", attributes: [("evt", "onStopped"), ("delay", "0")])
        let endTgt = XML.Element("p:tgtEl")
        endTgt.appendElement(XML.Element("p:spTgt", attributes: [("spid", String(shapeID))]))
        endCond.appendElement(endTgt)
        endCondLst.appendElement(endCond)
        cTn.appendElement(endCondLst)
        cMediaNode.appendElement(cTn)
        let tgtEl = XML.Element("p:tgtEl")
        tgtEl.appendElement(XML.Element("p:spTgt", attributes: [("spid", String(shapeID))]))
        cMediaNode.appendElement(tgtEl)
        media.appendElement(cMediaNode)
        childTnLst.appendElement(media)
    }

    /// Test hook for the id-uniqueness invariant.
    static func timingIDsForTesting(in element: XML.Element) -> [Int] { timingIDs(in: element) }

    /// Every `p:cTn@id` already used in a timing tree.
    private static func timingIDs(in element: XML.Element) -> [Int] {
        var ids: [Int] = []
        if element.name == "p:cTn", let id = element[attribute: "id"].flatMap({ Int($0) }) {
            ids.append(id)
        }
        for child in element.childElements { ids += timingIDs(in: child) }
        return ids
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
