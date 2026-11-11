import Foundation

/// Bounded, analytic outlines for common DrawingML presets. This deliberately
/// handles only literal adjustment guides; unsupported formulas stay diagnosed.
/// Outline equations follow ECMA-376 Part 1 presetShapeDefinitions (2016);
/// upArrow uses the Microsoft Open Specifications clarification of May 2025.
enum SVGPresetGeometry {
    static let openPresets: Set<String> = ["line", "straightConnector1", "arc"]
    static let supported: Set<String> = ["rect", "ellipse", "roundRect", "triangle", "rtTriangle", "diamond",
        "parallelogram", "trapezoid", "chevron", "rightArrow", "leftArrow", "upArrow", "downArrow",
        "line", "straightConnector1", "arc"]

    private static func adjustment(_ name: String, fallback: Double, limit: Double, in adjustments: XML.Element?) -> Double {
        guard let formula = adjustments?.children(named: "a:gd").first(where: { $0[attribute: "name"] == name })?[attribute: "fmla"] else { return min(fallback, limit) }
        let parts = formula.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 2, parts[0] == "val", let value = Double(parts[1]), value.isFinite else { return min(fallback, limit) }
        return min(max(0, value), limit)
    }

    private static func angleAdjustment(_ name: String, fallback: Double, in adjustments: XML.Element?) -> Double {
        let fullCircle = 21_600_000.0
        guard let formula = adjustments?.children(named: "a:gd").first(where: { $0[attribute: "name"] == name })?[attribute: "fmla"] else {
            return fallback
        }
        let parts = formula.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 2, parts[0] == "val", let value = Double(parts[1]), value.isFinite, abs(value) <= 1e14 else {
            return fallback
        }
        let wrapped = value.truncatingRemainder(dividingBy: fullCircle)
        return wrapped < 0 ? wrapped + fullCircle : wrapped
    }

    /// Preset text rectangles are part of the geometry definition. Placing text
    /// in the full outer box makes labels disappear against the page at notches.
    static func textFrame(_ preset: String, adjustments: XML.Element?, frame: (Int, Int, Int, Int)) -> (Int, Int, Int, Int) {
        let (x,y,iw,ih) = frame
        let w = Double(max(0,iw)), h = Double(max(0,ih)), ss = Double(max(0,min(iw,ih)))
        func adj(_ name: String, _ fallback: Double, max limit: Double = 100_000) -> Double {
            adjustment(name, fallback: fallback, limit: limit, in: adjustments)
        }
        let l,t,r,b: Double
        switch preset {
        case "diamond": (l,t,r,b) = (w/4,h/4,3*w/4,3*h/4)
        case "ellipse": (l,t,r,b) = (w * 0.1464466094,h * 0.1464466094,w * 0.8535533906,h * 0.8535533906)
        case "triangle":
            let apex = w * adj("adj",50_000) / 100_000
            (l,t,r,b) = (apex/2,h/2,apex/2+w/2,h)
        case "rtTriangle": (l,t,r,b) = (w/12,7*h/12,7*w/12,11*h/12)
        case "roundRect":
            let inset = ss * adj("adj",16_667,max:50_000) / 100_000 * 0.29289
            (l,t,r,b) = (inset,inset,w-inset,h-inset)
        case "parallelogram":
            let limit = ss > 0 ? 100_000*w/ss : 0
            let ratio = limit > 0 ? adj("adj",25_000,max:limit)/limit : 0
            let q = (1 + 5*ratio)/12
            (l,t,r,b) = (q*w,q*h,w-q*w,h-q*h)
        case "trapezoid":
            let limit = ss > 0 ? 50_000*w/ss : 0
            let ratio = limit > 0 ? adj("adj",25_000,max:limit)/limit : 0
            (l,t,r,b) = (w/3*ratio,h/3*ratio,w-w/3*ratio,h)
        case "chevron":
            let inset = ss * adj("adj",50_000,max:ss > 0 ? 100_000*w/ss : 0)/100_000
            (l,t,r,b) = w-2*inset > 0 ? (inset,0,w-inset,h) : (0,0,w,h)
        case "rightArrow", "leftArrow", "upArrow", "downArrow":
            let vertical = preset == "upArrow" || preset == "downArrow"
            let length = vertical ? h : w, thickness = vertical ? w : h
            let head = ss * adj("adj2",50_000,max:ss > 0 ? 100_000*length/ss : 0)/100_000
            let halfShaft = thickness * adj("adj1",50_000)/200_000
            let low = thickness/2-halfShaft, high = thickness/2+halfShaft
            let innerHead = thickness > 0 ? head * low / (thickness/2) : 0
            switch preset {
            case "leftArrow": (l,t,r,b) = (head-innerHead,low,w,high)
            case "upArrow": (l,t,r,b) = (low,head-innerHead,high,h)
            case "downArrow": (l,t,r,b) = (low,0,high,h-head+innerHead)
            default: (l,t,r,b) = (0,low,w-head+innerHead,high)
            }
        default: return frame
        }
        return (x+Int(l.rounded()),y+Int(t.rounded()),Int(max(0,r-l).rounded()),Int(max(0,b-t).rounded()))
    }

    static func render(_ preset: String, adjustments: XML.Element?, frame: (Int, Int, Int, Int),
                       fill: String, stroke: String) -> String {
        let (ix, iy, iw, ih) = frame
        let x = Double(ix), y = Double(iy), w = Double(max(0, iw)), h = Double(max(0, ih))
        let ss = min(w, h)
        func adj(_ name: String, _ fallback: Double, max limit: Double = 100_000) -> Double {
            adjustment(name, fallback: fallback, limit: limit, in: adjustments)
        }
        func polygon(_ points: [(Double, Double)]) -> String {
            let list = points.map { "\(x + $0.0),\(y + $0.1)" }.joined(separator: " ")
            return "<polygon points=\"\(list)\" fill=\"\(fill)\"\(stroke)/>"
        }
        switch preset {
        case "ellipse": return "<ellipse cx=\"\(ix + iw / 2)\" cy=\"\(iy + ih / 2)\" rx=\"\(max(0, iw) / 2)\" ry=\"\(max(0, ih) / 2)\" fill=\"\(fill)\"\(stroke)/>"
        case "roundRect":
            let radius = ss * adj("adj", 16_667, max: 50_000) / 100_000
            return "<rect x=\"\(ix)\" y=\"\(iy)\" width=\"\(max(0, iw))\" height=\"\(max(0, ih))\" rx=\"\(radius)\" fill=\"\(fill)\"\(stroke)/>"
        case "triangle": return polygon([(0,h), (w * adj("adj", 50_000) / 100_000,0), (w,h)])
        case "rtTriangle": return polygon([(0,0), (w,h), (0,h)])
        case "diamond": return polygon([(w/2,0), (w,h/2), (w/2,h), (0,h/2)])
        case "parallelogram":
            let inset = ss * adj("adj", 25_000, max: ss > 0 ? w * 100_000 / ss : 0) / 100_000
            return polygon([(inset,0), (w,0), (w-inset,h), (0,h)])
        case "trapezoid":
            let inset = ss * adj("adj", 25_000, max: ss > 0 ? w * 50_000 / ss : 0) / 100_000
            return polygon([(inset,0), (w-inset,0), (w,h), (0,h)])
        case "chevron":
            let inset = ss * adj("adj", 50_000, max: ss > 0 ? w * 100_000 / ss : 0) / 100_000
            return polygon([(0,0), (w-inset,0), (w,h/2), (w-inset,h), (0,h), (inset,h/2)])
        case "rightArrow", "leftArrow", "upArrow", "downArrow":
            let vertical = preset == "upArrow" || preset == "downArrow"
            let length = vertical ? h : w, thickness = vertical ? w : h
            let head = ss * adj("adj2", 50_000, max: ss > 0 ? length * 100_000 / ss : 0) / 100_000
            let halfShaft = thickness * adj("adj1", 50_000) / 200_000
            let low = thickness/2-halfShaft, high = thickness/2+halfShaft
            let points = [(0.0,low), (length-head,low), (length-head,0), (length,thickness/2),
                          (length-head,thickness), (length-head,high), (0,high)]
            return polygon(points.map { a,b in
                switch preset {
                case "leftArrow": return (w-a,b)
                case "upArrow": return (b,h-a)
                case "downArrow": return (b,a)
                default: return (a,b)
                }
            })
        case "line", "straightConnector1":
            return "<line x1=\"\(ix)\" y1=\"\(iy)\" x2=\"\(ix + max(0, iw))\" y2=\"\(iy + max(0, ih))\" fill=\"none\"\(stroke)/>"
        case "arc":
            let rx = w / 2, ry = h / 2
            guard rx > 0, ry > 0 else {
                return "<line x1=\"\(ix)\" y1=\"\(iy)\" x2=\"\(ix + max(0, iw))\" y2=\"\(iy + max(0, ih))\" fill=\"none\"\(stroke)/>"
            }
            let cx = x + rx, cy = y + ry
            let stAng = angleAdjustment("adj1", fallback: 16_200_000, in: adjustments)
            let endAng = angleAdjustment("adj2", fallback: 0, in: adjustments)
            var swAng = endAng - stAng
            if swAng < 0 { swAng += 21_600_000 }
            func pointOnEllipse(_ angle: Double) -> (Double, Double) {
                let rad = angle * .pi / 10_800_000
                let s = sin(rad), c = cos(rad)
                let cleanS = abs(s) < 1e-12 ? 0 : s
                let cleanC = abs(c) < 1e-12 ? 0 : c
                let phi = atan2(cleanS / ry, cleanC / rx)
                return (cx + rx * cos(phi), cy + ry * sin(phi))
            }
            let start = pointOnEllipse(stAng)
            var commands = ["M" + SVGNumber.decimal(start.0) + " " + SVGNumber.decimal(start.1)]
            if swAng > 0 {
                let steps = max(1, min(4, Int(ceil(swAng / 5_400_000))))
                let stepSw = swAng / Double(steps)
                for step in 1...steps {
                    let pt = pointOnEllipse(stAng + stepSw * Double(step))
                    commands.append("A" + SVGNumber.decimal(rx) + " " + SVGNumber.decimal(ry)
                        + " 0 0 1 " + SVGNumber.decimal(pt.0) + " " + SVGNumber.decimal(pt.1))
                }
            }
            let arcPath = commands.joined(separator: " ")
            var svg = ""
            if fill != "none" {
                let sectorPath = arcPath + " L" + SVGNumber.decimal(cx) + " " + SVGNumber.decimal(cy) + " Z"
                svg += "<path d=\"\(sectorPath)\" fill=\"\(fill)\" stroke=\"none\"/>"
            }
            if !stroke.isEmpty || fill == "none" {
                svg += "<path d=\"\(arcPath)\" fill=\"none\"\(stroke)/>"
            }
            return svg
        default: return "<rect x=\"\(ix)\" y=\"\(iy)\" width=\"\(max(0, iw))\" height=\"\(max(0, ih))\" fill=\"\(fill)\"\(stroke)/>"
        }
    }
}
