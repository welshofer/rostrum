# Lectern template selection — 2026-10-02

**New Deck → Choose Template…** accepts `.potx` and `.pptx` on macOS and iOS.
Import runs off the main actor while security-scoped file access is active. A
validated immutable snapshot survives source moves, changes and file-provider
access expiry. Selection lasts for the app session. Generation waits for import;
cancelling a replacement or a failed import preserves the previous choice.
Removing the template restores the catalog style.

The snapshot travels through draft, repair, QA and rendering separately from the
provider request. Template bytes never enter text or image prompts. Its theme,
fonts, dimensions, masters, layouts and shared assets survive. Generated content
replaces example slides, notes, comments, sections and custom shows. Cleanup also
removes dependencies used exclusively by those example slides, including chart
workbooks and attachments, while preserving shared assets and unrelated package
parts. The deliverable is a `.pptx`; the original file is not modified.

The first master and layout now follow their declared document lists instead of
incidental relationship order. Library Lab's **Layouts and placeholders** recipe
demonstrates opposite declaration/relationship orders with two saved-file checks.

## Boundaries

- New content uses Lectern's compositions, not arbitrary template placeholder
  geometry. Generated fills can cover inherited background imagery. The form
  and generated result report this limitation.
- Generated slides use the first declared master. Other masters are retained.
- Import accepts at most 100 MiB compressed and 512 MiB expanded. Each canvas
  dimension must exceed the layout engine's margin/gutter overhead (currently
  four inches) and be at most 56 inches. Invalid/unsupported files fail before
  provider work.
- This is template-based generation, not a lossless conversion of the source
  presentation's example content. Existing renderer limitations still apply.

## Verification

| Check | Result |
|---|---|
| Rostrum | 997 tests / 136 suites passed |
| LecternCore | 230 tests / 25 suites passed |
| Native macOS app | 76 tests / 18 suites passed; no failures or skips |
| iOS simulator build | Passed; binary contains arm64 and x86_64 |
| Offline generation pipeline | Selected POTX → forced draft repair → QA → saved three-slide PPTX → reopen |
| Native picker | Selected POTX, displayed dimensions/layout count, cancelled replacement without losing selection, removed template and restored style controls |
| External package checks | ZIP CRC and every XML/rels part parsed; python-pptx opened output with three slides and 10 × 7.5-inch canvas |
| Native PowerPoint | Corrected output opened without repair; cover title fits, subtitle has no inherited bullet, cream field and purple master artwork remain visible |

Native checking exposed an oversized cover title on a 4:3 Georgia template.
The builder now fits actual font styling against both frame dimensions and writes
an explicit autofit scale. Title/subtitle paragraphs explicitly suppress inherited
bullets. Regression cases cover 4:3/widescreen, bold/italic inheritance, reopening
and small configured type sizes. Native PowerPoint confirms the computed scale is
honored; this is a specific visual check, not universal pixel parity.

The generation tests use an offline provider. No paid provider request was made.
Core tests also cover source-only dependency cleanup, shared-asset preservation,
source edits/deletion after import, malformed and oversized files, unsupported
dimensions, empty templates, multiple masters and catalog-style precedence.
App tests cover asynchronous replacement/cancellation and the generation guard.

Local evidence:

- `/tmp/lectern-template-library-final.log`
- `/tmp/lectern-template-core-final.log`
- `/tmp/lectern-template-native-final.xcresult` and `lectern-template-native-summary.json`
- `/tmp/lectern-template-ios-final.log`
- `/tmp/lectern-template-final/external-verification.json`

Owned fixture SHA-256 values:

| File | SHA-256 |
|---|---|
| selected-template.potx | `e1a3526a5e0ac96e0f910b4ad78e451a6859c31f28f78f54bb946194fa940e0c` |
| template-generated.pptx | `50b82dd857f7483a00aa7649a8158e08971f6b2daa8534a0c445a71a36fd8be5` |

Reproduce the retained generation fixture with a fresh output directory:

```sh
LECTERN_TEMPLATE_ARTIFACTS=/tmp/lectern-template-check \
  swift test --package-path Lectern --jobs 2 --filter TemplateGenerationTests
```
