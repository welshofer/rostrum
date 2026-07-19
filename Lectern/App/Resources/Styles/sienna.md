# Sienna

**ID:** `sienna`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#ff2f00`
- `#000000`
- `#666666`
- `#fafafa`
- `#ededed`
- `#ffb700`
- `#bfe0ff`

## Typography

Families: "'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif", "'Neue Montreal', sans-serif". Weights: 400, 500, 530, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Pangram Pangram Foundry

Design token description: A curatorial, gallery-style interface on a bare stone canvas, where typography is the primary visual element. The system uses a near-pure grayscale palette on a warm off-white (fafafa) canvas, with hairline black (000000) borders defining every surface. A single, saturated orange-red (ff2f00) acts as a hot accent for status badges and selected states — a curator's label. Type runs a single, confident sans-serif at all sizes, from 12px captions to massive 145px display overlays. Shapes are soft and uniform, with a consistent 20px radius on cards and buttons, reserving a full pill shape for small status badges. The system avoids all elevation and shadow, creating a flat, print-catalogue aesthetic.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is an editorial, type-forward design system that presents content as if in a museum vitrine. The canvas is a warm, bare stone ({colors.canvas-light} — fafafa), with lighting that feels like flat daylight. The structure is defined by ubiquitous 1px hairline black borders ({colors.hairline-on-light} — 000000), which give every card and input a crisp, drafted quality. The palette is almost entirely grayscale, relying on the contrast between {colors.ink} text and {colors.canvas-light} surfaces. The only vivid color is a single, saturated orange-red ({colors.primary} — ff2f00), used sparingly for status badges and selected states, like a curator's label flagging what is new or important. All UI typography runs in a single sans-serif workhorse family, 'Neue Montreal', from massive 145px display headlines ({typography.hero-display}) down to 12px captions ({typography.caption}). The typeface is the main character; the UI exists to frame it. Components are lightweight and soft, with a consistent {rounded.lg} (20px) radius on cards, inputs, and buttons. {rounded.pill} is reserved exclusively for small status badges. The system deliberately avoids elevation—no drop shadows or gradients....

Color tokens:
- primary: #ff2f00
- ink: #000000
- body: #000000
- muted: #666666
- hairline-on-light: #000000
- canvas-light: #fafafa
- surface-soft-light: #ededed
- on-primary: #fafafa
- on-dark: #fafafa
- accent-yellow: #ffb700
- accent-blue: #bfe0ff

Typography tokens:
- hero-display: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 145px, weight 600, line 1, tracking 0
- display-lg: family 'Neue Montreal', sans-serif, size 121px, weight 600, line 1, tracking 0
- display-md: family 'Neue Montreal', sans-serif, size 48px, weight 600, line 1.1, tracking 0
- display-sm: family 'Neue Montreal', sans-serif, size 36px, weight 600, line 1.17, tracking 0
- title-lg: family 'Neue Montreal', sans-serif, size 22px, weight 530, line 1.17, tracking 0
- title-md: family 'Neue Montreal', sans-serif, size 18px, weight 530, line 1.2, tracking 0
- body-md: family 'Neue Montreal', sans-serif, size 16px, weight 400, line 1.2, tracking 0
- body-sm: family 'Neue Montreal', sans-serif, size 14px, weight 400, line 1.3, tracking 0
- caption: family 'Neue Montreal', sans-serif, size 12px, weight 500, line 1.3, tracking 0
- button: family 'Neue Montreal', sans-serif, size 14px, weight 500, line 1, tracking 0
- nav-link: family 'Neue Montreal', sans-serif, size 14px, weight 400, line 1.3, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 20px
- lg: 24px
- xl: 36px
- section: 92px

Radius and shape tokens:
- lg: 20px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.lg}, padding: 8px 23px
- button-secondary-ghost: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.lg}, padding: 8px 23px
- badge-new: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 4px 12px
- badge-update: backgroundColor: {colors.accent-yellow}, textColor: {colors.ink}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 4px 12px
- badge-early-access: backgroundColor: {colors.accent-blue}, textColor: {colors.ink}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 4px 12px
- specimen-card: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.title-md}, rounded: {rounded.lg}, padding: 26px
- hero-card: backgroundColor: {colors.ink}, textColor: {colors.on-dark}, typography: {typography.hero-display}, rounded: {rounded.lg}
- top-nav: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, height: 60px

Color rationale: Brand & Accent - Primary ({colors.primary} — ff2f00): The single orange-red action color. Reserved for filled status badges, selected navigation states, and focused conversion moments. Its scarcity makes it impactful. - Accent Yellow ({colors.accent-yellow} — ffb700): A secondary state accent for "update" status badges and validation surfaces. - Accent Blue ({colors.accent-blue} — bfe0ff): A tertiary state accent for "early access" status badges and informational states. Surface - Canvas Light ({colors.canvas-light} — fafafa): The default page floor, card surfaces, input fields, and panel backgrounds. A warm, barely off-white tone. - Surface Soft Light ({colors.surface-soft-light} — ededed): A secondary surface, one step deeper than canvas. Used for muted card backgrounds or image placeholder fills to create gentle separation. Hairlines & Borders - Hairline on Light ({colors.hairline-on-light} — 000000): The structural backbone of the system. A 1px solid black border is used on almost every card, list item, badge, and input. Text - Ink ({colors.ink} — 000000): Pure black for all primary text, headings, and icons. - Body ({colors.body} — 000000): Default running text reuses the ink...

Typography rationale: Font Family The system's UI is built entirely on a single sans-serif family: 'Neue Montreal'. This workhorse face carries everything from the largest display headlines to the smallest captions. It is the core of the visual identity. The fallback stack is a standard -apple-system, BlinkMacSystemFont, sans-serif. Other type families appear only within product specimen cards as showcase content, not as part of the system's UI chrome. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 145px | 600 | 1 | 0 | The largest display size, for hero-card type overlays. | | {typography.display-lg} | 121px | 600 | 1 | 0 | Secondary hero size. | | {typography.display-md} | 48px | 600 | 1.1 | 0 | Section headlines. | | {typography.display-sm} | 36px | 600 | 1.17 | 0 | Large sub-section heads. | | {typography.title-lg} | 22px | 530 | 1.17 | 0 | Card titles and medium headings. | | {typography.title-md} | 18px | 530 | 1.2 | 0 | Subheadings and emphasized text. | | {typography.body-md} | 16px | 400 | 1.2 | 0 | Default running-text. | | {typography.body-sm} | 14px | 400 | 1.3 | 0 | Secondary body copy and metadata. | | {typo...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 20px · {spacing.lg} 24px · {spacing.xl} 36px. - Section padding (vertical): {spacing.section} (92px) is used between major content blocks, creating a generous, comfortable rhythm. - Card internal padding: 26px is the standard for content cards. - Gutters: Gaps between cards in a grid range from 15px to 23px. Grid & Container - Max content width: 1200px, centered. - Hero sections: Often full-bleed, breaking the 1200px container to create immersive, large-format moments. - Grid: The primary content layout is a 4-column grid for catalogue views. Whitespace Philosophy The system prefers generous whitespace over rule-based dividers. The large {spacing.section} gap is the primary tool for separating content, reinforcing the clean, uncluttered, gallery-like feel.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Page canvas, text-only content blocks | | Hairline | 1px {colors.hairline-on-light} | The default for all cards, buttons, inputs, and badges. | | Overlay | Dark gradient on image | Used on hero media to ensure contrast for overlaid white text. | The elevation philosophy is explicitly flat. There are no box-shadows. Depth and separation are achieved exclusively through 1px solid {colors.hairline-on-light} borders and whitespace. This creates a print-catalogue feel where elements sit on the page like printed sheets rather than floating digital cards.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.lg} | 20px | The standard radius for all cards, buttons, and inputs. Creates a signature soft-rect shape. | | {rounded.pill} | 9999px | Reserved exclusively for small status badges to distinguish them from larger interactive elements. | The shape language is defined by two simple rules: 20px for containers, pill for badges. This consistency gives the UI a calm, ordered feel.

Component language: Buttons button-primary — The main call-to-action. A soft rectangle ({rounded.lg}) with a {colors.canvas-light} background and a crisp 1px {colors.hairline-on-light} border. Text is {colors.ink} set in {typography.button}. It reads as a filled, tangible object. button-secondary-ghost — A secondary action, often paired with the primary button over media backgrounds. Transparent background with a 1px white border and {colors.on-dark} text. Same shape and typography as the primary button. Badges badge-new — The signature accent element. A {rounded.pill} shape with a {colors.primary} background and {colors.on-primary} text. Small, tight, and high-contrast, used to tag new items. badge-update — A yellow variant using {colors.accent-yellow} background and {colors.ink} text for update notifications. badge-early-access — A cool blue variant using {colors.accent-blue} background and {colors.ink} text for preview-release status. Cards & Containers hero-card — A full-bleed feature card with a {rounded.lg} shape. It typically contains a background image with a dark overlay to ensure contrast for the centered, white display type set in {typography.hero-display}. specimen-card — The workhorse gr...

Guardrails: Do - Use {colors.primary} only as a chromatic accent for badges and interactive states. It must remain rare to be effective. - Set all borders to 1px solid {colors.hairline-on-light} for cards, buttons, and inputs. The hairline is the structural skeleton. - Use {rounded.lg} (20px) for all major containers and {rounded.pill} exclusively for badges. - Set hero type to {typography.hero-display} or {typography.display-lg} with a line-height of 1.0. The type should feel monumental. - Let full-bleed media carry hero sections, using dark overlays for text contrast. Don't - Don't use {colors.primary} for body text, headings, or large surface fills. Its role is punctuation only. - Don't apply box-shadows or heavy elevation. The system is flat by design. - Don't introduce other radius values. The strict two-radius system is a key signature. - Don't use multiple type families for the UI. The single workhorse fa...
```
