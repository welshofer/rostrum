# Cosmos

**ID:** `cosmos`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#1253ff`
- `#528fff`
- `#f1f607`
- `#232426`
- `#121214`
- `#000000`
- `#ffffff`
- `#a6a8ad`
- `#c8c9cc`
- `#63656d`

## Typography

Families: "'InterVariable', 'Inter', sans-serif", "'Soehne', 'Inter', sans-serif", "'SoehneBreit', 'Inter', sans-serif". Weights: 400, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Splice

Design token description: A dark, weightless interface designed as a midnight space, using deep charcoal canvases (121214) and near-borderless surfaces. A single electric blue (1253ff) accent cuts through the darkness on primary CTAs and links. Typography splits between a wide, whisper-weight display face for editorial headlines and a dense variable workhorse for UI, creating a contrast between performance and utility. Components stay flat — shadows are replaced by hairline inset strokes, and elevation is conveyed through color and border, not depth. Color is rationed to grayscale plus the single blue and a rare, saturated yellow-green (f1f607) for text punctuation.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system operates like a midnight creative space: deep charcoal canvases ({colors.canvas-dark} — 232426), near-borderless surfaces, and a single electric blue ({colors.primary} — 1253ff) accent that cuts through the darkness like a signal light. Typography is a core feature, splitting between a custom wide, whisper-weight display face (SoehneBreit) for editorial headlines and a dense variable workhorse (InterVariable) for all UI text. This creates a deliberate contrast between a spacious, atmospheric voice and a compact, functional one. Components are designed to feel flat and weightless. Cards sit on near-identical surface tones ({colors.surface-card-dark} — 121214), shadows are replaced by hairline inset strokes, and elevation is conveyed through media content itself, not interface chrome. Color is strictly rationed: one blue carries primary CTAs and interactive elements, a saturated yellow-green ({colors.accent-highlight} — f1f607) appears as rare text punctuation, and everything else recedes into a functional grayscale. The goal is a quiet, focused environment where the content is the only element that gets loud. Key Characteristics: - Rationed Color: A near-monochromatic gr...

Color tokens:
- primary: #1253ff
- accent: #528fff
- accent-highlight: #f1f607
- canvas-dark: #232426
- surface-card-dark: #121214
- surface-deep-dark: #000000
- body: #ffffff
- on-primary: #ffffff
- muted: #a6a8ad
- hairline: #c8c9cc
- border: #63656d
- border-strong: #45464d

Typography tokens:
- hero-display: family 'SoehneBreit', 'Inter', sans-serif, size 54px, weight 400, line 1.25, tracking -0.81px
- display-lg: family 'SoehneBreit', 'Inter', sans-serif, size 48px, weight 400, line 1.25, tracking -0.72px
- display-md: family 'SoehneBreit', 'Inter', sans-serif, size 36px, weight 400, line 1.25, tracking -0.54px
- display-sm: family 'SoehneBreit', 'Inter', sans-serif, size 28px, weight 400, line 1.25, tracking -0.42px
- title-lg: family 'Soehne', 'Inter', sans-serif, size 20px, weight 400, line 1.25, tracking -0.3px
- body-md: family 'InterVariable', 'Inter', sans-serif, size 16px, weight 400, line 1.5, tracking -0.24px
- body-sm: family 'InterVariable', 'Inter', sans-serif, size 14px, weight 400, line 1.43, tracking -0.21px
- caption: family 'InterVariable', 'Inter', sans-serif, size 12px, weight 400, line 1.2, tracking -0.18px
- button: family 'InterVariable', 'Inter', sans-serif, size 14px, weight 600, line 1, tracking -0.21px
- nav-link: family 'InterVariable', 'Inter', sans-serif, size 14px, weight 400, line 1.43, tracking -0.21px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 16px
- md: 20px
- lg: 32px
- xl: 48px
- xxl: 64px
- section: 80px
- section-lg: 120px

Radius and shape tokens:
- sm: 4px
- md: 8px
- pill: 60px
- full: 1440px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}, padding: 16px 20px
- button-ghost: backgroundColor: transparent, textColor: {colors.body}, borderColor: {colors.hairline}, borderWidth: 1px, typography: {typography.button}, rounded: {rounded.md}, padding: 8px 20px
- button-pill: backgroundColor: transparent, textColor: {colors.body}, rounded: {rounded.pill}, padding: 10px 20px
- text-link: backgroundColor: transparent, textColor: {colors.accent}, typography: {typography.body-sm}
- top-nav: backgroundColor: {colors.surface-deep-dark}, textColor: {colors.muted}, typography: {typography.nav-link}, height: 60px
- hero-band: backgroundColor: {colors.surface-deep-dark}, textColor: {colors.body}, typography: {typography.hero-display}
- content-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.body}, rounded: {rounded.sm}, padding: 24px
- text-input: backgroundColor: {colors.surface-card-dark}, textColor: {colors.body}, rounded: {rounded.sm}, padding: 14px 16px

Color rationale: Brand & Accent - Button Blue ({colors.primary} — 1253ff): The primary action color, used exclusively for filled button backgrounds. It's a deeper, more saturated blue intended to ground interactive elements. - Signal Blue ({colors.accent} — 528fff): A lighter, more electric blue used for inline links, focus states, and the top promotional banner. It serves as the system's primary non-grayscale signal. - Voltage Yellow ({colors.accent-highlight} — f1f607): A rare text accent for highlighting punctuation or featured labels. Used very sparingly for emphasis against the dark canvas; never for backgrounds. Surface - Obsidian ({colors.surface-deep-dark} — 000000): The deepest dark, used for the main navigation bar and footer to create a solid frame at the top and bottom of the viewport. - Carbon ({colors.surface-card-dark} — 121214): The primary surface for interactive components like cards and input fields. It's the dominant working surface color. - Graphite ({colors.canvas-dark} — 232426): The main page canvas background. It sits one step lighter than Carbon, used when a surface needs to feel distinct from a card without using a border or shadow. Text - Body ({colors.body} — ffffff):...

Typography rationale: Font Family The system employs a deliberate typographic split to distinguish between editorial and functional contexts: - SoehneBreit / Soehne: A custom, wide geometric sans-serif used for all display headlines and subheadings. It is always set at a light weight (400) to create an atmospheric, whisper-quiet voice. It is never bolded. - InterVariable: A variable workhorse font used for all UI text: body copy, navigation, buttons, inputs, cards, and captions. It is prized for its legibility and compact rhythm, enhanced by a universal negative letter-spacing. If custom fonts are unavailable, Inter can serve as a substitute for both, with display sizes receiving a slight increase in width and tracking to mimic SoehneBreit. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 54px | 400 | 1.25 | -0.81px | Hero section headlines (SoehneBreit) | | {typography.display-lg} | 48px | 400 | 1.25 | -0.72px | Large section headlines (SoehneBreit) | | {typography.display-md} | 36px | 400 | 1.25 | -0.54px | Standard section headlines (SoehneBreit) | | {typography.display-sm} | 28px | 400 | 1.25 | -0.42px | Card titles, sm...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 20px · {spacing.lg} 32px · {spacing.xl} 48px · {spacing.xxl} 64px. - Section padding (vertical): {spacing.section} (80px) is the standard gap between major content blocks, creating a spacious, comfortable rhythm. The largest gap is {spacing.section-lg} (120px). - Card internal padding: Varies between {spacing.md} (20px) and {spacing.lg} (32px). - Gutters: Gaps between elements are typically {spacing.xs} (8px) or {spacing.sm} (16px). Grid & Container The layout is intentionally unconstrained and full-bleed. The navigation, hero, and footer all span the full viewport width. There is no rigid max-width container for body content; instead, content blocks are centered or left-aligned with generous margins, creating a more editorial, free-form feel than a strict columnar grid would allow. Whitespace Philosophy The system uses generous whitespace to maintain its clean, uncluttered aesthetic. The 80px section gap is fundamental to the pacing of long-scroll pages, allowing each content block—especially those containing large media—to breathe. The density is comfortable, not sp...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body canvas, full-bleed media containers | | Hairline Border | 1px {colors.hairline} or {colors.border-strong} | Cards, inputs, ghost buttons. Provides separation without creating depth. | | Inset Stroke | rgba(0, 0, 0, 0.07) 0px 0px 0px 1px inset | The system's only "shadow," used to create subtle internal separation on dark surfaces. | | Focus State | 1px border in {colors.accent} | Input focus state; the border color shifts to Signal Blue. | The elevation philosophy is intentionally flat. The system actively avoids drop shadows to maintain a weightless, two-dimensional feel. Depth is implied through the careful layering of flat, colored surfaces and the use of 1px borders or inset strokes. The primary driver of visual hierarchy and "elevation" is not interface chrome but the content itself, typically large-scale, atmospheric photography.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 4px | Content cards, images, input fields. The default, subtle corner rounding. | | {rounded.md} | 8px | Standard primary and secondary buttons. | | {rounded.pill} | 60px | Pill-shaped buttons used for tags, filters, and small utility actions. | | {rounded.full} | 1440px | Used on nested elements within the navigation bar to create a fully-rounded pill shape. | The radius scale is minimal and functional. Small radii maintain a clean, modern feel, while the pill shape is reserved for specific, small-scale interactive elements where a softer, more organic shape is desired.

Component language: Top Navigation top-nav — A 60px tall navigation bar with a solid {colors.surface-deep-dark} background, sticky to the top of the viewport. It contains a left-aligned wordmark, a centered group of navigation links in {colors.muted}, and right-aligned utility actions. Buttons button-primary — The main call-to-action. It uses a solid {colors.primary} background with {colors.on-primary} text. Styled with {typography.button}, {rounded.md} (8px), and generous padding (16px 20px). It is the most visually dominant interactive element. button-ghost — The secondary action button. It features a transparent background with a 1px {colors.hairline} border and {colors.body} text. It's designed to be less prominent than the primary button. button-pill — A small, pill-shaped button with a {rounded.pill} radius. Used for tag-like actions, filters, or interactive chips. text-link — Standard inline text links are colored with {colors.accent} and have no underline by default, gaining one on hover. Cards & Containers content-card — The standard container for grouped content. It uses a {colors.surface-card-dark} background, a subtle {rounded.sm} radius, and a 1px {colors.border-strong} hairline border....

Guardrails: Do - Use {colors.primary} and {colors.accent} for all interactive elements and links. They are the system's only chromatic signals. - Apply the universal negative letter-spacing to all text to maintain t...
```
