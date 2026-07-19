# Monolith

**ID:** `monolith`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#8e93ff`
- `#1a1a1a`
- `#ffffff`
- `#47f654`

## Typography

Families: "'Beastly clauworks', Druk Wide, sans-serif", "'Suisse Intl clauworks', Suisse Int'l, Inter, sans-serif", "Times, serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Clau As Kee

Design token description: A typographic and monumental design system built on a flat periwinkle canvas (8e93ff). Colossal, custom display letterforms act as graphic sculpture. A strict palette of near-black ink (1a1a1a), paper white (ffffff), and a single jarring signal green (47f654) accent provides all structure. The system is intentionally flat and anti-SaaS, with no shadows, gradients, or soft radii; hierarchy is established through monumental scale differences in type, not weight or color.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a minimalist, poster-like design system defined by its flat lavender-periwinkle canvas ({colors.canvas} — 8e93ff) and its use of monumental typography as a primary graphic element. The aesthetic is anti-SaaS and editorial, rejecting common UI patterns like cards, shadows, and gradients in favor of stark color-blocking and scale. A strict four-color palette provides all structure: the periwinkle canvas, a near-black ink ({colors.ink} — 1a1a1a) for text and dark panels, a clean paper white ({colors.surface} — ffffff) for inverted surfaces, and a single, jarring signal green ({colors.accent} — 47f654) for the sole interactive accent. Hierarchy is communicated exclusively through dramatic shifts in type size. A custom, blocky display face is used at colossal sizes (288-504px) as architectural sculpture, while a supporting grotesque carries all other roles at a single, consistent weight. There are no bold or italic styles; prominence comes from scale alone. Layouts are full-bleed and container-less, treating the viewport as a canvas where typographic forms can bleed off the edges. The overall feeling is one of total restraint and graphic confidence. Key Characteristics: - Singl...

Color tokens:
- primary: #8e93ff
- ink: #1a1a1a
- surface: #ffffff
- accent: #47f654
- canvas: #8e93ff
- canvas-dark: #1a1a1a
- body: #1a1a1a
- on-dark: #ffffff
- hairline: #1a1a1a

Typography tokens:
- display-xl: family 'Beastly clauworks', Druk Wide, sans-serif, size 504px, weight 400, line 1, tracking 0
- display-lg: family 'Beastly clauworks', Druk Wide, sans-serif, size 288px, weight 400, line 1.05, tracking 0
- display-md: family 'Suisse Intl clauworks', Suisse Int'l, Inter, sans-serif, size 144px, weight 400, line 1.15, tracking 0
- title-md: family 'Suisse Intl clauworks', Suisse Int'l, Inter, sans-serif, size 30px, weight 400, line 1.3, tracking 0
- body-md: family 'Suisse Intl clauworks', Suisse Int'l, Inter, sans-serif, size 20px, weight 400, line 1.5, tracking 0
- nav-link: family 'Suisse Intl clauworks', Suisse Int'l, Inter, sans-serif, size 20px, weight 400, line 1.5, tracking 0
- caption: family Times, serif, size 16px, weight 400, line 1.15, tracking 0
- button: family 'Suisse Intl clauworks', Suisse Int'l, Inter, sans-serif, size 20px, weight 400, line 1.5, tracking 0

Spacing tokens:
- xxs: 5px
- xs: 22px
- sm: 30px
- md: 58px
- lg: 65px
- xl: 90px
- xxl: 130px
- section: 130px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 75px
- full: 75px

Component tokens:
- hero-sculpture-text: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.display-xl}
- top-nav: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- accent-badge: backgroundColor: {colors.accent}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.pill}, padding: 12px 24px
- content-band-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.body-md}, padding: 130px 65px
- media-spread-card: backgroundColor: {colors.surface}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.sm}
- hairline-divider: backgroundColor: {colors.hairline}, height: 1px

Color rationale: Brand & Canvas - Periwinkle Field ({colors.primary} — 8e93ff): The defining color of the system. Used as the default page canvas, hero background, and the floor for all primary content. Neutrals - Carbon Ink ({colors.ink} — 1a1a1a): The primary color for all text, hairlines, and dark, inverted panels ({component.content-band-dark}). It is a near-black, not a pure black, to reduce vibration against the periwinkle. - Paper White ({colors.surface} — ffffff): The surface for content inside dark panels, such as media plates or text blocks. It functions as the "paper" against the "ink" of the dark panel. Accent - Signal Green ({colors.accent} — 47f654): A high-voltage green used for the single interactive accent element, {component.accent-badge}. Its use is extremely restricted to maintain its signaling power.

Typography rationale: Font Family The system uses a two-font pairing: 1. A custom, blocky display face (Beastly clauworks) for monumental, sculptural headlines. It is architecture, not text. 2. A custom Swiss-style grotesque (Suisse Intl clauworks) for all other roles, from large editorial headlines to body copy. A system serif (Times) is used for the smallest caption text, creating a deliberate textural contrast. The key principle is the complete absence of weight variation; everything is set at fontWeight: 400. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 504px | 400 | 1 | 0 | Hero-level typographic sculpture (display face) | | {typography.display-lg} | 288px | 400 | 1.05 | 0 | Secondary hero-level type (display face) | | {typography.display-md} | 144px | 400 | 1.15 | 0 | Large editorial headlines in-flow (grotesque face) | | {typography.title-md} | 30px | 400 | 1.3 | 0 | Subheadings and section titles (grotesque face) | | {typography.body-md} | 20px | 400 | 1.5 | 0 | Default body copy, nav links (grotesque face) | | {typography.caption} | 16px | 400 | 1.15 | 0 | Smallest metadata labels (serif face) | Principles - Scal...

Layout system: Spacing System - Base unit: The system uses an ad-hoc but consistent scale. - Tokens: {spacing.xxs} 5px · {spacing.xs} 22px · {spacing.sm} 30px · {spacing.md} 58px · {spacing.lg} 65px · {spacing.xl} 90px · {spacing.xxl} 130px · {spacing.section} 130px. - Section padding (vertical): {spacing.section} (130px) is used to create significant breathing room between major content blocks, reinforcing the editorial, poster-like feel. - Internal padding: Dark content panels use {spacing.lg} (65px) for side padding. - Element gap: Typographic elements are separated by {spacing.sm} (30px). Grid & Container The system has no container or max-width grid. Layouts are full-bleed by default. Content blocks, whether typographic or media, span the full width of the viewport. The layout strategy is a simple vertical stack of full-width sections, alternating between {colors.canvas} and {colors.canvas-dark} backgrounds. Whitespace Philosophy Whitespace is a primary tool. The large {spacing.section} value ensures that each content block is perceived as a distinct, intentional composition on the periwinkle field. The system avoids density and clutter at all costs.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 1 | Flat color canvas ({colors.canvas}) | The base page floor. | | 2 | Inverted color panel ({colors.canvas-dark}) | Dark, full-bleed sections used to frame and contrast content. | | 3 | Surface on dark ({colors.surface}) | White "paper" plates inside dark panels that hold images or text. | | Separator | 1px hairline ({colors.hairline}) | A solid 1px line in {colors.ink} is the only element used to divide sections on the same canvas. | The system is philosophically flat. It actively rejects elevation through shadows, glows, or gradients. Depth is implied purely through the layering of opaque, contrasting color fields. A {component.content-band-dark} feels "separate" from the {colors.canvas} background because of its color, not because of a simulated z-axis.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 0px | The default for all elements: panels, media containers, images. | | {rounded.pill} | 75px | Used exclusively for the circular {component.accent-badge}. | The shape language is aggressively rectilinear. Sharp, 0px corners are the default and define the architectural feel of the layout. The single, perfectly circular badge is a deliberate and stark contrast to this rule.

Component language: Top Navigation top-nav — A minimal set of three text links, distributed across the top edge of the viewport (left, center, right). It uses {typography.nav-link} in {colors.ink} directly on the page canvas with no background bar or container. It is meant to be discovered, not to be a persistent, heavy UI element. Accent Badge accent-badge — The only interactive, chromatic element. A circular pill with {rounded.pill}, a {colors.accent} background, and {colors.ink} text. It is used as a floating overlay, typically anchored to a content block, to draw attention to a single, specific call to action. Content Bands & Cards content-band-dark — A full-bleed panel using {colors.canvas-dark} as its background. It acts as a "dark mode" section to break up the periwinkle canvas and frame specific content, such as a portfolio piece. It has generous {spacing.section} vertical padding. media-spread-card — A simple rectangular surface using {colors.surface} as a background. It lives inside a {component.content-band-dark} and contains images or text. It has {rounded.sm} (0px) corners and relies on the dark background for visual separation. Primitives hero-sculpture-text — Not a component but a typo...

Guardrails: Do - Start every page with a {colors.canvas} background. This is the non-negotiable foundation. - Use the custom display face only at monumental sizes (200px+). - Create hierarchy using only the discrete sizes in the type scale. Do not add intermediate sizes or bold weights. - Let large display type bleed off the edges of the viewport. The cropping is part of the aesthetic. - Use the {colors.accent} badge at most once per view to preserve its impact. - Alternate between {colors.canvas} and {colors.canvas-dark} sections to create a visual rhythm on long pages. - Use {spacing.section} (130px) of vertical space between all major content blocks. Don't - Don't introduce a fifth color. The four-color palette is intentionally restrictive. - Don't use rounded corners on any panel, container, or image. {rounded.sm} (0px) is the rule. - Don't use shadows, gradients, blurs, or any other effect that fakes elevation. The system is flat. - Don't use the display face for functional text or at small sizes; it is a graphic element. - Don't add a sticky header or complex navigation. The minimal, distributed top navigation is the only pattern. - Don't place content within a centered container. All l...

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- restrained compositions with generous negative space and high typographic confidence
- editorial pacing with strong headline moments, image fields, and magazine...
```
