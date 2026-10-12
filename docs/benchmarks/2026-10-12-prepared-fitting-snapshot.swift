import Foundation
import Rostrum

func snapshot(_ value: Any) -> Any {
    if let d = value as? Double { return ["doubleBits": String(d.bitPattern)] }
    if let s = value as? String { return s }
    if let b = value as? Bool { return b }
    if let i = value as? Int { return i }
    if let u = value as? UInt32 { return String(u) }
    let mirror = Mirror(reflecting: value)
    return ["type": String(reflecting: type(of: value)),
            "leaf": mirror.children.isEmpty ? String(reflecting: value) : "",
            "children": mirror.children.map { ["label": $0.label ?? "", "value": snapshot($0.value)] }]
}
let registered = FontLibrary()
for name in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique", "DejaVuSerif"] {
    try registered.register(contentsOf: URL(fileURLWithPath: "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/" + name + ".ttf"))
}
var snapshots: [Any] = []
        let contents = [
            "mixed": """
            <a:p><a:pPr><a:lnSpc><a:spcPts val="3300"/></a:lnSpc><a:buNone/></a:pPr><a:r><a:rPr sz="2423" spc="125" kern="2200" cap="all"/><a:t>AVATAR ToT </a:t></a:r><a:r><a:rPr sz="4800" b="1" u="sng"/><a:t>Large</a:t></a:r><a:r><a:rPr sz="2200" i="1"><a:latin typeface="DejaVu Sans"/></a:rPr><a:t> italic</a:t></a:r></a:p>
            """,
            "tabs": """
            <a:p><a:pPr><a:tabLst><a:tab pos="1270000" algn="dec"/></a:tabLst><a:buAutoNum type="arabicPeriod"/></a:pPr><a:r><a:t>Alpha\t12.75\nBeta\t3.0</a:t></a:r></a:p><a:p><a:pPr lvl="1"><a:buSzPct val="75000"/><a:buChar char="•"/></a:pPr><a:r><a:t>Nested words wrap here</a:t></a:r></a:p>
            """,
            "breaks": """
            <a:p><a:r><a:t>Start</a:t></a:r><a:br><a:rPr sz="3200"/></a:br><a:fld type="slidenum"><a:rPr sz="2200"/><a:t>1</a:t></a:fld><a:r><a:rPr baseline="25000"/><a:t> note</a:t></a:r><a:br/><a:endParaRPr sz="2900" i="1"/></a:p>
            """,
            "scripts": """
            <a:p><a:r><a:t>office é café 中文 אבד 123 مرحبا</a:t></a:r></a:p><a:p><a:r><a:rPr><a:latin typeface="Unregistered face"/></a:rPr><a:t>Missing 🙂</a:t></a:r></a:p>
            """,
            "empty": """
            <a:p><a:endParaRPr sz="3800" b="1"/></a:p><a:p><a:r><a:t>\n</a:t></a:r><a:endParaRPr sz="2100" i="1"/></a:p>
            """,
            "invalid": """
            <a:p><a:pPr marL="NaN" indent="-10000"><a:lnSpc><a:spcPct val="110000"/></a:lnSpc></a:pPr><a:r><a:rPr sz="NaN" spc="inf" kern="0"/><a:t>Bounded malformed attributes</a:t></a:r></a:p>
            """
        ]
        let inherited = try XML.parse(Data("""
        <a:lstStyle><a:defPPr marR="10000"><a:spcBef><a:spcPts val="1000"/></a:spcBef><a:spcAft><a:spcPts val="800"/></a:spcAft><a:defRPr sz="2400"><a:solidFill><a:schemeClr val="accent1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:defPPr><a:lvl2pPr marL="200000" indent="-100000"><a:defRPr sz="1800"/></a:lvl2pPr></a:lstStyle>
        """.utf8))
        let theme = try Presentation().theme
        theme.minorFont = "DejaVu Sans"

for name in contents.keys.sorted() {
    for library: FontLibrary? in [nil, registered] {
        let body = try XML.parse(Data(("<p:txBody><a:bodyPr anchor=\"ctr\"/><a:lstStyle/>" + contents[name]! + "</p:txBody>").utf8))
        for scale in [100.0, 99.99, 88.3, 75, 60, 0.9, 0.1] {
            for width in [42.0, 141.25] {
                for context in [RichTextLayout.Context.shape, .tableCell] {
                    for limit in [2, 64] {
                        let layout = RichTextLayout(textBody: body, width: width, height: 65.75,
                            fonts: library, theme: theme, inheritedStyles: [inherited],
                            fontScale: scale, lineSpacingReduction: 10, slideNumber: 42,
                            maxLines: limit, context: context)
                        snapshots.append(snapshot(layout))
                    }
                }
            }
        }
    }
}
for family in ["DejaVu Sans", "DejaVu Serif"] {
    let shaper = TextShaper(registered.metrics(for: family)!)
    for text in ["AVATAR office", "é café", "A אב 123", "中文\r\nWords", "x\u{200B}y\u{202E}z", "مرحبا", "🙂", ""] {
        for direction in [TextDirection.automatic, .leftToRight, .rightToLeft] {
            for size in [0.0, 0.9, 10.3, 24, 99.9, .infinity] {
                for kerning in [false, true] {
                    snapshots.append(snapshot(shaper.shape(text, pointSize: size, direction: direction, kerning: kerning)))
                }
            }
        }
    }
}
try JSONSerialization.data(withJSONObject: snapshots, options: [.sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("snapshots", snapshots.count)
