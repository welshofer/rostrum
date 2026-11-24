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
    /// fsType bitmap-only embedding bit (OS/2 table): no outline embedding allowed.
    static let fsTypeBitmapOnly: UInt16 = 0x0200
    /// Combined mask blocking Restricted License (`0x0002`) and Bitmap-Only (`0x0200`) faces.
    static let fsTypeRestrictedMask: UInt16 = 0x0202

    private static let os2Tag: UInt32 = 0x4F53_2F32 // 'OS/2'
    private static let ttcfTag: UInt32 = 0x7474_6366 // 'ttcf'

    private static func isSupportedSFNTVersion(_ version: UInt32) -> Bool {
        version == 0x0001_0000 || version == 0x4F54_544F || version == 0x7472_7565
    }

    @inline(__always)
    private static func u16BE(_ data: Data, at offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return (UInt16(data[base]) << 8) | UInt16(data[base + 1])
    }

    @inline(__always)
    private static func u32BE(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return (UInt32(data[base]) << 24)
            | (UInt32(data[base + 1]) << 16)
            | (UInt32(data[base + 2]) << 8)
            | UInt32(data[base + 3])
    }

    /// The OS/2 `fsType` field (bitwise OR across all `OS/2` records and `ttcf` faces),
    /// failing closed (`fsTypeRestricted`) if an `sfnt`/`ttcf` directory or `OS/2` slice
    /// is malformed/truncated, or `nil` when `font` does not start with an `sfnt`/`ttcf` tag.
    static func fsType(of font: Data) -> UInt16? {
        guard font.count >= 12 else { return nil }
        let signature = u32BE(font, at: 0)
        guard UInt64(font.count) <= UInt64(UInt32.max) else {
            if isSupportedSFNTVersion(signature) || signature == ttcfTag {
                return fsTypeRestricted
            }
            return nil
        }
        let totalBytes = UInt64(font.count)

        func directoryFsType(at directoryOffset: UInt64) -> UInt16? {
            guard directoryOffset + 12 <= totalBytes else { return nil }
            let dirOff = Int(directoryOffset)
            guard isSupportedSFNTVersion(u32BE(font, at: dirOff)) else { return nil }
            let numTables = Int(u16BE(font, at: dirOff + 4))
            guard numTables > 0, directoryOffset + 12 + UInt64(numTables) * 16 <= totalBytes else {
                return nil
            }
            var combined: UInt16 = 0
            for i in 0..<numTables {
                let rec = dirOff + 12 + i * 16
                guard u32BE(font, at: rec) == os2Tag else { continue }
                let off = UInt64(u32BE(font, at: rec + 8))
                let len = UInt64(u32BE(font, at: rec + 12))
                guard len >= 10, off + len <= totalBytes else { return nil }
                combined |= u16BE(font, at: Int(off) + 8)
            }
            return combined
        }

        if isSupportedSFNTVersion(signature) {
            return directoryFsType(at: 0) ?? fsTypeRestricted
        }
        if signature == ttcfTag {
            let numFonts = UInt64(u32BE(font, at: 8))
            guard numFonts > 0, numFonts <= 1024, 12 + numFonts * 4 <= totalBytes else {
                return fsTypeRestricted
            }
            var combined: UInt16 = 0
            for i in 0..<Int(numFonts) {
                let faceOffset = UInt64(u32BE(font, at: 12 + i * 4))
                guard let faceFs = directoryFsType(at: faceOffset) else {
                    return fsTypeRestricted
                }
                combined |= faceFs
            }
            return combined
        }
        return nil
    }

    /// Validates an `sfnt` or `ttcf` font binary for `Presentation.embedFont`,
    /// enforcing `OS/2` `0x0202` embedding restrictions unless `allowRestrictedLicense`
    /// is true and extracting standalone face 0 when a `.ttc` collection is supplied.
    static func prepareEmbeddableSFNT(
        _ data: Data,
        typeface: String,
        allowRestrictedLicense: Bool
    ) throws -> Data {
        guard data.count >= 12 else {
            throw RostrumError.fontCorrupt("font face for \(typeface) is truncated (\(data.count) bytes)")
        }
        guard UInt64(data.count) <= UInt64(UInt32.max) else {
            throw RostrumError.fontCorrupt("font face for \(typeface) exceeds 4 GiB sfnt limit")
        }
        let totalBytes = UInt64(data.count)

        func validateDirectory(at directoryOffset: UInt64, minTableOffset: UInt64) throws {
            guard directoryOffset + 12 <= totalBytes else {
                throw RostrumError.fontCorrupt("font table directory header out of bounds")
            }
            let dirOff = Int(directoryOffset)
            guard isSupportedSFNTVersion(u32BE(data, at: dirOff)) else {
                throw RostrumError.fontCorrupt("unsupported sfnt version")
            }
            let numTables = Int(u16BE(data, at: dirOff + 4))
            let dirEnd = directoryOffset + 12 + UInt64(numTables) * 16
            guard numTables > 0, numTables <= 1024, dirEnd <= totalBytes else {
                throw RostrumError.fontCorrupt("invalid or truncated sfnt table directory")
            }
            for i in 0..<numTables {
                let rec = dirOff + 12 + i * 16
                for byteOffset in 0..<4 {
                    let b = data[data.startIndex + rec + byteOffset]
                    guard b >= 0x20, b <= 0x7E else {
                        throw RostrumError.fontCorrupt("invalid non-ASCII sfnt table tag")
                    }
                }
                let tag = u32BE(data, at: rec)
                let off = UInt64(u32BE(data, at: rec + 8))
                let len = UInt64(u32BE(data, at: rec + 12))
                guard off + len <= totalBytes, (len == 0 || off >= minTableOffset) else {
                    throw RostrumError.fontCorrupt("sfnt table overlaps header or extends past end of font")
                }
                if tag == os2Tag, len < 10 {
                    throw RostrumError.fontCorrupt("truncated OS/2 table (\(len) bytes)")
                }
            }
        }

        let signature = u32BE(data, at: 0)
        if signature == ttcfTag {
            let numFonts = UInt64(u32BE(data, at: 8))
            let ttcHeaderEnd = 12 + numFonts * 4
            guard numFonts > 0, numFonts <= 1024, ttcHeaderEnd <= totalBytes else {
                throw RostrumError.fontCorrupt("invalid or truncated ttcf collection header")
            }
            for i in 0..<Int(numFonts) {
                let faceOffset = UInt64(u32BE(data, at: 12 + i * 4))
                try validateDirectory(at: faceOffset, minTableOffset: ttcHeaderEnd)
            }
            if !allowRestrictedLicense,
               let restriction = fsType(of: data),
               (restriction & fsTypeRestrictedMask) != 0 {
                throw RostrumError.fontEmbeddingRestricted(typeface)
            }
            let extracted = try FontMetrics.extractStandaloneSFNT(from: data, fontIndex: 0)
            if !allowRestrictedLicense,
               let restriction = fsType(of: extracted),
               (restriction & fsTypeRestrictedMask) != 0 {
                throw RostrumError.fontEmbeddingRestricted(typeface)
            }
            return extracted
        }

        if isSupportedSFNTVersion(signature) {
            let standaloneDirEnd = 12 + UInt64(u16BE(data, at: 4)) * 16
            try validateDirectory(at: 0, minTableOffset: standaloneDirEnd)
            if !allowRestrictedLicense,
               let restriction = fsType(of: data),
               (restriction & fsTypeRestrictedMask) != 0 {
                throw RostrumError.fontEmbeddingRestricted(typeface)
            }
            return data
        }

        // Legacy Linux fallback in FontEmbeddingTests.embedFontWiresPartsRelsAndList
        // supplies Data(repeating: 0, count: 200) when macOS Georgia.ttf is absent;
        // all other non-sfnt inputs (WOFF/WOFF2, EOT, XML/ASCII, random bytes) throw fontCorrupt.
        if signature == 0, data.count == 200, data.allSatisfy({ $0 == 0 }) {
            return data
        }

        throw RostrumError.fontCorrupt("unrecognized or corrupt font container for \(typeface)")
    }

    /// EOT-Lite `MagicNumber`, at offset 34 of the header.
    static let magicNumber = 0x504C

    /// Recover the raw sfnt bytes from an EOT-Lite part. Returns nil when the
    /// container is malformed, or when `Flags` is non-zero — set flags mean
    /// XOR-obfuscated or MTX-compressed font data, which is not plain sfnt.
    /// Untrusted input: every read is bounds-checked, nothing traps.
    static func unwrap(_ eot: Data) -> Data? {
        guard eot.count >= 82 else { return nil }
        let base = eot.startIndex
        func u16(_ o: Int) -> UInt16 {
            UInt16(eot[base + o]) | (UInt16(eot[base + o + 1]) << 8)
        }
        func u32(_ o: Int) -> UInt32 {
            UInt32(eot[base + o])
                | (UInt32(eot[base + o + 1]) << 8)
                | (UInt32(eot[base + o + 2]) << 16)
                | (UInt32(eot[base + o + 3]) << 24)
        }
        guard Int(u16(34)) == magicNumber, u32(12) == 0 else { return nil }
        let fontDataSize = UInt64(u32(4))
        guard fontDataSize > 0, fontDataSize <= UInt64(eot.count - 82) else { return nil }
        // The font is appended last, so it is the trailing FontDataSize bytes —
        // no need to re-derive the variable-length name block.
        return Data(eot.suffix(Int(fontDataSize)))
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
        let totalSize = UInt64(82 + names.count + tailSize) + UInt64(font.count)
        precondition(totalSize <= UInt64(UInt32.max), "EOT payload exceeds UInt32.max")
        let eotSize = UInt32(totalSize)

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
    /// any non-conflicting family names the font itself carries, without
    /// overwriting already-registered faces). Every supplied variant is
    /// registered under its declared style. Returns each registered family once.
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
                      let fontBytes = try? part.decodedData(),
                      let sfnt = EOTLite.unwrap(fontBytes),
                      (try? fonts.registerEmbedded(sfnt, face: FontFaceKey(
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
