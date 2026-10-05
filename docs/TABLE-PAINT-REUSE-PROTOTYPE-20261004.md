# Table paint reuse prototype — S20

This is an output-preserving prototype, not an accepted performance improvement.
No comparative timing or process-memory campaign was run in this lane. The
baseline is S19 `dc40a98b09d0db7c132c82c9e8f41b12dd4c5638`; this branch is
`codex/burndown/table-paint-reuse20-20261004`.

## Grounded repeated work

`TableStyleResolver.RenderSession` already caches at most 36 style-only
variants, subject to an estimated 1 MiB budget. S19's default black edges are
shared descendants of those templates; adding another effective-style cache
would duplicate existing work. The remaining repetition is in
`SVGRenderer.renderTable`'s border decoder: color/CSS, width, dash, simple-solid
eligibility and double-border eligibility are decoded again for each owned
cell edge, even when the XML line is the same immutable template descendant.
`colorHex` delegates to `SVGPaint.resolve`; this path reads color/theme data and
has no diagnostic-emission side effect.

An isolated, instrumented copy retained each observed node strongly so address
reuse could not distort the identity counts. All five controls have 200 rows
and 50 columns and make 40,250 border calls, including 20,000 nil diagonals.
The instrumented runs were untimed and their extra retention disqualifies them
from allocation or memory comparisons.

| Control | Original nonnil decodes | Distinct line nodes | Prototype decodes |
| --- | ---: | ---: | ---: |
| Partial custom fill-only style | 20,250 | 84 | 84 |
| Built-in grid | 20,250 | 84 | 84 |
| Unique direct borders | 20,250 | 20,250 | 20,250 |
| Explicit empty style lines | 20,250 | 84 | 84 |
| Explicit style noFill | 20,250 | 84 | 84 |

Both instrumented versions produce the same 15 SVG/package/problem artifacts
as the frozen, uninstrumented baseline. The counts establish redundant work;
they do not establish elapsed-time savings.

## Bounded design

The existing render session registers identities only for border descendants
of admitted templates. It reserves an estimated additional 512 bytes per edge
for identity bookkeeping, decoded entries and bounded CSS/pattern strings
within its existing estimated budget. This is an accounting allowance, not an
allocator measurement. Over-budget templates render normally without reuse.

`TableBorderPaintCache` exists only inside one synchronous `renderTable` call.
It has a hard 216-entry ceiling (36 templates × six edges). Each entry retains
its XML owner and an optional decoded paint result, so an explicit none result
is cached and addresses cannot be recycled under a live entry. Direct overlay
copies and uncached templates bypass insertion. Cache hits still contribute to
`maximumBorderWidth`, preserving admission for wide-border geometries.

Public resolver and fitting APIs remain uncached. No global or persistent
state, snapshot sharing, border owner/donor change, diagnostic change, XML
mutation or text-layout change is included. Reusing a renderer after style,
theme, alias or direct-cell edits creates fresh operation-local caches.

## Preservation and tests

The final uninstrumented comparison uses the exact same input bytes for each
baseline/candidate pair. Twelve cases produce 40 byte-identical artifacts:

- All five S17–S19 native decks, covering seven slides. Full SVG preserves
  every line, fill, text attribute and embedded font; saved packages and ordered
  problem descriptions are also exact.
- The five 200×50 controls above.
- A custom-style budget-saturation control with 40,000-character unknown
  comments per edge, and an over-budget control with 1,100,000-character
  comments per edge. These exercise partial admission and complete bypass.

Focused tests cover owner lifetime, cached none, the hard entry cap, mutable
uncached direct nodes, oversized unknown XML, exact shared-versus-direct paint,
maximum border width, alpha, dash, double-line predicates, and live renderer
reuse. Existing native S17–S19 assertions and bounds are unchanged.

The initial focused run had three invalid *test assumptions*: materializing
unsupported style declarations on every cell legitimately changes diagnostic
locations and multiplicity. SVG already matched. The corrected test compares
exact diagnostics across reopen/repeated rendering of each authored input;
the baseline/candidate artifact proof compares exact ordered diagnostics for
the same input. The failed log remains retained rather than reclassified as a
production regression.

Final checks:

- Focused: 22 tests / five suites passed.
- Full: 1,189 Rostrum tests / 173 suites and 18 RostrumLayout tests / three suites
  passed.
- Final same-input proof: 12 cases / 40 artifacts exact.
- Instrumented preservation: 15 artifacts exact for each diagnostic version.
- `git diff --check` passed; no configured lint command.

Raw drivers, source snapshots, original/candidate objects, input decks, outputs,
counts and logs remain under `.build/table-paint-reuse20`. The machine-readable
receipt in `docs/benchmarks/2026-10-04-table-paint-reuse-prototype.json` pins them.
Independent review, integrated platform/native acceptance and any formal timing
protocol remain parent-owned.

## Retained artifact clarification

The original receipt pinned the candidate object hash but omitted its path.
Following review, `.build/debug/Rostrum.o` was verified against that exact
pre-existing hash and copied to
`.build/table-paint-reuse20/candidate-Rostrum.o`. This is the Debug object used
for the untimed proof, not a new build. The baseline object was already retained
as `baseline-Rostrum.o`. Immutable production source archives are now explicitly
retained as `baseline-sources.tar` (dc40a98) and `candidate-sources.tar` (3bab3d5).
The receipt records each path, object/archive hash and Git Sources tree. The
instrumented source directories are separate diagnostic modifications, not
substitutes for the production source archives.

The budget edge case was also reviewed without changing source: when the
per-edge reservation exceeds the remaining estimated budget, `cost` receives a
negative limit. Its nonempty roots contribute a positive cost and immediately
reject admission, so the remaining budget is not decremented. Successful
admission requires `cost <= remainingCost - paintCost`, keeping the stored
remaining budget nonnegative. The cache's configurable internal test limit is
clamped to zero; the renderer uses its fixed default of 216 entries.
