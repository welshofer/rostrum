# Noir

**ID:** `noir`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#000000`
- `#ffffff`
- `#888888`
- `#cacaca`
- `#eeeeee`

## Typography

Families: "'NB International Mono Web', ui-monospace, monospace", "'NB International Web', -apple-system, BlinkMacSystemFont, sans-serif", "'NB International Web', sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: A24

Design token description: A cinematic editorial system built on pure monochrome, where typography does all the emotional work. The design alternates full-bleed black (000000) and white (ffffff) bands, using a custom humanist sans-serif at extreme sizes to let headlines become visual artifacts. Every UI element is stripped to its barest form — hairline borders, zero radius, zero shadow, zero chromatic accent. The system's restraint IS its character; it borrows the visual grammar of a high-contrast opening title sequence, expressing confidence through absence rather than addition.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a cinematic, editorial system built on a foundation of pure monochrome. Its character comes from what it omits: there are no chromatic accents, no gradients, no shadows, and no rounded corners. The design alternates full-bleed black ({colors.canvas-dark}) and white ({colors.canvas-light}) bands, creating a stark, rhythmic page structure. Typography does all the emotional and hierarchical work, using a single custom humanist sans-serif family (NB International Web) at extreme scales — from a whisper-thin 10px caption to a commanding 74px display headline ({typography.display}). These headlines are set with tight line-height and negative tracking, allowing them to stack into dense, poster-like blocks that feel more like visual artifacts than text. Every element is stripped to its barest functional form, trusting high contrast and generous negative space to guide the user's eye. Key Characteristics: - Strictly achromatic palette: {colors.ink} (000000) and {colors.canvas-light} (ffffff) are the only functional colors for text, surfaces, and borders. - Single primary typeface: A custom humanist sans-serif carries every role from 74px display to 10px captions. A mono companion (...

Color tokens:
- ink: #000000
- body: #ffffff
- body-on-light: #000000
- muted: #888888
- hairline-on-light: #cacaca
- hairline-on-dark: #ffffff
- canvas-light: #ffffff
- canvas-dark: #000000
- surface-soft-light: #eeeeee
- on-dark: #ffffff

Typography tokens:
- display: family 'NB International Web', -apple-system, BlinkMacSystemFont, sans-serif, size 74px, weight 400, line 0.92, tracking -2.96px
- heading-sm: family 'NB International Web', sans-serif, size 21px, weight 400, line 1.3, tracking -0.18px
- subheading: family 'NB International Web', sans-serif, size 18px, weight 400, line 1.33, tracking -0.09px
- body-md: family 'NB International Web', sans-serif, size 15px, weight 400, line 1.5, tracking 0
- caption: family 'NB International Web', sans-serif, size 10px, weight 400, line 1.5, tracking 0.14px
- button: family 'NB International Web', sans-serif, size 11px, weight 400, line 1.3, tracking 1.5px
- nav-link: family 'NB International Web', sans-serif, size 13px, weight 400, line 1.3, tracking 0.1px
- mono-label: family 'NB International Mono Web', ui-monospace, monospace, size 15px, weight 400, line 0.92, tracking -1px

Spacing tokens:
- xxs: 4px
- xs: 9px
- sm: 18px
- md: 22px
- lg: 36px
- xl: 56px
- xxl: 96px
- section: 96px

Radius and shape tokens:
- none: 0px
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- top-nav: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, height: 56px
- hero-display-band: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.display}, padding: 96px 0
- light-band: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.body-md}, padding: 96px 0
- text-link-with-arrow: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md}
- item-card: backgroundColor: {colors.surface-soft-light}, textColor: {colors.ink}, rounded: {rounded.none}, padding: 22px
- signup-modal: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.body-md}, rounded: {rounded.none}
- text-input-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.none}, padding: 22px 18px, border: 1px solid {colors.hairline-on-dark}
- button-primary-on-dark: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.none}, padding: 22px 18px

Color rationale: Brand & Accent The system has no brand or accent color. The identity is defined by its strict adherence to an achromatic palette. Surface The system is built on two primary canvas tones that alternate in full-bleed sections. - Canvas Dark ({colors.canvas-dark} — 000000): Pure black, used for hero bands, dark-themed sections, and modal overlays. - Canvas Light ({colors.canvas-light} — ffffff): Pure white, used for light-themed sections and as the background for primary submission buttons. - Surface Soft Light ({colors.surface-soft-light} — eeeeee): A subtle off-white used for item card backgrounds to gently lift them from the pure white canvas. Hairlines & Borders Borders are used sparingly and are always 1px hairlines. - Hairline on Light ({colors.hairline-on-light} — cacaca): A very light gray for minimal separators on white surfaces. - Hairline on Dark ({colors.hairline-on-dark} — ffffff): A pure white hairline for borders on black surfaces, like on the {component.text-input-on-dark}. Text Text color is always a direct contrast to its background surface. - Ink ({colors.ink} — 000000): Pure black text, used on light surfaces. - On Dark ({colors.on-dark} — ffffff): Pure white text...

Typography rationale: Font Family The system relies on a primary custom humanist sans-serif, NB International Web, for nearly all text. It is paired with a monospaced companion, NB International Mono Web, for technical annotations. - NB International Web: Used for display headlines, body copy, navigation, and button labels. It scales from 10px to 74px using only weights 400 and 500. - NB International Mono Web: Used exclusively for small, data-like labels (e.g., year markers) that need to feel distinct from the primary editorial voice. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display} | 74px | 400 | 0.92 | -2.96px | Hero headlines, stacked to form poster-like blocks | | {typography.heading-sm} | 21px | 400 | 1.3 | -0.18px | Item titles, section sub-headers | | {typography.subheading} | 18px | 400 | 1.33 | -0.09px | Introductory text blocks | | {typography.body-md} | 15px | 400 | 1.5 | 0 | Default running-text | | {typography.caption} | 10px | 400 | 1.5 | 0.14px | Small uppercase meta labels | | {typography.button} | 11px | 400 | 1.3 | 1.5px | Uppercase button and input labels | | {typography.nav-link} | 13px | 400 | 1.3 | 0.1px | T...

Layout system: Spacing System - Base unit: An irregular but consistent scale. - Tokens: {spacing.xxs} 4px · {spacing.xs} 9px · {spacing.sm} 18px · {spacing.md} 22px · {spacing.lg} 36px · {spacing.xl} 56px · {spacing.xxl} 96px · {spacing.section} 96px. - Section padding (vertical): {spacing.section} (96px) provides generous breathing room between the alternating black and white content bands. - Card internal padding: {spacing.md} (22px) is used for the internal padding of item cards and form controls. - Gutters: {spacing.xs} (9px) is the default gap between adjacent elements within a component. Grid & Container - Full-bleed: The layout model rejects a constrained max-width. All section backgrounds and many content elements bleed to the edges of the viewport. - Asymmetric splits: A common pattern is a two-column layout with left-aligned text and a right-aligned image block, or vice-versa. - Left-alignment: All text is strictly left-aligned. There is no centered or right-aligned copy. Whitespace Philosophy The system uses whitespace as a primary design tool. The generous {spacing.section} gap between content bands emphasizes the stark contrast and creates a deliberate, paced rhythm for scrolling. W...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The default state for all body sections, text, and images. | | Surface lift | Contrasting background color (e.g., {colors.surface-soft-light} on {colors.canvas-light}) | Item cards are lifted from the canvas via a subtle color shift, not shadow. | | Hairline | 1px {colors.hairline-on-light} or {colors.hairline-on-dark} | The only border treatment, used to define input fields or subtle separators. | The elevation philosophy is strictly flat. There are no drop shadows, inner shadows, or gradients used to imply a z-axis. Depth is created exclusively through value contrast: a black section feels like a void, a white section feels like a surface, and an object on that surface is defined by a hairline or a subtle shift in background color.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Universal. Applied to all buttons, inputs, cards, modals, and images. | The system's shape language is defined by sharp, 0px corners. This is a non-negotiable rule that contributes to the precise, architectural, and editorial aesthetic. Every rectangle is a perfect rectangle. Photography & Iconography - Imagery is typically presented in unadorned rectangular frames with {rounded.none} corners. Photos are often high-contrast black-and-white to match the surrounding UI. - Icons are simple, monochrome line glyphs with a thin (~1.5px) stroke. They include basic UI controls like a hamburger menu, search icon, and directional arrows. They do not have fills and match the color of surrounding text.

Component language: Navigation top-nav — A minimal, transparent, fixed-position bar that floats over page content. It contains a hamburger menu trigger on the left and a search icon on the right. Text and icon colors adapt to the background section they are over (black on white, white on black). Content Blocks hero-display-band — The primary opening component. A full-bleed {colors.canvas-dark} band containing large, stacked headlines set in {typography.display}. These headlines are the main visual focus of the page. Often paired with a small {typography.mono-label} for a year or other metadata. item-card — A simple container for showcasing a single item. It uses a {colors.surface-soft-light} background to create a subtle separation from a white canvas, with sharp {rounded.none} corners and {spacing.md} of internal padding around a central image. Forms & Modals signup-modal — A full-screen overlay with a {colors.canvas-dark} background. It features minimal, uppercase caption text and a form group composed of an input field and button. text-input-on-dark — An input field with a transparent background, defined only by a 1px {colors.hairline-on-dark} border on its left, top, and bottom sides. The right s...

Guardrails: Do - Use {colors.canvas-dark} and {colors.canvas-light} as the only background values for major sections, alternating them to create visual rhythm. - Set display headlines in {typography.display} (74px / 400) with its specific tight leading and tracking. - Use {rounded.none} (0px) border-radius on every component. Sharp edges are a core principle. - Keep all body copy and headlines left-aligned. - Rely on contrast and...
```
