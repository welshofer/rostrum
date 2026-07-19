import Foundation

/// Optional image generators. A deck is fully valid without one; when the user
/// supplies an image key, slides whose model added an `ImageBrief` get an on-brand
/// illustration (invariant I1: the key lives only in the Keychain).
public enum ImageProviderID: String, Sendable, CaseIterable, Codable {
    case gemini      // Gemini 2.5 Flash Image ("Nano Banana")
    case openAI      // gpt-image-1

    public var label: String {
        switch self {
        case .gemini: "Gemini (Nano Banana)"
        case .openAI: "OpenAI Images"
        }
    }
    public var defaultModel: String {
        switch self {
        case .gemini: "gemini-2.5-flash-image"
        case .openAI: "gpt-image-1"
        }
    }
}

public enum ImageAspect: String, Sendable, Codable {
    case wide = "16:9", standard = "4:3", square = "1:1", tall = "3:4", portrait = "9:16"

    public init(brief: String?) { self = brief.flatMap { ImageAspect(rawValue: $0) } ?? .standard }

    /// Nearest gpt-image-1 size.
    var openAISize: String {
        switch self {
        case .wide: "1536x1024"
        case .tall, .portrait: "1024x1536"
        case .standard, .square: "1024x1024"
        }
    }
}

public protocol ImageProvider: Sendable {
    var id: ImageProviderID { get }
    /// Returns encoded image bytes (PNG/JPEG). `style` is the on-brand art
    /// direction prepended to `prompt`.
    func image(prompt: String, style: String?, aspect: ImageAspect) async throws -> Data
}

public enum ImageProviderFactory {
    public static func make(id: ImageProviderID, apiKey: String?, model: String? = nil) throws -> any ImageProvider {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw LecternError.noKey
        }
        switch id {
        case .gemini: return GeminiImageProvider(apiKey: key, model: model ?? id.defaultModel)
        case .openAI: return OpenAIImageProvider(apiKey: key, model: model ?? id.defaultModel)
        }
    }
}

/// Distills a `design.md` into a concise art-direction line so generated imagery
/// matches the deck's visual language (palette, vibe, personality). Pure/testable.
public enum ImageStyleDirective {
    public static func from(style: Style, designText: String?) -> String {
        var parts: [String] = []
        if let vibe = style.vibe { parts.append("\(vibe.lowercased()) visual style") }
        if style.theme != .unknown { parts.append("\(style.theme.rawValue) theme") }
        if !style.swatches.isEmpty { parts.append("color palette " + style.swatches.prefix(5).joined(separator: ", ")) }
        if let text = designText, let personality = personality(text) { parts.append(personality) }
        parts.append("cohesive editorial art direction; absolutely no text, letters, logos, or watermarks in the image")
        return "ART DIRECTION — " + parts.joined(separator: "; ") + "."
    }

    /// The "Overall visual personality" sentence, if the design.md has one.
    private static func personality(_ text: String) -> String? {
        guard let r = text.range(of: "Overall visual personality", options: .caseInsensitive) else { return nil }
        let after = text[r.upperBound...].drop { $0 == ":" || $0 == " " || $0 == "\n" }
        let snippet = after.prefix(220).replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return snippet.isEmpty ? nil : snippet
    }
}
