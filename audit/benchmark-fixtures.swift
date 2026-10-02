import Foundation
import Rostrum
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let deck = try Presentation()
for i in 1...100 {
    switch i % 3 {
    case 0:
        let values = ChartData(categories: ["Q1", "Q2", "Q3", "Q4"], series: [ChartData.Series(name: "Sample", values: [12, 15, 18, Double(20 + i)])])
        try deck.chartSlide("Synthetic series \(i)", .barClustered, values)
    case 1:
        try deck.bulletSlide("Test slide \(i)", ["Every part survives the round trip", "Every slide keeps its original position", "Measurements include all slides in the deck", "No synthetic claim is real research"])
    default:
        try deck.titleSlide("Section \(i)", subtitle: "Synthetic large-deck benchmark")
    }
}
try deck.slides.remove(at: 0)
try deck.save(to: output.appendingPathComponent("large-100.pptx"))
print("Wrote 100-slide synthetic deck")
