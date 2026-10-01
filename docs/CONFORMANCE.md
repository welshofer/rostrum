# Fidelity and conformance

Support is evaluated separately for read, author, edit, duplicate/import,
round-trip preservation and rendering. Preserving opaque XML does not imply the
renderer understands it. Animation is outside the current implementation scope.

| Feature | Current regression evidence | Independent evidence | Release reference |
| --- | --- | --- | --- |
| Tables | TableConformanceTests, TableTests, TableStylingTests, TableFillAtomicityTests | python-pptx 1.0.2 fixture with merges, borders, margins, mixed runs | PowerPoint slide export pending |
| Pictures/crops | PictureTests, SVGRendererTests | Producer deck corpus | Crop/tile visual reference pending |
| Typography | FontMetricsTests, TextRichnessTests | Font/shaping fixture oracle | Mixed-run slide visual reference pending |
| Speaker notes | NotesTests, DeckMergeTests | Producer deck corpus | Notes-page export pending |
| Comments | CommentsTests | Producer deck corpus | Office thread lifecycle check pending |
| Sections | SectionsTests | Producer deck corpus | Office membership check pending |

`Tools/conformance/make_table_fixture.py` authors the redistributable fixture
using python-pptx, independently of Rostrum. The manifest pins its hash,
producer, fonts and provenance. Originals are never edited by a test.

Run `swift test --filter TableConformanceTests` and
`python3 Tools/conformance/release_gate.py --semantic-only` for development.
`python3 Tools/conformance/release_gate.py` is the strict release gate: missing
Office, missing reference exports, semantic failures, repair or timeout fail.
Development success alone is not full-fidelity certification.

`Tools/ppt-check.sh FILE` checks an owned temporary copy through PowerPoint's
normal open path. It never closes an existing user document. Failed copies are
retained. System Events/Office automation must be available; an inaccessible
oracle fails rather than silently passing. Reference images must record Office
version, installed font hashes, export settings and comparison tolerance before
being accepted into the manifest. Do not replace a failing reference with a new
one just to make a test pass.

Benchmarks: `ROSTRUM_BENCH_FONT=/path/to/font.ttf python3
Tools/rostrum-bench/run.py --output /tmp/rostrum-bench.json`. The release driver
records cold process samples, median/p95, peak RSS, fixture/output hashes and
independent output parsing. Keep baselines per platform/compiler/font/corpus;
set regression limits from measured variance.
