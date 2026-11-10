import Foundation

/// Markup Compatibility (ECMA-376 Part 3) branch selection for the preview.
///
/// Office writes newer content (equations, ink, newer shape kinds) as an
/// `mc:AlternateContent` whose `mc:Choice` needs an extension namespace and
/// whose `mc:Fallback` holds ordinary pictures or shapes. The preview draws
/// the branch a reader without those extensions would use. Source XML is only
/// read: both branches remain in the part and survive save unchanged.
enum MarkupCompatibility {
    /// Namespace prefixes whose `mc:Choice` content the preview can draw.
    /// None yet: equation (a14), ink and newer-shape choices hold content the
    /// renderer lacks, while their fallbacks are content it already draws.
    static let understoodPrefixes: Set<String> = []

    /// The branch to draw and its same-name index among its siblings, or nil
    /// when no choice is understood and there is no fallback.
    static func selectedBranch(of alternateContent: XML.Element) -> (branch: XML.Element, occurrence: Int)? {
        var occurrences: [String: Int] = [:]
        for branch in alternateContent.childElements {
            occurrences[branch.name, default: 0] += 1
            switch branch.name {
            case "mc:Choice":
                let required = (branch[attribute: "Requires"] ?? "").split(whereSeparator: \.isWhitespace)
                if !required.isEmpty, required.allSatisfy({ understoodPrefixes.contains(String($0)) }) {
                    return (branch, occurrences[branch.name]!)
                }
            case "mc:Fallback":
                return (branch, occurrences[branch.name]!)
            default:
                continue
            }
        }
        return nil
    }
}
