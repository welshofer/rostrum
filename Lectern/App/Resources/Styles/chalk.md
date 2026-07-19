# Chalk

**ID:** `chalk`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#ffffff`
- `#000000`
- `#e5e7eb`
- `#a9a9a9`
- `#fff5fa`

## Typography

Families: "'Hoefler Text', 'Cormorant Garamond', serif", "'Jost', 'Futura PT', sans-serif", "Anton, 'Bebas Neue', 'DIN', sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Exhibition Magazine

Design token description: A concrete editorial system that translates a printed artifact to the clean interface-like information plane, built on a pure white canvas (ffffff), pure black ink (000000), and organizing hairline rules (e5e7eb). The visual language is almost entirely achromatic, finding its voice in extreme typographic scale contrast. An oversized, tightly-tracked condensed sans-serif at 90-100px commands display moments, while a warm serif carries long-form editorial copy. UI chrome, navigation, and micro-labels use a tiny 13px all-caps sans-serif with generous letter-spacing, creating a deliberate tension between gargantuan display type and whisper-quiet functional text. All elements are sharp-cornered (0px radius), reinforcing a severe, monolithic grid.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This system operates as a printed editorial artifact translated to the clean interface-like information plane. The entire interface is built on a pure white canvas ({colors.canvas} — ffffff), organized by severe black text ({colors.ink} — 000000) and the occasional {colors.hairline} (e5e7eb) 1px rule. Color is virtually absent; the design language is an exercise in achromatic restraint and typographic brutalism. The visual hierarchy depends entirely on extreme scale contrast. An oversized, tightly-tracked condensed sans-serif (see {typography.hero-display-xl}) is used for display headlines, collapsing its line-height to form near-solid blocks of type. This is contrasted with a warm, classical serif ({typography.body-serif}) for all editorial body copy, signaling a shift from 'display' to 'content'. All UI chrome—navigation, labels, tags—uses a tiny, all-caps sans-serif ({typography.nav-link}) with signature wide letter-spacing. This creates a powerful tension between the monumental display type and the whisper-quiet functional elements. Components are stripped to their essentials. Image cards have no containers or rounded corners. Buttons do not exist; all actions are underlined t...

Color tokens:
- canvas: #ffffff
- ink: #000000
- hairline: #e5e7eb
- muted-surface: #a9a9a9
- surface-warm: #fff5fa
- on-dark: #ffffff
- on-light: #000000

Typography tokens:
- hero-display-xl: family Anton, 'Bebas Neue', 'DIN', sans-serif, size 100px, weight 400, line 0.8, tracking -0.008em
- hero-display-lg: family Anton, 'Bebas Neue', 'DIN', sans-serif, size 90px, weight 400, line 0.8, tracking -0.008em
- display-md: family Anton, 'Bebas Neue', 'DIN', sans-serif, size 52px, weight 400, line 1, tracking -0.006em
- display-sm: family Anton, 'Bebas Neue', 'DIN', sans-serif, size 50px, weight 400, line 1, tracking -0.006em
- title-serif: family 'Hoefler Text', 'Cormorant Garamond', serif, size 46px, weight 400, line 1.2, tracking 0
- title-lg: family Anton, 'Bebas Neue', 'DIN', sans-serif, size 40px, weight 400, line 1, tracking -0.004em
- title-md: family Anton, 'Bebas Neue', 'DIN', sans-serif, size 36px, weight 400, line 1, tracking -0.004em
- title-sm: family Anton, 'Bebas Neue', 'DIN', sans-serif, size 25px, weight 400, line 1.2, tracking -0.004em
- body-serif: family 'Hoefler Text', 'Cormorant Garamond', serif, size 16px, weight 400, line 1.5, tracking 0
- nav-link: family 'Jost', 'Futura PT', sans-serif, size 13px, weight 500, line 1.6, tracking 0.062em

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 60px
- xxl: 100px
- section: 100px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- top-nav: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- hero-text-overlay: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-md}
- editorial-card-title: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.title-lg}
- editorial-card-body: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-serif}
- underlined-text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- dark-footer: backgroundColor: {colors.ink}, textColor: {colors.on-dark}, typography: {typography.nav-link}, padding: 60px
- footer-display-cta: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-md}
- category-tag: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}

Color rationale: Core Palette - Canvas ({colors.canvas} — ffffff): The page background, navigation bar the source brand, and card the source brand. The system floor. - Ink ({colors.ink} — 000000): All text, display headings, navigation links, and the footer background. The primary content color. - On Dark ({colors.on-dark} — ffffff): Text color for use on the dark footer the source brand. - On Light ({colors.on-light} — 000000): Text color for use on the light canvas the source brand, reusing the {colors.ink} token. Structural & Muted - Hairline ({colors.hairline} — e5e7eb): The color for all 1px borders, dividers, and some link underlines. It provides structure without adding visual weight. - Muted the source brand ({colors.muted-surface} — a9a9a9): Used for image placeholder backgrounds or secondary tonal blocks. The only grey the source brand fill. - the source brand Warm ({colors.surface-warm} — fff5fa): A subtle, near-white the source brand with a hint of warmth. Used sparingly on select editorial cards to break the pure-white field.

Typography rationale: Font Family The system relies on a strict three-family hierarchy: - Condensed Sans-Serif: (e.g., Anton, Bebas Neue) Used for all display and section headings. Its defining characteristic is extreme scale, tight tracking, and compressed line-height. - Humanist Serif: (e.g., Hoefler Text, Cormorant Garamond) Used exclusively for editorial body text and long-form descriptions. Its presence signals 'content to be read'. - Geometric Sans-Serif: (e.g., Jost, Futura PT) Used for all UI chrome: navigation, micro-labels, tags, and footer links. Always rendered in all-caps with generous letter-spacing. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display-xl} | 100px | 400 | 0.8 | -0.008em | Top-level masthead display text. | | {typography.hero-display-lg} | 90px | 400 | 0.8 | -0.008em | Major feature headlines. | | {typography.display-md} | 52px | 400 | 1 | -0.006em | Card titles, footer CTA. | | {typography.display-sm} | 50px | 400 | 1 | -0.006em | Hero text overlays. | | {typography.title-serif} | 46px | 400 | 1.2 | 0 | Oversized serif lead-in paragraphs. | | {typography.title-lg} | 40px | 400 | 1 | -0.004em | Larger...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 60px · {spacing.xxl} 100px. - Section padding (vertical): {spacing.xl} (60px) to {spacing.xxl} (100px). Space is used generously to separate content blocks. - Card internal padding: {spacing.lg} (24px) for the text block below an image. - Gutters: {spacing.sm} (12px) between cards in multi-column grids. Grid & Container - Max content width: ~1400px for centered content grids. Hero images and the footer are always full-bleed. - Editorial body: A 4-column equal grid is the standard for presenting content cards. This reflows to 2-column on tablet and 1-column on mobile. - Footer: Two-column link list (left-aligned and right-aligned) flanking a centered display-scale text link. Whitespace Philosophy The system is defined by its generous use of negative space. Since there are no card backgrounds or shadows, whitespace and thin {colors.hairline} dividers are the sole tools for creating structure and separation. The layout feels open and architectural, allowing the oversized typography and full-bleed imagery to command attention.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Page canvas, all cards, all text blocks. | | Hairline | 1px solid {colors.hairline} | Section dividers, underlines on some links. | The elevation philosophy is strictly flat. There are no drop shadows, gradients, or any effects that imply Z-axis depth. The visual model is that of a printed page or a concrete wall—all elements exist on a single, uncompromising plane. Separation is achieved through structure (hairlines) and composition (whitespace), never through simulated depth.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | Universally applied. Cards, images, containers, buttons (links). | | {rounded.sm} | 0px | N/A | | {rounded.md} | 0px | N/A | | {rounded.lg} | 0px | N/A | | {rounded.xl} | 0px | N/A | | {rounded.pill} | 0px | N/A | | {rounded.full} | 0px | N/A | The system's shape language is defined by its rejection of rounded corners. All elements must have sharp, 90-degree angles. This contributes to the severe, architectural, and monolithic feel of the design. Photography & Iconography - Imagery is typically full-bleed, edge-to-edge, with 0px radius. - Icons are not a feature of the system. Where affordances are needed (e.g., carousel arrows, expand buttons), they are rendered as simple typographic glyphs (e.g., '‹', '+').

Component language: Navigation top-nav — A minimal, floating horizontal bar of text links. No background or border. Uses {typography.nav-link} for all items, rendered in {colors.ink} on the {colors.canvas} page background. The active state is indicated by a simple underline. Content hero-text-overlay — Used for text placed directly on top of a full-bleed hero image. Text is {colors.on-dark} (white) and uses a display size like {typography.display-md}. editorial-card — The primary content unit. It is not a container, but a composition of an {component.image-area} stacked above a text block. The title uses {component.editorial-card-title} and the description uses {component.editorial-card-body}. The entire unit sits directly on the page canvas with no background or border. category-tag — An inline text label using {typography.nav-link} to classify content. Appears above card titles. Actions underlined-text-link — The system's only "button." It's a text link styled with {typography.nav-link} (13px, all-caps, wide tracking). The affordance is a 1px underline in {colors.ink} or {colors.hairline}. Footer dark-footer — A full-width, full-bleed band with a {colors.ink} background. It contains secondary navig...

Guardrails: Do - Use extreme typographic scale for hierarchy. A 100px display headline is a feature, not an option. - Set all UI text (nav, tags, links) in the {typography.nav-link} style: 13px, all-caps, with 0.062em letter-spacing. This specific tracking is non-negotiable. - Maintain 0px border-radius on all elements. Corners must be sharp. - Use the humanist serif font for all long-form body copy to provide a readable, literary contrast to the severe display sans-serif. - Rely on whitespace and 1px {colors.hairline} rules for all visual separation. - Compress the line-height of display headlines (to ~0.8) to create dense, powerful typograp...
```
