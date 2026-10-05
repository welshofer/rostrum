# S17 table fidelity cost: preparation protocol

Status: baseline and fixed inputs prepared; candidate source is not frozen. This proposal does not authorize timing. No changing worker source is copied. Candidate builds/proofs wait for the approved engine commit; a later complete executable plan must pin both binaries and pass independent review before the root grants a quiet window.

Baseline: root `a88540380d4b041af08f1db21f3224337ddd4c01`, fresh complete Release object/module/compiler/source pins in `baseline-pins.json`. Candidate will be this baseline plus the frozen S17 engine commit, with any additional differences surfaced before proceeding. No production optimization is presumed or added by this lane.

## Proposed one-run comparison

- 110 children: unchanged canonical five workloads, including fallback/registered tables and fitting.
- 66 children: unchanged Unicode Latin, mixed RTL and long-combining controls.
- 286 children: 13 file workloads with embedded DejaVu Sans, each using one excluded warmup pair and ten alternating retained fresh-process pairs.
- Total: **462 children**, expected **22 primary render/fitting comparisons**. Expected **240 total phases**, to be verified against functional helper output before freeze. All phases, raw samples, process RSS and SVG byte counts remain reported; no adaptive rerun or selective omission.

The file workloads are three captured native sources (12 cases total); absent applied-ID tables at 20×10, 100×20 and 200×50; explicit built-in style controls at 20×10 and 200×50; absent/custom-explicit 20×10 controls; mixed-width opaque solid unmerged joins at 20×10 and 100×20; and a uniform-width 100×20 control. Large controls derive from the independently authored native table package, retaining direct text settings and the exact embedded font. They are performance stress inputs, not additional native fidelity cases.

The original deck renders before the existing one-cell-edit/save validation. No new mutating fitting phase is introduced. Registration of embedded fonts and exact sfnt-byte verification occur outside render timing. Canonical and supplementary drivers remain unchanged. A separate `table-main.swift` differs from the prior native file helper only in its post-edit verification: it locates the first TableFrame instead of assuming the first shape is a table, since native sources have labels. The same helper source and compile flags will link against both builds. The measured render code is unchanged.

## Correctness before timing

1. Full candidate library/RostrumLayout tests, Release build and diff check; native source owner retains negative baseline and positive paint/diagnostic evidence. Root owns app/platform/PowerPoint acceptance.
2. Fresh baseline and candidate repeated corpus outputs, extending the previous 155-case /849-slide corpus with the new 13 files. Keep SVG, ordered diagnostics, saved packages, deterministic repeats and independent python-pptx reopen proof. Exact comparison is required outside the affected policy, not blindly across all old absent-ID tables.
3. Classify every changed old/new table. Absent applied ID can change style-derived cell paint and text properties; the native support here establishes bounded fill/stroke behavior only and does **not** establish general text parity. Unmerged opaque solid mixed-width joins may change bounded border geometry/order. Explicit applied styles, uniform joins and rejected paint/topology contexts must be separately checked. No broad SVG stripping can silently accept unrelated changes.
4. Pure read/render/save package bytes must remain unchanged and deterministic, including original native sources. Small/large/image-heavy preservation checks and external reopening remain required.
5. Include live DOM/alias/relationship tests from the source owner and differential merge proof. Merge is a separate explicit mutation: candidate must preserve absent applied IDs through import; a baseline-stamped versus candidate-absent ID difference is classified intentionally, not falsely claimed as cross-version package identity. Source packages must remain untouched by import, and merged outputs must save/reopen deterministically. Inspect direct styles, explicit IDs and unknown XML too.
6. Reuse the standalone shaping and layout record oracles. Any affected inherited-table text records must be identified with the applied-style decision rather than waived by an all-output exception.

## Measurement and claims

Freeze full Git/source/object/module/compiler/helper/input/font pins, all functional proof results, exact commands and environment semantics. Fresh host process snapshots at start/during/end are mandatory. Root and other lanes must pause builds/tests/GUI; uncontrolled user/background load remains qualified, with no settings changes. Report progress at 60 seconds and immediate release at campaign completion.

Use paired percentage deltas, 100,000 seeded bootstrap median resamples (20261004), exact two-sided sign tests excluding ties, all secondary phases and whole-process RSS. Separate fidelity cost, observed wins and inconclusive/adverse controls. No clean-host, universal nonregression, historical cumulative recovery, text-parity or cross-platform speed claim follows from this run.
