# Crimson

**ID:** `crimson`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#e4002b`
- `#000000`
- `#ffffff`
- `#a0a0a0`
- `#484848`
- `#101010`

## Typography

Families: "NextBook, Sohne, Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 300, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Studio Oker

Design token description: A minimalist, gallery-like interface built on a pure black (000000) canvas. Typography is the primary visual element, using a custom humanist-geometric face at whisper-thin weights (300) and tight negative letter-spacing. White (ffffff) is the sole color for text and structure, creating a stark, high-contrast environment. A single, scarce scarlet accent (e4002b) is used as punctuation—for a single link, a dot, or a hero-scale typographic statement—but never as a repeating brand color. The system rejects elevation, shadows, and rounded corners, opting for sharp 0px radii and generous negative space (120px+ section gaps) to structure content with monastic restraint.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This is a design system of monastic restraint, presenting a darkened gallery aesthetic built on a pure black canvas ({colors.canvas-dark} — 000000). The system speaks through negative space and typography, not color or decoration. Layouts are structured by generous, deliberate whitespace — with section breaks of {spacing.xxl} (120px) to {spacing.section} (240px) creating a slow, considered rhythm. All elements feature sharp, 90-degree corners, as the entire radius scale is set to {rounded.md} (0px). Typography is the system's primary voice, using a custom humanist-geometric face ('NextBook') at whisper-thin weights. Display sizes ({typography.display-lg}) use weight 300 with tight negative letter-spacing to feel architectural and composed. Running text ({typography.body-md}) uses weight 400. The color palette is almost entirely achromatic: white text ({colors.body}) on a black canvas. A single, vivid scarlet accent ({colors.primary} — e4002b) acts as punctuation rather than a brand color, appearing with extreme scarcity on a single link, dot, or hero statement per view. The system is confident in its minimalism, trusting silence over spectacle. Key Characteristics: - Pure black ca...

Color tokens:
- primary: #e4002b
- ink: #000000
- body: #ffffff
- muted: #a0a0a0
- hairline-on-dark: #484848
- canvas-dark: #000000
- surface-card-dark: #101010
- on-dark: #ffffff

Typography tokens:
- hero-display: family NextBook, Sohne, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 140px, weight 300, line 1, tracking -2.8px
- display-lg: family NextBook, Sohne, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 80px, weight 300, line 1, tracking -1.6px
- title-lg: family NextBook, Sohne, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 300, line 1, tracking -0.64px
- title-md: family NextBook, Sohne, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 400, line 1.13, tracking -0.24px
- body-md: family NextBook, Sohne, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.25, tracking -0.16px
- nav-link: family NextBook, Sohne, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.25, tracking -0.16px

Spacing tokens:
- xs: 8px
- sm: 16px
- md: 16px
- lg: 48px
- xl: 48px
- xxl: 120px
- section: 240px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- top-nav-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.nav-link}, height: 48px, padding: 0px 16px
- project-tile-card: backgroundColor: {colors.canvas-dark}, rounded: {rounded.md}
- hero-statement-panel: backgroundColor: {colors.canvas-dark}, textColor: {colors.primary}, typography: {typography.hero-display}, padding: 16px
- project-showcase-card: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.title-md}, padding: 16px
- link-with-accent: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.body-md}
- footer-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.muted}, typography: {typography.body-md}, padding: 16px 0

Color rationale: Brand & Accent - Primary Scarlet ({colors.primary} — e4002b): The sole chromatic accent. Used with extreme scarcity for a single, high-impact moment like a hero typographic statement or a small dot prefixing a link. It is a punctuation mark, not a UI color. the source brand - Canvas Dark ({colors.canvas-dark} — 000000): The universal page background. Everything sits on this pure black floor. - the source brand Card Dark ({colors.surface-card-dark} — 101010): A near-black tone used for rare, subtly elevated surfaces to break the pure black void. Hairlines & Borders - Hairline on Dark ({colors.hairline-on-dark} — 484848): A dark graphite tone for the 1px footer top border and other subtle structural dividers. Text - Body ({colors.body} — ffffff): The default text color for all primary content, headlines, and navigation on the dark canvas. - Muted ({colors.muted} — a0a0a0): A soft gray for secondary text, metadata, captions, and inactive labels. - On Dark ({colors.on-dark} — ffffff): Re-uses the main body token for any text on a dark the source brand. - Ink ({colors.ink} — 000000): Pure black for text on the rare occasion it appears over a white the source brand (e.g., inside a media...

Typography rationale: Font Family The system uses a single custom typeface, 'NextBook', for all roles. It is a humanist-geometric sans-serif characterized by its clean letterforms and ability to hold whisper-thin weights at large sizes. The fallback stack should prioritize close open-source alternatives like Inter or licensed alternatives like Söhne. - NextBook → used for all display, heading, body, and UI text. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 140px | 300 | 1 | -2.8px | Oversized hero-scale typographic statements | | {typography.display-lg} | 80px | 300 | 1 | -1.6px | Section headings | | {typography.title-lg} | 32px | 300 | 1 | -0.64px | Sub-section headings, large labels | | {typography.title-md} | 24px | 400 | 1.13 | -0.24px | Card titles, showcase headlines | | {typography.body-md} | 16px | 400 | 1.25 | -0.16px | Default running text, captions, list items | | {typography.nav-link} | 16px | 400 | 1.25 | -0.16px | Top navigation links, footer text | Principles The typographic voice is defined by its restraint. Display sizes ({typography.display-lg}) use an intentionally light weight (300) combined with ti...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xs} 8px · {spacing.sm} 16px · {spacing.lg} 48px · {spacing.xxl} 120px · {spacing.section} 240px. - Section padding (vertical): {spacing.xxl} (120px) is the standard gap between content blocks within a section. {spacing.section} (240px) is used for major breaks between page sections (e.g., between the work grid and the about section). These values are structural. - Card internal padding: {spacing.sm} (16px) is used for text content within cards or showcase blocks. - Gutters: {spacing.sm} (16px) between tiles in grids. Grid & Container - Max content width: None. The layout is full-bleed, expanding to the edges of the viewport. - Grid: Content is arranged in asymmetric grids (e.g., 3- or 4-column) where tiles have varying aspect ratios. This creates visual rhythm and avoids monolithic blocks. Text-heavy sections often use a 2- or 3-column layout for readability. - Alignment: All text is strictly left-aligned. Whitespace Philosophy Negative space is the primary layout tool. The system uses vast fields of {colors.canvas-dark} to frame content, creating deliberate pauses and giving each element room to breathe. The large spacing tokens...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The default state for all text, images, and panels on the main canvas | | Soft the source brand | {colors.surface-card-dark} background fill | A rare, subtle lift for a card that must sit above the pure black canvas | | Hairline | 1px {colors.hairline-on-dark} border | Footer top-border, structural dividers that must be visible but recessive | The elevation philosophy is to replace depth with void. The design treats the {colors.canvas-dark} canvas as a gallery wall, where all elements are mounted on the same plane. There are no drop shadows, inner shadows, or glows. Separation between elements is achieved through negative space or, when absolutely necessary, a thin hairline border. This is a deliberate anti-skeuomorphic stance.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | All elements | | {rounded.sm} | 0px | All elements | | {rounded.md} | 0px | The system default for cards, images, inputs, and buttons | | {rounded.lg} | 0px | All elements | | {rounded.xl} | 0px | All elements | | {rounded.pill} | 0px | Not used; actions are text-based or dot-prefixed links | | {rounded.full} | 0px | Not used | The system's shape language is defined by sharp, 90-degree corners. A {rounded.md} value of 0px is applied universally. This reinforces the architectural, precise, and composed character of the design. Photography & Iconography - Media (images, videos) is treated as artwork. It is always displayed full-bleed within its container, with {rounded.md} (0px) corners and no internal padding. - The system avoids iconography, preferring plain text for navigation and labels. The only exception may be a minimal glyph for a menu expander.

Component language: Top Navigation top-nav-dark — A persistent, full-bleed header bar. It has a {colors.canvas-dark} background that blends seamlessly with the page canvas. Height is ~48px with {spacing.sm} (16px) horizontal padding. It contains left-aligned identity text, muted metadata in the center, and right-aligned navigation links. All text uses {typography.nav-link}. Content Tiles project-tile-card — A grid cell in a showcase. It is an aspect-ratio-locked block with {rounded.md} (0px) corners and a {colors.canvas-dark} background. The content is typically a full-bleed image or a media element, filling the tile edge-to-edge. hero-statement-panel — A special tile used for a single, powerful typographic message. It uses a {colors.canvas-dark} background and sets an oversized statement in {typography.hero-display} using the scarce {colors.primary} scarlet color. project-showcase-card — A larger format card for detailed work. It consists of a full-width image area at the top, followed by a text block below with {spacing.sm} (16px) padding. The title uses {typography.title-md} in {colors.body}, while descriptive text and metadata use {typography.body-md} in {colors.muted}. Actions link-with-accent —...

Guardrails: Do - Use {colors.canvas-dark} (000000) as the universal background. Do not introduce gray surfaces or off-white panels. - Set all border radii to {rounded.md} (0px). Sharp corners are a core principle. - Use 'NextBook' weight 300 for all large display text, with tight negative letter-spacing. The whisper-weight is the signature. - Reserve {colors.primary} (e4002b) for a single use per clean interface-like information plane. Its power comes from its scarcity. - Honor the {spacing.xxl} (120px) and {spacing.section} (240px) vertical mar...
```
