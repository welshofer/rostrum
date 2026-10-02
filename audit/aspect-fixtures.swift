import Foundation
import Rostrum
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (name, width, height) in [("wide", 16.0, 9.0), ("classic", 10.0, 7.5), ("portrait", 7.5, 13.333333)] {
    let deck = try Presentation()
    deck.slideSize = (.inches(width), .inches(height))
    let slide = try deck.slides[0]
    for (x, y, color) in [(0.0,0.0,"FF0000"),(width-0.5,0.0,"00FF00"),(0.0,height-0.5,"0000FF"),(width-0.5,height-0.5,"FFFF00")] {
        try slide.shapes.addShape(.rectangle, frame: Rect(x: .inches(x), y: .inches(y), width: .inches(0.5), height: .inches(0.5)), fill: .solid(Color(color)))
    }
    let label = try slide.shapes.addTextBox(Rect(x: .inches(1), y: .inches(height/2-0.5), width: .inches(width-2), height: .inches(1)))
    label.textFrame?.text = "\(name): all four corners survive"
    try deck.save(to: out.appendingPathComponent("\(name).pptx"))
    try deck.renderSVG(slideAt: 0, pixelWidth: 640).write(to: out.appendingPathComponent("\(name).svg"), atomically: true, encoding: .utf8)
}
