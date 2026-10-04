# Lectern integration — October 2, 2026

This pass integrates the library work into Lectern's inspection, generation,
preview and export paths. Animation remains outside scope. The existing
[library implementation record](IMPLEMENTATION-20261002.md) retains the broader
Office fidelity results and open acceptance gates.

## Changes

- Inspect actual table cells with lazy rows and six-column paging. Store column
  counts once; preflight semantic and legacy table projections against independent
  one-million-cell budgets, each shared across the deck, before materializing
  dense matrices. In table text inspection and export, DrawingML prefix
  aliases, default namespaces, local rebinding, fields and explicit breaks are
  handled without modifying the presentation.
- Show section slide membership, speaker notes, complete modern threads and
  replies, resolved status, and legacy comments. Export these alongside original
  media bytes. A table projection override replaces inaccurate legacy table text
  rather than leaving conflicting duplicate tables in the Markdown.
- Register exact installed font families and regular/bold/italic/bold-italic
  faces for generation and inspection. Embedded faces retain priority. Validate
  collection PostScript identity and style names so Black does not become Bold;
  bound lookup, parsing and file reads. Gather inherited layout/master/theme
  declarations before preview measurement. Generation-only foundry aliases are
  reported, and unavailable metrics remain explicit.
- Preserve actual portrait, 4:3 and other slide aspect ratios in previews and
  snapshots. Cache keys include the complete SVG and output dimensions. Limit
  snapshots to 4096 pixels per axis and 4,194,304 pixels total, queue depth to 64,
  and active native requests to ten seconds. Cancellation releases queued and
  active requests without allowing stale completions to satisfy another slide.
- Move startup library scans off the main actor; coalesce requests and reject
  stale results. Serialize actual export completion even after UI cancellation.
  App-hosted tests use isolated defaults and owned temporary directories while
  retaining production startup work and avoiding real keychain reads.

## End-to-end evidence

The committed [feature fixture](../Lectern/Tests/LecternCoreTests/Fixtures/FeaturePipeline/README.md)
combines native/custom tables, merged cells and borders, rich text, an owned
image crop, notes, modern/legacy comments, replies, sections, duplication and
import. Its pipeline tests save, reopen, inspect and export, check deterministic
refresh, preserve input bytes, and verify expected fidelity diagnostics. The
independently produced Office table fixture is also inspected and exported.

A normal macOS app launch opened the authored fixture through the native file
chooser. The inspector displayed all four previews, section member numbers,
table contents, notes, resolved threads, replies and legacy comments. Export
reported four slides and two media files; both images matched the source PNG
byte for byte. A separate owned eight-column fixture exercised Next/Previous
column paging and accessible cell text.

Live interaction found a SwiftUI/AppKit accessibility recursion when selectable
cell text had a custom accessibility label. Removing that label and the unbounded
cell height fixed the crash; expanding and paging tables then passed repeated
accessibility and visual checks. The original crash report remains a historical
failure, not a passing result.

## Verification

Final code revision: `35cb03297844fa9b9ff4fd39e108b0890fdd872e`. Combined results,
source fingerprints, binary hashes, log hashes and native export hashes are in
the [verification receipt](benchmarks/2026-10-02-lectern-integration.json).

| Check | Result |
| --- | --- |
| Rostrum | 954 tests / 129 suites pass, 38.277 seconds |
| LecternCore | 192 tests / 19 suites pass, 8.913 seconds |
| Headless app harness | Pass; 59 reported tests / 15 suites, with the native WebKit test disabled; 8.907 seconds |
| Real macOS app-hosted tests | 59 tests / 15 suites pass, zero skipped or failed; 12.955 seconds |
| Native WebKit portrait and 4:3 snapshot case | Pass, 0.259 seconds |
| iOS simulator build | Pass; resulting executable contains arm64 and x86_64 |
| Normal macOS GUI | Open, inspect, expand tables, page columns, export and verify files pass |

The Rostrum run used `497a362`; its source/test/package inputs are unchanged in
the final revision. The other combined checks used the final code. Checks ran
concurrently on macOS 27.0.1 with Swift 6.4; durations are test results, not a
performance benchmark. The [headless input receipt](benchmarks/2026-10-02-lectern-app-headless.json)
records the copied app sources and separate harness log.

App-hosted tests exercise real WebKit portrait and 4:3
snapshots in addition to the headless state tests. The earlier hosted startup
failure documented in the library record is superseded for this tested Lectern
revision; that earlier receipt remains unchanged.

Independent review approved startup isolation, installed face selection,
namespace-aware extraction, canonical table export, the compatible Markdown API,
font discovery/registration wiring and table paging. Review caught and fixed the
Aptos Black/Bold mismatch, repeated row scans, conflicting export projections and
overbroad documentation claims. Root reran the combined checks and native actions
after integration.

## Scope and remaining limits

This is integration and regression evidence, not universal PowerPoint fidelity.
The prior table/typography whole-image failures, advanced shaping gaps, conflicting
notes-master/page-size import limitations, incomplete generic release gate and
Linux runtime gap remain open. This pass does not requalify those Office oracles.

The table viewer is a text projection: it does not reproduce merged visual cell
geometry. The source PPTX retains that geometry, and supported renderer paths
display it. Namespace-aware table text extraction does not establish support for
every namespace variant in the SVG renderer. Tables exceeding
the inspection cell budget fail explicitly. Unusual weight/stretch font aliases
are refused when the four-style registry cannot represent them without mislabeling
another family; unavailable faces still generate diagnostics. No proprietary font
files were added.

The native checks cover local opening, inspection, previews, table interaction and
export. Fixture providers cover generation; no paid live provider request was
made. iOS verification is compilation, not simulator/device interaction. Nothing
was pushed, published or deployed.
