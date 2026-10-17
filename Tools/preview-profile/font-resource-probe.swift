import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
@main struct Probe {
    static func document(_ svg: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <style>
          html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
          body > svg { display: block; width: 100%; height: 100%; }
        </style></head><body>\(svg)</body></html>
        """
    }
    static func main() throws {
        let paths = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        let svgs = try paths.map { try String(contentsOfFile: $0, encoding: .utf8) }
        let shared = CommandLine.arguments[1] == "shared"
        let store = PreviewFontResources()
        var samples = [[String: Any]]()
        for _ in 0..<2 {
            let start = ProcessInfo.processInfo.systemUptime, cpu = clock()
            var bytes = 0, resourceBytes = 0
            for svg in svgs {
                if shared {
                    let prepared = store.prepare(svg: svg)
                    bytes += document(prepared.svg).utf8.count
                    resourceBytes += prepared.resources.reduce(0) { $0 + $1.data.count }
                } else { bytes += document(svg).utf8.count }
            }
            samples.append(["elapsedSeconds": ProcessInfo.processInfo.systemUptime-start,
                            "cpuSeconds": Double(clock()-cpu)/Double(CLOCKS_PER_SEC),
                            "htmlBytes": bytes, "fontBytesIfRequestedEverySlide": resourceBytes])
        }
        var usage = rusage()
        #if canImport(Glibc)
        getrusage(__rusage_who_t(RUSAGE_SELF.rawValue), &usage)
        let peakRSSBytes = usage.ru_maxrss * 1024
        #else
        getrusage(RUSAGE_SELF, &usage)
        let peakRSSBytes = usage.ru_maxrss
        #endif
        let report: [String:Any] = ["mode":CommandLine.arguments[1],"samples":samples,"retainedBytes":store.retainedBytes,
                                   "decodedResources":store.decodedResources,"peakRSSBytes":peakRSSBytes]
        print(String(decoding: try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
        if CommandLine.arguments.contains("verify") {
            // Optional, untimed evidence for comparing implementations. Only
            // the random store namespace is normalized; IDs and ordering stay.
            let output = CommandLine.arguments.firstIndex(of: "artifacts").map {
                URL(fileURLWithPath: CommandLine.arguments[$0 + 1], isDirectory: true)
            }
            if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false) }
            for (index, svg) in svgs.enumerated() {
                let prepared = store.prepare(svg: svg)
                let restored = prepared.resources.reduce(prepared.svg) { result,r in
                    result.replacingOccurrences(of:r.url + ")",with:"data:\(r.mimeType);base64,\(r.data.base64EncodedString()))")
                }
                guard Data(restored.utf8) == Data(svg.utf8) else { fatalError("Output changed") }
                if let output {
                    var normalized = prepared.svg
                    for resource in prepared.resources {
                        let id = URL(string: resource.url)!.lastPathComponent
                        normalized = normalized.replacingOccurrences(of: resource.url + ")",
                            with: "\(PreviewFontResources.scheme)://store/\(id))")
                        try resource.data.write(to: output.appendingPathComponent("font-\(id).bin"))
                    }
                    try Data(normalized.utf8).write(to: output.appendingPathComponent("slide-\(index + 1).svg"))
                    let inventory = prepared.resources.map { ["id": URL(string: $0.url)!.lastPathComponent, "mime": $0.mimeType] }
                    try JSONSerialization.data(withJSONObject: inventory, options: [.sortedKeys])
                        .write(to: output.appendingPathComponent("slide-\(index + 1)-resources.json"))
                }
            }
        }
    }
}
