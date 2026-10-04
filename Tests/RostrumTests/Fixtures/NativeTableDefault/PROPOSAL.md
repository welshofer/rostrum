# Fidelity17: absent applied table style — retained pre-implementation proposal

Observed on the generated alignment15 deck before source changes:
- All four one-cell tables have no `a:tableStyleId` or inline style, and no direct fill/borders.
- Related tableStyles.xml has only `def={5C22544A-7EE6-4342-B048-85BDC9FD1C3A}`.
- Accepted native PDF has no cell fill and 16 black 1 pt strokes; existing saved inspector SVG has four #E9EDF4 fills and 16 white 1 pt strokes.
- Endpoint geometry agrees, including half-point corner extension. The mismatch is style selection, not line geometry.

Code: TableStyleResolver.definition at lines 491-503 substitutes the table style list's `def` into an absent applied ID, then resolves Medium Style 2 Accent 1.

Primary corroboration: Microsoft-hosted ISO text describes `tblStyleLst@def` as a default usable when a table is initially inserted, while `tableStyleId` references the currently applied style:
- https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.tablestylelist?view=openxml-3.0.1
- https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.tablestyleid?view=openxml-3.0.1
This supports the distinction but does not replace native paint observations.

Two independent one-slide decks, 720 pt square, four 111.01 x 160 pt cells each, x=30/380 and y=70/350. All bodies are Agjp, actual embedded DejaVu Sans, 14.5 pt, kern=0, centered, zero margins, stored scale100/reduction0. Background #DDEECC exposes transparent versus opaque white fills.
1. Built-in insertion default: absent ID; explicit Medium2Accent1; explicit NoStyleTableGrid; explicit NoStyleNoGrid.
2. Actual custom insertion default: absent ID; explicit custom ID; absent ID with direct orange fill, green2pt left border and noFill right border; inline custom style.

Root will supply separate accepted PDFs and receipts before any production edit. capture.py retains all page paths/raw operators and per-frame path colors/opacities/widths/endpoints, with all 16 visible glyphs consumed per deck. Glyph traces are completeness controls, not a new outline identity claim. Existing accepted alignment glyph references remain unchanged.

Candidate only after native result: separate applied-style resolution from insertion preference; preserve explicit built-in/custom/inline precedence and direct overrides. Check hasStyleDefinition/public resolution semantics, fitting projection and import behavior; no blanket rewrite of unknown IDs or packages. Existing BuiltInTableStyleTests packageDefault... synthetic assertion and TableStyleImportTests nil-ID/default case require independent native reconciliation rather than silent test changes. No production source, tests, or tolerances changed yet.
