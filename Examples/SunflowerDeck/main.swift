// SunflowerDeck — a 30-slide deck on the sunflower, in the "Sunflower" design
// system (canary yellow, playful, Roobert PRO), with OpenAI-generated imagery.
// Run:  swift run SunflowerDeck out.pptx <images-dir>
import Foundation
import Rostrum

// MARK: - Sunflower design system

enum C {
    static let charcoal = Color("1C1C1E")
    static let white = Color.white
    static let yellow = Color("FFD02F")       // brand canary
    static let yellowDeep = Color("FCB900")
    static let yellowLight = Color("FFF4C4")   // pale bg tint
    static let yellowDark = Color("746019")    // yellow-tag text
    static let blue = Color("4262FF")
    static let blue450 = Color("5B76FE")
    static let bluePressed = Color("2A41B6")
    static let coral = Color("FF9999")
    static let coralLight = Color("FFC6C6")
    static let rose = Color("FFD8F4")
    static let cream = Color("FAF7EF")
    static let ink = Color("2B2B30")
    static let inkSoft = Color("6B6B73")
    static let hairline = Color("E7E3D8")
}

let font = "Roobert PRO"   // brand face; substitutes gracefully if not installed
let W = 13.333333, H = 7.5

func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Rect {
    Rect(x: .inches(x), y: .inches(y), width: .inches(w), height: .inches(h))
}

// MARK: - Images (cover-crop that bleeds off-slide; PowerPoint clips to the slide)

let imagesDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "images"
func image(_ name: String) -> Data? {
    try? Data(contentsOf: URL(filePath: "\(imagesDir)/\(name).png"))
}

/// A frame that covers the whole slide with a source image of `aspect`
/// (w/h), centered, no distortion — the overflow bleeds past the slide edges
/// and gets clipped on render.
func coverFrame(aspect: Double) -> Rect {
    let slideAspect = W / H
    if aspect < slideAspect {   // image relatively taller: match width, bleed top/bottom
        let w = W, h = W / aspect
        return r(0, (H - h) / 2, w, h)
    } else {                    // match height, bleed left/right
        let h = H, w = H * aspect
        return r((W - w) / 2, 0, w, h)
    }
}

/// Full-bleed background image (or a palette fallback if the file is absent).
@MainActor func bleed(_ slide: Slide, _ name: String, aspect: Double, fallback: Color = C.yellowLight) throws {
    if let data = image(name) {
        try slide.shapes.addPicture(data, frame: coverFrame(aspect: aspect))
    } else {
        try slide.setBackground(.solid(fallback))
    }
}

/// A scrim anchored to the bottom edge: transparent at `top`, ramping to full
/// darkness by ~45% of the way down and HOLDING that darkness solid through
/// the bottom of the slide. The rect bleeds 0.3" past the bottom so the dark
/// reaches the very edge — never a floating band that fades out early.
@MainActor func bottomScrim(_ slide: Slide, top: Double, dark: Double) throws {
    try slide.shapes.addShape(.rectangle, frame: r(0, top, W, H - top + 0.3),
        fill: .gradient(GradientFill(stops: [
            GradientStop(position: 0, color: C.charcoal, alpha: 0),
            GradientStop(position: 0.45, color: C.charcoal, alpha: dark),
            GradientStop(position: 1, color: C.charcoal, alpha: dark),
        ], angleDegrees: 90)))
}

// MARK: - Typography

struct Line {
    var s: String
    var size: Double
    var weight: Bool = false   // true = medium/semibold
    var color = C.charcoal
    var tracking: Double? = nil
    var before: Double = 0
}

@discardableResult
@MainActor func text(_ slide: Slide, _ frame: Rect, _ lines: [Line],
                     align: TextAlignment = .left, anchor: VerticalAnchor = .top,
                     lineSpacing: Double = 1.08) throws -> Shape {
    let box = try slide.shapes.addTextBox(frame)
    let tf = box.textFrame!
    tf.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
    tf.verticalAnchor = anchor
    tf.clear()
    for line in lines {
        let p = tf.addParagraph()
        p.alignment = align
        p.setLineSpacing(lineSpacing)
        if line.before > 0 { p.setSpacing(beforePoints: line.before) }
        let run = p.addRun(line.s)
        run.fontName = font
        run.fontSize = line.size
        run.bold = line.weight
        run.color = line.color
        if let t = line.tracking { run.letterSpacing = t }
    }
    return box
}

func kicker(_ s: String, color: Color = C.yellowDark) -> Line {
    Line(s: s.uppercased(), size: 12.5, weight: true, color: color, tracking: 2.5)
}

/// A yellow "tag" pill (design motif: yellow-light bg, olive text).
@MainActor func tag(_ slide: Slide, _ s: String, x: Double, y: Double,
                    bg: Color = C.yellowLight, fg: Color = C.yellowDark) throws {
    let w = 0.16 * Double(s.count) + 0.5
    try slide.shapes.addRoundedRectangle(r(x, y, w, 0.42), cornerRadius: .inches(0.21), fill: .solid(bg))
    try text(slide, r(x + 0.22, y, w - 0.4, 0.42),
             [Line(s: s.uppercased(), size: 11, weight: true, color: fg, tracking: 1.5)],
             anchor: .middle)
}

/// Standard content-slide header: kicker + big title on the deck's left grid.
@MainActor func header(_ slide: Slide, _ kickerText: String, _ title: String,
                       titleColor: Color = C.charcoal, kickerColor: Color = C.yellowDark) throws {
    try text(slide, r(0.9, 0.62, 11.5, 0.4), [kicker(kickerText, color: kickerColor)])
    try text(slide, r(0.9, 1.02, 11.5, 0.95), [Line(s: title, size: 32, weight: true, color: titleColor, tracking: -0.5)])
    try slide.shapes.addShape(.rectangle, frame: r(0.92, 1.78, 0.7, 0.055), fill: .solid(C.yellow))
}

// MARK: - Deck scaffold

let deck = try Presentation()
deck.slideSize = (width: .inches(13.333333), height: .inches(7.5))   // 16:9, explicit
while deck.slides.count > 0 { try deck.slides.remove(at: 0) }

@MainActor func creamSlide() throws -> Slide {
    let s = try deck.slides.add(layout: deck.layout(type: "blank")!)
    try s.setBackground(.solid(C.cream))
    return s
}
@MainActor func whiteSlide() throws -> Slide {
    let s = try deck.slides.add(layout: deck.layout(type: "blank")!)
    try s.setBackground(.solid(C.white))
    return s
}

// A section divider: full-bleed image with ONE tight bottom scrim sized to
// the text block. The top ~60% of each photograph is left untouched; the
// section number, title, and subtitle stack in the darkened lower band.
@MainActor func divider(_ index: String, _ title: String, _ subtitle: String,
                        image name: String) throws {
    let s = try deck.slides.add(layout: deck.layout(type: "blank")!)
    try bleed(s, name, aspect: 1.5, fallback: C.yellowDeep)
    try bottomScrim(s, top: 4.3, dark: 0.92)
    try text(s, r(0.95, 5.02, 9, 0.4),
             [Line(s: index, size: 13, weight: true, color: C.yellow, tracking: 3)])
    try text(s, r(0.95, 5.42, 11.7, 1.1),
             [Line(s: title, size: 46, weight: true, color: C.white, tracking: -1)])
    try text(s, r(0.97, 6.55, 11.0, 0.6),
             [Line(s: subtitle, size: 15, color: C.yellowLight)], lineSpacing: 1.25)
}

// A stat card (big number + label), rounded, with optional colored top rule.
@MainActor func statCard(_ slide: Slide, x: Double, y: Double, w: Double, h: Double,
                         number: String, label: String, accent: Color,
                         bg: Color = C.white, numberColor: Color? = nil) throws {
    try slide.shapes.addRoundedRectangle(r(x, y, w, h), cornerRadius: .inches(0.28),
                                         fill: .solid(bg)).enableSoftShadow()
    try slide.shapes.addRoundedRectangle(r(x + 0.35, y + 0.4, 0.5, 0.1),
                                         cornerRadius: .inches(0.05), fill: .solid(accent))
    try text(slide, r(x + 0.32, y + 0.62, w - 0.6, h * 0.5),
             [Line(s: number, size: min(46, h * 12), weight: true, color: numberColor ?? C.charcoal, tracking: -1)])
    try text(slide, r(x + 0.34, y + h - 0.95, w - 0.64, 0.8),
             [Line(s: label, size: 13, color: C.inkSoft)], lineSpacing: 1.2)
}

// MARK: - Table builder

@MainActor func makeTable(_ slide: Slide, _ frame: Rect, headers: [String], rows: [[String]],
                          colWidths: [Double], headerBg: Color = C.charcoal,
                          accentCol: Int? = nil, accentColor: Color = C.yellowDeep) throws {
    let t = try slide.shapes.addTable(rows: rows.count + 1, columns: headers.count, frame: frame)
    for (i, w) in colWidths.enumerated() { t.setColumnWidth(i, .inches(w)) }
    t.setRowHeight(0, .inches(0.62))
    let rowH = (frame.height.inches - 0.62) / Double(rows.count)
    for i in 1...rows.count { t.setRowHeight(i, .inches(rowH)) }
    let all = [headers] + rows
    for (ri, row) in all.enumerated() {
        for (ci, value) in row.enumerated() {
            let cell = t.cell(ri, ci)
            cell.verticalAnchor = .middle
            if ri == 0 { cell.setFill(.solid(headerBg)) }
            else if ri % 2 == 0 { cell.setFill(.solid(C.cream)) }
            else { cell.setFill(.solid(C.white)) }
            let tf = cell.textFrame
            tf.setMargins(left: .inches(0.14), top: .zero, right: .inches(0.1), bottom: .zero)
            tf.clear()
            let p = tf.addParagraph()
            if ci > 0 { p.alignment = .right }
            let run = p.addRun(value)
            run.fontName = font
            run.fontSize = ri == 0 ? 13 : 13.5
            run.bold = ri == 0 || ci == 0
            run.color = ri == 0 ? C.white
                : (ci == accentCol ? accentColor : (ci == 0 ? C.charcoal : C.inkSoft))
        }
    }
}

// MARK: - Horizontal bar row (shape-drawn, for compact comparisons)

@MainActor func barRows(_ slide: Slide, x: Double, y: Double, labelW: Double, barMaxW: Double,
                        rowH: Double, gap: Double, maxValue: Double,
                        items: [(String, Double, String, Color)]) throws {
    for (i, item) in items.enumerated() {
        let ry = y + Double(i) * (rowH + gap)
        try text(slide, r(x, ry, labelW, rowH),
                 [Line(s: item.0, size: 14, weight: true, color: C.charcoal)], anchor: .middle)
        let bw = barMaxW * item.1 / maxValue
        try slide.shapes.addRoundedRectangle(r(x + labelW + 0.15, ry + rowH * 0.15, max(0.12, bw), rowH * 0.7),
                                             cornerRadius: .inches(rowH * 0.35), fill: .solid(item.3))
        try text(slide, r(x + labelW + 0.15 + bw + 0.16, ry, 1.6, rowH),
                 [Line(s: item.2, size: 13.5, weight: true, color: C.charcoal)], anchor: .middle)
    }
}

@MainActor func footnote(_ slide: Slide, _ s: String, color: Color = C.inkSoft) throws {
    try text(slide, r(0.9, 7.02, 11.5, 0.35), [Line(s: s, size: 10.5, color: color)])
}

// ============================================================================
// SLIDES
// ============================================================================

// ---- 1 · Title
do {
    let s = try deck.slides.add(layout: deck.layout(type: "blank")!)
    try bleed(s, "title-hero", aspect: 1.5, fallback: C.yellow)
    try bottomScrim(s, top: 3.55, dark: 0.86)
    try tag(s, "A field guide", x: 0.95, y: 0.9)
    try text(s, r(0.9, 3.9, 11.5, 2.0),
             [Line(s: "Sunflower", size: 92, weight: true, color: C.white, tracking: -2)])
    try s.shapes.addShape(.rectangle, frame: r(0.95, 5.65, 1.4, 0.07), fill: .solid(C.yellow))
    try text(s, r(0.95, 5.95, 11.0, 0.9),
             [Line(s: "The science, the numbers, and the quiet genius of Helianthus annuus.",
                   size: 19, color: C.white)], lineSpacing: 1.3)
    try text(s, r(0.95, 6.95, 11.0, 0.4),
             [Line(s: "THIRTY SLIDES · GENERATED IN PURE SWIFT · IMAGERY BY OPENAI", size: 11, color: C.yellowLight, tracking: 2)])
    try s.setNotes("A 30-slide field guide to the sunflower — botany, economics, ecology, culture, and how to grow your own. Every chart, table and layout was emitted by Rostrum; every photograph by an image model.")
}

// ---- 2 · Contents
do {
    let s = try creamSlide()
    try header(s, "What's inside", "Five ways to look at a flower")
    // Each row: (index, title, desc, barColor, numeralColor). The bar keeps
    // the bright tint (a fill); the numeral uses a readable variant so no
    // number drops out on the white card.
    let plum = Color("B0468F")
    let sections: [(String, String, String, Color, Color)] = [
        ("01", "Botany", "Anatomy, heliotropism, and the Fibonacci spiral", C.yellowDeep, C.yellowDark),
        ("02", "The numbers", "Production, oil, yield, and price", C.blue, C.blue),
        ("03", "Ecology", "Pollinators, soil healing, and wildlife", C.coral, C.coral),
        ("04", "Culture & art", "Van Gogh, symbolism, and world records", C.rose, plum),
        ("05", "Grow your own", "Varieties, planting, care, and harvest", C.yellow, C.yellowDark),
    ]
    let cardH = 0.9, top = 2.05, gap = 0.13
    for (i, sec) in sections.enumerated() {
        let y = top + Double(i) * (cardH + gap)
        try s.shapes.addRoundedRectangle(r(0.9, y, 11.5, cardH), cornerRadius: .inches(0.16), fill: .solid(C.white)).enableSoftShadow()
        try s.shapes.addRoundedRectangle(r(0.9, y, 0.12, cardH), cornerRadius: .inches(0.06), fill: .solid(sec.3))
        try text(s, r(1.25, y, 1.2, cardH), [Line(s: sec.0, size: 30, weight: true, color: sec.4, tracking: -1)], anchor: .middle)
        try text(s, r(2.5, y + 0.16, 4.0, 0.6), [Line(s: sec.1, size: 21, weight: true, color: C.charcoal)])
        try text(s, r(2.5, y + 0.5, 8.6, 0.4), [Line(s: sec.2, size: 13.5, color: C.inkSoft)])
    }
}

// ---- 3 · Divider: Botany
try divider("01 · BOTANY", "The architecture of a bloom", "One flower that is really a thousand flowers.", image: "div-botany")

// ---- 4 · Anatomy
do {
    let s = try whiteSlide()
    try header(s, "Anatomy", "Not one flower, but thousands")
    if let img = image("anatomy") {
        try s.shapes.addPicture(img, frame: r(0.7, 2.05, 4.9, 4.9))
    } else {
        try s.shapes.addRoundedRectangle(r(0.7, 2.05, 4.9, 4.9), cornerRadius: .inches(0.2), fill: .solid(C.yellowLight))
    }
    let parts: [(String, String, Color)] = [
        ("Ray florets", "The showy outer \u{201C}petals\u{201D} — each one a sterile flower advertising to pollinators.", C.yellowDeep),
        ("Disc florets", "Up to 2,000 tiny fertile flowers packed in the center; each becomes a seed.", C.coral),
        ("Involucre & bracts", "The green cup of leaf-like bracts cradling the head.", C.blue),
        ("Stem & pith", "A sturdy fibrous stalk with a spongy core that can top 3 metres.", C.yellowDark),
    ]
    let top = 2.15, rh = 1.2
    for (i, part) in parts.enumerated() {
        let y = top + Double(i) * rh
        try s.shapes.addShape(.ellipse, frame: r(6.1, y + 0.08, 0.28, 0.28), fill: .solid(part.2))
        try text(s, r(6.6, y, 6.2, 0.5), [Line(s: part.0, size: 18, weight: true, color: C.charcoal)])
        try text(s, r(6.6, y + 0.42, 6.2, 0.7), [Line(s: part.1, size: 13, color: C.inkSoft)], lineSpacing: 1.2)
    }
    try footnote(s, "A sunflower \u{201C}bloom\u{201D} is a composite inflorescence — a dense cluster of many true flowers acting as one.")
}

// ---- 5 · Heliotropism
do {
    let s = try creamSlide()
    try header(s, "Heliotropism", "Young heads follow the sun")
    try s.shapes.addChart(.line,
        data: ChartData(categories: ["6am", "8am", "10am", "Noon", "2pm", "4pm", "6pm"],
                        series: [.init(name: "Head angle from vertical (°)", values: [-55, -38, -18, 2, 22, 40, 58])]),
        frame: r(0.7, 2.0, 7.8, 5.0), colors: [C.yellowDeep])
    try text(s, r(8.9, 2.3, 3.7, 4.6), [
        Line(s: "East at dawn,", size: 22, weight: true, color: C.charcoal),
        Line(s: "west by dusk.", size: 22, weight: true, color: C.yellowDeep),
        Line(s: "A growing sunflower's stem elongates on alternating sides over 24 hours, sweeping the bud from east to west and back overnight.", size: 14, color: C.inkSoft, before: 14),
        Line(s: "At maturity the motion stops — most faces settle facing east, warming faster and drawing more pollinators.", size: 14, color: C.inkSoft, before: 12),
    ], lineSpacing: 1.28)
    try footnote(s, "Stylized daily arc after Atamian et al., Science (2016), \u{201C}Circadian regulation of sunflower heliotropism.\u{201D}")
}

// ---- 6 · Fibonacci
do {
    let s = try whiteSlide()
    try header(s, "Phyllotaxis", "The 137.5° golden angle")
    if let img = image("fibonacci") {
        try s.shapes.addRoundedRectangle(r(7.2, 1.95, 5.4, 5.05), cornerRadius: .inches(0.24), fill: .solid(C.yellowLight))
        try s.shapes.addPicture(img, frame: r(7.35, 2.1, 5.1, 4.75))
    }
    try text(s, r(0.9, 2.05, 5.8, 1.6), [
        Line(s: "Each seed sits 137.5° around from the last — the golden angle.", size: 20, weight: true, color: C.charcoal),
    ], lineSpacing: 1.25)
    try text(s, r(0.9, 3.6, 5.8, 1.0), [
        Line(s: "That single rule packs seeds with no gaps and no overlaps, and it makes the interlocking spirals you can count by eye — almost always consecutive Fibonacci numbers.", size: 13.5, color: C.inkSoft),
    ], lineSpacing: 1.3)
    try s.shapes.addChart(.barClustered,
        data: ChartData(categories: ["Clockwise", "Counter-clockwise", "In a giant head"],
                        series: [.init(name: "Typical spiral count", values: [34, 55, 89])]),
        frame: r(0.7, 4.55, 6.2, 2.5), colors: [C.blue])
    try footnote(s, "34, 55, 89 — adjacent terms of the Fibonacci sequence.")
}

// ---- 7 · Growth timeline
do {
    let s = try creamSlide()
    try header(s, "Life cycle", "Seed to seed in a season")
    let stages: [(String, String, Double, Color)] = [
        ("Germination", "Days 0–10", 10, C.yellowDeep),
        ("Vegetative", "Days 10–35", 25, C.yellow),
        ("Bud (R1–R5)", "Days 35–65", 30, C.coral),
        ("Bloom (R5–R6)", "Days 65–80", 15, C.rose),
        ("Seed fill", "Days 80–110", 30, C.blue),
        ("Maturity", "Days 110–125", 15, C.yellowDark),
    ]
    let total = stages.reduce(0) { $0 + $1.2 }
    let trackX = 0.9, trackW = 11.5, trackY = 3.4
    var cx = trackX
    for stage in stages {
        let segW = trackW * stage.2 / total
        try s.shapes.addRoundedRectangle(r(cx + 0.03, trackY, segW - 0.06, 0.6), cornerRadius: .inches(0.1), fill: .solid(stage.3))
        cx += segW
    }
    cx = trackX
    for (i, stage) in stages.enumerated() {
        let segW = trackW * stage.2 / total
        let up = i % 2 == 0
        let labelY = up ? 2.35 : 4.2
        try s.shapes.addShape(.rectangle, frame: r(cx + segW/2 - 0.005, up ? 2.95 : 4.0, 0.01, 0.45), fill: .solid(C.hairline))
        try text(s, r(cx + segW/2 - 1.1, labelY, 2.2, 0.75),
                 [Line(s: stage.0, size: 14, weight: true, color: C.charcoal),
                  Line(s: stage.1, size: 11.5, color: C.inkSoft, before: 2)],
                 align: .center, lineSpacing: 1.1)
        cx += segW
    }
    try text(s, r(0.9, 5.5, 11.5, 1.0), [
        Line(s: "~125 days", size: 40, weight: true, color: C.yellowDeep, tracking: -1),
        Line(s: "from a planted seed to a head of new seeds, in a single warm growing season.", size: 15, color: C.inkSoft, before: 6),
    ], lineSpacing: 1.2)
}

// ---- 8 · Divider: The Numbers
try divider("02 · THE NUMBERS", "A global commodity", "From a prairie wildflower to 55 million tonnes a year.", image: "div-numbers")

// ---- 9 · Production bar chart
do {
    let s = try creamSlide()
    try header(s, "Production · seed", "Where sunflowers grow at scale")
    try s.shapes.addChart(.barClustered,
        data: ChartData(categories: ["Russia", "Ukraine", "Argentina", "China", "Romania", "Turkey", "Bulgaria"],
                        series: [.init(name: "Sunflower seed (million tonnes, 2023)", values: [17.5, 12.5, 4.5, 3.6, 2.5, 1.9, 1.8])]),
        frame: r(0.7, 2.0, 11.9, 4.9), colors: [C.yellowDeep])
    try footnote(s, "Illustrative recent-year figures, FAOSTAT-style ordering. Russia and Ukraine together grow over half the world's crop.")
}

// ---- 10 · Oil market line chart
do {
    let s = try whiteSlide()
    try header(s, "The oil market", "A steadily rising pour")
    try s.shapes.addChart(.line,
        data: ChartData(categories: ["2010", "2013", "2016", "2019", "2022", "2025"],
                        series: [.init(name: "Global sunflower-oil market (US$ billion)", values: [17.5, 21.0, 24.5, 28.0, 30.5, 34.2])]),
        frame: r(0.7, 2.0, 8.4, 5.0), colors: [C.blue])
    try statCard(s, x: 9.4, y: 2.2, w: 3.2, h: 2.15, number: "~US$34B", label: "estimated 2025 market for sunflower oil", accent: C.blue, bg: C.cream)
    try statCard(s, x: 9.4, y: 4.6, w: 3.2, h: 2.15, number: "#4", label: "most-produced vegetable oil worldwide", accent: C.yellowDeep, bg: C.cream)
    try footnote(s, "Directional market-size trend for illustration; sunflower trails palm, soybean and rapeseed oils.")
}

// ---- 11 · Oil composition pie
do {
    let s = try creamSlide()
    try header(s, "What's in the oil", "Mostly healthy unsaturated fat")
    let comp: [(String, Double, Color)] = [
        ("Oleic acid (omega-9)", 48, C.yellowDeep),
        ("Linoleic acid (omega-6)", 40, C.blue),
        ("Palmitic acid", 6, C.coral),
        ("Stearic acid", 4, C.rose),
        ("Other", 2, C.inkSoft),
    ]
    try s.shapes.addChart(.pie,
        data: ChartData(categories: comp.map(\.0), name: "Fatty acid profile", values: comp.map(\.1)),
        frame: r(0.4, 1.8, 6.6, 5.3), colors: comp.map(\.2))
    for (i, c) in comp.enumerated() {
        let y = 2.55 + Double(i) * 0.66
        try s.shapes.addRoundedRectangle(r(7.7, y + 0.05, 0.32, 0.32), cornerRadius: .inches(0.08), fill: .solid(c.2))
        try text(s, r(8.15, y, 3.7, 0.5), [Line(s: c.0, size: 14.5, color: C.charcoal)], anchor: .middle)
        try text(s, r(11.9, y, 0.7, 0.5), [Line(s: "\(Int(c.1))%", size: 14.5, weight: true, color: C.inkSoft)], align: .right, anchor: .middle)
    }
    try footnote(s, "Typical mid-oleic profile; high-oleic cultivars push oleic acid past 80%.")
}

// ---- 12 · Yield table
do {
    let s = try whiteSlide()
    try header(s, "Yield by region", "Area, output, and productivity")
    try makeTable(s, r(0.9, 2.05, 11.5, 4.5),
        headers: ["Region", "Area (M ha)", "Yield (t/ha)", "Production (Mt)"],
        rows: [
            ["Eastern Europe", "9.8", "2.4", "23.5"],
            ["European Union", "4.6", "2.2", "10.1"],
            ["South America", "2.4", "1.9", "4.6"],
            ["Asia", "3.1", "1.5", "4.7"],
            ["Africa", "2.0", "1.0", "2.0"],
            ["North America", "0.9", "2.0", "1.8"],
        ],
        colWidths: [4.4, 2.37, 2.37, 2.36], accentCol: 3, accentColor: C.yellowDark)
    try footnote(s, "Illustrative regional aggregates. Yield gaps track rainfall, hybrids, and mechanization.")
}

// ---- 13 · Price trends
do {
    let s = try creamSlide()
    try header(s, "Price", "A decade of volatility")
    try s.shapes.addChart(.line,
        data: ChartData(categories: ["2016", "2017", "2018", "2019", "2020", "2021", "2022", "2023", "2024"],
                        series: [.init(name: "Sunflower oil (US$ / tonne)", values: [820, 790, 730, 760, 1100, 1450, 1870, 970, 1080])]),
        frame: r(0.7, 2.0, 8.4, 5.0), colors: [C.coral])
    try statCard(s, x: 9.4, y: 2.2, w: 3.2, h: 2.15, number: "2.4×", label: "peak vs. trough price over the decade", accent: C.coral, bg: C.white, numberColor: C.charcoal)
    try statCard(s, x: 9.4, y: 4.6, w: 3.2, h: 2.15, number: "2022", label: "spike as Black Sea supply seized up", accent: C.yellowDeep, bg: C.white)
    try footnote(s, "Directional annual averages; sunflower oil is unusually exposed to a small number of exporting regions.")
}

// ---- 14 · Nutrition
do {
    let s = try whiteSlide()
    try header(s, "Nutrition · seeds", "A dense little package")
    try makeTable(s, r(0.9, 2.05, 7.4, 4.5),
        headers: ["Per 100 g kernels", "Amount", "% DV"],
        rows: [
            ["Energy", "584 kcal", "—"],
            ["Protein", "21 g", "42%"],
            ["Fat", "51 g", "—"],
            ["Fibre", "9 g", "32%"],
            ["Vitamin E", "35 mg", "234%"],
            ["Magnesium", "325 mg", "81%"],
            ["Selenium", "53 µg", "96%"],
        ],
        colWidths: [4.0, 1.9, 1.5], accentCol: 2, accentColor: C.yellowDark)
    try statCard(s, x: 8.7, y: 2.05, w: 3.7, h: 2.15, number: "234%", label: "of daily vitamin E in one 100 g handful", accent: C.yellowDeep, bg: C.cream)
    try statCard(s, x: 8.7, y: 4.4, w: 3.7, h: 2.15, number: "21 g", label: "plant protein — more than two eggs", accent: C.blue, bg: C.cream)
    try footnote(s, "USDA-style values for dried, unsalted kernels; %DV on a 2,000 kcal reference.")
}

// ---- 15 · Divider: Ecology
try divider("03 · ECOLOGY", "A working flower", "Feeding pollinators, cleaning soil, sheltering wildlife.", image: "div-ecology")

// ---- 16 · Pollinators
do {
    let s = try creamSlide()
    try header(s, "Pollinators", "Who visits the disc")
    if let img = image("pollinator") {
        try s.shapes.addRoundedRectangle(r(8.6, 2.15, 4.0, 4.6), cornerRadius: .inches(0.24), fill: .solid(C.yellowLight))
        try s.shapes.addPicture(img, frame: r(8.75, 2.3, 3.7, 4.3))
    }
    try barRows(s, x: 0.9, y: 2.35, labelW: 2.6, barMaxW: 2.9, rowH: 0.6, gap: 0.34, maxValue: 100, items: [
        ("Honeybees", 100, "most visits", C.yellowDeep),
        ("Bumblebees", 62, "", C.coral),
        ("Solitary bees", 48, "", C.blue),
        ("Hoverflies", 30, "", C.rose),
        ("Butterflies", 18, "", C.yellowDark),
    ])
    try footnote(s, "Relative visitation, stylized; a single head can serve hundreds of visits a day. Exact mix varies with region and cultivar.")
}

// ---- 17 · Phytoremediation
do {
    let s = try whiteSlide()
    try header(s, "Soil healing", "The flower that pulls poison")
    if let img = image("phytoremediation") {
        try s.shapes.addRoundedRectangle(r(7.6, 2.0, 5.0, 4.4), cornerRadius: .inches(0.24), fill: .solid(C.yellowLight))
        try s.shapes.addPicture(img, frame: r(7.75, 2.15, 4.7, 4.1))
    }
    try text(s, r(0.9, 2.1, 6.2, 1.4), [
        Line(s: "Sunflowers are hyperaccumulators — their roots draw heavy metals and radionuclides up out of contaminated ground.", size: 17, color: C.charcoal),
    ], lineSpacing: 1.3)
    let facts: [(String, String, Color)] = [
        ("Chernobyl & Fukushima", "Planted on floating rafts and fields to draw caesium and strontium from soil and water.", C.blue),
        ("Lead, arsenic, cadmium", "Roots concentrate metals into harvestable biomass, lowering soil loads season by season.", C.coral),
        ("Low cost, living tech", "Phytoremediation runs on sunlight instead of excavation and haulage.", C.yellowDeep),
    ]
    for (i, f) in facts.enumerated() {
        let y = 3.7 + Double(i) * 1.05
        try s.shapes.addShape(.ellipse, frame: r(0.9, y + 0.05, 0.26, 0.26), fill: .solid(f.2))
        try text(s, r(1.35, y - 0.02, 5.8, 0.4), [Line(s: f.0, size: 15, weight: true, color: C.charcoal)])
        try text(s, r(1.35, y + 0.36, 5.8, 0.6), [Line(s: f.1, size: 12.5, color: C.inkSoft)], lineSpacing: 1.2)
    }
}

// ---- 18 · Wildlife table
do {
    let s = try creamSlide()
    try header(s, "Wildlife value", "A late-season larder")
    try makeTable(s, r(0.9, 2.05, 11.5, 4.5),
        headers: ["Visitor", "Takes", "When"],
        rows: [
            ["American goldfinch", "Ripe seeds, straight from the head", "Late summer–autumn"],
            ["Chickadees & nuthatches", "Seeds cached for winter", "Autumn–winter"],
            ["Doves & sparrows", "Fallen seed on the ground", "Autumn"],
            ["Bees & hoverflies", "Pollen and nectar", "Bloom"],
            ["Small mammals", "Seed heads left standing", "Winter"],
        ],
        colWidths: [4.6, 4.5, 2.4], accentCol: nil)
    try footnote(s, "Leaving spent heads standing through winter turns a flower bed into a bird feeder.")
}

// ---- 19 · Divider: Culture & Art
try divider("04 · CULTURE & ART", "A muse in yellow", "From Van Gogh's studio to the record books.", image: "div-culture")

// ---- 20 · Van Gogh
do {
    let s = try whiteSlide()
    try header(s, "Van Gogh", "The sunflowers that made a name")
    if let img = image("div-culture") {
        try s.shapes.addRoundedRectangle(r(7.5, 2.0, 5.1, 4.5), cornerRadius: .inches(0.24), fill: .solid(C.yellowLight))
        try s.shapes.addPicture(img, frame: r(7.65, 2.15, 4.8, 4.2))
    }
    try text(s, r(0.9, 2.05, 6.2, 1.3), [
        Line(s: "In Arles in 1888, Van Gogh painted sunflowers to decorate a room for his friend Gauguin.", size: 16, color: C.charcoal),
    ], lineSpacing: 1.3)
    try makeTable(s, r(0.9, 3.4, 6.3, 3.1),
        headers: ["Version", "Blooms", "Now at"],
        rows: [
            ["1st Arles", "Fifteen", "National Gallery, London"],
            ["2nd", "Fifteen", "Neue Pinakothek, Munich"],
            ["3rd", "Twelve", "Philadelphia Museum"],
            ["Repetition", "Fifteen", "Van Gogh Museum, A'dam"],
        ],
        colWidths: [1.9, 1.7, 2.7])
    try footnote(s, "The image here is an original painterly still life, not a reproduction of a specific canvas.")
}

// ---- 21 · Symbolism
do {
    let s = try creamSlide()
    try header(s, "Symbolism", "What the flower has meant")
    let meanings: [(String, String, Color)] = [
        ("Adoration", "Greek myth: the nymph Clytie pined for the sun god and became a sun-following flower.", C.yellowDeep),
        ("Loyalty & faith", "The head that always turns to the light became an emblem of steadfast devotion.", C.coral),
        ("Longevity", "In Chinese tradition, a wish for a long life and good fortune.", C.blue),
        ("Hope & peace", "Ukraine's national flower, and since 2022 a worldwide symbol of solidarity.", C.rose),
    ]
    let cw = (W - 2 * 0.9 - 0.35) / 2, gap = 0.35, ch = 2.15
    for (i, m) in meanings.enumerated() {
        let x = 0.9 + Double(i % 2) * (cw + gap)
        let y = 2.15 + Double(i / 2) * (ch + 0.3)
        try s.shapes.addRoundedRectangle(r(x, y, cw, ch), cornerRadius: .inches(0.26), fill: .solid(C.white)).enableSoftShadow()
        try s.shapes.addRoundedRectangle(r(x + 0.4, y + 0.42, 0.55, 0.12), cornerRadius: .inches(0.06), fill: .solid(m.2))
        try text(s, r(x + 0.4, y + 0.66, cw - 0.8, 0.55), [Line(s: m.0, size: 22, weight: true, color: C.charcoal)])
        try text(s, r(x + 0.4, y + 1.24, cw - 0.8, 0.8), [Line(s: m.1, size: 13.5, color: C.inkSoft)], lineSpacing: 1.25)
    }
}

// ---- 22 · Records
do {
    let s = try whiteSlide()
    try header(s, "Records", "Sunflowers at the extremes")
    if let img = image("records") {
        try s.shapes.addPicture(img, frame: r(9.0, 2.05, 3.6, 4.9))
    }
    try statCard(s, x: 0.9, y: 2.05, w: 3.7, h: 2.35, number: "9.17 m", label: "world's tallest sunflower (Germany, 2014)", accent: C.yellowDeep, bg: C.cream)
    try statCard(s, x: 4.85, y: 2.05, w: 3.7, h: 2.35, number: "82 cm", label: "widest flower head on record (Canada, 1983)", accent: C.blue, bg: C.cream)
    try statCard(s, x: 0.9, y: 4.6, w: 3.7, h: 2.35, number: "837", label: "most heads on a single plant (2018)", accent: C.coral, bg: C.cream)
    try statCard(s, x: 4.85, y: 4.6, w: 3.7, h: 2.35, number: "2,000+", label: "seeds a single big head can hold", accent: C.yellowDark, bg: C.cream)
    try footnote(s, "Guinness World Records; figures rounded.")
}

// ---- 23 · Divider: Grow Your Own
try divider("05 · GROW YOUR OWN", "From your own soil", "A flower generous enough for a first-time gardener.", image: "div-grow")

// ---- 24 · Varieties
do {
    let s = try creamSlide()
    try header(s, "Choosing a variety", "Giants, dwarfs, and cut-flowers")
    try makeTable(s, r(0.9, 2.05, 11.5, 4.5),
        headers: ["Variety", "Height", "Days to bloom", "Best for"],
        rows: [
            ["'Mammoth Russian'", "3.0 m", "90", "Seeds & sheer height"],
            ["'Autumn Beauty'", "1.8 m", "75", "Warm bicolor blooms"],
            ["'Teddy Bear'", "0.6 m", "70", "Pots & children's plots"],
            ["'Lemon Queen'", "1.7 m", "80", "Pollinators, pale petals"],
            ["'ProCut' (F1)", "1.5 m", "60", "Cut flowers, pollen-free"],
            ["'Red Sun'", "1.8 m", "80", "Deep mahogany drama"],
        ],
        colWidths: [3.4, 1.8, 2.9, 3.4], accentCol: 2, accentColor: C.blue)
    try footnote(s, "Days-to-bloom assume warm soil and full sun; cooler sites run a week or two longer.")
}

// ---- 25 · Planting guide
do {
    let s = try whiteSlide()
    try header(s, "Planting", "Four things a seed asks for")
    let steps: [(String, String, String, Color)] = [
        ("Sun", "6–8 hrs", "Full sun, all day. Sunflowers will not thrive in shade.", C.yellowDeep),
        ("Soil", "pH 6–7.5", "Loose, well-drained ground; they tolerate poor soil but love compost.", C.coral),
        ("Spacing", "30–45 cm", "Sow 2–3 cm deep after frost, thinning tall types to give heads room.", C.blue),
        ("Water", "Deep, weekly", "Steady moisture while establishing; drought-hardy once rooted.", C.yellowDark),
    ]
    let cw = (W - 2 * 0.9 - 3 * 0.3) / 4, gap = 0.3, ch = 4.4
    for (i, step) in steps.enumerated() {
        let x = 0.9 + Double(i) * (cw + gap)
        try s.shapes.addRoundedRectangle(r(x, 2.2, cw, ch), cornerRadius: .inches(0.28), fill: .solid(C.cream)).enableSoftShadow()
        try s.shapes.addRoundedRectangle(r(x + 0.3, 2.55, 0.9, 0.9), cornerRadius: .inches(0.45), fill: .solid(step.3))
        try text(s, r(x + 0.3, 3.65, cw - 0.6, 0.5), [Line(s: step.0, size: 21, weight: true, color: C.charcoal)])
        try text(s, r(x + 0.3, 4.15, cw - 0.6, 0.4), [Line(s: step.1, size: 15, weight: true, color: C.charcoal)])
        try text(s, r(x + 0.3, 4.7, cw - 0.6, 1.6), [Line(s: step.2, size: 12.5, color: C.inkSoft)], lineSpacing: 1.25)
    }
}

// ---- 26 · Care calendar
do {
    let s = try creamSlide()
    try header(s, "Season calendar", "What to do, month by month")
    let months = ["Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct"]
    let tasks: [(String, [Int], Color)] = [
        ("Sow seed", [0, 1], C.yellowDeep),
        ("Thin & feed", [1, 2], C.yellow),
        ("Stake tall types", [2, 3], C.coral),
        ("Bloom & enjoy", [3, 4, 5], C.rose),
        ("Harvest seed", [5, 6], C.blue),
    ]
    let gridX = 3.3, gridW = 9.1, colW = gridW / Double(months.count)
    for (i, m) in months.enumerated() {
        try text(s, r(gridX + Double(i) * colW, 2.1, colW, 0.4),
                 [Line(s: m, size: 13, weight: true, color: C.inkSoft)], align: .center)
    }
    let rowH = 0.72
    for (ri, task) in tasks.enumerated() {
        let y = 2.6 + Double(ri) * (rowH + 0.12)
        try text(s, r(0.9, y, 2.3, rowH), [Line(s: task.0, size: 14, weight: true, color: C.charcoal)], anchor: .middle)
        for mi in task.1 {
            try s.shapes.addRoundedRectangle(r(gridX + Double(mi) * colW + 0.06, y + rowH * 0.15, colW - 0.12, rowH * 0.7),
                                             cornerRadius: .inches(0.1), fill: .solid(task.2))
        }
    }
    try footnote(s, "Northern-hemisphere temperate timing; shift by your local last-frost date.")
}

// ---- 27 · Harvest
do {
    let s = try whiteSlide()
    try header(s, "Harvest", "Knowing when to cut")
    if let img = image("harvest") {
        try s.shapes.addRoundedRectangle(r(7.6, 2.0, 5.0, 4.5), cornerRadius: .inches(0.24), fill: .solid(C.yellowLight))
        try s.shapes.addPicture(img, frame: r(7.75, 2.15, 4.7, 4.2))
    }
    let steps: [(String, String, Color)] = [
        ("1 · Watch the back", "The head's reverse turns from green to yellow, then papery brown.", C.yellowDeep),
        ("2 · Cut & hang", "Snip 30 cm of stalk and hang the head to dry in a warm, airy, rodent-proof spot.", C.coral),
        ("3 · Rub out seeds", "Once dry, rub two heads together or brush by hand over a bucket.", C.blue),
        ("4 · Cure & store", "Dry a week more, then keep airtight; roast, or save the plumpest for next spring.", C.yellowDark),
    ]
    for (i, step) in steps.enumerated() {
        let y = 2.2 + Double(i) * 1.12
        try s.shapes.addShape(.ellipse, frame: r(0.9, y + 0.05, 0.28, 0.28), fill: .solid(step.2))
        try text(s, r(1.4, y - 0.02, 5.9, 0.45), [Line(s: step.0, size: 16, weight: true, color: C.charcoal)])
        try text(s, r(1.4, y + 0.4, 5.9, 0.6), [Line(s: step.1, size: 12.5, color: C.inkSoft)], lineSpacing: 1.2)
    }
}

// ---- 28 · Companion planting
do {
    let s = try creamSlide()
    try header(s, "Good company", "Who to plant nearby")
    let good: [(String, String)] = [
        ("Cucumbers & squash", "Climb the stalks; the shade keeps their roots cool."),
        ("Corn", "Two tall crops that share sun and shelter each other from wind."),
        ("Beans", "Fix nitrogen for the hungry sunflower and clamber up the stem."),
    ]
    let bad: [(String, String)] = [
        ("Potatoes", "Compete heavily and are prone to the same fungal troubles."),
        ("Pole beans near roots", "Allelopathic seed hulls can stunt some seedlings underneath."),
    ]
    try s.shapes.addRoundedRectangle(r(0.9, 2.15, 5.65, 4.6), cornerRadius: .inches(0.24), fill: .solid(C.white)).enableSoftShadow()
    try s.shapes.addRoundedRectangle(r(1.25, 2.5, 0.55, 0.12), cornerRadius: .inches(0.06), fill: .solid(C.yellowDeep))
    try text(s, r(1.25, 2.74, 5.0, 0.5), [Line(s: "Plant together", size: 18, weight: true, color: C.charcoal)])
    for (i, g) in good.enumerated() {
        let y = 3.45 + Double(i) * 1.05
        try text(s, r(1.25, y, 5.0, 0.4), [Line(s: g.0, size: 15, weight: true, color: C.charcoal)])
        try text(s, r(1.25, y + 0.36, 5.0, 0.6), [Line(s: g.1, size: 12.5, color: C.inkSoft)], lineSpacing: 1.2)
    }
    try s.shapes.addRoundedRectangle(r(6.75, 2.15, 5.65, 4.6), cornerRadius: .inches(0.24), fill: .solid(C.white)).enableSoftShadow()
    try s.shapes.addRoundedRectangle(r(7.1, 2.5, 0.55, 0.12), cornerRadius: .inches(0.06), fill: .solid(C.coral))
    try text(s, r(7.1, 2.74, 5.0, 0.5), [Line(s: "Keep apart", size: 18, weight: true, color: C.charcoal)])
    for (i, b) in bad.enumerated() {
        let y = 3.45 + Double(i) * 1.05
        try text(s, r(7.1, y, 5.0, 0.4), [Line(s: b.0, size: 15, weight: true, color: C.charcoal)])
        try text(s, r(7.1, y + 0.36, 5.0, 0.6), [Line(s: b.1, size: 12.5, color: C.inkSoft)], lineSpacing: 1.2)
    }
}

// ---- 29 · Fun facts
do {
    let s = try whiteSlide()
    try header(s, "Odds & ends", "Nine things worth knowing")
    let facts: [(String, String, Color)] = [
        ("Not one flower", "A head is up to 2,000 tiny flowers acting as one.", C.yellowDeep),
        ("Native American", "Domesticated in North America ~3000 BCE.", C.coral),
        ("Round trip", "Taken to Europe by the Spanish, returned as a crop.", C.blue),
        ("State flower", "Kansas is \u{201C}The Sunflower State.\u{201D}", C.yellowDark),
        ("Edible whole", "Seeds, sprouts, petals and buds are all eaten.", C.rose),
        ("Dye & more", "Petals and hulls yield yellow and purple dyes.", C.yellowDeep),
        ("Space flower", "Grown aboard the ISS in 2012.", C.blue),
        ("Fast riser", "Can add several cm of height in a single day.", C.coral),
        ("Faces east", "Mature heads mostly settle facing sunrise.", C.yellowDark),
    ]
    let cw = (W - 2 * 0.9 - 2 * 0.3) / 3, gap = 0.3, ch = 1.5
    for (i, f) in facts.enumerated() {
        let x = 0.9 + Double(i % 3) * (cw + gap)
        let y = 2.2 + Double(i / 3) * (ch + 0.22)
        try s.shapes.addRoundedRectangle(r(x, y, cw, ch), cornerRadius: .inches(0.2), fill: .solid(C.cream))
        try s.shapes.addRoundedRectangle(r(x + 0.28, y + 0.28, 0.4, 0.09), cornerRadius: .inches(0.045), fill: .solid(f.2))
        try text(s, r(x + 0.28, y + 0.48, cw - 0.56, 0.4), [Line(s: f.0, size: 15, weight: true, color: C.charcoal)])
        try text(s, r(x + 0.28, y + 0.86, cw - 0.56, 0.55), [Line(s: f.1, size: 11.5, color: C.inkSoft)], lineSpacing: 1.15)
    }
}

// ---- 30 · Closing
do {
    let s = try deck.slides.add(layout: deck.layout(type: "blank")!)
    try bleed(s, "closing", aspect: 1.5, fallback: C.yellowDeep)
    try bottomScrim(s, top: 3.55, dark: 0.74)
    try text(s, r(0.9, 2.7, 11.5, 1.5),
             [Line(s: "Turn toward the light.", size: 56, weight: true, color: C.white, tracking: -1)], align: .center)
    try s.shapes.addShape(.rectangle, frame: r(W/2 - 0.7, 4.25, 1.4, 0.06), fill: .solid(C.yellow))
    try text(s, r(0.9, 4.55, 11.5, 0.6),
             [Line(s: "Helianthus annuus", size: 20, color: C.yellowLight, tracking: 1)], align: .center)
    try text(s, r(0.9, 6.75, 11.5, 0.6), [
        Line(s: "Sources: FAOSTAT · USDA · Guinness World Records · Atamian et al. 2016 · Van Gogh Museum", size: 11, color: C.yellowLight),
        Line(s: "Deck generated in pure Swift by Rostrum · imagery by OpenAI gpt-image-1", size: 11, color: C.white, before: 4),
    ], align: .center)
}

// MARK: - Save

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "sunflower.pptx"
try deck.save(to: URL(filePath: outputPath))
print("wrote \(outputPath): \(deck.slides.count) slides")
