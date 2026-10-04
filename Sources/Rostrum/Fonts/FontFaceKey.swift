import Foundation

/// A case-insensitive family and an explicit style. No platform substitution.
public struct FontFaceKey: Hashable, Sendable {
    public let family: String
    public let bold: Bool
    public let italic: Bool

    public init(family: String, bold: Bool = false, italic: Bool = false) {
        self.family = family.lowercased()
        self.bold = bold
        self.italic = italic
    }
}
