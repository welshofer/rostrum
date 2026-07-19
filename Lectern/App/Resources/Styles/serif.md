# Serif

**ID:** `serif`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#ffffff`
- `#111111`
- `#000000`
- `#2b2b2b`

## Typography

Families: "Beatrice Display, Tiempos Headline, serif", "Diatype, Söhne, Inter, sans-serif", "New Grotesk, Space Grotesk, sans-serif", "Teg, Migra, Canela Display, serif". Weights: 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Bpowell

Design token description: A text-only interface that lets typography do every job, with no imagery, decoration, or chrome. The page reads as an architectural list, with oversized, tightly-tracked project names stacking like concrete blocks. Two surfaces alternate — a bright white canvas (ffffff) and an inverted near-black canvas (111111) — and the contrast between them is the only visual rhythm. The layout is asymmetric, with a single column of type pinned to the left, generous negative space, and a top nav distributed across the full viewport width. The system has no buttons, cards, or borders in the traditional sense, resulting in an austere, deliberate, and confident visual language.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a text-only system that uses typography as its sole architectural and decorative element. The interface is built on two alternating, full-bleed surfaces: a bright white canvas ({colors.canvas-light}) and an inverted near-black canvas ({colors.canvas-dark}). The stark contrast between these two states creates the page's primary visual rhythm. The layout is deliberately asymmetric and minimalist. All content is pinned to a single left-aligned column, leaving a vast amount of negative space to the right. The system avoids all conventional UI chrome: there are no buttons, cards, icons, borders, or imagery. Instead, oversized display type with aggressive negative letter-spacing ({typography.display-lg}) creates monolithic blocks of text that act as the primary structural elements. Small, wide-tracked labels ({typography.label}) serve as section markers. The result is an austere, confident, and highly structured visual language that feels more like a gallery wall than a webpage. Key Characteristics: - Monochrome palette: The system uses only black ({colors.ink}), white ({colors.canvas-light}), and one near-black ({colors.canvas-dark}). Color is used for surface inversion, not ac...

Color tokens:
- canvas-light: #ffffff
- canvas-dark: #111111
- ink: #111111
- ink-strong: #000000
- on-dark: #ffffff
- hairline-on-light: #2b2b2b
- hairline-on-dark: #ffffff

Typography tokens:
- display-lg: family Teg, Migra, Canela Display, serif, size 86px, weight 600, line 1.04, tracking -2.84px
- display-md: family Teg, Migra, Canela Display, serif, size 58px, weight 500, line 1.05, tracking -1px
- title-lg: family Beatrice Display, Tiempos Headline, serif, size 26px, weight 600, line 1.15, tracking 0
- body-lg: family Diatype, Söhne, Inter, sans-serif, size 26px, weight 500, line 1.15, tracking 0
- nav-link: family Diatype, Söhne, Inter, sans-serif, size 26px, weight 500, line 1.15, tracking 0
- nav-link-strong: family Diatype, Söhne, Inter, sans-serif, size 26px, weight 700, line 1.15, tracking 0
- label: family New Grotesk, Space Grotesk, sans-serif, size 14px, weight 600, line 1, tracking 1px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 16px
- md: 24px
- lg: 32px
- xl: 40px
- xxl: 56px
- section: 104px

Radius and shape tokens:
- none: 0px

Component tokens:
- top-nav: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, padding: 0 40px
- section-label-on-light: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.label}
- section-label-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.label}
- list-item-display-on-light: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.display-lg}
- list-item-display-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-lg}
- list-item-title-on-light: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.display-md}
- list-item-title-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-md}
- canvas-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, padding: 104px 40px

Color rationale: Surface The system is built on a binary color scheme that alternates between two full-bleed canvas colors to delineate sections. - Canvas Light ({colors.canvas-light} — ffffff): The primary page floor for default sections. - Canvas Dark ({colors.canvas-dark} — 111111): The inverted page floor for alternate sections. Text Text color is determined by the surface it rests on, maintaining high contrast. - Ink ({colors.ink} — 111111): The default text color on light surfaces. Same value as {colors.canvas-dark}. - Ink Strong ({colors.ink-strong} — 000000): Used for text requiring maximum contrast against the white canvas. - On Dark ({colors.on-dark} — ffffff): The text color used on dark surfaces. Same value as {colors.canvas-light}. Hairlines & Borders - Hairline on Light ({colors.hairline-on-light} — 2b2b2b): A subtle, darker-than-ink tone for low-emphasis rules on light surfaces, though used sparingly. - Hairline on Dark ({colors.hairline-on-dark} — ffffff): A white hairline for dividers on dark surfaces.

Typography rationale: Font Family The system uses a curated set of typefaces, each with a specific architectural role. - Teg: A sharp serif display face used for the largest text blocks. Its tight, aggressive tracking is a defining characteristic. Substitute with Migra or Canela Display. - Beatrice Display: A secondary serif for mid-scale titles, providing a calmer counterpoint to Teg. Substitute with Tiempos Headline. - Diatype: A workhorse sans-serif for all navigation and body copy. Substitute with Söhne or Inter. - New Grotesk: A geometric sans used exclusively for small, wide-tracked, all-caps section labels. Substitute with Space Grotesk. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 86px | 600 | 1.04 | -2.84px | Primary structural text blocks; set in Teg with aggressive negative tracking | | {typography.display-md} | 58px | 500 | 1.05 | -1px | Secondary structural text blocks; set in Teg or Beatrice Display | | {typography.title-lg} | 26px | 600 | 1.15 | 0 | Supporting titles, set in Beatrice Display | | {typography.body-lg} | 26px | 500 | 1.15 | 0 | Main text for navigation and body copy, set in Diatype | | {typogr...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 40px · {spacing.xxl} 56px · {spacing.section} 104px. - Section padding (vertical): The system uses a single, generous {spacing.section} (104px) for the top and bottom padding of all major content sections. This creates a calm, spacious rhythm. - Content column margin: All content is pinned to a left margin of {spacing.xl} (40px) from the viewport edge. - Element gap: A standard {spacing.sm} (16px) is used between smaller adjacent elements. The gap between large display text blocks is near-zero (0-4px) to form a cohesive visual block. Grid & Container - Max content width: ~1400px, though there is no visible container. - Layout: The entire page uses a single, left-aligned column. There is no grid, no right rail, and no centered content. The right side of the page is intentionally left as negative space. The width of the content column is determined organically by the length of the text itself. - Sectioning: Sections are not defined by cards or dividers, but by full-bleed changes in the background color between {colors.canvas-light...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border, no fill | All text elements and layout sections | The elevation philosophy is entirely flat. There are no drop shadows, gradients, or other effects used to simulate depth. Sectioning and hierarchy are achieved exclusively through color inversion, typographic scale, and spatial arrangement. This is a 2D-native system.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Universal. All corners are sharp. | The system uses zero border-radius. All elements are rectilinear, reinforcing the architectural and print-inspired aesthetic.

Component language: Navigation top-nav — A single horizontal row at the very top of the viewport. It uses flexbox with space-between to distribute four text items across the full width, with {spacing.xl} (40px) of horizontal padding from the viewport edges. Most links use {typography.nav-link}. The leftmost link, acting as the primary anchor, uses {typography.nav-link-strong} for emphasis. Content Blocks canvas-light / canvas-dark — These are the fundamental building blocks of the page. Each is a full-bleed section with a solid background color ({colors.canvas-light} or {colors.canvas-dark}) and generous {spacing.section} (104px) vertical padding. They contain the labels and text items. section-label-on-light / section-label-on-dark — A small, wide-tracked typographic marker used to introduce a content section. It uses {typography.label} and sits above the main content blocks. Its color inverts depending on the canvas it's on. list-item-display-on-light / list-item-display-on-dark — The primary content unit. This is an oversized text block set in {typography.display-lg}. These items are stacked vertically with a near-zero gap between them, forming what appears to be a single, solid wall of type. They...

Guardrails: Do - Use exactly two surfaces — {colors.canvas-light} and {colors.canvas-dark} — and alternate them as full-bleed sections to create rhythm. - Set primary display text in {typography.display-lg}. The aggressive negative letter-spacing is essential to the "wall of text" aesthetic. - Use {typography.label} for all section markers. The wide letter-spacing is the system's only "decorative" move. - Distribute nav items across the full viewport width using space-between. Never cluster them. - Pin all content to a {spacing.xl} (40px) left margin. - Use {spacing.section} (104px) for the major vertical padding to maintain the page's calm rhythm. Don't - Do not introduce any color beyond the core monochrome palette. - Do not add images, thumbnails, or icons. The system is pure typography. - Do not center text or align it to a grid. All content is left-pinned. - Do not use card containers, rounded corners, or drop shadows. The system has zero elevation and zero radius. - Do not add hover effects, underlines, or button styles to text items. They are presentational, not interactive. - Do not mix typefaces within a single text block. Each role has one designated font.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- restrained compositions with generous negative space and high typographic confidence
- approachable color beats, simple geometry, and lively but controlled rhythm
- technical dashboards, calibrated readouts, fine gridlines, and annotated systems diagrams

Chart and infographic grammar:
- Charts must inherit the DESIGN.md palette, typography scale, stroke weight, corner radius, spacing, and grid density.
- Use brand...
```
