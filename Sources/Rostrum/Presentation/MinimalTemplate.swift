import Foundation

/// Builds Rostrum's default new-presentation package from first principles.
///
/// python-pptx ships a binary `default.pptx` and opens it behind the scenes;
/// Rostrum constructs the equivalent package from the XML constants below —
/// inspectable, diffable, and with a 16:9 slide size (python-pptx's bundled
/// template is 4:3).
///
/// The part set is the documented minimum for PowerPoint to open a file
/// without repair: presentation + one master + one (blank) layout + one slide
/// + theme + docProps.
enum MinimalTemplate {
    static let nsA = "http://schemas.openxmlformats.org/drawingml/2006/main"
    static let nsR = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    static let nsP = "http://schemas.openxmlformats.org/presentationml/2006/main"

    /// 16:9, 13.333" × 7.5".
    static let defaultSlideWidth = EMU.inches(13.333333)
    static let defaultSlideHeight = EMU.inches(7.5)

    static func makePackage(created: Date = Date()) throws -> OPCPackage {
        let package = OPCPackage()

        let presentation = package.addPart(
            uri: PackURI("/ppt/presentation.xml"),
            contentType: ContentType.presentationMain,
            blob: Data(presentationXML.utf8))
        let master = package.addPart(
            uri: PackURI("/ppt/slideMasters/slideMaster1.xml"),
            contentType: ContentType.slideMaster,
            blob: Data(slideMasterXML.utf8))
        let layout = package.addPart(
            uri: PackURI("/ppt/slideLayouts/slideLayout1.xml"),
            contentType: ContentType.slideLayout,
            blob: Data(slideLayoutXML.utf8))
        let slide = package.addPart(
            uri: PackURI("/ppt/slides/slide1.xml"),
            contentType: ContentType.slide,
            blob: Data(slideXML.utf8))
        package.addPart(
            uri: PackURI("/ppt/theme/theme1.xml"),
            contentType: ContentType.theme,
            blob: Data(themeXML.utf8))
        package.addPart(
            uri: PackURI("/docProps/core.xml"),
            contentType: ContentType.opcCoreProperties,
            blob: Data(corePropertiesXML(created: created).utf8))
        package.addPart(
            uri: PackURI("/docProps/app.xml"),
            contentType: ContentType.officeExtendedProperties,
            blob: Data(appPropertiesXML.utf8))

        // Relationship wiring. rIds must line up with the r:id references in
        // presentationXML (rId1 → master, rId2 → slide) and slideMasterXML
        // (rId1 → layout, rId2 → theme).
        package.rels.add(type: RelType.officeDocument, target: "ppt/presentation.xml")
        package.rels.add(type: RelType.coreProperties, target: "docProps/core.xml")
        package.rels.add(type: RelType.extendedProperties, target: "docProps/app.xml")

        presentation.rels.add(type: RelType.slideMaster, target: "slideMasters/slideMaster1.xml")
        presentation.rels.add(type: RelType.slide, target: "slides/slide1.xml")
        presentation.rels.add(type: RelType.theme, target: "theme/theme1.xml")

        master.rels.add(type: RelType.slideLayout, target: "../slideLayouts/slideLayout1.xml")
        master.rels.add(type: RelType.theme, target: "../theme/theme1.xml")

        layout.rels.add(type: RelType.slideMaster, target: "../slideMasters/slideMaster1.xml")

        slide.rels.add(type: RelType.slideLayout, target: "../slideLayouts/slideLayout1.xml")

        return package
    }

    // MARK: - Part XML

    /// Required children, in schema order: sldMasterIdLst, sldIdLst, sldSz, notesSz.
    /// sldMasterId ids live in a distinct 2147483648+ range; sldId ids start at 256.
    static let presentationXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="\(nsA)" xmlns:r="\(nsR)" xmlns:p="\(nsP)"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst><p:sldSz cx="\(defaultSlideWidth.rawValue)" cy="\(defaultSlideHeight.rawValue)"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>
        """

    /// The empty shape tree every cSld must contain: the root group shape with
    /// its non-visual properties and a zeroed transform.
    static let emptySpTree = """
        <p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>
        """

    /// Master: cSld (with a theme-background reference), the color map binding
    /// scheme slots to master roles, and the layout list. r:id values refer to
    /// this part's own rels.
    static let slideMasterXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:a="\(nsA)" xmlns:r="\(nsR)" xmlns:p="\(nsP)"><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>\(emptySpTree)</p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>
        """

    static let slideLayoutXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:a="\(nsA)" xmlns:r="\(nsR)" xmlns:p="\(nsP)" type="blank" preserve="1"><p:cSld name="Blank">\(emptySpTree)</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
        """

    static let slideXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="\(nsA)" xmlns:r="\(nsR)" xmlns:p="\(nsP)"><p:cSld>\(emptySpTree)</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
        """

    /// The standard Office theme, complete per schema: 12-color clrScheme,
    /// major/minor fontScheme, and a fmtScheme with exactly 3 fill styles,
    /// 3 line styles, 3 effect styles and 3 background fill styles.
    static let themeXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="\(nsA)" name="Office Theme"><a:themeElements><a:clrScheme name="Office"><a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2><a:accent1><a:srgbClr val="4472C4"/></a:accent1><a:accent2><a:srgbClr val="ED7D31"/></a:accent2><a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4><a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme><a:fontScheme name="Office"><a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme><a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:lumMod val="110000"/><a:satMod val="105000"/><a:tint val="67000"/></a:schemeClr></a:gs><a:gs pos="50000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="103000"/><a:tint val="73000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="109000"/><a:tint val="81000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:satMod val="103000"/><a:lumMod val="102000"/><a:tint val="94000"/></a:schemeClr></a:gs><a:gs pos="50000"><a:schemeClr val="phClr"><a:satMod val="110000"/><a:lumMod val="100000"/><a:shade val="100000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="99000"/><a:satMod val="120000"/><a:shade val="78000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill></a:fillStyleLst><a:lnStyleLst><a:ln w="6350" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln><a:ln w="12700" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln><a:ln w="19050" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst><a:outerShdw blurRad="57150" dist="19050" dir="5400000" algn="ctr" rotWithShape="0"><a:srgbClr val="000000"><a:alpha val="63000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:tint val="95000"/><a:satMod val="170000"/></a:schemeClr></a:solidFill><a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="93000"/><a:satMod val="150000"/><a:shade val="98000"/><a:lumMod val="102000"/></a:schemeClr></a:gs><a:gs pos="50000"><a:schemeClr val="phClr"><a:tint val="98000"/><a:satMod val="130000"/><a:shade val="90000"/><a:lumMod val="103000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="63000"/><a:satMod val="120000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>
        """

    static func corePropertiesXML(created: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: created)
        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title/><dc:creator>Rostrum</dc:creator><cp:lastModifiedBy>Rostrum</cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">\(stamp)</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">\(stamp)</dcterms:modified></cp:coreProperties>
            """
    }

    static let appPropertiesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Rostrum</Application><PresentationFormat>Widescreen</PresentationFormat><Slides>1</Slides></Properties>
        """
}
