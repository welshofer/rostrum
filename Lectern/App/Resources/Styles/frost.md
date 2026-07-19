# Frost

**ID:** `frost`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#3a3a3e`
- `#090b11`
- `#b5b0b0`
- `#ffffff`
- `#bfe0f7`
- `#ffcf9e`
- `#babfff`
- `#e3a2ef`

## Typography

Families: "Instrument Sans, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: BlueYard Capital

Design token description: An editorial, monograph-like design language built on a vast white canvas. A warm near-black (3a3a3e) carries all typography, set in a single geometric sans-serif with aggressive negative tracking for a modern, couture feel. Chromatic color is used exclusively for surface treatments — pale peach (ffcf9e), lavender (babfff), and fuchsia (e3a2ef) tints appear as card backgrounds or hairline borders, never for interactive elements. The system is intentionally flat, with 0px radii on all elements, achieving separation through generous whitespace and stark, thin hairlines instead of shadows or elevation.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system reads as a printed editorial object disguised as a digital interface: a vast white canvas ({colors.canvas-light}) anchored by atmospheric color washes, a single oversized sans-serif headline, and large, uncaptioned media. The palette is overwhelmingly achromatic — a warm near-black ({colors.ink} — 3a3a3e) does all the textual heavy lifting against pure white. Three pale chromatic tints — a warm peach ({colors.accent-peach}), cool lavender ({colors.accent-lavender}), and vivid pink ({colors.accent-fuchsia}) — appear only as card backgrounds and hairlines, never as functional buttons or interactive-state colors. Cards are flat and borderless or hairline-bordered, floating in generous whitespace. Navigation is minimal to the point of near-invisibility. The entire experience earns attention through restraint, scale, and typographic precision, not UI chrome. Key Characteristics: - Single typeface system: Instrument Sans is used for every UI element, from 54px display headlines to 12px captions. - Monolithic text color: {colors.ink} (3a3a3e) carries over 95% of all text and hairline strokes. - Chromatics for surface only: {colors.accent-peach}, {colors.accent-lavender}, and {...

Color tokens:
- ink: #3a3a3e
- ink-strong: #090b11
- body: #3a3a3e
- muted: #b5b0b0
- hairline: #3a3a3e
- canvas-light: #ffffff
- surface-soft: #b5b0b0
- surface-cool: #bfe0f7
- accent-peach: #ffcf9e
- accent-lavender: #babfff
- accent-fuchsia: #e3a2ef
- border-accent-peach: #ffcf9e
- border-accent-lavender: #babfff

Typography tokens:
- display-lg: family Instrument Sans, -apple-system, BlinkMacSystemFont, sans-serif, size 54px, weight 400, line 1, tracking -1.62px
- display-md: family Instrument Sans, -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 400, line 1.2, tracking -0.54px
- body-lg: family Instrument Sans, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 400, line 1.5, tracking -0.24px
- caption: family Instrument Sans, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.5, tracking -0.36px
- nav-link: family Instrument Sans, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 500, line 1, tracking -0.36px

Spacing tokens:
- xxs: 5px
- xs: 8px
- sm: 12px
- md: 18px
- lg: 24px
- xl: 60px
- xxl: 90px
- section: 90px

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
- hero-headline: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.display-lg}
- card-peach-border: backgroundColor: {colors.canvas-light}, borderColor: {colors.border-accent-peach}, borderWidth: 1px, textColor: {colors.body}, typography: {typography.body-lg}, rounded: {rounded.none}, padding: 12px
- card-peach-fill: backgroundColor: {colors.accent-peach}, textColor: {colors.ink}, typography: {typography.body-lg}, rounded: {rounded.none}, padding: 12px
- card-lavender-border: backgroundColor: {colors.canvas-light}, borderColor: {colors.border-accent-lavender}, borderWidth: 1px, textColor: {colors.body}, typography: {typography.body-lg}, rounded: {rounded.none}, padding: 12px
- card-fuchsia-fill: backgroundColor: {colors.accent-fuchsia}, textColor: {colors.ink-strong}, typography: {typography.body-lg}, rounded: {rounded.none}, padding: 12px
- section-band-soft: backgroundColor: {colors.surface-soft}, padding: 90px 0
- section-band-cool: backgroundColor: {colors.surface-cool}, padding: 90px 0
- nav-trigger-button: backgroundColor: {colors.canvas-light}, borderColor: {colors.hairline}, borderWidth: 1px, rounded: {rounded.none}, height: 40px, width: 40px

Color rationale: Text & Ink - Graphite Ink ({colors.ink} — 3a3a3e): The primary text, link, icon, and hairline color. A warm near-black that carries the vast majority of the typographic weight. - Deep Carbon ({colors.ink-strong} — 090b11): A slightly cooler, higher-contrast near-black reserved for text on the most saturated accent surfaces like {colors.accent-fuchsia}. Surface - Canvas White ({colors.canvas-light} — ffffff): The default page background. The dominant surface occupying most of the viewport, serving as the primary stage. - Ash Veil ({colors.surface-soft} — b5b0b0): A warm gray used for full-bleed secondary surface bands, providing a quiet pause between white sections. - Polar Blue ({colors.surface-cool} — bfe0f7): A pale sky blue used as a rare, full-bleed section background to cool the otherwise warm palette. Accent & Borders Accent colors are used exclusively as card background fills or 1px hairline borders. They categorize content rather than signal interaction. - Apricot Wash ({colors.accent-peach} — ffcf9e): The dominant chromatic accent, used as a warm fill or hairline outline ({colors.border-accent-peach}) on featured cards. - Iris Mist ({colors.accent-lavender} — babfff): A c...

Typography rationale: Font Family The system uses a single typeface, Instrument Sans, for all UI elements, headlines, and body copy. It's a humanist geometric grotesque that, when paired with aggressive negative tracking, produces a tight, modern, editorial quality. The fallback stack is a standard sans-serif system UI list. - Substitute: Inter, Söhne, or General Sans. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 54px | 400 | 1 | -1.62px | Primary hero headlines; designed to not wrap. | | {typography.display-md} | 48px | 400 | 1.2 | -0.54px | Secondary headlines and large section titles. | | {typography.body-lg} | 24px | 400 | 1.5 | -0.24px | Default running text. Unusually large, giving paragraphs a printed-magazine feel. | | {typography.caption} | 12px | 400 | 1.5 | -0.36px | Small meta-text and labels. | | {typography.nav-link} | 12px | 500 | 1 | -0.36px | Navigation links and other emphasized small text. The only common use of weight 500. | Principles - Single Typeface: The entire typographic voice is carried by Instrument Sans. - Editorial Scale: The type scale has a 4.5x jump from caption to display, prioritizing im...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 5px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 18px · {spacing.lg} 24px · {spacing.xl} 60px · {spacing.xxl} 90px. - Section padding (vertical): {spacing.section} (90px) is used between all major content blocks, creating a spacious, unhurried rhythm. - Card internal padding: {spacing.sm} (12px) is the standard for all content cards. - Gutters: {spacing.xxs} (5px) between elements in a tight cluster; {spacing.sm} (12px) between cards in a grid. Grid & Container - Max content width: ~1200px, with content either centered or left-aligned within this container. - Hero layout: The defining pattern is a large, centered headline in the upper third of the viewport, with a large, uncaptioned media object occupying the lower half, often bleeding off the bottom edge. - Body layout: Below the hero, the page flows in alternating white and soft-tinted full-bleed bands, with card grids (1-3 columns) inside. Whitespace Philosophy The system is defined by its generous use of negative space. Hierarchy is established through scale and whitespace, not chrome or elevation. The {spacing.section} gap between content blocks is crucial to m...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Default page canvas, body text, hero bands | | Hairline | 1px {colors.hairline} or accent border | Cards, navigation trigger, section dividers | | Color Surface | Solid background fill ({colors.accent-peach}, etc.) | Highlighted cards, section bands | The elevation model is strictly flat. Depth is non-existent. Separation between layers is achieved exclusively through whitespace, 1px hairline borders, and shifts in surface color. There are no box-shadows, glows, or gradients applied to UI components.

Shape language: Border Radius Scale The system uses a single, non-negotiable radius value for all elements. | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | The universal corner radius for all cards, buttons, tags, and inputs. | All other radius tokens ({rounded.xs} through {rounded.full}) are also set to 0px to enforce this rule. Sharp, 90-degree corners are a core visual signature. Media & Iconography - Media objects are typically large, uncaptioned, and bleed off the edges of the viewport without a frame. - There is no decorative iconography. When icons appear (e.g., a hamburger menu icon), they are simple, thin-line glyphs rendered in {colors.ink}.

Component language: Hero Headline hero-headline — A full-width, centered typographic block. Uses {typography.display-lg} (54px / 400wt) in {colors.ink}, with a line-height of 1.0 to keep it tight. It sits in the upper third of the viewport with generous {spacing.section} top padding. Accent Cards The system uses a family of cards distinguished by their surface treatment. All share {rounded.none} corners and {spacing.sm} padding. card-peach-border — A standard content card on a {colors.canvas-light} surface, defined by a 1px {colors.border-accent-peach} hairline. The warm border is the only signal of its special status. card-peach-fill — A highlighted card with a solid {colors.accent-peach} background and {colors.ink} text. Used sparingly to feature a single item. card-lavender-border — A cool counterpoint to the peach card, using a 1px {colors.border-accent-lavender} hairline. Often paired with peach-bordered cards in a grid to create a warm/cool rhythm. card-fuchsia-fill — The most vibrant card, with a solid {colors.accent-fuchsia} background and high-contrast {colors.ink-strong} text. Used as a singular accent block, never repeated in a grid. Navigation & Links nav-trigger-button — The primary navi...

Guardrails: Do - Keep over 95% of all text and borders in {colors.ink}. Let the warm near-black carry the interface. - Use the chromatic tints ({colors.accent-peach}, {colors.accent-lavender}, {colors.accent-fuchsia}) only as card backgrounds or 1px hairline borders. - Set every radius to {rounded.none}. Sharp corners are a defining characteristic. - Apply aggressive negative letter-spacing to display typography, especially {typography.display-lg}. - Anchor every section with {spacing.section} of vertical breathing room. Let whitespace create the hierarchy. - Use weight 400 for almost everything, including large display headlines. Reserve weight 500 for small, important labels. Don't - Do not introduce shadows, glows, or any other elevation effects. The system is flat. - Do not round corners on any...
```
