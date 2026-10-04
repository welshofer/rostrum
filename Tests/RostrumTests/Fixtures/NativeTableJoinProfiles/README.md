# Native mixed table-join profiles

Eight independent cases on two 720 pt slides extend the separate Fidelity17
corpus. PowerPoint 16.113.3 opened the owned source without repair; root exported
local Best for printing with online conversion off and did not save the source.
The original receipt, accepted PDF, all raw page operators and ordered drawing
records remain alongside the compact mechanical paint reference.

- Source SHA256: `39a1ed0ccef5faeda6608bb74528b541dc197a6f4ab3f6d6a05e54cfdd0a663e`
- PDF SHA256: `76fb8fb6e663efe692e15873ee51d21bc1e6a85e759d0a4527c02742a1874e46`
- Font SHA256: `7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954`

Page 1 pairs LTR/RTL black unequal-width grids, then red-vertical/blue-horizontal
and reversed-color grids. Page 2 pairs horizontal and vertical merges, each with
matching versus deliberately conflicting hidden continuation-cell borders. All
physical cells and attributes are pinned in cases.json. The source-grid coordinates
are an unmirrored input descriptor, not an assumed native RTL placement.

Frames are 240 × 160 pt with 90/150 pt columns and 60/100 pt rows. Each visible
cell contains `Agjp`, embedded DejaVu Sans at authored 14.5 pt, kern 0, stored 100%
scale and zero insets. Every table explicitly applies No Style Grid. There are 112
visible body glyphs. Font licensing reuses NativeListMarkers/fonts.

## Observations and scope

Against frozen Fidelity17, seven cases failed 69 painted interval comparisons by
up to 1.5 pt; the existing LTR control passed. The Swift fail-before recorded 71
issues: those 69 intervals and two crossing-order assertions. All 112 glyph origins
already matched (maximum 0.008225 pt). Matching/conflicting merge pairs have identical
frame-relative native text and borders. Existing ownership is correct; no text,
merge topology, style or donor-lookup change follows from these observations.

The existing signed endpoint rule matches all new interval endpoints exactly when
logical lower/upper extensions are swapped for horizontal RTL physical emission.
Native paint order is interior verticals, interior horizontals, outer verticals,
then outer horizontals. Correcting geometry alone with old cell-order painting
still produces one wrong colored overlap out of nine per swapped-color case.
Grouped painting matches both independent colored controls. Complete raw sequence
is retained; overlap midpoint checks supplement it and are not raster parity.

New mixed-width admission is limited to:

- Unmerged single-color RTL grids.
- Unmerged LTR grids with one consistent color per axis.
- Single-color LTR merges whose regions all share a single merge orientation.

These require validated rectangular topology, opaque flat centered solid strokes,
no diagonals, and every physical dimension greater than the largest stroke width.
Existing uniform-width geometry and existing Fidelity17 profiles remain unchanged.
RTL+merge, RTL+multicolor, merge+multicolor, two-axis or mixed-orientation merges, arbitrary collinear
color transitions, dashes, alpha, diagonals, oversized strokes and invalid grids
retain the previous fallback. No claim covers those combined or unsupported cases.

## Verification and reproduction

Native interval endpoints retain the 0.001 pt bound; raw RGB retains 0.0001 normalized
channel tolerance for PDF quantization. Every glyph retains text/count, 0.025 pt
origin and 0.002 pt paint-size checks. Traces do not establish a new source-outline
ink or raster guarantee. Only adjacent collinear identical-paint intervals may
coalesce; distinct color, opacity, width, position and gaps remain significant.

```
python3 Tests/RostrumTests/Fixtures/NativeTableJoinProfiles/generate.py
python3 Tests/RostrumTests/Fixtures/NativeTableJoinProfiles/capture.py 76fb8fb6e663efe692e15873ee51d21bc1e6a85e759d0a4527c02742a1874e46
swift test --jobs 2 --filter NativeTableJoinProfileTests
```

Python dependencies are development-only: python-pptx, lxml, fontTools, PyMuPDF
and pypdf. The generator is independent of Rostrum; expected paint comes only
from the captured native PDF. Production remains dependency-free. The retained
proposal and model receipt describe pre-implementation research; final worker
commands, counts and source hashes are in verification.json.
