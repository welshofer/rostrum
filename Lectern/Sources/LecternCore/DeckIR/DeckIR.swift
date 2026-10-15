import Foundation
@_exported import LecternIR
import Rostrum

// The IR types live in LecternIR (one definition for every renderer). This is
// LecternCore's rendering policy over them: where a generated image goes.

extension SlideLayoutKind {
    /// How a generated image is placed on this layout — chosen so imagery never
    /// clips or crowds text.
    public var imagePlacement: ImagePlacement {
        switch self {
        case .title, .closing: return .none // Typography carries the opening and closing.
        case .bigNumber, .quote, .statement: return .fullBleed
        // Text narrows to the left seven columns and the picture takes the
        // panel Rostrum reserves. Bullets and agendas qualify: they are one
        // column of text, so losing the right-hand fifth costs width, not
        // structure. That is what lets a mostly-bullets deck carry imagery at
        // all — with only the sparse layouts eligible, a 25-slide deck had
        // barely five places to put a picture.
        case .sectionHeader, .bullets, .agenda: return .sidePanel(.right)
        // The classic pairing, asked for explicitly so a deck can alternate
        // sides rather than leaning on one composition.
        case .imageLeft: return .sidePanel(.left)
        case .imageRight: return .sidePanel(.right)
        // Genuinely full-width: two columns of text, a plotted chart, a row of
        // metrics, stacked bands, a diagram. Narrowing any of these breaks the
        // layout rather than reflowing it.
        case .twoColumn, .comparison, .chart, .metrics, .bands, .diagram, .table,
             .timeline, .quadrant, .callout, .unknown:
            return .none
        }
    }

    /// Prompt-facing layout lists DERIVED from `imagePlacement` — the single
    /// source of truth. Three prompts used to hand-copy these names; the QA
    /// editor's copy listed five layouts and told the model to move briefs
    /// off the rest, quietly stripping imagery from the picture-beside-
    /// bullets slides the renderer was built around. Interpolating from here
    /// means the vocabulary cannot drift from the renderer again.
    public static var fullBleedImageLayoutNames: [String] {
        knownCases.filter { $0.imagePlacement == .fullBleed }.map(\.name)
    }
    public static var panelImageLayoutNames: [String] {
        knownCases.filter {
            if case .sidePanel = $0.imagePlacement { return true }
            return false
        }.map(\.name)
    }
    public static var imageEligibleLayoutNames: [String] {
        fullBleedImageLayoutNames + panelImageLayoutNames
    }
}

/// Where a slide's generated image goes.
public enum ImagePlacement: Sendable, Equatable {
    case none        // don't place an image (text-dense layout)
    case sidePanel(SideImage)   // a framed panel on one side, text on the other
    case fullBleed   // a scrimmed, edge-to-edge background behind the text
}
