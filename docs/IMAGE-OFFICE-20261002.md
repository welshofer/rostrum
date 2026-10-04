# Office image mapping evidence — 2026-10-02

Twelve independent image-mapping cases now pass the existing whole-slide
comparison policy against PowerPoint 16.113.3: channel tolerance 16 and at most
0.5% differing pixels, at 1200×700. This is evidence for these authored cases,
not universal image/effect equivalence.

The [immutable corpus](../Tests/RostrumTests/Fixtures/ImageOffice/manifest.json)
contains independently authored python-pptx 1.0.2 sources, a project-authored
RGBA quadrant PNG, and hashed native Office PNG exports. No library code creates
the source fixture. Its PNG has explicit 96-dpi metadata. Each 12×7-inch slide
contains a single picture, shape fill or table-cell fill and no text. The normal
Office open path showed no repair dialog. File → Export → PNG → Save Every Slide
produced the references; PowerPoint did not rewrite the source PPTX.

The cases cover whole-source stretch, right-half and asymmetric source crops,
negative crops, destination insets, combined source/destination rectangles,
rotation plus two reflections and ellipse clipping, shape image fills,
center-aligned mirrored tiles with positive/negative offsets, and table image
fills with bottom-right-aligned, scaled, mirrored tiles. The authored source
rectangles follow Microsoft's [fill rectangle](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.fillrectangle?view=openxml-3.0.1)
and [tile](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.tile?view=openxml-3.0.1)
semantics.

## Preserved failure and correction to diagnostics

The first source, v1, retains python-pptx's normal theme effect reference on
shapes. Nine cases pass; three shape cases fail at 3.92–6.58% differing pixels.
PowerPoint applies a shadow behind the partly transparent image fill. The SVG
renderer omits this theme effect. Both 1200×700 and 2400×1400 v1 Office exports
remain preserved. The [original 1200-pixel failure report](../Tests/RostrumTests/Fixtures/ImageOffice/comparison-v1.json)
is retained.

The omission previously escaped strict-rendering diagnostics because the effect
lives in the theme rather than inside the shape. Shape and picture rendering
now resolve active effect references and report the omission at each referring
shape. Invalid or unavailable references report unresolved inheritance. Empty
direct effect properties override the corresponding theme component; namespace
declarations alone do not create an effect. The change reports the limitation;
it does not add shadow rendering.

Slide/layout theme overrides containing format schemes are not yet applied by
the renderer. These now report unresolved inheritance at the effect reference,
instead of accepting an empty inactive master style or blaming its inactive
shadow. Override names resolve namespace aliases and local rebindings; invalid,
missing and external override parts are diagnosed without loading external data.

V2 is a separately named fixture that explicitly disables theme effects to
isolate image mapping. Its [12-case report](../Tests/RostrumTests/Fixtures/ImageOffice/comparison-v2.json)
passes with 0–0.1130% differing pixels per case. V2 does not replace v1 or certify
its shadow behavior. Reference dimensions and thresholds were not changed.

## Repeatable checks

```sh
swift run pptx-tool render Tests/RostrumTests/Fixtures/ImageOffice/image-mapping-v2.pptx /tmp/image-office-svg
python Tools/conformance/check_image_office.py Tests/RostrumTests/Fixtures/ImageOffice/manifest.json /tmp/image-office-svg --output /tmp/image-office-comparison
swift test --filter RenderDiagnosticsTests
```

The Python command requires the development-only pinned resvg-py 0.5.0 and
Pillow 12.3.0. It verifies fixture, archive and individual reference hashes;
checks reference dimensions and the 12×7-inch SVG viewBox; normalizes only the
pixel viewport; disables system font lookup; and writes candidate images and a
hashed report outside the reference corpus. Missing or changed inputs fail.
The existing v1 can be checked with `--variant v1`; its failures are expected.
The portable Swift tests also exercise both sources, require the three v1
omissions, require no known issues for v2, and verify rendering does not change
saved document bytes.

A negative control moves the first candidate image by one inch without changing
its viewBox. The checker rejects it (20.4104% differing pixels, exit 1); the
remaining eleven images still pass. Neither references nor thresholds change.
