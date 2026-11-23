import Foundation
import Testing
@testable import Rostrum

@Suite struct OPCandFontSecurityTests {
    private static func makeFaceBytes(family: String, fsType: UInt16, prefixSize: Int = 0) -> [UInt8] {
        let advances = [600] + (0x20...0x7E).map(TestFont.advance(forChar:))
        var os2 = TestFont.os2(useTypoMetrics: false)
        os2.replaceSubrange(8..<10, with: TestFont.be16(Int(fsType)))
        let tables: [(String, [UInt8])] = [
            ("head", TestFont.head(upem: 1000)),
            ("hhea", TestFont.hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: advances.count)),
            ("maxp", TestFont.maxp(numGlyphs: advances.count)),
            ("hmtx", TestFont.hmtx(advances: advances)),
            ("cmap", TestFont.cmapFormat4()),
            ("OS/2", os2),
            ("name", TestFont.nameTable(family: family)),
            ("loca", [UInt8](repeating: 0, count: (advances.count + 1) * 2)),
            ("glyf", [0, 0, 0, 0]),
        ]
        return TestFont.assemble(tables: tables, prefixSize: prefixSize)
    }

    private static func makeTwoFaceTTC(firstFsType: UInt16, secondFsType: UInt16) -> Data {
        let headerSize = 20 // 'ttcf' + version(4) + count(4) + [off0, off1](8)
        let face0 = makeFaceBytes(family: "TTCFirst", fsType: firstFsType, prefixSize: headerSize)
        let face1Offset = headerSize + face0.count
        let face1 = makeFaceBytes(family: "TTCSecond", fsType: secondFsType, prefixSize: face1Offset)
        let header = Array("ttcf".utf8)
            + TestFont.be32(0x0001_0000)
            + TestFont.be32(2)
            + TestFont.be32(headerSize)
            + TestFont.be32(face1Offset)
        return Data(header + face0 + face1)
    }

    @Test func externalRelationshipsNeverMasqueradeAsInternalPartsOrDesynchronizePrune() throws {
        let seed = try Presentation()
        let slide0 = try seed.slides[0]
        let box = try slide0.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1))
        )
        box.setHyperlink("https://example.com/safe")

        // Prepend External officeDocument ahead of internal officeDocument in /_rels/.rels,
        // and prepend External slideLayout ahead of internal slideLayout on slide1.xml.rels.
        let originalRootRels = seed.package.rels.items
        seed.package.rels.setItems([
            Relationship(
                rId: "rIdExtRoot",
                type: RelType.officeDocument,
                target: "https://evil.example/ppt/presentation.xml",
                isExternal: true
            ),
        ] + originalRootRels)

        let originalSlideRels = slide0.part.rels.items
        slide0.part.rels.setItems([
            Relationship(
                rId: "rIdExtLayout",
                type: RelType.slideLayout,
                target: "https://evil.example/ppt/slideLayouts/slideLayout1.xml",
                isExternal: true
            ),
        ] + originalSlideRels)

        let bytes = try seed.serializedData()

        // Both OPCArchive and Presentation resolve the internal officeDocument & slideLayout,
        // and prune() retains the entire reachable presentation subgraph.
        let archive = try OPCArchive(data: bytes)
        #expect(archive.mainPartURI == PackURI("/ppt/presentation.xml"))

        let reopened = try Presentation(data: bytes)
        #expect(reopened.slides.count == 1)
        let reopenedSlide = try reopened.slides[0]
        #expect(reopenedSlide.layout != nil)
        #expect(reopenedSlide.shapes.all.first?.hyperlink == "https://example.com/safe")

        let pruned = reopened.prune()
        #expect(pruned.isEmpty)
        #expect(reopened.slides.count == 1)
        #expect(try reopened.slides[0].layout != nil)
        let renderAfterPrune = try reopened.renderSVGReportingProblems(slideAt: 0)
        #expect(!renderAfterPrune.problems.layoutUnresolved)
        #expect(!renderAfterPrune.problems.masterUnresolved)

        // Package whose ONLY officeDocument relationship is TargetMode="External" (even with a
        // local-looking target path) is rejected on open and returns nil mainPartURI in OPCArchive.
        let externalOnlyPkg = try OPCPackage.read(data: seed.serializedData())
        externalOnlyPkg.rels.setItems([
            Relationship(
                rId: "rId1",
                type: RelType.officeDocument,
                target: "ppt/presentation.xml",
                isExternal: true
            ),
        ])
        let externalOnlyBytes = try externalOnlyPkg.serialize()
        let externalOnlyArchive = try OPCArchive(data: externalOnlyBytes)
        #expect(externalOnlyArchive.mainPartURI == nil)
        #expect(throws: RostrumError.self) {
            _ = try Presentation(data: externalOnlyBytes)
        }

        // Part.related(by:in:) refuses External relationships even when Target names an existing part.
        let layoutCheckDeck = try Presentation()
        let checkSlide = try layoutCheckDeck.slides[0]
        checkSlide.part.rels.setItems([
            Relationship(
                rId: "rId1",
                type: RelType.slideLayout,
                target: "../slideLayouts/slideLayout1.xml",
                isExternal: true
            ),
        ])
        #expect(checkSlide.layout == nil)
        #expect(throws: RostrumError.self) {
            _ = try checkSlide.part.related(by: RelType.slideLayout, in: layoutCheckDeck.package)
        }
        let brokenLayoutRender = try layoutCheckDeck.renderSVGReportingProblems(slideAt: 0)
        #expect(brokenLayoutRender.problems.layoutUnresolved)
    }

    @Test(arguments: [UInt16(0x0002), UInt16(0x0200)])
    func embedFontEnforcesOS2RestrictionsAcrossStandaloneAndMultiFaceTTC(restrictedBits: UInt16) throws {
        let standaloneRestricted = Data(Self.makeFaceBytes(family: "RestrictedStandalone", fsType: restrictedBits))
        let ttcFirstRestricted = Self.makeTwoFaceTTC(firstFsType: restrictedBits, secondFsType: 0)
        let ttcSecondRestricted = Self.makeTwoFaceTTC(firstFsType: 0, secondFsType: restrictedBits)

        #expect((EOTLite.fsType(of: standaloneRestricted) ?? 0) & EOTLite.fsTypeRestrictedMask == restrictedBits)
        #expect((EOTLite.fsType(of: ttcFirstRestricted) ?? 0) & EOTLite.fsTypeRestrictedMask == restrictedBits)
        #expect((EOTLite.fsType(of: ttcSecondRestricted) ?? 0) & EOTLite.fsTypeRestrictedMask == restrictedBits)

        for candidate in [standaloneRestricted, ttcFirstRestricted, ttcSecondRestricted] {
            let deck = try Presentation()
            let before = try deck.serializedData()
            #expect(throws: RostrumError.self) {
                try deck.embedFont("RestrictedFamily", faces: FontFaces(regular: candidate))
            }
            #expect(try deck.serializedData() == before)
        }

        // Permissible TTC extracts standalone face 0 cleanly, registers for measurement, and re-embeds idempotently.
        let permissibleTTC = Self.makeTwoFaceTTC(firstFsType: 0, secondFsType: 0)
        let okDeck = try Presentation()
        try okDeck.embedFont("TTCFirst", faces: FontFaces(regular: permissibleTTC))
        let afterFirstEmbed = try okDeck.serializedData()
        try okDeck.embedFont("TTCFirst", faces: FontFaces(regular: permissibleTTC))
        #expect(try okDeck.serializedData() == afterFirstEmbed)

        let reopened = try Presentation(data: afterFirstEmbed)
        let fontPart = try reopened.presentationPart.related(by: RelType.font, in: reopened.package)
        let unwrapped = try #require(EOTLite.unwrap(try fontPart.decodedData()))
        #expect(Array(unwrapped.prefix(4)) == [0x00, 0x01, 0x00, 0x00])
        #expect(reopened.registerEmbeddedFonts() == ["TTCFirst"])
    }

    @Test func svgFontFaceFailsClosedWhenRestrictedFontCarriesZeroLengthOrDuplicateTables() throws {
        // Construct a font that FontMetrics accepts (valid head/hhea/maxp/hmtx/cmap/name/loca/glyf)
        // plus an empty (offset=0, length=0) DSIG record and duplicate 'cvt ' records alongside a
        // restricted OS/2 record — ensuring EOTLite.fsType never fails open to nil for RenderDiagnostics.
        let base = Data(Self.makeFaceBytes(family: "QuirkyRestricted", fsType: 0x0200))
        var quirky = [UInt8](base)
        let origTables = (Int(quirky[4]) << 8) | Int(quirky[5])
        let extraRecordsCount = 2 // 1 zero-length DSIG + 1 duplicate cmap/cvt
        let shift = extraRecordsCount * 16
        let newTables = origTables + extraRecordsCount

        var header = Array(quirky[0..<12])
        header[4] = UInt8((newTables >> 8) & 0xFF)
        header[5] = UInt8(newTables & 0xFF)

        // Prepend DSIG with offset=0, length=0 and duplicate 'cvt ' tables BEFORE OS/2.
        var records: [UInt8] = []
        records += Array("DSIG".utf8) + TestFont.be32(0) + TestFont.be32(0) + TestFont.be32(0)
        records += Array("cvt ".utf8) + TestFont.be32(0) + TestFont.be32(0) + TestFont.be32(0)
        for i in 0..<origTables {
            let rec = 12 + i * 16
            var entry = Array(quirky[rec..<(rec + 16)])
            let oldOff = (Int(entry[8]) << 24) | (Int(entry[9]) << 16) | (Int(entry[10]) << 8) | Int(entry[11])
            let newOff = oldOff + shift
            entry.replaceSubrange(8..<12, with: TestFont.be32(newOff))
            records += entry
        }
        let body = Array(quirky[(12 + origTables * 16)...])
        let craftedFont = Data(header + records + body)

        #expect((EOTLite.fsType(of: craftedFont) ?? 0) & EOTLite.fsTypeRestrictedMask == 0x0200)

        let deck = try Presentation()
        #expect(try deck.fonts.register(craftedFont) == "QuirkyRestricted")
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1))
        )
        let tf = try #require(box.textFrame)
        tf.text = "Confidential"
        tf.paragraphs[0].runs[0].fontName = "QuirkyRestricted"

        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(!report.svg.contains("@font-face"))
        #expect(report.problems.fidelityIssues.contains { $0.code == .fontEmbeddingRestricted })
    }

    @Test func embedFontRefusesCorruptAndNonSFNTContainersAtomically() throws {
        let validSFNT = Data(Self.makeFaceBytes(family: "Valid", fsType: 0))
        var truncatedSFNT = validSFNT
        truncatedSFNT.removeLast(20)

        let fakeTTCZeroFaces = Data(Array("ttcf".utf8) + TestFont.be32(0x0001_0000) + TestFont.be32(0))
        let fakeTTCOverflowFaces = Data(Array("ttcf".utf8) + TestFont.be32(0x0001_0000) + [0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 16])
        let woffHeader = Data(Array("wOFF".utf8) + [UInt8](repeating: 0, count: 60))
        let zero64 = Data(repeating: 0, count: 64)
        let shortBytes = Data([0x00, 0x01, 0x00, 0x00])

        for corrupt in [
            Data("not an sfnt font".utf8),
            woffHeader,
            zero64,
            shortBytes,
            truncatedSFNT,
            fakeTTCZeroFaces,
            fakeTTCOverflowFaces,
        ] {
            let deck = try Presentation()
            let before = try deck.serializedData()
            #expect(throws: RostrumError.self) {
                try deck.embedFont("Broken", faces: FontFaces(regular: validSFNT, bold: corrupt))
            }
            #expect(try deck.serializedData() == before)
        }
    }
}
