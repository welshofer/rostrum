import Foundation
import Rostrum
let inputs = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let fontRoot = URL(fileURLWithPath: "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
struct LocalFonts: Decodable { struct Face: Decodable { let path: String }; let fonts: [Face] }
let external = CommandLine.arguments.count > 3 ? try JSONDecoder().decode(LocalFonts.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))).fonts : []
var counts: [[String: Any]] = []
for input in inputs {
    let deck = try Presentation(contentsOf: URL(fileURLWithPath: input))
    for name in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique", "DejaVuSerif"] {
        try deck.fonts.register(contentsOf: fontRoot.appendingPathComponent(name + ".ttf"))
    }
    for font in external { try deck.fonts.register(contentsOf: URL(fileURLWithPath: font.path)) }
    let path = output.appendingPathComponent(String(input.dropFirst("Tests/RostrumTests/Fixtures/".count)))
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    let saved = try deck.serializedData()
    try saved.write(to: path.appendingPathComponent("saved.pptx"))
    for index in 0..<deck.slides.count {
        let result = try deck.renderSVGReportingProblems(slideAt: index)
        try Data(result.svg.utf8).write(to: path.appendingPathComponent("slide-\(index).svg"))
        try JSONEncoder().encode(result.problems.fidelityIssues).write(to: path.appendingPathComponent("slide-\(index)-issues.json"))
    }
    let afterRender = try deck.serializedData()
    precondition(afterRender == saved)
    let reopened = try Presentation(data: saved)
    let afterReopen = try reopened.serializedData()
    precondition(afterReopen == saved)
    counts.append(["source":input,"slides":deck.slides.count])
}
print(String(decoding: try JSONSerialization.data(withJSONObject: counts,options:[.sortedKeys]),as: UTF8.self))
