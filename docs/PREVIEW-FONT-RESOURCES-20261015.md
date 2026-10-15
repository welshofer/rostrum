# Mac preview font-resource loading experiment — 2026-10-15

Status: **opt-in experiment; normal app behavior unchanged; native comparison pending**.

## Trigger and decision

The supplied Release Mac run at reported revision `e71b087` used a 17-slide deck.
All 12 selected regression tests passed, all slides rendered, and all repeat
requests hit the bitmap cache. Its first bitmap was available in 698/257 ms,
and all repeat thumbnail requests totaled 1.53 ms (1.54 ms app CPU). First-pass
requests spent 828 of 1,113 ms in WebKit navigation and 169 ms waiting for fonts.
Installed-font registration took 163/124 ms. Process-lifetime app peak RSS was
429/478 MiB, excluding WebKit helpers. The input differs from the earlier 28-slide
baseline, so neither timing improvements nor output equivalence across versions
can be inferred. The upload reports a dirty checkout without identifying its cause.

Each uncached slide sends `loadHTMLString` its standalone SVG, including full
base64 font data. A bounded transport can replace only canonical font URLs in
that temporary document and serve their exact decoded bytes from memory.
Preparation adds CPU, and WebKit custom-scheme font loading needs native evidence.
Keep the candidate off in the normal app until it passes rendering and timing gates.

## Implementation and preservation

- `PreviewFontResources` recognizes the renderer's canonical CSS font rules with
  a UTF-8 scan and small-header validation. Unknown rules stay inline. It preserves
  alias, style, weight, format, text, coordinates, images and all other SVG bytes.
- Cache keys are exact data URLs, never font aliases or fingerprints alone. Same
  bytes with different aliases reuse resources; different bytes under the same
  alias get different URLs. Host namespaces and nonrecycled IDs prevent stale URLs
  from resolving to different bytes after eviction.
- Retained encoded keys plus decoded font data are bounded by 32 entries/32 MiB.
  Each active document has a separate 32-entry/32 MiB accounted budget, so eviction
  cannot invalidate a font while a capture is using it. Oversized fonts stay inline.
  Collection/object overhead, temporary markup and WebKit memory are outside these
  bounds. This storage is additional to the bitmap cache's 256 MiB budget.
- The Mac scheme handler serves only an exact URL in the active capture's resource
  set. Delivery is synchronous on the main actor, uses CORS for the local document,
  and disables browser caching. It does not read files or access the network.
  Cancellation/completion clears active resources; closing releases the font cache.
  Page scripting stays disabled. Existing queue, timeout and bitmap-cache behavior
  remains in force. Standalone exports and saved PPTX content never use this transport.
- Normal app construction and iOS use the original inline path. The test host's
  `LECTERN_PREVIEW_SHARED_FONTS=1` opt-in selects the candidate explicitly.

## Portable Release evidence

Swift 6.1.3 on Linux; one warmup and seven alternating fresh-process pairs per
workload, two preparation passes per process. Two workloads yield 32 processes.
The large workload uses the exact 28 previously uploaded SVGs (114,992,537 bytes).
A separate verification pass restores every replaced data URL and requires exact
UTF-8 equality with all source SVGs. No WebKit runs in this measurement.

| 28-slide preparation | Inline | Shared-resource candidate |
| --- | ---: | ---: |
| First-pass CPU | 17.395 ms | 173.588 ms |
| Repeat-pass CPU | 12.375 ms | 163.643 ms |
| First-pass elapsed | 17.397 ms | 173.587 ms |
| Repeat-pass elapsed | 12.371 ms | 163.636 ms |
| Process peak RSS (median) | 160.30 MiB | 151.99 MiB |
| Whole-process CPU (median) | 155.41 ms | 455.62 ms |
| Whole-process elapsed (median) | 155.91 ms | 456.17 ms |
| HTML bytes per pass | 114,999,901 | 43,927,613 |

The candidate decodes three unique resources, retaining 4,442,287 accounted bytes.
HTML payload falls 61.8%, but font responses are additional: if WebKit requests
every font on every slide, they add 53,306,624 bytes per pass. Combined SVG/HTML
and font payload would therefore fall about 15.4%, before protocol overhead.
Neither figure is a measured WebKit IPC or memory saving. Host memory includes
source SVG loading and wrapper preparation, not browser helpers or snapshots.

The tiny font-free control retains no resources: first preparation CPU is
8 microseconds inline versus 11 microseconds shared; repeated preparation is
about 1 microsecond for both. Median process peak RSS is 11.00 MiB for both.
These small timing differences do not demonstrate a benefit.

Raw samples and scope: [measurement JSON](benchmarks/2026-10-15-preview-font-resources.json).
The extra preparation cost means reduced HTML alone is insufficient to enable
this transport. Adopt it only if the native comparison shows a useful net gain
without pixel differences or unacceptable memory cost.

## Native validation and next decision

After pulling, quit Lectern and run from the repository root:

```sh
python3 Lectern/scripts/compare-preview-loading.py "/path/to/your-deck.pptx"
```

The default collects one warmup per mode and three alternating measured pairs of
fresh Release test processes on exactly the same input and executable. Each
candidate run subsequently compares all slide bitmaps against an independent
inline host using normalized sRGB RGBA pixels, outside the timed operations.
Input bytes, standalone SVG hashes, executable identity and complete render/cache
traces must match. Failed or skipped native regressions and missing comparisons
fail the run. Existing results and running apps are preserved. Send the printed ZIP.

Schema 3 reports resource accounting, mode and bitmap-comparison count. New
`thumbnail.document` and `thumbnail.fontResources` spans separate preparation
from navigation. Compare whole thumbnail requests with prior schema results;
the navigation boundary has changed. The paired report preserves raw stage CPU,
elapsed and app-lifetime RSS measurements. It excludes helper-process CPU/memory
and actual first-visible-frame presentation. PowerPoint visual acceptance remains
separate from preview pixel parity.

The existing macOS CI job builds the app, simulator app and isolated native test
host; it does not execute app-hosted tests. Native failure/recovery checks exercise
both font transports. Portable tests cover exact reconstruction, alias changes,
style and format retention, eviction, budget fallback and malformed inputs;
runner checks reject changed artifacts, skipped tests and incomplete evidence.
