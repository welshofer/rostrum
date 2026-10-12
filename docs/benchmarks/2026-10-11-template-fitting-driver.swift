import Foundation
import Rostrum
import RostrumLayout
#if os(Linux)
import Glibc
#else
import Darwin
#endif
let scenario = CommandLine.arguments.dropFirst().first ?? "plan-plain"
let deck = try Presentation()
deck.theme.majorFont = "DejaVu Sans"
deck.theme.minorFont = "DejaVu Sans"
let fontRoot = URL(fileURLWithPath: "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
for name in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
    try deck.fonts.register(contentsOf: fontRoot.appendingPathComponent(name + ".ttf"))
}
let layout = deck.layout(type: "obj")!
let frame = scenario.hasPrefix("fit-") ? Rect(x: .points(30), y: .points(130), width: .points(330), height: .points(110)) : layout.placeholders.first { $0.index == 1 }!.frame!
func child(_ element: XML.Element, _ name: String) -> XML.Element {
    if let existing = element.firstChild(named: name) { return existing }
    let result = XML.Element(name); element.appendElement(result); return result
}
let tree = try layout.part.dom().firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!
let shape = tree.children(named: "p:sp").first { $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "idx"] == "1" }!
let text = child(shape, "p:txBody")
let properties = child(child(text, "a:lstStyle"), "a:lvl1pPr")
child(properties, "a:defRPr")[attribute: "sz"] = "2400"
if scenario.hasPrefix("fit-") {
    let transform = child(child(shape, "p:spPr"), "a:xfrm")
    let offset = child(transform, "a:off"), extent = child(transform, "a:ext")
    offset[attribute: "x"] = String(frame.x.rawValue); offset[attribute: "y"] = String(frame.y.rawValue)
    extent[attribute: "cx"] = String(frame.width.rawValue); extent[attribute: "cy"] = String(frame.height.rawValue)
    for key in ["lIns", "rIns", "tIns", "bIns"] { child(text, "a:bodyPr")[attribute: key] = "0" }
    let body = child(text, "a:bodyPr")
    body.children.removeAll { node in if case .element(let e) = node { return ["a:normAutofit", "a:noAutofit", "a:spAutoFit"].contains(e.name) }; return false }
    body.appendElement(XML.Element("a:normAutofit"))
    if scenario == "fit-tabs" {
        child(properties, "a:tabLst").appendElement(XML.Element("a:tab", attributes: [("pos", "1524000"), ("algn", "l")]))
    }
}
layout.part.markDirty()
#if LEGACY
let engine = LegacyTemplateLayoutEngine(presentation: deck)
#else
let engine = TemplateLayoutEngine(presentation: deck)
#endif
let before = try deck.serializedData()
let iterations = 40
func cpu() -> Double { var value = timespec(); clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value); return Double(value.tv_sec) + Double(value.tv_nsec) / 1e9 }
var accepted = 0
var plans: [TemplateSlidePlan] = []
var lastContent = ""
let start = ProcessInfo.processInfo.systemUptime, cpuStart = cpu()
for index in 0..<iterations {
    let suffix = scenario.hasSuffix("unique") ? " \(index)" : ""
    let content = scenario == "fit-tabs" ? "Alpha\tBeta\nGamma\tDelta" : scenario.hasPrefix("fit-") ? String(repeating: "Measured text\(suffix) ", count: 10) : "An evidence statement\(suffix)"
    lastContent = content
    if scenario.hasPrefix("fit-") {
        if engine.fits([LayoutParagraph(content)], in: frame, layout: layout, slot: 1) { accepted += 1 }
    } else {
        let plan = try engine.plan(title: "A title\(suffix)", columns: [[LayoutParagraph("Section", role: .heading), LayoutParagraph(content)]], preferredTypes: ["obj"])
        plans.append(plan)
        accepted += 1
    }
}
let cpuMS = (cpu() - cpuStart) * 1000
let elapsedMS = (ProcessInfo.processInfo.systemUptime - start) * 1000
let unchanged = try before == deck.serializedData()
guard unchanged else { fatalError("Read-only planning changed document bytes") }
let columns = scenario.hasPrefix("fit-") ? [[LayoutParagraph(lastContent)]] : [[LayoutParagraph("Section", role: .heading), LayoutParagraph(lastContent)]]
let proofPlan = try plans.last ?? engine.plan(title: "A title", columns: columns, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
let slide = try engine.compose(proofPlan, title: "A title", columns: columns)
let fitting = slide.shapes.all.filter { shape in
    guard let text = shape.element.firstChild(named: "p:txBody"), let frame = slide.effectiveFrame(of: shape) else { return false }
    return RichTextLayout(textBody: text, width: frame.width.points, height: frame.height.points,
        fonts: deck.fonts, theme: slide.master?.theme,
        inheritedStyles: RichTextLayout.inheritedStyles(for: shape.element, owner: slide.part, package: deck.package), maxLines: 64).fits
}.count
let bytes = try deck.serializedData()
if CommandLine.arguments.count > 2 { try bytes.write(to: URL(fileURLWithPath: CommandLine.arguments[2])) }
let choices = Array(Set(plans.map { plan in
    plan.layout.part.uri.value + " " + plan.textFits.sorted { $0.key < $1.key }.map { index, fit in
        "\(index):\(fit.frame.x.rawValue),\(fit.frame.y.rawValue),\(fit.frame.width.rawValue),\(fit.frame.height.rawValue)@\(fit.fontScale)"
    }.joined(separator: ";")
})).sorted()
print(String(decoding: try JSONSerialization.data(withJSONObject: ["scenario":scenario, "iterations":iterations, "accepted":accepted, "cpuMS":cpuMS, "elapsedMS":elapsedMS, "sourcePreserved":unchanged, "outputFittingShapes":fitting, "outputShapes":slide.shapes.all.count, "choices":choices], options:.sortedKeys), as:UTF8.self))
