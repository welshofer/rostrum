import Foundation
import Rostrum

// One input per process makes /usr/bin/time's peak RSS attributable to one deck.
// Timings exclude disk I/O and the independent fidelity checks below.
struct Sample: Codable {
    let openMS: Double
    let serializeMS: Double
    let firstSVGPassMS: Double
    let repeatSVGPassMS: Double
}

struct Result: Codable {
    let input: String
    let inputBytes: Int
    let slides: Int
    let pixelWidth: Int
    let samples: [Sample]
    let median: Sample
    let allPartPayloadsPreserved: Bool
    let deterministicSave: Bool
    let reopenedSVGsMatch: Bool
}

enum Failure: Error { case invalidArguments, outputExists, fidelity(String) }

@MainActor
func timed<T>(_ body: () throws -> T) rethrows -> (T, Double) {
    let start = ProcessInfo.processInfo.systemUptime
    let value = try body()
    return (value, (ProcessInfo.processInfo.systemUptime - start) * 1000)
}

func median(_ values: [Double]) -> Double {
    let sorted = values.sorted(), middle = values.count / 2
    return values.count.isMultiple(of: 2)
        ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

@MainActor
func run() throws {
    let args = CommandLine.arguments
    guard args.count == 3 || args.count == 4,
          let iterations = Int(args.count == 4 ? args[3] : "3"), (1...100).contains(iterations) else {
        throw Failure.invalidArguments
    }
    let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
    guard !FileManager.default.fileExists(atPath: output.path) else { throw Failure.outputExists }
    let bytes = try Data(contentsOf: input)
    let pixelWidth = 640
    var samples: [Sample] = []
    var saved = Data(), referenceSVGs: [String] = []
    var slideCount = 0
    for _ in 0..<iterations {
        let (deck, open) = try timed { try Presentation(data: bytes) }
        slideCount = deck.slides.count
        let (serialized, save) = try timed { try deck.serializedData() }
        let (first, render) = try timed {
            try (0..<slideCount).map { try deck.renderSVG(slideAt: $0, pixelWidth: pixelWidth) }
        }
        let (again, repeatRender) = try timed {
            try (0..<slideCount).map { try deck.renderSVG(slideAt: $0, pixelWidth: pixelWidth) }
        }
        guard first == again else { throw Failure.fidelity("Repeated SVG pass differs") }
        guard serialized == (try deck.serializedData()) else {
            throw Failure.fidelity("Serialization differs after read-only rendering")
        }
        if !saved.isEmpty, saved != serialized { throw Failure.fidelity("Save differs across samples") }
        saved = serialized
        referenceSVGs = first
        samples.append(Sample(openMS: open, serializeMS: save, firstSVGPassMS: render,
                              repeatSVGPassMS: repeatRender))
    }

    // Compare decoded payloads, not ZIP container bytes: compression can differ.
    let originalZIP = try ZipReader(data: bytes), savedZIP = try ZipReader(data: saved)
    guard Set(originalZIP.entryNames) == Set(savedZIP.entryNames) else {
        throw Failure.fidelity("Part names changed")
    }
    for name in originalZIP.entryNames {
        guard try originalZIP.data(forEntry: name) == savedZIP.data(forEntry: name) else {
            throw Failure.fidelity("Part payload changed: \(name)")
        }
    }
    let reopened = try Presentation(data: saved)
    guard reopened.slides.count == slideCount else { throw Failure.fidelity("Slide count changed") }
    for index in 0..<slideCount {
        guard try reopened.renderSVG(slideAt: index, pixelWidth: pixelWidth) == referenceSVGs[index] else {
            throw Failure.fidelity("Reopened SVG changed at slide \(index + 1)")
        }
    }
    let result = Result(input: input.lastPathComponent, inputBytes: bytes.count, slides: slideCount,
                        pixelWidth: pixelWidth, samples: samples,
                        median: Sample(openMS: median(samples.map(\.openMS)),
                                       serializeMS: median(samples.map(\.serializeMS)),
                                       firstSVGPassMS: median(samples.map(\.firstSVGPassMS)),
                                       repeatSVGPassMS: median(samples.map(\.repeatSVGPassMS))),
                        allPartPayloadsPreserved: true, deterministicSave: true, reopenedSVGsMatch: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let json = try encoder.encode(result)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try saved.write(to: output.appendingPathComponent("roundtrip.pptx"), options: .atomic)
    for (index, svg) in referenceSVGs.enumerated() {
        try svg.write(to: output.appendingPathComponent("slide-\(index + 1).svg"), atomically: true, encoding: .utf8)
    }
    try json.write(to: output.appendingPathComponent("timings.json"), options: .atomic)
    print(String(decoding: json, as: UTF8.self))
}

do { try run() } catch {
    FileHandle.standardError.write(Data("rostrum-benchmark: \(error)\nUsage: rostrum-benchmark input.pptx NEW-output-directory [iterations: 1...100]\n".utf8))
    exit(1)
}
