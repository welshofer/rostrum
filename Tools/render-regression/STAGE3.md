# Historical comparison and image scaling controls

See [the measured follow-up](../../docs/ISOLATED-PERFORMANCE-20261002.md) for
results, limits and source identities. Existing paired and visual acceptance
tools remain unchanged.

`historical_compare.swift` compiles against both historical and modern Rostrum.
Build each library in a separate release directory, then compile this same
source with `swiftc -O -parse-as-library`, its matching module/object and an
isolated module cache. Modern builds additionally define
`-DROSTRUM_HAS_FIDELITY`; this affects only diagnostic capture outside timing.

`compare_eras.py` requires baseline/candidate binaries, their matching source
directories and revisions, an immutable PPTX, declared build flags, and new
output/work paths. For the retained experiment use `--runs 20 --warmups 1
--iterations 4 --pixel-width 1280`. The runner captures source/input/binary
hashes and checks them again after sequential AB/BA execution. Output serialization
occurs outside the timed render. First renders and later warm renders remain
separate. No fonts are registered. The source-to-binary linkage is caller
provenance; retain build logs and actual commands. Changed output semantics
are explicitly reported, never treated as an equivalence or acceptance pass.

Generate threshold controls from the retained, hash-pinned, owned 2,000-image
fixture with:

```sh
python3 Tools/render-regression/make_image_scale_fixtures.py --output-dir /path/to/new-fixtures
```

This requires python-pptx 1.0.2, refuses existing outputs, removes trailing
pictures and their relationships/media, verifies reopening and exact package
counts, and records hashes/provenance. The original fixture stays unchanged.
Use the existing `run.py --scenarios file:/absolute/path/input.pptx ...` interface
for exact SVG/ordered-diagnostic comparisons. A layout relationship adds one
to the picture count; 510 and 511 pictures straddle the 512-relationship policy.

Timing runs should have no concurrent builds or sampling. Preserve raw samples
and unfavorable measurements; stress-fixture gains are not general guarantees.
