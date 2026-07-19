# Iris

**ID:** `iris`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#471cff`
- `#0f0733`
- `#18181f`
- `#ffffff`
- `#494949`
- `#dbd3ff`
- `#f0f5fa`
- `#bbc5fa`
- `#eaecf7`
- `#eb0130`

## Typography

Families: "Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif". Weights: 400, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Quicken

Design token description: The design system orbits a single electric violet (471cff) that acts as the power source for every interactive element against a clean white canvas. The visual personality is confident financial-tech — a custom geometric sans sets the voice with tight negative tracking that tightens further as type grows, creating density and authority without weight. Dark violet sections (0f0733) alternate with white bands to create rhythm, while soft lavender card borders (dbd3ff, bbc5fa) replace the usual gray dividers and reinforce brand identity at every edge. Components lean rounded and pill-shaped; cards use 16px corners, buttons stretch to a 400px radius, and shadows are nearly absent. Depth comes from color contrast and border treatment, not elevation.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system's design orbits a single electric violet ({colors.primary} — 471cff) that acts as the power source for every interactive element against a clean white canvas. The visual personality is confident and tech-forward: a custom geometric sans-serif font sets the voice with tight negative tracking that intensifies as type grows, creating density and authority without adding weight. Dark violet sections ({colors.canvas-dark} — 0f0733) alternate with white bands to create a strong visual rhythm. Soft, tinted borders ({colors.border-soft} — dbd3ff, {colors.border-medium} — bbc5fa) replace conventional gray dividers, reinforcing the brand identity at every edge. Components lean heavily into rounded and pill shapes: cards use a generous {rounded.md} (16px) radius, buttons are always full pills ({rounded.pill} — 400px), and shadows are nearly absent. Depth is achieved through color contrast and border treatments, not elevation. Key Characteristics: - Single accent color: {colors.primary} is the chromatic pulse, used for all primary CTAs, active states, and key links. - Binary theme: Pages alternate between {colors.canvas-light} and {colors.canvas-dark} bands, creating a rhythmic, hi...

Color tokens:
- primary: #471cff
- canvas-dark: #0f0733
- ink: #18181f
- body: #18181f
- body-on-dark: #ffffff
- muted: #494949
- muted-on-dark: #dbd3ff
- canvas-light: #ffffff
- surface-soft-light: #f0f5fa
- border-soft: #dbd3ff
- border-medium: #bbc5fa
- hairline: #eaecf7
- on-primary: #ffffff
- on-dark: #ffffff

Typography tokens:
- hero-display: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 60px, weight 600, line 1, tracking -2.7px
- display-lg: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 48px, weight 600, line 1, tracking -2.2px
- display-md: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 30px, weight 600, line 1.16, tracking -1px
- display-sm: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 26px, weight 600, line 1.2, tracking -0.9px
- title-lg: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 20px, weight 600, line 1.31, tracking -0.6px
- title-md: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 18px, weight 400, line 1.5, tracking -0.5px
- body-md: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 400, line 1.5, tracking -0.5px
- body-sm: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 14px, weight 400, line 1.4, tracking -0.4px
- caption: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 12px, weight 400, line 1.5, tracking -0.4px
- button: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 600, line 1, tracking -0.5px
- nav-link: family Haffer, ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 400, line 1, tracking -0.5px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 80px

Radius and shape tokens:
- sm: 8px
- md: 16px
- lg: 20px
- pill: 400px
- full: 400px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- button-secondary-ghost: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- hero-band-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.hero-display}, padding: 80px 0
- trust-badge: backgroundColor: {colors.accent-decorative}, textColor: {colors.ink}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 8px 16px
- pricing-card: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.title-lg}, rounded: {rounded.md}, padding: 24px
- promo-badge: backgroundColor: {colors.accent-promo}, textColor: {colors.on-primary}, typography: {typography.caption}, rounded: {rounded.lg}, padding: 4px 8px
- feature-card-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, rounded: {rounded.md}, padding: 0
- feature-comparison-table: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.body-md}

Color rationale: Brand & Accent - Primary Violet ({colors.primary} — 471cff): The single, electric brand color. Used for all primary CTA backgrounds, active navigation items, key links, and moments of brand emphasis. - Promo Red ({colors.accent-promo} — eb0130): A high-visibility red used sparingly for promotional accents, sale indicators, and urgency markers. - Error Coral ({colors.accent-error} — ff5a43): A warm coral used for error and warning badge fills. - Decorative Aqua ({colors.accent-decorative} — 7ae7fb): A cool cyan used for decorative badge backgrounds, particularly for trust-pills on dark sections. the source brand - Canvas Light ({colors.canvas-light} — ffffff): The default page floor, card backgrounds, and light-mode section canvas. - Canvas Dark ({colors.canvas-dark} — 0f0733): The deep, near-black violet for dark hero sections and alternating content bands. - the source brand Soft Light ({colors.surface-soft-light} — f0f5fa): A subtle, cool blue-tinted white used for muted the source brand tints, such as in header backgrounds or alternating light bands. Hairlines & Borders - Border Soft ({colors.border-soft} — dbd3ff): A warm, low-contrast lilac used for soft card and container bo...

Typography rationale: Font Family The system uses a single custom geometric sans-serif font, Haffer, for all typographic roles from display headlines to body copy. It is characterized by rounder apertures and tight terminals. The fallback stack is ui-sans-serif, system-ui, -apple-system, sans-serif. Hierarchy The typographic signature relies on a binary weight system and progressive negative letter-spacing. Headings and interactive elements use weight 600, while body and secondary text use weight 400. Letter-spacing becomes increasingly negative as font size increases, creating a dense, authoritative feel for display type. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 60px | 600 | 1.0 | -2.7px | Main hero headline on dark canvas | | {typography.display-lg} | 48px | 600 | 1.0 | -2.2px | Centered section headers | | {typography.display-md} | 30px | 600 | 1.16 | -1.0px | Large card headings | | {typography.display-sm} | 26px | 600 | 1.2 | -0.9px | Feature card headings | | {typography.title-lg} | 20px | 600 | 1.31 | -0.6px | Pricing plan names, subheadings | | {typography.title-md} | 18px | 400 | 1.5 | -0.5px | Hero subtitles, large...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section gap: {spacing.section} (80px) provides a consistent vertical rhythm between alternating dark and light content bands. - Card internal padding: {spacing.lg} (24px) is the standard for most content cards. - Element gap: {spacing.md} (16px) is used for spacing between elements within a component, such as a heading and its subsequent button. Grid & Container - Max content width: 1200px centered container with generous side padding. - Grid structure: Layouts favor simple 2- and 3-column grids for card-based content. The system does not use complex multi-column editorial layouts. - Alternating bands: The primary layout tactile material surface is the alternation of full-bleed {colors.canvas-dark} sections with {colors.canvas-light} sections, creating a clear and rhythmic page structure.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, hero bands, most cards | | Tinted Border | 1.5px solid {colors.border-soft} or {colors.border-medium} | Outlined cards ({component.pricing-card}), secondary buttons | | Soft Drop Shadow | rgba(0,0,0,0.15) 10px 20px 30px 0px | Exclusively on {component.pricing-card} to lift it off the white canvas | The system's elevation philosophy is overwhelmingly flat. Depth is primarily created through the stark contrast between light and dark color blocks. The tinted borders add a layer of visual separation without resorting to shadows. The single use of a drop shadow on pricing cards is a deliberate exception to draw attention to a key conversion area.

Shape language: Border Radius Scale The shape language is defined by soft, generous curves, with the pill shape being a non-negotiable signature for interactive elements. | Token | Value | Use | |---|---|---| | {rounded.sm} | 8px | Small decorative elements like icon tiles | | {rounded.md} | 16px | Standard for all content cards ({component.pricing-card}, {component.feature-card-dark}) | | {rounded.lg} | 20px | Small badges ({component.promo-badge}) | | {rounded.pill} | 400px | All buttons and active navigation indicators. This is a key brand signature. | | {rounded.full} | 400px | Reused token for pill shapes. | Iconography - Icons are typically rendered as white line art inside 32x32px {colors.primary} squares with an {rounded.sm} (8px) radius.

Component language: Buttons - button-primary: The main CTA. A {rounded.pill} shape with a {colors.primary} background and {colors.on-primary} text. This is the most important interactive element in the system. - button-secondary-ghost: The secondary action, often paired with the primary. It shares the same {rounded.pill} shape and {typography.button} style, but has a transparent background with a 1.5px {colors.primary} border and text. Cards & Containers - hero-band-dark: The top-of-page hero section. A full-bleed {colors.canvas-dark} band with the main headline in {typography.hero-display} and a subtitle in {colors.muted-on-dark}. - trust-badge: A small pill-shaped badge used for social proof, often appearing above a hero headline. Typically uses {colors.accent-decorative} for its background on dark surfaces. - pricing-card: A key conversion component. A {colors.canvas-light} card with {rounded.md} corners, a tinted {colors.border-medium} border, and the system's only drop shadow. It contains a plan name, price, feature...
```
