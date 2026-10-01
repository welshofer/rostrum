import Foundation

/// Fractions inset from the original image's left, top, right and bottom
/// edges, before mapping the remaining source rectangle into the frame.
/// 0.25 trims one quarter of that edge; negative values add transparent space.
/// The original image bytes are never rewritten by a crop edit.
public struct PictureCrop: Equatable, Sendable {
    public var left: Double
    public var top: Double
    public var right: Double
    public var bottom: Double

    public init(left: Double = 0, top: Double = 0, right: Double = 0, bottom: Double = 0) {
        self.left = left; self.top = top; self.right = right; self.bottom = bottom
    }

    static func read(_ element: XML.Element?) -> PictureCrop {
        func fraction(_ name: String) -> Double {
            Double(element?.boundedInt(name, in: Int(Int32.min)...Int(Int32.max)) ?? 0) / 100000
        }
        return PictureCrop(left: fraction("l"), top: fraction("t"), right: fraction("r"), bottom: fraction("b"))
    }

    var valid: Bool {
        [left, top, right, bottom].allSatisfy { $0.isFinite && $0 * 100000 >= Double(Int32.min) && $0 * 100000 <= Double(Int32.max) }
            && 1 - left - right > 0 && 1 - top - bottom > 0
    }
}

public extension Picture {
    /// Authored source crop, or nil when no source rectangle is present.
    /// A pure read, including for images in unsupported formats.
    var crop: PictureCrop? {
        element.firstChild(named: "p:blipFill")?.firstChild(named: "a:srcRect").map(PictureCrop.read)
    }

    /// Set or clear the source crop. Rejects nonfinite values, values outside
    /// DrawingML's signed percentage range, and empty/inverted source areas.
    /// Negative insets are supported. Failure leaves the package unchanged.
    func setCrop(_ crop: PictureCrop?) throws {
        if let crop, !crop.valid { throw RostrumError.packageInvalid("picture crop must leave a positive source rectangle and contain bounded finite fractions") }
        if let crop {
            let quantized = PictureCrop(left: (crop.left * 100000).rounded() / 100000,
                top: (crop.top * 100000).rounded() / 100000,
                right: (crop.right * 100000).rounded() / 100000,
                bottom: (crop.bottom * 100000).rounded() / 100000)
            guard quantized.valid else { throw RostrumError.packageInvalid("picture crop rounds to an empty source rectangle") }
        }
        guard let fill = element.firstChild(named: "p:blipFill") else {
            throw RostrumError.packageInvalid("picture has no blip fill")
        }
        if let crop {
            let source = fill.getOrAddChild("a:srcRect", beforeAnyOf: ["a:tile", "a:stretch"])
            for (name, value) in [("l", crop.left), ("t", crop.top), ("r", crop.right), ("b", crop.bottom)] {
                source[attribute: name] = String(Int((value * 100000).rounded()))
            }
        } else { fill.removeChildren(named: "a:srcRect") }
        part.markDirty()
    }

    /// Replace this picture's embedded image while keeping its frame, crop,
    /// transforms, hyperlinks, effects and unknown XML. Shared images remain
    /// unchanged: only this picture gets a new relationship. Old relationships
    /// and media are retained because other XML may still reference them.
    /// PNG, JPEG and GIF are accepted; unsupported bytes throw atomically.
    /// Pictures with linked sources or retained Office SVG/image-layer source
    /// alternates are refused, because changing only their raster fallback
    /// would not replace the image Office displays.
    func replaceImage(_ data: Data) throws {
        guard let info = ImageSniffer.sniff(data), let package,
              let blip = element.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip") else {
            throw RostrumError.packageInvalid("picture replacement needs a package, blip and recognized PNG/JPEG/GIF data")
        }
        let relationshipsNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        var bindings = ["r": relationshipsNamespace]
        // Prefixes belong to namespace bindings, not to attribute spelling.
        // Resolve the blip's inherited declarations without parent pointers.
        var ancestors: [(XML.Element, [String: String])] = [(try part.dom(), bindings)]
        while let (node, inherited) = ancestors.popLast() {
            var current = inherited
            for attribute in node.attributes where attribute.name.hasPrefix("xmlns:") {
                current[String(attribute.name.dropFirst(6))] = attribute.value
            }
            if node === blip { bindings = current; break }
            for child in node.childElements { ancestors.append((child, current)) }
        }
        let linkedSource = blip.attributes.contains { attribute in
            let name = attribute.name.split(separator: ":", maxSplits: 1)
            return name.count == 2 && name[1] == "link" && bindings[String(name[0])] == relationshipsNamespace
        }
        var stack = [blip]
        while let node = stack.popLast() {
            let localName = node.name.split(separator: ":").last.map(String.init) ?? node.name
            guard !["svgBlip", "imgProps", "imgLayer"].contains(localName),
                  !(node === blip && linkedSource) else {
                throw RostrumError.packageInvalid("picture has an alternate SVG, image-layer or linked source; replacing only its raster fallback would be incomplete")
            }
            stack.append(contentsOf: node.childElements)
        }
        if imageData == data { return }
        let media = package.imagePart(for: data, info: info)
        let relationship = part.rels.add(type: RelType.image, target: part.uri.relativeReference(to: media.uri))
        blip[attribute: "r:embed"] = relationship
        part.markDirty()
    }
}

/// Shared source-to-destination mapping for picture shapes and image fills.
/// Values stay as Doubles until SVG emission; invalid file-supplied areas
/// yield no placement instead of division by zero, infinities or traps.
struct ImagePlacement {
    struct Rectangle {
        let x: Double, y: Double, width: Double, height: Double
    }
    let image: Rectangle
    let clip: Rectangle

    init?(fill: XML.Element, frame: (Int, Int, Int, Int)) {
        let crop = PictureCrop.read(fill.firstChild(named: "a:srcRect"))
        let destination = PictureCrop.read(fill.firstChild(named: "a:stretch")?.firstChild(named: "a:fillRect"))
        guard crop.valid, destination.valid, frame.2 > 0, frame.3 > 0 else { return nil }
        let x = Double(frame.0), y = Double(frame.1), width = Double(frame.2), height = Double(frame.3)
        let destX = x + width * destination.left, destY = y + height * destination.top
        let destWidth = width * (1 - destination.left - destination.right)
        let destHeight = height * (1 - destination.top - destination.bottom)
        let imageWidth = destWidth / (1 - crop.left - crop.right)
        let imageHeight = destHeight / (1 - crop.top - crop.bottom)
        image = Rectangle(x: destX - crop.left * imageWidth, y: destY - crop.top * imageHeight,
                          width: imageWidth, height: imageHeight)
        let clipX = max(x, destX), clipY = max(y, destY)
        clip = Rectangle(x: clipX, y: clipY, width: max(0, min(x + width, destX + destWidth) - clipX),
                         height: max(0, min(y + height, destY + destHeight) - clipY))
    }
}
