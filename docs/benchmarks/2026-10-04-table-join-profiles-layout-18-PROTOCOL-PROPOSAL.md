# S18 table-join profile campaign proposal

Baseline is the retained matching Release build of accepted S17 production. Exact object/module/helper bytes are copied and pinned; this is not described as a fresh baseline build. Candidate adds frozen engine b5407e49 only in SVGRenderer.swift. All prior artifacts remain immutable.

One proposed campaign: canonical 110 children plus Unicode 66 plus 198 for nine table files, totaling 374. Each workload retains one excluded warmup pair and ten alternating fresh-process pairs. There are 18 primary render/richtext-fitting comparisons and 196 measured phases. Every phase and adverse result is retained. No adaptive rerun or implied speedup.

The table pool consists of the captured two-slide/eight-case native source plus eight 100×20 controls: existing LTR single-color, admitted RTL single-color, admitted axis colors, horizontal merges, vertical merges, rejected RTL+colors, rejected merge+colors, and unchanged uniform grid. Controls use explicit NoStyleGrid, exact embedded DejaVu Sans registration before render, dimensions exceeding the largest stroke, and unchanged direct text. Merged continuation cells retain the physical grid and empty hidden text. These controls are performance inputs, not additional native references.

Canonical/Unicode helpers are unchanged. The accepted S17 table helper is reused byte for byte; original rendering precedes any cell mutation and no new fitting phase is added. Both builds use identical source helper and flags. Source/native/protocol approval is separate from the explicit timing quiet grant.

Preservation expands prior168 cases/862 slides with nine files/ten slides to177 cases/872 slides, each in baseline and two candidate processes. Require exact saved packages, diagnostics, inheritance, full non-line SVG tree including text, and line paint attributes/counts. Only endpoint coordinates and paint order may differ in admitted profiles. Old/S17 controls and newly rejected profiles must be entirely byte-identical. Native112 glyph/paint assertions remain distinct from stress attribution. Fixed small/large/image preservation and full shaping/layout records are retained.

Final plan will pin all inputs, fonts, source tree, objects/modules, drivers and commands before independent review. Host snapshots will qualify ambient load. Statistics use100000 median bootstrap resamples, seed20261004, and exact sign tests, with process RSS and exact SVG bytes. No comparative timing is authorized yet.
