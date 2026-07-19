# Ultramarine

**ID:** `ultramarine`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Bold

## Color palette

- `#381fd1`
- `#e5e0ff`
- `#fedb63`
- `#99d6cc`
- `#10284b`
- `#faf5ff`
- `#f6f6eb`
- `#ffffff`
- `#000000`
- `#e5e7eb`

## Typography

Families: "ArminGrotesk, ui-sans-serif, system-ui, sans-serif", "RobotoMono, ui-monospace, monospace". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Stark

Design token description: Stark operates as a confident accessibility-infrastructure brand sitting on a dual-surface canvas: a deep midnight-navy hero (10284b) that crashes into a warm cream secondary field (f6f6eb), linked by a vivid violet primary action (381fd1) and a mustard-yellow highlighter (fedb63) that reads like a teacher's marking pen. The type system is anchored by ArminGrotesk at its heaviest possible weight (900) for hero display — creating a wall-of-text effect — with tight negative tracking throughout. Yellow is used as a specific marker, while violet is the chromatic engine for all primary interactions.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: Stark reads as a confident, scholarly accessibility-infrastructure brand. Its layout is defined by a dramatic vertical split: a deep, authoritative midnight-navy hero ({colors.canvas-dark} — 10284b) gives way to a warmer, more relaxed cream section ({colors.surface-cream} — f6f6eb) below the fold. Linking these two worlds is a single, vivid Stark Violet ({colors.primary} — 381fd1) that drives every primary CTA, and a punctuating Highlighter Yellow ({colors.accent-yellow} — fedb63) used not for decoration, but to mark specific words within headlines, like a professor's pen. The brand's typographic signature is its hero headline: ArminGrotesk at a colossal 110px with weight 900 ({typography.display}), pulled into a tight, sculptural block with aggressive negative letter-spacing. This "wall of text" establishes immediate authority. The rest of the type scale steps down conventionally but maintains the tight-tracking feel of a geometric grotesque. A secondary monospace font, RobotoMono, is used for all-caps eyebrow labels ({typography.eyebrow-label}), adding a utilitarian, technical layer. The system is unapologetically flat, preferring stark {colors.hairline} borders over drop shadow...

Color tokens:
- primary: #381fd1
- primary-soft: #e5e0ff
- accent-yellow: #fedb63
- accent-mint: #99d6cc
- canvas-dark: #10284b
- canvas-light: #faf5ff
- surface-cream: #f6f6eb
- surface-card: #ffffff
- ink: #000000
- body: #000000
- body-on-dark: #f6f6eb
- on-dark: #ffffff
- on-primary: #ffffff
- hairline: #e5e7eb

Typography tokens:
- display: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 110px, weight 900, line 1.1, tracking -2.2px
- heading-lg: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 56px, weight 600, line 1.1, tracking -0.56px
- heading-md: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 48px, weight 600, line 1.1, tracking -0.48px
- heading-sm: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 28px, weight 600, line 1.5, tracking 0px
- title-md: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 24px, weight 600, line 1.5, tracking 0px
- body-lg: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 20px, weight 400, line 1.7, tracking 0.4px
- body-md: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 16px, weight 400, line 1.5, tracking -0.16px
- caption: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 14px, weight 400, line 1.43, tracking -0.28px
- button: family ArminGrotesk, ui-sans-serif, system-ui, sans-serif, size 16px, weight 500, line 1, tracking 0.32px
- eyebrow-label: family RobotoMono, ui-monospace, monospace, size 13px, weight 700, line 1.4, tracking 1.04px

Spacing tokens:
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 32px
- lg: 48px
- xl: 64px
- xxl: 80px
- section: 56px

Radius and shape tokens:
- sm: 6px
- md: 12px
- lg: 20px
- xl: 40px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.sm}, padding: 8px 24px
- button-secondary-yellow: backgroundColor: {colors.accent-yellow}, textColor: {colors.canvas-dark}, typography: {typography.button}, rounded: {rounded.sm}, padding: 8px 24px
- button-tertiary-outline-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.sm}, padding: 8px 24px
- feature-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.xl}, padding: {spacing.sm}
- product-frame: backgroundColor: {colors.surface-card}, rounded: {rounded.md}
- top-nav: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.caption}
- pill-label: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.eyebrow-label}, rounded: {rounded.lg}, padding: 4px 12px
- hero-band: backgroundColor: {colors.canvas-dark}, textColor: {colors.body-on-dark}, typography: {typography.display}, padding: {spacing.xxl}

Color rationale: Brand & Accent - Stark Violet ({colors.primary} — 381fd1): The single interactive brand color. Used for primary CTA backgrounds, card border accents, active nav states, and inline emphasis text. It's the electric, "switched-on" signal. - Highlighter Yellow ({colors.accent-yellow} — fedb63): The emphasis marker. Used for a diagonal text-highlight gradient and a single secondary CTA on the hero. It is never used for general decoration. - Lilac Tint ({colors.primary-soft} — e5e0ff): A soft, desaturated wash of the primary violet. Used for gentle tinted card backgrounds and soft button variants. - Mint Splash ({colors.accent-mint} — 99d6cc): A decorative accent used only within illustrations for feature cards. Not a core UI color. Surface - Canvas Dark ({colors.canvas-dark} — 10284b): The hero background. A deep midnight navy that anchors the page and serves as the dark-mode canvas. Also used for headings on light surfaces. - Page Canvas ({colors.canvas-light} — faf5ff): The primary light background. A very faint violet-tinted near-white that unifies all light surfaces. - Surface Cream ({colors.surface-cream} — f6f6eb): A secondary surface for body sections. The warm, greenish-cream p...

Typography rationale: Font Family The system relies almost exclusively on ArminGrotesk, a geometric grotesque that provides a contemporary, slightly technical authority. It is supplemented by RobotoMono for a specific utilitarian role. - ArminGrotesk → Display headlines, subheadings, body text, button labels. - RobotoMono → All-caps eyebrow labels and section markers. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display} | 110px | 900 | 1.1 | -2.2px | The hero H1 "wall-of-text" | | {typography.heading-lg} | 56px | 600 | 1.1 | -0.56px | Major section headlines | | {typography.heading-md} | 48px | 600 | 1.1 | -0.48px | Secondary section headlines | | {typography.heading-sm} | 28px | 600 | 1.5 | 0 | Card titles, sub-section heads | | {typography.title-md} | 24px | 600 | 1.5 | 0 | Feature card titles | | {typography.body-lg} | 20px | 400 | 1.7 | 0.4px | Hero body copy | | {typography.body-md} | 16px | 400 | 1.5 | -0.16px | Default running-text | | {typography.caption} | 14px | 400 | 1.43 | -0.28px | Small meta-text | | {typography.button} | 16px | 500 | 1 | 0.32px | All button labels | | {typography.eyebrow-label} | 13px | 700 | 1.4 | 1.04...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 32px · {spacing.lg} 48px · {spacing.xl} 64px · {spacing.xxl} 80px. - Section padding (vertical): {spacing.section} (56px) between major content bands. - Card internal padding: {spacing.sm} (24px) for most content cards. - Gutters: {spacing.xs} (16px) between elements in a dense list; {spacing.md} (32px) between grid items. Grid & Container - Max content width: 1200px, centered. - Editorial body: A centered container holds most content, with a 4-column grid used for feature sections. - Hero layout: Centered headline and body copy, flanked by asymmetrically placed floating stat cards. Whitespace Philosophy The design uses whitespace to amplify its bold typography. The hero is dense with text but floats in the vastness of the {colors.canvas-dark}. Below the fold, sections are separated by a consistent {spacing.section} gap, creating a comfortable rhythm that alternates between information-dense product screenshot sections and spacious 4-column feature grids.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top nav, footer, cream bands | | Hairline | 1px {colors.hairline} border | Cards, inputs, dividers, outline buttons | | Card surface | {colors.surface-card} background on {colors.surface-cream} or {colors.canvas-light} | Content cards that require a pure white background | | Soft shadow | 0 8px 32px rgba(0, 0, 0, 0.2) | Hero stat cards floating over the dark canvas | | Strong shadow | 0 20px 60px rgba(16, 40, 75, 0.15) | Product screenshot frames to create depth and overlap | The system primarily uses color and hairlines for separation. Shadows are reserved for two specific components—product screenshots and hero stat cards—where they are used to create a sense of layering and depth against a flat background.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 6px | Standard buttons, nav elements, inputs | | {rounded.md} | 12px | Product screenshot frames, standard cards | | {rounded.lg} | 20px | Pill-shaped labels and tags | | {rounded.xl} | 40px | Large feature cards | | {rounded.pill} | 9999px | Fully-rounded elements like avatars | The radius scale is one of contrasts: sharp, tight corners ({rounded.sm}) for interactive controls, and soft, exaggerated curves ({rounded.xl}) for large content containers, creating a distinct visual identity. Photography & Iconography - Imagery: The system avoids photography of people. The visual language is split between abstract data-visualization patterns on the hero (dots and bars) and functional product screenshots on light surfaces. - Illustrations: Feature cards use flat, isometric-style geometric illustrations with a controlled palette of {colors.accent-mint}, {colors.accent-yellow}, {colors.primary}, and {colors.canvas-dark}. - Iconography: Minimalist line icons are used in stat cards and feature illustrations.

Component language: Buttons - button-primary: The main CTA. A solid {colors.primary} fill with {colors.on-primary} text, using {typography.button} and a {rounded.sm} radius. It is the most vibrant, attention-grabbing element on any surface. - button-secondary-yellow: An alternate CTA used sparingly on the dark hero. It uses a {colors.accent-yellow} fill with {colors.canvas-dark} text, providing a secondary action path without competing with the primary violet button. - button-tertiary-outline-on-dark: A ghost button for tertiary actions like "Request Demo" in the nav. Transparent background with a 1px {colors.on-dark} border. Cards & Containers - hero-band: The full-bleed {colors.canvas-dark} section above the fold, featuring the {typography.display} headline. Abstract dot patterns provide a subtle background texture. - feature-card: Used in 4-column grids to explain product features. Has a large {rounded.xl} radius and contains a flat geometric illustration, a {typography.eyebrow-label}, a {typography.title-md} heading, and body t...
```
