# Citron

**ID:** `citron`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#a6ff00`
- `#101010`
- `#000000`
- `#fdfdfd`
- `#6f6f6f`
- `#040126`
- `#333333`
- `#3d3d3d`
- `#171717`

## Typography

Families: "'Arial', -apple-system, BlinkMacSystemFont, sans-serif", "'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Stryds

Design token description: A poster-scale interface manifesto built on a near-black void, ringed by a segmented spectrum gradient. Display typography pushes past 100px to feel like a billboard, not a dashboard. The entire palette is monochrome — one canvas tone, one text tone, one border tone — broken only by an electric lime (a6ff00), the single chromatic voice that makes CTAs and active states feel switched on. A massive circular gradient frame is the signature visual gesture. Components are minimal and pill-shaped; the design uses hairline borders instead of elevation. The result is an editorial, late-night broadcast feel that is bold, confrontational, and deeply opinionated.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: telecom/connectivity. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, SIM cards, cell towers, antennas, routers, call screens, or telecom product shots.

Overall visual personality: This is a poster-scale design system that feels more like a late-night broadcast than a product interface. The foundation is a near-black void ({colors.canvas-dark} — 101010) that fills the viewport, creating a dramatic, focused canvas. The entire palette is monochrome, using shades of gray for text and surfaces, with a single, potent chromatic accent: Electric Lime ({colors.primary} — a6ff00). This lime is used exclusively for primary CTAs and active states, giving it immense visual power. The system's most defining characteristic is its typography, which scales to billboard-like proportions (up to 184px) with tight line-heights and negative tracking to feel architectural. This is paired with a signature visual gesture: a massive, segmented circular spectrum gradient ring that frames hero content like an aura. Components are minimal and soft, using either pill ({rounded.pill}) or large ({rounded.xl}) radii. The system is deliberately flat, using {colors.hairline-on-dark} borders to distinguish surfaces rather than shadows or elevation. Spacing is extremely generous ({spacing.section} — 80px), letting the massive typography and graphic elements breathe. Key Characteristics: - Sing...

Color tokens:
- primary: #a6ff00
- on-primary: #101010
- ink: #000000
- body: #fdfdfd
- on-dark: #fdfdfd
- muted: #6f6f6f
- border-accent: #040126
- hairline-on-dark: #333333
- border-strong: #3d3d3d
- canvas-dark: #101010
- surface-card-dark: #171717

Typography tokens:
- hero-display-xl: family 'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif, size 184px, weight 600, line 0.95, tracking -6.26px
- hero-display-lg: family 'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif, size 148px, weight 600, line 1, tracking -4px
- hero-display: family 'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif, size 109px, weight 500, line 1, tracking -2.83px
- display-lg: family 'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif, size 78px, weight 500, line 1, tracking -1.79px
- display-md: family 'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif, size 44px, weight 600, line 1.1, tracking -0.53px
- display-sm: family 'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif, size 36px, weight 600, line 1.2, tracking -0.36px
- title-lg: family 'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif, size 21px, weight 500, line 1.25, tracking -0.15px
- body-md: family 'Arial', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.25, tracking 0.43px
- caption: family 'Arial', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.43, tracking -0.48px
- button: family 'Arial', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 500, line 1, tracking 0

Spacing tokens:
- md: 16px
- lg: 20px
- xl: 32px
- section: 80px
- section-lg: 108px

Radius and shape tokens:
- xl: 40px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 13px 20px
- button-secondary-outlined: backgroundColor: transparent, textColor: {colors.border-accent}, typography: {typography.button}, rounded: {rounded.pill}, padding: 13px 20px
- feature-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.on-dark}, rounded: {rounded.xl}, padding: {spacing.section}
- avatar-badge: backgroundColor: {colors.muted}, rounded: {rounded.full}, height: 60px, width: 60px

Color rationale: Brand & Accent - Electric Lime ({colors.primary} — a6ff00): The sole brand color. Used for primary CTA backgrounds and active state indicators. Its rarity makes it feel urgent and important. - On Primary ({colors.on-primary} — 101010): The near-black text color used on top of lime CTAs for high contrast. Surface - Canvas Dark ({colors.canvas-dark} — 101010): The base page background. A deep, near-black that serves as the void for all other elements. - Surface Card Dark ({colors.surface-card-dark} — 171717): The only elevated surface tone, used for content cards. It's a subtle step up from the canvas. Hairlines & Borders - Hairline on Dark ({colors.hairline-on-dark} — 333333): The primary border color for separating cards from the canvas and for full-width dividers. - Border Strong ({colors.border-strong} — 3d3d3d): A slightly lighter border for nested or secondary dividers. - Border Accent ({colors.border-accent} — 040126): A deep, near-black violet used for the border of outlined secondary buttons. It's a tonal accent, not a chromatic one. Text - Body / On Dark ({colors.body} — fdfdfd): The primary text color for headlines and active body copy. Bright white for maximum contrast a...

Typography rationale: Font Family The system uses a deliberate two-font strategy to create hierarchy: - SF Pro Display (or substitute: Inter, system-ui): Used for all display and heading typography. Its selection high-availability connection system a premium, confident voice. Weights are kept at a moderate 500-600; authority comes from size, not boldness. - Arial (or substitute: system-ui, sans-serif): Used for all body copy and button labels. It is intentionally neutral and "invisible," allowing the display type to perform all the emotional and branding work. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display-xl} | 184px | 600 | 0.95 | -6.26px | Top-level hero headlines. | | {typography.hero-display-lg} | 148px | 600 | 1.0 | -4px | Primary hero headlines. | | {typography.hero-display} | 109px | 500 | 1.0 | -2.83px | Large editorial statements. | | {typography.display-lg} | 78px | 500 | 1.0 | -1.79px | Section headlines. | | {typography.display-md} | 44px | 600 | 1.1 | -0.53px | Card titles. | | {typography.display-sm} | 36px | 600 | 1.2 | -0.36px | Smaller card titles. | | {typography.title-lg} | 21px | 500 | 1.25 | -0.15px | S...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.md} 16px · {spacing.lg} 20px · {spacing.xl} 32px · {spacing.section} 80px · {spacing.section-lg} 108px. - Section padding (vertical): {spacing.section} (80px) is the default gap between major content blocks, creating a very spacious, editorial rhythm. - Card internal padding: A very generous {spacing.section} (80px) is used inside {component.feature-card}, allowing content to breathe heavily. - Gutters: {spacing.md} (16px) is used for small gaps between inline elements. Grid & Container The system largely avoids a traditional grid. Layouts are full-bleed with no maximum content width. Content is almost always center-aligned, reinforcing the poster-like, declarative feel. The structure is a simple vertical stack of full-width sections, each treated as a distinct moment. Whitespace Philosophy Whitespace is a primary tool. The design feels expansive and unhurried due to the large, consistent gaps ({spacing.section}) between elements. The system trusts negative space, not dense containers, to create structure and focus.

Depth and hierarchy: The system is deliberately flat. There are no box-shadows used for elevation. - Level 1 (Canvas): The base {colors.canvas-dark} page floor. - Level 2 (Card): The {colors.surface-card-dark} sits directly on the canvas. Separation is achieved with a 1px {colors.hairline-on-dark} border, not by lifting the surface with a shadow. Visual hierarchy is established through typographic scale, color contrast ({colors.primary} on dark), and the framing provided by graphic elements, never through Z-axis depth.

Shape language: Border Radius Scale The system uses a very simple and bold radius scale with no small or medium values. | Token | Value | Use | |---|---|---| | {rounded.xl} | 40px | Content cards ({component.feature-card}). | | {rounded.pill} | 9999px | All buttons ({component.button-primary}, {component.button-secondary-outlined}). | | {rounded.full} | 9999px / 50% | Avatars. | Signature Graphic: The Aurora Ring The most recognizable shape is a large, decorative circular gradient ring. It is not a UI component but a framing device. - Structure: A thick-stroked ring with a conic gradient running through a spectrum (lime, teal, blue, purple, pink, the source brand). - Appearance: The gradient has intentional gaps, making the ring look segmented or dashed. - Usage: It frames hero headlines and other major content blocks, filling most of the viewport at large sizes. It is the only element in the system that uses multiple colors or gradients.

Component language: Buttons button-primary — The main call-to-action. A full pill shape ({rounded.pill}) with a {colors.primary} background and {colors.on-primary} text. The high-contrast lime and black combination is the system's primary high-availability connection system for action. button-secondary-outlined — The secondary action button. Also a full pill shape, but with a transparent background. It uses a 1px border and text in {colors.border-accent}, a near-black violet that is subtly visible against the {colors.canvas-dark} background. Cards & Containers feature-card — The primary container for content. It uses a {colors.surface-card-dark} background, separated from the canvas by a 1px {colors.hairline-on-dark} border. Its signature features are its soft {rounded.xl} (40px) corners and extremely generous {spacing.section} (80px) internal padding. avatar-badge — A simple circular element for user profile images. It is a perfect circle ({rounded.full}) with no border or shadow, often positioned to overlap with other graphic elements.

Guardrails: Do - Use the signature gradient ring as the primary visual frame for hero sections. It is the system's most distinct gesture. - Set display type at poster-scale (78px-184px) with tight line heights and negative tracking. - Reserve {colors.primary} exclusively for primary CTAs and critical active states. Its power comes from its rarity. - Adhere to the strict shape language: all buttons are pills ({rounded.pill}), all cards are softly rounded ({rounded.xl}). - Use {colors.hairline-on-dark} borders, not shadows, to separate surfaces. - Maintain {spacing.section} (80px) for both section gaps and internal card padding. The design must breathe. - Create text emphasis by contrasting {colors.body} and {colors.muted} within a single headline. Don't - Don't use box-shadows for elevation. The system is flat. - Don't introduce additional accent colors. The monochrome-plus-one discipline is fund...
```
