# Selected image fills in inspection and export

Cell appearance retained an 84-byte PNG in its PowerPoint package, but the
outline omitted table-cell and custom-style image fills. Lectern's Export
Everything consequently wrote no images. This pass includes the resources
selected by image fills and exports their original bytes. The integrated
checkpoint is `3d4bde195096cebe543d452187c372826ff2f9cb`, Sources tree
`f19a4a905e014d11653091619b2dea850f10bb39`.

Independent source review approves the engine and its four preserved stages.
The final library gate passes 1,213 tests plus eighteen layout tests; focused
inventory tests pass 36 cases. The original root gate was interrupted during
app-hosted testing and is not accepted as a complete gate. The subsequent
credential repair and demo persistence checks use a standalone app-source
harness. Fresh native UI/browser and measured performance acceptance remain
deferred; no app was relaunched to obtain them. See the
[credential safety record](KEYCHAIN-SAFETY-20261004.md).

## Selection and ownership

The collector resolves direct shape and table fills, selected table-style
regions, theme matrix references, backgrounds and active inherited furniture.
It retains the owning package part when resolving a relationship: identical
relationship IDs in a slide, theme or style part can refer to different images.
Explicit noFill and direct overrides suppress inherited resources. Matched
placeholder and selected group-fill resources are inventoried without claiming
that the renderer supports every corresponding inheritance case.

Existing picture, video, audio and chart filename allocation precedes newly
discovered fills. Images deduplicate by actual package part within each slide;
two different parts with equal bytes remain distinct. No external image is
fetched, transcoded or substituted. Missing, malformed and external selected
references produce deterministic, owner-specific warnings. This is an inventory
of selected resources, not pixel-occlusion analysis or a dump of package media.

Per-operation table sessions reuse selected style nodes within bounded region
signatures. Direct changes remain live and valid merge continuations are skipped.
All state expires after the outline operation. Review caught and corrected
direct-fill precedence, alternate PresentationML controls, aliased theme cell
references and aliased theme table backgrounds. Their failing tests, separate
commits and original receipts remain retained; the SVG renderer is unchanged.

## Lectern coverage

The same 33 demonstrations remain available. Cell appearance now checks that
its one package image is exported once on each of slides one and two. Fills and
lines checks its selected shape fill and two backgrounds on slides one, nine
and ten. Both options of both recipes verify exact 84-byte image copies,
Markdown links, fresh inspector previews, repeated export and source purity.

The worker's final focused run verifies all four recipe/option combinations and
ten exported PNG files. Earlier full Core and actual app tests pass on the
preserved intermediate source; they do not substitute for the final root gate.
The expected catalog gains two findings for the existing malformed imported
picture: one inspection finding and one export finding for the same missing
embedded relationship. The source and preview limitation already existed;
the two API stages now report it accurately.

Both original S20 Cell appearance decks also export the two exact images with
unchanged PPTX bytes and repeat/reopen behavior. Those retained headless proofs
remain separate from visible root workflow acceptance, which is deferred.

## Performance status

The proposed measurement covers the first outline after rendering and a first
outline on a separately opened, unrendered presentation. Opening and result
consumption are outside each outline timer. The process and filesystem are
already warm; this does not claim cold application-start performance. Fixed
inputs include image-free tables, direct/shared image fills, ownership and
namespace controls, and the actual Cell appearance files. Comparative timing
has not started. Complete SVG, package and rendering-diagnostic preservation
is checked independently of intentional inventory and export changes.

The [engine report](IMAGE-FILL-ASSETS-20261004.md) retains selection boundaries,
strict regressions and the additive source history. A separate subsequent pass
corrects rendering of shape theme-image owners; that correction is not included
in this source checkpoint.


## Combined source integration before main

The subsequent integration includes the selected theme-image owner renderer fix
and the 34th Lectern demonstration, alongside credential safety and automatic
demo persistence. Local verification passes 1,218 library tests, eighteen layout
tests, 315 Core tests, and 28 standalone app-test definitions / 37 executions.
The full 34-demo catalog persists its completed decks; selected image fills and
image ownership reach the actual AppState inspector/export code in the standalone
harness. Both README examples save and reopen, and the four retained native
source decks pass the seven-image byte/geometry audit.

[Combined verification receipt](verification/2026-10-04-main-integration.json).
The original interrupted hosted gate remains unaccepted. Native UI/browser
checks and comparative image-inventory timing are still deferred; merging this
source does not change those evidence limits.
