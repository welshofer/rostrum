# Rosewood

**ID:** `rosewood`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#ff7777`
- `#cacaca`
- `#727272`
- `#0a0a0a`

## Typography

Families: "Inter, ui-sans-serif, system-ui, -apple-system, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Channel Studio

Design token description: A starkly minimalist, editorial interface set in a monochrome studio darkroom. The design operates on a near-black (0a0a0a) canvas with desaturated bone-white (cacaca) type and hairlines. There are no shadows, gradients, or rounded corners. A single, warm coral-red (ff7777) accent is used with extreme scarcity for signature headings and decorative strokes, acting like a signal flare in the grayscale environment. The entire identity is typographic, driven by a single neo-grotesque sans-serif at a single weight (400). Hierarchy is built exclusively through scale and aggressive negative letter-spacing, with display headlines stacking at a compressed, sub-1.0 line-height.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a stark, editorial system that lives in a monochrome studio darkroom. The entire design is built on a near-black canvas ({colors.canvas-dark} — 0a0a0a) with flat surfaces, no shadows, and no gradients. A single warm coral-red accent ({colors.accent} — ff7777) fires like a signal flare against the grayscale, reserved exclusively for key titles and signature borders. The identity is entirely typographic. It uses a single neo-grotesque sans-serif at a single weight (400) for all roles. Visual hierarchy is built through size and aggressive negative letter-spacing, not weight changes. The most defining characteristic is the compressed display type ({typography.display-lg}), which stacks at a sub-1.0 line-height (0.9), creating a dense, concrete-poetry effect. Layout is full-bleed and editorial, treating the viewport as a gallery wall. Sections alternate between type-only black panels and oversized media that fills the screen edge-to-edge. There are no traditional buttons; interactions are handled by simple text links with arrow indicators. The aesthetic is severe, minimalist, and prioritizes typographic form over conventional UI patterns. Key Characteristics: - Monochrome + one...

Color tokens:
- accent: #ff7777
- body: #cacaca
- muted: #727272
- canvas-dark: #0a0a0a
- hairline: #cacaca
- on-dark: #cacaca

Typography tokens:
- display-lg: family Inter, ui-sans-serif, system-ui, -apple-system, sans-serif, size 75px, weight 400, line 0.9, tracking -2.25px
- display-md: family Inter, ui-sans-serif, system-ui, -apple-system, sans-serif, size 45px, weight 400, line 1.19, tracking -1.35px
- title-md: family Inter, ui-sans-serif, system-ui, -apple-system, sans-serif, size 18px, weight 400, line 1.2, tracking -0.36px
- body-md: family Inter, ui-sans-serif, system-ui, -apple-system, sans-serif, size 15px, weight 400, line 1.2, tracking -0.3px
- caption: family Inter, ui-sans-serif, system-ui, -apple-system, sans-serif, size 13px, weight 400, line 1.2, tracking -0.26px
- nav-link: family Inter, ui-sans-serif, system-ui, -apple-system, sans-serif, size 13px, weight 400, line 1.2, tracking -0.26px

Spacing tokens:
- xxs: 4px
- xs: 9px
- sm: 13px
- md: 16px
- lg: 20px
- xl: 40px
- section: 40px
- footer-gap: 192px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- top-nav: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.nav-link}
- hero-display: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.display-lg}
- section-display: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.display-md}
- accent-title: backgroundColor: transparent, textColor: {colors.accent}, typography: {typography.display-md}
- text-link-arrow: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}
- accent-divider: backgroundColor: {colors.accent}, height: 1px
- media-card: backgroundColor: transparent, rounded: {rounded.xs}
- footer: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.caption}, paddingTop: {spacing.footer-gap}

Color rationale: Brand & Accent - Accent Red ({colors.accent} — ff7777): The only chromatic element. Used with extreme scarcity for project titles ({component.accent-title}) and signature horizontal dividers ({component.accent-divider}). Its power comes from its rarity. Surface - Canvas Dark ({colors.canvas-dark} — 0a0a0a): The page background and base surface for all components. The entire design lives on this near-black floor. - Media Surface: There is no distinct color for media cards. Instead, full-bleed imagery, typically desaturated or grayscale, acts as a secondary surface texture. Text - Body ({colors.body} — cacaca): The primary text color on dark surfaces. A desaturated bone-white that reads softer than pure fff against the black canvas. - Muted ({colors.muted} — 727272): Secondary text for captions and low-emphasis metadata. Hairlines & Borders - Hairline ({colors.hairline} — cacaca): The 1px stroke color for dividers and decorative borders, reusing the body text color.

Typography rationale: Font Family The system uses a single neo-grotesque sans-serif (substitute: Inter) for every typographic role, from display headlines to captions. All type is rendered at a single weight: 400 (Regular). This constraint forces hierarchy to be established through scale, letter-spacing, and line-height alone. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 75px | 400 | 0.9 | -2.25px | Hero headlines; the system's signature compressed type style | | {typography.display-md} | 45px | 400 | 1.19 | -1.35px | Section headlines, accent-colored titles | | {typography.title-md} | 18px | 400 | 1.2 | -0.36px | Subheadings, navigation logomark text | | {typography.body-md} | 15px | 400 | 1.2 | -0.3px | Default body text, primary text links | | {typography.caption} | 13px | 400 | 1.2 | -0.26px | Small meta labels, navigation links, footer text | | {typography.nav-link} | 13px | 400 | 1.2 | -0.26px | Top navigation menu items | Principles The most important typographic principle is the compressed line-height on display sizes. {typography.display-lg} uses lineHeight: 0.9, causing descenders and ascenders of stacked lines...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 9px · {spacing.sm} 13px · {spacing.md} 16px · {spacing.lg} 20px · {spacing.xl} 40px · {spacing.section} 40px · {spacing.footer-gap} 192px. - Section padding (vertical): {spacing.section} (40px) between major content blocks. - Element gap: {spacing.xs} (9-10px) for small gaps between navigation links or inline elements. - Footer separation: A signature {spacing.footer-gap} (192px) of empty space is used above the footer, creating a dramatic pause before the page concludes. Grid & Container - Full-bleed: The system does not use a max-width content container. All sections, text blocks, and images extend to the full width of the viewport. - Left-alignment: Content is consistently left-aligned, creating a strong vertical axis along the left edge of the screen. - Structure: The layout is a simple vertical stack of full-width sections, alternating between type-only panels and media-centric panels. Whitespace Philosophy Whitespace is structural and dramatic. The system uses generous vertical spacing ({spacing.section}, {spacing.footer-gap}) to separate content blocks, creating a rhythmic, editorial flow. Because t...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border, no fill | All components, text, and surfaces | The elevation philosophy is absolute flatness. There are no shadows, gradients, glows, or any effects that imply a z-axis. Visual separation is achieved through color contrast ({colors.body} on {colors.canvas-dark}), typographic scale, and whitespace. This two-dimensional approach reinforces the system's connection to print design and minimalist graphic arts.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | Universal radius for all elements | | {rounded.sm} | 0px | (not used) | | {rounded.md} | 0px | (not used) | | {rounded.lg} | 0px | (not used) | | {rounded.xl} | 0px | (not used) | | {rounded.pill} | 0px | (not used) | | {rounded.full} | 0px | (not used) | All elements in the system have a border radius of 0px. Corners are always sharp and rectangular. This is a strict rule that defines the system's severe, architectural aesthetic. There are no circles, pills, or soft shapes. Photography & Media Media elements, such as photography or 3D renders, are always displayed full-bleed, filling the container or viewport edge-to-edge. They are cropped as sharp rectangles with {rounded.xs} (0px) corners. Imagery is often desaturated to harmonize with the monochrome palette.

Component language: Top Navigation top-nav — A simple typographic block in the top-left corner of the page. It is not a persistent bar. It consists of a small text-based mark and a vertical list of navigation links set in {typography.nav-link}. It has no background or border, sitting directly on the {colors.canvas-dark} canvas. Headlines hero-display — The primary hero headline, set in {typography.display-lg}. Its defining feature is the compressed lineHeight: 0.9 that creates a dense, stacked text block. section-display — A smaller display headline for section titles, using {typography.display-md}. accent-title — The only component that applies color to text. Used for featured titles (e.g., project names), it shares the same {typography.display-md} style as a section headline but uses {colors.accent} for its text color. Media & Cards media-card — Represents a full-bleed image area. It has no intrinsic chrome (padding, background, border). The media itself is the component. It is often accompanied by overlaid text components like {component.accent-title}. Links & Actions text-link-arrow — The system's replacement for a button. It's a simple text label set in {typography.body-md} followed by a thin →...

Guardrails: Do - Use {colors.body} (cacaca) for all primary text. Never use pure fff, as the slight desaturation is a key part of the aesthetic. - Set display headlines using {typography.display-lg} with its lineHeight: 0.9 for the signature compressed effect. - Reserve {colors.accent} (ff7777) exclusively for featured titles and signature divider lines. Its impact depends on its scarcity. - Keep all border radii at 0px ({rounded.xs}). Sharp edges are fundamental to the design. - Use full-bleed, edge-to-edge imagery for all media sections. - Build hierarchy exclusively through typographic size and negative tracking. Do not introduce bold weights. Don't - Never use shadows, gradients, or any elevation effects. The design must remain absolutely flat. - Never add border-radius to any element. - Never use a color other than {colors.accent} for emphasis. The system is intentionally monochrome-plus-one. - Never use centered text alignment. All text should be left-aligned to maintain a strong vertical axis. - Never contain content within a max-width container. Embrace the full-bleed layout. - Never create traditional "buttons" with backgrounds or borders. Use {component.text-link-arrow} instead.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible fram...
```
