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
