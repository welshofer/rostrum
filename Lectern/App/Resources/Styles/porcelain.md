# Porcelain

**ID:** `porcelain`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#0066cc`
- `#101820`
- `#ffffff`
- `#e6e0f8`
- `#d6d6d6`
- `#f4f1ea`
- `#0e2575`
- `#213680`
- `#e9f4ff`
- `#f7e1d5`

## Typography

Families: "'Maison Neue', -apple-system, BlinkMacSystemFont, sans-serif", "'Maison Neue', sans-serif", "'Spoof', 'Maison Neue', sans-serif". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: MetaMusic

Design token description: An editorial system anchored on a warm paper-cream canvas (f4f1ea), where oversized, tightly-tracked display type and a single vivid blue accent (0066cc) define the visual hierarchy. A deep indigo (0e2575) serves as a contrasting panel for dark-themed sections. The system's most distinct feature is a hard, sticker-flat solid black offset shadow applied to all interactive controls, giving them a tactile, printed feel instead of soft digital elevation. The UI relies almost entirely on a single neo-grotesque typeface, with a secondary font reserved for a single accent role. Layouts are spacious and structured, with large-radius cards and generous internal padding reinforcing the clean, broadsheet aesthetic.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This system evokes a clean, editorial, "printed broadsheet" feel. The primary canvas is a warm paper cream ({colors.canvas-light} — f4f1ea), creating a soft, approachable base. The hierarchy is driven by oversized display typography (up to 120px) that is aggressively tightened with negative letter-spacing, giving headlines a monumental, block-like presence. A single, vivid brand blue ({colors.primary} — 0066cc) carries all interactive states — primary CTAs, links, and accents. For contrast, full-bleed sections use a deep indigo ({colors.canvas-dark} — 0e2575) as a dark-mode-like canvas. The system's most defining feature is its elevation model: a hard, 4px solid black offset shadow with zero blur. This "sticker-flat" treatment is applied exclusively to interactive controls like buttons, giving them a tactile, cut-out-paper feel that deliberately avoids digital softness. Layouts are spacious and structured, using a simple 8px-based spacing scale, large-radius cards, and generous internal padding to maintain a comfortable, uncluttered reading experience. Key Characteristics: - Single accent color: {colors.primary} (0066cc) is the only chromatic voice, used for all primary actions, l...

Color tokens:
- primary: #0066cc
- ink: #101820
- body: #101820
- body-on-dark: #ffffff
- muted: #e6e0f8
- hairline: #d6d6d6
- canvas-light: #f4f1ea
- canvas-dark: #0e2575
- surface-card-light: #ffffff
- surface-card-dark: #213680
- surface-wash-light: #e9f4ff
- surface-wash-warm: #f7e1d5
- on-primary: #ffffff
- on-dark: #ffffff

Typography tokens:
- display-lg: family 'Maison Neue', -apple-system, BlinkMacSystemFont, sans-serif, size 120px, weight 600, line 0.95, tracking -3.6px
- display: family 'Maison Neue', sans-serif, size 80px, weight 600, line 1.05, tracking -1.6px
- display-sm: family 'Maison Neue', sans-serif, size 56px, weight 600, line 1.05, tracking -1.12px
- heading-lg: family 'Maison Neue', sans-serif, size 40px, weight 600, line 1.1, tracking -0.4px
- heading: family 'Maison Neue', sans-serif, size 32px, weight 600, line 1.2, tracking -0.32px
- heading-sm: family 'Maison Neue', sans-serif, size 22px, weight 600, line 1.2, tracking -0.2px
- heading-accent: family 'Spoof', 'Maison Neue', sans-serif, size 22px, weight 500, line 0.9, tracking -0.44px
- subheading: family 'Maison Neue', sans-serif, size 19px, weight 500, line 1.4, tracking 0
- eyebrow: family 'Maison Neue', sans-serif, size 16px, weight 500, line 1.4, tracking 0
- body-md: family 'Maison Neue', sans-serif, size 16px, weight 400, line 1.4, tracking 0
- body-sm: family 'Maison Neue', sans-serif, size 14px, weight 400, line 1.5, tracking 0
- caption: family 'Maison Neue', sans-serif, size 12px, weight 400, line 1.5, tracking 0

Spacing tokens:
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 32px
- lg: 40px
- xl: 48px
- xxl: 80px
- section: 80px

Radius and shape tokens:
- md: 8px
- xl: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 24px
- button-secondary-outline: backgroundColor: {colors.surface-card-light}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- button-icon-circular: backgroundColor: {colors.ink}, textColor: {colors.on-primary}, rounded: {rounded.pill}, height: 40px, width: 40px
- card-on-dark: backgroundColor: {colors.surface-card-dark}, textColor: {colors.on-dark}, typography: {typography.body-md}, rounded: {rounded.xl}, padding: {spacing.lg}
- card-on-light: backgroundColor: {colors.surface-card-light}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.xl}, padding: {spacing.lg}
- text-input: backgroundColor: {colors.surface-card-light}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.md}, padding: 16px
- notification-banner: backgroundColor: {colors.muted}, textColor: {colors.ink}, typography: {typography.caption}, padding: 8px
- icon-circle-container: backgroundColor: {colors.surface-wash-warm}, rounded: {rounded.pill}, height: 48px, width: 48px

Color rationale: Brand & Accent - Primary ({colors.primary} — 0066cc): The single, vivid blue accent. Used for primary CTA backgrounds, link underlines, heading accents, and icon fills. It is the functional and decorative workhorse. Surface The system uses a warm-to-cool stacking of surfaces. - Canvas Light ({colors.canvas-light} — f4f1ea): The primary page floor. A warm, paper-like cream that sets the editorial tone. - Surface Card Light ({colors.surface-card-light} — ffffff): The standard surface for cards, navigation, and inputs, sitting atop the cream canvas. - Canvas Dark ({colors.canvas-dark} — 0e2575): A deep, saturated indigo used for full-bleed feature sections to create high-contrast moments. - Surface Card Dark ({colors.surface-card-dark} — 213680): An elevated card surface used only on {colors.canvas-dark} panels, providing separation without shadows. - Surface Wash Light ({colors.surface-wash-light} — e9f4ff): A subtle ice-blue wash for alternate light card backgrounds. - Surface Wash Warm ({colors.surface-wash-warm} — f7e1d5): A warm peach used exclusively as a background color for decorative icon circles. Text - Ink ({colors.ink} — 101820): The primary text color on light surfaces....

Typography rationale: Font Family The system relies on a primary workhorse font, Maison Neue, for nearly all UI roles. It provides a clean, neo-grotesque feel with humanist warmth. A secondary accent font, Spoof, is reserved for a single heading role ({typography.heading-accent}) to act as a typographic exclamation point, not a general-use face. The fallback stack is a standard system sans-serif. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 120px | 600 | 0.95 | -3.6px | Main hero headline | | {typography.display} | 80px | 600 | 1.05 | -1.6px | Secondary hero headline | | {typography.display-sm} | 56px | 600 | 1.05 | -1.12px | Section headings | | {typography.heading-lg} | 40px | 600 | 1.1 | -0.4px | Large card titles | | {typography.heading} | 32px | 600 | 1.2 | -0.32px | Sub-section titles | | {typography.heading-sm} | 22px | 600 | 1.2 | -0.2px | Standard card titles | | {typography.heading-accent} | 22px | 500 | 0.9 | -0.44px | Special accent labels (Spoof) | | {typography.subheading} | 19px | 500 | 1.4 | 0 | Minor headings, large labels | | {typography.eyebrow} | 16px | 500 | 1.4 | 0 | Pre-title labels in {colors.prima...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 32px · {spacing.lg} 40px · {spacing.xl} 48px · {spacing.xxl} 80px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) is the standard gap between major content bands. Separation is achieved through this whitespace and surface color changes, not dividers. - Card internal padding: {spacing.lg} (40px) is used consistently inside all content cards, creating a generous internal margin. - Gutters: {spacing.sm} (24px) is the typical gap between elements like cards in a grid. Grid & Container - Max content width: 1280px, centered. This creates generous outer gutters on wider viewports, reinforcing the focused, editorial feel. - Layouts: Pages use simple structures like 2-column splits (e.g., heading on left, card stack on right) or 3-4 column card grids. The emphasis is on clarity and breathing room. Whitespace Philosophy The system is intentionally spacious and uncluttered. It uses generous, consistent whitespace as a primary design element. The combination of {spacing.section} between bands and {spacing.lg} inside cards establishes a calm, comf...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, content cards, image areas, icons | | Hairline | 1px {colors.hairline} | Top navigation bottom border, subtle dividers | | Interactive Border | 1px {colors.muted} or {colors.primary} | Default and focused text inputs | | Sticker Shadow | 0 4px 0 0 000000 | Applied ONLY to interactive controls: primary buttons, secondary buttons, nav items | The elevation philosophy is unique: flat surfaces with tactile, interactive lifts. Standard content cards ({component.card-on-light}) are completely flat, separating from the canvas by color alone. Depth is introduced only on clickable elements like buttons via a hard, solid black, 4px downward-offset shadow. This zero-blur shadow creates a sticker-like, cut-out-paper effect that is graphic and intentional, completely avoiding soft, realistic drop shadows.

Shape language: Border Radius Scale The system uses a strict, three-tier radius scale to define its shapes. | Token | Value | Use | |---|---|---| | {rounded.md} | 8px | Text inputs and form fields. | | {rounded.xl} | 24px | All content cards ({component.card-on-light}, {component.card-on-dark}). | | {rounded.pill} | 9999px | All buttons ({component.button-primary}, {component.button-secondary-outline}) and small badges. | This strict separation is key: cards are always generously rounded, buttons are always pills, and inputs are always subtly rounded. Mixing these roles (e.g., a pill-shaped card) is not permitted. Iconography Decorative icons are rendered as simple, monoweight line art in {colors.primary}. They are typically housed within a circular container ({component.icon-circle-container}) filled with {colors.surface-wash-warm}. This treatment keeps icons feeling like editorial spot illustrations rather than functional UI controls.

Component language: Buttons button-primary — The main call to action. A pill-shaped button with a {colors.primary} background and {colors.on-primary} text. It always features the system's signature hard offset "sticker shadow". button-secondary-outline — Used for secondary actions, like a log-in control in the header. It's a pill with a {colors.surface-card-light} background, {colors.ink} text, and a 1px solid black border. It also receives the hard offset shadow. button-icon-circular — A small, 40x40px circular button with an {colors.ink} background and {colors.on-primary} icon. Used for card-level actions, like a "continue" arrow, without a text label. It does not have the offset shadow. Cards & Containers card-on-light — The standard content card, used on the {colors.canvas-light} background. It has a {colors.surface-car...
```
