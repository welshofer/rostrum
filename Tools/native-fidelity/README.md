# Native text/table fidelity pack

Build a fixed offline corpus using **your chosen font files**. This is test
tooling, not a font policy or a change to the library's font resolution.
The pack extends the [native corpus](../../docs/CONFORMANCE.md) with four
profiles: true 4:3 and 16:9 canvases, each with external and embedded fonts.

Each profile includes inherited template text, tabs, soft breaks, a bullet,
mixed regular/bold/italic faces and sizes, and 24 table rows with measured column
widths, pagination and a repeated horizontally merged header. An optional
bold-italic face adds another run. It does not cover vertical merges, arbitrary
private templates, complex scripts, dynamic fields or native autofit equivalence.

## Run

Use Swift 6 and Python 3.11+ on macOS or Linux. Build outside the measured run:

```bash
swift build -c release --product native-fidelity
```

Create a private JSON manifest outside Git, using family names from the fonts'
name tables. Paths are absolute or relative to the manifest:

```json
{
  "family": "Your Font Family",
  "regular": "fonts/regular.ttf",
  "bold": "fonts/bold.ttf",
  "italic": "fonts/italic.ttf",
  "boldItalic": "fonts/bold-italic.ttf"
}
```

Regular, bold and italic are required; `boldItalic` is optional. The tool checks
family and style metadata, and refuses a missing or mismatched face. It uses
standalone TTF/OTF files and the library's embedding restrictions; collections,
variable-font instance selection and family aliases are outside this first pack.
Do not add proprietary fonts, private templates or generated packs to Git.

```bash
python3 Tools/native-fidelity/run.py \
  --binary .build/release/native-fidelity --build-mode release \
  --fonts /path/to/fonts.json --output /path/to/new-pack --runs 2
```

The collector refuses an existing output directory. Each sample runs in a fresh
process. Repeated profiles must produce identical PPTX, POTX, SVG, diagnostics
and planned geometry. A failed collection keeps `complete: false` and its log;
it must not be used as a passing pack. A single profile can also run directly:

```bash
.build/release/native-fidelity /path/to/fonts.json /path/to/new-case 4x3 external
```

Each case retains the source POTX, saved PPTX, per-slide SVGs and ordered
diagnostics, plus font identities, source row ranges, column widths, row
heights and portable text line/baseline geometry. Read-back checks cover words,
notes, sections, inherited text and soft
breaks, shape bounds, deterministic save, unchanged template parts, and identical
SVGs/diagnostics before and after reopening. Portable text must fit and retain its
line geometry; this does **not** prove native text fits inside its frame.
SVG diagnostics remain visible even if checks pass.

The top-level manifest records font, executable and artifact SHA-256 hashes,
source revision/dirty status, toolchain, platform and caller-declared build mode.
The source revision identifies the checkout, not a proven executable build;
the executable hash identifies the measured binary. Build it from that checkout.

## Measurements and native review

Reports retain per-phase elapsed and process CPU time for font input validation,
registration/embedding, template import, text/table planning and composition,
save, reopen, saved-font registration and all-slide SVG generation. Composition
includes the library's fresh checks. File writes and output verification are
outside those phase timings. Template serialization and fixture decoration are
also outside the named phases; do not sum them into an end-to-end claim.

The collector additionally measures whole-process elapsed, user/system CPU and
peak RSS, including verification, writes and both preview sets. It does not
measure OS font discovery, production Lectern rendering, WebKit thumbnails,
UI first-preview latency or native PowerPoint. These are pending in
[PLAN.md](../../PLAN.md). Small phase timings and these synthetic fixtures are
measurement probes, not a speedup claim or a production performance baseline.
Input hashing can warm filesystem caches before execution; fresh processes
reset library caches but do not establish a cold filesystem or native app start.

For each first sample of each profile on a Mac:

1. Install the exact manifest faces for the external-font profile. For embedded
   profiles, record whether the same faces are also installed; embedding alone
   does not prove which face PowerPoint selected.
2. Open the **saved** `deck.pptx` in Lectern Inspect and exercise its export path.
   Record diagnostics and thumbnails separately from the library SVGs.
3. Open the same bytes in PowerPoint for Mac, record its version, and review every
   slide in slide view. Capture letter spacing, wrapping, baselines, bullet
   visibility, clipping, header merges, captions and page boundaries.
4. Export PDF or images and review them separately. Previous overlapping glyphs
   appeared only in slide view; a good PDF cannot approve the slide-view result.
5. Record native evidence with the existing
   [export comparison workflow](../../Lectern/Tools/CompositionRegression/README.md).
   Keep a separate slide-view review record with the deck/font hashes, app
   version, installed-font conditions, reviewer and slide numbers. Leave any
   unreviewed path `pending`; portable checks never set native acceptance.

## Tool regression checks

The licensed repository fixture faces are used only for portable integration
tests; users can run the pack with any supported exact faces.

```bash
swift build --product native-fidelity
PYTHONDONTWRITEBYTECODE=1 python3 Tools/native-fidelity/test_pack.py
```

The suite generates all four profiles twice, checks independent ZIP/XML content,
geometry and font storage, and verifies refusal of mismatched/missing faces and
existing output. Set `ROSTRUM_NATIVE_FIDELITY_BINARY` to test another built binary.
