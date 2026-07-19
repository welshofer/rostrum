# Hush

**ID:** `hush`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#000000`
- `#ffffff`
- `#dbdad9`
- `#808080`

## Typography

Families: "'PT Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace", "HaasR, -apple-system, BlinkMacSystemFont, sans-serif", "HaasT, HaasR, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 100, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Silencio

Design token description: A monochrome gallery aesthetic anchored on a stark white canvas. The system operates as a form of visual silence, where every element earns its space against negative volume. Typography provides the primary texture, with extreme contrast between huge, whisper-thin display headlines (141px) and small monospaced metadata labels. There are no chromatic accents; a single warm paper-gray (dbdad9) is the only departure from pure black-on-white. Surfaces are paper-flat, separated by hairline rules and distinct radii rather than elevation or shadow. Components feel like printed catalog pages, with full-pill buttons and cards that often feature a single rounded corner, creating a composition that breathes with minimalist confidence.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This system operates as a form of visual silence — a monochrome gallery where elements float on a stark white canvas and typography does almost all the expressive work. The system strips away every non-essential element: no chromatic accents, no shadows, no decorative geometry. Instead, it relies on extreme typographic contrast — a 141px display face ({typography.hero-display}) whispers next to 9px metadata ({typography.caption}) — and a single warm paper-gray ({colors.surface-card} — dbdad9) as the only departure from pure black-on-white. Surfaces are paper-flat, separated by hairline rules ({colors.hairline}) and distinctive, specific corner radii ({rounded.sm} at 7.2px) rather than elevation. The voice reads like museum wall text: centered, brief, and formal, with monospaced labels ({typography.label}) used as quiet signatures next to a primary Haas-style grotesque. Components feel more like a printed catalog than a digital UI; buttons are extreme pill shapes ({rounded.full} at 129.6px), cards are simple color blocks, and the entire composition breathes with the confidence of a room with nothing on its walls. Key Characteristics: - Strict Monochrome Palette: The system uses onl...

Color tokens:
- ink: #000000
- canvas: #ffffff
- surface-card: #dbdad9
- hairline: #000000
- hairline-muted: #808080
- body: #000000
- muted: #808080
- on-surface: #000000

Typography tokens:
- hero-display: family HaasT, HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 141px, weight 100, line 0.9, tracking 0
- display-md: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 58px, weight 100, line 0.9, tracking 0
- display-sm: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 39px, weight 100, line 1, tracking 0
- title-lg: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 22px, weight 400, line 1.1, tracking 0
- title-md: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 19px, weight 400, line 1.2, tracking 0
- body-md: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.4, tracking 0
- body-sm: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.4, tracking 0
- label: family 'PT Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace, size 11px, weight 400, line 1.2, tracking 0
- caption: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 9px, weight 400, line 1.2, tracking 0
- button: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1, tracking 0
- nav-link: family HaasR, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.4, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 7px
- sm: 14px
- md: 16px
- lg: 29px
- xl: 43px
- xxl: 72px
- section: 144px

Radius and shape tokens:
- sm: 7.2px
- lg: 43.2px
- pill: 9999px
- full: 129.6px

Component tokens:
- button-pill: backgroundColor: transparent, borderColor: {colors.ink}, borderWidth: 1px, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.full}, padding: 14px 29px
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md}
- paper-card: backgroundColor: {colors.surface-card}, textColor: {colors.on-surface}, rounded: {rounded.sm}, padding: {spacing.lg}
- display-headline: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.hero-display}
- museum-label: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.label}
- hairline-divider: backgroundColor: {colors.hairline}, height: 1px
- table-rule: backgroundColor: {colors.hairline-muted}, height: 1px
- centered-statement: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.title-lg}

Color rationale: The palette is intentionally spartan, designed to evoke the feeling of ink on paper in a gallery setting. Core Palette - Ink ({colors.ink} — 000000): The primary color for all text, iconography, and primary rule lines. It is the only high-contrast element on the page. - Canvas ({colors.canvas} — ffffff): The dominant background and page floor. It functions as the negative space against which all other elements are set. - the source brand Card ({colors.surface-card} — dbdad9): The single chromatic departure from pure white. Used for card surfaces, soft fills, and as the origin point for the system's only sanctioned gradient. Hairlines & Borders - Hairline ({colors.hairline} — 000000): The default 1px border and divider tone. - Hairline Muted ({colors.hairline-muted} — 808080): A softer graphite gray for subtle table dividers and secondary rule lines, used where pure black would feel too heavy.

Typography rationale: Font Family The system is built on a strict three-font hierarchy, each with a non-negotiable role. - HaasR → The workhorse grotesque. Used for body copy, subheadings, and mid-size titles. A light weight (100) is used for restraint, while 400/700 are used for standard text and emphasis. - HaasT → The display-only face. Reserved for {typography.hero-display} at 141px with tightened leading. It is the system's loudest voice, used for singular, impactful statements. - PT Mono → The metadata face. Appears only at 11px for spec labels, catalog tags, and captions. It functions as a typographic signature, like a printed museum label. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 141px | 100 | 0.9 | 0 | Singular hero statements, once per page | | {typography.display-md} | 58px | 100 | 0.9 | 0 | Major section headings | | {typography.display-sm} | 39px | 100 | 1.0 | 0 | Sub-section headings | | {typography.title-lg} | 22px | 400 | 1.1 | 0 | Editorial statement blocks, card titles | | {typography.body-md} | 16px | 400 | 1.4 | 0 | Default running-text | | {typography.body-sm} | 12px | 400 | 1.4 | 0 | Button lab...

Layout system: Spacing System - Base unit: 4px, though the scale is irregular and favors specific aesthetic gaps over a strict mathematical progression. - Tokens: {spacing.xxs} 4px · {spacing.xs} 7px · {spacing.sm} 14px · {spacing.md} 16px · {spacing.lg} 29px · {spacing.xl} 43px · {spacing.xxl} 72px · {spacing.section} 144px. - Section gap (vertical): {spacing.xl} (43px) between major content blocks. - Card internal padding: {spacing.lg} (29px) is standard for most cards. - Element gap (gutters): {spacing.xs} (7px) for fine-tuned spacing between adjacent small elements. Grid & Container - Max content width: 1440px, centered. - Grid: The grid is loose and often ignored in favor of centered, single-column text blocks or asymmetrical arrangements of text and imagery. There is no rigid column structure. - Content Rhythm: The layout alternates between quiet, text-only bands and sparse, object-laden bands where a single image can occupy a large portion of the viewport. Whitespace Philosophy Whitespace is a primary design material. The system uses generous vertical spacing ({spacing.section}) and an uncluttered canvas to create a sense of calm and focus. Content is never crowded; the layout prioritizes...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Flat) | No effect, {colors.canvas} background | The default page floor, body sections, text blocks | | 1 (the source brand) | {colors.surface-card} background fill, no shadow | All cards and soft-fill areas ({component.paper-card}) | | 2 (Gradient) | Linear gradient from {colors.surface-card} to transparent | The only sanctioned depth effect, used to gently lift a section off the page | | 3 (Stroke) | 1px border in {colors.hairline} or {colors.hairline-muted} | Hairline dividers, table rules, outline buttons | The elevation model is strictly paper-flat. Depth is implied only through the contrast of the warm gray {colors.surface-card} on the white {colors.canvas}. Drop shadows, blurs, and glows are forbidden.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 7.2px | Content cards ({component.paper-card}) | | {rounded.lg} | 43.2px | Large the source brand containers | | {rounded.pill} | 9999px | Small, fully-rounded tags or labels | | {rounded.full} | 129.6px | The signature radius for primary pill buttons | The system uses a highly specific and unconventional set of radii. These values are intentional and should not be substituted with standard 8px or 16px values. Photography & Iconography - Imagery is treated as a "floating artifact." Product photos are rendered on a transparent background and placed directly on the {colors.canvas} with no frame, shadow, or container. - Iconography is minimal and line-based, rendered in {colors.ink} at 1px stroke width.

Component language: Buttons & Links button-pill — The primary interactive element. It is an outline-only button with a transparent fill, a 1px {colors.hairline} border, and an extreme {rounded.full} (129.6px) radius. The label uses {typography.button}. It is defined by its shape, not its color. text-link — Inline navigation links. They appear as standard body text in {colors.ink} with no default underline or color change, to maintain the flow of text. An underline may appear on interaction. Cards & Containers paper-card — The primary content container. It uses a {colors.surface-card} background, a {rounded.sm} (7.2px) radius, and {spacing.lg} (29px) of internal padding. It provides the only moment of warmth on the page. display-headline — A typographic component for hero sections. Renders text in {typography.hero-display} and is almost always paired with a {component.museum-label} directly beneath it. museum-label — A metadata component using {typography.label} (PT Mono). It acts as a caption or spec tag for headlines and images, evoking a museum-style label. Structure & Dividers hairline-divider — A 1px solid line in {colors.hairline}. It is the primary tool for separating content sections, replacin...

Guardrails: Do - Use the full 141px {typography.hero-display} for hero statements; it is the only moment the system should feel "loud." - Use {colors.surface-card} as the only chromatic the source brand. Every other the source brand should be {colors.canvas} or {colors.ink}. - Separate content with 1px {colors.hairline} dividers, not shadows or heavy padding. - Pair every display headline with a {component.museum-l...
```
