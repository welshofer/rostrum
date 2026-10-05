import Foundation
import Rostrum

extension DrawingLabRecipes {
    /// These two existing galleries deliberately share one tiny package image.
    /// Selection describes resource ownership, not pixel visibility or occlusion.
    static func imageFillSlides(for id: LibraryDemoID) -> [Int]? {
        switch id {
        case .tableAppearance: return [1, 2]
        case .fillsAndLines: return [1, 9, 10]
        default: return nil
        }
    }
    static func imageFillInventoryCheck(_ deck: Presentation, id: LibraryDemoID) throws -> LibraryLabCheck {
        let expected = imageFillSlides(for: id) ?? []
        let before = try deck.serializedData(), outline = deck.outline()
        let selected = outline.slides.filter { !$0.assets.isEmpty }
        let assets = selected.flatMap(\.assets)
        let imageParts = deck.package.parts.values.filter { $0.contentType.hasPrefix("image/") }
        let correct = !expected.isEmpty && selected.map(\.number) == expected
            && selected.allSatisfy { $0.assets.count == 1 }
            && assets.allSatisfy { $0.kind == .image && $0.filename == "image1.png" && $0.byteCount == LibraryLabSupport.pixels.count }
            && Set(assets.map(\.partName)).count == 1 && imageParts.count == 1
            && assets.allSatisfy { $0.partName == imageParts.first?.uri.value }
            && imageParts.first?.blob == LibraryLabSupport.pixels && outline.warnings.isEmpty
        return .init("Selected image fills enter the outline", try correct && deck.serializedData() == before,
                     "One shared package image is inventoried once per owning slide (\(expected.map(String.init).joined(separator: ", "))), without changing source bytes. This is selected resource inventory, not occlusion analysis.")
    }
    static func imageFillExportChecks(id: LibraryDemoID, export: DeckExporter.Outcome) throws -> [LibraryLabCheck] {
        guard let slides = imageFillSlides(for: id) else { return [] }
        let expected = Set(slides.map { String(format: "slide-%02d/image1.png", $0) })
        let enumerator = FileManager.default.enumerator(at: export.directory, includingPropertiesForKeys: [.isRegularFileKey])
        var actual: Set<String> = [], bytesMatch = true
        while let file = enumerator?.nextObject() as? URL {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                  file.pathExtension != "md" else { continue }
            actual.insert(file.resolvingSymlinksInPath().pathComponents.dropFirst(export.directory.resolvingSymlinksInPath().pathComponents.count).joined(separator: "/"))
            if try Data(contentsOf: file) != LibraryLabSupport.pixels { bytesMatch = false }
        }
        let markdown = try String(contentsOf: export.markdownFile, encoding: .utf8)
        return [.init("Selected image fills export exact bytes", actual == expected && bytesMatch
                      && export.assetsWritten == slides.count && export.chartsWritten == 0 && export.warnings.isEmpty
                      && expected.allSatisfy { markdown.contains($0) },
                      "Export contains \(slides.count) exact 84-byte PNG copies, one per owning slide, with Markdown links and no duplicate copies within a slide.")]
    }
}
