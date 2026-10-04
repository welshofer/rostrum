# Fidelity13 manual paragraph addendum — 2026-10-04

Both paragraph Library Lab variants now pass the real app workflow at published
checkpoint `8d1714b`: Run Demo → Inspect Result → Export Everything through the
native folder picker. Each displayed 74 passing checks, zero findings and seven
loaded previews, then exported seven slides with zero media files or chart CSVs.
The default inspector initially had two loading placeholders; subsequent
observation confirmed all seven loaded.

The independently approved [manual receipt](benchmarks/2026-10-04-fidelity13-manual-paragraph-verification.json)
pins 38 artifacts plus the exact app and verifier script. Source hashes were
recorded after inspection and before export, then remained unchanged through
completed export. The exported Markdown preserves all 165 default and 169
alternative source text nodes after decoding only escaped pipes and the specified
backslash/newline/two-space continuations. All other characters are compared
literally; recipe and manually exported Markdown are byte-identical.

The manual packages differ from the native-glyph gate specimens only in
`slide1.xml`, with four changed text nodes each: the title, two body paragraphs
using sample size four instead of two, and the caption. Every other package part,
including slides two through seven, is exact. This is not title-only or
whole-package identity.

Slide-seven SVGs differ in the root viewport (640×360 inspector versus 1280×720
raw gate) **and** transforms on 18 childless, textless elements. Their tags and
all other attributes are checked explicitly; every painting node and all
remaining XML match. Neither raw nor viewport-only SVG identity is claimed.
The initial literal-Markdown and viewport-only assertions remain recorded,
alongside the corrected bounded comparisons. No new PowerPoint capture,
whole-deck native raster parity or native-selected autofit is claimed.

The completed hosted snapshot for `8d1714b` records passing macOS PR-gate,
Linux Swift 6.0 build/README and Linux Swift 6.1 test checks. GitGuardian check
`111527728994` remains failed on two historical occurrences. Both values were
independently recomputed as the same SHA-256 of the named
`TemplateAuthoring.swift` source, not credentials; the classification receipt
is pinned. No check bypass or dismissal is claimed.

This addendum completes the paragraph manual workflows that were pending in the
[fidelity13 integration checkpoint](LAYOUT-FIDELITY-20261004-11.md); its prior
records and frozen performance data remain unchanged. Both table manual workflows
were already completed there. The separate marker correction remains future
work. This documentation-only addendum includes no build, GUI operation, push,
merge or deployment.
