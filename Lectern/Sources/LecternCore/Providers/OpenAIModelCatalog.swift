import Foundation

/// OpenAI catalog verified against the model documentation on 2026-10-02.
public enum TextStrength: String, CaseIterable, Sendable, Codable {
    case astra, sol, luna
    public var modelID: String {
        switch self {
        case .astra: "gpt-6-astra"
        case .sol: "gpt-6.1-sol"
        case .luna: "gpt-6-luna"
        }
    }
    public var label: String {
        switch self {
        case .astra: "Astra — strongest"
        case .sol: "Sol — balanced"
        case .luna: "Luna — fastest"
        }
    }
    public var efforts: [ReasoningEffort] {
        ReasoningEffort.allCases.filter { $0 != .none || self == .luna }
    }
    public func supported(_ effort: ReasoningEffort) -> ReasoningEffort {
        efforts.contains(effort) ? effort : .low
    }
    public static func resolve(modelID: String?) -> Self {
        allCases.first { $0.modelID == modelID } ?? .sol
    }
}

public enum ReasoningEffort: String, CaseIterable, Sendable, Codable {
    case none, low, medium, high, xhigh, max
    public var label: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .xhigh: "Extra high"
        case .max: "Maximum"
        }
    }
    /// Responses output tokens include reasoning as well as the final deck.
    var tokenAllowance: Int {
        switch self {
        case .none: 0
        case .low: 8_192
        case .medium: 16_384
        case .high: 32_768
        case .xhigh: 49_152
        case .max: 65_536
        }
    }
    var timeout: TimeInterval {
        switch self {
        case .none, .low, .medium: 300
        case .high, .xhigh, .max: 900
        }
    }
}

public enum ImageModel: String, CaseIterable, Sendable, Codable {
    case flare = "gpt-image-2.5-flare"
    case sunburst = "gpt-image-2.5-sunburst"
    public var label: String {
        switch self {
        case .flare: "Flare — faster"
        case .sunburst: "Sunburst — highest fidelity"
        }
    }
}

public enum ImageQuality: String, CaseIterable, Sendable, Codable {
    case auto, low, medium, high, xhigh, max
    public var label: String {
        self == .auto ? "Automatic" : (self == .xhigh ? "Extra high" : (self == .max ? "Maximum" : rawValue.capitalized))
    }
}
