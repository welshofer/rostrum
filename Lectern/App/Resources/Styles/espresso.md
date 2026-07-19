# Espresso

**ID:** `espresso`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#1d1610`
- `#fff5f2`
- `#ffffff`
- `#282828`
- `#000000`
- `#333333`

## Typography

Families: "'Inter', 'Söhne', -apple-system, sans-serif", "'wtqc', 'Inter Tight', 'Söhne Breit', -apple-system, sans-serif", "'wtqc', 'Inter', 'Söhne', -apple-system, sans-serif", "'wtqc', 'Roboto', 'Inter', -apple-system, sans-serif". Weights: 300, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Doug Alves

Design token description: A ruthlessly achromatic system built on a warm charcoal canvas (1d1610) and bone-white (fff5f2) surfaces. The visual identity is driven by a stark, 10:1 typographic scale contrast: monolithic display headlines run up to 197px in a whisper-thin light weight, while editorial body copy remains generous and readable at 18px. There are no chromatic accents; all energy comes from type scale and the hard-cut alternation between full-bleed dark and contained light sections. Layout is structured on crisp multi-column grids separated by hairline graphite (282828) rules, reinforcing a flat, architectural, and gallery-wall aesthetic.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system treats every viewport like a gallery wall: a single, massive piece of typographic art dominates the dark hero ({colors.canvas-dark}), after which the layout steps down into compact, editorial information grids. The palette is ruthlessly achromatic—warm espresso black, bone white, and graphite—with no chromatic accent; all visual energy comes from an extreme 10:1 type scale contrast. Headlines run at whisper-thin weights ({typography.hero-display}), while body copy remains generous and readable ({typography.body-lg}). Layout is full-bleed, with sections switching between warm-dark and white surfaces, and information is always arranged into crisp multi-column grids separated by hairline graphite rules ({colors.hairline}). Key Characteristics: - Achromatic Palette: No brand or accent color. The system uses a warm-tinted monochrome palette of {colors.canvas-dark} (1d1610), {colors.canvas-light} (fff5f2), {colors.ink} (282828), and {colors.ink-strong} (000000). - Extreme Typographic Scale: A two-register system creates a brutalist 10:1 size ratio between display type ({typography.hero-display} at 197px) and body copy ({typography.body-lg} at 18px). - Light-Weight Display: La...

Color tokens:
- canvas-dark: #1d1610
- canvas-light: #fff5f2
- surface-light: #ffffff
- ink: #282828
- ink-strong: #000000
- muted: #333333
- hairline: #282828
- on-dark: #fff5f2
- on-light: #282828

Typography tokens:
- hero-display: family 'wtqc', 'Inter Tight', 'Söhne Breit', -apple-system, sans-serif, size 197px, weight 300, line 1, tracking -6.5px
- display-lg: family 'wtqc', 'Inter Tight', 'Söhne Breit', -apple-system, sans-serif, size 72px, weight 300, line 1.04, tracking -1.51px
- title-md: family 'wtqc', 'Inter', 'Söhne', -apple-system, sans-serif, size 28px, weight 300, line 1.29, tracking -0.39px
- body-lg: family 'Inter', 'Söhne', -apple-system, sans-serif, size 18px, weight 400, line 1.78, tracking 0
- body-md: family 'Inter', 'Söhne', -apple-system, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- caption: family 'wtqc', 'Roboto', 'Inter', -apple-system, sans-serif, size 12px, weight 400, line 1.33, tracking -0.04px

Spacing tokens:
- xs: 8px
- sm: 16px
- md: 24px
- lg: 32px
- xl: 64px
- xxl: 80px
- section: 120px

Radius and shape tokens:
- xs: 0px
- xl: 20px

Component tokens:
- hero-display-block: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.hero-display}
- section-mega-header: backgroundColor: {colors.surface-light}, textColor: {colors.ink-strong}, typography: {typography.display-lg}
- media-card: backgroundColor: transparent, rounded: {rounded.xl}
- info-grid-row: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md}, padding: 24px 0
- prose-block: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-lg}
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md}
- icon-button-utility: backgroundColor: transparent, textColor: {colors.on-dark}, rounded: {rounded.xs}

Color rationale: The palette is strictly achromatic, relying on warm-tinted neutrals to create an architectural, gallery-like feel. Surface - Canvas Dark ({colors.canvas-dark} — 1d1610): The warm, near-black background for heroes and dark sections. It reads as architectural espresso, not pure black. - Canvas Light ({colors.canvas-light} — fff5f2): The primary page canvas. A subtle pink-ivory off-white that keeps the entire palette on the warm side of neutral. - Surface Light ({colors.surface-light} — ffffff): A pure white surface used for contained content sections that need to lift off the main {colors.canvas-light} floor. Text - On Dark ({colors.on-dark} — fff5f2): Text on dark backgrounds. It re-uses the warm off-white canvas color for consistency. - On Light ({colors.on-light} — 282828): Default text color on light backgrounds. - Ink ({colors.ink} — 282828): The workhorse neutral for primary body text. - Ink Strong ({colors.ink-strong} — 000000): Pure black, reserved for maximum-impact display headings on light surfaces. - Muted ({colors.muted} — 333333): Secondary body text, sub-labels, and column headers in info grids. Hairlines & Borders - Hairline ({colors.hairline} — 282828): The color fo...

Typography rationale: Font Family The system operates on a two-font model: a distinct, sharp display face (wtqc) for poster-scale headlines and a highly readable sans-serif (Inter) for body copy and UI text. - Display: wtqc (or substitutes Inter Tight / Söhne Breit) - Body: Inter (or substitute Söhne) Hierarchy The system uses a brutalist size ratio, creating two distinct typographic registers: "poster" and "fine print." There is no middle ground. Display sizes are paired with extremely light weights and tight tracking, while body sizes use regular weights and generous line heights for readability. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 197px | 300 | 1 | -6.5px | The main hero-block headline | | {typography.display-lg} | 72px | 300 | 1.04 | -1.51px | Section mega-headers | | {typography.title-md} | 28px | 300 | 1.29 | -0.39px | Subheadings within content sections | | {typography.body-lg} | 18px | 400 | 1.78 | 0 | Primary long-form body text | | {typography.body-md} | 16px | 400 | 1.5 | 0 | Secondary body copy, info grid content | | {typography.caption} | 12px | 400 | 1.33 | -0.04px | Metadata, small labels, grid column head...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 64px · {spacing.xxl} 80px · {spacing.section} 120px. - Section padding (vertical): Ranges from {spacing.xxl} (80px) to {spacing.section} (120px) between major content blocks. - Card/Grid internal padding: {spacing.md} (24px) to {spacing.lg} (32px). - Gutters: {spacing.lg} (32px) to {spacing.xl} (64px) between grid columns. - Element gap: {spacing.xs} (8px) to {spacing.sm} (16px) for tight stacks, like in an experience timeline. Grid & Container - Max content width: ~1200px for centered light-theme content sections. Dark sections are always full-bleed. - Grid: A 4-column grid is the standard for all structured information (footers, contact details, metadata). This collapses to a 2-column grid on smaller viewports. - Prose: Long-form text is set in a single column with a max-width of ~800-900px for optimal line length. Whitespace Philosophy The system uses hard cuts and generous negative space, not gradients or fades. The feeling is architectural and deliberate. The large vertical gap ({spacing.section}) between alternating dark and light sections cr...

Depth and hierarchy: The elevation model is entirely flat. Depth is an illusion created by surface color contrast and typography scale, not through shadows or layers. | Level | Treatment | Use | |---|---|---| | Flat | No shadow, 1px {colors.hairline} border | The default for all elements. Body sections, text blocks, info grids. | | Surface Contrast | {colors.surface-light} on {colors.canvas-light} | Contained white sections are placed on the off-white canvas to create a subtle lift without a shadow. | | Dark Section | {colors.canvas-dark} full-bleed | Full-bleed dark sections create dramatic depth through sheer contrast with adjacent light sections. | There are no drop shadows, glows, or blur effects in the system. The aesthetic is purely two-dimensional, relying on composition and contrast to guide the eye.

Shape language: Border Radius Scale The system uses sharp, 0px corners for all UI and structural elements to maintain a crisp, architectural feel. The only exception is for embedded media. | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | Default for all UI elements: cards, buttons, tags, dividers. | | {rounded.xl} | 20px | Reserved exclusively for media containers (images, videos). | Iconography Iconography is almost entirely absent. The system relies on pure typography for structure and navigation. Where an icon must be used (e.g., a utility function), it is a minimal, monochrome, 1px hairline glyph.

Component language: Hero & Headers hero-display-block — A full-bleed, full-viewport dark section. Background is {colors.canvas-dark}. It contains a single, massive typographic element styled with {typography.hero-display} in {colors.on-dark}. There are no CTAs or navigation; the type is the entire content. section-mega-header — A section opener that repeats the poster-scale type on a light surface. Background {colors.surface-light}, with left-aligned text using {typography.display-lg} in {colors.ink-strong}. It acts as a visual reset between dark and light sections. Content & Data media-card — A container for showcasing images or videos. It has no background or border, but applies a {rounded.xl} (20px) corner radius to the media it contains. info-grid-row — A row within a multi-column structured data grid. It has a transparent background, with content using {typography.body-md}. Columns are separated by generous gutters or 1px {colors.hairline} dividers. prose-block — A container for long-form text. It's a single, left-aligned column with a comfortable max-width, using {typography.body-lg} for a generous, readable feel. UI & Interaction text-link — An inline link styled as plain text. It uses {typogr...

Guardrails: Do - Use weight 300 at all display sizes (72px+). The light weight on massive type is the core identity. - Set letter-spacing at -0.03em or tighter for any text above 48px to create a cohesive, block-like feel. - Alternate between full-bleed {colors.canvas-dark} sections and contained {colors.canvas-light} sections. Use hard cuts only. - Use 1px {colors.hairline} rules as the primary structural element for grids and dividers. - Keep the palette strictly achromatic. Color should only come from content (e.g., images), not UI chrome. - Set body copy at 18px with a 1.78 line-height ({typography.body-lg}) to balance the compressed display type. - Maintain a 4-column grid for all structured information. Don't - Don't add a brand accent color. The system is monochrome by design. - Don't use border-radius on UI elements. Sharp {rounded.xs} corners are the rule; {rounded.xl} is for media only. - Don't set display type above weight 400. Bolding the headlines undermines the restrained, "whispering" tone. - Don't use drop shadows, glows, or blur effects. Elevation is communicated through contrast, not skeuomorphism. - Don't add decorative gradients. The palette is flat and a...
```
