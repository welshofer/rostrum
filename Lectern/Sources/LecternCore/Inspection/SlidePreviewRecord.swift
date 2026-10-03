import Foundation

/// A preview keeps its original one-based slide number even if rendering fails.
public struct SlidePreviewRecord: Sendable, Identifiable {
    public var id: Int { number }
    public let number: Int
    public let title: String
    public let svg: String?
    public let warnings: [String]
    public let geometry: SlidePreviewGeometry

    public init(number: Int, title: String, svg: String?, geometry: SlidePreviewGeometry? = nil, warnings: [String] = []) {
        self.number = number
        self.title = title
        self.svg = svg
        self.warnings = warnings
        self.geometry = geometry ?? svg.map { SlidePreviewGeometry(svg: $0) } ?? .widescreen
    }

    public func accessibilityLabel(total: Int) -> String {
        let base = "Slide \(number) of \(total)"
        let titled = title.isEmpty ? base : "\(base): \(title)"
        return svg == nil ? "\(titled). Preview unavailable" : titled + (warnings.isEmpty ? "" : ". Preview has limitations: " + warnings.joined(separator: " "))
    }

    /// Compatibility surface for SVG consumers: failed slides still occupy a slot.
    public var displaySVG: String {
        if let svg { return svg }
        let size = geometry.fitted(toWidth: 640)
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(size.width)" height="\(size.height)" viewBox="0 0 \(size.width) \(size.height)">
          <rect width="100%" height="100%" fill="#EEEEEE"/>
          <text x="50%" y="50%" text-anchor="middle" font-family="sans-serif" font-size="24" fill="#444444">Preview unavailable</text>
        </svg>
        """
    }
}
