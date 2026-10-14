# Importing and previewing presentations

Rostrum preserves source package content independently of what its SVG preview
can display. Opening or previewing a deck is not a conversion to a new layout.
An untouched part retains its original bytes; supported edits change the relevant
parts. Unknown XML does not imply preview support or permission to edit an
otherwise unsupported object.

The imported-fidelity update is on `main` and listed under **Unreleased** in the
[changelog](../CHANGELOG.md). Consumers needing it before a tagged release should
pin a reviewed commit revision. It is not included merely by specifying the
older version shown in the README installation example.

## Register fonts before rendering

The portable library does not search the operating system's font folders.
Register the exact licensed faces used by the source presentation for reproducible
measurement. Register regular, bold and italic files separately; registration
keeps distinct styles. Font embedding restrictions still apply to SVG output.

```swift
import Foundation
import Rostrum

let deck = try Presentation(contentsOf: URL(filePath: "input.pptx"))
try deck.fonts.register(contentsOf: URL(filePath: "fonts/Source-Regular.ttf"))
try deck.fonts.register(contentsOf: URL(filePath: "fonts/Source-Bold.ttf"))

// Optional: explicitly choose a licensed registered family for missing fonts.
let fallback = try deck.fonts.register(
    contentsOf: URL(filePath: "fonts/Preview-Regular.ttf"))
deck.fonts.previewFallbackFamily = fallback

let preview = try deck.renderSVGReportingProblems(slideAt: 0, pixelWidth: 1280)
try preview.svg.write(to: URL(filePath: "slide.svg"), atomically: true,
                      encoding: .utf8)
// Present preview.problems alongside the image; do not discard fidelity issues.
```

The file paths above are placeholders for local fonts, not bundled downloads.
Without an explicit fallback, `previewFallbackFamily` defaults to `nil` and
unavailable faces retain estimated measurements and viewer substitution. Preview
selection prefers the exact requested face, then the requested family's regular
face, then the configured fallback style, then its regular face. Synthesized
styles and missing families remain diagnosed. Exact `metrics(for:)` face lookup
does not treat a preview substitute as the requested font.

Fallback improves readability by measuring and drawing with the same registered
face. It cannot reproduce the source font's appearance. It does not rewrite
serialized typeface names or register an alias under a missing source family.
Lectern's generation, recovery and inspection previews explicitly register Arial;
the offline Library Lab recipe uses its licensed bundled DejaVu face. Other hosts
choose their own policy. Lectern reopens generated/recovered files and discovers
the same slide, layout, master and theme font declarations as Inspect. Generation
font aliases and measurement state are kept separate from this preview registry.
No preview operation saves or changes the caller's requested font families.

## Embedding fonts safely

`deck.embedFont("Your Family", faces: FontFaces(regular: regularBytes, bold: boldBytes))`
accepts caller-supplied font bytes. It validates all supplied faces before changing
the package, including embedding-license restrictions. Repeating a request with
identical raw bytes for the same case-insensitive family/style is a byte-identical
no-op, including after reopening. Existing EOT wrappers, metadata and omitted
styles remain intact; missing styles are added in schema order.

Different bytes for an existing style, ambiguous declarations and broken font
references throw without modifying the package. Compressed/opaque embedded fonts
cannot be compared with raw sfnt bytes and are conservatively refused. Embedding
does not silently replace a face already used by other slides. Names and payloads
that exceed EOT's integer size limits also throw before mutation.

Call `registerEmbeddedFonts()` explicitly to enable local measurement with
decodable embedded faces. Embedding cannot guarantee identical rendering in every
PowerPoint version; native slide-view acceptance remains a separate check.

## Embedded fonts during slide import

`destination.slides.import(from:at:)` and `importAll(from:)` preserve every source
embedded family and style. Font declarations belong to the presentation, so
copying only the slide's relationships would lose them. All embedded families
travel with a nonempty import, including fonts used through inherited themes,
notes, or unmodeled content.

Matching family/style declarations with identical payloads and compatible
metadata are reused. Missing styles are added. Different bytes for the same
case-insensitive family/style, incompatible opaque metadata, or broken font
relationships throw before any imported parts are installed. Even different
subsets of the same font can conflict; import does not rewrite or combine font
binaries. The source remains unchanged.

After importing, call `destination.registerEmbeddedFonts()` to make decodable
embedded faces available to measurement and SVG rendering. This remains explicit:
import does not change your live font registry or find unembedded system fonts.
Opaque compressed fonts are retained in the saved deck even when registration
cannot decode them. Callers remain free to use any supported font family; the
fonts in tests and sample decks impose no library font policy.

## Keep diagnostics visible

`renderSVGReportingProblems` returns the SVG and a `SlideRenderProblems` report.
Reports distinguish damaged inheritance links from omissions, approximations and
missing resources. `strictRendering: true` throws `StrictRenderingError` when
known issues are present, including missing fonts even with a preview fallback.
An empty report is not certification of complete PowerPoint equivalence.

For a command-line preview with exact registered fonts:

```sh
swift run pptx-tool render input.pptx /tmp/slide-preview --font /path/to/font.ttf
swift run pptx-tool render input.pptx /tmp/slide-preview --font /path/to/font.ttf --strict
```

Read-only rendering does not repair or regenerate chart caches, SmartArt layout
or other source structures. Text fitting is a separate, explicit editing operation.

## What improved

| Content | Current behavior | Boundary |
| --- | --- | --- |
| Custom DrawingML artwork | Lines, quadratic/cubic curves, guide coordinates and independent stroke scaling | Custom arcs, shaded path fills and custom geometry text rectangles remain unsupported |
| SVG pictures | Basic self-contained SVG, including Office SVG-only relationships, within a 4 MiB input limit | General SVG/CSS, active content and external references are rejected; original bytes remain preserved |
| SmartArt | Renders supported saved drawing caches and text bounds | Does not run PowerPoint's layout engine; missing or unsupported caches retain a diagnosed placeholder |
| Imported text | Inherits body/list styles; applies all-caps before measuring; anchors exact-spacing blocks without a trailing line gap | Small capitals and broader text-layout features remain diagnosed |
| Lists | Empty paragraphs keep spacing without markers or numbering increments; font/size choices inherit together | Automatic numbers use paragraph text faces; character bullets use their own face |
| Missing-font runs | Viewer advances prevent estimated mixed-run overlap; explicit measured fallback stabilizes wrapping | Unavailable native fonts still prevent identical typography |
| Hidden content | Hidden shapes and groups stay out of the preview | Content remains in the source package |

See the [format matrix](FORMAT_SUPPORT.md) and [conformance record](CONFORMANCE.md)
for broader feature support and remaining failures.

## Verify the consumer, not only the package

Run `./scripts/verify.sh` before publishing changes. It covers library and layout
tests, LecternCore and offline examples, executable README snippets, Apple app
builds and app-hosted tests. Linux and macOS CI provide additional platform checks.

For visual acceptance, compare against the same deck in native PowerPoint using
the same registered fonts and output size. Load SVG fonts before capturing a
viewer image. Then inspect the actual consuming app, especially on platforms
where fonts differ. Structural validity, a successful build and a clean diagnostic
report each answer different questions from visual acceptance.

The [October 3–4 acceptance record](IMPORTED-FIDELITY-20261003.md) includes a
22-slide native comparison and a separate iOS consumer sweep. It distinguishes
exact-font desktop evidence from readable Arial-fallback device acceptance.
Its [performance result](PERFORMANCE.md) measures warm library SVG rendering at
a specific optimization checkpoint, excluding viewer rasterization and startup.
Private decks, proprietary fonts and private screenshots remain outside Git.
