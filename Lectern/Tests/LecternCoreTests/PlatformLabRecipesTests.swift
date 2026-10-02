import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PlatformLabRecipesTests {
    private static let ids: [LibraryDemoID] = [.layouts, .fontsAndFitting, .theme, .templates, .design, .mediaAndAttachments, .package, .extractionAndRendering]

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
}
