import Foundation
import Rostrum

/// Stable entry points for exercising Rostrum without a provider account.
/// Each entry creates real document artifacts and verifies the reopened file.
public enum LibraryDemoID: String, CaseIterable, Codable, Sendable, Identifiable {
    case slides, layouts, shapes, fillsAndLines, text, fontsAndFitting, paragraphLayout, tabLayout, pictures
    case tableStructure, tableStyles, tableAppearance, charts, chartEditing, smartArt
    case notes, comments, sections, slideImport, theme, templates, design
    case mediaAndAttachments, package, extractionAndRendering
    public var id: String { rawValue }
}

public enum LibraryLabInput: String, Codable, Sendable {
    case text, accent, sampleSize, alternative
}

public struct LibraryLabOptions: Sendable, Codable, Equatable {
    public var text: String
    public var accentHex: String
    public var sampleSize: Int
    public var alternative: Bool

    public init(text: String = "Rostrum in Lectern", accentHex: String = "276D89",
                sampleSize: Int = 4, alternative: Bool = false) {
        self.text = text
        self.accentHex = accentHex
        self.sampleSize = sampleSize
        self.alternative = alternative
    }
}

public struct LibraryLabRecipe: Sendable, Identifiable {
    public let id: LibraryDemoID
    public let title: String
    public let summary: String
    /// Concrete public operations invoked by this recipe, also used by the
    /// coverage ledger so the catalog cannot quietly become a static gallery.
    public let operations: [String]
    public let limitations: [String]
    public let inputs: [LibraryLabInput]
    public let alternativeLabel: String?

    init(_ id: LibraryDemoID, title: String, summary: String, operations: [String],
         limitations: [String] = [], inputs: [LibraryLabInput] = [], alternativeLabel: String? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.operations = operations
        self.limitations = limitations
        self.inputs = inputs
        self.alternativeLabel = alternativeLabel
    }
}

public struct LibraryLabCheck: Sendable, Codable, Equatable {
    public let name: String
    public let passed: Bool
    public let detail: String

    init(_ name: String, _ passed: Bool, _ detail: String) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}

/// Stays inside the synchronous recipe runner. A mutable Presentation and its
/// validation closure never cross an actor boundary.
struct LibraryLabDraft {
    let deck: Presentation
    var before: Data? = nil
    var checks: [LibraryLabCheck] = []
    var extraFiles: [String: Data] = [:]
    var verify: (Presentation) throws -> [LibraryLabCheck] = { _ in [] }
}

enum LibraryLabSupport {
    static let pixels = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAG0lEQVR4nGP4z8DwH4SRIJoAlA8EDA0gjCEAAE9EIeGwsrFwAAAAAElFTkSuQmCC")!

    static func deck(title: String) throws -> Presentation {
        let deck = try Presentation()
        deck.documentProperties.title = title
        deck.documentProperties.author = "Lectern Library Lab"
        deck.documentProperties.created = Date(timeIntervalSince1970: 0)
        deck.documentProperties.modified = Date(timeIntervalSince1970: 0)
        return deck
    }

    static func frame(_ x: Double = 1, _ y: Double = 1, _ width: Double = 10,
                      _ height: Double = 5) -> Rect {
        Rect(x: .inches(x), y: .inches(y), width: .inches(width), height: .inches(height))
    }

    static func text(_ value: String, on slide: Slide, frame: Rect? = nil) throws {
        let shape = try slide.shapes.addTextBox(frame ?? self.frame(0.5, 0.2, 12, 0.6))
        shape.textFrame?.text = value
    }
}
