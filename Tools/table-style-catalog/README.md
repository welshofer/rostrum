# Native table-style catalog

`styles.json` pins the 74 native PowerPoint style GUIDs and serialized DrawingML
style definitions from PPTX Studio, revision
`875a825d156812dda5fd7a359599d69fe700c972`. Source URL and SHA-256 are recorded in
the file. `LICENSE`, `NOTICE` and the root `THIRD_PARTY_LICENSES.md` retain the
attribution. The source identifies Microsoft PowerPoint for Windows as the
producer of the definitions; these definitions were not captured on this Mac.

Regenerate the Foundation-only Swift catalog offline:

```sh
python3 Tools/table-style-catalog/generate.py
```

The generator validates the roster size, uniqueness and XML identity, extracts
the style data, adds an explicit DrawingML namespace, and emits fresh mutable
XML for each resolver. It does not fetch anything or add runtime dependencies.
Inline/package definitions take precedence over native fallback. Theme edits
and table flags remain live. Unknown GUIDs continue to produce fidelity issues.
`clearBuiltInStyle()` uses No Style, No Grid; No Style, Table Grid has a different
GUID and retains its borders.

`BuiltInTableStyleTests` exercise every catalog entry, nonmutation, independent
definitions, save/reopen, direct overrides and visible diagnostic limits.
`Tools/conformance/make_native_style_fixture.py` independently authors a deck
using only style IDs and original text. The pinned deck was then round-tripped by PowerPoint Mac, which also exported
the reference PNGs. Last-modified author metadata is normalized to the project
test identity. The pixel checker compares cell fill samples, not text, border or
whole-slide equivalence. Effects and other unsupported preview features remain
reported even when the native style itself is recognized.

Run the cell-fill oracle after rendering the pinned input:

```sh
swift run pptx-tool render Tests/RostrumTests/Fixtures/NativeTableStyles/native-styles.pptx .build/native-style-oracles/svg
python Tools/conformance/check_native_styles.py .build/native-style-oracles/svg --report .build/native-style-oracles/report.json
```

The checker validates source/reference hashes, uses a 1200x700 viewport with the
unchanged 12x7-inch viewBox, and allows at most three RGB channel levels at each
of 1,480 cell centers. It exits nonzero for any mismatch. The source fixes were
selected from Microsoft's documented transform/interpolation behavior and
confirmed against the independent references, without changing this tolerance.
