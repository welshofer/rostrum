import Foundation
import KeynoteInterchange
import LecternIR

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".build/keyx-example", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let deck = DeckIR(meta: Meta(title: "Native Keynote Interchange"), slides: [
    IRSlide(id: "intro", layout: "title", title: "Keynote, directly from Swift",
            body: Body(subtitle: "Editable text, vector shapes, images, tables and charts.\nNo PPTX intermediate."),
            notes: "This fixture is authored locally and contains no Apple theme artwork."),
    IRSlide(id: "table", layout: "table", title: "Editable native table",
            body: Body(table: IRTable(headers: ["Capability", "Status"], rows: [
                ["Reader and writer", "Native Swift"], ["Unknown fields", "Preserved"], ["Previews", "Explicit approximations"]
            ]))),
    IRSlide(id: "chart", layout: "chart", title: "Editable native chart",
            body: Body(chart: IRChart(kind: "bar", categories: ["Read", "Edit", "Write"],
                                      series: [IRSeries(name: "Example values", values: [4, 7, 9])]))),
    IRSlide(id: "line", layout: "chart", title: "Native line chart",
            body: Body(chart: IRChart(kind: "line", categories: ["One", "Two", "Three"],
                                      series: [IRSeries(name: "Example values", values: [2, 5, 4])]))),
    IRSlide(id: "pie", layout: "chart", title: "Native pie chart",
            body: Body(chart: IRChart(kind: "pie", categories: ["North", "South", "West"],
                                      series: [IRSeries(name: "Example values", values: [4, 3, 2])]))),
    IRSlide(id: "image", layout: "imageRight", title: "Owned resource, exact bytes",
            body: Body(bullets: [Bullet(text: "This small generated pixel fixture is embedded in Data/.")]),
            image: ImageBrief(prompt: "Local pixel fixture"))
])
guard let pixels = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAG0lEQVR4nGP4z8DwH4SRIJoAlA8EDA0gjCEAAE9EIeGwsrFwAAAAAElFTkSuQmCC") else {
    throw KeyxError.invalid("Invalid fixture")
}
var result = try KeyxAuthor.render(deck, images: ["image": pixels])
try result.document.editSlide(at: 0) { slide in
    slide.node["example_extension"] = .object(["preserved": .bool(true), "large_integer": .number("9007199254740993")])
}
let url = directory.appendingPathComponent("Native Keynote Interchange.keyx")
try result.document.save(to: url)
let reopened = try KeyxDocument(contentsOf: url)
for index in try reopened.slides.indices {
    let preview = try KeyxPreviewRenderer.render(reopened, slideAt: index)
    try Data(preview.svg.utf8).write(to: directory.appendingPathComponent("slide-\(index + 1).svg"), options: .atomic)
}
print("Saved and reopened \(try reopened.slides.count) slides: \(url.path)")
for warning in result.warnings { print("Authoring: \(warning)") }
for issue in reopened.validate() { print("Validation: \(issue)") }
