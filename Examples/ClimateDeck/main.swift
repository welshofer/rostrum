// ClimateDeck — Rostrum's showcase: a 15-slide deck on climate change,
// generated entirely in Swift. Run:  swift run ClimateDeck out.pptx
import Foundation
import Rostrum

// MARK: - Design system

enum Palette {
    static let navy = Color("0B1D33")
    static let navyDeep = Color("071426")
    static let navyLift = Color("14314F")
    static let paper = Color("F7F4EE")
    static let ink = Color("22303F")
    static let inkSoft = Color("5A6B7A")
    static let teal = Color("18A999")
    static let coral = Color("FF6B5B")
    static let amber = Color("FFB454")
    static let mist = Color("AFC3D4")

    /// ColorBrewer RdBu-style ramp for the warming stripes, cold → hot.
    static let stripes = [
        "08306B", "08519C", "2171B5", "4292C6", "6BAED6", "9ECAE1", "C6DBEF", "DEEBF7",
        "FEE0D2", "FCBBA1", "FC9272", "FB6A4A", "EF3B2C", "CB181D", "A50F15", "67000D",
    ].map(Color.init)
}

let display = "Avenir Next"
let W = 13.333333, H = 7.5

func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Rect {
    Rect(x: .inches(x), y: .inches(y), width: .inches(w), height: .inches(h))
}

struct TextSpec {
    var text: String
    var size: Double
    var bold = false
    var color = Color.white
    var tracking: Double? = nil
    var spaceBefore: Double = 0
}

@discardableResult
func addText(
    _ slide: Slide, _ frame: Rect, _ specs: [TextSpec],
    align: TextAlignment = .left, anchor: VerticalAnchor = .top,
    lineSpacing: Double = 1.0
) throws -> Shape {
    let box = try slide.shapes.addTextBox(frame)
    let tf = box.textFrame!
    tf.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
    tf.verticalAnchor = anchor
    tf.wordWrap = true
    tf.clear()
    for spec in specs {
        let p = tf.addParagraph()
        p.alignment = align
        p.setLineSpacing(lineSpacing)
        if spec.spaceBefore > 0 { p.setSpacing(beforePoints: spec.spaceBefore) }
        let run = p.addRun(spec.text)
        run.fontName = display
        run.fontSize = spec.size
        run.bold = spec.bold
        run.color = spec.color
        if let tracking = spec.tracking { run.letterSpacing = tracking }
    }
    return box
}

func kicker(_ text: String, color: Color = Palette.teal) -> TextSpec {
    TextSpec(text: text.uppercased(), size: 15, bold: true, color: color, tracking: 3)
}

@discardableResult
func accentBar(_ slide: Slide, x: Double, y: Double, w: Double = 0.9,
               color: Color = Palette.coral) throws -> Shape {
    try slide.shapes.addShape(.rectangle, frame: r(x, y, w, 0.07), fill: .solid(color))
}

func sectionDivider(_ slide: Slide, index: String, word: String) throws {
    try slide.setBackground(.gradient(GradientFill(
        from: Palette.navyDeep, to: Palette.navyLift, angleDegrees: 115)))
    try addText(slide, r(1.0, 2.1, 2.0, 1.0),
        [TextSpec(text: index, size: 40, bold: true, color: Palette.coral, tracking: 2)])
    try addText(slide, r(1.0, 2.9, 11.4, 2.2),
        [TextSpec(text: word, size: 96, bold: true, color: .white, tracking: 1)])
    try accentBar(slide, x: 1.04, y: 2.95, w: 1.4)
    // Ghost number, oversized, low-alpha, right-aligned.
    let ghost = try slide.shapes.addTextBox(r(7.2, 0.6, 5.8, 6.3))
    let tf = ghost.textFrame!
    tf.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
    tf.verticalAnchor = .middle
    tf.clear()
    let p = tf.addParagraph()
    p.alignment = .right
    let run = p.addRun(index)
    run.fontName = display
    run.fontSize = 320
    run.bold = true
    run.color = Palette.navyLift
}

func bigNumberSlide(
    _ slide: Slide, kickerText: String, number: String, numberColor: Color,
    context: String, source: String
) throws {
    try slide.setBackground(.solid(Palette.navy))
    try addText(slide, r(1.0, 1.15, 11.0, 0.5), [kicker(kickerText)])
    try accentBar(slide, x: 1.04, y: 1.72, color: numberColor)
    try addText(slide, r(1.0, 2.1, 11.4, 2.6),
        [TextSpec(text: number, size: 150, bold: true, color: numberColor, tracking: -1)])
    try addText(slide, r(1.0, 4.75, 10.2, 1.5),
        [TextSpec(text: context, size: 24, color: .white)], lineSpacing: 1.15)
    try addText(slide, r(1.0, 6.7, 11.0, 0.4),
        [TextSpec(text: source, size: 12, color: Palette.mist, tracking: 1)])
}

struct Card { var emoji: String; var title: String; var body: String }

func cardRow(_ slide: Slide, cards: [Card], top: Double, cardH: Double,
             compact: Bool = false) throws {
    let margin = 1.0, gap = 0.35
    let cardW = (W - 2 * margin - Double(cards.count - 1) * gap) / Double(cards.count)
    for (i, card) in cards.enumerated() {
        let x = margin + Double(i) * (cardW + gap)
        let panel = try slide.shapes.addShape(
            .roundedRectangle, frame: r(x, top, cardW, cardH), fill: .solid(.white))
        panel.enableSoftShadow()
        if compact {
            // Emoji and title share the top line; body hugs beneath.
            try addText(slide, r(x + 0.3, top + 0.28, 0.7, 0.55),
                [TextSpec(text: card.emoji, size: 28)])
            try addText(slide, r(x + 1.0, top + 0.32, cardW - 1.3, 0.5),
                [TextSpec(text: card.title, size: 19, bold: true, color: Palette.ink)])
            try addText(slide, r(x + 0.3, top + 0.95, cardW - 0.6, cardH - 1.2),
                [TextSpec(text: card.body, size: 13.5, color: Palette.inkSoft)], lineSpacing: 1.15)
        } else {
            try addText(slide, r(x + 0.3, top + 0.3, cardW - 0.6, 0.9),
                [TextSpec(text: card.emoji, size: 44)])
            try addText(slide, r(x + 0.3, top + 1.25, cardW - 0.6, 0.5),
                [TextSpec(text: card.title, size: 20, bold: true, color: Palette.ink)])
            try addText(slide, r(x + 0.3, top + 1.8, cardW - 0.6, cardH - 2.1),
                [TextSpec(text: card.body, size: 14, color: Palette.inkSoft)], lineSpacing: 1.2)
        }
    }
}

// MARK: - Build the deck

let deck = try Presentation()
var slides: [Slide] = [try deck.slides[0]]
while slides.count < 15 { slides.append(try deck.slides.add()) }

// ---- 1 · Title
do {
    let s = slides[0]
    try s.setBackground(.gradient(GradientFill(stops: [
        GradientStop(position: 0, color: Palette.navyDeep),
        GradientStop(position: 0.65, color: Palette.navy),
        GradientStop(position: 1, color: Palette.navyLift),
    ], angleDegrees: 115)))
    // Horizon accent: thin warming-gradient strip.
    try s.shapes.addShape(.rectangle, frame: r(0, 5.62, W, 0.06),
        fill: .gradient(GradientFill(stops: [
            GradientStop(position: 0, color: Palette.teal),
            GradientStop(position: 0.55, color: Palette.amber),
            GradientStop(position: 1, color: Palette.coral),
        ], angleDegrees: 0)))
    try addText(s, r(1.0, 1.55, 11.0, 0.5), [kicker("A briefing in fifteen slides")])
    try addText(s, r(1.0, 2.05, 11.4, 2.6), [
        TextSpec(text: "Our Changing", size: 88, bold: true, color: .white),
        TextSpec(text: "Climate", size: 88, bold: true, color: Palette.coral),
    ], lineSpacing: 0.98)
    try addText(s, r(1.0, 5.9, 11.0, 0.9), [
        TextSpec(text: "What the numbers say — and why this decade decides the century.",
                 size: 22, color: Palette.mist),
    ])
    try addText(s, r(1.0, 6.95, 11.0, 0.4), [
        TextSpec(text: "Generated 100% in Swift by Rostrum", size: 11,
                 color: Palette.inkSoft, tracking: 2),
    ])
}

// ---- 2 · Framing statement
do {
    let s = slides[1]
    try s.setBackground(.solid(Palette.paper))
    try addText(s, r(1.0, 1.1, 11.0, 0.5), [kicker("The mechanism", color: Palette.coral)])
    try accentBar(s, x: 1.04, y: 1.68, color: Palette.teal)
    try addText(s, r(1.0, 2.0, 11.3, 3.2), [
        TextSpec(text: "The physics is simple.", size: 54, bold: true, color: Palette.ink),
        TextSpec(text: "Carbon dioxide traps heat — and we have raised it to levels unseen in 800,000 years.",
                 size: 30, color: Palette.inkSoft, spaceBefore: 18),
    ], lineSpacing: 1.12)
    let facts: [(String, String)] = [
        ("50%", "more CO₂ than pre-industrial air"),
        ("90%", "of excess heat absorbed by the ocean"),
        ("~0", "natural explanations left standing"),
    ]
    let cw = 3.6, gap = 0.35
    for (i, fact) in facts.enumerated() {
        let x = 1.0 + Double(i) * (cw + gap)
        try s.shapes.addShape(.rectangle, frame: r(x, 5.35, 0.06, 1.25),
                              fill: .solid(Palette.teal))
        try addText(s, r(x + 0.25, 5.3, cw - 0.3, 0.75),
            [TextSpec(text: fact.0, size: 40, bold: true, color: Palette.ink)])
        try addText(s, r(x + 0.25, 6.05, cw - 0.3, 0.6),
            [TextSpec(text: fact.1, size: 14, color: Palette.inkSoft)], lineSpacing: 1.1)
    }
}

// ---- 3 · Big number: warming
try bigNumberSlide(slides[2],
    kickerText: "Global mean temperature · 2024",
    number: "+1.55 °C",
    numberColor: Palette.coral,
    context: "2024 was the warmest year on record — the first calendar year more than 1.5 °C above the pre-industrial baseline.",
    source: "SOURCE · WMO STATE OF THE GLOBAL CLIMATE 2024")

// ---- 4 · CO₂ bar chart
do {
    let s = slides[3]
    try s.setBackground(.solid(Palette.navy))
    try addText(s, r(1.0, 0.75, 11.0, 0.5), [kicker("Atmospheric CO₂ · Mauna Loa")])
    try addText(s, r(1.0, 1.2, 11.3, 0.9),
        [TextSpec(text: "The Keeling curve only knows one direction", size: 36, bold: true)])
    let data: [(String, Double)] = [
        ("1960", 316.9), ("1970", 325.7), ("1980", 338.8), ("1990", 354.4),
        ("2000", 369.7), ("2010", 390.1), ("2020", 414.2), ("2024", 424.6),
    ]
    let plotX = 1.0, plotW = 11.3, baseY = 6.15, maxBarH = 3.4
    let floorPPM = 290.0, ceilPPM = 430.0
    let barW = 0.95, slot = plotW / Double(data.count)
    for (i, point) in data.enumerated() {
        let x = plotX + Double(i) * slot + (slot - barW) / 2
        let h = maxBarH * (point.1 - floorPPM) / (ceilPPM - floorPPM)
        let isLast = i == data.count - 1
        try s.shapes.addShape(.roundedRectangle,
            frame: r(x, baseY - h, barW, h),
            fill: isLast ? .solid(Palette.coral)
                         : .gradient(GradientFill(from: Palette.amber, to: Color("D98A2B"))))
        try addText(s, r(x - 0.2, baseY - h - 0.42, barW + 0.4, 0.35),
            [TextSpec(text: String(Int(point.1.rounded())), size: 15, bold: true,
                      color: isLast ? Palette.coral : Palette.amber)], align: .center)
        try addText(s, r(x - 0.2, baseY + 0.12, barW + 0.4, 0.32),
            [TextSpec(text: point.0, size: 13, color: Palette.mist)], align: .center)
    }
    try s.shapes.addShape(.rectangle, frame: r(plotX, baseY, plotW, 0.02),
                          fill: .solid(Palette.mist))
    try addText(s, r(1.0, 6.75, 11.3, 0.4),
        [TextSpec(text: "Annual mean, parts per million · NOAA Global Monitoring Laboratory",
                  size: 12, color: Palette.mist)])
}

// ---- 5 · Warming stripes
do {
    let s = slides[4]
    try s.setBackground(.solid(Palette.navyDeep))
    // Stylized 1850–2024 anomaly series (°C vs 1961–1990-ish baseline).
    func anomaly(_ year: Int) -> Double {
        let t = Double(year)
        switch year {
        case ..<1920: return -0.28 + 0.05 * sin(t / 9)
        case ..<1945: return -0.28 + (t - 1920) * 0.014
        case ..<1975: return 0.02 + 0.05 * sin(t / 6) - 0.04
        default: return 0.0 + (t - 1975) * 0.0195 + 0.04 * sin(t / 4)
        }
    }
    let years = Array(1850...2024)
    let stripeW = W / Double(years.count)
    for (i, year) in years.enumerated() {
        let a = anomaly(year)
        let idx = max(0, min(Palette.stripes.count - 1,
                             Int(((a + 0.65) / 2.25) * Double(Palette.stripes.count))))
        try s.shapes.addShape(.rectangle,
            frame: Rect(x: .inches(Double(i) * stripeW), y: .zero,
                        width: .inches(stripeW + 0.005), height: .inches(H)),
            fill: .solid(Palette.stripes[idx]))
    }
    // Scrim + caption.
    try s.shapes.addShape(.rectangle, frame: r(0, 5.5, W, 2.0),
        fill: .gradient(GradientFill(stops: [
            GradientStop(position: 0, color: Palette.navyDeep, alpha: 0),
            GradientStop(position: 1, color: Palette.navyDeep, alpha: 0.85),
        ], angleDegrees: 90)))
    try addText(s, r(1.0, 5.95, 11.3, 0.8),
        [TextSpec(text: "175 years, one stripe each", size: 34, bold: true)])
    try addText(s, r(1.0, 6.75, 11.3, 0.45),
        [TextSpec(text: "After Ed Hawkins' climate stripes · blue = cooler than baseline, red = warmer",
                  size: 13, color: Palette.mist)])
}

// ---- 6 · Emissions by sector
do {
    let s = slides[5]
    try s.setBackground(.solid(Palette.paper))
    try addText(s, r(1.0, 0.8, 11.0, 0.5), [kicker("Global greenhouse emissions · 2019", color: Palette.coral)])
    try addText(s, r(1.0, 1.25, 11.3, 0.9),
        [TextSpec(text: "Where it all comes from", size: 36, bold: true, color: Palette.ink)])
    let sectors: [(String, Double, Color)] = [
        ("Energy supply", 34, Palette.coral),
        ("Industry", 24, Palette.amber),
        ("Agriculture, forestry & land", 22, Palette.teal),
        ("Transport", 15, Color("5B9BD5")),
        ("Buildings", 6, Palette.mist),
    ]
    let labelW = 3.6, barX = 1.0 + labelW + 0.2, barMaxW = 6.6, rowH = 0.62, gap = 0.28
    for (i, sector) in sectors.enumerated() {
        let y = 2.5 + Double(i) * (rowH + gap)
        try addText(s, r(1.0, y + 0.08, labelW, rowH),
            [TextSpec(text: sector.0, size: 17, bold: true, color: Palette.ink)])
        try s.shapes.addShape(.roundedRectangle,
            frame: r(barX, y, barMaxW * sector.1 / 34.0, rowH),
            fill: .solid(sector.2))
        try addText(s, r(barX + barMaxW * sector.1 / 34.0 + 0.15, y + 0.05, 1.0, rowH),
            [TextSpec(text: "\(Int(sector.1))%", size: 20, bold: true, color: Palette.ink)])
    }
    try addText(s, r(1.0, 7.0, 11.3, 0.35),
        [TextSpec(text: "Share of global net anthropogenic GHG emissions · IPCC AR6 WGIII",
                  size: 12, color: Palette.inkSoft)])
}

// ---- 7 · Divider: Impacts
try sectionDivider(slides[6], index: "02", word: "Impacts")

// ---- 8 · Sea level
try bigNumberSlide(slides[7],
    kickerText: "Global mean sea level · satellite era",
    number: "+10.5 cm",
    numberColor: Palette.teal,
    context: "Since 1993 — and the rate has more than doubled, from 2.1 mm per year to about 4.5 mm per year today.",
    source: "SOURCE · NASA SEA LEVEL CHANGE PORTAL / AVISO ALTIMETRY")

// ---- 9 · Extreme weather cards
do {
    let s = slides[8]
    try s.setBackground(.solid(Palette.paper))
    try addText(s, r(1.0, 0.85, 11.0, 0.5), [kicker("Loaded dice", color: Palette.coral)])
    try addText(s, r(1.0, 1.3, 11.3, 0.9),
        [TextSpec(text: "Extremes are the new normal", size: 36, bold: true, color: Palette.ink)])
    try cardRow(s, cards: [
        Card(emoji: "🌡️", title: "Heatwaves",
             body: "Events like the 2021 Pacific-Northwest heat dome were made ~150× more likely by warming."),
        Card(emoji: "🌊", title: "Flooding rains",
             body: "Warmer air holds ~7% more moisture per degree — downpours land harder everywhere."),
        Card(emoji: "🔥", title: "Fire weather",
             body: "The global fire-weather season has lengthened by roughly two weeks since 1979."),
    ], top: 2.55, cardH: 3.6)
    try addText(s, r(1.0, 6.5, 11.3, 0.35),
        [TextSpec(text: "Attribution: World Weather Attribution · Clausius-Clapeyron ≈ 7%/°C · Jolly et al. 2015",
                  size: 11, color: Palette.inkSoft)])
}

// ---- 10 · Arctic ice
try bigNumberSlide(slides[9],
    kickerText: "Arctic sea ice · September minimum",
    number: "−12.2%",
    numberColor: Palette.mist,
    context: "Per decade since 1979. The Arctic has lost an area of summer ice roughly the size of Alaska and Texas combined.",
    source: "SOURCE · NSIDC / NASA SATELLITE RECORD")

// ---- 11 · Divider: Solutions
try sectionDivider(slides[10], index: "03", word: "Solutions")

// ---- 12 · Solar cost decline
do {
    let s = slides[11]
    try s.setBackground(.solid(Palette.navy))
    try addText(s, r(1.0, 0.75, 11.0, 0.5), [kicker("Levelized cost of solar power")])
    try addText(s, r(1.0, 1.2, 11.3, 0.9),
        [TextSpec(text: "Clean energy got absurdly cheap", size: 36, bold: true)])
    let costs: [(String, Double)] = [
        ("2010", 0.417), ("2012", 0.286), ("2014", 0.175), ("2016", 0.114),
        ("2018", 0.085), ("2020", 0.057), ("2023", 0.044),
    ]
    let plotX = 1.0, plotW = 11.3, baseY = 6.1, maxBarH = 3.3
    let slot = plotW / Double(costs.count), barW = 1.05
    for (i, point) in costs.enumerated() {
        let x = plotX + Double(i) * slot + (slot - barW) / 2
        let h = maxBarH * point.1 / 0.417
        let isLast = i == costs.count - 1
        try s.shapes.addShape(.roundedRectangle,
            frame: r(x, baseY - h, barW, h),
            fill: isLast ? .solid(Palette.teal) : .solidAlpha(Palette.teal, 0.45))
        try addText(s, r(x - 0.25, baseY - h - 0.42, barW + 0.5, 0.35),
            [TextSpec(text: String(format: "%.0f¢", point.1 * 100), size: 15, bold: true,
                      color: isLast ? .white : Palette.mist)], align: .center)
        try addText(s, r(x - 0.25, baseY + 0.12, barW + 0.5, 0.32),
            [TextSpec(text: point.0, size: 13, color: Palette.mist)], align: .center)
    }
    try s.shapes.addShape(.rectangle, frame: r(plotX, baseY, plotW, 0.02),
                          fill: .solid(Palette.mist))
    try addText(s, r(1.0, 6.75, 11.3, 0.4),
        [TextSpec(text: "Global average $/kWh, utility-scale PV — down ~90% in 13 years · IRENA",
                  size: 12, color: Palette.mist)])
}

// ---- 13 · Solutions grid
do {
    let s = slides[12]
    try s.setBackground(.solid(Palette.paper))
    try addText(s, r(1.0, 0.75, 11.0, 0.5), [kicker("The playbook exists", color: Palette.coral)])
    try addText(s, r(1.0, 1.2, 11.3, 0.8),
        [TextSpec(text: "Four levers move most of the needle", size: 36, bold: true, color: Palette.ink)])
    try cardRow(s, cards: [
        Card(emoji: "⚡️", title: "Clean power",
             body: "Wind + solar already the cheapest new electricity in most of the world."),
        Card(emoji: "🚗", title: "Electrify",
             body: "Cars, heat, industry — swap combustion for electrons on a clean grid."),
    ], top: 2.3, cardH: 2.15, compact: true)
    try cardRow(s, cards: [
        Card(emoji: "🌲", title: "Protect nature",
             body: "Forests, wetlands and soils absorb about a third of what we emit."),
        Card(emoji: "🏢", title: "Waste less",
             body: "Efficiency is the quiet giant — the cheapest ton of CO₂ is the one never made."),
    ], top: 4.75, cardH: 2.15, compact: true)
}

// ---- 14 · Statement
do {
    let s = slides[13]
    try s.setBackground(.gradient(GradientFill(stops: [
        GradientStop(position: 0, color: Color("0E3A38")),
        GradientStop(position: 1, color: Palette.navyDeep),
    ], angleDegrees: 115)))
    try accentBar(s, x: 1.04, y: 2.35, w: 1.2, color: Palette.amber)
    try addText(s, r(1.0, 2.6, 11.4, 2.6), [
        TextSpec(text: "Every tenth of a", size: 66, bold: true),
        TextSpec(text: "degree matters.", size: 66, bold: true, color: Palette.amber),
    ], lineSpacing: 1.02)
    try addText(s, r(1.0, 5.35, 10.5, 1.0),
        [TextSpec(text: "Emissions cut this decade set the trajectory for centuries of sea level, harvests, and heat.",
                  size: 22, color: Palette.mist)], lineSpacing: 1.2)
}

// ---- 15 · Close
do {
    let s = slides[14]
    try s.setBackground(.solid(Palette.navyDeep))
    try s.shapes.addShape(.rectangle, frame: r(0, 3.62, W, 0.05),
        fill: .gradient(GradientFill(stops: [
            GradientStop(position: 0, color: Palette.coral),
            GradientStop(position: 0.5, color: Palette.amber),
            GradientStop(position: 1, color: Palette.teal),
        ], angleDegrees: 0)))
    try addText(s, r(1.0, 2.35, 11.4, 1.2),
        [TextSpec(text: "The window is still open.", size: 54, bold: true)], align: .center)
    try addText(s, r(1.0, 4.0, 11.4, 0.6),
        [TextSpec(text: "Act like it.", size: 26, color: Palette.amber, tracking: 1)],
        align: .center)
    try addText(s, r(1.0, 6.55, 11.4, 0.6), [
        TextSpec(text: "Sources: WMO · NOAA GML · NASA · NSIDC · IPCC AR6 · IRENA · World Weather Attribution",
                 size: 11, color: Palette.mist),
        TextSpec(text: "Deck generated by Rostrum — pure Swift, zero dependencies", size: 11,
                 color: Palette.inkSoft, spaceBefore: 4),
    ], align: .center)
}

// MARK: - Save

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "climate.pptx"
try deck.save(to: URL(filePath: outputPath))
print("wrote \(outputPath): \(deck.slides.count) slides")
