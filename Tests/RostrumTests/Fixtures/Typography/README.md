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
unpointed Hebrew reversal. The original Arabic joining case is now a positive
oracle; selected residual mark sequences now have positive attachment oracles. Indic contextual substitution,
ligature/cursive attachment, language selection, full UAX #9 and full UAX #14 remain unsupported.
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
mark positioning or full script shaping. The additional Arabic stage below
uses the same filtering rules.

Primary specifications:
https://learn.microsoft.com/en-us/typography/opentype/spec/chapter2#lookup-table
https://learn.microsoft.com/en-us/typography/opentype/spec/gdef

## Bounded Arabic contextual shaping

`arabic-harfbuzz-14.4.0.json` contains 33 positive and 7 negative DejaVu cases.
Positive cases cover default-language Arabic, Persian and Urdu letter sequences,
joining forms, required/optional ligatures, normalization, spaces, ZWJ and ZWNJ.
The reference invocation fixes `--direction=rtl --script=arab --language=und`.
All positive glyph IDs, cluster starts, advances and x/y offsets are checked.
Negative cases pin ligature-component marks and mixed-script/bidi output; they
remain diagnosed while that geometry is unimplemented.

The Arabic program applies `ccmp`, `locl`, joining forms, `rlig`, `rclt`, `calt`,
`liga` and `mset` in stages. It implements single substitutions (formats 1/2),
ligature substitution, chained contexts (formats 1/2/3) and extension lookups.
Other lookup types, malformed graphs, parse-budget exhaustion and execution
limits produce diagnostics. Execution has a maximum depth of 16 and at most
262144 work units, including scans for nested targets. This is a bounded profile,
not full OpenType or Unicode conformance.

`ArabicContexts.ttf` is an owned outline-free font under the repository license;
its 12 HarfBuzz cases exercise actual context matches/misses, all three context
formats, nested extension lookups, pair placement and contextual records following
ligatures that consume input positions. Both font hashes are pinned in their
oracle JSON files. Regenerate using:

```sh
python3 Tools/typography/make_arabic_oracle.py
python3 Tools/typography/make_arabic_context_oracle.py
swift test --filter ArabicShapingTests
```

To compare a local font without redistributing it:

```sh
python3 Tools/typography/make_arabic_oracle.py --font /path/to/font.ttf --output /tmp/arabic-oracle.json
ROSTRUM_ARABIC_ORACLE=/tmp/arabic-oracle.json ROSTRUM_ARABIC_FONT=/path/to/font.ttf swift test --filter suppliedLocalArabicOracle
```

Joining data is generated from the SHA-pinned Unicode 17.0.0
`extracted/DerivedJoiningType.txt` by `Tools/typography/make_joining_data.py`.
Its Unicode license is retained as `LICENSE-Unicode.txt`. The runtime uses owned
Swift data and code; no platform text stack or external shaping library is added.

Ligature/cursive positioning, language-system selection and mixed Arabic paragraph
bidi remain unsupported. Arabic digits and punctuation outside this narrow RTL
letter/space/control profile remain diagnosed. RichTextLayout still diagnoses
RTL span ordering, so strict slide rendering does not claim complete Arabic
paragraph geometry merely because TextShaper can produce contextual glyphs.

Primary references:
https://learn.microsoft.com/en-us/typography/script-development/arabic
https://learn.microsoft.com/en-us/typography/opentype/spec/gsub
https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedJoiningType.txt

## Calibri compatibility cases

`SingleComponentLigature.ttf` is an owned, outline-free MIT test font. Its
single-component GSUB4 replacement (`f` to `F`) and identity (`g` to `g`) rules
verify that one input glyph is consumed without revisiting the replacement.
The Arabic executor has matching identity/replacement regression coverage.
`WrappedKern.ttf` is another owned, outline-free MIT fixture with 11,000 sorted
legacy pairs and a wrapped subtable length; five HarfBuzz cases verify the actual
legacy kerning fallback when GPOS is absent.

`calibri-harfbuzz-14.4.0.json` pins ten owned-font cases and 18 cases each for
local Office Calibri and Calibri Bold. It contains numeric shaping results and
font hashes; proprietary font bytes are not included. The Calibri and GSUB cases compare glyph
IDs, scalar clusters, advances and x/y offsets. Legacy kerning compares absolute
glyph origins and total advance: HarfBuzz distributes a pair adjustment across
two advances and the second offset, while Rostrum assigns it to the first advance;
these representations produce identical geometry. To verify the exact local font
hashes and replay HarfBuzz before running the optional local-font tests:

```sh
python3 Tools/typography/make_calibri_oracle.py --verify
ROSTRUM_CALIBRI_FONT_DIRECTORY='/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts' swift test --filter FontCompatibilityTests
```

`--font-directory` selects another directory containing the exact pinned font
versions. Without the environment variable, portable tests use only owned fonts.
Regeneration without `--verify` still requires the pinned proprietary-font hashes
and HarfBuzz 14.4.0. The local files used are `Calibri.ttf` (SHA-256
`ea801e1f869b55464339058b1d4263d07cc074a18e20aa3ee1d07901423dee53`) and
`Calibrib.ttf` (`ac1cf97565de97cdc322228d875dc18c1131656c5138173e2c6d8ac7a37aa7f2`).

These fonts have legacy format-0 `kern` subtable lengths that wrap their uint16
field. Rostrum accepts that compatibility case only when there is one complete
subtable, the count-derived byte size exactly reaches the table boundary, all
wrapped length/search fields agree, and pair keys are strictly increasing.
Truncation, extra bytes, duplicate or unordered pairs, inconsistent counts/search
fields, or multiple subtables retain an explicit refusal. Parsing stays bounded
by the existing layout budget. This is a narrow deployed-font compatibility
exception to the [OpenType kern length field](https://learn.microsoft.com/en-us/typography/opentype/spec/kern),
not a relaxation of arbitrary font-table bounds. Calibri's remaining Arabic
GSUB2 and GPOS1/8 requirements are still diagnosed.

## Bounded mark attachment

See [MARK-POSITIONING.md](../../../../Tools/typography/MARK-POSITIONING.md) for the
GPOS 4/6/9 contract, positive and negative HarfBuzz cases, owned fixture provenance,
local-font reproduction commands, and parsing/execution limits.
