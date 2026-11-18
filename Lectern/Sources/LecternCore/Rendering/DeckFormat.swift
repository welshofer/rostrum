import Foundation

/// File-format policy lives here; UI and storage never invent their own list.
public enum DeckFormat: String, Codable, Sendable, CaseIterable, Identifiable {
    case powerPoint = "pptx"
    case keynoteInterchange = "keyx"
    public var id: String { rawValue }
    public var fileExtension: String { rawValue }
    public var label: String {
        switch self {
        case .powerPoint: "PowerPoint (.pptx)"
        case .keynoteInterchange: "Keynote Interchange (.keyx)"
        }
    }
    public var applicationName: String {
        switch self { case .powerPoint: "PowerPoint"; case .keynoteInterchange: "Keynote" }
    }
    public static let inspectionExtensions = ["pptx", "potx", "ppsx", "keyx"]
    public static let templateExtensions = ["potx", "pptx", "keyx"]
    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "pptx", "potx", "ppsx": self = .powerPoint
        case "keyx": self = .keynoteInterchange
        default: return nil
        }
    }
    public init?(url: URL) { self.init(fileExtension: url.pathExtension) }
}

public extension DeckResult {
    var format: DeckFormat { DeckFormat(url: url) ?? .powerPoint }
}

public extension DeckInspection {
    var format: DeckFormat { DeckFormat(url: fileURL) ?? .powerPoint }
}

public extension DeckFile {
    var format: DeckFormat { DeckFormat(url: url) ?? .powerPoint }
}
