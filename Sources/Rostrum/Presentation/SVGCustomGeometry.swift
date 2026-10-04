import Foundation

/// Read-only DrawingML paths. Coordinates are resolved before emission so a
/// path's private coordinate system cannot scale the shape's stroke width.
enum SVGCustomGeometry {
    struct Path {
        let data: String
        let fill: Bool
        let stroke: Bool
    }

    static func paths(_ geometry: XML.Element, width: Double, height: Double) -> [Path]? {
        guard width >= 0, height >= 0, width.isFinite, height.isFinite,
              let list = geometry.firstChild(named: "a:pathLst"),
              !list.childElements.isEmpty, list.childElements.count <= 4096 else { return nil }
        var values: [String: Double] = ["w": width, "h": height, "l": 0, "t": 0,
            "r": width, "b": height, "hc": width / 2, "vc": height / 2,
            "ss": min(width, height), "ls": max(width, height), "cd2": 10800000,
            "cd4": 5400000, "cd8": 2700000, "3cd4": 16200000]
        for divisor in [2, 3, 4, 5, 6, 8, 10, 12, 16, 32] {
            values["wd\(divisor)"] = width / Double(divisor)
            values["hd\(divisor)"] = height / Double(divisor)
            values["ssd\(divisor)"] = min(width, height) / Double(divisor)
        }
        func value(_ token: String?) -> Double? {
            guard let token, let number = values[token] ?? Double(token),
                  number.isFinite, abs(number) <= 1e14 else { return nil }
            return number
        }
        // Unsupported, unused connection-site guides do not invalidate paths.
        // A path that references one fails explicitly rather than inventing 0.
        for name in ["a:avLst", "a:gdLst"] {
            let guides = geometry.firstChild(named: name)?.childElements ?? []
            guard guides.count <= 4096 else { return nil }
            for guide in guides {
                guard let name = guide[attribute: "name"], let formula = guide[attribute: "fmla"] else { continue }
                let tokens = formula.split(whereSeparator: \.isWhitespace).map(String.init)
                guard let op = tokens.first else { continue }
                let args = tokens.dropFirst().compactMap { value($0) }
                guard args.count == tokens.count - 1 else { values[name] = nil; continue }
                let result: Double?
                switch (op, args.count) {
                case ("val", 1): result = args[0]
                case ("*/", 3): result = args[2] == 0 ? nil : args[0] * args[1] / args[2]
                case ("+-", 3): result = args[0] + args[1] - args[2]
                case ("+/", 3): result = args[2] == 0 ? nil : (args[0] + args[1]) / args[2]
                case ("?:", 3): result = args[0] > 0 ? args[1] : args[2]
                case ("abs", 1): result = abs(args[0])
                case ("min", 2): result = min(args[0], args[1])
                case ("max", 2): result = max(args[0], args[1])
                case ("sqrt", 1): result = args[0] >= 0 ? sqrt(args[0]) : nil
                case ("pin", 3): result = max(args[0], min(args[1], args[2]))
                case ("mod", 3): result = hypot(hypot(args[0], args[1]), args[2])
                case ("sin", 2): result = args[0] * sin(args[1] * .pi / 10800000)
                case ("cos", 2): result = args[0] * cos(args[1] * .pi / 10800000)
                case ("tan", 2): result = args[0] * tan(args[1] * .pi / 10800000)
                case ("at2", 2): result = atan2(args[1], args[0]) * 10800000 / .pi
                case ("cat2", 3): result = args[0] * cos(atan2(args[2], args[1]))
                case ("sat2", 3): result = args[0] * sin(atan2(args[2], args[1]))
                default: result = nil
                }
                values[name] = result.flatMap { $0.isFinite && abs($0) <= 1e14 ? $0 : nil }
            }
        }
        var result: [Path] = [], commands = 0
        for path in list.childElements {
            guard path.name == "a:path", [nil, "norm", "none"].contains(path[attribute: "fill"]) else { return nil }
            guard path[attribute: "w"] == nil || path[attribute: "w"].flatMap(Double.init) != nil,
                  path[attribute: "h"] == nil || path[attribute: "h"].flatMap(Double.init) != nil else { return nil }
            let pw = path[attribute: "w"].flatMap(Double.init) ?? width
            let ph = path[attribute: "h"].flatMap(Double.init) ?? height
            guard pw > 0, ph > 0, pw.isFinite, ph.isFinite else { return nil }
            let sx = width / pw, sy = height / ph
            var parts: [String] = [], hasPoint = false
            for command in path.childElements {
                commands += 1
                guard commands <= 65536 else { return nil }
                if command.name == "a:close" {
                    guard hasPoint else { return nil }; parts.append("Z"); continue
                }
                let count: Int, letter: String
                switch command.name {
                case "a:moveTo": count = 1; letter = "M"
                case "a:lnTo": count = 1; letter = "L"
                case "a:quadBezTo": count = 2; letter = "Q"
                case "a:cubicBezTo": count = 3; letter = "C"
                default: return nil
                }
                guard command.name == "a:moveTo" || hasPoint else { return nil }
                let points = command.children(named: "a:pt")
                guard points.count == count else { return nil }
                var coordinates: [String] = []
                for point in points {
                    guard let x = value(point[attribute: "x"]), let y = value(point[attribute: "y"]),
                          (x * sx).isFinite, (y * sy).isFinite,
                          abs(x * sx) <= 1e14, abs(y * sy) <= 1e14 else { return nil }
                    coordinates.append(SVGNumber.decimal(x * sx) + " " + SVGNumber.decimal(y * sy))
                }
                parts.append(letter + coordinates.joined(separator: " ")); hasPoint = true
            }
            guard hasPoint else { return nil }
            result.append(Path(data: parts.joined(separator: " "), fill: path[attribute: "fill"] != "none",
                stroke: !["0", "false"].contains(path[attribute: "stroke"] ?? "1")))
        }
        return result
    }

    static func render(_ paths: [Path], x: Int, y: Int, fill: String, stroke: String) -> String {
        "<g transform=\"translate(\(x) \(y))\">" + paths.map {
            "<path d=\"\($0.data)\" fill=\"\($0.fill ? fill : "none")\"\($0.stroke ? stroke : "")/>"
        }.joined() + "</g>"
    }
}
