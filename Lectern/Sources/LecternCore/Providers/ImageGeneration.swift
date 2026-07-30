import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

typealias HTTPRequestSender = @Sendable (URLRequest) async throws -> (Data, URLResponse)

/// Optional image generators. A deck is fully valid without one; when the user
/// supplies an image key, slides whose model added an `ImageBrief` get an on-brand
/// illustration (invariant I1: the key lives only in the Keychain).
public enum ImageProviderID: String, Sendable, CaseIterable, Codable {
    case gemini      // Gemini 3.1 Flash Image ("Nano Banana 2")
    case openAI      // gpt-image-1

    public var label: String {
        switch self {
        case .gemini: "Gemini (Nano Banana 2)"
        case .openAI: "OpenAI Images"
        }
    }
    public var defaultModel: String {
        switch self {
        case .gemini: "gemini-3.1-flash-image"
        case .openAI: "gpt-image-1"
        }
    }

    /// Gemini image quotas are sensitive to request bursts. Keep its calls
    /// serialized while allowing providers with independent request capacity to
    /// render several bespoke images in parallel.
    public var maximumConcurrentRequests: Int {
        switch self {
        case .gemini: 1
        case .openAI: 4
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
        let key = try normalizedKey(apiKey)
        switch id {
        case .gemini: return GeminiImageProvider(apiKey: key, model: model ?? id.defaultModel)
        case .openAI: return OpenAIImageProvider(apiKey: key, model: model ?? id.defaultModel)
        }
    }

    /// Confirms both authentication and access to the selected image model.
    public static func validate(id: ImageProviderID, apiKey: String?, model: String? = nil) async throws {
        let key = try normalizedKey(apiKey)
        switch id {
        case .gemini:
            try await GeminiImageProvider(apiKey: key, model: model ?? id.defaultModel).validate()
        case .openAI:
            try await OpenAIImageProvider(apiKey: key, model: model ?? id.defaultModel).validate()
        }
    }

    private static func normalizedKey(_ apiKey: String?) throws -> String {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw LecternError.noKey
        }
        return key
    }
}

/// Turns the selected style's visual metadata into image-only art direction.
/// Deck/UI prose is intentionally excluded because typography and component
/// guidance conflict with the requirement that generated images contain no text.
public enum ImageStyleDirective {
    public static func from(style: Style) -> String {
        var parts: [String] = []
        if let vibe = style.vibe { parts.append("\(vibe.lowercased()) editorial imagery") }
        if style.theme != .unknown { parts.append("\(style.theme.rawValue) overall tonality") }
        if !style.swatches.isEmpty { parts.append("color palette " + style.swatches.prefix(5).joined(separator: ", ")) }
        parts.append("use the palette through lighting, materials, atmosphere, and background")
        parts.append("premium cohesive art direction; no typography, letters, numbers, interface chrome, charts, logos, or watermarks")
        return "ART DIRECTION — " + parts.joined(separator: "; ") + "."
    }
}
