# Amethyst

**ID:** `amethyst`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#9f8dfc`
- `#bf7af0`
- `#a667ff`
- `#000000`
- `#111111`
- `#141716`
- `#21222b`
- `#ffffff`
- `#272626`
- `#424242`

## Typography

Families: "'JetBrains Mono', ui-monospace, monospace", "'Suisse Int''l', -apple-system, BlinkMacSystemFont, sans-serif", "'Suisse Int''l', sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Liveblocks

Design token description: A clinical, high-contrast interface built on a pure black (000000) canvas. The system uses a single Swiss grotesque typeface for all UI text, creating a monastic and precise rhythm. Color is severely rationed: a vivid violet-magenta (9f8dfc) provides the sole brand accent for states and highlights, while a secondary neon palette (teal, blue) is reserved strictly for code syntax and in-product UI. Separation is achieved through 1px hairlines, not shadows, reinforcing the flat, diagrammatic aesthetic. This strict grid is intentionally broken by two elements — a dramatic, soft-focus magenta cloud texture behind hero elements, and hand-drawn brush annotations layered over product visuals.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This system is a study in high-contrast minimalism, built on a pure black obsidian canvas ({colors.canvas-void} — 000000). Every surface is flat, with separation defined by 1px hairlines ({colors.hairline} — 272626) rather than shadows. The entire interface runs on a single Swiss grotesque typeface, used for everything from 64px display headlines to 10px micro-copy. Display sizes are set with tight negative tracking and compressed line heights, giving headlines a dense, architectural feel. Color is rationed and functional. A vivid violet-magenta ({colors.primary} — 9f8dfc) serves as the sole brand accent, reserved for active states, underlines, and announcement badges. A secondary neon palette (teal, electric blue) is strictly cordoned off, appearing only within code syntax highlighting and product UI mockups. The default state is monochrome: white text on a black canvas. This severe, clinical grid is intentionally disrupted by two organic elements: a dramatic, soft-focus magenta cloud texture that erupts behind hero product mockups, and hand-drawn brush-script annotations layered over screenshots. These moments of "controlled chaos" add a human, sketchbook-like quality to an othe...

Color tokens:
- primary: #9f8dfc
- primary-strong: #bf7af0
- primary-hover: #a667ff
- canvas-void: #000000
- surface-obsidian: #111111
- surface-carbon: #141716
- surface-graphite: #21222b
- surface-inverted: #ffffff
- hairline: #272626
- divider-strong: #424242
- text-light: #ffffff
- text-body: #edecee
- text-muted: #918d8d
- text-muted-strong: #a3a3a3

Typography tokens:
- hero-display: family 'Suisse Int''l', -apple-system, BlinkMacSystemFont, sans-serif, size 64px, weight 400, line 1.05, tracking -1.28px
- display-lg: family 'Suisse Int''l', sans-serif, size 48px, weight 400, line 1.1, tracking -0.96px
- display-md: family 'Suisse Int''l', sans-serif, size 32px, weight 400, line 1.2, tracking -0.32px
- display-sm: family 'Suisse Int''l', sans-serif, size 24px, weight 400, line 1.25, tracking -0.24px
- title-md: family 'Suisse Int''l', sans-serif, size 20px, weight 500, line 1.33, tracking -0.1px
- body-md: family 'Suisse Int''l', sans-serif, size 16px, weight 400, line 1.5, tracking 0.096px
- body-sm: family 'Suisse Int''l', sans-serif, size 14px, weight 400, line 1.43, tracking 0.056px
- caption: family 'Suisse Int''l', sans-serif, size 12px, weight 500, line 1.38, tracking 0.12px
- micro: family 'Suisse Int''l', sans-serif, size 10px, weight 500, line 1, tracking 0.25px
- button: family 'Suisse Int''l', sans-serif, size 14px, weight 500, line 1, tracking 0
- nav-link: family 'Suisse Int''l', sans-serif, size 14px, weight 500, line 1.43, tracking 0
- code-body: family 'JetBrains Mono', ui-monospace, monospace, size 14px, weight 400, line 1.43, tracking 0.35px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 80px

Radius and shape tokens:
- sm: 4px
- md: 8px
- lg: 12px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-filled: backgroundColor: {colors.surface-inverted}, textColor: {colors.text-on-inverted}, typography: {typography.button}, rounded: {rounded.sm}, padding: 12px 20px
- button-secondary-dark: backgroundColor: {colors.surface-obsidian}, textColor: {colors.text-light}, typography: {typography.button}, rounded: {rounded.sm}, padding: 12px 20px
- button-tertiary-ghost: backgroundColor: transparent, textColor: {colors.text-light}, typography: {typography.button}, rounded: {rounded.sm}, padding: 8px 16px
- text-link-arrow: backgroundColor: transparent, textColor: {colors.text-light}, typography: {typography.button}
- announcement-badge-pill: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 6px 14px
- top-nav-bar: backgroundColor: {colors.canvas-void}, textColor: {colors.text-muted}, typography: {typography.nav-link}, height: 64px
- product-editor-panel: backgroundColor: {colors.surface-graphite}, textColor: {colors.text-body}, typography: {typography.body-sm}, rounded: {rounded.md}
- code-block: backgroundColor: {colors.surface-carbon}, textColor: {colors.text-body}, typography: {typography.code-body}, rounded: {rounded.md}, padding: 24px

Color rationale: Brand & Accent - Plasma Violet ({colors.primary} — 9f8dfc): The primary brand accent. Used for announcement badge borders and text, active underlines, and brand glow effects. It is never used as a solid background fill for buttons or large surfaces. - Ultraviolet ({colors.primary-strong} — bf7af0): A secondary, more saturated violet used for code syntax keywords and badge fills. - Wisteria ({colors.primary-hover} — a667ff): A deeper violet for hover states and gradient accents. - Ember Pink ({colors.accent-pink} — f76e99): The base color of the atmospheric magenta cloud texture used behind hero elements. It's the system's only use of a warm, organic color. Surface The system uses a four-step scale of near-black surfaces to create depth without shadows. - Void Canvas ({colors.canvas-void} — 000000): The absolute base layer for all pages. - Obsidian Surface ({colors.surface-obsidian} — 111111): The first elevated level for dark-filled buttons, dropdowns, and active tabs. - Carbon Layer ({colors.surface-carbon} — 141716): The second level, used specifically for the background of code blocks. - Graphite Panel ({colors.surface-graphite} — 21222b): The highest surface level, used for in...

Typography rationale: Font Family The system relies on a two-font structure: a primary Swiss grotesque for all interface text and a secondary monospace for code. - Interface Font: Suisse Int'l is the sole typeface for all headings, body copy, buttons, and labels. Its clinical, geometric quality defines the system's voice. - Code Font: JetBrains Mono is used exclusively inside code blocks and for technical annotations, providing clear, legible monospace rendering. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 64px | 400 | 1.05 | -1.28px | Main hero headlines | | {typography.display-lg} | 48px | 400 | 1.1 | -0.96px | Section headlines | | {typography.display-md} | 32px | 400 | 1.2 | -0.32px | Sub-section headlines | | {typography.display-sm} | 24px | 400 | 1.25 | -0.24px | Card titles, large labels | | {typography.title-md} | 20px | 500 | 1.33 | -0.1px | Feature titles, modal headers | | {typography.body-md} | 16px | 400 | 1.5 | 0.096px | Default running text | | {typography.body-sm} | 14px | 400 | 1.43 | 0.056px | Secondary body, component text | | {typography.caption} | 12px | 500 | 1.38 | 0.12px | Metadata, labels, badg...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) is standard between major content bands. - Card internal padding: {spacing.lg} (24px) to {spacing.xl} (32px) is used for most content cards and code blocks. - Gutters: {spacing.md} (16px) is common between elements in a tight cluster; {spacing.lg} (24px) is used for grid gutters. Grid & Container - Max content width: ~1200px, centered. - Editorial body: Content typically sits within a standard 12-column grid. Feature lists and grids often resolve to 2-up or 3-up layouts. Whitespace Philosophy The system is compact and dense. Whitespace is used precisely to structure content, not to create an airy, open feel. The pure black canvas makes even small amounts of space feel significant. The primary role of layout is to create a clear, diagrammatic hierarchy.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Canvas) | {colors.canvas-void} background | Page floor, full-bleed sections | | 1 (Surface) | {colors.surface-obsidian} background, 1px {colors.hairline} border | Dark-filled buttons, nav bar, elevated panels | | 2 (Code) | {colors.surface-carbon} background, 1px {colors.hairline} border | Code block backgrounds | | 3 (Product UI) | {colors.surface-graphite} background | Nested UI panels inside product mockups | | Inverted | {colors.surface-inverted} background | Primary CTA buttons, comment cards | The elevation philosophy is strictly anti-shadow. Depth is communicated exclusively through a four-step scale of near-black surfaces and the consistent use of 1px {colors.hairline} borders. This creates a flat, clinical aesthetic where every surface boundary is explicitly drawn. There are no gradients (except for the decorative hero cloud) and no blurs.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 4px | Buttons, inputs — the default for interactive elements | | {rounded.md} | 8px | Cards, product editor panels, code blocks | | {rounded.lg} | 12px | Modals and larger containers | | {rounded.pill} | 9999px | Announcement badges | | {rounded.full} | 9999px / 50% | Avatars | The system uses sharp, small radii. The default for most interactive elements is a tight 4px, reinforcing the precise, engineered feel. The pill radius is reserved for a single, specific component: the announcement badge. Photography & Iconography - The system is photography-free. Visual content consists of product UI mockups. - All partner/customer logos are desaturated to {colors.text-muted-strong}, removing all external brand colors to maintain the system's monochrome integrity. - A key visual element is the use of hand-drawn, brush-script annotations and arrows overlaid on product screenshots, adding a human touch that contrasts with the geometric UI.

Component language: Buttons & Links button-primary-filled — The single primary call-to-action. A solid {colors.surface-inverted} (white) background with {colors.text-on-inverted} (black) text. It has a {rounded.sm} (4px) radius and is used sparingly for the most important action on a page. button-secondary-dark — A subtle, recessed button. It uses an {colors.surface-obsidian} background with a {colors.hairline} border and {colors.text-light} text. button-tertiary-ghost — The most common secondary button. Transparent background with a 1px {colors.text-light} border and {colors.text-light} text. text-link-arrow — A standard inline link, rendered in {colors.text-light} with a rightward arrow (→) suffix. It has no background or border. Badges & Navigation announcement-badge-pill — A pill-shaped badge used above hero headline...
```
