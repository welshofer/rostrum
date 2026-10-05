# Mixed-face exact spacing — 2026-10-04

This checkpoint corrects vertical placement for a bounded class of paragraphs
that combine distinct fonts with equivalent vertical metrics and exact point
spacing. It adds Mixed faces and exact spacing as Lectern's 29th offline demo.
The local gate, fresh native comparison and independent browser extraction pass
at source `1660253`. Both manual Lectern workflows also pass. Independent
performance review accepts the measured, bounded fidelity cost; it does not
establish an optimization or nonregression. The
[integration manifest](benchmarks/2026-10-04-mixed-spacing-integration-verification.json)
records the evidence and retained verification history.

## Native correction and limits

The original two native pages contain 12 cases and 96 visible glyphs. Before
the correction, admitted mixed-face text could appear about 9.08 pt too low.
The representative 12 pt DejaVu Sans / 24 pt DejaVu Serif case now places its
two baselines at 14 and 32 pt, against PowerPoint's 13.920044 and 31.920044 pt.
The existing 0.121 pt baseline bound is unchanged. Reversing run order, single-face
controls, exact 18/36 pt spacing, center/bottom anchors and stored 100/72.5%
scale establish the narrow supported behavior.

The correction admits distinct actual font resources only when their normalized
Windows ascent share and height match, with explicit point spacing in shapes
and the existing compatible paint/scale conditions. It changes vertical origins;
horizontal positions, painted sizes, embedded faces and outlines stay unchanged.
Unequal font metrics, percentage spacing with mixed faces, table context,
incompatible spacing flags and nonzero line-spacing reduction retain their prior
fallback behavior. This does not establish general mixed-font or whole-slide
PowerPoint parity.

Both public fitting APIs now compute 100% font scale and zero line reduction for
the demonstrated 290 × 40 pt frame, with unrounded content height
37.33489932885906 pt. This is a shared-layout fitting result, not evidence of
PowerPoint's selected autofit scale. Authored run sizes and original source bodies
remain intact.

## Lectern demonstration and native output

Both demo options preserve all 12 original specimen nodes, frames, master links
and embedded font bytes on the first two pages. Only captions outside specimens
switch to bundled DejaVu Sans for predictable offline previews; complete page XML
byte identity is not claimed. A third page compares `Shape.fitText` and
`TextFrame.fitText` on separate copies. The alternative changes those copies from
top to bottom anchoring without changing the original native specimens.
Each option passes 37 saved-file checks with zero findings.

Both generated three-slide decks opened in PowerPoint 16.113.3 without repair.
Root selected local Best for printing PDF export with online export off. The
source PPTX bytes remained unchanged. Fresh independent extraction of the first
two pages verifies 24 cases and 192 visible glyphs across the two options:
actual source/subset font-outline identities match, and x positions, baselines,
paint sizes and ink dimensions have zero delta from the original native captures.
The unchanged bounds are 0.025 pt for line-first x, 0.06 pt for other x,
0.121 pt for baselines and 0.002 pt for paint/ink dimensions. The computed third
page is excluded from numerical native and autofit-choice acceptance.

The app tests exercise Library Lab → actual inspector → folder export for both
options. They compare every saved SVG exactly with the actual inspector output
and compare the independent raw render at the same 640 px viewport. Specimen
checks parse each page once and establish each glyph's actual face from embedded
font bytes. Font-ready WebKit PDF capture uses those exact saved inspector SVGs.
Fresh independent extraction passes four mixed-face PDFs / 24 cases / 192 glyphs,
eight alignment PDFs / 48 cases / 344 glyphs, eight marker PDFs / 48 cases /
554 glyphs with six explicit omissions, and three paragraph/kerning PDFs /
14 cases / 208 glyphs. Paragraph captures also use exact saved inspector SVGs;
the kerning control retains its explicit raw-library scope. Source outlines,
actual faces, raw PDF matrices and ink dimensions are checked, with browser-to-SVG
coordinates bounded by 0.025 pt and all native bounds unchanged. The computed-fit
pages remain outside numerical native acceptance.

The earlier verifier plumbing failures remain in the receipt history. In the
marker review, a wrong descriptor key prevented initial extraction; a subsequent
aggregation error occurred after all eight fresh extractions passed. Correcting
the aggregation required no PDF reruns. Neither capture bytes nor bounds changed.
This is fresh PDF extraction, not transfer based on prior PDF identity.

Root completed both real top/bottom workflows through Run Demo, Inspect Result
and Export Everything using the native folder picker. Each showed three loaded
previews, 37 checks, zero findings and a three-slide export with no media or chart
CSVs. Both computed fits were visibly inside their frames. All 73 source text
nodes per option survive the explicitly scoped Markdown unescaping, and recipe
and manual Markdown exports match exactly. Source hashes taken before inspection
remain unchanged through export and match the independent native inputs. All
six saved previews exactly match the app-gate previews; comparison with raw
library SVGs requires only root viewport normalization. The 38-pin manual receipt
also records the actual app binary. Observed UI elapsed times of 4.36 and 15.85
seconds are workflow observations, not controlled benchmarks.

## Verification

`scripts/verify.sh` passes with 1,174 Rostrum tests / 170 suites, 18 RostrumLayout
tests / three suites, 292 LecternCore tests / 43 suites, README and offline checks,
macOS and iOS simulator builds, and 87 app test definitions / 25 suites covering
121 executions. The xcresult records zero failures, expected failures, skips or
runtime warnings. The app console retains ten clipboard, 207 preferences-daemon
and ten audio-component messages. The two quiet app-build stages exited zero,
but their retained log contains 11 contradictory compiler messages saying a
command failed with exit code zero and produced no further output. Those messages
are not a clean diagnostic result. Fresh serial macOS and iOS simulator builds
with full output, each in a separate empty derived-data directory, subsequently
exited zero with an explicit `BUILD SUCCEEDED` and zero error diagnostics.
The original gate log and tested app remain unchanged. The integration manifest
retains both confirmation logs and their receipt; no tests or timings were rerun.

All 29 Lab reports pass 542 checks and retain 413 findings. Independent ZIP CRC,
unique-member, XML and python-pptx checks reopen 64 packages / 224 slides /
2,097 XML and relationship parts. All 361 input files remain unchanged. Six
special alignment, marker and mixed-face option packages exactly match their
native capture inputs. Four general Lab packages differ from the prior gate only
in valid, consistently mapped comment/author UUIDs and ISO timestamps; every other
node, attribute, part and payload remains exact.

Completed receipts are retained at
`/tmp/lectern-fidelity16-external.json` (SHA-256
`ddbf9a707c7df05c61b2e37fba721c47480e66ad21353a7ea5d4dc739ea6b73b`),
`/tmp/lectern-fidelity16-comment-differences.json` (SHA-256
`9f6919780bb56b50b9f708e35307dfecac176ba1d522f62e83b90721c895e4b8`),
and `/tmp/lectern-fidelity16-mixed-native/independent-final-native-receipt.json`
(SHA-256 `f966ff76b4642e5b8dc553688297fe5e941cf87774aea29a48612ec017792fa8`).
The manifest also pins the four accepted fresh WebKit receipts, including
`/tmp/lectern-fidelity16-mixed-webkit/independent-final/review-receipt.json`
(SHA-256 `80560149b8fd401ec74e6c5504e7dd07fec611d968dd4acb70582e0517ed7c3c`).
The completed manual receipt is
`/tmp/lectern-fidelity16-manual/manual-mixed-spacing-verification.json`
(SHA-256 `df00b9ebe5fbfd3c826091954dc6f5c5ee44df2b96d0f4c9cdada33de9513d15`).

## Bounded performance cost

The separate [mixed-face spacing performance report](MIXED-FACE-SPACING-PERFORMANCE-20261004-16.md)
measures fidelity cost, not a speedup. Independent numerical review reconciles
all 173 vectors, comprising 21 primary and 152 secondary phases, from 330 child
processes. The retained paired result is +2.110% for admitted mixed-face warm fitting
(interval +0.615% to +3.312%) and +1.161% for long combining-text rendering
(+0.316% to +2.678%). Both have eight of ten slower pairs and inconclusive exact
sign tests. The affected mixed-face rendering interval spans zero, both captured
native rendering results are inconclusive, and process peak RSS results have
mixed signs. These results do not establish a performance or memory gain,
universal nonregression, or cumulative improvement over earlier checkpoints.
The experiment retains background load, the untimed superseded protocol and all
control outcomes rather than selecting favorable phases. Original physical
receipts with their review-pending wording remain historical evidence; acceptance
does not rewrite those measurements.

## Known next gap

The separate table appearance mismatch remains unfixed here: four cells without
an applied table style show a pale fill and white borders in Lectern, while
PowerPoint shows no fill and black borders. Treating the style-list insertion
default as an applied style is being investigated separately for checkpoint 17.
This checkpoint accepts only the stated text-layout scope.
