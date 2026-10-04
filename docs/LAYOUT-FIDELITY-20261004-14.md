# List marker and table acquisition integration — 2026-10-04

The shared layout now handles the native-evidenced marker profile, including
separate character/number sizing and face rules, inherited marker choices,
explicitly absent markers and continuation lines returning to the paragraph
margin. The bounded profile retains its kerning/tracking/context restrictions;
other contexts keep the previous marker path. Shallow inherited-choice projection
avoids copying unrelated master subtrees without a persistent mutable cache or
new public API.

The complete local gate passes at `05613d0`; the independently accepted performance
packet is integrated as documentation-only `6a3f61b`. The
[integration manifest](benchmarks/2026-10-04-native-markers-integration-verification.json)
pins the original failed gate, test-only correction, final evidence and retained
performance costs. Earlier checkpoints and measured packets are unchanged.

## Offline demonstration and native evidence

List markers is the 27th offline Library Lab demo. Its first four slides preserve
all 24 native specimens, distinct master chains, source bodies/frames and licensed
font bytes. A separate fifth slide compares Shape.fitText and TextFrame.fitText
in smaller copies. The alternative switches the fitting source. Both options
pass 58 checks with no findings. Computed fits are distinct from native-selected
autofit; the fifth page is excluded from numerical native-transfer proof.

Both actual generated five-slide variants opened in PowerPoint 16.113.3 without
repair and were exported locally using Best for printing with online export off.
Source hashes remained unchanged. Independent comparison verifies all 24 cases,
277 visible glyphs and three explicit absent markers per variant on the first
four pages, with zero deltas from the original native captures for origins,
baselines, painted size and source-outline ink dimensions. Original finite
bounds remain 0.06 pt x, 0.121 pt baseline and 0.002 pt paint/ink dimensions.
Only the fifth source slide differs between variants; the first four source XML
pages, master/layout/font members and native geometry projections match.

Fresh final-gate WebKit PDFs pass independent source/subset-outline and raw-matrix
extraction for both marker options: 48 cases, 554 visible glyphs and six explicit
omissions. The existing paragraph/kerning captures separately pass 14 cases /
208 glyphs. Marker and paragraph captures use exact saved inspector SVGs; the
kerning control remains explicitly raw-library scoped. Browser/SVG origins keep
the 0.025 pt bound, marker/native x the 0.06 pt bound, native baseline 0.121 pt
and paint/ink 0.002 pt. An unnecessary prior-PDF byte-identity preflight failed
before extraction; its receipt remains. Final verification hashes each new PDF
and extracts its actual geometry without changing a parser or tolerance.

Root completed both real List markers workflows: Run Demo → inspector → native
folder export. Each showed 58 checks, zero findings, five loaded previews and a
five-slide export with no media or chart CSVs. All 60 source text nodes per
variant survive the narrowly specified Markdown unescaping; recipe and manually
exported Markdown are identical. Source hashes taken before inspection remain
unchanged through completed export and exactly match the native captures.
Both computed-fit copies were visibly inside their frames. All ten manual SVG
comparisons differ from raw library SVGs only in root viewport dimensions;
raw SVG identity is not claimed. The independently reviewed receipt retains
38 artifact pins and the historical binary hash observed at both manual runs.
A later canonical rebuild changed the binary at that path, so current-path
identity is explicitly not substituted for the historical observation.

## Full gate, preserved failure and external validation

The final `./scripts/verify.sh` returns zero: 1,165 Rostrum tests in 167 suites,
18 layout tests in three suites, 288 Core tests in 41 suites, offline checks,
README examples, macOS/iOS simulator builds and 83 app tests in 23 suites /
115 executions pass. The app xcresult reports zero failures, expected failures,
skips or runtime warnings. There are no contradictory quiet exit-zero build
messages. Eight retained `error:` lines are app-host WebContent clipboard
messages, not build failures; no additional nonquiet rebuild was needed.

The first full gate at `c71f668` remains failed: ten assertions in the new
parameterized marker test compared 640-pixel inspector SVGs with 1280-pixel raw
renders. Apparent differences inside logged font bytes were two interleaved
DisplayLink console events, verified using diagnostic copies only. The
`05613d0` correction changes tests alone: independently render at the inspector's
640-pixel width and also require exact saved-inspector SVG identity. It does not
normalize production output or loosen a native bound. A focused marker run and
the final full gate pass. The initial log, xcresult summary and diagnostic
comparison remain pinned.

Independent external checks pass all 445 checks across 27 recipes, retaining
411 findings. All 335 inputs remain unchanged during verification; 64 ZIP
CRC/python-pptx reopens cover 243 slides and 1,930 XML/relationship parts.
Twelve prior special paragraph/table artifacts match exactly, and the generated
marker PPTX files exactly match the independently captured native sources.
Four general Lab packages differ only in valid, consistently mapped comment and
author UUIDs and ISO timestamps. A separate classifier verifies every remaining
node, attribute and package byte exactly; those packages are not relabeled
byte-identical or used for native acceptance. The original external receipt and
its initially unresolved classification remain intact.

## Two separate performance results

The independently accepted [cell-acquisition report](CELL-ACQUISITION-PERFORMANCE-20261004-14.md)
measures streaming lookup of live indexed cells. Four explicit acquisition loops
improve paired medians 96.84%, 99.18%, 99.69% and 99.47%, each with 10/10 faster
pairs. These timings exclude input loading, font registration and returned-text
consumption. Rendering/fitting controls remain inconclusive; no end-to-end table
rendering benefit, constant-time lookup, general lower memory or historical
cumulative recovery is claimed.

The separate [marker performance report](NATIVE-MARKER-PERFORMANCE-20261004-14.md)
accepts cycle two as a bounded fidelity tradeoff. Cycle one remains **WITHHELD**
with its adverse four-copy inheritance results intact. Cycle two retains
+2.777% and +2.702% paired rendering costs on ordinary `buNone` controls and
+1.136% on placeholders. These costs have positive intervals and are not
dismissed as noise. The primary marker deck and ordinary inherited ASCII/Unicode
controls improve; followup uncertainty, possible canonical/fitting costs, mixed
RSS and background load remain explicit.

The two marker cycles compare against the same retained baseline in different
windows, not against each other in one matched optimization experiment. Their
measured candidates exclude the separately accepted cell-acquisition change.
Shallow projection preserves cycle-one SVG, ordered diagnostics, inheritance
flags and saved packages across 148 cases / 842 slides. Original packets and all
207 phase comparisons remain available. No universal nonregression, clean-host,
cumulative recovery or cross-platform speed claim follows.

The next 24-case body center/right alignment probe is separate future work and is not
accepted by this checkpoint. No numerical native acceptance is claimed for the
computed-fit fifth page, no whole-deck raster parity is claimed, and no merge or
deployment is recorded here. The documentation lane performed no builds,
timings, GUI operations or production edits.
