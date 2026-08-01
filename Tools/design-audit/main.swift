import Foundation
import Rostrum

// Audit every bundled style for the pairings the builders actually draw.
// Auto-contrasted pairings (textColor(on:)) are included as a regression net;
// the interesting ones are the FIXED colors a design.md supplies.
guard CommandLine.arguments.count >= 2 else {
    print("usage: design-audit <directory-of-design-md-files>")
    print("  Reports every text/fill pairing a builder draws that misses its")
    print("  WCAG threshold: 4.5:1 for body text, 3:1 for large text and for")
    print("  filled shapes a reader has to tell apart from the canvas.")
    exit(2)
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let files = (try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))
    .filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

struct Finding { let style: String; let pairing: String; let ratio: Double; let fg: String; let bg: String }
var findings: [Finding] = []
var latent: [Finding] = []
var checked = 0

/// Roles no builder currently draws on a card. Reported separately: they are a
/// warning for whoever draws them there first, not a defect in the catalog.
let notDrawnOnSurface: Set<String> = ["kicker", "caption", "display", "stat", "quote", "subhead", "title"]

for file in files {
    let slug = file.deletingPathExtension().lastPathComponent
    let deck = try Presentation()
    _ = try deck.applyDesign(contentsOf: file)
    let s = deck.style
    var pairs: [(String, Color, Color, Double)] = []

    // 1. Every text role, on both surfaces text is drawn on. Large display
    //    type gets WCAG's 3:1; the rest 4.5:1.
    for role in TypeRole.allCases {
        let t = s.type(role)
        let threshold = t.sizePt >= 24 ? 3.0 : 4.5
        pairs.append(("role \(role.rawValue) on background", t.color, s.background, threshold))
        // Cards carry heading and body only; the rest are latent.
        let name = notDrawnOnSurface.contains(role.rawValue)
            ? "latent: role \(role.rawValue) on surface"
            : "role \(role.rawValue) on surface"
        pairs.append((name, t.color, s.surface, threshold))
    }
    // 2. Filled shapes on the canvas: chart series and band blocks are the
    //    structure, so they need 3:1 against the background to read at all.
    for (i, c) in s.plotColors.prefix(6).enumerated() {
        pairs.append(("plot fill \(i + 1) on background", c, s.background, 3.0))
    }
    // Band fills are deliberately exempt: a band is a full-width block in a
    // contiguous stack, so its neighbours define its edges. See bandsSlide.
    // 3. Auto-contrasted pairings — a net, these should never fail.
    pairs.append(("text on accent-1 field", s.textColor(on: s.accent(1)), s.accent(1), 4.5))
    pairs.append(("table header text", s.textColor(on: s.primary), s.primary, 4.5))
    for n in 1...SlideCapacity.bands {
        pairs.append(("band label on its fill", s.textColor(on: s.accent(n)), s.accent(n), 4.5))
    }
    let band2 = s.primary.mixed(with: s.surface, amount: 0.90)
    pairs.append(("table banded row text", s.textColor(on: band2), band2, 4.5))
    pairs.append(("card text on surface", s.textColor(on: s.surface), s.surface, 4.5))

    for (name, fg, bg, threshold) in pairs {
        checked += 1
        let ratio = fg.contrastRatio(with: bg)
        if ratio < threshold {
            let finding = Finding(style: slug, pairing: name, ratio: ratio, fg: fg.hex, bg: bg.hex)
            if name.hasPrefix("latent:") { latent.append(finding) } else { findings.append(finding) }
        }
    }
}

print("styles: \(files.count)   pairings checked: \(checked)   failures: \(findings.count)\n")
if !latent.isEmpty {
    let byPairing = Dictionary(grouping: latent, by: \.pairing)
    print("latent (no builder draws these today): "
          + byPairing.map { "\($0.key.replacingOccurrences(of: "latent: ", with: "")) x\($0.value.count)" }
              .sorted().joined(separator: ", ") + "\n")
}
for (pairing, group) in Dictionary(grouping: findings, by: \.pairing).sorted(by: { $0.value.count > $1.value.count }) {
    print("\(pairing): \(group.count) styles")
    for f in group.sorted(by: { $0.ratio < $1.ratio }).prefix(3) {
        print(String(format: "    %-14@ %.2f:1  #%@ on #%@", f.style as NSString, f.ratio, f.fg, f.bg))
    }
}
print("\nstyles with at least one failure: \(Set(findings.map(\.style)).count) of \(files.count)")
exit(findings.isEmpty ? 0 : 1)
