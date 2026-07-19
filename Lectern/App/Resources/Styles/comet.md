# Comet

**ID:** `comet`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#6a48f2`
- `#ffffff`
- `#f3f3f3`
- `#888888`
- `#dddddd`
- `#e9e9e9`
- `#2c2c2e`
- `#000000`
- `#171718`
- `#ffdb00`

## Typography

Families: "'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Stellar

Design token description: An interface that operates like a creative marketplace set on a midnight-black canvas — pure void (000000) for the page background, dark elevated surfaces, and oversized, whisper-light display type. A single vivid violet (6a48f2) is rationed for primary CTAs and active states, acting as a precise electric punctuation in an otherwise achromatic system. Type runs a single family (Neue Montreal) at weight 400 even for massive 70-104px display sizes, using tight negative tracking to create a hushed, authoritative feel. The design's defining choice is restraint, creating a 'gallery wall' effect where everything recedes into shadow except the main content and the single call to action.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: The system reads like a creative dynamic transaction/data-flow pattern on a closed gallery wall at midnight. The base is an absolute-black canvas ({colors.canvas-dark} — 000000) that eliminates all atmospheric depth, making content and type feel like they float. Surfaces are one shade above black ({colors.surface-card-dark} — 171718), creating separation without illumination. Color is strictly rationed: an achromatic palette of near-white text and graphite hairlines does 95% of the work, and a single vivid violet ({colors.primary} — 6a48f2) appears only on primary CTAs and active states. Typography is the system's defining signature. A single family, Neue Montreal, is used for everything. Critically, display sizes up to 104px are set at weight 400, a deliberate refusal of bold weight that creates a hushed, authoritative tone. This whisper-light approach, combined with tight negative letter-spacing on display sizes, lets the void around the type carry the visual weight. The result is a minimal, confident interface where everything recedes into shadow except the primary content and the one clear action. Key Characteristics: - Absolute black canvas: The page floor is {colors.canvas-d...

Color tokens:
- primary: #6a48f2
- ink: #ffffff
- body: #f3f3f3
- body-on-dark: #f3f3f3
- muted: #888888
- muted-strong: #dddddd
- muted-soft: #e9e9e9
- hairline-on-dark: #2c2c2e
- canvas-dark: #000000
- surface-card-dark: #171718
- on-primary: #ffffff
- on-dark: #ffffff
- accent-glow: #ffdb00

Typography tokens:
- hero-display: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 104px, weight 400, line 1.0, tracking -2.08px
- display-lg: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 72px, weight 400, line 1.1, tracking -1.44px
- display-md: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 400, line 1.2, tracking -0.4px
- title-lg: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 22px, weight 400, line 1.43, tracking -0.22px
- title-md: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 19px, weight 400, line 1.43, tracking -0.19px
- body-md: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.55, tracking 0
- caption: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.5, tracking 0.5px
- label-eyebrow: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 500, line 1.5, tracking 0.5px
- button: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 500, line 1, tracking 0
- nav-link: family 'Neue Montreal', -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 400, line 1.5, tracking 0

Spacing tokens:
- xxs: 8px
- xs: 12px
- sm: 16px
- md: 20px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 80px

Radius and shape tokens:
- sm: 6px
- md: 10px
- pill: 50px
- full: 50px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 24px
- nav-link-ghost: backgroundColor: transparent, textColor: {colors.muted-strong}, typography: {typography.nav-link}
- text-input-on-dark: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 20px 16px, border: 1px solid {colors.hairline-on-dark}
- profile-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.on-dark}, rounded: {rounded.md}, padding: {spacing.md}
- project-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.on-dark}, rounded: {rounded.sm}
- project-thumbnail: backgroundColor: transparent, rounded: {rounded.md}
- top-nav-dark: backgroundColor: transparent, textColor: {colors.muted-strong}, typography: {typography.nav-link}, padding: 20px 0
- section-header: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-lg}

Color rationale: Brand & Accent - Primary Violet ({colors.primary} — 6a48f2): The single chromatic note in the system. Used for the primary CTA background, active link states, and input focus rings. It is rationed to signal "this is the action." - Accent Glow ({colors.accent-glow} — ffdb00): A yellow color used for a decorative glow effect, not a structural part of the UI. Applied as a spotlight shadow on select media elements. Surface - Canvas Dark ({colors.canvas-dark} — 000000): The page background. Pure, absolute black. - Surface layered rectangular token motif Dark ({colors.surface-card-dark} — 171718): The background for elevated layered rectangular token motif and panels. One shade lighter than the canvas to create subtle, shadowless depth. Hairlines & Borders - Hairline on Dark ({colors.hairline-on-dark} — 2c2c2e): The 1px border tone for inputs and outlined controls. The thinnest readable outline on the near-black surfaces. Text - On Dark ({colors.on-dark} — ffffff): Pure white, reserved for the highest-contrast text like primary display headlines. - Body on Dark ({colors.body-on-dark} — f3f3f3): The default text color for headings. Slightly off-white to reduce harshness against the pure...

Typography rationale: Font Family The system uses a single font family, Neue Montreal, for all typographic roles. The fallback stack is a standard sans-serif: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. Hierarchy The typographic hierarchy is defined by an unconventional use of weight and letter-spacing. Display sizes use a light weight 400 to create a hushed, confident tone. This is contrasted by weight 500 used only for small button and label text. Letter-spacing is tight and negative for large display sizes, but wide and positive for small uppercase labels. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 104px | 400 | 1.0 | -2.08px | Page-level hero headlines | | {typography.display-lg} | 72px | 400 | 1.1 | -1.44px | Section titles | | {typography.display-md} | 40px | 400 | 1.2 | -0.4px | Large headings within components | | {typography.title-lg} | 22px | 400 | 1.43 | -0.22px | layered rectangular token motif titles | | {typography.title-md} | 19px | 400 | 1.43 | -0.19px | Supporting sub-headlines | | {typography.body-md} | 16px | 400 | 1.55 | 0 | Default running text | | {typography.caption} | 14px | 400 |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 12px · {spacing.sm} 16px · {spacing.md} 20px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px). Sections are separated by generous whitespace, using the void itself as a divider. - layered rectangular token motif internal padding: {spacing.md} (20px) is the standard for content layered rectangular token motif. - Gutters: {spacing.md} (20px) between elements in a grid or stack. Grid & Container - Max content width: 1200px, centered. The {colors.canvas-dark} background extends to the full viewport width. - Editorial body: Content typically lives in a single centered column. - Grids: Component grids (e.g., for profiles) use a 3 or 4-column layout at desktop with uniform {spacing.md} gutters. Whitespace Philosophy The system treats whitespace as an active element. The pure black void is not empty space but a feature that frames content, creates rhythm, and enforces focus. Density is intentionally spacious to maintain the "gallery wall" aesthetic.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, hero bands, top nav | | layered rectangular token motif surface | {colors.surface-card-dark} background on {colors.canvas-dark} | All elevated layered rectangular token motif ({component.profile-card}, {component.project-card}) | | Outlined | 1px {colors.hairline-on-dark} border | Inputs, outlined controls | | Focus | 1px {colors.primary} border | Input focus state | | Decorative glow | 0 0 16px {colors.accent-glow} shadow | A non-structural spotlight effect on select media elements, not used for UI elevation | The elevation model is strictly shadowless. Depth is communicated exclusively through the subtle contrast between the {colors.canvas-dark} floor and the one-step-lighter {colors.surface-card-dark}. This reinforces the flat, graphic, "on the wall" feeling of the interface.

Shape language: Border Radius Scale The system uses a very specific and limited radius scale to define its geometric character. | Token | Value | Use | |---|---|---| | {rounded.sm} | 6px | Inputs, navigation containers, small tags | | {rounded.md} | 10px | Primary content layered rectangular token motif ({component.profile-card}) | | {rounded.pill} | 50px | Primary CTA buttons | | {rounded.full} | 50px | Avatars, circular elements | Photography & Iconography - Media within layered rectangular token motif is typically full-bleed, cropping to the layered rectangular token motif's corner radius ({rounded.md} or {rounded.sm}). - Iconography is minimal, using thin-stroke arrow indicators on links and simple geometric marks for brand elements.

Component language: Buttons & Links button-primary — The single, high-intent call to action. It's a pill shape ({rounded.pill}) with a solid {colors.primary} violet background and {colors.on-primary} white text. The type is {typography.button}. It is the only fully chromatic control in the system, and its scarcity makes it a powerful focal point. nav-link-ghost — The default state for top navigation links. It has no background or border, with text in {colors.muted-strong}. On hover, the text color shifts to {colors.on-dark} for emphasis. layered rectangular token motif & Containers profile-card — A container for displaying individual profiles. It uses {colors.surface-card-dark} for the background, with a {rounded.md} radius and {spacing.md} internal padding. The top half typically contains a full-bleed image area, while the bottom contains text content. project-card — A larger horizontal layered rectangular token motif for showcasing work. It shares the same {colors.surface-card-dark} background but uses a tighter {rounded.sm} radius. It often contains a centered media element with a {colors.hairline-on-dark} divider b...
```
