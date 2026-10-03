import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PlatformLabRecipesTests {
    private static let ids: [LibraryDemoID] = [.layouts, .fontsAndFitting, .paragraphLayout, .tabLayout, .theme, .templates, .design, .mediaAndAttachments, .package, .extractionAndRendering]

    @Test(arguments: ids, [false, true])
    func everyRecipeExecutesSerializesAndVerifies(id: LibraryDemoID, alternative: Bool) throws {
        let options = LibraryLabOptions(text: alternative ? "Alternative laboratory" : "Offline library example", accentHex: alternative ? "963D61" : "276D89", sampleSize: alternative ? 12 : 2, alternative: alternative)
        let draft = try PlatformLabRecipes.make(id, options: options)
        #expect(!draft.checks.isEmpty)
        for check in draft.checks { #expect(check.passed, "\(id.rawValue): \(check.name): \(check.detail)") }
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        #expect(reopened.slides.count > 0)
        let checks = try draft.verify(reopened)
        #expect(!checks.isEmpty)
        for check in checks { #expect(check.passed, "\(id.rawValue) reopened: \(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        let issues = try reopened.validate()
        #expect(issues.isEmpty, "\(id.rawValue): \(issues)")
        #expect(draft.before != nil && draft.before != bytes)
        for (name, data) in draft.extraFiles {
            #expect(!name.contains("/") && !name.contains("\\") && !data.isEmpty)
            if name.hasSuffix(".potx") { #expect(try Presentation(data: data).documentKind == .template) }
            if name.hasSuffix(".ppsx") { #expect(try Presentation(data: data).documentKind == .slideShow) }
            if name.hasSuffix(".xlsx") { #expect(try ZipReader(data: data).contains("[Content_Types].xml")) }
        }
    }

    @Test(arguments: [false, true])
    func paragraphControlsChangeGeometryAndSurviveSaving(narrow: Bool) throws {
        let short = try PlatformLabRecipes.make(.paragraphLayout, options: .init(sampleSize: 2, alternative: narrow))
        let long = try PlatformLabRecipes.make(.paragraphLayout, options: .init(sampleSize: 12, alternative: narrow))
        let shortLayout = try PlatformLabRecipes.paragraphGeometry(short.deck, named: "Justified paragraph")
        let longLayout = try PlatformLabRecipes.paragraphGeometry(long.deck, named: "Justified paragraph")
        #expect(shortLayout.lines != longLayout.lines)
        let expectedWidth = (narrow ? 4.5 : 5.7) * 72
        #expect(abs(PlatformLabRecipes.paragraphVisibleWidth(shortLayout.lines[0], fonts: short.deck.fonts) - expectedWidth) < 0.01)
        #expect(shortLayout.lines.dropLast().allSatisfy { abs(PlatformLabRecipes.paragraphVisibleWidth($0, fonts: short.deck.fonts) - expectedWidth) < 0.01 })
        #expect(shortLayout.lines.last!.width < expectedWidth)
        #expect(shortLayout.diagnostics.isEmpty && longLayout.diagnostics.isEmpty)
        let first = try long.deck.serializedData()
        #expect(try long.deck.serializedData() == first)
        let reopened = try Presentation(data: first)
        reopened.registerEmbeddedFonts()
        let recovered = try PlatformLabRecipes.paragraphGeometry(reopened, named: "Justified paragraph")
        #expect(recovered.lines == longLayout.lines)
        #expect(try reopened.serializedData() == first)
        #expect(try PlatformLabRecipes.paragraphGeometry(short.deck, named: "Left paragraph").lines[0].width < expectedWidth)
    }

    @Test func embeddedWorkbookHasResolvableNativePreview() throws {
        let draft = try PlatformLabRecipes.make(.mediaAndAttachments, options: .init())
        let deck = try Presentation(data: draft.deck.serializedData())
        let slide = try deck.slides[1]
        let frame = try #require(slide.shapes.all.compactMap { $0 as? GraphicFrame }.first)
        let object = try #require(frame.graphicData?.firstChild(named: "p:oleObj"))
        #expect(object.firstChild(named: "p:embed") != nil)
        let preview = try #require(object.firstChild(named: "p:pic"))
        let imageID = try #require(preview.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip")?[attribute: "r:embed"])
        let relation = try #require(slide.part.rels.relationship(withId: imageID))
        #expect(relation.type == RelType.image)
        let imageURI = PackURI.resolve(target: relation.target, relativeTo: slide.part.uri.baseURI)
        let image = try deck.package.part(at: imageURI)
        #expect(image.contentType == "image/png")
        #expect(image.blob == LibraryLabSupport.pixels)
        let frameSize = frame.frame
        let previewSize = try #require(preview.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm")?.firstChild(named: "a:ext"))
        #expect(previewSize[attribute: "cx"] == String(frameSize.width.rawValue))
        #expect(previewSize[attribute: "cy"] == String(frameSize.height.rawValue))
    }

    @Test func catalogIsCompleteAndInputsAreBounded() throws {
        #expect(Set(PlatformLabRecipes.catalog.map(\.id)) == Set(Self.ids))
        #expect(PlatformLabRecipes.catalog.allSatisfy { !$0.operations.isEmpty && !$0.summary.isEmpty })
        for size in [Int.min, 1, 13, Int.max] {
            #expect(throws: RostrumError.self) { _ = try PlatformLabRecipes.make(.design, options: .init(sampleSize: size)) }
        }
        #expect(throws: RostrumError.self) { _ = try PlatformLabRecipes.make(.theme, options: .init(accentHex: "not a color")) }
        #expect(throws: RostrumError.self) { _ = try PlatformLabRecipes.make(.slides, options: .init()) }
    }

    @Test func ownedMediaHasActualContainerHeadersAndLicensedFontWorksWithoutPlatformFonts() throws {
        let wav = try PlatformLabRecipes.resource("PlatformSample", "wav")
        let mp4 = try PlatformLabRecipes.resource("PlatformSample", "mp4")
        #expect(String(decoding: wav.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: wav[8..<12], as: UTF8.self) == "WAVE")
        #expect(String(decoding: mp4[4..<8], as: UTF8.self) == "ftyp")
        let font = try PlatformLabRecipes.resource("DejaVuSans", "ttf")
        let metrics = try FontMetrics(data: font)
        #expect(metrics.unitsPerEm == 2048)
        #expect(TextShaper(metrics).shape("AV office x́", pointSize: 24).isSupported)
    }

    @Test(arguments: ["Hello\nWorld", "Hello\r\nWorld\tAgain", String(repeating: "x", count: 240)])
    func fontWrappingAcceptsMultilineAndLongInput(_ text: String) throws {
        let draft = try PlatformLabRecipes.make(.fontsAndFitting, options: .init(text: text))
        for check in draft.checks { #expect(check.passed, "\(check.name): \(check.detail)") }
        let reopened = try Presentation(data: draft.deck.serializedData())
        for check in try draft.verify(reopened) { #expect(check.passed, "\(check.name): \(check.detail)") }
    }
}
