# Persimmon

**ID:** `persimmon`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#ff5000`
- `#8800ff`
- `#2c0fb1`
- `#ffcc00`
- `#1551ff`
- `#000000`
- `#282828`
- `#0f0e0e`
- `#808080`
- `#e7e7e7`

## Typography

Families: "'Graphik', -apple-system, BlinkMacSystemFont, sans-serif", "'Readymag Display (custom)', 'Graphik', sans-serif". Weights: 400, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Readymag

Design token description: A designer's editorial playground—a restrained white canvas shell wrapped around a bold, magazine-grade visual identity. The interface stays minimal (pure white ffffff, near-black text 282828, hairline borders e7e7e7) so that feature blocks painted in saturated solid panels—electric violet 8800ff, cobalt blue 1551ff, ember orange ff5000, and pure black 000000—carry the visual weight. Typography has enormous personality; a custom geometric display face with aggressively tight negative tracking headlines everything, while a quieter workhorse sans handles body copy. Components feel hand-set rather than templated; pill-shaped CTAs and thick section margins reinforce an identity that reads less like a SaaS product and more like a creative agency's dynamic transaction/data-flow pattern.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: This is a designer's editorial playground: a restrained white-canvas ({colors.canvas} — ffffff) product shell wrapped around an unmistakably bold, magazine-grade visual identity. The interface itself stays quiet—pure white background, near-black text ({colors.body} — 282828), and hairline dividers ({colors.hairline} — e7e7e7)—to allow the brand's personality to emerge from feature blocks. These are painted in saturated solid panels of electric violet ({colors.accent-violet}), cobalt blue ({colors.accent-blue}), ember orange ({colors.primary}), and pure black ({colors.ink}). There is no shadow-based elevation; depth comes from the stark contrast of these color fields against the white canvas. Typography carries enormous weight. A custom geometric display face defines the brand's voice, used for all headlines with aggressively tight negative letter-spacing ({typography.hero-display} runs -5.36px) that makes letterforms feel hand-set and monumental. A quieter workhorse sans (Graphik) handles body copy and UI text, creating a clear functional split. Components feel bespoke rather than templated—pill-shaped CTAs ({rounded.pill} at 200px), thick section margins ({spacing.section} at 86p...

Color tokens:
- primary: #ff5000
- accent-violet: #8800ff
- accent-violet-deep: #2c0fb1
- accent-yellow: #ffcc00
- accent-blue: #1551ff
- ink: #000000
- body: #282828
- heading: #0f0e0e
- muted: #808080
- hairline: #e7e7e7
- canvas: #ffffff
- surface-soft: #f4f4f4
- on-primary: #ffffff
- on-dark: #ffffff

Typography tokens:
- hero-display: family 'Readymag Display (custom)', 'Graphik', sans-serif, size 80px, weight 700, line 0.88, tracking -5.36px
- display-lg: family 'Readymag Display (custom)', 'Graphik', sans-serif, size 40px, weight 700, line 1.43, tracking -2.12px
- display-md: family 'Readymag Display (custom)', 'Graphik', sans-serif, size 32px, weight 700, line 1.83, tracking -1.6px
- display-sm: family 'Readymag Display (custom)', 'Graphik', sans-serif, size 30px, weight 700, line 2.7, tracking -1.32px
- title-lg: family 'Readymag Display (custom)', 'Graphik', sans-serif, size 18px, weight 400, line 2.67, tracking -0.49px
- body-md: family 'Graphik', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking -0.05px
- body-sm: family 'Graphik', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.43, tracking -0.35px
- caption: family 'Readymag Display (custom)', 'Graphik', sans-serif, size 12px, weight 700, line 1, tracking -0.17px
- button: family 'Readymag Display (custom)', 'Graphik', sans-serif, size 14px, weight 700, line 1, tracking -0.35px
- nav-link: family 'Graphik', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.4, tracking 0

Spacing tokens:
- xxs: 6px
- xs: 14px
- sm: 16px
- md: 20px
- lg: 24px
- xl: 30px
- section: 86px

Radius and shape tokens:
- sm: 10px
- md: 16px
- lg: 20px
- pill: 200px
- full: 200px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- button-secondary-outlined: backgroundColor: {colors.canvas}, textColor: {colors.heading}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- nav-pill: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 8px 16px
- feature-card-dark: backgroundColor: {colors.ink}, textColor: {colors.on-dark}, typography: {typography.display-lg}, rounded: {rounded.lg}, padding: 48px
- feature-card-accent: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.display-lg}, rounded: {rounded.lg}, padding: 48px
- interactive-demo-panel: backgroundColor: {colors.accent-blue}, textColor: {colors.on-dark}, rounded: {rounded.md}, padding: 32px
- accent-band-yellow: backgroundColor: {colors.accent-yellow}, textColor: {colors.ink}, padding: 64px
- section-heading-block: backgroundColor: transparent, textColor: {colors.heading}, typography: {typography.display-lg}

Color rationale: Brand & Accent - Ember Orange ({colors.primary} — ff5000): The single primary action color. Reserved for the main filled CTA background ({component.button-primary}). Used sparingly to maintain its high-contrast signal. - Electric Violet ({colors.accent-violet} — 8800ff): The primary brand accent. Used for headline highlights, decorative strokes, and feature callouts. Its vibrancy against the white canvas gives typographic moments an electric, editorial feel. - Signal Yellow ({colors.accent-yellow} — ffcc00): A high-impact decorative color used for full-bleed accent bands and section dividers. Appears infrequently but dominates attention. - Cobalt Blue ({colors.accent-blue} — 1551ff): A supporting palette color used for interactive demo surfaces and other decorative accents. Text - Heading ({colors.heading} — 0f0e0e): The darkest near-black, used for display headlines for maximum contrast and hierarchy. - Body ({colors.body} — 282828): The primary text color for body copy, links, and most UI text. A workhorse near-black that is slightly softer than pure black for reading comfort. - Ink ({colors.ink} — 000000): Pure black, reserved for solid feature layered rectangular token motif b...

Typography rationale: Font Family The system operates on a strict dual-font model: - Readymag Display (custom): A geometric sans-serif used for all headlines, display copy, and large feature titles. Its signature is its extremely tight negative letter-spacing. (Substitute: Suisse Int'l) - Graphik: A neutral, workhorse sans-serif used for all body copy, UI text, and inline links. (Substitute: Inter) The display face should never be used for running body text, and the body face should never be used for headlines. This separation is fundamental to the system's voice. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 700 | 0.88 | -5.36px | The largest, tightest-set headline for hero moments. | | {typography.display-lg} | 40px | 700 | 1.43 | -2.12px | Primary section headlines. | | {typography.display-md} | 32px | 700 | 1.83 | -1.6px | Secondary section headlines. | | {typography.display-sm} | 30px | 700 | 2.7 | -1.32px | Headlines on solid color feature layered rectangular token motif. | | {typography.title-lg} | 18px | 400 | 2.67 | -0.49px | Subheadings and large labels. | | {typography.body-md} | 16px | 400 | 1.5 | -0.0...

Layout system: Spacing System - Base unit: An irregular but rhythmic scale. - Tokens: {spacing.xxs} 6px · {spacing.xs} 14px · {spacing.sm} 16px · {spacing.md} 20px · {spacing.lg} 24px · {spacing.xl} 30px · {spacing.section} 86px. - Section gap: {spacing.section} (86px) is the standard vertical margin between all major page sections, creating a distinct, magazine-like pacing. - layered rectangular token motif internal padding: {spacing.lg} (24px) is standard. Large feature layered rectangular token motif can expand this to {spacing.xl} or more. - Element gap: {spacing.xxs} (6px) for small, adjacent UI elements. Grid & Container - Max content width: ~1200px, centered. - Structure: The page often begins with a full-bleed masonry grid of tiles, then settles into a centered single-column or two-column layout for editorial content. - Full-bleed breaks: The system frequently breaks out of the 1200px container with full-width, solid-color bands ({component.feature-card-dark}, {component.accent-band-yellow}) that span the entire viewport. This alternation between contained and full-bleed sections is a core layout principle.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The default state for all canvas and content sections. | | Soft hairline | 1px {colors.hairline} | Separating UI elements on the same surface, like input fields or table rows. | | Color Block | Solid background ({colors.ink}, {colors.primary}, etc.) on {colors.canvas} | The primary method of separation and "elevation." Used for all feature layered rectangular token motif and content panels. | | Outlined | 1.5px {colors.heading} border | Secondary buttons, to de-emphasize them next to a solid primary button. | The elevation philosophy is flat surfaces with color-block separation. The system strictly avoids drop shadows. Depth is created by the contrast of saturated color panels against the white page canvas. This is a print-editorial approach: depth comes from ink coverage, not simulated light.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 10px | Small UI tiles, dynamic transaction/data-flow pattern grid items. | | {rounded.md} | 16px | Interactive demo panels. | | {rounded.lg} | 20px | Large feature layered rectangular token motif and panels. | | {rounded.pill} | 200px | Universal radius for all buttons: primary, secondary, and navigation. | The system's shape language is defined by two extremes: modestly rounded rectangles ({rounded.md}/{rounded.lg}) for content panels, and the exaggerated {rounded.pill} for all interactive controls. This binary choice—panel or pill—creates a clean, intentional feel. Iconography The system is largely non-iconographic. It prefers bold typography and color to communicate. Where icons appear, they are minimal and functional: a simple 'X' for close, circular bullet markers, or abstract glyphs for UI controls. There is no decorative icon set.

Component language: Buttons All buttons, regardless of role, share the {rounded.pill} (200px) shape. button-primary — The main call-to-action. A solid pill filled with {colors.primary} (Ember Orange), with {colors.on-primary} (white) text. Use sparingly, with a maximum of one visible per viewport to maintain its visual weight. button-secondary-outlined — The secondary action button. A pill with a transparent background, {colors.canvas}, and a 1.5px border in {colors.heading}. The text is also {colors.heading}. Designed to pair cleanly with the primary button without competing. nav-pill — The navigation menu item style. A text-only pill with no visible border or fill at rest. On hover, it reveals a subtle background fill. The shared pill shape unifies it with the other buttons. layered rectangular token m...
```
