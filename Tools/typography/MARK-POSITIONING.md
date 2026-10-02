# FUNC-3 bounded mark attachment evidence

Implemented unhinted horizontal GPOS mark-to-base (type 4) and mark-to-mark
(type 6), format 1, including extension lookup 9 and default-language `mark` /
`mkmk` feature selection for Latin and isolated RTL Arabic. Anchors 1 and 2 use
font-design coordinates; anchor 3 is accepted only with absent device offsets.
No rasterizer, platform text stack or production dependency is introduced.

Attachment retains source clusters, obeys GDEF lookup filters, zeros GDEF mark
advances and resolves parent offsets after lookup processing. Parent indices
strictly decrease, so attachment graphs cannot cycle. RTL offsets account for
reversal and the actual advances between a mark and its parent. This is a
TextShaper milestone: strict rendering still diagnoses Arabic paragraph layout.

The supported residual Latin profile is ASCII letter bases except soft-dotted
`i`/`j`, followed by marks actually attached by supported lookups. NFC-composable
single glyphs keep their existing support. Soft-dot substitution, residual
non-ASCII Latin bases, leading/unattached marks, mark-to-ligature components,
cursive positioning, variable/device positioning, mixed bidi, and combined
pair placement with mark attachment remain diagnosed. Pair advance kerning is
supported. No claim of complete Arabic, OpenType or Unicode shaping is made.

## Independent oracles

`Tests/RostrumTests/Fixtures/Typography/marks-harfbuzz-14.4.0.json` records exact
HarfBuzz 14.4.0 glyph IDs, scalar cluster starts, advances and x/y offsets, plus
font SHA-256 values. Tests compare each field independently, repeat each case
for determinism, and check half-size geometry. Source font bytes are unchanged
DejaVu Sans 2.37 (existing redistributable fixture) and `MarkAttachments.ttf`,
an owned outline-free font under the repository license. The owned font has
nonzero mark hmtx advances, extension lookups, genuine stacked mark attachment,
and simultaneous mark-attachment-class / mark-filtering-set flags. The latter
makes a class-excluded lower mark a valid target via the filtering set, proving
that the set takes precedence. The fixture generator uses development-only
FontTools 4.60.1; runtime and tests remain Foundation-only.

The DejaVu Arabic case `بَ` has visual `[mark, base]`, mark `(dx,dy)=(388,-200)`
and zero advance at 2048 units/em. `مِّ`, joined marked letters and controls
also match. Lam-alef component marks and `ff` ligature marks remain diagnosed.
The former blanket negatives for `بَ`, `مِّ`, `بَ‍ب` and `x́` are now exact positive
checks; no oracle glyph data was changed to match Rostrum.

```sh
python3 Tools/typography/make_mark_oracle.py
swift test --jobs 2 --filter MarkPositioningTests
swift test --jobs 2
```

Adversarial checks cover every byte truncation of the owned GPOS, invalid class
and offset references, null required mark anchors, missing GDEF, device anchors,
variable-font refusal, aliased anchor matrices sharing the 262144-unit parsing
budget, and a 10000-mark execution-budget refusal. Lookup scanning is bounded by
at most 262144 operations; graph resolution and storage are linear in glyph count.

Local-only comparisons also pass for Arial and Office Calibri, five residual
Latin cases each. No proprietary font bytes are committed. To reproduce:

```sh
python3 Tools/typography/make_mark_oracle.py \
  --local-font /System/Library/Fonts/Supplemental/Arial.ttf \
  --local-output /tmp/marks-arial.json
ROSTRUM_MARK_ORACLE=/tmp/marks-arial.json swift test --jobs 2 --filter suppliedLocalMarkOracle
python3 Tools/typography/make_mark_oracle.py \
  --local-font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/Calibri.ttf' \
  --local-output /tmp/marks-calibri.json
ROSTRUM_MARK_ORACLE=/tmp/marks-calibri.json swift test --jobs 2 --filter suppliedLocalMarkOracle
```

This milestone does not alter Office PNG baselines or their existing 4/6
failures. It provides numeric shaping evidence, not an Office visual-fidelity
claim. Primary format reference:
https://learn.microsoft.com/en-us/typography/opentype/spec/gpos

Verification on 2026-10-02: `swift test --jobs 2` passed 979 tests in 133 suites.
Both opt-in local-font tests passed. Exact local font hashes were Arial
`525979822591a3447cfc49d943d6f7683508e25543407871c0ed8fed05fd2bd9`
and Calibri `ea801e1f869b55464339058b1d4263d07cc074a18e20aa3ee1d07901423dee53`.
Two fixture generations were byte-identical; owned font SHA-256 is
`07c11a0555fe32015b1af4701570a5ca0db5e3ace2d760701c7199e66c80def9`.
