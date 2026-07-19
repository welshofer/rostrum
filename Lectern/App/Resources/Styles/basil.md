# Basil

**ID:** `basil`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#00473c`
- `#e6ff55`
- `#f4f3e7`
- `#d8e5d6`
- `#e8dcc6`
- `#0e150e`
- `#000000`
- `#8c8c82`
- `#555555`

## Typography

Families: "Grenette, Migra, Canela, serif", "SweetSans, Dazzed, Supreme, sans-serif", "SweetSansText, Söhne, Inter, sans-serif", "SweetSansText-Regular, Söhne, Inter, sans-serif". Weights: 200, 400, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Sweetgreen

Design token description: A warm, farm-stand-meets-modern-typography aesthetic on a cream canvas (f4f3e7), rooted in natural materials. Deep forest green (00473c) serves as the structural anchor, while a singular, high-energy electric lime (e6ff55) carries all primary actions. Saturated, overhead imagery is treated as hero content. Typography leads the interface, with a custom geometric sans for oversized, tightly-leaded headlines and a secondary ultra-light display face for contrast. Components are deliberately spare — pill-shaped buttons and borderless cards — letting the imagery and typography dominate every clean interface-like information plane.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: food/hospitality, consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: food photography, dishes, plates, chefs, kitchens, menus, recipes, utensils, or dining scenes; phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system's design is a warm, farm-stand-meets-modern-typography aesthetic. It is built on a cream canvas ({colors.canvas} — f4f3e7) that evokes natural materials, with a deep forest green ({colors.primary-brand} — 00473c) serving as the structural anchor for text and secondary actions. A single, high-energy electric lime ({colors.accent} — e6ff55) is reserved for all primary CTAs, giving conversion moments an unmissable focal point. The visual language is led by imagery and typography. Saturated, overhead photography is treated as hero content, filling cards and backgrounds. The typographic system is the primary interface element, using a custom geometric sans (SweetSans) for oversized, tightly-leaded headlines that feel monumental yet calm. Components are deliberately spare — pill-shaped buttons, text-only links, and borderless product cards — to ensure the imagery and typography own every clean interface-like information plane.

Color tokens:
- primary-brand: #00473c
- accent: #e6ff55
- canvas: #f4f3e7
- surface-soft: #d8e5d6
- surface-alt: #e8dcc6
- ink: #0e150e
- ink-strong: #000000
- border: #8c8c82
- muted: #555555
- on-accent: #0e150e

Typography tokens:
- hero-display: family SweetSans, Dazzed, Supreme, sans-serif, size 80px, weight 400, line 1, tracking 0
- display-lg: family SweetSans, Dazzed, Supreme, sans-serif, size 70px, weight 400, line 0.85, tracking 0
- display-md: family Grenette, Migra, Canela, serif, size 48px, weight 200, line 1, tracking -2.26px
- display-sm: family SweetSans, Dazzed, Supreme, sans-serif, size 40px, weight 400, line 0.85, tracking 0
- title-lg: family SweetSansText, Söhne, Inter, sans-serif, size 24px, weight 700, line 1.21, tracking 1.2px
- title-md: family SweetSansText, Söhne, Inter, sans-serif, size 20px, weight 700, line 1.2, tracking 0.6px
- title-sm: family SweetSansText, Söhne, Inter, sans-serif, size 18px, weight 700, line 1.33, tracking 0.54px
- body-md: family SweetSansText, Söhne, Inter, sans-serif, size 16px, weight 400, line 1.25, tracking 0.27px
- body-sm: family SweetSansText-Regular, Söhne, Inter, sans-serif, size 14px, weight 400, line 1.29, tracking 0.24px
- caption: family SweetSansText-Regular, Söhne, Inter, sans-serif, size 12px, weight 400, line 1.33, tracking 0.2px
- button: family SweetSansText, Söhne, Inter, sans-serif, size 16px, weight 700, line 1.25, tracking 0.27px
- nav-link: family SweetSansText, Söhne, Inter, sans-serif, size 14px, weight 700, line 1.29, tracking 0.7px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 40px
- xxl: 60px
- section: 80px

Radius and shape tokens:
- xs: 4px
- sm: 8px
- lg: 20px
- xl: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.accent}, textColor: {colors.on-accent}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 24px
- button-secondary: backgroundColor: transparent, textColor: {colors.primary-brand}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 20px, borderWidth: 2px, borderColor: {colors.primary-brand}
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md}
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.primary-brand}, typography: {typography.nav-link}
- product-card: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.lg}, padding: 24px
- availability-badge: backgroundColor: {colors.accent}, textColor: {colors.on-accent}, typography: {typography.caption}, rounded: {rounded.lg}, padding: 4px 12px
- hero-band-overlay: backgroundColor: rgba(244, 243, 231, 0.9), textColor: {colors.ink}, typography: {typography.display-lg}, padding: 40px
- content-band-soft: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, padding: 80px

Color rationale: Brand & Accent - Primary Brand ({colors.primary-brand} — 00473c): A deep forest green that acts as the structural anchor. Used for secondary button outlines, text accents, and some high-contrast text roles. - Accent ({colors.accent} — e6ff55): A vibrant lime green used exclusively for primary action button backgrounds and small availability badges. Its sole purpose is to signal interactive, high-priority elements. the source brand - Canvas ({colors.canvas} — f4f3e7): The primary page background. A warm off-white that gives the system an organic, non-clinical feel. - the source brand Soft ({colors.surface-soft} — d8e5d6): A soft sage green used for alternating full-width content bands, providing gentle visual separation for editorial sections. - the source brand Alt ({colors.surface-alt} — e8dcc6): A warm sand beige used as a secondary content band color, adding earthy variety to the green-dominant palette. Text - Ink ({colors.ink} — 0e150e): The primary text color. A near-black with a subtle green undertone that harmonizes with the brand palette. Used for body copy, headlines, and links. - Ink Strong ({colors.ink-strong} — 000000): Pure black for maximum-contrast text, hairlines,...

Typography rationale: Font Family The system uses three custom typefaces with distinct roles: - SweetSans: A geometric sans-serif for all major display headlines. Its signature is using a regular weight (400) at very large sizes with extremely tight line-height. - Grenette: An ultra-thin, high-contrast secondary display face. Used sparingly for an editorial, delicate counterpoint to the sturdy SweetSans. - SweetSansText: The workhorse for all UI text, including body copy, button labels, and navigation. It uses positive tracking at small sizes to enhance readability. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 400 | 1.0 | 0 | Top-level hero headlines | | {typography.display-lg} | 70px | 400 | 0.85 | 0 | Primary display headlines with signature tight leading | | {typography.display-md} | 48px | 200 | 1.0 | -2.26px | Secondary editorial display accent | | {typography.display-sm} | 40px | 400 | 0.85 | 0 | Section titles, large category labels | | {typography.title-lg} | 24px | 700 | 1.21 | 1.2px | Card titles, bolded sub-sections | | {typography.title-md} | 20px | 700 | 1.2 | 0.6px | Component titles, smaller headin...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 40px · {spacing.xxl} 60px · {spacing.section} 80px. - Section padding (vertical): A generous {spacing.section} (80px) is used between all major content bands, creating a calm, gallery-like pacing. - Card internal padding: {spacing.lg} (24px) is standard for content within cards. - Gutters: {spacing.md} (16px) or {spacing.lg} (24px) between grid items. Grid & Container - Max content width: 1200px, centered. - Editorial body: Content sections typically use a 2-column (1:1) split for text and imagery. Product grids are often 3-up at desktop. - Alternating Bands: The layout rhythm is built on alternating the default {colors.canvas} background with full-width content bands using {colors.surface-soft} or {colors.surface-alt}. Whitespace Philosophy The system uses generous whitespace to let the typography and photography breathe. It avoids dense, chrome-heavy layouts in favor of an open, editorial feel. The large {spacing.section} value between blocks is key to this pacing.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Page canvas, content bands, text links, category tabs | | Soft Shadow | rgba(14, 21, 14, 0.4) 3px 3px 32px -10px | A subtle, moody shadow applied to primary CTA buttons and product cards to give them a slight lift off the page. | The system is predominantly flat. Depth is created through color blocking (e.g., a colored content band on the cream canvas) rather than a complex shadow hierarchy. The single shadow style is used sparingly to elevate key interactive elements.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small UI elements, micro-badges | | {rounded.sm} | 8px | Input fields | | {rounded.lg} | 20px | Badges, image corners | | {rounded.xl} | 24px | Larger content cards | | {rounded.pill} | 9999px | The exclusive shape for all buttons | | {rounded.full} | 9999px | Avatars, circular icons | The shape language is defined by two extremes: soft, generous radii ({rounded.lg} and {rounded.xl}) for cards and images, and the fully-rounded {rounded.pill} for all buttons. There are no sharp corners in the system. Imagery & Iconography - Imagery is the primary visual content. All images are high-saturation, overhead or 3/4-angle shots, presented on organic surfaces. - Image containers use a consistent {rounded.lg} (20px) corner radius and are typically full-bleed within their parent element. - Icons are minimal, line-based, and use a single-weight stroke in {colors.ink}. They are reserved for functional UI like arrows and navigation controls.

Component language: Top Navigation top-nav — A simple horizontal bar on the {colors.canvas} background. Contains left and right-aligned navigation items rendered in {typography.nav-link}. One item is often styled as a {component.button-secondary} to draw attention to a primary journey. Buttons button-primary — The main call-to-action. A {rounded.pill} button with a {colors.accent} background and {colors.on-accent} text. This is the highest-contrast, most visually prominent interactive element. button-secondary — An outlined {rounded.pill} button used for secondary actions. It has a transparent background with a 2px border and text in {colors.primary-brand}. text-link — A "ghost" link with no background or border. Rendered in {colors.ink} at {typography.body-md}, often appended with a right-arrow glyph to signify interaction. Underline appears on hover only. Cards & Containers product-card — A borderless, shadowless container for a single item. It consists of a square image at the top with {rounded.lg} corners, followed by text content below with {spacing.lg} of internal padding. The image itself forms the top boundary of the card. availability-badge — A small, {rounded.lg} badge used to indicate spec...

Guardrails: Do - Use SweetSans at 70–80px, weight 400, with 0.85 line-height for all primary display headlines....
```
