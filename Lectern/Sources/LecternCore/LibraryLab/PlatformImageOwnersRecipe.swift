import Foundation
import Rostrum

struct ImageOwnersReferences: Decodable {
    struct Paint: Decodable { let frame: [Double]; let rgb: [Int]; let pixels: [Int] }
    struct Source: Decodable {
        let source: String
        let originalSource: String
        let group: String
        let sourceSHA256: String
        let pdfSHA256: String
        let nativePagePoints: [Double]
        let paints: [Paint]
    }
    let sources: [Source]
}

/// Parses each actual page once. Admits only the captured flat rectangular
/// image profile, including the pattern's clip and final painted rectangle.
struct ImageOwnersSVGPage {
    let root: XML.Element
    init(_ svg: String) throws { root = try XML.parse(Data(svg.utf8)) }
    func matches(_ paints: [ImageOwnersReferences.Paint], red: Data, blue: Data) -> Bool {
        let patterns = DrawingLabFixtures.nodes(root, "pattern")
        guard root.attributes.allSatisfy({ ["xmlns", "width", "height", "viewBox"].contains($0.name) }),
              patterns.count == paints.count,
              DrawingLabFixtures.nodes(root, "image").count == paints.count,
              DrawingLabFixtures.nodes(root, "g").allSatisfy({ $0.attributes.allSatisfy { $0.name == "clip-path" } }) else { return false }
        func allowed(_ node: XML.Element, _ names: Set<String>) -> Bool { node.attributes.allSatisfy { names.contains($0.name) } }
        func dimensions(_ node: XML.Element) -> [Double]? {
            let a = ["x", "y", "width", "height"].compactMap { node[attribute: $0].flatMap(Double.init) }
            return a.count == 4 && a.allSatisfy(\.isFinite) ? a : nil
        }
        let visible = root.childElements.filter { $0.name != "defs" }
        let viewBox = (root[attribute: "viewBox"] ?? "").split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        guard visible.count == paints.count + 1, visible.allSatisfy({ $0.name == "rect" }),
              viewBox.count == 4, viewBox[0] == 0, viewBox[1] == 0,
              allowed(visible[0], ["x", "y", "width", "height", "fill"]),
              dimensions(visible[0]) == viewBox, visible[0][attribute: "fill"] == "#FFFFFF" else { return false }
        for (index, pair) in zip(patterns, paints).enumerated() {
            let (pattern, paint) = pair
            guard paint.frame.count == 4, paint.pixels == [2, 2],
                  allowed(pattern, ["id", "patternUnits", "x", "y", "width", "height"]),
                  pattern[attribute: "patternUnits"] == "userSpaceOnUse",
                  let f = dimensions(pattern), let id = pattern[attribute: "id"],
                  pattern.childElements.count == 1, let group = pattern.firstChild(named: "g"),
                  group.childElements.count == 1, let image = group.firstChild(named: "image"),
                  allowed(image, ["x", "y", "width", "height", "preserveAspectRatio", "href"]),
                  dimensions(image) == [0, 0, f[2], f[3]], image[attribute: "preserveAspectRatio"] == "none",
                  paint.rgb == [255, 0, 0] || paint.rgb == [0, 0, 255] else { return false }
            let points = [f[0], f[1], f[0] + f[2], f[1] + f[3]].map { $0 / Double(EMU.perPoint) }
            guard zip(points, paint.frame).allSatisfy({ abs($0 - $1) < 0.001 }),
                  image[attribute: "href"] == "data:image/png;base64," + (paint.rgb == [255, 0, 0] ? red : blue).base64EncodedString(),
                  let clipRef = group[attribute: "clip-path"], clipRef.hasPrefix("url(#"), clipRef.hasSuffix(")") else { return false }
            let clipID = String(clipRef.dropFirst(5).dropLast())
            let clips = DrawingLabFixtures.nodes(root, "clipPath").filter { $0[attribute: "id"] == clipID }
            guard clips.count == 1, allowed(clips[0], ["id"]), clips[0].childElements.count == 1,
                  let clip = clips[0].firstChild(named: "rect"), allowed(clip, ["x", "y", "width", "height"]),
                  dimensions(clip) == [0, 0, f[2], f[3]] else { return false }
            let painted = root.children(named: "rect").filter { $0[attribute: "fill"] == "url(#\(id))" }
            guard painted.count == 1, visible[index + 1] === painted[0], allowed(painted[0], ["x", "y", "width", "height", "fill", "stroke", "stroke-width"]),
                  dimensions(painted[0]) == f,
                  painted[0][attribute: "stroke"] == nil || painted[0][attribute: "stroke"] == "none" else { return false }
        }
        return true
    }
}

extension PlatformLabRecipes {
    static func imageOwnersReferences() throws -> ImageOwnersReferences {
        try JSONDecoder().decode(ImageOwnersReferences.self, from: resource("ImageOwnersReferences", "json"))
    }
    static func imageOwnerChecks(_ deck: Presentation, reference: ImageOwnersReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let red = try resource("ImageOwners-theme-red", "png"), blue = try resource("ImageOwners-slide-blue", "png")
        return try reference.sources.enumerated().map { index, source in
            let rendered = try deck.renderSVGReportingProblems(slideAt: index)
            return .init(prefix + "Native image owner: " + source.group,
                         try ImageOwnersSVGPage(rendered.svg).matches(source.paints, red: red, blue: blue) && rendered.problems.fidelityIssues.isEmpty,
                         "Exact selected PNG bytes, clip, painted frame and order; native finite rectangle bound .001 pt. Canvas extension does not scale specimens.")
        }
    }
    /// Compare whole reachable owner graphs by relationship identity and payload,
    /// permitting only destination part URI renaming performed by public import.
    static func imageOwnerPartPayloadMatches(_ a: Part, _ b: Part) throws -> Bool {
        if a.blob == b.blob { return true }
        guard a.contentType.contains("slideMaster+xml"), b.contentType == a.contentType else { return false }
        let roots = try [a, b].map { try XML.parse($0.blob) }
        for root in roots {
            guard let list = root.firstChild(named: "p:sldLayoutIdLst") else { return false }
            let ids = list.children(named: "p:sldLayoutId")
            let values = ids.compactMap { $0[attribute: "id"].flatMap(UInt32.init) }
            guard values.count == ids.count, Set(values).count == ids.count,
                  values.allSatisfy({ $0 >= 2_147_483_648 }) else { return false }
            // Public slide import must allocate deck-unique layout IDs. Only
            // those validated numeric IDs are normalized; r:id stays exact.
            for (index, node) in ids.enumerated() { node[attribute: "id"] = String(index) }
        }
        return roots[0].serialized() == roots[1].serialized()
    }
    static func imageOwnerGraphMatches(_ source: Presentation, _ destination: Presentation, destinationIndex: Int) throws -> Bool {
        var visited: Set<String> = []
        func matches(_ a: Part, _ b: Part) throws -> Bool {
            let key = a.uri.value + "|" + b.uri.value
            if !visited.insert(key).inserted { return true }
            guard a.contentType == b.contentType, try imageOwnerPartPayloadMatches(a, b),
                  a.rels.items.count == b.rels.items.count else { return false }
            for rel in a.rels.items {
                guard let other = b.rels.relationship(withId: rel.rId), rel.type == other.type, rel.isExternal == other.isExternal else { return false }
                if rel.isExternal { if rel.target != other.target { return false }; continue }
                let aURI = PackURI.resolve(target: rel.target, relativeTo: a.uri.baseURI)
                let bURI = PackURI.resolve(target: other.target, relativeTo: b.uri.baseURI)
                if try !matches(source.package.part(at: aURI), destination.package.part(at: bURI)) { return false }
            }
            return true
        }
        return try matches(source.slides[0].part, destination.slides[destinationIndex].part)
    }
    static func imageOwners(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let referenceData = try resource("ImageOwnersReferences", "json"), reference = try imageOwnersReferences()
        let sourceData = try reference.sources.map { try resource(String($0.source.dropLast(5)), "pptx") }
        let sources = try sourceData.map { try Presentation(data: $0) }
        let originalNodes = try sources.map { try DrawingLabFixtures.nodes($0.slides[0].part.dom(), "p:sp").map { $0.serialized() } }
        let deck = sources[0], before = sourceData[0]
        for source in sources.dropFirst() { _ = try deck.slides.importAll(from: source) }
        deck.slideSize = (width: .points(864), height: .points(540))
        let originalParts = try (0..<4).map { index in
            let s = try deck.slides[index]
            let layout = try require(s.layout, "Source layout missing"), master = try require(s.master, "Source master missing")
            return try [s.part, layout.part, master.part].map { try $0.dom().serialized() }
        }
        let control = try deck.slides.import(from: Presentation(data: sourceData[2]), at: 0)
        let shape = try require(control.shapes.all.first, "Image control missing")
        let blue = try resource("ImageOwners-slide-blue", "png")
        try shape.setFill(options.alternative ? .none : .image(blue))
        let font = try resource("DejaVuSans", "ttf")
        try deck.fonts.register(font); try deck.embedFont("DejaVu Sans", faces: .init(regular: font))
        func caption(_ value: String, y: Double, size: Double = 20, height: Double = 70) throws {
            let box = try text(value, on: control, in: .init(x: .points(270), y: .points(y), width: .points(540), height: .points(height)))
            for p in box.textFrame?.paragraphs ?? [] { for run in p.runs { run.fontSize = size } }
        }
        try caption("Image fill ownership", y: 45, size: 28)
        try caption(options.alternative ? "Public no-fill override\nThe theme image is suppressed." : "Public direct-image override\nSlide-owned blue replaces theme red.", y: 135)
        try caption("Pages 1-2: theme-owned red, with and without a colliding slide relationship. Page 3: direct slide blue. Page 4: theme red plus direct layout and master blue.", y: 240, height: 110)
        try caption("Native source rectangles stay unchanged on an extended 864 by 540 pt canvas. Exact source files and image references are included. This page exercises public APIs; it is outside the native image oracle.", y: 365, size: 17, height: 120)
        var checks = try imageOwnerChecks(deck, reference: reference)
        let importedNodes = try (0..<4).map { try DrawingLabFixtures.nodes(deck.slides[$0].part.dom(), "p:sp").map { $0.serialized() } }
        checks.append(.init("Native image shapes remain exact", importedNodes == originalNodes, "All original shape XML and frames survive import without scaling."))
        let graphsMatch = try sourceData.enumerated().allSatisfy { index, data in
            try imageOwnerGraphMatches(Presentation(data: data), deck, destinationIndex: index)
        }
        checks.append(.init("Native image owner graphs remain exact", graphsMatch, "Reachable payloads and relationship identities remain exact except validated unique numeric master layout-ID rebasing and XML serialization; imported part URI names may change."))
        checks.append(.init("Public image override changes selection", try imageOwnerControlMatches(deck, alternative: options.alternative), "Public authored fill read, actual SVG and outline agree."))
        checks += try imageOwnerInventoryChecks(deck, alternative: options.alternative)
        let bytes = try deck.serializedData(), svgs = try (0..<5).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Image-owner inspection is pure", try deck.serializedData() == bytes, "Rendering and outline reads preserve source bytes."))
        var extra = ["native-image-owners-reference.json": referenceData]
        for (ref, data) in zip(reference.sources, sourceData) { extra["native-source-" + ref.originalSource] = data }
        return LibraryLabDraft(deck: deck, before: before, checks: checks, extraFiles: extra, verify: { reopened in
            reopened.registerEmbeddedFonts()
            var result = try imageOwnerChecks(reopened, reference: reference, prefix: "Saved ")
            let parts = try (0..<4).map { index in
                let s = try reopened.slides[index]
                let layout = try require(s.layout, "Source layout missing"), master = try require(s.master, "Source master missing")
            return try [s.part, layout.part, master.part].map { try $0.dom().serialized() }
            }
            result.append(.init("Native image inheritance survives", parts == originalParts, "Original slide, layout and master XML retain their resource references on reopening."))
            let graphsMatch = try sourceData.enumerated().allSatisfy { index, data in
                try imageOwnerGraphMatches(Presentation(data: data), reopened, destinationIndex: index)
            }
            result.append(.init("Saved native owner graphs remain exact", graphsMatch, "Reachable owner graphs survive with only validated master layout-ID rebasing; theme, layout and selected image payloads remain exact."))
            result.append(.init("Image-owner previews are deterministic", try (0..<5).map { try reopened.renderSVG(slideAt: $0) } == svgs, "All five SVGs reopen byte-identically."))
            result.append(.init("Public image override survives", try imageOwnerControlMatches(reopened, alternative: options.alternative), "Direct image or noFill still overrides the retained theme reference."))
            result.append(.init("Caption font survives", reopened.fonts.data(for: .init(family: "DejaVu Sans")) == font, "Bundled licensed face, used only on the public control page."))
            result += try imageOwnerInventoryChecks(reopened, alternative: options.alternative)
            return result
        })
    }
    static func imageOwnerControlMatches(_ deck: Presentation, alternative: Bool) throws -> Bool {
        let shape = try require(deck.slides[4].shapes.all.first, "Saved image control missing")
        let xml = try XML.parse(Data(deck.renderSVG(slideAt: 4).utf8))
        let images = DrawingLabFixtures.nodes(xml, "image")
        if alternative { return shape.fill == .noFill && images.isEmpty && deck.outline().slides[4].assets.isEmpty }
        guard case .image = shape.fill else { return false }
        let blue = try resource("ImageOwners-slide-blue", "png")
        return images.count == 1 && images[0][attribute: "href"] == "data:image/png;base64," + blue.base64EncodedString()
    }
    static func imageOwnerInventoryChecks(_ deck: Presentation, alternative: Bool) throws -> [LibraryLabCheck] {
        let red = try resource("ImageOwners-theme-red", "png"), blue = try resource("ImageOwners-slide-blue", "png")
        let expected: [[Data]] = [[red], [red], [blue], [blue, red], alternative ? [] : [blue]]
        let outline = deck.outline()
        var valid = outline.slides.count == 5 && outline.warnings.isEmpty
        for (slide, payloads) in zip(outline.slides, expected) {
            let actual = try slide.assets.map { try deck.package.part(at: PackURI($0.partName)).blob }
            valid = valid && actual.count == payloads.count && Set(actual) == Set(payloads)
        }
        return [.init("Selected owner assets match outline", valid, "Resource ownership deduplicates actual package parts per slide; unused colliding blue is not exported for theme-red pages.")]
    }
}

extension PlatformLabRecipes {
    static func imageOwnerExportCheck(_ deck: Presentation, export: DeckExporter.Outcome) throws -> LibraryLabCheck {
        let outline = deck.outline()
        var expected: [String: Data] = [:]
        for slide in outline.slides { for asset in slide.assets {
            expected[String(format: "slide-%02d/", slide.number) + asset.filename] = try deck.package.part(at: PackURI(asset.partName)).blob
        } }
        var actual: [String: Data] = [:]
        let enumerator = FileManager.default.enumerator(at: export.directory, includingPropertiesForKeys: [.isRegularFileKey])
        while let file = enumerator?.nextObject() as? URL {
            if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true, file.pathExtension != "md" {
                let relative = file.resolvingSymlinksInPath().pathComponents.dropFirst(export.directory.resolvingSymlinksInPath().pathComponents.count).joined(separator: "/")
                actual[relative] = try Data(contentsOf: file)
            }
        }
        let markdown = try String(contentsOf: export.markdownFile, encoding: .utf8)
        return .init("Selected image owners export exact bytes", !expected.isEmpty && actual == expected
                     && export.assetsWritten == expected.count && export.chartsWritten == 0 && export.warnings.isEmpty
                     && expected.keys.allSatisfy { markdown.contains($0) }, "Actual folder export contains only the selected per-slide image resources and exact PNG bytes, with Markdown links.")
    }
}
