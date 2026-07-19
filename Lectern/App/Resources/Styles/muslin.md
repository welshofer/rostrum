# Muslin

**ID:** `muslin`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#222222`
- `#ffffff`
- `#f5f5f5`
- `#b6b6b6`
- `#727272`
- `#e6e6e6`

## Typography

Families: "'Farfetch Basis', Inter, -apple-system, BlinkMacSystemFont, sans-serif", "A display serif font, Georgia, Times, serif". Weights: 400, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: FARFETCH Espana

Design token description: A minimalist, white-cube fashion gallery interface built on a bone-white canvas (ffffff), where typography and editorial photography carry the entire visual load. Text and essential UI elements are rendered in a near-black carbon (222222). A custom geometric sans-serif runs at a strict 400 weight for all UI, while a display serif handles section titles, creating a sharp functional/editorial contrast. The layout is architectural and rigid, with generous whitespace and zero decorative chrome, borders, or shadows. The only surface inversion is a full-bleed carbon footer (222222) that closes the otherwise luminous page.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a system of extreme restraint, operating like a white-cube gallery for its content. The interface is almost entirely achromatic, built on a pure white canvas ({colors.canvas} — ffffff) and anchored by near-black text ({colors.ink} — 222222). There are no brand colors; all chromatic information is carried exclusively by photography. Typography performs all structural and hierarchical work. The system employs a dual-font model: a custom geometric sans-serif for all functional UI (navigation, labels, body copy) and a contrasting display serif for major section titles. Weights are used with extreme prejudice: almost everything is set at a regular 400 weight, with 700 reserved for rare, emphatic moments. This creates a calm, editorial feel that prioritizes composition over visual noise. The layout is architectural, using a centered, fixed-width grid and generous whitespace ({spacing.md} to {spacing.lg}) as its primary organizational tool. Components are unornamented to the point of invisibility: there are no shadows, no gradients, and every border radius is {rounded.md} (0px). The only major surface change is the full-bleed, inverted {colors.surface-dark-inverted} footer, which...

Color tokens:
- ink: #222222
- canvas: #ffffff
- body-on-light: #222222
- body-on-dark: #ffffff
- surface-soft: #f5f5f5
- surface-dark-inverted: #222222
- muted: #b6b6b6
- muted-strong: #727272
- hairline: #e6e6e6
- border-placeholder: #b6b6b6
- on-dark-inverted: #ffffff

Typography tokens:
- display-serif-lg: family A display serif font, Georgia, Times, serif, size 30px, weight 400, line 1.2, tracking -0.3px
- display-serif-sm: family A display serif font, Georgia, Times, serif, size 22px, weight 400, line 1.31, tracking 0
- body-md: family 'Farfetch Basis', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 400, line 1.33, tracking 0
- label-emphasis: family 'Farfetch Basis', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 700, line 1.33, tracking 0
- nav-link: family 'Farfetch Basis', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 13px, weight 400, line 1.33, tracking 0
- caption: family 'Farfetch Basis', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 13px, weight 400, line 1.33, tracking 0

Spacing tokens:
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 48px
- lg: 72px
- section: 72px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- announcement-bar: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, typography: {typography.caption}, padding: 8px 0
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- search-input-underlined: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, borderBottom: 1px solid {colors.border-placeholder}
- hero-category-tile: backgroundColor: transparent, textColor: {colors.body-on-dark}, typography: {typography.display-serif-sm}
- product-category-card: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.caption}
- nav-link-ghost: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- icon-button-utility: backgroundColor: transparent, textColor: {colors.ink}, padding: 8px
- footer-dark-inverted: backgroundColor: {colors.surface-dark-inverted}, textColor: {colors.on-dark-inverted}, typography: {typography.body-md}, padding: 64px 0

Color rationale: The palette is strictly monochrome, designed to frame content rather than compete with it. Core - Ink ({colors.ink} — 222222): The primary text color, used for all body copy, navigation, and icons on light surfaces. - Canvas ({colors.canvas} — ffffff): The page floor and dominant background for all components. - Body on Light ({colors.body-on-light} — 222222): Reuses the ink token for running text. - Body on Dark ({colors.body-on-dark} — ffffff): Used for text overlaid on dark imagery or the inverted footer. Surfaces - Surface Soft ({colors.surface-soft} — f5f5f5): The only non-white surface, used for subtle hover washes and the top announcement bar. - Surface Dark Inverted ({colors.surface-dark-inverted} — 222222): The footer background, a full-bleed inversion of the page canvas. Neutrals & Borders - Hairline ({colors.hairline} — e6e6e6): The barely-visible 1px divider tone for separating layout sections or list items. - Muted ({colors.muted} — b6b6b6): Placeholder text and resting-state underlines on inputs. - Muted Strong ({colors.muted-strong} — 727272): Secondary helper text and inactive UI states.

Typography rationale: Font Family The system operates on a dual-font model: 1. A custom geometric sans-serif (e.g., 'Farfetch Basis' or its open-source substitute, Inter) for all functional UI text: navigation, buttons, captions, and body copy. 2. A display serif font (e.g., Georgia, Times) for major editorial section titles, creating a clear distinction between UI and editorial voice. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-serif-lg} | 30px | 400 | 1.2 | -0.3px | Major section titles (Serif) | | {typography.display-serif-sm} | 22px | 400 | 1.31 | 0 | Sub-section titles and hero tile labels (Serif) | | {typography.body-md} | 15px | 400 | 1.33 | 0 | Default running text, product descriptions (Sans) | | {typography.label-emphasis} | 15px | 700 | 1.33 | 0 | Rare, emphatic labels (Sans) | | {typography.nav-link} | 13px | 400 | 1.33 | 0 | Top navigation links, input text (Sans) | | {typography.caption} | 13px | 400 | 1.33 | 0 | Product card captions, small meta-text (Sans) | Principles The use of weight 400 for display headings ({typography.display-serif-lg}) is a core principle. The system avoids bold headings, relying on size...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 48px · {spacing.lg} 72px. - Section padding (vertical): {spacing.md} (48px) to {spacing.lg} (72px) provides generous breathing room between content blocks. This whitespace is a primary layout tool. - Gutters: {spacing.sm} (24px) between cards in product grids. Grid & Container - Max content width: ~1280px, centered. - Grid: The layout is built on rigid 3- and 4-column grids for editorial and product content. There are no masonry or asymmetric layouts. - Header: A simple three-zone layout: left-aligned category navigation, a centered area for branding, and right-aligned utility icons.

Depth and hierarchy: The system is entirely flat. There is no concept of elevation through shadow, blur, or z-axis movement. - Flat: All surfaces are on the same plane. - No Shadow: No drop shadows are used on any element, including cards, buttons, or navigation. - Surface Elevation: The only "lift" comes from a subtle background color shift from {colors.canvas} to {colors.surface-soft}, used for hover states or utility bars. This is a color change, not a simulated depth change.

Shape language: Border Radius Scale The system uses a border radius of 0px for all elements, resulting in a sharp, architectural, and geometric aesthetic. | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | All elements | | {rounded.sm} | 0px | All elements | | {rounded.md} | 0px | All elements | | {rounded.lg} | 0px | All elements | | {rounded.xl} | 0px | All elements | | {rounded.pill} | 0px | Not used | Photography & Iconography - All images are displayed with sharp, 0px corners. - Icons are simple, 1.5px stroke outline forms rendered in {colors.ink}.

Component language: Navigation & Headers top-nav — A 64px tall header on a {colors.canvas} background. It contains a three-zone layout with left-aligned category links ({component.nav-link-ghost}), a center zone for brand identity, and right-aligned {component.icon-button-utility} elements. It is not sticky and has no bottom border. announcement-bar — A thin, full-bleed utility strip at the very top of the page. It uses {colors.surface-soft} for its background and {typography.caption} for centered, informational text. nav-link-ghost — The standard navigation link. It is text-only in {colors.ink} with no background. Interaction is typically shown with an underline on hover. Content Cards hero-category-tile — A large, full-bleed editorial image used as a primary category entry point. It has no border or shadow. A category label is overlaid on the image, typically using {typography.display-serif-sm} in a high-contrast color ({colors.body-on-dark}). product-category-card — A smaller card, typically in a 4-column grid. It consists of an image with a text caption ({typography.caption}) positioned directly below it. The component has no background, border, or shadow; it is just the image and its label on th...

Guardrails: Do - Rely on whitespace as the primary tool for separation and hierarchy. - Use the dual-font system correctly: serif for editorial titles, sans-serif for all UI. - Keep all UI elements strictly achromatic ({colors.ink}, {colors.canvas}, and their gray variants). - Maintain 0px border radius on all elements. - Use 400 weight for almost all text, including headings. Reserve 700 for rare, intentional emphasis. - Use the inverted dark footer to close every page. Don't - Don't introduce color into any UI component. Color belongs exclusively to content photography. - Don't use box shadows, gradients, or any other depth effects. The system is flat. - Don't use filled buttons with background colors. Interactions are text-based or underlined. - Don't break the rigid, architectural grid with asymmetric or fluid layouts. - Don't apply rounded corners to any element, especially images.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- restrained compositions with generous negative space and high typographic confidence
- editorial pacing with strong headline moments, image fields, and magazine-like hierarchy

Chart and infographic grammar:
- Charts must inherit the DESIGN.md palette, typography scale, stroke weight, corner radius, spacing, and grid density.
- Use branded annotations, legends, callout panels, and dividers instead of default spreadsheet styling.
- On dark palettes, render ch...
```
