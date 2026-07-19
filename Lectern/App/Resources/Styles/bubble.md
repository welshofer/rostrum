# Bubble

**ID:** `bubble`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Playful

## Color palette

- `#0e76fd`
- `#3898ff`
- `#7a70ff`
- `#38228f`
- `#ff5ca0`
- `#fa423c`
- `#ff801f`
- `#1db847`
- `#000000`
- `#1b1c1e`

## Typography

Families: "'SFMono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace", "'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: RainbowKit

Design token description: A developer-native dark UI anchored on a true-black void, where floating obsidian cards create a sense of depth. The visual language is defined by friendly, pill-shaped elements (9999px radius), a single signal-blue action color (0e76fd), and a vibrant blue-to-violet aurora gradient reserved for primary brand moments. Typography uses a soft, rounded sans-serif with generous positive letter-spacing to make technical content feel approachable. A signature 1px inset white border gives interactive elements a subtle, glass-like edge highlight, defining them against the dark surfaces.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a developer-native dark UI anchored on a true-black void ({colors.canvas} — 000000), where floating obsidian cards ({colors.surface-card} — 1b1c1e) create a sense of depth using heavy drop shadows. The visual language is defined by approachable, pill-shaped elements ({rounded.pill} — 9999px), a single signal-blue action color ({colors.primary} — 0e76fd), and a vibrant blue-to-violet aurora gradient reserved for primary brand moments. The system aims to bridge developer-tool severity with consumer-app friendliness. Typography uses a soft, rounded sans-serif with generous positive letter-spacing at all sizes. This gives headlines a roomy, open rhythm, making technical content feel less intimidating. Color is used surgically: {colors.primary} for all standard actions, the aurora gradient for the single hero CTA, and pure white text against layered grays for hierarchy. A signature 1px inset white border is applied to buttons and cards, giving interactive elements a subtle, glass-like edge highlight that defines them against the dark surfaces. Key Characteristics: - Void Canvas: The page background is true black ({colors.canvas}), creating a deep, focused environment. - Floatin...

Color tokens:
- primary: #0e76fd
- aurora-start: #3898ff
- aurora-end: #7a70ff
- accent-deep: #38228f
- accent-demo-pink: #ff5ca0
- accent-demo-red: #fa423c
- accent-demo-orange: #ff801f
- accent-demo-green: #1db847
- canvas: #000000
- surface-card: #1b1c1e
- shadow-tint: #121314
- hairline: #25292e
- border-muted: #2f3334
- surface-disabled: #646566

Typography tokens:
- display: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 52px, weight 700, line 1, tracking 1.3px
- heading-lg: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 40px, weight 700, line 1.05, tracking 0.88px
- heading: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 24px, weight 600, line 1.17, tracking 0.43px
- heading-sm: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 20px, weight 600, line 1.2, tracking 0.3px
- subheading: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 18px, weight 500, line 1.33, tracking 0.31px
- body-md: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 400, line 1.25, tracking 0.27px
- body-sm: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 14px, weight 400, line 1.29, tracking 0.35px
- button: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 500, line 1, tracking 0.27px
- caption: family 'SFRounded', ui-sans-serif, system-ui, -apple-system, sans-serif, size 11px, weight 400, line 1.31, tracking 0.35px
- code: family 'SFMono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace, size 14px, weight 400, line 1, tracking 0.025em

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
- sm: 12px
- lg: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-gradient: backgroundColor: linear-gradient(to right, {colors.aurora-start}, {colors.aurora-end}), textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- button-primary-solid: backgroundColor: {colors.primary}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 6px 16px
- code-block: backgroundColor: {colors.surface-card}, textColor: {colors.on-dark}, typography: {typography.code}, rounded: {rounded.sm}, padding: 12px 18px
- modal-card: backgroundColor: {colors.surface-card}, textColor: {colors.on-dark}, typography: {typography.body-md}, rounded: {rounded.lg}, padding: {spacing.lg}
- modal-list-item: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.body-md}, padding: 12px 16px
- info-card: backgroundColor: {colors.surface-card}, textColor: {colors.on-dark}, typography: {typography.body-sm}, rounded: {rounded.lg}, padding: {spacing.lg}
- version-badge: backgroundColor: {colors.surface-disabled}, textColor: {colors.on-dark}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 1px 5px
- partner-logo-frame: backgroundColor: transparent, textColor: {colors.on-dark}, rounded: {rounded.pill}

Color rationale: Brand & Accent - Signal Blue ({colors.primary} — 0e76fd): The primary action color for solid-fill buttons, links, and active states. The only chromatic blue used for standard UI components. - Aurora Gradient ({colors.aurora-start} to {colors.aurora-end}): A linear gradient from sky blue (3898ff) to electric violet (7a70ff). Reserved exclusively for the hero CTA and primary display headings to give them premium emphasis. - Deep Accent ({colors.accent-deep} — 38228f): A dark violet wash used for highlight backgrounds and decorative surfaces, often in conjunction with the aurora gradient. Demo Accents These colors are present for demonstration purposes (e.g., in a settings showcase) but are not used for semantic UI states like success, error, or warning. - Demo Pink ({colors.accent-demo-pink} — ff5ca0) - Demo Red ({colors.accent-demo-red} — fa423c) - Demo Orange ({colors.accent-demo-orange} — ff801f) - Demo Green ({colors.accent-demo-green} — 1db847) Surface - Canvas ({colors.canvas} — 000000): The true-black page floor. The system's foundation. - Surface Card ({colors.surface-card} — 1b1c1e): The standard background for all elevated cards, modals, and code blocks. - Surface Disabled...

Typography rationale: Font Family The system uses a single rounded sans-serif typeface, SFRounded, for all UI text from captions to display headlines. Its soft terminals are chosen to make technical content feel approachable. For code snippets, a monospace font, SFMono, is used. - SFRounded substitute: Nunito, Inter (rounded variant) - SFMono substitute: JetBrains Mono, Fira Code Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display} | 52px | 700 | 1 | 1.3px | Primary hero headlines | | {typography.heading-lg} | 40px | 700 | 1.05 | 0.88px | Large hero titles with gradient fill | | {typography.heading} | 24px | 600 | 1.17 | 0.43px | Section titles | | {typography.heading-sm} | 20px | 600 | 1.2 | 0.3px | Card and modal titles | | {typography.subheading} | 18px | 500 | 1.33 | 0.31px | Sub-section titles | | {typography.body-md} | 16px | 400 | 1.25 | 0.27px | Default running text | | {typography.body-sm} | 14px | 400 | 1.29 | 0.35px | Secondary body copy | | {typography.button} | 16px | 500 | 1 | 0.27px | All button labels | | {typography.caption} | 11px | 400 | 1.31 | 0.35px | Small metadata, version badges | | {typography.code} | 14px | 4...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) is used between major content bands, allowing the black canvas to provide ample breathing room. - Card internal padding: {spacing.lg} (24px) is standard for modal and info cards. - Element gap: {spacing.sm} (12px) is used for spacing between elements inside a component. Grid & Container - Max content width: ~1200px, with all content centered. - Editorial body: Content is typically arranged in a single-column stack, with occasional 2-column layouts for side-by-side product showcases. - Logo grid: A 6-column grid is used to display partner or integration logos. Whitespace Philosophy The system uses generous whitespace to create focus. The true-black canvas is a key part of the design, and large {spacing.section} gaps between content blocks allow it to frame the floating cards. The layout is intentionally minimal and centered, directing all attention to the product components being showcased.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The {colors.canvas} page background | | Inset Highlight | rgba(255, 255, 255, 0.12) 0px 0px 0px 1px inset | The signature lit-edge on all buttons and cards | | Card surface | {colors.surface-card} with heavy drop shadow | Modals, code blocks, info cards. The primary elevated surface. | | Heavy Drop Shadow | rgba(0, 0, 0, 0.4) 0px 8px 24px 0px | Applied to all floating cards to create significant depth | | Focus ring | 0 0 0 4px {colors.focus-ring} | Keyboard focus state on interactive elements | The elevation philosophy is based on dramatic depth. Instead of subtle layering, cards are lifted far off the canvas with strong, diffuse shadows. The inset highlight provides a countervailing sense of definition, making the edges feel crisp and glass-like despite the soft shadow behind them.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 12px | Code blocks, inputs, small icon containers | | {rounded.lg} | 24px | Main content cards, modals | | {rounded.pill} | 9999px | All buttons, tags, badges, and circular frames | | {rounded.full} | 9999px / 50% | Circular logo frames | The shape language is dominated by {rounded.pill}. This consistent, soft geometry is a primary contributor to the system's friendly and approachable feel. Even large cards use a generous {rounded.lg} (24px) radius. Iconography & Imagery - Content is product-centric. The main visuals are screenshots of the UI itself, presented in floating cards. - Icon frames and logo containers are circular, using {rounded.full}. - There is no photography, illustration, or abstract graphical content. The aesthetic is clean, focused, and tool-like.

Component language: Buttons button-primary-gradient — The main hero CTA. This is a pill-shaped button filled with the aurora linear-gradient(to right, {colors.aurora-start}, {colors.aurora-end}). It features {colors.on-dark} text, {typography.button} styling, and the signature inset white highlight border. It is reserved for the most prominent action on a page. button-primary-solid — The standard action button. A compact pill with a solid {colors.primary} background and {colors.on-dark} text. Used for all secondary CTAs and persistent actions, such as in a navigation bar. Cards & Containers modal-card — The core component surface. A floating card with a {colors.surface-card} background, {rounded.lg} radius, and a heavy drop shadow. It contains a title in {typography.heading-sm} and body content. modal-list-item — A selectable row inside a modal. Transparen...
```
