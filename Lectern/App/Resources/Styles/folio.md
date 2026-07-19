# Folio

**ID:** `folio`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#fef9ed`
- `#2e4d4d`
- `#f5f0e4`
- `#5d524b`
- `#72675b`
- `#cec7bc`
- `#fbd3be`
- `#8c5462`
- `#666583`

## Typography

Families: "'Bradford LL', 'Source Serif Pro', serif", "'Red Hat Mono', 'IBM Plex Mono', monospace". Weights: 400, 450.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Microsoft AI

Design token description: A rare-press manuscript aesthetic bound in linen, featuring warm parchment canvases (fef9ed), deep ink-teal voids (2e4d4d), and oversized serif type that treats the page as editorial space. The palette is almost entirely earth-toned — cream, walnut (5d524b), and faded rose (8c5462) — with a single deep green-black reserved for the hero to create dramatic chiaroscuro. Typography is the entire personality, splitting between a custom transitional serif for all editorial content and a sharp monospace for UI affordances. The system intentionally avoids shadow and elevation; surfaces are flat planes of warm paper stacked with generous breathing room. Actions live in text, arrow glyphs, and giant pill radii that feel like wax seals on an envelope.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system reads like a rare-press manuscript bound in linen — warm parchment canvases ({colors.canvas-light} — fef9ed), deep ink-teal voids ({colors.canvas-dark} — 2e4d4d), and oversized serif type that treats the page as editorial space rather than a product the source brand. The palette is almost entirely earth-toned: cream, walnut ({colors.ink} — 5d524b), faded rose, and a single anchoring deep green-black that appears only in the hero, creating a dramatic chiaroscuro between the top of the page and everything below. Typography is the entire personality. A custom transitional serif ('Bradford LL') dominates display and body, carrying italic for emphasis and aggressive negative tracking as sizes grow. A monospace ('Red Hat Mono') handles the few UI affordances — tabs, labels, search, and navigation links. There are no saturated brand colors, no gradient buttons, and no filled CTAs with hue. Action lives in text, in arrow glyphs, and in the giant pill radius ({rounded.pill-cta}) that makes every control look like a wax seal on an envelope. The design intentionally avoids shadow and elevation; surfaces are flat planes of warm paper stacked against each other, separated by generou...

Color tokens:
- canvas-light: #fef9ed
- canvas-dark: #2e4d4d
- surface-soft: #f5f0e4
- ink: #5d524b
- muted: #72675b
- hairline: #cec7bc
- accent-wash: #fbd3be
- accent-text: #8c5462
- accent-secondary: #666583
- on-dark: #fef9ed

Typography tokens:
- hero-display: family 'Bradford LL', 'Source Serif Pro', serif, size 125px, weight 400, line 1, tracking -5px
- display-lg: family 'Bradford LL', 'Source Serif Pro', serif, size 100px, weight 400, line 1, tracking -3px
- display-md: family 'Bradford LL', 'Source Serif Pro', serif, size 45px, weight 400, line 1.13, tracking -0.9px
- title-lg: family 'Bradford LL', 'Source Serif Pro', serif, size 35px, weight 400, line 1.2, tracking 0
- title-md: family 'Bradford LL', 'Source Serif Pro', serif, size 25px, weight 400, line 1.25, tracking -0.33px
- title-sm: family 'Bradford LL', 'Source Serif Pro', serif, size 20px, weight 400, line 1.25, tracking -0.26px
- body-md: family 'Bradford LL', 'Source Serif Pro', serif, size 15px, weight 400, line 1.4, tracking -0.15px
- ui-monospace-md: family 'Red Hat Mono', 'IBM Plex Mono', monospace, size 15px, weight 450, line 1.25, tracking -0.2px
- ui-monospace-sm: family 'Red Hat Mono', 'IBM Plex Mono', monospace, size 13px, weight 400, line 1.6, tracking -0.2px
- caption: family 'Red Hat Mono', 'IBM Plex Mono', monospace, size 12px, weight 400, line 1.25, tracking 0.05px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 24px
- lg: 32px
- xl: 48px
- xxl: 64px
- section: 96px

Radius and shape tokens:
- xs: 4px
- sm: 8px
- md: 16px
- lg: 25px
- xl: 50px
- pill-nav: 65px
- pill-cta: 86px
- full: 9999px

Component tokens:
- top-nav-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.ui-monospace-sm}, height: 64px
- hero-display-band: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.hero-display}, padding: 96px 0
- section-heading: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.display-lg}
- editorial-body-block: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.title-md}
- gradient-atmosphere-band: backgroundColor: {colors.accent-wash}, textColor: {colors.ink}, typography: {typography.title-md}, padding: 96px 0
- pill-tab-nav: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, typography: {typography.ui-monospace-md}, rounded: {rounded.pill-nav}, padding: 16px 24px
- pill-tab-active: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.ui-monospace-md}, rounded: {rounded.pill-nav}
- pill-search-input: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.ui-monospace-md}, rounded: {rounded.xl}, padding: 12px 20px, height: 44px

Color rationale: the source brand - Canvas Dark ({colors.canvas-dark} — 2e4d4d): The deep, desaturated teal-green hero background. The only cool note in the system, creating a dramatic stage for the display typography. - Canvas Light ({colors.canvas-light} — fef9ed): The primary page floor. A warm parchment cream that carries all content sections below the hero. - the source brand Soft ({colors.surface-soft} — f5f0e4): A secondary the source brand one shade deeper than the canvas. Used for recessed panels, badge backgrounds, and tab navigation tracks. Text & Hairlines - Ink ({colors.ink} — 5d524b): The primary text color. A warm, dark brown that replaces black, keeping the system on the earth-tone spectrum. - Muted ({colors.muted} — 72675b): A mid-tone brown for secondary or helper copy, such as footer links. - On Dark ({colors.on-dark} — fef9ed): The light text color for use on {colors.canvas-dark}. The same value as {colors.canvas-light}, unifying the two primary surfaces. - Hairline ({colors.hairline} — cec7bc): A warm, light gray for dividers and input outlines that reads as thread on the cream canvas. Brand & Accent - Accent Wash ({colors.accent-wash} — fbd3be): A peachy, warm highlight. Used...

Typography rationale: Font Family The system uses a two-font model to separate editorial content from user interface chrome. - Primary Serif ('Bradford LL'): A custom transitional serif with warm proportions. It is used for all display headlines, section titles, and body copy. Its italic cut is the system's primary expressive voice. - UI Monospace ('Red Hat Mono'): A mechanical monospace used for all UI elements, including navigation links, tab labels, search inputs, and footer micro-copy. Its structured nature provides a counterpoint to the flowing serif. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 125px | 400 | 1 | -5px | The main hero headline | | {typography.display-lg} | 100px | 400 | 1 | -3px | Major section headings below the hero | | {typography.display-md} | 45px | 400 | 1.13 | -0.9px | Large sub-headings | | {typography.title-lg} | 35px | 400 | 1.2 | 0 | H3-level titles | | {typography.title-md} | 25px | 400 | 1.25 | -0.33px | Standard body copy for editorial blocks | | {typography.title-sm} | 20px | 400 | 1.25 | -0.26px | Hero sub-headline, smaller callouts | | {typography.body-md} | 15px | 400 | 1.4 | -0.15...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 48px · {spacing.xxl} 64px · {spacing.section} 96px. - Section padding (vertical): {spacing.section} (96px) is used between all major content bands, creating a generous, unhurried scroll. - Card internal padding: {spacing.lg} (32px) for content cards. - Gutters: {spacing.sm} (12px) between smaller adjacent elements. Grid & Container - Max content width: ~1200px for centered content blocks. Full-bleed elements like the hero and gradient bands have no max-width. - Editorial body: Centered within a ~720px column to maintain a comfortable reading line-length. - Layout Philosophy: The page is structured as a sequence of distinct editorial spreads, not a dense dashboard. Whitespace Philosophy The system uses whitespace as a primary design tool. Generous vertical rhythm separates content into clear, focused chapters, encouraging a slow, deliberate reading pace. The feeling is more akin to a gallery or a high-end publication than a typical tech interface.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat Canvas | No shadow, no border | Body sections, hero bands, footer | | Recessed the source brand | {colors.surface-soft} background | Tab navigation tracks, subtle panels | | Active the source brand | {colors.canvas-light} background | Active tab state, search inputs | The elevation philosophy is flat paper-on-table. There are no drop shadows. Depth is conveyed exclusively through subtle, one-step shifts in the warm, monochromatic the source brand colors. The primary elevation effect comes from the dramatic color temperature inversion between the deep, cool {colors.canvas-dark} of the hero and the warm {colors.canvas-light} of the main page.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Badges, small icons | | {rounded.lg} | 25px | Content cards | | {rounded.xl} | 50px | Input fields | | {rounded.pill-nav} | 65px | Pill-based tab navigation | | {rounded.pill-cta} | 86px | Primary pill-shaped controls | The system's shape language is defined by its use of extremely large, soft radii. The {rounded.pill-nav} and {rounded.pill-cta} values are signatures, creating an organic, hand-crafted feel that contrasts with the sharp, mechanical monospace type. Using standard 8px or 16px radii for controls would break this core "wax seal" metaphor.

Component language: Top Navigation top-nav-on-dark — The top-of-page navigation bar, which floats over the dark hero canvas ({colors.canvas-dark}). It is not a distinct bar with a background color. It consists of a {component.pill-search-input} on the left, a central typographic mark, and a series of {component.text-link-on-dark} elements on the right. All text uses {typography.ui-monospace-sm} in {colors.on-dark}. Hero & Headings hero-display-band — A full-bleed, full-viewport band setting the initial tone. Background {colors.canvas-dark}. Carries a centered headline in {typography.hero-display} in {colors.on-dark}. Often, the first word uses an italic cut for emphasis while the rest remains roman. section-heading — Large serif titles for content sections below the hero. Uses {typography.display-lg} in {colors.ink} on the {colors.canvas-light} background. editorial-body-block — The primary component for long-form text. A centered column of text using {typography.title-md} in {colors.ink}. Containers & Bands gradient-atmosphere-band — A full-bleed band used as a visual palate cleanser between content sections. It features a soft vertical gradient from {colors.accent-wash} to {colors.canvas-light}. It...

Guardrails: Do - Use the primary serif for all editorial content and the UI monospace only for interface controls. - Apply aggressive negative letter-spacing (-3px to -5px) to all display-sized serif headlines. - Create em...
```
