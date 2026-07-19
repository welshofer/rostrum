# Fresco

**ID:** `fresco`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#fafafa`
- `#000000`
- `#1c1c1c`
- `#141109`
- `#dcdcdc`
- `#c2b5ae`

## Typography

Families: "'FAVORIT', Söhne, Inter, Neue Haas Grotesk, sans-serif". Weights: 300, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Freytag Anderson

Design token description: A cinematic, achromatic dynamic transaction/data-flow pattern interface where full-bleed atmospheric imagery carries the entire visual weight. The system operates on an off-white canvas (fafafa) with pure black ink (000000) and a single warm-charcoal (1c1c1c) section for text-only interludes. A single grotesque sans-serif is the only voice, used for all type roles from headlines to body copy, with hierarchy established by subtle shifts in size and weight. Text is consistently anchored to the top-left corner over media, and components are reduced to their absolute minimum — pill-shaped ghost controls with hairline borders and no surfaces, shadows, or gradients.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: This is a cinematic and restrained design system where full-bleed atmospheric imagery serves as the primary content surface. The interface is almost entirely achromatic, built on an off-white canvas ({colors.canvas-light} — fafafa) and pure black ink ({colors.ink} — 000000). A single grotesque sans-serif typeface carries the entire hierarchy, with subtle shifts in size (41px, 17px, 15px) and weight (300, 400) doing the work typically assigned to different font families. The system's defining gesture is its layout: text is consistently anchored to the top-left of the viewport, sitting directly over media like a film title layered rectangular token motif. Components are radically minimal — there are no layered rectangular token motif surfaces, no shadows, and no gradients. Interactive elements are reduced to pill-shaped ghost buttons with a simple hairline border. The overall impression is of a quiet, spacious, and editorially-focused experience that prioritizes mood and image over UI density. Whitespace is dramatic, with major sections separated by a vast {spacing.section} (288px) gap, creating a slow, deliberate rhythm. Key Characteristics: - Achromatic Palette: The system is buil...

Color tokens:
- canvas-light: #fafafa
- ink: #000000
- canvas-dark: #1c1c1c
- canvas-darker: #141109
- hairline: #dcdcdc
- surface-accent-warm: #c2b5ae
- on-dark: #fafafa

Typography tokens:
- display-lg: family 'FAVORIT', Söhne, Inter, Neue Haas Grotesk, sans-serif, size 41px, weight 400, line 1.18, tracking -0.9px
- body-md: family 'FAVORIT', Söhne, Inter, Neue Haas Grotesk, sans-serif, size 17px, weight 400, line 1.7, tracking -0.34px
- caption: family 'FAVORIT', Söhne, Inter, Neue Haas Grotesk, sans-serif, size 15px, weight 300, line 1.4, tracking -0.33px
- button: family 'FAVORIT', Söhne, Inter, Neue Haas Grotesk, sans-serif, size 15px, weight 400, line 1.2, tracking -0.3px

Spacing tokens:
- xxs: 6px
- xs: 12px
- sm: 16px
- md: 17px
- lg: 20px
- xl: 29px
- xxl: 43px
- section: 288px

Radius and shape tokens:
- none: 0px
- pill: 9999px

Component tokens:
- button-ghost-on-light: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 20px
- button-ghost-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 20px
- hero-band-over-media: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-lg}, padding: 29px
- content-section-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.display-lg}, padding: 43px 43px 288px 43px
- text-block-three-column: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.body-md}, columnGap: 17px
- image-grid-item: backgroundColor: transparent, rounded: {rounded.none}

Color rationale: Surface & Canvas - Canvas Light ({colors.canvas-light} — fafafa): The primary page floor. An off-white that softens the contrast with pure black text and photographic edges. - Canvas Dark ({colors.canvas-dark} — 1c1c1c): A warm charcoal used for text-only sections, creating a visual pause between full-bleed media sections. - Canvas Darker ({colors.canvas-darker} — 141109): The deepest dark surface, used for the most recessed bands to create subtle depth within dark themes. - Surface Accent Warm ({colors.surface-accent-warm} — c2b5ae): A warm taupe accent surface, used very sparingly as a tonal break in dark sections. It's the only non-achromatic hint in the palette. Text & Ink - Ink ({colors.ink} — 000000): Primary text color on light surfaces, and the default border color for ghost buttons. - On Dark ({colors.on-dark} — fafafa): Text color for use on {colors.canvas-dark} or over dark photographic media. Same value as {colors.canvas-light}. Hairlines & Borders - Hairline ({colors.hairline} — dcdcdc): A neutral gray used for subtle dividers or disabled borders, where {colors.ink} would be too strong.

Typography rationale: Font Family The system uses a single grotesque sans-serif typeface, FAVORIT, for every text role. This unification is a core principle; hierarchy is created by adjusting size and weight, not by switching fonts. The suggested open-source substitute is Inter or Söhne. The system avoids bold weights, speaking only in light (300) and regular (400) voices. All type roles use tight negative letter-spacing for a refined, compact feel. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 41px | 400 | 1.18 | -0.9px | Hero headlines, section statements over media or dark canvas | | {typography.body-md} | 17px | 400 | 1.7 | -0.34px | Main running-text in multi-column grids or paragraphs | | {typography.caption} | 15px | 300 | 1.4 | -0.33px | Button labels, secondary info, micro-copy | | {typography.button} | 15px | 400 | 1.2 | -0.3px | All interactive button labels | Principles - One Font, Two Weights: The entire system relies on one font family in weights 300 and 400. Introducing other fonts or heavier weights would break the minimalist, quiet character. - Generous Leading: Body copy uses a very generous line-height o...

Layout system: Spacing System - Base unit: 6px. - Tokens: {spacing.xxs} 6px · {spacing.xs} 12px · {spacing.sm} 16px · {spacing.md} 17px · {spacing.lg} 20px · {spacing.xl} 29px · {spacing.xxl} 43px. - Section padding (vertical): {spacing.section} (288px) — a massive gap used between major content blocks to create a cinematic, intermission-like pause. - layered rectangular token motif internal padding: {spacing.xxl} (43px) is the standard for dark content sections. - Gutters: {spacing.md} (17px) between columns in the three-column text grid. Grid & Container - Full-bleed: The primary layout principle. Sections fill the viewport edge-to-edge. There is no max-width container. - Top-Left Anchor: Text is always aligned to the top and left of its container, with a modest inset ({spacing.xl} or {spacing.xxl}). - Three-Column Grid: For dense body copy, a three-column grid with {spacing.md} gutters is used. The grid is implied by alignment, with no visible column rules. - Low Density: The layout is intentionally sparse. Most "screens" consist of a single image and a single line of text. Whitespace Philosophy Whitespace is a primary design element, used to create rhythm and focus. The system trusts empty s...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border, just a background color | All surfaces: {colors.canvas-light}, {colors.canvas-dark}, and media planes | | Ghost Border | 1px solid border ({colors.ink} or {colors.on-dark}) | The only interactive elements, {component.button-ghost-on-light} and {component.button-ghost-on-dark} | The system is deliberately and completely flat. There are no shadows, glows, or any other effects used to simulate depth. Layers are distinguished solely by their color ({colors.canvas-light} vs. {colors.canvas-dark}) or by being placed over a photographic background. This is a foundational principle of the design's minimalist and print-like aesthetic.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Default for all elements: images, content sections, text blocks. | | {rounded.pill} | 9999px | Used exclusively for buttons. | The shape language is binary: sharp, 90-degree angles for all containers and media, and fully-rounded pills for all interactive controls. There are no intermediate radii. This stark contrast reinforces the separation between static content and interactive elements. Images are always presented as raw, un-rounded rectangles.

Component language: Buttons button-ghost-on-light — The standard interactive control on light backgrounds. It has a transparent background, a 1px solid border in {colors.ink}, and text in {colors.ink}. It uses {typography.button} and is shaped as a {rounded.pill}. button-ghost-on-dark — The equivalent for dark or photographic backgrounds. The geometry is identical, but the border and text use {colors.on-dark} for contrast. Content Containers hero-band-over-media — Not a component with a surface, but a placement rule. A headline using {typography.display-lg} is set in {colors.on-dark} and anchored to the top-left of a full-bleed media element with {spacing.xl} padding. content-section-dark — A text-only interlude section. It has a solid {colors.canvas-dark} background and uses {colors.on-dark} for text. It typically contains a top-left-aligned headline in {typography.display-lg} followed by a body text block. A massive {spacing.section} padding is applied to its bottom edge. text-block-three-column — A grid for presenting detailed body copy within a {component.content-section-dark}. It arranges text using {typography.body-md} into three equal columns with an {spacing.md} gap. image-grid-item — A full-...

Guardrails: Do - Use full-bleed, high-quality imagery as the canvas for typography. - Anchor all headlines and major text blocks to the top-left of their container. - Rely on a single grotesque typeface for all text, using only size and weight (300/400) for hierarchy. - Use the {rounded.pill} shape for all buttons and the {rounded.none} shape for everything else. - Employ dramatic whitespace, especially the {spacing.section} gap, to create a cinematic rhythm. - Keep the palette strictly achromatic. The only "color" comes from the photographic content itself. Don't - Do not add a chromatic accent color. The system's power comes from its restraint. - Do not use shadows, gradients, or any other elevation effects. The design must remain flat. - Do not center-align text. The top-left anchor is a non-negotiable rule. - Do not use layered rectangular token motif components. Content lives on the page canvas or over media, not on elevated surfaces. - Do not frame or apply a border-radius to images. Media should always be presented raw and full-bleed. - Do not use bold (600+) font weights. The system's voice is quiet and should not be made to shout.

Reusable visual grammar extracted from DESIGN.md:
- sharp fintech clarity with layered glass-like surfaces and confident contrast
- dynamic value-flow lines, modular cards, and precision data visualization
- premium operational polish with energetic accent gradients used sparingly
- disciplined grid construction with deliber...
```
