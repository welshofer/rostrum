# Performance and fidelity implementation record — 2026-10-01

Current integrated status: [October 2 implementation and verification](IMPLEMENTATION-20261002.md).
The checkpoint details below remain historical evidence.

This is the preserved initial-pass record. See the [follow-up](IMPLEMENTATION-FOLLOWUP-20261001.md)
for subsequent implementation, Office references and current verification.

Work is committed locally on `codex/burndown/20261001`. No PR, push, merge or
deployment was performed. This is a substantial implementation with explicit
acceptance gaps, not a claim of complete or perfect feature support.

The pull was already current at `a35e7b14da2ae1130616bb2b3af9ac766cd23ef2`.
Final tested library code is `e3fc99bc790d7d7c23ca2acacd8f5274d3bdf3cd`;
later documentation commits do not change it. Animation was excluded.

Of 18 scoped items, **11 have local implementations within documented contracts,
6 are partial, and 1 has a blocked acceptance gate**. The Office gate applies to
the whole feature program, including items with passing local tests. Nothing is
labeled shipped. The original audit remains local scratch; this compact record,
[conformance matrix](CONFORMANCE.md), [performance evidence](PERFORMANCE.md),
CHANGELOG and ROADMAP retain the durable outcome.

## Item disposition and evidence

Commit IDs identify the primary implementation, with later corrections listed
where material. Each test name is a source-level evidence pointer, not an Office
certification.

| Item | Status | Implementation, checks and remaining scope |
| --- | --- | --- |
| PERF-1: benchmarks | Partial | `44afb8b`: [release driver](../Tools/rostrum-bench/run.py), 12 local scenarios, one warmup/five samples, RSS/hashes and python-pptx reopen. macOS measurements are recorded; Linux/iOS baselines and defensible regression thresholds remain open. |
| PERF-2: traversal | Implemented locally | `c20e468`: [TableGridSnapshot](../Sources/Rostrum/Presentation/TableGridSnapshot.swift) and operation-local slide/table snapshots. Table and iteration tests pass; large-table population/style and slide traversal gains are measured. |
| PERF-3: media index | Implemented locally | `c20e468`, `84e78c5`: [OPCPackage](../Sources/Rostrum/OPC/OPCPackage.swift) indexes size/CRC and confirms exact bytes, invalidating replaced/removed entries. CRC-collision and mutation tests pass. Image insertion is approximately unchanged in the final timing run. |
| PERF-4: bounded archive access | Implemented locally | `c20e468`, `05b8574`: [OPCArchive](../Sources/Rostrum/OPC/OPCArchive.swift), Data-backed ZIP reads, bounded lazy payload cache, explicit validation timing and compressed/decoded input budgets. `ArchivePerformanceContractTests` pass. Linux execution remains a platform gate. |
| PERF-5: streaming saves | Implemented locally | `c20e468`, `05b8574`: [writeAtomically](../Sources/Rostrum/OPC/OPCPackage.swift) streams to a sibling, preserves existing permissions, publishes with rename and evicts replaced cache payloads. Directory-destination refusal, retained-old-part, deterministic save and foreign-deck tests pass on macOS. |
| FUNC-1: tables | Partial | `7c5d551`, `3db65ea`, `e057f57`: [structural edits](../Sources/Rostrum/Presentation/TableEditing.swift), [style resolution](../Sources/Rostrum/Presentation/TableStyleResolver.swift), [style graph import](../Sources/Rostrum/Presentation/TableStyleImport.swift). Contract/conformance/style/import tests pass. Native GUID-only style catalog, advanced vertical text, pattern/compound-border preview and Office equivalence remain open. |
| FUNC-2: rich layout | Implemented locally | `6cf070b`: [RichTextLayout](../Sources/Rostrum/Presentation/RichTextLayout.swift) shared by font-registry fitting and rendering; mixed runs, fields, breaks, tabs, bullets, spacing, insets and autofit regressions pass. Unsupported layout/script cases remain diagnosed under FUNC-3/USE-1. |
| FUNC-3: font faces and shaping | Partial | `6a4a33c`, `c84ffca`: [face selection](../Sources/Rostrum/Fonts/FontLibrary.swift), [TextShaper](../Sources/Rostrum/Fonts/TextShaper.swift), bounded OpenType expansion. Face, HarfBuzz fixture and adversarial layout-budget tests pass. Contextual Arabic/Indic, mark positioning and complete Unicode bidi/line breaking remain open. |
| FUNC-4: images/crops | Implemented locally | `879dac0`, `1153339`, `3eeed89`, `e3fc99b`: [PictureCrop](../Sources/Rostrum/Presentation/PictureCrop.swift), isolated replacement, shared stretch/tile mappings and transforms. Picture mapping tests and 14 independent raster probes pass. Alternate/layered/linked image replacement refuses atomically; Office comparisons remain under REL-1. |
| FUNC-5: comments | Implemented locally | `c5de4ac`: [modern editing](../Sources/Rostrum/Presentation/CommentEditing.swift) and [legacy comments](../Sources/Rostrum/Presentation/LegacyComments.swift). Edit/status/delete/reply/author/anchor and save-reopen tests pass. Shape/text anchor authoring is limited to supported top-level shapes; Office lifecycle coverage remains under REL-1. |
| STAB-1: atomic table fills | Implemented locally | `d3fde15`: [TableCell.setFill](../Sources/Rostrum/Presentation/Tables.swift) prepares replacement before mutation and preserves schema order. `TableFillAtomicityTests` cover rejected fills and untouched dirty state. |
| STAB-2: shared colors | Implemented locally | `566d1dd`, `eae62a4`: [DrawingColor](../Sources/Rostrum/Drawing/DrawingColor.swift) and background/theme resolution share transformed colors. Background regressions and single-application alpha tests pass. Unsupported transforms are diagnosed. |
| REL-1: independent conformance | Acceptance blocked | `e01163e`, `4c6e75b`, `448f47b`, `f0c3d89`: independent table fixtures, pinned original Office PNG, semantic checks and fail-closed release gate. Earlier raster comparison failed; final preview still diagnoses style/font gaps. Notes references and the corrected fixture's Office slide reference are missing. Scripted Office automation timed out. |
| REL-2: independent annotations | Implemented locally | `83c1f19`: [SlideAnnotations](../Sources/Rostrum/Presentation/SlideAnnotations.swift) copies private notes/comment graphs and retargets backlinks/anchors. Duplicate-edit-remove, independent IDs and shared legacy references pass regression tests. |
| REL-3: authors/anchors | Partial | `2b16874`, `21791b7`: [AnnotationImport](../Sources/Rostrum/Presentation/AnnotationImport.swift) uses durable identities, remaps authors/anchors and stages changes atomically. Relationship-bearing author parts currently refuse cross-package import because their unknown dependency graphs are not yet transferred. |
| REL-4: sections | Partial | `940cde9`, `21791b7`: [Sections](../Sources/Rostrum/Presentation/Sections.swift) maintains membership through slide lifecycle and preserves member metadata during section operations. Section/metadata tests pass; namespace-aliased section mutation currently refuses to avoid corruption. |
| REL-5: notes appearance | Partial | `197415a`: [DeckMerge](../Sources/Rostrum/Presentation/DeckMerge.swift) preserves source notes master/theme/media/page size and reuses equivalent graphs. Conflicting masters/page sizes refuse atomically; appearance reconciliation and Office notes-page references remain open. |
| USE-1: fidelity status | Implemented locally | `1a7591a`, `9bf3c13`, `586d459`, `f0c3d89`: [SVGRenderer](../Sources/Rostrum/Presentation/SVGRenderer.swift) returns located issues, optionally throws in strict mode and embeds permitted registered font faces. Diagnostic/strict/nonmutation tests pass; passing strict mode is not universal conformance. |

## Verification

Final library code, macOS 27.0.1 / Apple Swift 6.4:

- `ROSTRUM_IMAGE_ORACLE_OUTPUT=.build/image-oracles swift test`: **820 tests,
  105 suites, passed** (32.260 s), including four existing foreign-deck cases.
- `swift test` in `Lectern`: **162 tests, 14 suites, passed** (6.324 s).
- `swift run ReadmeSnippets /tmp/rostrum-readme-final`: passed after creating
  its required output directory.
- `python3 Tools/conformance/release_gate.py --semantic-only`: passed both
  independent table fixtures with python-pptx 1.0.2.
- `python3 -m unittest discover -s Tools/conformance -p 'test_*.py'`: 2 passed.
- `check_image_mapping.py` with resvg-py 0.5.0 / Pillow 12.3.0: **14/14 exact
  raster probes passed**. This is an image-mapping oracle, not a text or Office
  raster oracle.
- Release benchmark: all 12 scenarios and independent output reads completed.
  [Committed synthetic samples](benchmarks/2026-10-01-macos.json) retain the
  original measurements. Table population/style improve; rendering and total
  peak RSS regress. Both directions are reported.
- Permissive CLI rendering succeeds and prints fidelity issues. The same table
  fixture under `--strict` exits 1 for unresolved native style, missing Calibri,
  viewer font dependency and unsupported OpenType lookup flags.
- `git diff --check`: passed. No separate linter is configured. A release
  executable build is included in the benchmark driver.

`python3 Tools/conformance/release_gate.py` exits **1**, with these mandatory
preflight failures:

```text
python-tables.pptx: required powerPointReference candidate render missing
python-tables.pptx: required notesPageReference missing
python-tables-v2.pptx: required powerPointReference missing
python-tables-v2.pptx: required notesPageReference missing
```

The preflight intentionally prevents launching Office when required inputs are
missing. Earlier Office scripted verification timed out; a separate UI opening
and export of the owned original fixture observed no repair dialog. That does
not substitute for the failed release gate. The earlier 4.087% table pixel
difference predates final font embedding and is not a final-render measurement.

Linux runtime checks and the full Lectern macOS/iOS app build and app-hosted
tests were not executed for this run. The Docker daemon was unavailable; Linux
Foundation source inspection is not counted as a passing runtime check. Local
test success is not reported as remote CI success.

## Execution and review provenance

The host-selected root agent integrated changes sequentially on the working
branch. Three workers used isolated Git worktrees; the concurrency limit was
four agents including root:

| Worker | Recorded model | Isolated branch / worktree |
| --- | --- | --- |
| `implement_tables` | `gpt-6-astra`, high | `codex/burndown/tables-20261001`, `/Users/welshofer/.codex/worktrees/rostrum-tables/rostrum` |
| `implement_fonts` | `gpt-6-astra`, high | `codex/burndown/fonts-20261001`, `/Users/welshofer/.codex/worktrees/rostrum-fonts/rostrum` |
| `implement_metadata` | `gpt-6.1-sol`, high | `codex/burndown/metadata-20261001`, `/Users/welshofer/.codex/worktrees/rostrum-metadata/rostrum` |

Feature workers ran focused tests before integration. Integration checks covered
the shared table/color/text code, metadata lifecycle, image mappings and package
paths; final full-suite results above supersede intermediate counts.

Independent read-only review was applied across scopes. The metadata worker
reviewed font parsing and found aliased-offset expansion, then implemented the
budget correction. The fonts worker reviewed metadata preservation and later
implemented table-style graph transfer; metadata independently reviewed that
transfer and its corrections. The tables worker reviewed root package changes,
finding directory replacement, compressed-input budgeting and cache-retention
issues, then approved their fixes. It also identified and approved the final
SVG definition-count correction. The fonts worker approved the root fidelity
diagnostic changes and corrected the documentation's font-registry overload.
Metadata approved the final no-table-style import fast path.
Its final evidence review recomputed the benchmark summaries and checked the
status totals and logs; the raster-oracle coverage wording was corrected to
separate image pixel probes from background structural tests.

Reviews between the recorded Astra and Sol workers were cross-model; other
independent passes are not represented as cross-model when the root model
identity was not recorded. Root re-read the final source at the evidence links
and checked the named regressions. Remaining limitations are explicit above
and in ROADMAP, rather than treated as completed acceptance.
