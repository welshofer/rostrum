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

/// What the image has to *do* on the slide. Aspect ratio was standing in for
/// this, and the two are not the same thing: a 16:9 full-bleed background is
/// scrimmed and carries the title over it, so a strong central subject is
/// actively wrong — it fights the text and then gets flattened by the scrim.
/// A side panel is the opposite: it is the hero, seen at full contrast, and
/// wants a close, singular subject. Asking for "one clear focal hierarchy" in
/// both cases produced weak backgrounds and timid panels.
public enum ImageRole: Sendable {
    case background   // full-bleed, scrimmed, text on top
    case panel        // framed on one side, shown at full strength

    public init(placement: ImagePlacement) {
        switch placement {
        case .fullBleed: self = .background
        case .sidePanel, .none: self = .panel
        }
    }

    /// Role-specific direction. This is the part that was missing.
    public var direction: String {
        switch self {
        case .background:
            return """
            ROLE — this is a full-bleed slide BACKGROUND. Large type sits on top of it and \
            a translucent scrim is laid over it, so it must read as atmosphere, not as a \
            photograph with a subject. Treat the subject as texture: far away, abstracted, \
            or heavily out of focus. Low local contrast and a narrow tonal range so text \
            stays legible everywhere. No single dominant object, no face, no hard bright \
            highlight, nothing centred. Push all incident away from the middle and the \
            upper-left; keep those regions calm and near-empty. Depth, gradient and \
            atmosphere over detail.
            """
        case .panel:
            return """
            ROLE — this is the HERO image on the slide, shown sharp and uncropped in a \
            framed panel beside the text. It carries the slide's idea on its own, so it \
            should be strong and specific: one subject, close in, deliberate lighting with \
            real direction, shallow depth of field, rich material detail. Commissioned \
            editorial photography or a finished illustration — never a stock-photo cliché, \
            never a vague abstract wash, never a montage of small elements.
            """
        }
    }
}

public protocol ImageProvider: Sendable {
    var id: ImageProviderID { get }
    /// Returns encoded image bytes (PNG/JPEG). `style` is the on-brand art
    /// direction prepended to `prompt`; `role` says what job the image does on
    /// the slide, which decides composition far more than the aspect does.
    func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data
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
    /// The complete prompt sent to any image model: brand direction, what the
    /// image has to do on the slide, the subject, and the frame. Shared so the
    /// two providers cannot drift — OpenAI used to send only style + subject,
    /// which is why its output read flatter than Gemini's.
    public static func compose(style: String?,
                               role: ImageRole,
                               subject: String,
                               aspect: ImageAspect) -> String {
        [style, role.direction, "SUBJECT — \(subject)", frame(for: aspect)]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }

    /// Framing only. Composition intent belongs to the role, not the ratio.
    static func frame(for aspect: ImageAspect) -> String {
        "FRAME — \(aspect.rawValue). Compose for this ratio edge to edge; no letterboxing, "
            + "no borders, no padding, no drop shadow, and nothing important within 5% of any edge."
    }

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
