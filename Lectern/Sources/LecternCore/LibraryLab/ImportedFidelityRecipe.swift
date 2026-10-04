import Foundation
import Rostrum

/// Imported XML examples: no private deck, proprietary fonts or network input.
enum ImportedFidelityRecipe {
    static let catalog = LibraryLabRecipe(.importedFidelity, title: "Imported artwork and text",
        summary: "Curved paths, SVG-only artwork, saved SmartArt, capitals and spaced numbered lists.",
        operations: ["Part.dom", "OPCPackage.addPart", "ShapeCollection.addSmartArt", "Presentation.renderSVGReportingProblems", "Presentation.serializedData"],
        limitations: ["XML specimens demonstrate imported content, not new typed authoring APIs. Custom paths support lines and quadratic/cubic curves; arcs and shaded path fills remain unsupported. SVG images support self-contained basic shapes and solid-color Office CSS only. SmartArt requires a saved drawing cache; no SmartArt layout algorithm is generated. Fonts still need explicit registration or viewer substitution."],
        inputs: [.text, .accent])

    static func make(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Imported fidelity")
        let slide = try deck.slides[0]
        try LibraryLabSupport.text(options.text, on: slide)
        let before = try deck.serializedData()
        let tree = try slide.part.dom().firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!
        func node(_ shape: Shape) -> XML.Element {
            tree.childElements.first { $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"] == shape.shapeID.map(String.init) }!
        }
        func xml(_ text: String) throws -> XML.Element { try XML.parse(Data(text.utf8)) }
        let curved = try slide.shapes.addShape(.rectangle, frame: LibraryLabSupport.frame(0.5, 1.2, 3, 2), fill: .solid(Color(options.accentHex)))
        if let sp = node(curved).firstChild(named: "p:spPr") {
            sp.children.removeAll { if case .element(let child) = $0 { return child.name == "a:prstGeom" }; return false }
            let geometry = try xml("<a:custGeom><a:pathLst><a:path w=\"100\" h=\"100\"><a:moveTo><a:pt x=\"0\" y=\"50\"/></a:moveTo><a:cubicBezTo><a:pt x=\"0\" y=\"0\"/><a:pt x=\"100\" y=\"0\"/><a:pt x=\"100\" y=\"50\"/></a:cubicBezTo><a:lnTo><a:pt x=\"50\" y=\"100\"/></a:lnTo><a:close/></a:path></a:pathLst></a:custGeom>")
            let index = sp.children.firstIndex { if case .element(let child) = $0 { return child.name != "a:xfrm" }; return false } ?? sp.children.count
            sp.children.insert(.element(geometry), at: index)
        }
        let list = try slide.shapes.addTextBox(LibraryLabSupport.frame(4, 1.2, 4, 3.2))
        if let body = node(list).firstChild(named: "p:txBody") {
            body.children.removeAll { if case .element(let child) = $0 { return child.name == "a:p" }; return false }
            for word in ["First", "", "Second", "", "Third"] {
                body.appendElement(try xml("<a:p><a:pPr algn=\"r\"><a:buAutoNum type=\"arabicPeriod\"/><a:defRPr sz=\"2400\" cap=\"all\"/></a:pPr><a:r><a:t>\(word)</a:t></a:r></a:p>"))
            }
        }
        let vector = Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><path fill=\"#\(options.accentHex)\" d=\"M0 0 L100 0 L100 100 Z\"/></svg>".utf8)
        _ = deck.package.addPart(uri: PackURI("/ppt/media/lab.svg"), contentType: "image/svg+xml", blob: vector)
        let imageID = slide.part.rels.add(type: RelType.image, target: "../media/lab.svg")

        tree.appendElement(try xml("<p:pic><p:nvPicPr><p:cNvPr id=\"50\" name=\"SVG only artwork\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip><a:extLst><a:ext uri=\"{96DAC541-7B7A-43D3-8B79-37D633B846F1}\"><asvg:svgBlip xmlns:asvg=\"http://schemas.microsoft.com/office/drawing/2016/SVG/main\" r:embed=\"\(imageID)\"/></a:ext></a:extLst></a:blip><a:stretch/></p:blipFill><p:spPr><a:xfrm><a:off x=\"8229600\" y=\"1097280\"/><a:ext cx=\"1828800\" cy=\"1828800\"/></a:xfrm><a:prstGeom prst=\"rect\"/></p:spPr></p:pic>"))
        _ = try slide.shapes.addSmartArt(items: ["Saved diagram text"], frame: LibraryLabSupport.frame(1, 4.5, 10, 1.5))
        let drawingXML = """
        <dsp:drawing xmlns:dsp="http://schemas.microsoft.com/office/drawing/2008/diagram" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><dsp:spTree><dsp:nvGrpSpPr><dsp:cNvPr id="0" name=""/><dsp:cNvGrpSpPr/></dsp:nvGrpSpPr><dsp:grpSpPr/>
        <dsp:sp><dsp:nvSpPr><dsp:cNvPr id="1" name="Saved shape"/><dsp:cNvSpPr/></dsp:nvSpPr><dsp:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="9144000" cy="1371600"/></a:xfrm><a:prstGeom prst="roundRect"/><a:solidFill><a:srgbClr val="F5CDCE"/></a:solidFill></dsp:spPr><dsp:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="2400"/><a:t>Saved diagram text</a:t></a:r></a:p></dsp:txBody></dsp:sp></dsp:spTree></dsp:drawing>
        """
        _ = deck.package.addPart(uri: PackURI("/ppt/diagrams/drawing1.xml"), contentType: "application/vnd.ms-office.drawingml.diagramDrawing+xml", blob: Data(drawingXML.utf8))
        let drawingID = slide.part.rels.add(type: "http://schemas.microsoft.com/office/2007/relationships/diagramDrawing", target: "../diagrams/drawing1.xml")
        let data = try deck.package.part(at: PackURI("/ppt/diagrams/data1.xml"))
        try data.dom().appendElement(xml("<dgm:extLst><a:ext uri=\"{C1C4B2C5-EE94-4FBA-B6DD-F449D9B2D5BA}\"><dsp:dataModelExt xmlns:dsp=\"http://schemas.microsoft.com/office/drawing/2008/diagram\" relId=\"\(drawingID)\"/></a:ext></dgm:extLst>"))
        data.markDirty(); slide.part.markDirty()
        return LibraryLabDraft(deck: deck, before: before, verify: { reopened in
            let bytes = try reopened.serializedData()
            let result = try reopened.renderSVGReportingProblems(slideAt: 0)
            let svg = result.svg
            return [
                .init("Imported curve survives", svg.contains("C0 0 2743200 0 2743200 914400"), "Private path coordinates scale into the shape frame."),
                .init("SVG-only artwork survives", svg.contains("data:image/svg+xml;base64,"), "The extension relationship resolves from its owning part."),
                .init("Saved SmartArt text survives", svg.contains("Saved diagram text") && !svg.contains("[SmartArt]"), "Cached native drawing is rendered, without generating diagram layout."),
                .init("Capitalization and numbering", svg.contains("FIRST") && svg.contains("SECOND") && svg.contains("THIRD") && !svg.contains(">4. ") && !svg.contains(">5. "), "Empty paragraphs retain spacing without advancing numbering."),
                .init("Rendering preserves source", try reopened.serializedData() == bytes, "Read-only rendering does not change any saved bytes.")
            ]
        })
    }
}
