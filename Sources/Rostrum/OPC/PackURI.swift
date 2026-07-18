import Foundation

/// A pack URI — the absolute, `/`-rooted name of a part inside an OPC package,
/// e.g. `/ppt/slides/slide1.xml`.
///
/// Mirrors python-pptx's `PackURI` (a `str` subclass); in Swift it is a value
/// type with the derived-path conveniences the packaging layer needs.
public struct PackURI: Hashable, Sendable, CustomStringConvertible {
    public let value: String

    /// `value` must begin with "/". Constructing an invalid pack URI is a
    /// programmer error, not a recoverable condition.
    public init(_ value: String) {
        precondition(value.hasPrefix("/"), "PackURI must begin with '/': \(value)")
        self.value = value
    }

    /// The special URI of the content-types stream, which is *not* a part.
    public static let contentTypes = PackURI("/[Content_Types].xml")
    /// The package-level relationships part.
    public static let packageRels = PackURI("/_rels/.rels")

    /// "slide1.xml" for "/ppt/slides/slide1.xml".
    public var filename: String {
        String(value.split(separator: "/").last ?? "")
    }

    /// Lowercased extension without the dot: "xml", "png", "rels". Empty if none.
    public var ext: String {
        guard let dot = filename.lastIndex(of: "."), dot != filename.startIndex else { return "" }
        return String(filename[filename.index(after: dot)...]).lowercased()
    }

    /// "/ppt/slides" for "/ppt/slides/slide1.xml"; "/" for a root-level part.
    public var baseURI: String {
        let comps = value.split(separator: "/").dropLast()
        return comps.isEmpty ? "/" : "/" + comps.joined(separator: "/")
    }

    /// The URI of this part's relationships part:
    /// "/ppt/slides/slide1.xml" → "/ppt/slides/_rels/slide1.xml.rels".
    /// For the package root, use `PackURI.packageRels`.
    public var relsURI: PackURI {
        let base = baseURI == "/" ? "" : baseURI
        return PackURI("\(base)/_rels/\(filename).rels")
    }

    /// The zip member name: the pack URI without its leading slash.
    public var memberName: String {
        String(value.dropFirst())
    }

    /// Resolve a relationship target against a source part's base URI.
    /// Handles "./", "../" and absolute ("/…") targets.
    ///
    ///     PackURI.resolve(target: "../slideLayouts/slideLayout1.xml",
    ///                     relativeTo: "/ppt/slideMasters")
    ///     // → /ppt/slideLayouts/slideLayout1.xml
    public static func resolve(target: String, relativeTo baseURI: String) -> PackURI {
        if target.hasPrefix("/") { return PackURI(target) }
        var stack = baseURI.split(separator: "/").map(String.init)
        for segment in target.split(separator: "/") {
            switch segment {
            case ".": continue
            case "..": if !stack.isEmpty { stack.removeLast() }
            default: stack.append(String(segment))
            }
        }
        return PackURI("/" + stack.joined(separator: "/"))
    }

    /// Express `other` relative to this part's base URI, for writing
    /// relationship targets the way Office does ("../slideLayouts/slideLayout1.xml").
    public func relativeReference(to other: PackURI) -> String {
        let from = baseURI.split(separator: "/").map(String.init)
        let dest = other.value.split(separator: "/").map(String.init)
        var common = 0
        while common < from.count && common < dest.count - 1 && from[common] == dest[common] {
            common += 1
        }
        let ups = Array(repeating: "..", count: from.count - common)
        let downs = dest[common...]
        return (ups + downs).joined(separator: "/")
    }

    public var description: String { value }
}
