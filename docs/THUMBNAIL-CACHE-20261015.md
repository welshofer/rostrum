# Prepared thumbnail identity and bounded bitmap retention

The supplied native Mac profile showed 28 cache hits spending **287 ms elapsed /
288 ms app CPU** without any WebKit navigation, font readiness or snapshot work.
The SVGs total 114,992,537 bytes (109.7 MiB). Cache-hit duration correlates with
SVG size (Pearson 0.986). The old key hashes the whole Swift String repeatedly;
LRU promotion also searches an array of these content-bearing keys.

## Native baseline provenance and scope

The user supplied two operations from a Release app test host at revision
`e35bf241724775d17af43c9026c4eb335505ea49`, Xcode 27.0 (27A266a), macOS
27.0.1 (26A434). Input SHA-256:
`fa07996c34921c1eb3d5bca5c0a9f993eef8ba9622617378bf92ce97a2e8b8ff`.
Test-host SHA-256:
`8970a68a361729e3b00af9f249c997030cff60c9c0e80e05b7a16f5ef18af847`.
The original receipt says `sourceDirty: true`; the user confirmed only generated
or untracked output, with no source changes. That clarification is user-reported,
not an independently verified clean-build receipt.

| Native measurement | First operation | Repeat operation |
| --- | ---: | ---: |
| First bitmap available | 1.533 s | 0.373 s |
| Through final bitmap | 4.353 s | 0.644 s |
| All SVG rendering | 59.6 ms | 46.3 ms |
| Installed-font registration | 190.0 ms | 142.5 ms |
| All thumbnail requests | 3.922 s | 287.2 ms |
| App lifetime peak RSS | 540.6 MiB | 693.8 MiB |

All 28 first-use renders and 28 repeat hits succeeded, with no dropped samples.
First-use navigation totals 2.069 s, font readiness 307 ms and snapshots 89 ms;
another 1.458 s within requests is outside the original child stages. Do not
attribute all that residual time to cache work without the updated native trace.
First bitmap availability is not first visible display frame. Evidence writes
fall between requests and affect later wall offsets. CPU/RSS exclude WebKit
helpers; lifetime RSS includes test-host startup and overlapping old/new
inspections. Two high-water marks do not establish a leak.

## Change and limits

`PreviewContent` retains immutable SVG storage, UTF-8 byte count and a prepared,
process-local hash. It compares actual bytes on matching fingerprints; a hash
collision cannot reuse the wrong image. Shared String storage avoids even that
scan. Changed text, fonts, image payloads or dimensions still produce distinct
keys. No identity is serialized into a deck, SVG or diagnostic.

Generation, recovery and Inspect keep the prepared records through to the UI,
including SwiftUI task identity. Preparation happens alongside preview creation,
before UI handoff. A fresh inspection prepares its fresh records again. A linked
LRU list promotes entries without searching/comparing all retained SVG keys.
The one-WebKit queue, deadlines, cancellation, bounded dimensions and second
lookup after queue acquisition remain in place.

The bitmap cache admits at most **256 entries / 256 MiB of accounted bytes**.
Cost includes retained UTF-8 markup and bitmap representation bytes, with an
RGBA dimension estimate as a minimum. Arithmetic is overflow-checked. Oversized
results still display but are not retained; admission refusal leaves existing
entries intact. This limits cache accounting, not total app, WebKit, view-held,
GPU or allocator memory. A working set larger than the budget can miss on every
sequential revisit. Quick Look's separate small-key cache is unchanged.

Standalone SVGs remain self-contained. The supplied SVGs repeat 67.8 MiB of
embedded font payloads; sharing these resources is a separate future effort.
User-selected font families and the existing preview fallback policy are unchanged.

## Release cache-only comparison

The [reproduction workflow](../Tools/preview-profile/README.md#cache-only-comparison)
compiles current production cache/identity code with a frozen original-cache
control. Swift 6.1.3, `swiftc -O`, Linux x86-64. One warmup pair and seven
alternating measured pairs per workload, each in fresh processes; no concurrent
builds/tests during collection. Independent SVG loads model a new inspection.
The reverse-order shared-content pass models revisiting existing records.
Values are integers: **no actual bitmaps, WebKit or UI are exercised**.

| Uploaded 28 SVGs, median CPU | Original | Candidate |
| --- | ---: | ---: |
| First identity preparation + insertion | 1,428.6 ms | 25.6 ms |
| Fresh-record identity preparation | Included in lookup | 25.6 ms |
| Repeated lookup alone | 503.8 ms | 9.9 ms |
| Preparation + repeated lookup | 503.8 ms | 35.4 ms |
| Reverse-order shared-content lookup | 581.7 ms | 0.058 ms |
| Whole-process CPU, including file reads | 2.731 s | 0.270 s |
| Lifetime peak RSS | 264.77 MiB | 264.89 MiB |

Combined repeat preparation/lookup improves median paired CPU by 92.94% in this
isolation. Elapsed medians closely match CPU (503.8 ms versus 35.4 ms combined).
The candidate accounts 134.27 MiB including hypothetical 640×360 RGBA bitmaps;
that figure is not observed resident bitmap memory. Peak RSS is essentially
unchanged because both processes retain two SVG copies. No general memory
reduction or native Mac speedup is established.

The adverse control uses 28 tiny, unique SVGs. Repeat lookup CPU increases from
4 µs to 10 µs plus 3 µs preparation; whole-process CPU is 6.83 versus 7.27 ms,
with 11.125 MiB peak RSS in both. Microsecond stage measurements include clock
overhead and should not be interpreted as precise ratios.

Raw rounds, source/executable/input hashes, CPU, elapsed and peak RSS:
[uploaded SVG workload](benchmarks/2026-10-15-thumbnail-cache-uploaded.json),
[small control](benchmarks/2026-10-15-thumbnail-cache-control.json).
Private SVG/font/media bytes are not committed. The collector verifies every
lookup result and unchanged source SVG hashes; source tests also retain exact
UTF-8 bytes, including canonically equivalent but byte-distinct Unicode.

An [output-only comparison](benchmarks/2026-10-15-thumbnail-cache-output-parity.json)
also matches all 74 artifact entries across six production fixtures: small,
embedded-font tables, image-heavy inspection, dense generation, authored tables
and template tables. It compares retained pre-change Release tools with the
candidate Debug tools, whose hashes are recorded. This comparison is only about
output equality, not performance: PPTX/SVG bytes, saved-content snapshots,
exports and ordered diagnostics match after normalizing paths, snapshot
filenames and timing fields. Equal saved deck bytes include the same table
widths, row heights and page boundaries.

## Validation and remaining native checks

Portable regressions cover forced fingerprint collisions, independent equal
content, changed bytes/dimensions, failed preview slots, byte/count eviction,
replacement accounting, oversized refusal, integer overflow and released values.
App-hosted regressions additionally cover prepared-content reuse, oversize
rendering, duplicate queued requests and the existing cancellation/timeouts.
The updated native probe records identity, geometry, lookup, admission, retained
entry count and accounted bytes separately.

The final local `scripts/verify.sh --fast` gate passed: 1,374 Rostrum tests,
346 LecternCore tests, 63 optimized layout tests, nine native-pack checks,
12 Python fidelity checks, 36 portable references and README examples. Workflow
checks passed 22 cases and skipped two requiring XcodeGen. App builds and
app-hosted tests are explicitly excluded by `--fast`.

Native app-hosted tests and a before/after Mac rerun remain pending. Run
`Lectern/scripts/profile-preview.sh` on the **same original 28-slide PPTX**, then
compare its SVG hashes and ordered diagnostics, CPU/elapsed stages and app RSS.
Use Instruments separately for first-visible-frame latency and helper-process
resources. The uploaded evidence contains SVGs, not that original PPTX, so the
cache-only run cannot substitute for that native comparison. PowerPoint visual
acceptance remains a separate fidelity gate.
