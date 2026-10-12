import Foundation
import Rostrum
import RostrumLayout
#if os(Linux)
import Glibc
#else
import Darwin
#endif

let scenario = CommandLine.arguments[1]
let unique = scenario.hasSuffix("-unique")
let deck = try Presentation()
deck.theme.minorFont = "DejaVu Sans"
if !scenario.hasPrefix("plain-fallback") {
    try deck.fonts.register(contentsOf: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf"))
}
let slide = try deck.slides[0]
for index in 0..<100 {
    let mixed = scenario.hasPrefix("mixed")
    let shrink = scenario.hasPrefix("shrink")
    let shape = try slide.shapes.addTextBox(Rect(x: .points(20), y: .points(20), width: .points(280), height: .points(mixed ? 45 : 100)))
    let tf = shape.textFrame!
    tf.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
    tf.clear()
    let paragraph = tf.addParagraph()
    let label = unique ? "Measured text \(index) " : "Measured text "
    let run = paragraph.addRun(shrink ? String(repeating: label, count: 8) : label)
    run.fontSize = mixed || shrink ? 24 : 18
    run.fontName = "DejaVu Sans"
    if mixed { let second = paragraph.addRun("LARGE"); second.fontSize = 48; second.fontName = "DejaVu Sans" }
}
func cpu() -> Double {
    var time = timespec()
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time)
    return Double(time.tv_sec) + Double(time.tv_nsec) / 1e9
}
#if LEGACY
let fitter = LegacyAuthoredLayoutEngine(presentation: deck)
#else
let fitter = AuthoredLayoutEngine(presentation: deck)
#endif
let start = ProcessInfo.processInfo.systemUptime, cpuStart = cpu()
var error: String?
do { try fitter.fitText(in: slide) } catch let failure { error = String(describing: failure) }
let cpuMS = (cpu() - cpuStart) * 1000
let elapsedMS = (ProcessInfo.processInfo.systemUptime - start) * 1000
var result: [String: Any] = ["scenario": scenario, "cpuMS": cpuMS, "elapsedMS": elapsedMS, "shapes": 100]
if let error { result["error"] = error }
// Verification is outside the measured section. Both implementations are
// checked against the same complete rich-text engine and saved text bodies.
let bodies = try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?
    .childElements.compactMap { $0.firstChild(named: "p:txBody") } ?? []
result["fittingShapes"] = bodies.filter {
    RichTextLayout(textBody: $0, width: 280, height: scenario.hasPrefix("mixed") ? 45 : 100,
                   fonts: deck.fonts, theme: deck.theme, maxLines: 64).fits
}.count
if CommandLine.arguments.count > 2 { try deck.serializedData().write(to: URL(fileURLWithPath: CommandLine.arguments[2])) }
print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
