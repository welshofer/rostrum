# Documentation

These guides describe the repository's current `main`. **1.0.0** is the released
API baseline; subsequent changes are listed under [Unreleased](../CHANGELOG.md#unreleased).
Use the [dependency instructions](GETTING-STARTED.md#install-with-swift-package-manager)
to choose a tagged release, a reviewed revision, or the development branch.
The [1.0 demo archive](../README.md#see-it-in-lectern) is historical release output,
not a download of the newest Library Lab results.

## Start here

| Goal | Guide |
| --- | --- |
| Install, create a deck, save and reopen it | [Getting started](GETTING-STARTED.md) |
| Plan tables, fit text, fill a template or paginate | [Layout engine](LAYOUT-ENGINE.md) |
| Generate cards, columns, numbered steps and structured tables | [Generated layouts](GENERATED-LAYOUTS.md) |
| Edit slides, charts, images, notes, comments and sections | [Cookbook](COOKBOOK.md) |
| Register or embed fonts, import slides, render SVG and interpret diagnostics | [Importing and previewing](IMPORTING-AND-PREVIEWING.md) |
| Pull, build and exercise the libraries through the app | [Lectern](../Lectern/README.md#pull-and-rebuild) |
| Run fixed production fixtures or replay saved content offline | [Composition regression](../Lectern/Tools/CompositionRegression/README.md) |
| Prepare text/table profiles with exact caller-supplied faces | [Native fidelity pack](../Tools/native-fidelity/README.md) |
| Retain production Lectern inspection/export evidence and timings | [Inspection runner](../Tools/native-fidelity/README.md#lectern-inspection-and-export) |
| Find an offline library demonstration | [Library Lab coverage](LIBRARY-LAB-20261002.md) |
| Understand preservation, package boundaries and deterministic output | [Architecture](ARCHITECTURE.md) |
| Check support and evidence before adopting a feature | [Format support](FORMAT_SUPPORT.md), [conformance](CONFORMANCE.md) |
| Reproduce performance results | [Performance ledger](PERFORMANCE.md), [benchmark tools](../Tools/rostrum-benchmark/README.md) |
| Contribute or run the completion gates | [Contributing](../CONTRIBUTING.md), [tool inventory](../Tools/README.md) |

## Enhancements since 1.0

| Capability | How to use it | Detailed evidence |
| --- | --- | --- |
| Shared authored and template fitting | Fit mixed runs, inherited styles, tabs, bullets, breaks and spacing with the same geometry used for previews; recheck before composing | [Authored fitting](AUTHORED-FITTING-20261011.md), [template fitting](TEMPLATE-FITTING-20261011.md) |
| Prepared shrink trials | Existing fit APIs reuse scale-independent preparation within each body; each trial still measures scaled geometry | [Prepared fitting](PREPARED-FITTING-20261012.md) |
| Native table row planning | `TableLayoutEngine.plan` reports cell geometry and diagnostics without editing the table | [Row layout](TABLE-LAYOUT-20261012.md), [vertical merges](TABLE-VERTICAL-SPANS-20261016.md) |
| Measured column widths | Choose `TemplateTableContent(rows:columnSizing:)` with `.measured()` and optional constraints | [Column search](TABLE-COLUMNS-20261012.md), [preparation](TABLE-PREPARATION-20261012.md), [fragment reuse](TABLE-SHAPING-20261013.md) |
| Table pagination and merged cells | `planTablePages` / `composeTablePages` preserve connected row groups, repeated headers, fixed widths and captions | [Pagination](TABLE-PAGINATION-20261012.md), [horizontal spans](TABLE-SPANS-20261012.md), [vertical/rectangular spans](TABLE-ROW-PAGINATION-20261016.md), [multi-row headers](TABLE-REPEATED-HEADERS-20261016.md) |
| Production tables and layout variety in Lectern | Generate or recover merged/rotated tables with repeated headers, or choose cards, three columns and numbered steps; `test-layouts.sh` exercises them offline | [Usage](GENERATED-LAYOUTS.md), [validation](GENERATED-LAYOUTS-20261017.md), [earlier tables](LECTERN-TABLES-20261013.md) |
| Shared text-layout reuse | Existing fitting, table measurement and SVG rendering reuse resolved run metrics during line measurement, with fresh checks on each operation | [Preservation and performance](TEXT-LAYOUT-20261017.md) |
| Table composition reuse | Existing `composeTablePages` calls share resolved template styles within one operation while retaining fresh validation | [Composition profile and comparison](TABLE-COMPOSITION-20261017.md) |
| Safer font embedding and import | Embed all supplied faces atomically; merge compatible embedded faces during slide import; register separately for measurement | [Font guide](IMPORTING-AND-PREVIEWING.md#embedding-fonts-safely), [embedding checks](FONT-EMBEDDING-20261013.md) |
| Prepared font registration | Validate one immutable byte/metrics snapshot and register it without parsing again; caller owns retention and refresh | [Prepared fonts](IMPORTING-AND-PREVIEWING.md#reuse-a-validated-font-snapshot) |
| Native line breaks and title defaults | Template composition writes soft breaks; newly authored masters declare typography; legacy title fallback resolves without XML edits | [PowerPoint review](POWERPOINT-LAYOUT-20261013.md) |
| Faster general pagination | Existing `MeasuredPaginator` APIs search near page boundaries with cancellation checks and deterministic monotonic fit predicates | [Boundary search](PAGINATION-PREFIX-20261013.md) |
| Consistent Lectern previews | Generation, recovery and Inspect share saved-deck font discovery and preview preparation | [App integration](../Lectern/README.md#feature-integration-and-regression-checks), [font policy](IMPORTING-AND-PREVIEWING.md#lectern-saved-deck-previews) |
| Better authored continuations | Lectern uses full-width comparison tails, measured final-page balancing and free citation space before source-note pages | [Reflow](CONTINUATION-REFLOW-20261014.md), [decision reuse](CONTINUATION-PERFORMANCE-20261014.md) |
| Explicit missing chart caches | Call `Chart.rebuildMissingCachesFromWorkbook()` or run the Missing chart caches Lab; native acceptance pending | [Repair scope and evidence](CHART-CACHE-REPAIR.md) |
| More precise diagnostics and portable gates | Group issues retain child/part locations; painted shadows and inherited placeholders avoid false omissions; pinned references run in CI | [Diagnostic traversal](DIAGNOSTIC-TRAVERSAL-PERFORMANCE-20261011.md), [verification](../CONTRIBUTING.md#before-a-pr) |

The libraries impose no font-family policy. Applications register the faces they
intend to use; redistributable test fonts exist to make fixtures repeatable.
Font substitution and preview fallback do not establish the source font's fidelity.

The [table measurement follow-up](TABLE-MEASUREMENT-20261017.md) documents
operation-local style-byte and key-hash reuse with output-preservation checks.

## Reading the evidence

Format support, saved-content preservation, preview fidelity and native PowerPoint
appearance are separate checks. A schema-clean file or matching SVG does not prove
PowerPoint slide-view equivalence. Native review should inspect both slide view
and exported output with the intended fonts; those rendering paths can differ.

Dated reports retain their original source revisions, workloads, raw measurements
and unresolved limitations. Follow the current guides for usage and the reports
for evidence. Performance percentages from different baselines are not additive;
CPU improvements do not imply lower peak memory. The [performance ledger](PERFORMANCE.md)
links both gains and measured costs. The [preview pipeline record](PREVIEW-PIPELINE-20261015.md)
adds per-stage CPU/elapsed, paired artifact checks and the native bitmap measurement boundary.
The [font-resource loading experiment](PREVIEW-FONT-RESOURCES-20261015.md) records
the opt-in WebKit transport, its preparation costs and the native comparison gate.
The [preparation follow-up](PREVIEW-PREPARATION-20261016.md) profiles repeated
scanning/hashing, retains paired CPU/elapsed/RSS results and exact resource
preservation, and extends the caller-font merged-table review corpus. The delivered Calibri
pack now has [user-reported PowerPoint acceptance](POWERPOINT-REVIEW-20261016.md),
recorded against exact deck/font hashes; export evidence remains separate.

The [roadmap](../ROADMAP.md) tracks remaining work; [PLAN.md](../PLAN.md) tracks
the current fidelity/performance milestones. Historical publication evidence
is in the [1.0 validation receipt](RELEASE-1.0-VALIDATION.md) and
[release audit](RELEASE-1.0-AUDIT.md).

The [rotated table-text guide](TABLE-ROTATED-TEXT-20261017.md) covers quarter-turn
cell fitting, template directions, repeated headers, and the Lectern review workflow.
