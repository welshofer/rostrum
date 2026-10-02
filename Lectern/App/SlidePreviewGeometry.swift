import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import CoreGraphics

/// Read the root SVG's intrinsic size without parsing embedded fonts/images.
/// Shared by live previews and snapshots so their viewports agree.
struct SlidePreviewGeometry: Equatable {
    let width: Double
    let height: Double
    var aspectRatio: Double { width / height }

    init?(svg: String) {
        let root = SVGRootDimensions()
        let parser = XMLParser(data: Data(svg.utf8.prefix(32_768)))
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = root
        _ = parser.parse() // The delegate stops immediately after the root tag.
        guard let size = root.size, (size.0 / size.1).isFinite,
              (1 / 4096.0...4096).contains(size.0 / size.1) else { return nil }
        width = size.0; height = size.1
    }

    /// Bound both dimensions and total pixels, retaining the slide's ratio.
    /// Invalid/extreme geometry is refused rather than allocated or clipped.
    func snapshotSize(pixelWidth: CGFloat) -> CGSize? {
        guard pixelWidth.isFinite, pixelWidth > 0, aspectRatio.isFinite,
              aspectRatio >= 1 / 4096.0, aspectRatio <= 4096 else { return nil }
        var w = min(Double(pixelWidth), 4096)
        var h = w / aspectRatio
        let reduction = min(1, 4096 / max(w, h), sqrt(4_194_304 / (w * h)))
        w *= reduction; h *= reduction
        guard w >= 0.5, h >= 0.5 else { return nil }
        // Rounding both axes up can cross the total-pixel ceiling after the
        // continuous scale above (for example a 2503:10000 portrait slide).
        return CGSize(width: max(1, w.rounded(.down)), height: max(1, h.rounded(.down)))
    }
}

private final class SVGRootDimensions: NSObject, XMLParserDelegate {
    var size: (Double, Double)?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String]) {
        defer { parser.abortParsing() }
        guard elementName == "svg", namespaceURI == nil || namespaceURI == "" || namespaceURI == "http://www.w3.org/2000/svg" else { return }
        if let width = Self.length(attributes["width"]), let height = Self.length(attributes["height"]) {
            size = (width, height)
        } else if let raw = attributes["viewBox"] {
            let tokens = raw.split { $0.isWhitespace || $0 == "," }
            guard tokens.count == 4 else { return }
            let values = tokens.compactMap { Double($0) }
            guard values.count == 4, values.allSatisfy(\.isFinite), values[2] > 0, values[3] > 0 else { return }
            size = (values[2], values[3])
        }
    }

    private static func length(_ value: String?) -> Double? {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        var scale = 1.0
        for (suffix, factor) in [("px", 1.0), ("pt", 96.0 / 72), ("pc", 16), ("in", 96),
                                 ("cm", 96 / 2.54), ("mm", 96 / 25.4), ("Q", 96 / 101.6)] {
            if value.hasSuffix(suffix) { value.removeLast(suffix.count); scale = factor; break }
        }
        guard let number = Double(value), number.isFinite, number > 0 else { return nil }
        let result = number * scale
        return result.isFinite ? result : nil
    }
}
