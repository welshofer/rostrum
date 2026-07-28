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
    ///
    ///     PackURI.resolve(target: "../slideLayouts/slideLayout1.xml",
    ///                     relativeTo: "/ppt/slideMasters")
    ///     // → /ppt/slideLayouts/slideLayout1.xml
    ///
    /// A RELATIVE target gets "./" and "../" resolved against `baseURI`. An
    /// ABSOLUTE target is taken verbatim, dot segments and all — an asymmetry,
    /// but the long-standing behaviour, and no producer writes absolute targets
    /// with dot segments.
    ///
    /// Targets are matched VERBATIM, without percent-decoding, and that is
    /// deliberate — an earlier commit decoded them and had to be reverted.
    ///
    /// A part name is a sequence of `pchar` segments (ECMA-376 Part 2 §8.1.1.1),
    /// and the zip item name is the part name minus its leading slash. So a
    /// part containing a space is *already* `my%20image.png` in the zip item
    /// name, in the `Override/@PartName`, and in the `Target` — a conformant
    /// package is internally consistent in ENCODED space. Decoding only the
    /// Target moves one end of the comparison into a namespace no other layer
    /// shares, so the lookup misses and the picture silently fails to load:
    /// precisely the bug the decoding was meant to fix.
    ///
    /// Decoding is also many-to-one: `slide%31.xml` decodes onto `slide1.xml`,
    /// and invalid UTF-8 escapes all funnel to U+FFFD. Note precisely what that
    /// does and does not do — parts are keyed by their raw zip member name, so
    /// two parts never collapse into one; what collapses is *resolution*, and a
    /// relationship ends up pointing at a different part than the one it names.
    /// Wrong-part is not the same failure as `hasEmptySegment`'s two-names-one-
    /// relsURI, and calling it that overstated the case.
    ///
    /// **Open, deliberately:** a producer that writes the zip item name RAW but
    /// the Target ENCODED is internally inconsistent, and neither spelling
    /// alone resolves it. The fix is to try the verbatim URI first and fall
    /// back to the decoded one only when no part matches — which needs the
    /// package at every one of the ~20 `resolve` call sites, not a change here.
    /// Designed rather than guessed at; see ROADMAP.
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
