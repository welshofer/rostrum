# Chart and symbol preview fidelity

These changes require the development revision containing this fix, rather than
Rostrum 1.0.0. They affect SVG previews and Lectern inspection; previewing does not
rewrite the deck's charts, workbooks, text, or font choices.

## Chart previews

The SVG renderer now honors chart-wide text properties, with local title, axis,
legend, and data-label overrides for font family, size, color, bold and italic.
Registered faces use the same permitted SVG font resources as ordinary text.
Font discovery in Lectern includes chart parts.

Numeric formats are compiled once per axis or label style. Supported formats
include decimal digits, optional fractional digits, grouping, positive/negative/
zero sections, quoted or escaped prefix/suffix text, and comma scaling. A bare
percent sign scales the value; a quoted or escaped percent sign does not:

| Source value | Format | Preview |
| --- | --- | --- |
| 20 | `0"%"` | 20% |
| 0.2 | `0%` | 20% |
| 64.7 | `"$"#,##0.0"B"` | $64.7B |
| 1200 | `#,##0"K"` | 1,200K |
| 1250000 | `0.0,,"M"` | 1.3M |

Unsupported formats, including conditional/date/scientific/fraction formats,
produce a diagnostic and use General formatting. The numeric subset is not a
complete Excel formatting engine.

Bar previews render requested value/category/series labels, including series
and point overrides, suppression, text styles, numeric formats and common
inside/outside positions. Line previews render explicit circle, square, diamond
and triangle markers, with point-level overrides. Custom rich labels, exact
PowerPoint label collision/layout behavior, other marker shapes, and unsupported
chart kinds retain fidelity diagnostics. The subsequent [measured chart layout](MEASURED-CHART-LAYOUT-20261018.md) adds
line/area and pie/doughnut labels, measured wrapping and collision handling.
The evidence below describes this earlier units/style change.

Series/category bounds remain 32 nonempty series and 512 categories. Actual
truncation produces a separate omission diagnostic. The general chart-layout
caution no longer suggests that this particular chart lost data merely because
it contains a chart.

## Connectors and symbols

`bentConnector3` uses the three-segment elbow geometry, including its literal
`adj1` adjustment. A zero-height default elbow is a horizontal rule. Connector
findings no longer incorrectly claim a rectangle was drawn. Other unsupported
connector presets and formulas remain diagnosed.

Standalone mathematical signs, arrows, geometric shapes and dingbats use normal
glyph mapping instead of being labeled unsupported scripts. Missing glyphs,
emoji sequences, variation selectors, combining and bidi limitations remain
explicit. This does not claim full Unicode shaping support.

A host may opt into **registered** fallback faces for missing standalone symbols:

```swift
deck.fonts.previewSymbolFallbackFamilies = ["Your Symbol Font"]
```

Register the actual font bytes first, as for any other measured face. The default
is an empty list. Up to eight families are consulted in order, preferring the
requested style and then regular. Only missing standalone symbols are substituted;
ordinary letters and multi-scalar graphemes are not split. Layout measures and
paints the same selected face, retains a substitution diagnostic, and leaves
source XML unchanged. A new operation observes changed registration or policy.

Lectern's saved-deck and notes previews register Apple Symbols and Zapf Dingbats
when available, then use Apple Symbols, Zapf Dingbats and Arial as their explicit
symbol fallback policy. Apple Symbols has no Dingbats-block glyphs such as ✓
(U+2713); Zapf Dingbats supplies them.
Unavailable or unsuitable faces do not make a missing glyph pass silently.
There is no new font restriction on library users and no automatic OS lookup
inside Rostrum.

## Inspector findings

Lectern groups repeated findings and lists affected slide ranges. Native layout
cases that have not been verified against PowerPoint appear under **Fidelity
verification notes**, separately from concrete preview limitations. A substituted
symbol reads as one sentence, such as "✓ (U+2713) is drawn with the installed Zapf
Dingbats because Arial Narrow lacks it"; "installed" replaces that face's separate
embedding-restriction message. Complete
per-slide/per-shape diagnostics and original warning strings remain available
in exports. Strict rendering still refuses verification gaps and substitutions.

## Reproduce and review

The offline Library Lab's **Chart gallery** checks literal-percent axis/value
labels after saving and reopening. **Extraction and honest previews** includes a
licensed Latin-only outline font with a missing checkmark, an explicitly selected
symbol fallback, a saved/reopened SVG check, and a retained substitution finding.
`RostrumLabLatin.ttf` is an ASCII subset of the existing licensed DejaVu fixture,
renamed for this test; it is not a recommended production font. Its original
license is retained in `Resources/LibraryLab/LICENSE-DejaVu.txt`, and
`Tools/typography/make_symbol_preview_fixture.py` reproduces it.

```sh
swift test --filter 'ChartPreviewFidelityTests|PreviewSymbolTests|ConnectorPreviewTests'
swift test --package-path Lectern --filter 'PreviewFindingGroupTests|LibraryLabTests|SavedDeckPreviewTests'
```

After pulling and quitting Lectern, the existing Mac follow-up script profiles
this deck in Release mode and runs the native preview regressions:

```sh
bash Lectern/scripts/test-preview.sh /path/to/the-state-of-higher-education-2026-1790864774198.pptx
```

It retains SVGs, font/source provenance, timing data and the native test result
bundle. See [the preview workflow](../Lectern/README.md) for requirements. Open
the same deck in Lectern Inspect to review the chart labels and slide 24's
checkmarks with installed fonts; compare against PowerPoint separately.

The supplied 33-slide higher-education deck stays outside version control.
Its six bar charts request 20 value labels and its two line charts contain eight
points. The original diagnostic identified erroneous 100× percentage tick labels,
lost B/K suffixes, lost bar labels, gray/smaller chart text, missing markers and
22 misleading connector reports. A native PowerPoint/Mac visual comparison with
its exact Arial Narrow/Courier New faces remains a separate acceptance step.

## Validation evidence — 2026-10-18

- All 1,424 library tests pass, including 49 focused final regressions. The 118
  optimized layout controls and 11 new-feature regressions also pass in Release.
- `scripts/verify.sh --fast` passes: all 371 LecternCore tests, native-pack
  portable checks, semantic oracles, 14 image probes, 36 comparisons against
  pinned PowerPoint image exports, and runnable README examples. This Linux gate
  excludes Apple app builds and app-hosted test execution; PR CI compiles the
  native apps and test host, while live PowerPoint acceptance stays pending.
- All 33 slides in the supplied deck render successfully with no read or schema
  errors. All 20 bar labels and eight line markers are present; chart labels use
  the authored white 13 pt style. Erroneous percentage scaling and all 22
  connector warnings are removed.
- The before/after inspection's extracted content, chart data and metadata are
  identical. All 15 Markdown, image and CSV exports remain byte-identical.
- The final 33 SVGs match the candidate used for the local before/after image.
  That image uses substitute fonts and is a diagnostic comparison, not native
  PowerPoint typography evidence.

### Resource smoke check

Five paired Linux **Debug** processes per build, after one warm-up each, compared
the final renderer with `e285cde`. Runs alternated order without concurrent
builds/tests. The same 33 SVGs were reproduced in every measured run of each
build. [Raw samples and binary/input hashes](benchmarks/2026-10-18-chart-preview-debug.json)
retain the results; medians are:

| Measurement | Before | After |
| --- | ---: | ---: |
| Inspection elapsed | 1.875 s | 1.947 s |
| Inspection CPU | 1.869 s | 1.947 s |
| SVG rendering CPU, all 33 slides | 235 ms | 286 ms |
| Process peak RSS | 36.26 MiB | 36.14 MiB |

The richer preview costs about 51 ms more rendering CPU in this Debug smoke
check; memory is essentially flat. This is a fidelity improvement, not evidence
of a speedup. The sample excludes native fonts, WebKit and UI work and does not
establish Release performance; use the Mac script above for that follow-up.
