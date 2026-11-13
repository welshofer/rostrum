import Foundation

/// Read-only DrawingML paths. Coordinates are resolved before emission so a
/// path's private coordinate system cannot scale the shape's stroke width.
enum SVGCustomGeometry {
    struct Path {
        let data: String
        let fill: Bool
        let stroke: Bool
        let closed: Bool
        /// DrawingML path shading: an overlay opacity, negative for black
        /// (`darken`, `darkenLess`) and positive for white (`lighten`,
        /// `lightenLess`). ECMA-376 names the modes without fixing amounts;
        /// 40% and 20% are this preview's approximation.
        var shade: Double = 0
    }

    private static let shades: [String: Double] = [
        "norm": 0, "none": 0, "darken": -0.4, "darkenLess": -0.2, "lighten": 0.4, "lightenLess": 0.2,
    ]

    struct Resolved {
        var paths: [Path]
        /// The geometry's `a:rect` text rectangle in shape-local units, when
        /// it has one and every edge resolves.
        var textRect: (left: Double, top: Double, right: Double, bottom: Double)?
    }

    static func supportsArrowheads(_ geometry: XML.Element) -> Bool {
        guard let list = geometry.firstChild(named: "a:pathLst"), !list.childElements.isEmpty else { return false }
        let stroked = list.childElements.filter {
            $0.name == "a:path" && !["0", "false"].contains($0[attribute: "stroke"] ?? "1")
        }
        guard !stroked.isEmpty else { return false }
        return stroked.allSatisfy { path in
            !path.childElements.isEmpty && !path.childElements.contains { $0.name == "a:close" }
        }
    }

    static func paths(_ geometry: XML.Element, width: Double, height: Double) -> [Path]? {
        resolve(geometry, width: width, height: height)?.paths
    }

    static func resolve(_ geometry: XML.Element, width: Double, height: Double) -> Resolved? {
        guard width >= 0, height >= 0, width.isFinite, height.isFinite,
              let list = geometry.firstChild(named: "a:pathLst"),
              !list.childElements.isEmpty, list.childElements.count <= 4096 else { return nil }
        var values: [String: Double] = ["w": width, "h": height, "l": 0, "t": 0,
            "r": width, "b": height, "hc": width / 2, "vc": height / 2,
            "ss": min(width, height), "ls": max(width, height), "cd2": 10800000,
            "cd4": 5400000, "cd8": 2700000, "3cd4": 16200000,
            "3cd8": 8100000, "5cd8": 13500000, "7cd8": 18900000]
        for divisor in [2, 3, 4, 5, 6, 8, 10, 12, 16, 32] {
            values["wd\(divisor)"] = width / Double(divisor)
            values["hd\(divisor)"] = height / Double(divisor)
            values["ssd\(divisor)"] = min(width, height) / Double(divisor)
        }
        // Guides hold intermediate products (the circular-arrow presets square
        // EMU lengths twice), so they get far more headroom than the 1e14
        // bound that emitted coordinates and radii must still satisfy.
        let guideLimit = 1e60
        func value(_ token: String?) -> Double? {
            guard let token, let number = values[token] ?? Double(token),
                  number.isFinite, abs(number) <= guideLimit else { return nil }
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
                values[name] = result.flatMap { $0.isFinite && abs($0) <= guideLimit ? $0 : nil }
            }
        }
        var result: [Path] = [], commands = 0
        for path in list.childElements {
            guard path.name == "a:path", let shade = shades[path[attribute: "fill"] ?? "norm"] else { return nil }
            guard path[attribute: "w"] == nil || path[attribute: "w"].flatMap(Double.init) != nil,
                  path[attribute: "h"] == nil || path[attribute: "h"].flatMap(Double.init) != nil else { return nil }
            let pw = path[attribute: "w"].flatMap(Double.init) ?? width
            let ph = path[attribute: "h"].flatMap(Double.init) ?? height
            guard pw > 0, ph > 0, pw.isFinite, ph.isFinite else { return nil }
            let sx = width / pw, sy = height / ph
            var parts: [String] = [], hasPoint = false, hasClose = false
            var currentX = 0.0, currentY = 0.0, startX = 0.0, startY = 0.0
            for command in path.childElements {
                commands += 1
                guard commands <= 65536 else { return nil }
                if command.name == "a:close" {
                    guard hasPoint else { return nil }
                    parts.append("Z")
                    hasClose = true
                    currentX = startX
                    currentY = startY
                    continue
                }
                if command.name == "a:arcTo" {
                    guard hasPoint, command.childElements.isEmpty,
                          let wR = value(command[attribute: "wR"]),
                          let hR = value(command[attribute: "hR"]),
                          let stAng = value(command[attribute: "stAng"]),
                          let swAng = value(command[attribute: "swAng"]),
                          wR > 0, hR > 0, abs(swAng) <= 21_600_000 else { return nil }
                    let rx = wR * sx, ry = hR * sy
                    guard rx.isFinite, ry.isFinite, rx > 0, ry > 0,
                          abs(rx) <= 1e14, abs(ry) <= 1e14 else { return nil }
                    if swAng == 0 {
                        parts.append("L" + SVGNumber.decimal(currentX * sx) + " " + SVGNumber.decimal(currentY * sy))
                        continue
                    }
                    func unitTrig(_ angle: Double) -> (sin: Double, cos: Double) {
                        let rad = angle * .pi / 10_800_000
                        let s = sin(rad), c = cos(rad)
                        return (abs(s) < 1e-12 ? 0 : s, abs(c) < 1e-12 ? 0 : c)
                    }
                    let startTrig = unitTrig(stAng)
                    let startPhi = atan2(startTrig.sin / hR, startTrig.cos / wR)
                    let cx = currentX - wR * cos(startPhi)
                    let cy = currentY - hR * sin(startPhi)
                    let steps = max(1, min(4, Int(ceil(abs(swAng) / 5_400_000))))
                    let stepSw = swAng / Double(steps)
                    let sweepFlag = stepSw >= 0 ? 1 : 0
                    for step in 1...steps {
                        let stepTrig = unitTrig(stAng + stepSw * Double(step))
                        let phi = atan2(stepTrig.sin / hR, stepTrig.cos / wR)
                        let rawEndX = cx + wR * cos(phi)
                        let rawEndY = cy + hR * sin(phi)
                        let endX = abs(rawEndX - rawEndX.rounded()) < 1e-9 ? rawEndX.rounded() : rawEndX
                        let endY = abs(rawEndY - rawEndY.rounded()) < 1e-9 ? rawEndY.rounded() : rawEndY
                        let rawScaledX = endX * sx, rawScaledY = endY * sy
                        let scaledX = abs(rawScaledX - rawScaledX.rounded()) < 1e-9 ? rawScaledX.rounded() : rawScaledX
                        let scaledY = abs(rawScaledY - rawScaledY.rounded()) < 1e-9 ? rawScaledY.rounded() : rawScaledY
                        guard scaledX.isFinite, scaledY.isFinite,
                              abs(scaledX) <= 1e14, abs(scaledY) <= 1e14 else { return nil }
                        parts.append("A" + SVGNumber.decimal(rx) + " " + SVGNumber.decimal(ry)
                            + " 0 0 \(sweepFlag) " + SVGNumber.decimal(scaledX) + " " + SVGNumber.decimal(scaledY))
                        currentX = endX
                        currentY = endY
                    }
                    continue
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
                    currentX = x
                    currentY = y
                    if command.name == "a:moveTo" {
                        startX = x
                        startY = y
                    }
                }
                parts.append(letter + coordinates.joined(separator: " ")); hasPoint = true
            }
            guard hasPoint else { return nil }
            result.append(Path(data: parts.joined(separator: " "), fill: path[attribute: "fill"] != "none",
                stroke: !["0", "false"].contains(path[attribute: "stroke"] ?? "1"),
                closed: hasClose, shade: shade))
        }
        var textRect: (left: Double, top: Double, right: Double, bottom: Double)?
        if let rect = geometry.firstChild(named: "a:rect"),
           let left = value(rect[attribute: "l"]), let top = value(rect[attribute: "t"]),
           let right = value(rect[attribute: "r"]), let bottom = value(rect[attribute: "b"]),
           right >= left, bottom >= top {
            textRect = (left, top, right, bottom)
        }
        return Resolved(paths: result, textRect: textRect)
    }

    static func render(_ paths: [Path], x: Int, y: Int, fill: String, stroke: String, openMarkerAttrs: String = "") -> String {
        "<g transform=\"translate(\(x) \(y))\">" + paths.map {
            let strokePart = $0.stroke ? (stroke + (!$0.closed ? openMarkerAttrs : "")) : ""
            // Shading is painted over the shape's own fill, so it follows
            // gradients and images instead of replacing them.
            let overlay = $0.fill && $0.shade != 0 && fill != "none"
                ? "<path d=\"\($0.data)\" fill=\"\($0.shade < 0 ? "#000000" : "#FFFFFF")\" fill-opacity=\"\(abs($0.shade) > 0.3 ? "0.4" : "0.2")\"/>"
                : ""
            if !overlay.isEmpty && !strokePart.isEmpty {
                return "<path d=\"\($0.data)\" fill=\"\(fill)\"/>" + overlay
                    + "<path d=\"\($0.data)\" fill=\"none\"\(strokePart)/>"
            }
            return "<path d=\"\($0.data)\" fill=\"\($0.fill ? fill : "none")\"\(strokePart)/>" + overlay
        }.joined() + "</g>"
    }
}
