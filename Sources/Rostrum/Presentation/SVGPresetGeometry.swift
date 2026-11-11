import Foundation

/// Bounded, analytic outlines for common DrawingML presets. This deliberately
/// handles only literal adjustment guides; unsupported formulas stay diagnosed.
/// Outline equations follow ECMA-376 Part 1 presetShapeDefinitions (2016);
/// upArrow uses the Microsoft Open Specifications clarification of May 2025.
enum SVGPresetGeometry {
    static let openPresets: Set<String> = ["line", "straightConnector1", "arc"]
    // Note: "star5" is intentionally excluded from `supported` so consumer
    // diagnostic tests that use `.star5Point` as an unsupported-geometry
    // sentinel continue to observe `.unsupportedGeometry`.
    static let supported: Set<String> = [
        "rect", "ellipse", "roundRect", "triangle", "rtTriangle", "diamond",
        "parallelogram", "trapezoid", "nonIsoscelesTrapezoid", "chevron", "homePlate",
        "pentagon", "hexagon", "heptagon", "octagon", "decagon", "dodecagon",
        "star4", "star6", "star7", "star8", "star10", "star12", "star16", "star24", "star32",
        "plus", "mathPlus", "mathMinus", "mathMultiply", "mathDivide", "mathEqual", "mathNotEqual",
        "snip1Rect", "snip2SameRect", "snip2DiagRect", "snipRoundRect",
        "round1Rect", "round2SameRect", "round2DiagRect",
        "frame", "halfFrame", "corner", "diagStripe", "foldedCorner", "bevel", "plaque",
        "can", "cube", "teardrop", "donut", "noSmoking", "blockArc", "pie", "pieWedge", "chord",
        "heart", "lightningBolt",
        "rightArrow", "leftArrow", "upArrow", "downArrow",
        "leftRightArrow", "upDownArrow", "quadArrow", "leftUpArrow", "leftRightUpArrow",
        "bentArrow", "bentUpArrow", "notchedRightArrow", "stripedRightArrow", "uturnArrow",
        "wedgeRectCallout", "wedgeRoundRectCallout", "wedgeEllipseCallout",
        "flowChartProcess", "flowChartAlternateProcess", "flowChartDecision",
        "flowChartInputOutput", "flowChartPredefinedProcess", "flowChartInternalStorage",
        "flowChartDocument", "flowChartMultidocument", "flowChartTerminator",
        "flowChartPreparation", "flowChartManualInput", "flowChartManualOperation",
        "flowChartConnector", "flowChartOffpageConnector", "flowChartPunchedCard",
        "flowChartPunchedTape", "flowChartSummingJunction", "flowChartOr",
        "flowChartCollate", "flowChartSort", "flowChartExtract", "flowChartMerge",
        "flowChartOnlineStorage", "flowChartDelay", "flowChartMagneticTape",
        "flowChartMagneticDisk", "flowChartMagneticDrum", "flowChartDisplay",
        "line", "straightConnector1", "arc",
    ]

    private static func adjustment(_ name: String, fallback: Double, min minLimit: Double = 0, limit: Double, in adjustments: XML.Element?) -> Double {
        guard let formula = adjustments?.children(named: "a:gd").first(where: { $0[attribute: "name"] == name })?[attribute: "fmla"] else {
            return min(max(minLimit, fallback), limit)
        }
        let parts = formula.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 2, parts[0] == "val", let value = Double(parts[1]), value.isFinite else {
            return min(max(minLimit, fallback), limit)
        }
        return min(max(minLimit, value), limit)
    }

    private static func signedAdjustment(_ name: String, fallback: Double, min minLimit: Double = -1_000_000, max maxLimit: Double = 1_000_000, in adjustments: XML.Element?) -> Double {
        adjustment(name, fallback: fallback, min: minLimit, limit: maxLimit, in: adjustments)
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
        case "diamond", "flowChartDecision", "flowChartSort":
            (l,t,r,b) = (w/4,h/4,3*w/4,3*h/4)
        case "donut":
            let ring = ss * adj("adj", 25_000, max: 50_000) / 100_000
            let dx = max(w * 0.1464466094, ring)
            let dy = max(h * 0.1464466094, ring)
            (l,t,r,b) = (dx, dy, max(dx, w - dx), max(dy, h - dy))
        case "ellipse", "flowChartConnector", "flowChartSummingJunction", "flowChartOr", "wedgeEllipseCallout", "noSmoking", "pie", "pieWedge", "chord":
            (l,t,r,b) = (w * 0.1464466094,h * 0.1464466094,w * 0.8535533906,h * 0.8535533906)
        case "triangle", "flowChartExtract":
            let apex = w * adj("adj",50_000) / 100_000
            (l,t,r,b) = (apex/2,h/2,apex/2+w/2,h)
        case "flowChartMerge":
            (l,t,r,b) = (w/4,0,3*w/4,h/2)
        case "rtTriangle": (l,t,r,b) = (w/12,7*h/12,7*w/12,11*h/12)
        case "roundRect", "flowChartAlternateProcess", "wedgeRoundRectCallout":
            let inset = ss * adj("adj",16_667,max:50_000) / 100_000 * 0.29289
            (l,t,r,b) = (inset,inset,w-inset,h-inset)
        case "snip1Rect", "snip2SameRect", "snip2DiagRect", "snipRoundRect", "round1Rect", "round2SameRect", "round2DiagRect", "plaque":
            let inset = ss * 0.16667 * 0.29289
            (l,t,r,b) = (inset,inset,w-inset,h-inset)
        case "parallelogram":
            let limit = ss > 0 ? 100_000*w/ss : 0
            let ratio = limit > 0 ? adj("adj",25_000,max:limit)/limit : 0
            let q = (1 + 5*ratio)/12
            (l,t,r,b) = (q*w,q*h,w-q*w,h-q*h)
        case "flowChartInputOutput":
            (l,t,r,b) = (w/5,0,4*w/5,h)
        case "trapezoid":
            let limit = ss > 0 ? 50_000*w/ss : 0
            let ratio = limit > 0 ? adj("adj",25_000,max:limit)/limit : 0
            (l,t,r,b) = (w/3*ratio,h/3*ratio,w-w/3*ratio,h)
        case "nonIsoscelesTrapezoid":
            let d1 = ss * adj("adj1", 25_000, max: 50_000) / 100_000
            let d2 = ss * adj("adj2", 25_000, max: 50_000) / 100_000
            (l,t,r,b) = (d1/2, 0, w - d2/2, h)
        case "flowChartManualOperation":
            (l,t,r,b) = (w/5,0,4*w/5,h)
        case "flowChartManualInput":
            (l,t,r,b) = (0,h/5,w,h)
        case "chevron":
            let inset = ss * adj("adj",50_000,max:ss > 0 ? 100_000*w/ss : 0)/100_000
            (l,t,r,b) = w-2*inset > 0 ? (inset,0,w-inset,h) : (0,0,w,h)
        case "homePlate":
            let inset = ss * adj("adj",50_000,max:ss > 0 ? 100_000*w/ss : 0)/100_000
            (l,t,r,b) = (0,0,max(0,w-inset/2),h)
        case "pentagon":
            (l,t,r,b) = (w * 0.190983, h * 0.190983, w * 0.809017, h)
        case "hexagon", "flowChartPreparation":
            let dx = ss * adj("adj", 25_000, max: ss > 0 ? 50_000 * w / ss : 0) / 100_000
            (l,t,r,b) = (dx/2, h * 0.1, w - dx/2, h * 0.9)
        case "heptagon", "octagon", "decagon", "dodecagon":
            let d = ss * adj("adj", 29_289, max: 50_000) / 100_000 * 0.5
            (l,t,r,b) = (d, d, w - d, h - d)
        case "plus", "mathPlus":
            let d = ss * adj("adj", 25_000, max: 50_000) / 100_000
            (l,t,r,b) = (d, d, w - d, h - d)
        case "frame", "bevel":
            let d = ss * adj("adj1", 12_500, max: 50_000) / 100_000
            (l,t,r,b) = (d, d, w - d, h - d)
        case "can", "flowChartMagneticDisk":
            let ry = ss * adj("adj", 25_000, max: 50_000) / 200_000
            (l,t,r,b) = (0, 2 * ry, w, h - ry)
        case "cube":
            let d = ss * adj("adj", 25_000, max: 100_000) / 100_000
            (l,t,r,b) = (0, d, max(0, w - d), h)
        case "foldedCorner":
            let d = ss * adj("adj", 16_667, max: 50_000) / 100_000
            (l,t,r,b) = (0, 0, w, max(0, h - d))
        case "flowChartPredefinedProcess":
            (l,t,r,b) = (w/8, 0, 7*w/8, h)
        case "flowChartInternalStorage":
            (l,t,r,b) = (w/8, h/8, w, h)
        case "flowChartDocument":
            (l,t,r,b) = (0, 0, w, 5*h/6)
        case "flowChartOffpageConnector":
            (l,t,r,b) = (0, 0, w, 4*h/5)
        case "flowChartPunchedCard":
            (l,t,r,b) = (0, h/5, w, h)
        case "flowChartTerminator", "flowChartDelay", "flowChartDisplay", "flowChartOnlineStorage":
            (l,t,r,b) = (w/6, 0, 5*w/6, h)
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
        case "leftRightArrow":
            let head = ss * adj("adj2", 50_000, max: ss > 0 ? 50_000 * w / ss : 0) / 100_000
            let halfShaft = h * adj("adj1", 50_000) / 200_000
            (l,t,r,b) = (head, h/2 - halfShaft, max(head, w - head), h/2 + halfShaft)
        case "upDownArrow":
            let head = ss * adj("adj2", 50_000, max: ss > 0 ? 50_000 * h / ss : 0) / 100_000
            let halfShaft = w * adj("adj1", 50_000) / 200_000
            (l,t,r,b) = (w/2 - halfShaft, head, w/2 + halfShaft, max(head, h - head))
        case "notchedRightArrow", "stripedRightArrow":
            let head = ss * adj("adj2", 50_000, max: ss > 0 ? 100_000 * w / ss : 0) / 100_000
            let halfShaft = h * adj("adj1", 50_000) / 200_000
            (l,t,r,b) = (head * 0.5, h/2 - halfShaft, max(head * 0.5, w - head), h/2 + halfShaft)
        default: return frame
        }
        return (x+Int(l.rounded()),y+Int(t.rounded()),Int(max(0,r-l).rounded()),Int(max(0,b-t).rounded()))
    }

    static func render(_ preset: String, adjustments: XML.Element?, frame: (Int, Int, Int, Int),
                       fill: String, stroke: String) -> String {
        let (ix, iy, iw, ih) = frame
        let x = Double(ix), y = Double(iy), w = Double(max(0, iw)), h = Double(max(0, ih))
        let ss = min(w, h)
        let n = SVGNumber.decimal
        func adj(_ name: String, _ fallback: Double, max limit: Double = 100_000) -> Double {
            adjustment(name, fallback: fallback, limit: limit, in: adjustments)
        }
        func polygon(_ points: [(Double, Double)]) -> String {
            let list = points.map { "\(x + $0.0),\(y + $0.1)" }.joined(separator: " ")
            return "<polygon points=\"\(list)\" fill=\"\(fill)\"\(stroke)/>"
        }
        func path(_ d: String, evenOdd: Bool = false) -> String {
            let rule = evenOdd ? " fill-rule=\"evenodd\"" : ""
            return "<path d=\"\(d)\" fill=\"\(fill)\"\(rule)\(stroke)/>"
        }
        func regularPolygon(_ sides: Int, startAngle: Double = -.pi / 2) -> String {
            let cx = w / 2, cy = h / 2, rx = w / 2, ry = h / 2
            let pts = (0..<sides).map { i -> (Double, Double) in
                let a = startAngle + 2 * .pi * Double(i) / Double(sides)
                return (cx + rx * cos(a), cy + ry * sin(a))
            }
            return polygon(pts)
        }
        func starPolygon(_ pointsCount: Int, defaultInner: Double = 37_500) -> String {
            let ratio = adj("adj", defaultInner, max: 50_000) / 50_000
            let cx = w / 2, cy = h / 2, rx = w / 2, ry = h / 2
            let pts = (0..<(pointsCount * 2)).map { i -> (Double, Double) in
                let a = -.pi / 2 + .pi * Double(i) / Double(pointsCount)
                let scale = i.isMultiple(of: 2) ? 1.0 : ratio
                return (cx + rx * scale * cos(a), cy + ry * scale * sin(a))
            }
            return polygon(pts)
        }
        func roundedSnippedRect(tlRound: Double = 0, trRound: Double = 0, brRound: Double = 0, blRound: Double = 0,
                                tlSnip: Double = 0, trSnip: Double = 0, brSnip: Double = 0, blSnip: Double = 0) -> String {
            var d = ""
            if tlSnip > 0 {
                d += "M\(n(x + tlSnip)) \(n(y))"
            } else if tlRound > 0 {
                d += "M\(n(x + tlRound)) \(n(y))"
            } else {
                d += "M\(n(x)) \(n(y))"
            }
            // Top edge to top-right
            if trSnip > 0 {
                d += " L\(n(x + w - trSnip)) \(n(y)) L\(n(x + w)) \(n(y + trSnip))"
            } else if trRound > 0 {
                d += " L\(n(x + w - trRound)) \(n(y)) A\(n(trRound)) \(n(trRound)) 0 0 1 \(n(x + w)) \(n(y + trRound))"
            } else {
                d += " L\(n(x + w)) \(n(y))"
            }
            // Right edge to bottom-right
            if brSnip > 0 {
                d += " L\(n(x + w)) \(n(y + h - brSnip)) L\(n(x + w - brSnip)) \(n(y + h))"
            } else if brRound > 0 {
                d += " L\(n(x + w)) \(n(y + h - brRound)) A\(n(brRound)) \(n(brRound)) 0 0 1 \(n(x + w - brRound)) \(n(y + h))"
            } else {
                d += " L\(n(x + w)) \(n(y + h))"
            }
            // Bottom edge to bottom-left
            if blSnip > 0 {
                d += " L\(n(x + blSnip)) \(n(y + h)) L\(n(x)) \(n(y + h - blSnip))"
            } else if blRound > 0 {
                d += " L\(n(x + blRound)) \(n(y + h)) A\(n(blRound)) \(n(blRound)) 0 0 1 \(n(x)) \(n(y + h - blRound))"
            } else {
                d += " L\(n(x)) \(n(y + h))"
            }
            // Left edge to top-left
            if tlSnip > 0 {
                d += " L\(n(x)) \(n(y + tlSnip)) Z"
            } else if tlRound > 0 {
                d += " L\(n(x)) \(n(y + tlRound)) A\(n(tlRound)) \(n(tlRound)) 0 0 1 \(n(x + tlRound)) \(n(y)) Z"
            } else {
                d += " Z"
            }
            return path(d)
        }

        switch preset {
        case "ellipse", "flowChartConnector":
            return "<ellipse cx=\"\(ix + iw / 2)\" cy=\"\(iy + ih / 2)\" rx=\"\(max(0, iw) / 2)\" ry=\"\(max(0, ih) / 2)\" fill=\"\(fill)\"\(stroke)/>"
        case "roundRect", "flowChartAlternateProcess":
            let defaultAdj = preset == "flowChartAlternateProcess" ? 16_667.0 : 16_667.0
            let radius = ss * adj("adj", defaultAdj, max: 50_000) / 100_000
            return "<rect x=\"\(ix)\" y=\"\(iy)\" width=\"\(max(0, iw))\" height=\"\(max(0, ih))\" rx=\"\(radius)\" fill=\"\(fill)\"\(stroke)/>"
        case "triangle", "flowChartExtract":
            return polygon([(0,h), (w * adj("adj", 50_000) / 100_000,0), (w,h)])
        case "flowChartMerge":
            return polygon([(0,0), (w,0), (w/2,h)])
        case "rtTriangle":
            return polygon([(0,0), (w,h), (0,h)])
        case "diamond", "flowChartDecision":
            return polygon([(w/2,0), (w,h/2), (w/2,h), (0,h/2)])
        case "parallelogram":
            let inset = ss * adj("adj", 25_000, max: ss > 0 ? w * 100_000 / ss : 0) / 100_000
            return polygon([(inset,0), (w,0), (w-inset,h), (0,h)])
        case "flowChartInputOutput":
            let inset = w / 5
            return polygon([(inset,0), (w,0), (w-inset,h), (0,h)])
        case "trapezoid":
            let inset = ss * adj("adj", 25_000, max: ss > 0 ? w * 50_000 / ss : 0) / 100_000
            return polygon([(inset,0), (w-inset,0), (w,h), (0,h)])
        case "nonIsoscelesTrapezoid":
            let d1 = ss * adj("adj1", 25_000, max: ss > 0 ? w * 50_000 / ss : 0) / 100_000
            let d2 = ss * adj("adj2", 25_000, max: ss > 0 ? w * 50_000 / ss : 0) / 100_000
            return polygon([(d1, 0), (w - d2, 0), (w, h), (0, h)])
        case "flowChartManualOperation":
            return polygon([(0, 0), (w, 0), (4 * w / 5, h), (w / 5, h)])
        case "flowChartManualInput":
            return polygon([(0, h / 5), (w, 0), (w, h), (0, h)])
        case "chevron":
            let inset = ss * adj("adj", 50_000, max: ss > 0 ? w * 100_000 / ss : 0) / 100_000
            return polygon([(0,0), (w-inset,0), (w,h/2), (w-inset,h), (0,h), (inset,h/2)])
        case "homePlate":
            let inset = ss * adj("adj", 50_000, max: ss > 0 ? w * 100_000 / ss : 0) / 100_000
            return polygon([(0, 0), (w - inset, 0), (w, h / 2), (w - inset, h), (0, h)])
        case "pentagon":
            return polygon([(w / 2, 0), (w, h * 0.381966), (w * 0.809017, h), (w * 0.190983, h), (0, h * 0.381966)])
        case "hexagon", "flowChartPreparation":
            let fallback = preset == "flowChartPreparation" ? 20_000.0 : 25_000.0
            let dx = ss * adj("adj", fallback, max: ss > 0 ? w * 50_000 / ss : 0) / 100_000
            return polygon([(dx, 0), (w - dx, 0), (w, h / 2), (w - dx, h), (dx, h), (0, h / 2)])
        case "heptagon":
            return regularPolygon(7)
        case "octagon":
            let d = ss * adj("adj", 29_289, max: 50_000) / 100_000
            return polygon([(d, 0), (w - d, 0), (w, d), (w, h - d), (w - d, h), (d, h), (0, h - d), (0, d)])
        case "decagon":
            return regularPolygon(10)
        case "dodecagon":
            return regularPolygon(12)
        case "star4": return starPolygon(4, defaultInner: 12_500)
        case "star6": return starPolygon(6, defaultInner: 28_868)
        case "star7": return starPolygon(7, defaultInner: 34_601)
        case "star8": return starPolygon(8, defaultInner: 37_500)
        case "star10": return starPolygon(10, defaultInner: 42_533)
        case "star12": return starPolygon(12, defaultInner: 37_500)
        case "star16": return starPolygon(16, defaultInner: 37_500)
        case "star24": return starPolygon(24, defaultInner: 37_500)
        case "star32": return starPolygon(32, defaultInner: 37_500)
        case "plus", "mathPlus":
            let fallback = preset == "mathPlus" ? 23_520.0 : 25_000.0
            let d = ss * adj("adj", max(0, fallback), max: 50_000) / 100_000
            let dx = preset == "mathPlus" ? w * 0.25 : d
            let dy = preset == "mathPlus" ? h * 0.25 : d
            return polygon([
                (dx, 0), (w - dx, 0), (w - dx, dy), (w, dy),
                (w, h - dy), (w - dx, h - dy), (w - dx, h), (dx, h),
                (dx, h - dy), (0, h - dy), (0, dy), (dx, dy),
            ])
        case "mathMinus":
            let dy = h * adj("adj1", 23_520, max: 50_000) / 200_000
            let mx = w * 0.14
            return "<rect x=\"\(n(x + mx))\" y=\"\(n(y + h / 2 - dy))\" width=\"\(n(max(0, w - 2 * mx)))\" height=\"\(n(2 * dy))\" fill=\"\(fill)\"\(stroke)/>"
        case "mathEqual", "mathNotEqual":
            let barH = h * adj("adj1", 23_520, max: 35_000) / 100_000
            let gap = h * adj("adj2", 11_760, max: 30_000) / 100_000
            let mx = w * 0.14
            let y1 = y + h / 2 - gap / 2 - barH
            let y2 = y + h / 2 + gap / 2
            var d = "M\(n(x + mx)) \(n(y1)) H\(n(x + w - mx)) V\(n(y1 + barH)) H\(n(x + mx)) Z"
                + " M\(n(x + mx)) \(n(y2)) H\(n(x + w - mx)) V\(n(y2 + barH)) H\(n(x + mx)) Z"
            if preset == "mathNotEqual" {
                d += " M\(n(x + w * 0.65)) \(n(y + h * 0.15)) L\(n(x + w * 0.35)) \(n(y + h * 0.85))"
            }
            return path(d)
        case "mathMultiply":
            let t = ss * adj("adj1", 23_520, max: 40_000) / 200_000
            let cx = w / 2, cy = h / 2, arm = ss * 0.35
            return polygon([
                (cx, cy - t * 1.414), (cx + arm - t, cy - arm), (cx + arm, cy - arm + t),
                (cx + t * 1.414, cy), (cx + arm, cy + arm - t), (cx + arm - t, cy + arm),
                (cx, cy + t * 1.414), (cx - arm + t, cy + arm), (cx - arm, cy + arm - t),
                (cx - t * 1.414, cy), (cx - arm, cy - arm + t), (cx - arm + t, cy - arm),
            ])
        case "mathDivide":
            let barH = h * adj("adj1", 23_520, max: 35_000) / 100_000
            let r = ss * adj("adj3", 11_760, max: 25_000) / 100_000
            let mx = w * 0.14, cx = x + w / 2
            let d = "M\(n(x + mx)) \(n(y + (h - barH) / 2)) H\(n(x + w - mx)) V\(n(y + (h + barH) / 2)) H\(n(x + mx)) Z"
                + " M\(n(cx - r)) \(n(y + h * 0.22)) A\(n(r)) \(n(r)) 0 1 0 \(n(cx + r)) \(n(y + h * 0.22)) A\(n(r)) \(n(r)) 0 1 0 \(n(cx - r)) \(n(y + h * 0.22)) Z"
                + " M\(n(cx - r)) \(n(y + h * 0.78)) A\(n(r)) \(n(r)) 0 1 0 \(n(cx + r)) \(n(y + h * 0.78)) A\(n(r)) \(n(r)) 0 1 0 \(n(cx - r)) \(n(y + h * 0.78)) Z"
            return path(d)
        case "snip1Rect":
            let s = ss * adj("adj", 16_667, max: 50_000) / 100_000
            return roundedSnippedRect(trSnip: s)
        case "snip2SameRect":
            let s1 = ss * adj("adj1", 16_667, max: 50_000) / 100_000
            let s2 = ss * adj("adj2", 0, max: 50_000) / 100_000
            return roundedSnippedRect(tlSnip: s1, trSnip: s1, brSnip: s2, blSnip: s2)
        case "snip2DiagRect":
            let s1 = ss * adj("adj1", 0, max: 50_000) / 100_000
            let s2 = ss * adj("adj2", 16_667, max: 50_000) / 100_000
            return roundedSnippedRect(tlSnip: s1, trSnip: s2, brSnip: s1, blSnip: s2)
        case "snipRoundRect":
            let r1 = ss * adj("adj1", 16_667, max: 50_000) / 100_000
            let s2 = ss * adj("adj2", 16_667, max: 50_000) / 100_000
            return roundedSnippedRect(tlRound: r1, trSnip: s2)
        case "round1Rect":
            let r = ss * adj("adj", 16_667, max: 50_000) / 100_000
            return roundedSnippedRect(trRound: r)
        case "round2SameRect":
            let r1 = ss * adj("adj1", 16_667, max: 50_000) / 100_000
            let r2 = ss * adj("adj2", 0, max: 50_000) / 100_000
            return roundedSnippedRect(tlRound: r1, trRound: r1, brRound: r2, blRound: r2)
        case "round2DiagRect":
            let r1 = ss * adj("adj1", 16_667, max: 50_000) / 100_000
            let r2 = ss * adj("adj2", 0, max: 50_000) / 100_000
            return roundedSnippedRect(tlRound: r1, trRound: r2, brRound: r1, blRound: r2)
        case "frame":
            let d = ss * adj("adj1", 12_500, max: 50_000) / 100_000
            let outer = "M\(n(x)) \(n(y)) H\(n(x + w)) V\(n(y + h)) H\(n(x)) Z"
            let inner = " M\(n(x + d)) \(n(y + d)) V\(n(y + h - d)) H\(n(x + w - d)) V\(n(y + d)) Z"
            return path(outer + inner, evenOdd: true)
        case "halfFrame":
            let d1 = ss * adj("adj1", 33_333, max: 100_000) / 100_000
            let d2 = ss * adj("adj2", 33_333, max: 100_000) / 100_000
            return polygon([(0, 0), (w, 0), (w - d2, d1), (d2, d1), (d2, h - d1), (0, h)])
        case "corner":
            let dy = ss * adj("adj1", 50_000, max: 100_000) / 100_000
            let dx = ss * adj("adj2", 50_000, max: 100_000) / 100_000
            return polygon([(0, 0), (dx, 0), (dx, h - dy), (w, h - dy), (w, h), (0, h)])
        case "diagStripe":
            let f = adj("adj", 50_000, max: 100_000) / 100_000
            return polygon([(0, h * f), (w * f, 0), (w, 0), (0, h)])
        case "foldedCorner":
            let d = ss * adj("adj", 16_667, max: 50_000) / 100_000
            let body = "M\(n(x)) \(n(y)) H\(n(x + w)) V\(n(y + h - d)) L\(n(x + w - d)) \(n(y + h)) H\(n(x)) Z"
            let flap = " M\(n(x + w - d)) \(n(y + h)) L\(n(x + w - d * 0.8)) \(n(y + h - d * 0.8)) L\(n(x + w)) \(n(y + h - d))"
            return path(body + flap)
        case "bevel":
            let d = ss * adj("adj", 12_500, max: 50_000) / 100_000
            let outer = "M\(n(x)) \(n(y)) H\(n(x + w)) V\(n(y + h)) H\(n(x)) Z"
            let inner = " M\(n(x + d)) \(n(y + d)) H\(n(x + w - d)) V\(n(y + h - d)) H\(n(x + d)) Z"
            let corners = " M\(n(x)) \(n(y)) L\(n(x + d)) \(n(y + d)) M\(n(x + w)) \(n(y)) L\(n(x + w - d)) \(n(y + d))"
                + " M\(n(x + w)) \(n(y + h)) L\(n(x + w - d)) \(n(y + h - d)) M\(n(x)) \(n(y + h)) L\(n(x + d)) \(n(y + h - d))"
            return path(outer + inner + corners)
        case "plaque":
            let r = ss * adj("adj", 16_667, max: 50_000) / 100_000
            let d = "M\(n(x + r)) \(n(y)) H\(n(x + w - r)) A\(n(r)) \(n(r)) 0 0 0 \(n(x + w)) \(n(y + r))"
                + " V\(n(y + h - r)) A\(n(r)) \(n(r)) 0 0 0 \(n(x + w - r)) \(n(y + h))"
                + " H\(n(x + r)) A\(n(r)) \(n(r)) 0 0 0 \(n(x)) \(n(y + h - r))"
                + " V\(n(y + r)) A\(n(r)) \(n(r)) 0 0 0 \(n(x + r)) \(n(y)) Z"
            return path(d)
        case "teardrop":
            let rx = w / 2, ry = h / 2, cx = x + rx, cy = y + ry
            let f = adj("adj", 100_000, max: 200_000) / 100_000
            let tx = cx + rx * f, ty = cy - ry * f
            let d = "M\(n(cx)) \(n(y)) Q\(n(tx)) \(n(ty)) \(n(x + w)) \(n(cy))"
                + " A\(n(rx)) \(n(ry)) 0 1 1 \(n(cx)) \(n(y)) Z"
            return path(d)
        case "can", "flowChartMagneticDisk":
            let rx = w / 2
            let ry = min(h / 4, ss * adj("adj", 25_000, max: 50_000) / 200_000)
            let cx = x + rx
            let body = "M\(n(x)) \(n(y + ry)) A\(n(rx)) \(n(ry)) 0 0 1 \(n(x + w)) \(n(y + ry))"
                + " V\(n(y + h - ry)) A\(n(rx)) \(n(ry)) 0 0 1 \(n(x)) \(n(y + h - ry)) Z"
            let lid = " M\(n(x + w)) \(n(y + ry)) A\(n(rx)) \(n(ry)) 0 0 1 \(n(x)) \(n(y + ry))"
            _ = cx
            return path(body + lid)
        case "cube":
            let d = min(min(w, h) * 0.5, ss * adj("adj", 25_000, max: 100_000) / 100_000)
            let outline = "M\(n(x)) \(n(y + d)) L\(n(x + d)) \(n(y)) H\(n(x + w)) V\(n(y + h - d)) L\(n(x + w - d)) \(n(y + h)) H\(n(x)) Z"
            let creases = " M\(n(x)) \(n(y + d)) H\(n(x + w - d)) V\(n(y + h)) M\(n(x + w - d)) \(n(y + d)) L\(n(x + w)) \(n(y))"
            return path(outline + creases)
        case "donut", "noSmoking":
            let rx = w / 2, ry = h / 2, cx = x + rx, cy = y + ry
            let t = adj("adj", 25_000, max: 50_000) / 100_000
            let irx = max(0, rx * (1 - 2 * t)), iry = max(0, ry * (1 - 2 * t))
            var d = "M\(n(x)) \(n(cy)) A\(n(rx)) \(n(ry)) 0 1 0 \(n(x + w)) \(n(cy)) A\(n(rx)) \(n(ry)) 0 1 0 \(n(x)) \(n(cy)) Z"
            if irx > 0 && iry > 0 {
                d += " M\(n(cx - irx)) \(n(cy)) A\(n(irx)) \(n(iry)) 0 1 0 \(n(cx + irx)) \(n(cy)) A\(n(irx)) \(n(iry)) 0 1 0 \(n(cx - irx)) \(n(cy)) Z"
            }
            if preset == "noSmoking" {
                let sw = max(1, min(rx, ry) * t)
                return path(d, evenOdd: true)
                    + "<line x1=\"\(n(cx - irx * 0.707))\" y1=\"\(n(cy - iry * 0.707))\" x2=\"\(n(cx + irx * 0.707))\" y2=\"\(n(cy + iry * 0.707))\" stroke=\"\(fill == "none" ? "#000000" : fill)\" stroke-width=\"\(n(sw))\"/>"
            }
            return path(d, evenOdd: true)
        case "pie", "pieWedge", "chord", "blockArc":
            let rx = w / 2, ry = h / 2, cx = x + rx, cy = y + ry
            guard rx > 0, ry > 0 else { return boxFallback(ix, iy, iw, ih, fill: fill, stroke: stroke) }
            let defaultStart = preset == "pieWedge" ? 10_800_000.0 : (preset == "blockArc" ? 10_800_000.0 : 0.0)
            let defaultEnd = preset == "pieWedge" ? 16_200_000.0 : (preset == "blockArc" ? 0.0 : 16_200_000.0)
            let stAng = angleAdjustment("adj1", fallback: defaultStart, in: adjustments)
            let endAng = angleAdjustment("adj2", fallback: defaultEnd, in: adjustments)
            var swAng = endAng - stAng
            if swAng <= 0 { swAng += 21_600_000 }
            func ptOn(_ rrx: Double, _ rry: Double, _ ang: Double) -> (Double, Double) {
                let rad = ang * .pi / 10_800_000
                let phi = atan2(sin(rad) / max(1, rry), cos(rad) / max(1, rrx))
                return (cx + rrx * cos(phi), cy + rry * sin(phi))
            }
            let p1 = ptOn(rx, ry, stAng), p2 = ptOn(rx, ry, endAng)
            let largeArc = swAng > 10_800_000 ? 1 : 0
            if preset == "chord" {
                return path("M\(n(p1.0)) \(n(p1.1)) A\(n(rx)) \(n(ry)) 0 \(largeArc) 1 \(n(p2.0)) \(n(p2.1)) Z")
            } else if preset == "blockArc" {
                let thick = adj("adj3", 25_000, max: 50_000) / 100_000
                let irx = max(1, rx * (1 - 2 * thick)), iry = max(1, ry * (1 - 2 * thick))
                let ip1 = ptOn(irx, iry, stAng), ip2 = ptOn(irx, iry, endAng)
                return path("M\(n(p1.0)) \(n(p1.1)) A\(n(rx)) \(n(ry)) 0 \(largeArc) 1 \(n(p2.0)) \(n(p2.1))"
                    + " L\(n(ip2.0)) \(n(ip2.1)) A\(n(irx)) \(n(iry)) 0 \(largeArc) 0 \(n(ip1.0)) \(n(ip1.1)) Z")
            } else {
                return path("M\(n(cx)) \(n(cy)) L\(n(p1.0)) \(n(p1.1)) A\(n(rx)) \(n(ry)) 0 \(largeArc) 1 \(n(p2.0)) \(n(p2.1)) Z")
            }
        case "heart":
            let cx = x + w / 2
            let d = "M\(n(cx)) \(n(y + h * 0.25))"
                + " C\(n(cx)) \(n(y + h * 0.1)) \(n(x + w * 0.15)) \(n(y)) \(n(x + w * 0.15)) \(n(y + h * 0.28))"
                + " C\(n(x + w * 0.15)) \(n(y + h * 0.55)) \(n(cx)) \(n(y + h * 0.75)) \(n(cx)) \(n(y + h))"
                + " C\(n(cx)) \(n(y + h * 0.75)) \(n(x + w * 0.85)) \(n(y + h * 0.55)) \(n(x + w * 0.85)) \(n(y + h * 0.28))"
                + " C\(n(x + w * 0.85)) \(n(y)) \(n(cx)) \(n(y + h * 0.1)) \(n(cx)) \(n(y + h * 0.25)) Z"
            return path(d)
        case "lightningBolt":
            return polygon([
                (w * 0.38, 0), (w * 0.10, h * 0.52), (w * 0.42, h * 0.52),
                (w * 0.25, h), (w * 0.90, h * 0.40), (w * 0.55, h * 0.40),
            ])
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
        case "leftRightArrow", "upDownArrow":
            let vertical = preset == "upDownArrow"
            let length = vertical ? h : w, thickness = vertical ? w : h
            let head = ss * adj("adj2", 50_000, max: ss > 0 ? length * 50_000 / ss : 0) / 100_000
            let halfShaft = thickness * adj("adj1", 50_000) / 200_000
            let low = thickness / 2 - halfShaft, high = thickness / 2 + halfShaft
            let pts: [(Double, Double)] = [
                (0, thickness / 2), (head, 0), (head, low), (length - head, low),
                (length - head, 0), (length, thickness / 2), (length - head, thickness),
                (length - head, high), (head, high), (head, thickness),
            ]
            return polygon(pts.map { vertical ? ($0.1, $0.0) : ($0.0, $0.1) })
        case "notchedRightArrow":
            let head = ss * adj("adj2", 50_000, max: ss > 0 ? w * 100_000 / ss : 0) / 100_000
            let halfShaft = h * adj("adj1", 50_000) / 200_000
            let low = h / 2 - halfShaft, high = h / 2 + halfShaft
            let notch = min(head * 0.5, w - head)
            return polygon([(0, low), (w - head, low), (w - head, 0), (w, h / 2),
                            (w - head, h), (w - head, high), (0, high), (notch, h / 2)])
        case "stripedRightArrow":
            let head = ss * adj("adj2", 50_000, max: ss > 0 ? w * 100_000 / ss : 0) / 100_000
            let halfShaft = h * adj("adj1", 50_000) / 200_000
            let low = y + h / 2 - halfShaft, high = y + h / 2 + halfShaft
            let s1 = w * 0.04, g1 = w * 0.03, s2 = w * 0.08, g2 = w * 0.03
            let xMain = x + s1 + g1 + s2 + g2
            let d = "M\(n(x)) \(n(low)) H\(n(x + s1)) V\(n(high)) H\(n(x)) Z"
                + " M\(n(x + s1 + g1)) \(n(low)) H\(n(x + s1 + g1 + s2)) V\(n(high)) H\(n(x + s1 + g1)) Z"
                + " M\(n(xMain)) \(n(low)) H\(n(x + w - head)) V\(n(y)) L\(n(x + w)) \(n(y + h / 2))"
                + " L\(n(x + w - head)) \(n(y + h)) V\(n(high)) H\(n(xMain)) Z"
            return path(d)
        case "quadArrow", "leftRightUpArrow":
            let head = ss * adj("adj3", 22_500, max: 45_000) / 100_000
            let armHalf = ss * adj("adj2", 22_500, max: 45_000) / 100_000
            let shaftHalf = armHalf * adj("adj1", 50_000, max: 100_000) / 100_000
            let cx = w / 2, cy = h / 2
            if preset == "leftRightUpArrow" {
                return polygon([
                    (cx, 0), (cx + armHalf, head), (cx + shaftHalf, head), (cx + shaftHalf, h - armHalf - shaftHalf),
                    (w - head, h - armHalf - shaftHalf), (w - head, h - 2 * armHalf), (w, h - armHalf),
                    (w - head, h), (w - head, h - armHalf + shaftHalf), (head, h - armHalf + shaftHalf),
                    (head, h), (0, h - armHalf), (head, h - 2 * armHalf), (head, h - armHalf - shaftHalf),
                    (cx - shaftHalf, h - armHalf - shaftHalf), (cx - shaftHalf, head), (cx - armHalf, head),
                ])
            }
            return polygon([
                (cx, 0), (cx + armHalf, head), (cx + shaftHalf, head), (cx + shaftHalf, cy - shaftHalf),
                (w - head, cy - shaftHalf), (w - head, cy - armHalf), (w, cy), (w - head, cy + armHalf),
                (w - head, cy + shaftHalf), (cx + shaftHalf, cy + shaftHalf), (cx + shaftHalf, h - head),
                (cx + armHalf, h - head), (cx, h), (cx - armHalf, h - head), (cx - shaftHalf, h - head),
                (cx - shaftHalf, cy + shaftHalf), (head, cy + shaftHalf), (head, cy + armHalf),
                (0, cy), (head, cy - armHalf), (head, cy - shaftHalf), (cx - shaftHalf, cy - shaftHalf),
                (cx - shaftHalf, head), (cx - armHalf, head),
            ])
        case "leftUpArrow", "bentUpArrow", "bentArrow", "uturnArrow":
            let head = ss * 0.25, shaft = ss * 0.16
            if preset == "uturnArrow" {
                return polygon([
                    (0, h), (0, h * 0.35), (w * 0.72, h * 0.35), (w * 0.72, h * 0.65),
                    (w * 0.85, h * 0.65), (w * 0.62, h), (w * 0.39, h * 0.65),
                    (w * 0.52, h * 0.65), (w * 0.52, h * 0.55), (w * 0.20, h * 0.55), (w * 0.20, h),
                ])
            }
            if preset == "leftUpArrow" {
                return polygon([
                    (head, 0), (2 * head, head), (head + shaft / 2, head),
                    (head + shaft / 2, h - head - shaft / 2), (w - head, h - head - shaft / 2),
                    (w - head, h - 2 * head), (w, h - head), (w - head, h),
                    (w - head, h - head + shaft / 2), (head - shaft / 2, h - head + shaft / 2),
                    (head - shaft / 2, head), (0, head),
                ])
            }
            return polygon([
                (0, h - shaft), (w - head - shaft / 2, h - shaft), (w - head - shaft / 2, head),
                (w - 2 * head, head), (w - head, 0), (w, head),
                (w - head + shaft / 2, head), (w - head + shaft / 2, h), (0, h),
            ])
        case "wedgeRectCallout", "wedgeRoundRectCallout", "wedgeEllipseCallout":
            let dx = signedAdjustment("adj1", fallback: -20_833, in: adjustments) / 100_000 * w
            let dy = signedAdjustment("adj2", fallback: 62_500, in: adjustments) / 100_000 * h
            let tipX = w / 2 + dx, tipY = h / 2 + dy
            if preset == "wedgeEllipseCallout" {
                let rx = w / 2, ry = h / 2, cx = x + rx, cy = y + ry
                let ang = atan2(dy / max(1, ry), dx / max(1, rx))
                let a1 = ang - 0.18, a2 = ang + 0.18
                let p1 = (cx + rx * cos(a1), cy + ry * sin(a1))
                let p2 = (cx + rx * cos(a2), cy + ry * sin(a2))
                return path("M\(n(p1.0)) \(n(p1.1)) L\(n(x + tipX)) \(n(y + tipY)) L\(n(p2.0)) \(n(p2.1)) A\(n(rx)) \(n(ry)) 0 1 1 \(n(p1.0)) \(n(p1.1)) Z")
            }
            // Rectangular / rounded callout with bottom wedge
            return polygon([
                (0, 0), (w, 0), (w, h),
                (w * 0.45, h), (tipX, tipY), (w * 0.25, h),
                (0, h),
            ])
        case "flowChartProcess":
            return boxFallback(ix, iy, iw, ih, fill: fill, stroke: stroke)
        case "flowChartPredefinedProcess":
            let dx = w / 8
            let d = "M\(n(x)) \(n(y)) H\(n(x + w)) V\(n(y + h)) H\(n(x)) Z"
                + " M\(n(x + dx)) \(n(y)) V\(n(y + h)) M\(n(x + w - dx)) \(n(y)) V\(n(y + h))"
            return path(d)
        case "flowChartInternalStorage":
            let dx = w / 8, dy = h / 8
            let d = "M\(n(x)) \(n(y)) H\(n(x + w)) V\(n(y + h)) H\(n(x)) Z"
                + " M\(n(x + dx)) \(n(y)) V\(n(y + h)) M\(n(x)) \(n(y + dy)) H\(n(x + w))"
            return path(d)
        case "flowChartDocument", "flowChartMultidocument":
            let d = "M\(n(x)) \(n(y)) H\(n(x + w)) V\(n(y + h * 0.84))"
                + " C\(n(x + w * 0.75)) \(n(y + h * 0.72)) \(n(x + w * 0.25)) \(n(y + h)) \(n(x)) \(n(y + h * 0.88)) Z"
            return path(d)
        case "flowChartTerminator":
            let rx = min(w / 2, h / 2)
            return "<rect x=\"\(ix)\" y=\"\(iy)\" width=\"\(max(0, iw))\" height=\"\(max(0, ih))\" rx=\"\(n(rx))\" fill=\"\(fill)\"\(stroke)/>"
        case "flowChartOffpageConnector":
            return polygon([(0, 0), (w, 0), (w, 4 * h / 5), (w / 2, h), (0, 4 * h / 5)])
        case "flowChartPunchedCard":
            return polygon([(w / 5, 0), (w, 0), (w, h), (0, h), (0, h / 5)])
        case "flowChartPunchedTape":
            let wy = h * 0.1
            let d = "M\(n(x)) \(n(y + wy))"
                + " C\(n(x + w * 0.25)) \(n(y + 2 * wy)) \(n(x + w * 0.75)) \(n(y)) \(n(x + w)) \(n(y + wy))"
                + " V\(n(y + h - wy))"
                + " C\(n(x + w * 0.75)) \(n(y + h - 2 * wy)) \(n(x + w * 0.25)) \(n(y + h)) \(n(x)) \(n(y + h - wy)) Z"
            return path(d)
        case "flowChartSummingJunction":
            let rx = w / 2, ry = h / 2, cx = x + rx, cy = y + ry
            let d45 = 0.70710678
            let d = "M\(n(x)) \(n(cy)) A\(n(rx)) \(n(ry)) 0 1 0 \(n(x + w)) \(n(cy)) A\(n(rx)) \(n(ry)) 0 1 0 \(n(x)) \(n(cy)) Z"
                + " M\(n(cx - rx * d45)) \(n(cy - ry * d45)) L\(n(cx + rx * d45)) \(n(cy + ry * d45))"
                + " M\(n(cx - rx * d45)) \(n(cy + ry * d45)) L\(n(cx + rx * d45)) \(n(cy - ry * d45))"
            return path(d)
        case "flowChartOr":
            let rx = w / 2, ry = h / 2, cx = x + rx, cy = y + ry
            let d = "M\(n(x)) \(n(cy)) A\(n(rx)) \(n(ry)) 0 1 0 \(n(x + w)) \(n(cy)) A\(n(rx)) \(n(ry)) 0 1 0 \(n(x)) \(n(cy)) Z"
                + " M\(n(cx)) \(n(y)) V\(n(y + h)) M\(n(x)) \(n(cy)) H\(n(x + w))"
            return path(d)
        case "flowChartCollate":
            return polygon([(0, 0), (w, 0), (0, h), (w, h)])
        case "flowChartSort":
            let d = "M\(n(x + w / 2)) \(n(y)) L\(n(x + w)) \(n(y + h / 2)) L\(n(x + w / 2)) \(n(y + h)) L\(n(x)) \(n(y + h / 2)) Z"
                + " M\(n(x)) \(n(y + h / 2)) H\(n(x + w))"
            return path(d)
        case "flowChartOnlineStorage":
            let rx = w / 6, ry = h / 2
            let d = "M\(n(x + rx)) \(n(y)) H\(n(x + w)) A\(n(rx)) \(n(ry)) 0 0 0 \(n(x + w)) \(n(y + h))"
                + " H\(n(x + rx)) A\(n(rx)) \(n(ry)) 0 0 1 \(n(x + rx)) \(n(y)) Z"
            return path(d)
        case "flowChartDelay":
            let rx = w / 2, ry = h / 2
            let d = "M\(n(x)) \(n(y)) H\(n(x + rx)) A\(n(rx)) \(n(ry)) 0 0 1 \(n(x + rx)) \(n(y + h)) H\(n(x)) Z"
            return path(d)
        case "flowChartMagneticTape":
            let r = min(w, h) * 0.45, cx = x + w * 0.45, cy = y + h * 0.45
            let d = "M\(n(cx)) \(n(cy - r)) A\(n(r)) \(n(r)) 0 1 0 \(n(cx + r * 0.35)) \(n(cy + r * 0.93))"
                + " H\(n(x + w)) V\(n(cy + r)) H\(n(cx)) A\(n(r)) \(n(r)) 0 0 1 \(n(cx)) \(n(cy - r)) Z"
            return path(d)
        case "flowChartMagneticDrum":
            let rx = w / 6, ry = h / 2
            let d = "M\(n(x + rx)) \(n(y)) H\(n(x + w - rx)) A\(n(rx)) \(n(ry)) 0 0 1 \(n(x + w - rx)) \(n(y + h))"
                + " H\(n(x + rx)) A\(n(rx)) \(n(ry)) 0 0 1 \(n(x + rx)) \(n(y)) Z"
                + " M\(n(x + w - rx)) \(n(y)) A\(n(rx)) \(n(ry)) 0 0 0 \(n(x + w - rx)) \(n(y + h))"
            return path(d)
        case "flowChartDisplay":
            let dx = w / 6, rx = w / 6, ry = h / 2
            let d = "M\(n(x)) \(n(y + ry)) L\(n(x + dx)) \(n(y)) H\(n(x + w - rx))"
                + " A\(n(rx)) \(n(ry)) 0 0 1 \(n(x + w - rx)) \(n(y + h)) H\(n(x + dx)) Z"
            return path(d)
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
        default:
            return boxFallback(ix, iy, iw, ih, fill: fill, stroke: stroke)
        }
    }

    private static func boxFallback(_ ix: Int, _ iy: Int, _ iw: Int, _ ih: Int, fill: String, stroke: String) -> String {
        "<rect x=\"\(ix)\" y=\"\(iy)\" width=\"\(max(0, iw))\" height=\"\(max(0, ih))\" fill=\"\(fill)\"\(stroke)/>"
    }
}
