# Prism

**ID:** `prism`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#ff5a46`
- `#00ffff`
- `#ffe100`
- `#000000`
- `#ffffff`
- `#ebebf5`

## Typography

Families: "TT Norms Pro, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 900.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: EVOKE

Design token description: A design system built on full-bleed saturated color panels—coral (ff5a46), cyan (00ffff), yellow (ffe100), and lavender (ebebf5)—that act as unmodulated, flat section anchors. Work is presented in a tight grid of oversized, sharp-cornered tiles where media fills each container edge-to-edge with no padding or frame. A single grotesk typeface creates a dramatic whisper/shout dynamic: a compressed normal weight for content headings, and a massive, architectural extra-black weight for major display text moments. The system completely rejects depth, using no shadows, gradients, or rounded corners, relying instead on scale, color contrast, and full-bleed composition for hierarchy.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a design system of confident, saturated declarations. The layout is built from full-bleed color panels — {colors.primary} (coral), {colors.accent-cyan}, {colors.accent-yellow}, and {colors.surface-soft} (lavender) — that serve as flat, unmodulated section backgrounds. Content, particularly portfolio work, is displayed in a tight 3-column grid of oversized {component.media-tile} containers. These tiles are chromeless, with images filling the space edge-to-edge, leaving no room for padding, borders, or captions. Typography is the system's other dominant feature, built on a single grotesk typeface ('TT Norms Pro') used in two distinct weights to create a "whisper/shout" dynamic. Content headings use a compressed normal weight ({typography.title-md}), while major display text moments employ a massive, architectural extra-black weight ({typography.display-lg}) that functions as a structural element. The system rejects depth entirely; there are no shadows, no gradients, and no rounded corners. Hierarchy is achieved exclusively through scale, vibrant color contrast, and full-bleed composition.

Color tokens:
- primary: #ff5a46
- accent-cyan: #00ffff
- accent-yellow: #ffe100
- ink: #000000
- canvas: #ffffff
- surface-soft: #ebebf5
- body: #000000
- on-primary: #ffffff

Typography tokens:
- display-lg: family TT Norms Pro, -apple-system, BlinkMacSystemFont, sans-serif, size 200px, weight 900, line 1, tracking -3px
- title-md: family TT Norms Pro, -apple-system, BlinkMacSystemFont, sans-serif, size 31px, weight 400, line 1.2, tracking -0.465px
- body-md: family TT Norms Pro, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0px

Spacing tokens:
- sm: 10px
- md: 20px
- lg: 40px
- xl: 60px
- section: 80px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- media-tile: backgroundColor: transparent, rounded: {rounded.xs}, padding: 0px
- color-block-section-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, padding: {spacing.section} 0
- color-block-section-cyan: backgroundColor: {colors.accent-cyan}, textColor: {colors.ink}, padding: {spacing.section} 0
- color-block-section-yellow: backgroundColor: {colors.accent-yellow}, textColor: {colors.ink}, padding: {spacing.section} 0
- color-block-section-soft: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, padding: {spacing.section} 0
- display-text-element: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.display-lg}
- content-heading: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.title-md}

Color rationale: Brand & Accent - Primary Coral ({colors.primary} — ff5a46): A warm, energetic coral used for full-bleed section panels. - Accent Cyan ({colors.accent-cyan} — 00ffff): A synthetic, screen-native cyan for high-energy color blocking. - Accent Yellow ({colors.accent-yellow} — ffe100): A saturated yellow used for high-attention section markers. Surface - Canvas ({colors.canvas} — ffffff): The base page floor, providing a neutral ground that separates the saturated color panels. - Surface Soft ({colors.surface-soft} — ebebf5): A cool lavender for quieter moments, used for full-bleed panels that offer a soft transition between louder colors. Text - Ink ({colors.ink} — 000000): Pure black for all text, including display-scale headings and content titles. It provides maximum contrast and grounds the vibrant color fields. - On Primary ({colors.on-primary} — ffffff): White text for use on the most saturated color backgrounds like {colors.primary} to ensure readability.

Typography rationale: Font Family The entire system is set in TT Norms Pro. The design relies on a strict two-weight split to create its characteristic "whisper/shout" hierarchy. The fallback stack is a standard system sans-serif. - Normal (400 weight): Used for all informational and content-level type, such as section headings ({typography.title-md}). Its tight default tracking gives it a dense, solid feel. - ExtraBlack (900 weight): Reserved exclusively for massive display-scale text elements ({typography.display-lg}). It is not used for standard headlines; its role is architectural. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 200px | 900 | 1 | -3px | Massive, page-spanning text elements that act as structural dividers. | | {typography.title-md} | 31px | 400 | 1.2 | -0.465px | Content headings for project names and section titles. | | {typography.body-md} | 16px | 400 | 1.5 | 0px | Assumed default body copy style. | Principles Tight letter-spacing is a key characteristic. The -0.465px tracking on {typography.title-md} makes headlines feel compressed and solid. The extremely tight tracking on {typography.display-lg} hel...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.md} 20px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) is used to create significant separation between the major color blocks and content grids. - Gutters: {spacing.md} (20px) provides the tight spacing between tiles in the work grid. Grid & Container - Max content width: The system is built on full-bleed principles, with color blocks spanning the entire viewport width. - Work Grid: A rigid 3-column grid is used to display portfolio tiles. Each tile fills the column width completely. Whitespace Philosophy The system uses whitespace dramatically. It is generous between major sections ({spacing.section}) but tight and compressed within content grids ({spacing.md}). This contrast reinforces the blocky, architectural feel of the layout. There is no internal padding within component tiles.

Depth and hierarchy: The system's elevation philosophy is one of absolute flatness. There are no z-axis effects. | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no gradient, no border | All elements. Page canvas, color blocks, media tiles, and text all exist on a single plane. | Depth and hierarchy are communicated through scale (e.g., the massive {typography.display-lg} text) and color-plane shifts (e.g., a white canvas transitioning to a {colors.primary} color block), never through shadows or simulated elevation.

Shape language: Border Radius Scale The system exclusively uses sharp, 90-degree angles. All border-radius values are 0px. | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | All elements, including media tiles and any potential future components like buttons or inputs. | This commitment to zero radius creates a crisp, geometric, and uncompromising aesthetic. There is no softness in the system's shape language.

Component language: Media Tile media-tile — A container for showcasing visual work within a 3-column grid. It has no chrome: {rounded.xs} (0px), padding: 0px, and no border. The contained image or media fills the tile completely, edge-to-edge. The only separation between tiles is the {spacing.md} page gutter. Color Block Sections color-block-section- — Full-width panels that act as section backgrounds and dividers. They are defined by their background color and have consistent vertical padding of {spacing.section}. - color-block-section-primary: Uses {colors.primary} with {colors.on-primary} text. - color-block-section-cyan: Uses {colors.accent-cyan} with {colors.ink} text. - color-block-section-yellow: Uses {colors.accent-yellow} with {colors.ink} text. - color-block-section-soft: Uses {colors.surface-soft} with {colors.ink} text. Typographic Elements display-text-element — A structural text block using {typography.display-lg}. This component spans a significant portion of the page width and uses {colors.ink} text, typically on the {colors.canvas} background. It functions as a powerful visual anchor or divider. content-heading — A standard heading for sections or content titles, set in {typography.t...

Guardrails: Do - Use full-bleed color panels to define and separate sections of content. - Adhere strictly to the two-weight typography system: {typography.title-md} for content, {typography.display-lg} for architectural impact. - Ensure all media within a {component.media-tile} is full-bleed, with no internal padding or framing. - Keep all corners perfectly sharp ({rounded.xs}: 0px). - Rely on scale and color contrast for all visual hierarchy. Don't - Don't introduce any drop shadows, gradients, or other z-axis depth effects. The system must remain flat. - Don't apply rounded corners to any element. - Don't use the ExtraBlack (900) font weight for anything other than the large-scale {component.display-text-element}. It is not for headings. - Don't place borders or frames around images or media tiles. - Don't introduce a secondary typeface. The entire identity is built on the single-family, two-weight concept.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy

Chart and infographic grammar:
- Charts must inherit the DESIGN.md palette, typography scale, stroke weight, corner radius, spacing, and grid density.
- Use branded annotations, legends, callout panels, and dividers instead of default spreadsheet styling.
- On dark palettes, render charts with luminous high-contrast lines, labels, and subtle gridlines.

Image and illustration grammar:
- Image-like areas must depict the slide topic from the slide JSON; DESIGN.md controls treatment, composition, material, color, and mood only.
- When the source design uses product or industry examples, translate them into abstract composition behaviors rather than literal objects.

Slide graphic system:
- Translate the design system into presentation imagery, not app chrome.
- Use the palette, type hierarchy, spacing, radii, depth model, and prose mood as the shared visual DNA.
- Create rich slide composition appropriate to the content: editorial title, diagrammatic explainer, data-forward layout, abstract illustration field, layered panel system, or image-like graphic scene.
- Graphics and images should feel native to the DESIGN.md system: matching geometry, material, stroke weight, texture, icon/diagram language, and visual density.
- For charts, infographics, and image-like...
```
