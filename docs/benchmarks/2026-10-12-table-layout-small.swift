import Foundation
import Rostrum
import RostrumLayout
@testable import LecternCore

let source = try Presentation()
source.documentKind = .template
let input = try source.serializedData()
let template = try PowerPointTemplate(data: input, name: "Benchmark")
var output: [[String: Any]] = []
for unique in [false, true] {
    let data = IRTable(headers: ["Item", "Status", "Result"], rows: (0..<7).map { row in
        [unique ? "Item \(row)" : "Item", "Ready for review", "Complete"]
    })
    let slide = IRSlide(id: "table", layout: "table", title: "Table planning", body: Body(table: data))
    for trial in 0..<7 {
        let deck = try Presentation.fromTemplate(data: input)
        let engine = TemplateLayoutEngine(presentation: deck)
        var warnings: [String] = []
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<20 { _ = try TemplateRendering.build(slide, in: deck, template: template, image: nil, warnings: &warnings, engine: engine) }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        output.append(["unique": unique, "trial": trial, "seconds": elapsed, "slides": deck.slides.count])
    }
}
print(String(decoding: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
