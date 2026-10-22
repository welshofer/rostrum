# Native performance and fidelity — 2026-10-22

Shared-font loading remains disabled. Native evidence does not support adoption.
The fidelity review found preserved content with documented chart, font and text-layout
limits. The historical typography checker now handles current scalar-positioned SVG
text while preserving its existing failing raster gate.

## Scope and environment

- Recovered library baseline: `38511b1c94f161c880e7391fad42eb341577da5e`.
- Tooling and evidence fixes: `103ba79c0a38f2076b1d4306bc67badc21ab8463`.
- Production app and rendering sources remain unchanged from that baseline.
- Execution was confirmed on Darwin before work began; macOS 27.0.1 (26A434), arm64.
- Xcode 27.1 (27A9275); fresh Release inspector and native test-host evidence.
- PowerPoint 16.114 (16.114.26101123) supplied the new slide-view and print-PDF review.
- Historical typography references remain the original PowerPoint 16.113.3 captures.
- Local signing settings and pre-existing local changes were preserved.
- Private inputs, screenshots, fonts and detailed receipts remain local and ignored.
- No reference image, font fingerprint or acceptance tolerance was changed.

The 33-slide review compares actual PowerPoint slide view, controlled print PDF and
native WebKit inline snapshots. Native snapshots are not production-window screenshots
or first-visible-frame measurements. Generated layout review covers both PowerPoint
endpoints, with SVG structure and supplemental raster checks kept separate.

## Five-pair native preview comparison

One isolated universal Release build at `103ba79` supplied twelve fresh native
profile processes: one warmup per mode, followed by five alternating measured pairs.
Each process performed first-use and repeated inspection. All 33 standalone SVGs and
ordered diagnostics matched across all twelve processes; input, tracked source, host,
test bundle and resources retained identical fingerprints. All 14 native regressions
passed afterward on the same build, without skips (18 parameterized executions).

The collection completed, but exact-pixel acceptance **failed**. Measured shared runs
1, 2 and 4 differed on slides 33, 16 and 33 respectively; the other three shared
comparisons, including warmup, matched all 33 slides. All process/operation samples and stage totals are retained in
[the sanitized measurement record](benchmarks/2026-10-22-native-preview-loading.json).
The collector returns nonzero, sets `collectionComplete=true`, `complete=false` and
`pixelAcceptance=false`, and writes a failure archive. It does not approve the candidate.

The Mac was reported locked before and after this collection. These are offscreen
native API diagnostics, not unlocked interactive measurements. No independent builds
or tests overlapped the measured processes; unrelated user/system activity remained.
Filesystem caches were not cleared. First use means a fresh test-host process and
empty in-process bitmap cache. Pixel controls/PNG writes occur after both timed operations.

| Operation / metric | Inline median | Shared median | Median paired delta | Paired delta range |
| --- | ---: | ---: | ---: | ---: |
| First / bitmap (ms) | 653.423 | 653.569 | +2.550 | -22.390 to +9.672 |
| Repeat / bitmap (ms) | 275.930 | 276.938 | +3.020 | -4.426 to +9.279 |
| First / thumbnail requests elapsed (ms) | 761.024 | 669.362 | -87.473 | -130.125 to -67.795 |
| First / thumbnail requests app CPU (ms) | 176.310 | 168.430 | -5.698 | -15.662 to -3.100 |
| First / navigation elapsed (ms) | 564.968 | 431.592 | -133.377 | -156.514 to -105.512 |
| First / font-resource preparation app CPU (ms) | 0.000 | 23.771 | +23.771 | +22.921 to +24.801 |
| First / installed fonts elapsed (ms) | 163.832 | 164.248 | +0.693 | -0.141 to +1.203 |
| Repeat / installed fonts elapsed (ms) | 162.936 | 162.466 | +1.467 | -2.273 to +6.100 |
| Repeat / thumbnail requests elapsed (ms) | 1.434 | 1.443 | +0.009 | -0.060 to +0.192 |
| First / app lifetime peak RSS (MiB) | 310.141 | 301.516 | -8.891 | -17.062 to -7.922 |
| Repeat / app lifetime peak RSS (MiB) | 344.297 | 342.969 | -1.156 | -7.672 to +0.391 |

Three of five first-bitmap pairs and four of five repeat-bitmap pairs were slower with
shared resources. One repeat app-RSS pair was also higher. Faster aggregate navigation
in this diagnostic does not establish a product speedup: exact pixels fail, visible-frame
latency is unmeasured, and helper-process costs are excluded. Stage spans overlap and
must not be summed; RSS is the app process lifetime peak, not operation memory.

The final mismatches are confined to JPEG artwork regions. Two controls alternate
exactly: inline-first equals shared-repeat, and shared-first equals inline-repeat.
The third shared repeat converges to the unchanged inline pixels. Text, headers,
footers and alpha channels are unchanged in these controls. Repeated inline captures
therefore independently reproduce the instability; it cannot simply be blamed on
font transport. The separate owned JPEG control was stable for all 12 direct-image
repeats, while four of 12 clipped-pattern repeats differed.

A preceding complete diagnostic run compared all 33 slides and matched 31 exactly.
Slides 15 and 20 differed in JPEG regions. Repeated inline/shared controls demonstrate
native image-sampling instability; the visual review did not find missing images.
Experimental production mitigations did not establish a reliable fix and were reverted.
An opt-in synthetic JPEG diagnostic preserves the direct-image versus clipped-pattern
reproduction without turning an unstable platform diagnostic into a default passing gate.

The collector retains complete failure receipts and still rejects pixel mismatches.
Saved diagnostic bitmaps are written after measured operations and excluded from the
explicit diagnostic archive allowlist. Shared fonts remain opt-in only.

## Production first-visible-slide and WebKit resources

**Blocked by the locked Mac; neither requested measurement is complete.**

The production arm64 Release app was built through the canonical signing wrapper,
verified with `codesign --verify --deep --strict`, and fingerprinted below. Production
sources and shared-font defaults are unchanged. The wrapper now accepts a validated
`LECTERN_BUILD_CONFIGURATION=Release`, avoiding the duplicate `-configuration` error
that prevented a normal Release build through its previous Debug-only invocation.

Native UI automation reported that the Mac is locked and automatic unlock is paused.
The user was asked to unlock it; the same condition was confirmed after the offscreen
collection. No production first-visible-slide number or WebKit resource total is claimed.
An Activity Monitor trace probe proved that the installed Instruments exposes cumulative
CPU, resident memory, physical footprint and responsible-PID ownership. That probe is
not a production workload measurement.

Resume with the same signed binary and input after unlocking. Capture cold-process and
same-process repeat Inspect operations in the actual app, bracket the Open action and
first identifiable visible slide using timestamped screen observations, and state the
observation uncertainty. Separately repeat under Instruments, selecting only the app
and WebKit helpers with that app's responsible PID. Report cumulative CPU boundary
ranges and simultaneous sampled RSS/physical-footprint totals, retaining missing
coverage and sampling uncertainty. Do not sum unrelated helpers or independent peaks.

## Fresh 33-slide inspection

Release inspection ran twice through the production entry point. All 33 preview slots
rendered; eight charts remained. The two runs produced 49 identical stable artifacts
with identical ordered diagnostics, excluding timing data. No preview failure, schema
issue, read warning or chart omission was recorded. The library's 261 source files were
unchanged between its build and these captures.

| Diagnostic | Count | Meaning retained in review |
| --- | ---: | --- |
| `chartApproximation` | 8 | Chart rendering is approximate |
| `unverifiedTextLayout` | 104 | Text layout is not certified identical |
| `fontEmbeddingRestricted` | 4 | Restricted symbol font was not embedded |
| `viewerFontDependency` | 4 | Those symbols depend on the viewer font |

Actual embedded faces were fingerprinted: Arial Narrow regular/bold, Calibri regular
and Courier New bold. The source deck had no missing-font diagnostic on this Mac.

## Native PowerPoint and WebKit fidelity

All 33 slides were reviewed at overview scale, with focused label and symbol inspection.
No new missing paragraph, omitted shape, overlap or clipped content was confirmed.
This qualitative review does not assert exact PowerPoint pixel fidelity.

- All 20 numeric bar labels remained visible across six bar charts.
- Both line charts retained four circle markers each: eight markers total.
- All four checkmarks and all five right-arrow symbols remained visible.
- Images retained their visible content and framing, including the two slides rejected
  by the separate exact-pixel stability gate.
- Chart padding, bar widths, tick cadence and some category wrapping differ from both
  PowerPoint endpoints within the existing chart approximation boundary.
- Slide 28 has one body bullet wrapping a word earlier than both PowerPoint endpoints.
  All text remains present; its body shape reports `unverifiedTextLayout`. One chart
  category also wraps onto two lines instead of one, under `chartApproximation`.
- Restricted symbol-font embedding leaves a slight checkmark appearance difference and
  a viewer dependency. The restriction was preserved rather than bypassed.
- A tracked-heading width difference seen in supplemental resvg was absent in actual
  native WebKit. The native ink width was about 292 pixels at 1280-pixel slide width,
  close to the roughly 291-pixel PDF result; no native source fix was justified.
- PowerPoint slide view and controlled print PDF themselves differ in color appearance.
  That endpoint difference was not classified as a source rendering defect.

## Generated layout and crowded-panel review

Fresh generation produced a six-slide layout deck and an eleven-slide crowded-panel
deck. Structural checks and 13 focused layout tests passed. All 17 generated slides
were visually reviewed in native PowerPoint slide view and controlled print PDF.

The two table pages repeat both header rows and preserve opposite 90°/270° header-label
rotations. All 16 body rows remain in their connected two-row groups across the pages.
Cards, columns, numbered steps, continued headings and source notes remain visible.
No dropped content or new clipping defect was confirmed.

This is PowerPoint endpoint and structural evidence. The generated packs did not receive
a separate complete native WebKit capture. Supplemental resvg output is not a substitute
for that endpoint and does not establish full generated-preview typography acceptance.

The generated cover exposes an existing Calibri Light support boundary. PowerPoint uses
Calibri Light; the preview diagnoses the unsupported styles and uses a fallback. The
installed font has legacy family/style names `Calibri Light / Regular` and typographic
names `Calibri / Light`. The resolver intentionally excludes Light from the base Calibri
Regular alias, with an existing regression enforcing that rule. Generic registration
would risk replacing the regular face. No font policy was broadened in this work.

## Historical exact-font typography oracle

The checker previously crashed when current scalar-positioned spans lacked `textLength`.
It now reads explicit scalar origins directly and retains legacy `spacingAndGlyphs`
handling, including the declared-width scaling of glyph origins. It does not invent
final glyph advances or full widths from a list of positions. Unsupported or nonfinite
positioning is refused. Four focused tests cover current, single-scalar, legacy and
invalid structures; an authentic legacy candidate also completes the checker.

All 268 PDF glyph outlines, 30 cases and 46 lines remain verified against the pinned
reference. The baseline gate passes: maximum error 0.12001708984375625 points against
an unchanged 0.121-point tolerance. Maximum horizontal glyph-origin difference is
0.024003906250015916 points. Current spans have no declared complete width; the measured
first-to-last-origin span difference is 0.1562390624999992 points and is reported as such.

The raster gate is unchanged: a pixel differs if any RGB channel difference exceeds tolerance 16;
at most 0.005 of pixels may differ. Candidates are rendered with pinned resvg and exact
fonts, then compared to the original native PowerPoint PNGs. Four of six comparisons
still fail; the overall checker exits 1 and writes the complete diagnostic report.

| Historical slide | Size | Differing pixels | Fraction | Result |
| --- | --- | ---: | ---: | --- |
| 1 | 1200×700 | 5,084 | 0.006052380952380952 | Fail |
| 1 | 2400×1400 | 12,557 | 0.003737202380952381 | Pass |
| 2 | 1200×700 | 10,288 | 0.012247619047619047 | Fail |
| 2 | 2400×1400 | 25,334 | 0.007539880952380952 | Fail |
| 3 | 1200×700 | 5,632 | 0.006704761904761904 | Fail |
| 3 | 2400×1400 | 14,589 | 0.004341964285714286 | Pass |

Independent single-raster checks agree with these results. Optional ablations remain
separate diagnostics and never replace the original candidate or native reference.

## Tool versions and source fingerprints

The isolated oracle used Python 3.12, PyMuPDF 1.27.2.3, fonttools 4.60.1, HarfBuzz 14.4.0,
resvg-py 0.5.0 and Pillow 12.3.0. Portable support packages were python-pptx 1.0.2,
lxml 6.1.3, typing-extensions 4.16.0 and XlsxWriter 3.2.9.

| Evidence | SHA-256 |
| --- | --- |
| Private 33-slide input | `fddcbe1c3b3f507dfcfd36f73e8219343ad1479575921a9e227807e37c827fea` |
| Fresh six-slide generated deck | `cf52e48ad759f738ea71e05441518a956d68eb2032c5bc89bc7606ae120227a4` |
| Fresh eleven-slide generated deck | `f5a22260d010117090157e5ed02d303d1aa62daa66260d9109a058f48c3a7548` |
| Fresh 33-slide print PDF | `b76eae0fea20e05dd9630bdcf8de5753c6a927b4f7ef59feb4d9fc93c1cd53be` |
| Historical typography PPTX | `e6ae71b1228c362eb9d1917df413e49d6850a92ffcb5416f2b9efdcc02393079` |
| Historical typography PDF | `1ecd600ebbed746667c5fecdb622b52b62dab98f0126657fc1818df9861945b3` |
| Historical native PNG archive | `b132733edf8647119301fb99ea2051e0015737c5e8bd585f2d7963919d5c071d` |
| Repaired typography checker | `4a2975fdf9743d158254a595946dfd8dbed2af5c9b482d53ef0a400591069f13` |
| Signed arm64 production Release executable | `eef474a121dd24e1a00eb9ca3d567a9afd2352bfe29367d818d32dc6f93f4c2f` |
| Release inspection executable | `17f222820e351cd85098af5f5d4932bfd1251dadec43b270edde13942a9e28ac` |
| Release typography renderer | `2227f41270fbacb8f17cdcedfe2b22e2817f80cb0f4bbf5bbd2a64d34afbec73` |

| Exact face | SHA-256 |
| --- | --- |
| Arial regular | `525979822591a3447cfc49d943d6f7683508e25543407871c0ed8fed05fd2bd9` |
| Arial bold | `d72db21f9242aedd6b917d8549ad5921766b24d5f8d0becfda2ff4c620b3c2e0` |
| Calibri regular | `ea801e1f869b55464339058b1d4263d07cc074a18e20aa3ee1d07901423dee53` |
| Calibri bold | `ac1cf97565de97cdc322228d875dc18c1131656c5138173e2c6d8ac7a37aa7f2` |
| Arial Narrow regular | `9e1d881c4e43b51868f5e235ea5a12c838e23cc8df6277df1a3c94e158999826` |
| Arial Narrow bold | `fcf34b330033e26c06e9bd466bea5a3e4b2f39272972275369beb7d8b257ed57` |
| Courier New bold | `500df4e46b554ae7d646e8727952fd8c7e60e94423481f6b82325cfddba2ee6a` |
| Calibri Light regular | `8c3ce077b95ad9764e839a8103c9e8370ed82309eba7d1e9c1e9f9435487e8d1` |

Individual SVG, native screenshot and PNG hashes are retained in private provenance.
The public report identifies artifacts without publishing private slides or font bytes.

## Validation and remaining limits

- Fast verification passed, including 1,312 root-package tests, 123 optimized text/layout
  tests, portable fidelity checks and 379 LecternCore tests.
- A final separate run passed all 58 offline workflow tests.
- Fresh generated-layout checks passed all 13 focused tests and structural manifests.
- The full native app suite passed 132 tests in 37 suites, with two intentional opt-in
  skips for profiling and image stability. The device receipt records 184 parameterized runs.
- Separate native profiling retained its exact-pixel rejection rather than changing the gate.
- The iOS simulator build succeeded. The signed arm64 macOS Release executable is
  fingerprinted above; production visibility and resource measurements remain blocked.
- Test counts above represent their stated suites; overlapping focused runs are not
  added as unique tests.
- Historical typography remains a deliberate failing fidelity gate: four raster failures.
- Calibri Light fallback, restricted symbol-font dependence, chart approximation and one
  reviewed body-wrap difference remain documented limitations, not full-fidelity passes.

No production rendering change is claimed to resolve these limits. The changes
repair evidence collection and compatibility while keeping shared-font loading disabled.
