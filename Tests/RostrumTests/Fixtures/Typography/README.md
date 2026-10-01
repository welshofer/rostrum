# Typography oracle fixtures

DejaVuSans.ttf is the unmodified DejaVu Sans 2.37 release font. Redistribution
terms are in LICENSE-DejaVu.txt. Source release:
https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-sans-ttf-2.37.zip

SHA-256 (font): `7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954`

Pinned reference engine: `hb-shape (HarfBuzz) 14.4.0`. Each JSON case is produced by:
`hb-shape DejaVuSans.ttf TEXT --output-format=json --no-glyph-names --direction=DIRECTION`
Values are font design units (2048 units/em), default OpenType features.
The engine is a development-only oracle; production and tests have no runtime dependency.

Supported cases exercise GPOS class kerning, GSUB ligatures, NFC composition and
unpointed Hebrew reversal. Arabic and residual combining-mark records are negative
oracles: they demonstrate different glyphs/positioning that this implementation
explicitly diagnoses instead of claiming conformance. Indic contextual substitution,
mark attachment, language selection, full UAX #9 and full UAX #14 remain unsupported.
Basic CJK break tests exercise an explicitly bounded punctuation/grapheme profile;
there is no CJK shaping or complete Unicode conformance claim.

The implementation follows OpenType GSUB/GPOS table semantics:
https://learn.microsoft.com/en-us/typography/opentype/spec/gsub
https://learn.microsoft.com/en-us/typography/opentype/spec/gpos

## GDEF lookup-filter oracle

`LookupFlags.ttf` is a small outline-free test font authored by
`Tools/typography/make_lookup_oracle.py`, under the repository license. It has no
third-party glyph outlines. Its ASCII glyphs deliberately carry base, ligature,
mark, component and unclassified GDEF classes, so the tests distinguish font
classification from Unicode category guesses. It is only a shaping fixture.

`lookup-flags-harfbuzz-14.4.0.json` pins 35 independent HarfBuzz outputs covering
GSUB ligatures and GPOS pairs with IgnoreBaseGlyphs, IgnoreLigatures, IgnoreMarks,
mark attachment classes and mark filtering sets, including precedence, preserved
ignored glyphs/clusters and pair second-value consumption. RIGHT_TO_LEFT has no
effect on these lookup types. `lookup-flags-manifest.json` pins the generated
font hash and oracle engine. Regenerate with:

```sh
python3 Tools/typography/make_lookup_oracle.py
swift test --filter FontLookupFilteringTests
```

Optional local Arial comparison (font bytes are not copied or redistributed):

```sh
python3 Tools/typography/make_lookup_oracle.py \
  --local-font /System/Library/Fonts/Supplemental/Arial.ttf \
  --local-output /tmp/arial-oracle.json
ROSTRUM_LOCAL_FONT_ORACLE=/tmp/arial-oracle.json swift test --filter suppliedLocalFontOracle
```

GDEF versions 1.0, 1.2 and 1.3 class definitions and mark glyph sets are supported
within the same byte-derived work budget as the other layout tables. Missing
required classification/filtering data, malformed data, reserved flag bits and
budget exhaustion are diagnosed. This adds filtering, not mark attachment,
Arabic joining, contextual substitutions or full script shaping.

Primary specifications:
https://learn.microsoft.com/en-us/typography/opentype/spec/chapter2#lookup-table
https://learn.microsoft.com/en-us/typography/opentype/spec/gdef
