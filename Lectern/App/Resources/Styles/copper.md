# Copper

**ID:** `copper`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#f35815`
- `#000000`
- `#111111`
- `#414141`
- `#737373`
- `#c1c1c1`
- `#fafafa`
- `#e5e5e5`
- `#0b6ec5`
- `#f2b600`

## Typography

Families: "'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: PlanetScale

Design token description: A developer-first, terminal-flavored interface defined by its exclusive use of monospace type. The palette is overwhelmingly achromatic—deep charcoal text (414141) on a near-white canvas (fafafa)—with a vivid orange (f35815) as the sole action accent and a restrained blue (0b6ec5) for links. Surfaces are flat and borderless; hierarchy is built through type weight, generous whitespace, and occasional hairline rules (c1c1c1) rather than shadow or elevation. Components are utilitarian, featuring pill-shaped buttons and sharp-cornered panels, creating an aesthetic of a technical man-page rather than a marketing site.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a developer-first, terminal-flavored system built on a foundation of typographic discipline. The entire interface speaks in fixed-width type, giving every screen the texture of a well-formatted README or man-page. The palette is overwhelmingly achromatic — deep charcoal text ({colors.body} — 414141) on a near-white canvas ({colors.canvas} — fafafa), establishing a stark, high-contrast reading environment. Color is used with extreme restraint. A vivid orange ({colors.primary} — f35815) serves as the sole action accent, reserved exclusively for primary CTA backgrounds. A secondary blue ({colors.link} — 0b6ec5) is used for all inline text links. No other chromatic tones appear in the UI, apart from a specific yellow ({colors.accent-highlight}) for inline banner highlights. Surfaces are flat and borderless; hierarchy is built through type weight, generous whitespace, and occasional hairline rules ({colors.hairline} — c1c1c1) rather than shadow or elevation. Components feel lightweight and utilitarian: pill-shaped buttons, plain text links, and raw grid tables with no decorative chrome. The result reads like a developer tool's reference page — confidence comes from typographic...

Color tokens:
- primary: #f35815
- ink: #000000
- ink-strong: #111111
- body: #414141
- muted: #737373
- hairline: #c1c1c1
- canvas: #fafafa
- surface-soft: #e5e5e5
- link: #0b6ec5
- accent-highlight: #f2b600
- on-primary: #fafafa
- on-dark: #fafafa

Typography tokens:
- display-md: family 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace, size 32px, weight 600, line 1.25, tracking -0.192px
- display-sm: family 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace, size 24px, weight 600, line 1.33, tracking -0.144px
- title-md: family 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace, size 18px, weight 500, line 1.5, tracking -0.108px
- body-md: family 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace, size 16px, weight 400, line 1.5, tracking -0.096px
- body-sm: family 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace, size 14px, weight 400, line 1.5, tracking -0.084px
- button: family 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace, size 14px, weight 600, line 1, tracking -0.084px
- nav-link: family 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace, size 14px, weight 500, line 1.5, tracking -0.084px

Spacing tokens:
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 40px
- lg: 48px
- xl: 56px
- section: 96px

Radius and shape tokens:
- none: 0px
- pill: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 16px
- button-ghost: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.nav-link}, padding: 8px 16px
- text-link: backgroundColor: transparent, textColor: {colors.link}, typography: {typography.body-md}
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.nav-link}, height: 56px
- announcement-banner: backgroundColor: {colors.ink-strong}, textColor: {colors.on-dark}, typography: {typography.body-sm}, padding: 8px 0
- announcement-highlight: backgroundColor: {colors.accent-highlight}, textColor: {colors.ink-strong}, typography: {typography.body-sm}, rounded: {rounded.pill}, padding: 2px 8px
- partner-grid-cell: backgroundColor: {colors.canvas}, borderColor: {colors.hairline}, borderWidth: 1px, rounded: {rounded.none}, padding: {spacing.xs}
- testimonial-quote: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}

Color rationale: Brand & Accent - Primary Orange ({colors.primary} — f35815): The single, high-voltage accent color. Used exclusively for the background of primary call-to-action buttons. Its purpose is to create an unmissable conversion point. - Link Blue ({colors.link} — 0b6ec5): The color for all inline hyperlinks. It is never used for backgrounds or other UI elements. - Accent Highlight ({colors.accent-highlight} — f2b600): A secondary yellow accent used for inline highlights within the dark announcement banner. Text - Ink ({colors.ink} — 000000): Pure black for maximum contrast. Used for all display-level headings. - Body ({colors.body} — 414141): The default text color for all paragraphs, labels, and secondary UI text. A softer-than-black charcoal. - Muted ({colors.muted} — 737373): A lighter gray for captions, secondary metadata, and attribution lines in testimonials. - On Primary ({colors.on-primary} — fafafa): The text color used on top of the orange primary CTA, ensuring high contrast. - On Dark ({colors.on-dark} — fafafa): The text color used on dark inverted surfaces, like the announcement banner. Surface & Borders - Canvas ({colors.canvas} — fafafa): The near-white page background and...

Typography rationale: Font Family The system exclusively uses a monospace font stack: 'ui-monospace', SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace. This choice is fundamental to the system's identity, creating a uniform character width that gives the entire interface the rhythm of a code editor or technical document. Proportional fonts (e.g., sans-serif or serif) are never used. Hierarchy Headlines use a heavier weight (600) for emphasis, while body copy defaults to a standard weight (400). The type scale is tight and functional, prioritizing readability in a dense, text-heavy context. A small negative letter-spacing is applied to slightly tighten the default spacing of the monospace glyphs. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-md} | 32px | 600 | 1.25 | -0.192px | Primary page headlines | | {typography.display-sm} | 24px | 600 | 1.33 | -0.144px | Section headlines | | {typography.title-md} | 18px | 500 | 1.5 | -0.108px | Sub-headings, secondary titles | | {typography.body-md} | 16px | 400 | 1.5 | -0.096px | Default running-text, paragraphs | | {typography.body-sm} | 14px | 400 | 1.5 | -0.084px | Small bod...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 40px · {spacing.lg} 48px · {spacing.xl} 56px · {spacing.section} 96px. - Section padding (vertical): {spacing.xl} (56px) or {spacing.section} (96px) is used between major content blocks, creating generous breathing room. - Card internal padding: {spacing.sm} (24px) is the standard for content cards. - Gutters: {spacing.xs} (16px) is the typical gap between adjacent elements within a component. Grid & Container - Max content width: A narrow 960px, centered. This reinforces the single-column, document-like reading experience. - Editorial body: Content flows in a single primary column. Grids are used for specific components like the partner media display, but the overall page structure is linear.

Depth and hierarchy: The system is intentionally and strictly flat. There are no drop shadows, glows, or z-axis layering effects. Depth and separation are communicated entirely through background color changes (e.g., an inverted dark banner on a light canvas) and thin, 1px hairline borders. | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top nav, testimonials | | Hairline Border | 1px {colors.hairline} | Partner grid cells, tab dividers | | Inverted Surface | {colors.ink-strong} background | Announcement banner, active tab state |

Shape language: Border Radius Scale The system uses a binary approach to shape: elements are either perfectly sharp or perfectly rounded. | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Cards, inputs, tabs, content panels, grid cells | | {rounded.pill} | 9999px | All buttons and inline tags | Imagery & Iconography The interface is nearly imageless by design. The primary visual content is the text itself. Where media is required (e.g., for social proof), it's displayed in a simple grid of {component.partner-grid-cell} containers. These cells are an exception to the monochrome palette, as their contents may retain original colors for recognizability. There is no photography or decorative illustration.

Component language: Buttons & Links button-primary — The single primary call-to-action. An orange ({colors.primary}) filled pill ({rounded.pill}) with light text ({colors.on-primary}). Its chromatic intensity makes it the focal point of any screen. button-ghost — A secondary, text-only button used for less-critical actions, typically in the navigation bar. It uses {colors.body} for text and has no background or border. text-link — A standard inline hyperlink, styled only with {colors.link} blue text. It does not have an underline by default. Navigation & Banners top-nav — A simple, 56px tall bar with a {colors.canvas} background. It is flat, with no border or shadow, and contains navigation links on the left/center and action buttons on the right. announcement-banner — A full-width, inverted strip at the top of the page. It has a dark ({colors.ink-strong}) background with light ({colors.on-dark}) text. announcement-highlight — A small, pill-shaped highlight used inline within the announcement banner to draw attention to a specific phrase. It uses an {colors.accent-highlight} background. Content & Containers headline-accent-bar — A purely decorative 2px wide vertical bar of {colors.primary} orange tha...

Guardrails: Do - Use {rounded.pill} for all buttons and tags; use {rounded.none} for all cards, inputs, and panels. - Reserve {colors.primary} (orange) exclusively for the background of the primary filled button. - Write all UI text in the monospace font family. - Anchor section headlines with the {component.headline-accent-bar}. - Use {colors.link} (blue) only for inline hyperlinks. - Keep page content within the 960px max-width container. Don't - Do not introduce proportional fonts (e.g., sans-serif). The monospace-only identity is fundamental. - Do not use {colors.link} as a button background or for any element other than a text link. - Do not add drop shadows, glows, or any other elevation effects. Surfaces must remain flat. - Do not use {colors.accent-highlight} for anything other than the specific inline banner highlight. - Do not use intermediate border-radius values. Stick to 0px or 9999px. - Do not stack multiple chromatic colors in a single component...
```
