import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Validated dimensions shared by preview records, layout, and rasterization.
public struct SlidePreviewGeometry: Sendable, Equatable {
    public let width: Double
    public let height: Double
    public var aspectRatio: Double { width / height }
    public static let widescreen = SlidePreviewGeometry(width: 16, height: 9)

    public init(width: Double, height: Double) {
        if width.isFinite, height.isFinite, width > 0, height > 0,
           (width / height).isFinite, width / height > 0 {
            self.width = width
            self.height = height
        } else {
            self.width = 16
            self.height = 9
        }
    }

    public init(svg: String) {
        let reader = SVGRootSizeReader()
        // Only the root is needed; embedded image payloads need not be copied or parsed.
        let parser = XMLParser(data: Data(svg.prefix(4096).utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = reader
        _ = parser.parse()
        self = reader.geometry ?? .widescreen
    }

    /// Bound bitmap allocation while preserving the original ratio.
    public func fitted(toWidth requested: Double, maximumDimension: Double = 4096) -> Self {
        let limit = maximumDimension.isFinite && maximumDimension >= 1 ? maximumDimension : 4096
        var width = min(max(1, requested.isFinite ? requested : 640), limit)
        var height = width / aspectRatio
        if height > limit {
            height = limit
            width = height * aspectRatio
        }
        return Self(width: width, height: height)
    }
}

private final class SVGRootSizeReader: NSObject, XMLParserDelegate {
    var geometry: SlidePreviewGeometry?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        defer { parser.abortParsing() }
        guard name == "svg" else { return }
        if let viewBox = attributes["viewBox"] {
            let fields = viewBox.split { $0.isWhitespace || $0 == "," }
            let values = fields.compactMap { Double($0) }
            if fields.count == 4, values.count == 4, values.allSatisfy(\.isFinite), values[2] > 0, values[3] > 0 {
                geometry = SlidePreviewGeometry(width: values[2], height: values[3])
                return
            }
        }
        func pixels(_ value: String?) -> Double? {
            guard let value else { return nil }
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(text.hasSuffix("px") ? String(text.dropLast(2)) : text)
        }
        if let width = pixels(attributes["width"]), let height = pixels(attributes["height"]) {
            geometry = SlidePreviewGeometry(width: width, height: height)
        }
    }
}
