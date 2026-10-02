# Performance and fidelity follow-up — 2026-10-01

This record follows [the initial implementation](IMPLEMENTATION-20261001.md).
This preserves the October 1 follow-up checkpoint. Work remains local on
`codex/burndown/20261001`. The pull was already current;
no push, PR, merge or deployment was performed. Animation remains excluded.
This is a tested expansion of supported operations, not complete table or
PowerPoint fidelity certification.

## Changes and evidence

- **PERF-1 / FUNC-1:** lazy diagnostic paths, render-local media reuse and a
  bounded table-style template cache remove repeated work. Style caching retains
  byte-identical SVG and ordered issues across 888 style/flag cases. The warm
  10,000-cell Grid comparison improves from 381.966 to 244.342 ms within that
  stage. [Performance evidence](PERFORMANCE.md) preserves raw samples and
  comparability limits; the earlier renderer/RSS regressions remain recorded.
- **FUNC-1 / STAB-2:** all 74 native GUID-only styles, correct No Grid identity,
  theme-owned references, linear-light tint/shade and Office interpolation for
  endpoint-pair/mirrored-three-stop gradients. Independent Office exports pass 1,480 cell-fill probes.
  Shared-border ownership now handles invisible edges, alpha, dash gaps,
  merged continuations and RTL; 737 probes across 42 cases pass. Border work
  does not regress the targeted warm render timings. Whole-image fidelity,
  compound borders, pattern fills, effects and advanced vertical text remain
  incomplete.
- **FUNC-3:** GDEF classes/lookup filtering, staged Arabic joining and contextual
  substitution, single-component ligatures and validated wrapped legacy kern
  tables used by Calibri. Owned Unicode/font fixtures and pinned HarfBuzz 14.4
  oracles cover these contracts. Local Arial/Calibri binaries are opt-in test
  inputs and are not redistributed. Arabic marks/cursive attachment, full RTL
  paragraph geometry, Indic and complete bidi/line breaking remain incomplete;
  known unsupported shaping and RTL cases are diagnosed.
- **REL-4:** namespace-aware section mutation preserves original prefixes,
  inherited markup-compatibility policy and XML language/space context.
  Unrepresentable destination-context conflicts fail atomically.
- **REL-3:** imported author graphs preserve custom XML/binary/media parts,
  external relationships, cycles, identity and references to the merged author
  list. Graph comparison and traversal have explicit budgets; ambiguous author
  metadata conflicts and defined Office semantic dependencies refuse atomically.
  Ordinary imports and a standard customXML author graph open in PowerPoint
  16.113.3 without repair. An earlier synthetic fixture's unsupported custom
  relationship type caused repair even before import; it was isolated by
  source/import and relationship/extension variants, not accepted as a pass.
- **REL-5:** newly authored notes have printable slide-image and body geometry.
  New notes inherit actual foreign-master placeholder IDs, and existing masters
  stay unchanged. The default master retains its background; aliased/default
  notes-size namespaces are recognized. Office PDF/PNG references verify the
  authored page. One same-size imported notes page matches its source PNG
  exactly. Conflicting masters and page sizes still refuse atomically.

## Visual acceptance remains open

The v3 independent table fixture corrects border ordering and explicitly
registers its notes master, which python-pptx 1.0.2 omitted. Earlier fixtures and
references remain preserved. V2/v3 slide and notes references were exported
through PowerPoint's normal UI without repair.

The offline SVG comparison initially substituted fonts because resvg ignores
CSS `@font-face` data URLs. A new fail-closed adapter verifies embedded-font
hashes against supplied local files, resolves generated aliases and disables
system fallback. It also checks reference dimensions/viewBox aspect.

The final font-corrected v3 result is **18,145 / 840,000 pixels (2.1601%)** over
channel tolerance 16, exceeding the unchanged 0.5% limit. The candidate and
[comparison report](../Tests/RostrumTests/Fixtures/Conformance/python-tables-v3-comparison.json)
are committed separately from the Office reference. Stroke-edge antialiasing
and small text offsets remain. Neither fill/border probes nor an empty render
diagnostic report establishes whole-slide equivalence.

## Verification and remaining platform scope

The final combined library suite at `2783ea3` passed **903 tests / 119 suites**
in 35.207 seconds, including the final author-context corrections. Focused local Calibri tests passed, as did 14 image mapping probes,
1,480 native-style fill probes, 737 border probes, all three python-pptx semantic
fixtures and seven Python comparator tests.

At integrated revision `2783ea3`, Lectern's 162 tests / 14 suites passed in
6.957 seconds. Its macOS and iOS simulator builds passed after regenerating the
stale ignored Xcode project. The app-hosted run failed: the runner hung before
establishing a connection (353 seconds). A process sample located startup
filesystem enumeration through `DeckLibrary.decks`; it was not a completed test
run. An attempt to inspect the app window also timed out.

At the earlier isolated metadata revision `1b1d283`, 30 app-hosted tests had
passed; that does not supersede the final integrated failure. Linux runtime
validation remains unavailable because the Docker daemon is not running.
Apple-platform compilation is not runtime or remote CI success.

The final release driver at `2783ea3` completed all 12 scenarios with one warmup
and five samples, independent output reopening and deterministic synthetic
hashes. Table render median is 217.752 ms; unique-image render is 2.940 ms.
Peak table RSS is 199.375 MiB. The [full report](benchmarks/2026-10-01-final-macos.json)
and [interpretation](PERFORMANCE.md) preserve output-semantics caveats.

Final opt-in checks also passed four local Arial filtering cases, 40 local Arial
Arabic cases, 300 expanded DejaVu Arabic cases and the pinned Calibri cases.
README snippets ran successfully. These are shaping/semantic checks, not proof
of complete paragraph or visual fidelity.

## Review provenance

The existing isolated table, font and metadata workers continued with their
recorded models: tables/fonts `gpt-6-astra` high; metadata `gpt-6.1-sol` high.
Root integrated sequentially. Metadata independently reviewed color/shaping and
font compatibility; tables reviewed author graphs and inherited context; fonts
reviewed sections and notes. Root inspected final code and independently ran
Office opens/exports and raster comparisons.

Review and integrated tests caught missing notes background, a namespace-literal
notes-size regression, an opaque-extension placeholder traversal issue,
synthetic author context attributes and ambiguous QName-valued root metadata.
These were corrected and covered with regressions. The visual comparator's
font substitution and rounded viewport were fixed as test-harness defects;
existing tolerances were retained.
