import Foundation

/// A pack URI — the absolute, `/`-rooted name of a part inside an OPC package,
/// e.g. `/ppt/slides/slide1.xml`.
///
/// Mirrors python-pptx's `PackURI` (a `str` subclass); in Swift it is a value
/// type with the derived-path conveniences the packaging layer needs.
public struct PackURI: Hashable, Sendable, CustomStringConvertible {
    public let value: String

    /// `value` must begin with "/". Constructing an invalid pack URI *in
    /// Rostrum's own code* is a programmer error, not a recoverable condition
    /// — every internal call site builds the string from a literal or from an
    /// already-valid URI.
    ///
    /// For a name that came out of a **file**, use `init?(parsing:)`: a
    /// precondition on untrusted input aborts the host process instead of
    /// letting the caller reject the deck.
    public init(_ value: String) {
        precondition(value.hasPrefix("/"), "PackURI must begin with '/': \(value)")
        self.value = value
    }

    /// A pack URI parsed from file content, or nil when the name is not an
    /// absolute part name. `[Content_Types].xml` `PartName` attributes and
    /// relationship targets are untrusted: a `.pptx` from anywhere can carry
    /// `PartName="ppt/slides/slide1.xml"` with no leading slash.
    public init?(parsing value: String) {
        guard value.hasPrefix("/") else { return nil }
        self.value = value
    }

    /// Does this zip member name have an empty path segment (OPC M1.1)?
    ///
    /// The reason this matters is aliasing, not tidiness. `PackURI`'s identity
    /// is its raw `value`, but `baseURI` and `filename` split on "/" and drop
    /// empty subsequences. So `ppt//slides/s.xml` and `ppt/slides/s.xml` are two
    /// distinct parts that derive ONE `relsURI` between them — a part-identity
    /// bug, and a way to make a reader decode a single `.rels` entry once per
    /// alias. The empty name is the same bug with no visible slash: `"/" + ""`
    /// is `/`, whose `relsURI` is the package relationships.
    ///
    /// Takes the member name (no leading slash), which is the form both the
    /// reader and the writer have in hand.
    ///
    /// Written as "any empty component" rather than as a list of the shapes
    /// that produce one. The first cut spelled out leading, internal and wholly
    /// empty and missed the TRAILING slash — `ppt/slides/s.xml/` aliases onto
    /// `ppt/slides/s.xml` exactly like `ppt//slides/s.xml` does, because
    /// `split` drops a trailing empty subsequence the same way. OPC happens to
    /// state that one separately (M1.4), which is presumably how it got lost.
    static func hasEmptySegment(_ memberName: String) -> Bool {
        memberName.split(separator: "/", omittingEmptySubsequences: false).contains(where: \.isEmpty)
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
        // A `.rels` Target is a URI reference, not a raw name, so a part called
        // "/ppt/media/my image.png" is written "my%20image.png" by any
        // conformant writer. Resolving without decoding yields a URI that
        // matches no part, and the picture silently fails to load.
        //
        // Decode per SEGMENT, after splitting: decoding first would turn an
        // encoded "%2F" — a literal slash inside one name — into a separator.
        var stack: [String] = target.hasPrefix("/") ? [] : baseURI.split(separator: "/").map(String.init)
        for segment in target.split(separator: "/") {
            switch segment {
            case ".": continue
            case "..": if !stack.isEmpty { stack.removeLast() }
            default: stack.append(percentDecoded(String(segment)))
            }
        }
        return PackURI("/" + stack.joined(separator: "/"))
    }

    /// Percent-decode one path segment (RFC 3986).
    ///
    /// An invalid escape is left as written rather than dropped or replaced:
    /// `100%.png` is not legal encoding, but a writer emitted it and the byte
    /// it meant is `%`. A conformant writer that means a literal `%` sends
    /// `%25`, which decodes back to exactly that.
    ///
    /// A decode that would introduce a `/` is refused outright and the segment
    /// kept as written. `%2F` inside one segment is not a legal part name — OPC
    /// segments are `pchar`, which excludes `/` — and honouring it would let a
    /// target manufacture a separator, producing two `PackURI`s that differ as
    /// strings but derive one `relsURI`. That is precisely the aliasing class
    /// `hasEmptySegment` exists to prevent; decoding must not reopen it.
    static func percentDecoded(_ segment: String) -> String {
        guard segment.contains("%") else { return segment }
        func hex(_ b: UInt8) -> UInt8? {
            switch b {
            case 0x30...0x39: return b - 0x30            // 0-9
            case 0x41...0x46: return b - 0x41 + 10       // A-F
            case 0x61...0x66: return b - 0x61 + 10       // a-f
            default: return nil
            }
        }
        let bytes = Array(segment.utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            if bytes[i] == 0x25, i + 2 < bytes.count,
               let high = hex(bytes[i + 1]), let low = hex(bytes[i + 2]) {
                out.append(high << 4 | low)
                i += 3
            } else {
                out.append(bytes[i])
                i += 1
            }
        }
        let decoded = String(decoding: out, as: UTF8.self)
        return decoded.contains("/") ? segment : decoded
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
