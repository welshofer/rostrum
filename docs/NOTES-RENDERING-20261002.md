# REL-1 / REL-5: bounded native notes-page preview

The public `Presentation.renderNotesSVG(slideAt:pixelWidth:strictRendering:)`
and `renderNotesSVGReportingProblems` APIs render existing notes pages. The
reporting variant returns `(svg: String, problems: SlideRenderProblems)` and
strict mode throws the existing `StrictRenderingError` for known gaps. Missing
notes, invalid notes dimensions, and a pixel width outside 1...100000 throw
without creating notes. `pptx-tool render input.pptx output --notes` exports
`notes-NN.svg`, skipping slides without notes.

Rendering uses original `p:notesSz`, the notes relationship's master and theme,
and namespace-aware placeholder **type** ancestry rather than slide-layout
indexes. Detached rendering views merge body/slide-image geometry, partial
local transforms, text body properties, notes styles, local fill/line overrides,
and background inheritance. Inherited resource references are retargeted only
in detached relationships. Source XML, dirty flags, blobs and package parts stay
unchanged. Namespace copying is iterative, with a 100,000-node regression.

Slide images use an isolated SVG image document so embedded font aliases and
SVG IDs cannot collide with the outer notes page. Effective `noFill` plus
`a:ln/a:noFill` suppresses the thumbnail, matching the native observation already
recorded in `NotesPageTemplate`. Otherwise the image keeps source proportions,
with white image backing when no fill is supplied. Backing and frame paint once,
including translucent paint. Hidden thumbnails do not render or diagnose the
slide. Local visible borders can restore a master-suppressed thumbnail.

This is a bounded preview, not universal notes support. Header/footer/date/slide
number placeholder semantics, header/footer visibility settings, unknown and
ambiguous ancestry, unregistered masters, and unavailable inheritance are
reported. Existing drawing/text diagnostics cover omitted inherited groups and
connectors, transforms, effects, unavailable fonts and other shared renderer
gaps. A relationship-resolvable master absent from `notesMasterIdLst` stays
usable in permissive mode but is explicitly diagnosed; the original v1/v2
native notes-positioning failures are not hidden or rewritten.

## Verification and native limits

`swift test --jobs 2` passed **985 tests in 133 suites** after the review fixes.
Twelve notes-renderer tests include three parameterized source/import cases,
source-size/background inheritance, aliased namespaces and foreign lookalikes,
partial geometry and local style, dirty/source-byte preservation, absent notes,
strict refusal, inherited group/connector omissions, suppressed images,
translucent single paint and isolated embedded thumbnail resources.

The development-only [oracle runner](../Tools/conformance/check_notes_render.py)
reopened ten pinned fixture decks with python-pptx 1.0.2, produced thirteen
notes SVG/PNG candidates, and verified every slide-image placeholder frame
against python-pptx's type-based notes ancestry. Four source/import SVG pairs
were byte-identical, including preserved target pages and local/index overrides.
This is exact **source/import preservation**, not pixel equality to Office.

The API retains the source notes-page size. Native print references are Letter
portrait PDFs with a recorded scale-to-fit notes area `[17, 11, 578, 770]` points.
The runner applies that explicit profile only to comparison copies. It never
infers a per-page fit from visible content, changes the source API SVG, or edits
a reference. It separately reports API-size evidence and print-profile evidence.
At 1200 × 1553 pixels, channel tolerance 16 and the unchanged maximum differing
fraction **0.005**, the current worker binary fails every absolute native case:

| Native PDF case | Differing fraction | Gate |
| --- | ---: | --- |
| Geometry source / imported page 2 | 0.008356944 | FAIL |
| Geometry target / imported page 1 | 0.010406203 | FAIL |
| Conformance original / v2 | 0.047888495 | FAIL |
| Conformance v3 | 0.010428740 | FAIL |

Residual native differences remain outside the bounded renderer implementation;
strict mode is a known-issue detector, not an Office pixel-conformance certificate.
No reference, tolerance, or font binary was committed. Re-run the command below
against the final integration binary; the worker numbers are not a release pass.

## Reproduction

Development tools used: Python 3.12.0, python-pptx 1.0.2, resvg-py 0.5.0,
PyMuPDF 1.27.2.3 and Pillow 12.3.0. These remain optional external oracles,
not Swift runtime dependencies. Supply exact installed font faces explicitly:

```sh
python3 Tools/conformance/check_notes_render.py \
  --binary .build/debug/pptx-tool \
  --output-dir /tmp/rostrum-notes-candidates \
  --report /tmp/rostrum-notes-evidence.json \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/arial.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/arialbd.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/ariali.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/arialbi.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/Calibri.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/Calibrib.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/Calibrii.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/Calibriz.ttf'
```

Exit 0 means all fixed native pixel gates passed, exit 1 means the report and
candidates were generated but a native gate failed, and exit 2 means the
measurement/structural checks failed. The JSON records source-deck, native-PDF,
font, candidate, renderer-source, whole-library-source, executable, script,
Python executable and tool-module hashes plus tool versions and the exact
command. The library source digest hashes a sorted JSON mapping of Swift source
paths to SHA-256 values. `python3 -m py_compile` and `git diff --check` passed.
