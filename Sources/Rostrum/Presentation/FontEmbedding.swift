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
    /// Embed raw `.ttf`/`.otf` faces in EOT-Lite parts for use by PowerPoint.
    /// Family names are caller-owned; native rendering depends on the consuming
    /// application. Embedding does not register fonts for local measurement.
    ///
    /// Reuses identical raw font bytes for an existing case-insensitive family
    /// and style, preserving its original wrapper and metadata. Adds missing
    /// styles without removing omitted ones. Different bytes for an existing
    /// style, ambiguous declarations or broken references throw `packageInvalid`.
    /// A repeated request with identical faces leaves the package byte-identical.
    ///
    /// Throws `fontEmbeddingRestricted` if a supplied face's OS/2 `fsType` forbids
    /// embedding, unless `allowRestrictedLicense` is true. Size limits throw
    /// `fontCorrupt`. All validation finishes before any package mutation.
    public func embedFont(_ typeface: String, faces: FontFaces,
                          allowRestrictedLicense: Bool = false) throws {
        let plan = try FontEmbeddingPlan(typeface: typeface, faces: faces,
            allowRestrictedLicense: allowRestrictedLicense, presentation: presentationPart, package: package)
        plan.commit(to: package, presentation: presentationPart)
    }
}

extension Presentation {
    /// Register the deck's own embedded fonts into `fonts`, so text
    /// measurement works on a deck that carries its typefaces with it.
    ///
    /// Reads `p:embeddedFontLst`, unwraps each EOT-Lite part back to raw sfnt
    /// bytes, and registers it under the deck's declared typeface name (plus
    /// whatever family names the font itself carries). Every supplied variant
    /// is registered under its declared style. Returns each registered family once.
    ///
    /// Explicit by design: nothing registers fonts behind your back, so
    /// output stays deterministic unless you ask for this.
    @discardableResult
    public func registerEmbeddedFonts() -> [String] {
        guard let dom = try? presentationPart.dom() else { return [] }
        guard let list = EmbeddedFontXML.children(dom, "embeddedFontLst").first else { return [] }
        let rootScope = EmbeddedFontXML.scope(dom)
        let listScope = EmbeddedFontXML.scope(list, rootScope)
        let embeddedFonts = EmbeddedFontXML.children(list, "embeddedFont", inheriting: rootScope)
        var registered: [String] = []
        for embedded in embeddedFonts {
            let embeddedScope = EmbeddedFontXML.scope(embedded, listScope)
            guard let typeface = EmbeddedFontXML.children(embedded, "font", inheriting: listScope).first?[attribute: "typeface"] else {
                continue
            }
            let variants = [("regular", false, false), ("bold", true, false),
                            ("italic", false, true), ("boldItalic", true, true)]
            for (tag, bold, italic) in variants {
                guard let face = EmbeddedFontXML.children(embedded, tag, inheriting: listScope).first else { continue }
                let scope = EmbeddedFontXML.scope(face, embeddedScope)
                guard let rId = face.attributes.first(where: {
                    EmbeddedFontXML.expanded($0.name, scope, attribute: true) == "{\(EmbeddedFontXML.relationships)}id"
                })?.value, let rel = presentationPart.rels.relationship(withId: rId),
                      rel.type == RelType.font, !rel.isExternal else { continue }
                let uri = PackURI.resolve(target: rel.target, relativeTo: presentationPart.uri.baseURI)
                guard let part = try? package.part(at: uri),
                      let sfnt = EOTLite.unwrap(part.blob),
                      (try? fonts.register(sfnt, face: FontFaceKey(
                        family: typeface, bold: bold, italic: italic))) != nil else { continue }
                if !registered.contains(typeface) { registered.append(typeface) }
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
