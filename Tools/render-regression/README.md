# Paired renderer checks

Compile the same `main.swift` against separately built baseline and candidate
release libraries. The driver renders identical synthetic 10,000-cell tables
and 250-image slides, recording SVG, ordered fidelity issues, inheritance flags
and timings. Text uses the same deterministic unregistered-font fallback in
both binaries. This measures warm rendering, separately from the existing
fresh-process `rostrum-bench` scenarios.

On the Xcode-backed SwiftPM layout used for the October 2026 measurements:

```sh
swift build --disable-sandbox --scratch-path /path/to/build -c release -debug-info-format none --product rostrum-bench -j 2
swiftc -O -I /path/to/build/out/Products/Release Tools/render-regression/main.swift /path/to/build/out/Products/Release/Rostrum.o -o /path/to/render-driver
```

Use separate scratch and module-cache paths for separate checkouts. Retain each
compiled driver before building the next revision. Other SwiftPM build engines
may use different object/module locations.

```sh
python3 Tools/render-regression/run.py --baseline /path/to/baseline-driver --candidate /path/to/candidate-driver --baseline-revision BASE_SHA --candidate-revision CANDIDATE_SHA --output /path/to/comparison.json --work-dir /path/to/render-outputs
```

The runner alternates AB/BA invocation order, excludes each invocation's first
sample, retains all samples and binary/driver/output hashes, and fails if SVG or
diagnostics differ. It does not assert a universal timing threshold. Run without
concurrent builds or profiling; use repeated comparisons for small differences.
Output directories can be large and should remain outside version control.

The driver also accepts `file:/absolute/path/deck.pptx`. Set
`ROSTRUM_PROFILE_FONTS` to pipe-separated font paths for manual visual checks;
the paired synthetic runner is intended to run without that environment variable.
It never changes the input deck. Pixel comparison against Office remains the
separate, unchanged `Tools/conformance/check_text_rendering.py` gate.

## Explaining an existing pixel failure

The supplemental diagnostic partitions this specific v3 fixture into its known
stroke zones and remaining text. It also renders a standalone fractional-width
line to separate rasterizer coverage from Rostrum geometry. It invokes the
unchanged pixel comparator; diagnostic completion is not an acceptance pass.

```sh
python Tools/render-regression/analyze_fidelity.py --candidate /path/to/font-corrected.png --reference Tests/RostrumTests/Fixtures/Conformance/python-tables-v3-office.png --candidate-revision SOURCE_SHA --output /path/to/diagnostic.json
```

Use the same pinned Pillow 12.3.0 and resvg-py 0.5.0 environment as the text
comparison adapter. The fixed zones are valid only for the 1200×700 v3 fixture.

## Compare the existing Office vectors through the same backend

`office_vector_diagnostic.py` uses the pinned v3 notes PDF's slide-background
rectangle to define the crop. It checks PDF glyph outlines against the supplied
font files, records glyph origins/advances, and compares the cropped Office
vectors and Rostrum through resvg. There is no fit to the PNG. Notes-print text
has separately rounded sizes/baselines, so this is attribution, not acceptance.

```sh
python3 Tools/render-regression/office_vector_diagnostic.py extract --pdf Tests/RostrumTests/Fixtures/Conformance/python-tables-v3-notes-office.pdf --candidate-svg /path/to/candidate.svg --fonts /path/to/fonts.json --output-dir /path/to/vector-scratch
python Tools/render-regression/office_vector_diagnostic.py raster --vector-dir /path/to/vector-scratch --candidate-svg /path/to/candidate.svg --fonts /path/to/fonts.json --office-png Tests/RostrumTests/Fixtures/Conformance/python-tables-v3-office.png --output /path/to/attribution.json
```

Extraction requires PyMuPDF 1.27.2.3, fonttools 4.60.1, and `hb-shape` 14.4.0;
rasterization requires Pillow 12.3.0 and resvg-py 0.5.0. Separate interpreters are
supported. Font-embedded SVG and extracted glyph paths remain local scratch
artifacts; no font binaries or extracted outlines belong in fixtures. Reports
record cell-region counts, overlapping difference masks, and PDF crop artifacts.
Pairwise thresholded masks are not additive error contributions.

## Dense and sparse image relationship workloads

The retained `fixtures/dense2000-images.pptx` contains 2,000 valid, distinct 1×1
PNG images/rIDs. `fixtures/sparse-image-relationships.pptx` has two early image
rIDs among 4,096 relationships; the other arcs are unused external hyperlinks
and are not fetched. These are owned stress controls, not representative image
content. Their generators require python-pptx 1.0.2 and refuse existing output:

```sh
python3 Tools/render-regression/make_dense_image_fixture.py /tmp/dense2000.pptx
python3 Tools/render-regression/make_sparse_image_fixture.py /tmp/sparse-images.pptx
python3 Tools/render-regression/run.py --baseline /path/to/baseline-driver --candidate /path/to/candidate-driver --baseline-revision BASE_SHA --candidate-revision CANDIDATE_SHA --output /path/to/comparison.json --work-dir /path/to/render-outputs --iterations 100 --scenarios images-unique images-repeated file:/absolute/path/dense2000.pptx file:/absolute/path/sparse-images.pptx
```

Choosing scenarios does not weaken exact SVG/diagnostic checks. Use 100
iterations for 99 measured samples per invocation, 198 per variant in AB/BA order.

## Pending direct-slide typography reference

`fixtures/text-baseline-v1.pptx` and its `.manifest.json` contain 30 explicitly
authored single-cell cases across three slides: individual font/size metrics,
size transitions with default/explicit line spacing, and mixed-run wrapping.
The manifest records geometry, fonts, runs, margins and capture instructions.
There are no Office references or acceptance results yet. Regeneration and
reopening checks are available without Office:

```sh
python3 Tools/render-regression/make_text_baseline_fixture.py --verify
```

The Office-session owner should export a direct-slide PDF at original slide
dimensions and PNGs at 1200×700 and 2400×1400. Pin new references independently;
do not replace the existing v3 PNG gate or infer golden pixels from the manifest.
