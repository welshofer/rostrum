# Orbit

**ID:** `orbit`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#408fed`
- `#3e1bc9`
- `#0a0a0a`
- `#ffffff`
- `#262626`
- `#737373`
- `#e4e7eb`
- `#484b73`
- `#0f0f35`
- `#15163d`

## Typography

Families: "Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Circle

Design token description: An aurora-lit mission control interface set on a deep, near-black indigo canvas (0f0f35) that glows from the center outward. A single, crisp white product panel (ffffff) floats on this darkness, creating a high-contrast binary between the theatrical, gradient-lit marketing the source brand and the information-dense product the source brand. The entire system is built on a single font family, with display sizes using aggressive negative tracking for a dense, architectural feel. Pill shapes (9999px) define all interactive elements, from gradient-filled primary CTAs to pastel-tinted accent cards (ffe0e2, f2dbf5) that add soft color to the cosmic void.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system's design is a deep-space stage: a near-black indigo canvas ({colors.canvas-dark} — 0f0f35) radiates soft aurora gradients toward the center, and a single bright product panel floats on that darkness like a window into daylight. The product the source brand inside is crisp white and information-dense, while the marketing the source brand around it is theatrical. Primary CTAs use a vivid blue-to-violet gradient, interactive elements are universally pill-shaped ({rounded.pill}), and pastel-tinted accent cards ({colors.surface-accent-rose}, {colors.surface-accent-lavender}) feel like soft constellation markers. Typography is a single family, Inter, pushed from whisper-tight tracking at display sizes ({typography.display-lg} at -3.2px) down to relaxed spacing on small captions. This gives headlines a dense, confident weight that fills the dark space. The visual rhythm alternates between the cosmic dark page and floating white product panels; this high contrast — not color variety — is the system's signature. Key Characteristics: - Binary contrast: Dark marketing canvas ({colors.canvas-dark}) vs. bright white product panels ({colors.canvas-light}). Separation is achieved thro...

Color tokens:
- primary-gradient-start: #408fed
- primary-gradient-end: #3e1bc9
- ink: #0a0a0a
- on-dark: #ffffff
- body-on-light: #262626
- muted: #737373
- hairline: #e4e7eb
- border-on-dark: #484b73
- canvas-dark: #0f0f35
- canvas-dark-outer: #15163d
- canvas-light: #ffffff
- surface-dark-inset: #191b1f
- surface-accent-rose: #ffe0e2
- surface-accent-lavender: #f2dbf5

Typography tokens:
- display-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 64px, weight 700, line 1.1, tracking -3.2px
- display: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 56px, weight 700, line 1.1, tracking -2.63px
- heading-xl: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 600, line 1.25, tracking -1.24px
- heading-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 600, line 1.3, tracking -0.9px
- heading-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 600, line 1.33, tracking -0.6px
- heading-sm: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 600, line 1.4, tracking -0.46px
- subheading: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 500, line 1.45, tracking -0.38px
- body-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 500, line 1.5, tracking -0.29px
- body-sm: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 500, line 1.5, tracking -0.22px
- caption: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 10px, weight 500, line 1.5, tracking 0.5px
- button: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 600, line 1, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 80px
- section-lg: 120px

Radius and shape tokens:
- lg: 20px
- xl: 24px
- xxl: 32px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-gradient: backgroundColor: linear-gradient(142deg, {colors.primary-gradient-start}, {colors.primary-gradient-end}), textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 14px 24px
- button-secondary-outline: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-sm}, rounded: {rounded.pill}, padding: 8px 18px, border: 1px solid {colors.hairline}
- button-tertiary-pastel: backgroundColor: {colors.surface-accent-lavender}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.pill}, padding: 12px 20px
- text-input-pill-on-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.pill}, height: 48px, padding: 12px 24px
- accent-card-pastel: backgroundColor: {colors.surface-accent-rose}, textColor: {colors.ink}, typography: {typography.heading-sm}, rounded: {rounded.xl}, padding: {spacing.lg}
- content-panel-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, rounded: {rounded.xl}, border: 1px solid {colors.hairline}
- media-card-dark: backgroundColor: {colors.accent-purple-deep}, textColor: {colors.on-dark}, typography: {typography.heading-md}, rounded: {rounded.xl}, padding: {spacing.lg}
- top-nav-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.body-md}, height: 64px

Color rationale: Brand & Accent - Primary Gradient ({colors.primary-gradient-start} → {colors.primary-gradient-end}): A linear gradient from a bright blue (408fed) to a deep violet (3e1bc9). This is reserved exclusively for the primary CTA button background. - Accent Blue ({colors.accent-blue} — 3655e5): A vivid blue-violet used for solid accent surfaces and card backgrounds in feature blocks. - Accent Purple Deep ({colors.accent-purple-deep} — 5a3f99): A deep purple background fill for media cards and feature panels, anchoring darker sections of the page. Pastel Accents A family of soft, muted colors used for {component.accent-card-pastel} backgrounds and secondary ghost buttons. - Accent Rose ({colors.surface-accent-rose} — ffe0e2) - Accent Lavender ({colors.surface-accent-lavender} — f2dbf5) - Accent Yellow ({colors.surface-accent-yellow} — fff0d8) - Accent Blue ({colors.surface-accent-blue} — e0eafc) - Accent Mint ({colors.surface-accent-mint} — e4f6f4) the source brand The system is built on a strict binary of dark and light surfaces. - Canvas Dark ({colors.canvas-dark} — 0f0f35): The primary page floor for all marketing surfaces. This is the base color for the atmospheric aurora gradient. -...

Typography rationale: Font Family The system uses a single font family, Inter, for all typographic roles. Its character is defined by weight and, most importantly, aggressive negative letter-spacing at large sizes. This creates dense, architectural headlines that contrast with the airy, spacious page layout. The fallback stack is -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 64px | 700 | 1.1 | -3.2px | Rare, hero-level headlines for maximum impact | | {typography.display} | 56px | 700 | 1.1 | -2.63px | Primary hero headlines | | {typography.heading-xl} | 40px | 600 | 1.25 | -1.24px | Major section titles | | {typography.heading-lg} | 32px | 600 | 1.3 | -0.9px | Sub-section titles | | {typography.heading-md} | 24px | 600 | 1.33 | -0.6px | Card titles, feature headlines | | {typography.heading-sm} | 20px | 600 | 1.4 | -0.46px | Smaller card titles | | {typography.subheading} | 18px | 500 | 1.45 | -0.38px | Body lead-in paragraphs | | {typography.body-md} | 16px | 500 | 1.5 | -0.29px | Default running text | | {typography.body-sm} | 14px | 500 | 1.5 | -0.22px...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px · {spacing.section-lg} 120px. - Section padding (vertical): Very generous, typically {spacing.section} (80px) to {spacing.section-lg} (120px). The system trusts whitespace to create a calm, focused rhythm. - Card internal padding: {spacing.lg} (24px) is the standard for most content and accent cards. - Gutters: {spacing.xl} (32px) or more between elements in a row, like tabs or cards. Grid & Container - Max content width: ~1200px, centered on a full-bleed dark canvas. - Editorial body: The layout alternates between single-column centered content (for heroes) and two-column layouts (for feature sections, typically media on one side and text on the other). Card grids are rare. - Whitespace Philosophy: The system is comfortable and spacious. It reads like a series of "windows" opening onto the product from a dark stage, with generous gaps between each window. Density is intentionally low to maintain focus and a theatrical feel.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, canvas, accent cards, all buttons | | Hairline | 1px {colors.hairline} border | Secondary outline buttons, product panel definition | | Product Panel | Whisper-soft drop shadow (0px 4px 8px 0px rgba(169, 169, 169, 0.08)) | The only element that receives a shadow, used to lift the white {component.content-panel-light} off the dark canvas | | Focus ring | 0 0 0 2px {colors.info-ring} | Input + button keyboard focus state | The elevation model is extremely restrained. Depth is primarily communicated through the high contrast between the dark canvas and the floating white product panels. The single, subtle drop shadow reinforces this "floating window" effect but is never used on other components.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.lg} | 20px | Small cards, media thumbnails | | {rounded.xl} | 24px | Standard content cards, accent cards | | {rounded.xxl} | 32px | Large panels and containers | | {rounded.pill} | 9999px | THE default for all interactive elements: buttons, inputs, tabs | | {rounded.full} | 9999px / 50% | Avatars, decorative circular elements | The system's geometry is defined by the pill. Any interactive element—a button to click, a field to type in, a tab to select—is rendered as a pill. Larger, static containers use generous corner radii from {rounded.lg} to {rounded.xxl}, maintaining a soft, modern feel. There are no sharp corners.

Component language: Buttons button-primary-gradient — The signature primary CTA. Background is a linear gradient from {colors.primary-gradient-start} to {colors.primary-gradient-end}. Text is {colors.on-dark}, shape is {rounded.pill}, and typography is {typography.button}. It has no border or shadow; the gradient provides all the visual affordance. button-secondary-outline — Used for secondary actions, typically in the top navigation. Transparent background with a 1px {colors.hairline} border. Text is {colors.ink} on light surfaces. Shape is {rounded.pill}. button-tertiary-pastel — A softer secondary action. Background is one of the pastel accent colors (e.g., {colors.surface-accent-lavender}). Text is {colors.ink}, and shape is...
```
