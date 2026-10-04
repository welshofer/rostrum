import Foundation

/// DrawingML's Office interpolation differs from SVG for endpoint pairs and
/// mirrored three-stop gradients. Intermediate SVG stops bound the error to
/// less than one 8-bit channel step, before rasterization/quantization.
/// Source: Microsoft Open Specifications, Mike Bowen, 2025-04-17:
/// https://learn.microsoft.com/en-us/answers/questions/2248059/non-preset-a-tilerect-behaves-strange-in-case-of-g
/// General multi-stop gradients retain their authored linear interpolation.
enum GradientStops {
    struct Stop {
        var position: Double
        var color: Color
        var alpha: Double
    }

    static func resolved(_ gradient: XML.Element, theme: Theme) -> [Stop] {
        let authored = (gradient.firstChild(named: "a:gsLst")?.children(named: "a:gs") ?? []).map { node in
            let resolved = SVGPaint.resolve(in: node, theme: theme)
            return Stop(position: Double(node.boundedInt("pos", in: 0...100_000) ?? 0) / 100_000,
                        color: resolved?.color ?? .black, alpha: resolved?.opacity ?? 1)
        }
        return interpolated(authored)
    }

    static func interpolated(_ authored: [Stop]) -> [Stop] {
        guard authored.count == 2 || authored.count == 3,
              authored.first?.position == 0, authored.last?.position == 1 else { return authored }
        if authored.count == 3 {
            guard authored[1].position > 0, authored[1].position < 1,
                  authored[0].color == authored[2].color,
                  authored[0].alpha == authored[2].alpha else { return authored }
        }
        var result: [Stop] = []
        // At most 65 stops, independent of pixel size or input dimensions.
        for index in 0..<(authored.count - 1) {
            let start = authored[index], end = authored[index + 1]
            for step in 0..<32 {
                let t = Double(step) / 32
                func channel(_ a: Int, _ b: Int) -> Int {
                    let weight = b > a ? 1 - pow(1 - t, 1.875) : pow(t, 1.875)
                    return Int((Double(a) + Double(b - a) * weight).rounded())
                }
                result.append(Stop(position: start.position + (end.position - start.position) * t,
                    color: Color(red: channel(start.color.red, end.color.red),
                                 green: channel(start.color.green, end.color.green),
                                 blue: channel(start.color.blue, end.color.blue)),
                    alpha: start.alpha + (end.alpha - start.alpha) * t))
            }
        }
        result.append(authored.last!)
        return result
    }

    static func svg(_ gradient: XML.Element, theme: Theme) -> String {
        resolved(gradient, theme: theme).map { stop in
            let color = stop.alpha < 1
                ? "rgba(\(stop.color.red),\(stop.color.green),\(stop.color.blue),\(stop.alpha))"
                : "#" + stop.color.hex
            return "<stop offset=\"\(stop.position)\" stop-color=\"\(color)\"/>"
        }.joined()
    }
}
