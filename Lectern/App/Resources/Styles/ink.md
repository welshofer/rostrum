# Ink

**ID:** `ink`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#000000`
- `#ffffff`
- `#00174f`
- `#c2c1bf`

## Typography

Families: "'Suisse Intl', Inter, 'Neue Haas Grotesk', 'NB International', sans-serif". Weights: 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Studio HEED

Design token description: An almost entirely monochrome system that operates as a midnight editorial gallery on a near-black canvas (000000) where content tiles hang like curated exhibition pieces. A single deep navy (00174f) and a warm cement gray (c2c1bf) provide sparing tonal interruptions. Typography is the system's signature: a single grotesque font at a uniform weight (600) and a deliberately microscopic size (12–14px) for everything from navigation to labels. All shapes are locked to a precise 5px radius, creating an architectural, unfussy aesthetic. The layout is defined by a consistent 14px gap between elements, reinforcing the sense of a meticulously curated grid.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This system operates as a midnight editorial gallery: an almost entirely monochrome canvas where the page itself is the dark room, white hairline borders become picture frames, and the work hangs like a curated exhibition. Every surface decision—the pure black canvas ({colors.canvas-dark}), a single deep navy panel ({colors.surface-accent}), and a warm cement gray alternate ({colors.surface-alternate})—reduces visual noise to let project tiles breathe. The system's most defining characteristic is its typography. It deploys a single grotesque font at a uniform weight (600) and a deliberately microscopic size range (12–14px) for everything, from navigation to project labels to body copy. This rejects conventional typographic hierarchy, treating all text as a single, authoritative visual register. Radii are locked to {rounded.md} (5px) everywhere, which keeps the aesthetic architectural and unfussy. There are no soft pillowy cards, decorative gradients, or shadows. The {spacing.sm} (14px) grid gap is the heartbeat of the layout, giving every element the same precise breathing room. Key Characteristics: - Monochrome Foundation: The dominant color is pure black ({colors.canvas-dark}),...

Color tokens:
- ink: #000000
- body: #ffffff
- hairline: #ffffff
- on-dark: #ffffff
- canvas-dark: #000000
- surface-accent: #00174f
- surface-alternate: #c2c1bf
- surface-inverted: #ffffff

Typography tokens:
- body: family 'Suisse Intl', Inter, 'Neue Haas Grotesk', 'NB International', sans-serif, size 14px, weight 600, line 1.4, tracking 0
- caption: family 'Suisse Intl', Inter, 'Neue Haas Grotesk', 'NB International', sans-serif, size 12px, weight 600, line 1.4, tracking 0
- nav-link: family 'Suisse Intl', Inter, 'Neue Haas Grotesk', 'NB International', sans-serif, size 14px, weight 600, line 1.4, tracking 0

Spacing tokens:
- xs: 10px
- sm: 14px
- md: 20px
- section: 80px

Radius and shape tokens:
- md: 5px

Component tokens:
- header-block: textColor: {colors.on-dark}, typography: {typography.body}
- nav-link: typography: {typography.nav-link}, textColor: {colors.on-dark}
- contact-line: typography: {typography.caption}, textColor: {colors.on-dark}
- language-toggle: typography: {typography.caption}, textColor: {colors.on-dark}
- description-paragraph: typography: {typography.body}, textColor: {colors.on-dark}
- project-tile: rounded: {rounded.md}, padding: 0
- project-tile-navy: backgroundColor: {colors.surface-accent}, rounded: {rounded.md}
- project-tile-cement: backgroundColor: {colors.surface-alternate}, rounded: {rounded.md}

Color rationale: The palette is built on extreme contrast and restraint, using only four tones to create its "dark gallery" atmosphere. Core Palette - Canvas Dark / Ink ({colors.canvas-dark} — 000000): The page canvas and dominant card surface. A pure, deep black that absorbs the eye and allows imagery to carry all visual weight. - Body / On Dark / Hairline ({colors.body} — ffffff): Pure white, used for all running text, labels, and the 1px hairline borders that frame tiles and sections. Accent Surfaces - Surface Accent ({colors.surface-accent} — 00174f): Midnight navy. The only chromatic hue in the system, used sparingly as a solid background for content tiles to create a deep tonal interruption against the black canvas. - Surface Alternate ({colors.surface-alternate} — c2c1bf): A warm, desaturated cement gray. Used as an alternate background for content tiles that need to feel more physical or grounded. - Surface Inverted ({colors.surface-inverted} — ffffff): A pure white surface used for inverted tiles, often to showcase imagery with a light background.

Typography rationale: Font Family The system uses a single grotesque font family, Suisse Intl, for all typographic roles. The fallback stack includes Inter, Neue Haas Grotesk, and NB International. The defining characteristic is not the font itself, but its disciplined application. Hierarchy The system's hierarchy is deliberately collapsed into a "micro-type register." It uses a single font weight (600) and a very narrow size range (12-14px) for every element. This is unconventional; most systems use a dramatic scale. This system treats all text as a single visual voice, relying on size difference and placement, not weight or style, to create structure. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.body} | 14px | 600 | 1.4 | 0 | Primary body copy, navigation links, project titles | | {typography.nav-link} | 14px | 600 | 1.4 | 0 | Identical to body, used for header navigation | | {typography.caption} | 12px | 600 | 1.4 | 0 | Secondary labels, category tags, contact info | Principles - No Large Type: The system explicitly avoids display-sized text. 14px is the largest font size used. - Uniform Weight: All text is rendered at weight 600. There are n...

Layout system: Spacing System The spacing is tight and consistent, reinforcing the architectural, grid-like feel. - Base unit: The system uses a few explicit values rather than a strict scale. - Tokens: {spacing.xs} 10px · {spacing.sm} 14px · {spacing.md} 20px · {spacing.section} 80px. - Element Gaps: {spacing.sm} (14px) is the primary gap used between tiles in a gallery and between stacked metadata lines. - Card Padding: {spacing.md} (20px) is used for the internal padding of content blocks, such as the space below a tile and above its caption. - Section Spacing: {spacing.section} (80px) is used for major vertical separation between distinct page sections. Grid & Container - Full-Bleed Canvas: The {colors.canvas-dark} background extends to all viewport edges. There is no maximum content width container. - Editorial Composition: The layout is highly compositional. A common pattern is a top-of-page block occupying the upper viewport with a narrow, left-aligned text column and a right-aligned contact stack. - Horizontal Gallery: The primary content structure is often a single, horizontal row of equal-height rectangular tiles, separated by {spacing.sm} (14px) gaps. This row fills the viewport width...

Depth and hierarchy: Elevation is deliberately absent. The design language treats the {colors.canvas-dark} canvas as a flat gallery wall. Tiles are distinguished by their fill color, not by shadow or depth. This creates a print-editorial feel rather than a software UI feel. | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, header block, text elements | | Surface Fill | Solid background color ({colors.surface-accent}, etc.) | All project tiles and content cards | | Hairline Frame | 1px {colors.hairline} border | Can be used to frame tiles, though often the edge is defined by the fill alone | There are no drop shadows, no glow effects, and no modal overlays with backdrop blur. All elements exist on a single plane.

Shape language: Border Radius Scale The system employs a single, universal border radius, creating a powerful and consistent architectural signature. | Token | Value | Use | |---|---|---| | {rounded.md} | 5px | Applied to every card, image, and interactive surface. This is the only radius used. | This strict adherence to a single radius ensures that all components feel like they belong to the same meticulously crafted system. No pill shapes or soft, high-radius corners are permitted. Imagery - Images within tiles are always full-bleed, filling the container edge-to-edge. - The {rounded.md} (5px) radius of the parent tile masks the image, giving it soft corners. - There is no decorative iconography in the interface.

Component language: Header header-block — The top-of-page block containing identity, navigation, and contact info. It sits on the transparent canvas. The left side contains identity text and {component.nav-link} items. The right side contains a stack of {component.contact-line} elements. nav-link — A pure text link using {typography.nav-link} in {colors.on-dark}. Used for primary navigation. There are no underlines or background fills. contact-line — A single line of contact information using {typography.caption} in {colors.on-dark}. language-toggle — A text-based language switcher using {typography.caption}. Content description-paragraph — A narrow, left-aligned column of body copy set in {typography.body}. project-tile — The primary content unit. A rectangular card with a {rounded.md} radius and no shadow. It has no background itself; its surface is defined by its content (an image) or one of the colored tile variants. - project-tile-navy: A tile with a {colors.surface-accent} background. - project-tile-cement: A tile with a {colors.surface-alternate} background. - project-tile-white: A tile with a {colors.surface-inverted} background. project-caption — The two-line label that sits below a project...

Guardrails: Do - Use {colors.canvas-dark} as the default page canvas for every section. - Apply {rounded.md} (5px) to every card, image, and interactive surface—never deviate. - Keep all type at 12px or 14px, weight 600. The micro-type register is the signature. - Maintain {spacing.sm} (14px) gaps between gallery tiles and between stacked metadata lines. - Use {colors.body} (white) for all text and hairline borders; the white wireframe is the UI structure. - Let the four surface colors (black, white, navy, cement) carry all visual variety. Don't - Never add drop shadows, elevation, or glow effects to any surface. - Never use a type size larger than 14px. - Never introduce additional colors beyond the four defined surface tones. - Never use soft radii (8px+) or pill shapes; 5px is the only radius in the system. - Never use font weights other than 600. - Never add underlines, backgrounds, or color differentiation to active navigation states.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- restrained compositions with generous negative space and high typographic confidence
- editorial pacing with strong headline moments, image fields, and magazine-like hierarchy

Chart and infographic grammar:
- Charts must inherit the DESIGN.md palette, typography scale, stroke weight, corner radius, spacing, and grid density.
- Use branded annotations, legends, callout panels, and dividers instead of default spreadsheet styling.
- On dark palettes, render charts...
```
