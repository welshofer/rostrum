# Atomic font embedding — 2026-10-13

`Presentation.embedFont` previously changed content types, parts and relationships
before checking later faces. A restricted bold face could leave a regular-font
part behind without a declaration. Repeating an identical request also appended
duplicate families and parts.

The operation now prepares its changes before committing. Identical raw font
bytes reuse existing family/style declarations, missing styles are added in order,
and conflicting replacements fail without changing the saved package. Existing
EOT wrappers, namespace bindings, opaque markup and omitted styles survive.
Oversized EOT name/size fields throw before integer conversion. Untyped resources
and unrelated content-type defaults remain intact.

## Release measurement

Linux x86_64, Swift 6.1.3, optimized builds. Baseline: the embedding implementation
at `364138f`; candidate: this change. Five alternating baseline/candidate process
runs per workload, medians below. Elapsed time uses a monotonic clock; CPU is
`wait4` user + system time, and memory is per-process peak RSS. These are small,
fixed-input measurements on a shared cloud host, not whole-deck generation claims.

Each process loads the same caller-supplied Calibri regular, bold, italic and bold
italic files (1,336,244 raw bytes total), creates one deck, embeds all four faces,
registers them for
measurement, and adds a 24 pt text box. It then performs either 100 additional
identical requests on that deck, or 100 first-time embeddings in fresh decks.
Measurement includes startup and this common setup; it excludes serialization
and SVG rendering. Private font files and generated decks are not committed.

| Workload | Elapsed, before → after | CPU, before → after | Peak RSS, before → after |
|---|---:|---:|---:|
| 100 repeated four-face requests | 90.8 → 39.8 ms | 90.3 → 39.5 ms | 152.3 → 23.5 MiB |
| 100 fresh four-face embeddings | 92.0 → 91.2 ms | 91.2 → 90.5 ms | 24.4 → 24.5 MiB |

The repeated workload retains **4 font parts instead of 404**, with about 56%
less CPU and 85% lower peak memory. Fresh embedding performance is effectively
unchanged at this scale. Every repeat rechecks current supplied and embedded
bytes; there is no persistent cache that can hide a changed font.

## Preservation and acceptance

- Regression tests reproduced the partial-write and duplicate-font failures on
  the baseline. Refusals and repeated calls now compare the entire saved package.
- 39 focused tests pass in debug and Release, covering embedding, import,
  registration, style merging,
  license checks, changed bytes, malformed references, namespace aliases, opaque
  metadata, untyped resources, and EOT name boundaries.
- A first-time four-face Calibri deck remains byte-identical in both debug and
  Release builds: PPTX 854,023 bytes, SHA-256
  `08ed8a76f5ec7e3b0bbe4a5976d5d3e5c8e4d6552103cf31787a7fd69e804928`;
  SVG 439,748 bytes, SHA-256
  `5c34e3a5c6076c5bb01d7368dd86144575e344c61dc896cc4023febcb0c72d7f`.
- Local Arial and all four Calibri faces retain exact bytes, advances and SVGs
  after repeated embedding and two slide imports. Saved 5-slide and 11-slide
  decks open with python-pptx and pass ZIP CRC checks.
- All 17 Fonts and Fitting Library Lab checks pass, including identical embedding before saving
  and after reopening, conflict refusal, exact recovered bytes and one retained
  relationship through the normal export/inspection pipeline.
- `scripts/verify.sh --fast` passes: 1,357 root tests, 63 optimized layout tests,
  309 Lectern tests, portable fidelity references and README examples. Native app
  builds and app-hosted tests remain CI checks; they were not run on Linux.

Font choice remains caller-owned; bundled fonts are offline test fixtures.
These checks do not establish native PowerPoint acceptance. In particular, the
reported PowerPoint for Mac slide-view overlap remains a separate rendering issue.
