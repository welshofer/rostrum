# Native text boundaries and shared visible width

The shared layout engine now reproduces the independently captured line breaks
for 175 narrow-boundary cases. Of these, 174 also pass the bounded horizontal
position/advance checks; one DejaVu ligature control explicitly reports an
unsupported shaping feature. This is numeric layout evidence for the tested
profile, not whole-slide raster parity.

The [native fixture record](../Tests/RostrumTests/Fixtures/LineBreakBoundaries/README.md)
retains five independently authored decks, their local PowerPoint PDFs, generation
and extraction scripts, font identity checks and source hashes. PowerPoint
16.113.3 opened all five decks without repair; the root exported 30 pages using
local **Best for printing**. The initial 72-case baseline had 23 line mismatches.
All 175 retained line cases now match. Portable numeric Arial metrics cover 149
cases; the bundled DejaVu font covers 26. No system Arial installation or platform
skip is required by these tests.

## Corrected layout rules

- For verified left-to-right ASCII segments with one scalar per shaped glyph,
  base advances round to the nearest eighth of a point after font scaling.
  Kerning and tracking remain separate from base rounding.
- Body width minus insets floors to the eighth-point capacity before subtracting
  paragraph coordinates. Paragraph margins and indent use the independently
  observed 0.05-point grid; negative text starts clamp to the body edge.
- Right alignment uses that capacity. Center alignment retains the original
  extent. Body insets retain their original precision.
- An explicit DrawingML `kern="0"` disables native kerning. Omission and positive
  thresholds retain their independently verified behavior. XML values and the
  standalone `TextShaper` contract remain unchanged.
- `RichTextLine.visibleWidth` exposes the line's advance width excluding trailing
  ordinary spaces. It includes tab gaps and excludes the separate bullet, body
  insets, paragraph indent and alignment offset; it is not glyph ink bounds.

Empty unresolved-font runs cannot change visible wrapping. RTL paragraphs keep
the prior raw geometry and report the unsupported native-calibration boundary.
If supported and unsupported segments mix, eligible segments retain calibrated
advances while paragraph coordinates/capacity remain raw, with an explicit
diagnostic. The supported-profile claim therefore does not cover every ASCII
string: a font can form multi-scalar ligatures from ASCII letters.

The native PDF can label authored 23.5-point text as 24 points while preserving
the source-size character positions. The oracle retains both facts. Its endpoint
uses the independently authored effective size and font advance for the final
glyph, whose following PDF origin is unavailable. It compares starts within
0.025 point and advance widths within 0.06 point; prior tab and paragraph oracle
tolerances remain unchanged.

## Verification checkpoint

Root integrated engine commit `85f70a2` as `301a6c2`, on top of the preserving
performance change. `swift test --jobs 2` passed 1,025 tests in 142 suites,
including the 60 existing native tab cases and unchanged paragraph references.
Both README sample decks were generated and reopened.

Independent review approved the frozen engine and native evidence. Review
prompted direct regressions for empty missing-face runs and RTL eligibility.
The stricter rendering test retains deterministic alias embedding, requires
the ligature diagnostic and strict rejection, then proves strict success for a
supported plain-text case.

PowerPoint opened the Rostrum-saved twelve-slide specimen without repair; its
first page was visually inspected. Its SHA-256 remained
`f504c33cbe50ce73de8ae849b935a15bf7b682c483ddcc0c964dc910aacc3a5d`.
Root verified all ten native source/PDF hashes and the worker test-log hash.

## Lectern and integrated acceptance

The existing paragraph demo now adds a third slide with uniform and mixed-size
native boundary cases before and after both public fitting paths. Its narrower
option switches between independently captured widths only 0.02 point apart.
Native line expectations, source/PDF/font hashes and saved style/autofit checks
travel with the offline recipe. Computed fit scales remain distinct from a
PowerPoint-selected autofit claim. Fixed sample words avoid diagnosed ligatures;
the library's explicit unsupported-ligature tests remain intact.

At source `87176bd`, root verification passed 236 LecternCore tests in 27 suites
and all 25 Lab demos' 319 saved-file checks. The paragraph demo passes 22 checks.
The native app suite passed 78 tests with zero failures/skips (106 total
executions). The headless harness passed 78 reported tests in 18 suites with
three native WebKit skips covered by the native run. Root verified all 55 copied
inputs, 148 dependency inputs and the headless log hash. iOS simulator Debug
builds passed for both arm64 and x86_64, confirmed in the built binary.

In the rebuilt app, root generated both width variants with four sentences and
a custom title, observed 22 passing checks each, inspected the three-slide deck,
and completed Export Everything. Exported Markdown contains the boundary slide,
narrow width and computed scale labels. PowerPoint opened separately retained
default/narrow specimens without repair; both third slides were visually checked
and their original hashes remained unchanged.

The [integration receipt](benchmarks/2026-10-03-boundary-integration-verification.json)
pins logs, artifacts, commands and distinctions between native and headless runs.
The [final combined performance report](INTEGRATED-LAYOUT-PERFORMANCE-20261003-3.md)
measures 4.44% faster registered-font table rendering and 5.92% faster fitting
against this pass's baseline, with all ten pairs faster and nonoverlapping ranges.
Fallback recovery remains unproven. These final figures supersede the isolated
preserving-stage figures for the integrated source.
