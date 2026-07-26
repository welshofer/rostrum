import Foundation

/// One font family's style variants, each the raw bytes of a `.ttf`/`.otf`.
public struct FontFaces: Sendable {
    public var regular: Data
    public var bold: Data?
    public var italic: Data?
    public var boldItalic: Data?

    public init(regular: Data, bold: Data? = nil, italic: Data? = nil, boldItalic: Data? = nil) {
        self.regular = regular
        self.bold = bold
        self.italic = italic
        self.boldItalic = boldItalic
    }
}

/// Wraps raw sfnt (TTF/OTF) bytes in an EOT-Lite container — the exact form
/// PowerPoint stores in `/ppt/fonts/*.fntdata`. This is NOT the Word ODTTF
/// obfuscation (that is WordprocessingML only): Flags = 0 means the complete
/// font bytes are appended unmodified after an ~82-byte metadata header.
enum EOTLite {
    /// fsType embedding-restriction bits (OS/2 table): Restricted License.
    static let fsTypeRestricted: UInt16 = 0x0002

    /// The OS/2 `fsType` field, if the sfnt can be parsed; nil otherwise.
    static func fsType(of font: Data) -> UInt16? {
        let b = [UInt8](font)
        guard b.count >= 12 else { return nil }
        func be16(_ o: Int) -> Int { Int(b[o]) << 8 | Int(b[o + 1]) }
        func be32(_ o: Int) -> Int { Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) }
        let numTables = be16(4)
        var rec = 12
        for _ in 0..<numTables {
            guard rec + 16 <= b.count else { return nil }
            let tag = String(decoding: b[rec..<rec + 4], as: UTF8.self)
            if tag == "OS/2" {
                let off = be32(rec + 8)
                guard off + 10 <= b.count else { return nil }
                return UInt16(be16(off + 8))   // fsType at offset 8 within OS/2
            }
            rec += 16
        }
        return nil
    }

    /// EOT-Lite `MagicNumber`, at offset 34 of the header.
    static let magicNumber = 0x504C

    /// Recover the raw sfnt bytes from an EOT-Lite part. Returns nil when the
    /// container is malformed, or when `Flags` is non-zero — set flags mean
    /// XOR-obfuscated or MTX-compressed font data, which is not plain sfnt.
    /// Untrusted input: every read is bounds-checked, nothing traps.
    static func unwrap(_ eot: Data) -> Data? {
        let b = [UInt8](eot)
        guard b.count >= 82 else { return nil }
        func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
        func u32(_ o: Int) -> Int {
            Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24
        }
        guard u16(34) == magicNumber, u32(12) == 0 else { return nil }
        let fontDataSize = u32(4)
        guard fontDataSize > 0, fontDataSize <= b.count - 82 else { return nil }
        // The font is appended last, so it is the trailing FontDataSize bytes —
        // no need to re-derive the variable-length name block.
        return Data(eot.suffix(fontDataSize))
    }

    static func wrap(_ font: Data, typeface: String, style: String,
                     weight: UInt32, italic: Bool) -> Data {
        var header = [UInt8]()
        func u16(_ v: UInt16) { header.append(UInt8(v & 0xFF)); header.append(UInt8(v >> 8)) }
        func u32(_ v: UInt32) { for s in [0, 8, 16, 24] { header.append(UInt8((v >> UInt32(s)) & 0xFF)) } }

        let fsType = self.fsType(of: font) ?? 0
        func nameBlock(_ s: String) -> [UInt8] {
            let utf16 = Array(s.utf16)
            var out = [UInt8]()
            out.append(UInt8((utf16.count * 2) & 0xFF)); out.append(UInt8((utf16.count * 2) >> 8))
            for u in utf16 { out.append(UInt8(u & 0xFF)); out.append(UInt8(u >> 8)) }
            out.append(0); out.append(0)   // trailing u16 padding
            return out
        }
        // Four name records; each nameBlock already appends its own trailing
        // u16 padding, so the FullName block's padding IS the v2 Padding5. Only
        // the RootStringSize (u16, 0) + empty RootString remain for the tail.
        let names = nameBlock(typeface) + nameBlock(style) + nameBlock("Version 1.0")
            + nameBlock("\(typeface) \(style)")
        let tailSize = 2
        let eotSize = UInt32(82 + names.count + tailSize + font.count)

        u32(eotSize)                 // EOTSize
        u32(UInt32(font.count))       // FontDataSize
        u32(0x0002_0001)              // Version
        u32(0)                        // Flags (no MTX, no XOR)
        header.append(contentsOf: [UInt8](repeating: 0, count: 10))   // PANOSE
        header.append(0x01)          // Charset = DEFAULT
        header.append(italic ? 1 : 0)
        u32(weight)                   // Weight
        u16(fsType)
        u16(0x504C)                   // MagicNumber
        header.append(contentsOf: [UInt8](repeating: 0, count: 16))   // UnicodeRange1-4
        header.append(contentsOf: [UInt8](repeating: 0, count: 8))    // CodePageRange1-2
        u32(0)                        // CheckSumAdjustment
        header.append(contentsOf: [UInt8](repeating: 0, count: 16))   // Reserved1-4
        u16(0)                        // Padding1
        // header is now 82 bytes.

        var out = Data(header)
        out.append(contentsOf: names)   // includes Padding5 (FullName's trailing pad)
        out.append(0); out.append(0)    // RootStringSize = 0 (empty RootString)
        out.append(font)
        return out
    }
}

extension Presentation {
    /// Embed a font so text in `typeface` renders identically on machines
    /// lacking it. Pass the raw `.ttf`/`.otf` file bytes for each style; each
    /// is EOT-Lite-wrapped into a `/ppt/fonts/fontN.fntdata` part, related
    /// from `presentation.xml`, and listed in `p:embeddedFontLst`. The
    /// presentation is marked `embedTrueTypeFonts="1"`.
    ///
    /// Throws `RostrumError.fontEmbeddingRestricted` if a face's OS/2 `fsType`
    /// forbids embedding, unless `allowRestrictedLicense` is true.
    public func embedFont(_ typeface: String, faces: FontFaces,
                          allowRestrictedLicense: Bool = false) throws {
        let variants: [(tag: String, style: String, weight: UInt32, italic: Bool, data: Data?)] = [
            ("p:regular", "Regular", 400, false, faces.regular),
            ("p:bold", "Bold", 700, false, faces.bold),
            ("p:italic", "Italic", 400, true, faces.italic),
            ("p:boldItalic", "Bold Italic", 700, true, faces.boldItalic),
        ]

        package.contentTypes.setDefault(extension: "fntdata", contentType: "application/x-fontdata")

        let embeddedFont = XML.Element("p:embeddedFont")
        embeddedFont.appendElement(XML.Element("p:font", attributes: [("typeface", typeface)]))

        for v in variants {
            guard let data = v.data else { continue }
            if !allowRestrictedLicense, let fsType = EOTLite.fsType(of: data),
               fsType & EOTLite.fsTypeRestricted != 0 {
                throw RostrumError.fontEmbeddingRestricted(typeface)
            }
            var n = 1
            while package.parts[PackURI("/ppt/fonts/font\(n).fntdata")] != nil { n += 1 }
            let uri = PackURI("/ppt/fonts/font\(n).fntdata")
            let wrapped = EOTLite.wrap(data, typeface: typeface, style: v.style,
                                       weight: v.weight, italic: v.italic)
            package.addPart(uri: uri, contentType: "application/x-fontdata", blob: wrapped)
            package.contentTypes.removeOverride(partName: uri)   // rides the Default
            let rId = presentationPart.rels.add(
                type: RelType.font, target: presentationPart.uri.relativeReference(to: uri))
            embeddedFont.appendElement(XML.Element(v.tag, attributes: [("r:id", rId)]))
        }

        let dom = try presentationPart.dom()
        dom[attribute: "embedTrueTypeFonts"] = "1"
        dom[attribute: "saveSubsetFonts"] = "0"
        // embeddedFontLst sits after sldSz/notesSz, before custShowLst… .
        let list = dom.getOrAddChild("p:embeddedFontLst", beforeAnyOf: [
            "p:custShowLst", "p:photoAlbum", "p:custDataLst", "p:kinsoku",
            "p:defaultTextStyle", "p:modifyVerifier", "p:extLst",
        ])
        list.appendElement(embeddedFont)
        presentationPart.markDirty()
    }
}

extension Presentation {
    /// Register the deck's own embedded fonts into `fonts`, so text
    /// measurement works on a deck that carries its typefaces with it.
    ///
    /// Reads `p:embeddedFontLst`, unwraps each EOT-Lite part back to raw sfnt
    /// bytes, and registers it under the deck's declared typeface name (plus
    /// whatever family names the font itself carries). One face per family —
    /// the regular weight when present — because metrics are keyed by family
    /// (see `FontLibrary.register`). Returns the typefaces registered.
    ///
    /// Explicit by design: nothing registers fonts behind your back, so
    /// output stays deterministic unless you ask for this.
    @discardableResult
    public func registerEmbeddedFonts() -> [String] {
        guard let dom = try? presentationPart.dom() else { return [] }
        let embeddedFonts = dom.firstChild(named: "p:embeddedFontLst")?
            .children(named: "p:embeddedFont") ?? []
        var registered: [String] = []
        for embedded in embeddedFonts {
            guard let typeface = embedded.firstChild(named: "p:font")?[attribute: "typeface"] else {
                continue
            }
            // Regular first: it is the face measurement should use.
            for tag in ["p:regular", "p:bold", "p:italic", "p:boldItalic"] {
                guard let rId = embedded.firstChild(named: tag)?[attribute: "r:id"],
                      let rel = presentationPart.rels.relationship(withId: rId) else { continue }
                let uri = PackURI.resolve(target: rel.target, relativeTo: presentationPart.uri.baseURI)
                guard let part = try? package.part(at: uri),
                      let sfnt = EOTLite.unwrap(part.blob),
                      (try? fonts.register(sfnt, aliases: [typeface])) != nil else { continue }
                registered.append(typeface)
                break
            }
        }
        return registered
    }
}

extension RelType {
    public static let font = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/font"
}

extension Shape {
    /// Accessibility alternative text (`p:cNvPr@descr`).
    public var altText: String? {
        get { cNvPr?[attribute: "descr"] }
        set {
            cNvPr?[attribute: "descr"] = newValue
            part.markDirty()
        }
    }

    /// The shape's non-visual `p:cNvPr` (works for sp, pic, and graphicFrame,
    /// whose first child is the nvXxxPr container).
    private var cNvPr: XML.Element? {
        element.childElements.first?.firstChild(named: "p:cNvPr")
    }
}
