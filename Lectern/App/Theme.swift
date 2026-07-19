import SwiftUI
import ImageIO
import LecternCore

extension Color {
    /// Parse a `#rgb` / `#rrggbb` / `#rrggbbaa` hex string.
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).lowercased()
        guard let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch s.count {
        case 3: r = Double((v >> 8) & 0xf) / 15; g = Double((v >> 4) & 0xf) / 15; b = Double(v & 0xf) / 15; a = 1
        case 6: r = Double((v >> 16) & 0xff) / 255; g = Double((v >> 8) & 0xff) / 255; b = Double(v & 0xff) / 255; a = 1
        case 8: r = Double((v >> 24) & 0xff) / 255; g = Double((v >> 16) & 0xff) / 255; b = Double((v >> 8) & 0xff) / 255; a = Double(v & 0xff) / 255
        default: return nil
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

extension Style {
    var swatchColors: [Color] { swatches.compactMap { Color(hex: $0) } }
}

extension ProviderID {
    /// Human label (`.capitalized` mangles "openAI").
    var label: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openAI: "OpenAI"
        case .gemini: "Gemini"
        case .custom: "Custom"
        }
    }
}

/// A concise label for a model id, e.g. `claude-opus-4-8` → "Opus 4.8",
/// `claude-haiku-4-5-20251001` → "Haiku 4.5".
func modelLabel(_ id: String) -> String {
    var s = id
    if s.hasPrefix("claude-") { s.removeFirst("claude-".count) }
    if let r = s.range(of: #"-\d{6,8}$"#, options: .regularExpression) { s.removeSubrange(r) }  // drop date stamp
    var name: [String] = [], nums: [String] = []
    for part in s.split(separator: "-") {
        if part.allSatisfy(\.isNumber) { nums.append(String(part)) }
        else { name.append(part.prefix(1).uppercased() + part.dropFirst()) }
    }
    return [name.joined(separator: " "), nums.joined(separator: ".")].filter { !$0.isEmpty }.joined(separator: " ")
}

/// Loads a downsampled thumbnail off-main via ImageIO — so a 150-card grid of
/// full-res hero JPGs stays smooth (I6). Falls back to a palette-tinted panel.
struct ThumbImage: View {
    let url: URL?
    var maxPixel: CGFloat = 640
    var fallback: [Color] = []
    @State private var image: Image?

    var body: some View {
        ZStack {
            if let image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: fallback.isEmpty ? [.gray.opacity(0.3), .gray.opacity(0.15)] : fallback,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .task(id: url?.path) { await load() }
    }

    private func load() async {
        guard let url else { image = nil; return }
        let px = maxPixel
        let loaded = await Task.detached(priority: .utility) { () -> Image? in
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: px,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return Image(decorative: cg, scale: 1)
        }.value
        withAnimation(.easeOut(duration: 0.2)) { image = loaded }
    }
}
