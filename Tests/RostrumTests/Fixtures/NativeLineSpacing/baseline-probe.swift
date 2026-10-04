import Foundation
@testable import Rostrum

struct Input: Decodable {
    let name: String
    let page: Int
    let width: Double
    let height: Double
    let table: Bool?
}
struct Observation: Encodable {
    struct Line: Encodable { let text: String; let baseline: Double; let height: Double; let width: Double }
    let name: String
    let lines: [Line]
    let contentHeight: Double
    let fits: Bool
    let diagnostics: [String]
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let font = URL(fileURLWithPath: CommandLine.arguments[2])
let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: root.appendingPathComponent("cases.json")))
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("manifest.json"))) as! [String: Any]
let deck = try Presentation(contentsOf: root.appendingPathComponent(manifest["source"] as! String))
let before = try deck.serializedData()
let fonts = FontLibrary()
try fonts.register(Data(contentsOf: font), aliases: ["DejaVu Sans"])
try fonts.register(Data(contentsOf: URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf")), aliases: ["Arial"])
var observations: [Observation] = []
for input in inputs {
    let shape = try deck.slides[input.page].shapes.first { $0.name == input.name }!
    let frame: TextFrame
    if input.table == true { frame = try (shape as! TableFrame).table!.cell(0, 0).textFrame }
    else { frame = shape.textFrame! }
    let layout = RichTextLayout(textBody: frame.txBody, width: input.width, height: input.height, fonts: fonts)
    observations.append(Observation(name: input.name, lines: layout.lines.map {
        Observation.Line(text: $0.spans.map(\.run.text).joined(), baseline: $0.baseline, height: $0.height, width: $0.width)
    }, contentHeight: layout.contentHeight, fits: layout.fits, diagnostics: layout.diagnostics.map { String(describing: $0) }))
}
guard try deck.serializedData() == before else { fatalError("layout mutated package") }
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(observations).write(to: root.appendingPathComponent("baseline-library-layout.json"))
