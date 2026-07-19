# Carousel

**ID:** `carousel`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#ff8a00`
- `#ff54bb`
- `#0f101a`
- `#777885`
- `#ffffff`
- `#f1f3f6`
- `#b8b8b8`
- `#c7c7c7`
- `#99eeff`
- `#ff8465`

## Typography

Families: "'SF Pro Rounded', Nunito, Quicksand, sans-serif", "sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Rainbow

Design token description: A sky-bright, toy-store visual language built on a light-mode foundation. The system uses a near-black (0f101a) for all type and iconography, creating high contrast against airy white and lavender surfaces. Two primary CTA colors — a tangerine orange (ff8a00) and a hot pink (ff54bb) — carry all primary actions. Components are playful and chunky, defined by extreme pill radii (40-50px) on buttons and large corner radii (32px) on cards. Heavy, rounded display type with tight negative tracking reinforces a soft, friendly aesthetic. Depth is achieved through inset highlights and pastel gradient washes, avoiding traditional drop shadows.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system employs a sky-bright, toy-store visual language, characterized by pillowy rounded letterforms, candy-saturated accents, and atmospheric pastel backgrounds. It is a light-mode system where a single near-black ink ({colors.ink} — 0f101a) provides high contrast against a base of white ({colors.canvas-light}) and soft gray ({colors.surface-soft-light}) surfaces. Two chromatic CTAs — a vibrant tangerine ({colors.primary}) and a hot pink ({colors.accent-secondary}) — carry every primary action. These are often paired with full-bleed, multi-hue gradients in feature sections that dissolve mint, coral, lavender, and sky-blue into white. Components are intentionally playful and chunky. Buttons use extreme pill radii of {rounded.xl} (40px) to {rounded.pill} (50px), and content cards use a large {rounded.lg} (32px) corner radius. The typography follows suit, with a heavy rounded display face ({typography.hero-display}) set at large sizes with tight negative letter-spacing for a friendly, compact feel. The core principle is "bold but soft": large, confident shapes with rounded edges everywhere. Depth is conveyed not through harsh shadows or fine borders, but from inset highlights an...

Color tokens:
- primary: #ff8a00
- accent-secondary: #ff54bb
- ink: #0f101a
- body: #777885
- on-primary: #ffffff
- canvas-light: #ffffff
- surface-soft-light: #f1f3f6
- muted: #b8b8b8
- inset-shadow: #c7c7c7
- accent-sky: #99eeff
- accent-coral-start: #ff8465
- accent-coral-end: #ff62a3
- accent-atmosphere-start: #94ffe8
- accent-atmosphere-mid: #e9e2f6

Typography tokens:
- hero-display: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 100px, weight 900, line 1, tracking -3px
- display-lg: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 56px, weight 800, line 1.1, tracking -1.6px
- display-md: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 42px, weight 600, line 1.1, tracking -1.3px
- title-lg: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 32px, weight 600, line 1.2, tracking -1px
- title-md: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 24px, weight 600, line 1.2, tracking -0.7px
- title-sm: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 20px, weight 600, line 1.2, tracking -0.6px
- body-md: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 16px, weight 500, line 1.2, tracking -0.2px
- caption: family sans-serif, size 12px, weight 400, line 1.2, tracking 0
- button: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 16px, weight 700, line 1, tracking -0.2px
- nav-link: family 'SF Pro Rounded', Nunito, Quicksand, sans-serif, size 16px, weight 600, line 1.2, tracking -0.5px

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
- xs: 10px
- sm: 16px
- md: 24px
- lg: 32px
- xl: 40px
- pill: 50px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.xl}, padding: 16px 24px
- button-secondary: backgroundColor: {colors.accent-secondary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.xl}, padding: 16px 24px
- button-nav-ghost: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.full}, padding: 12px 20px
- feature-card: backgroundColor: {colors.surface-soft-light}, textColor: {colors.ink}, rounded: {rounded.lg}, padding: {spacing.xxl}, boxShadow: rgba(255, 255, 255, 0.32) 0px 5px 32px 12px inset
- notification-toast: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 12px 20px, boxShadow: 0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -2px rgba(0,0,0,0.1)
- hero-band: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.hero-display}, padding: {spacing.section}
- nav-bar: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px

Color rationale: Brand & Accent - Primary / Tangerine ({colors.primary} — ff8a00): The main primary CTA color. A bright, confident orange used for filled button backgrounds. - Secondary Accent / Hot Pink ({colors.accent-secondary} — ff54bb): The companion primary CTA color. Used for a second, equally important action, often appearing alongside the primary button. - Accent Coral ({colors.accent-coral-start} / {colors.accent-coral-end}): A warm gradient from orange (ff8465) to pink (ff62a3), used for decorative ribbons and text highlights. - Accent Sky ({colors.accent-sky} — 99eeff): A decorative accent wash and soft highlight color used in feature sections. Surface - Canvas Light ({colors.canvas-light} — ffffff): The default page floor and primary card surface. - Surface Soft Light ({colors.surface-soft-light} — f1f3f6): A soft gray used for alternating content bands and secondary card fills to create subtle separation. Text - Ink ({colors.ink} — 0f101a): The primary text color for all headings, body copy, and iconography. A near-black that provides strong contrast. - Body ({colors.body} — 777885): A softer gray for secondary body text, helper labels, and annotations that need to recede. - On Prima...

Typography rationale: Font Family The system's voice is carried by SF Pro Rounded, a typeface with soft, pillowy letterforms. All display, heading, and body text uses this family. The heavy use of weights from Medium (500) to Black (900) is a key characteristic. - Substitutes: If the primary font is unavailable, Nunito or Quicksand can serve as effective open-source alternatives, preserving the soft, rounded feel. Hierarchy The type scale is defined by large, impactful display sizes and tight negative letter-spacing to create a compact, friendly block of text. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 100px | 900 | 1.0 | -3px | Main page h1, signature brand statements | | {typography.display-lg} | 56px | 800 | 1.1 | -1.6px | Section openers, large value props | | {typography.display-md} | 42px | 600 | 1.1 | -1.3px | Panel headings | | {typography.title-lg} | 32px | 600 | 1.2 | -1px | Major card titles | | {typography.title-md} | 24px | 600 | 1.2 | -0.7px | Subheadings, emphasized inline labels | | {typography.title-sm} | 20px | 600 | 1.2 | -0.6px | Small titles, large body emphasis | | {typography.body-md} | 16px | 500 | 1.2 |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) provides a comfortable rhythm between major content bands. - Card internal padding: {spacing.lg} (24px) for standard cards, up to {spacing.xxl} (48px) and beyond for promotional feature cards. - Gutters: {spacing.md} (16px) between elements within a component; {spacing.xl} (32px) or more between cards in a grid. Grid & Container - Max content width: 1200px centered. - Layout: The system favors full-bleed layouts where atmospheric gradients can extend to the page edges. Content is typically centered or arranged in simple 2-up or 3-up grids. Whitespace Philosophy The system is comfortable and airy. It avoids thin borders and relies on generous whitespace or subtle shifts in surface color (from {colors.canvas-light} to {colors.surface-soft-light}) to create separation and structure.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, text blocks, simple content areas | | Surface Shift | {colors.surface-soft-light} background | Alternating content bands to create rhythm without elevation | | Inset Highlight | inset 0px 5px 32px 12px rgba(255,255,255,0.32) | Media frames and feature cards to simulate a glassy, internally lit surface | | Soft Drop Shadow | Faint rgba(0,0,0,0.1) shadow | Used sparingly on floating UI elements like toasts to lift them from the page | The elevation philosophy deliberately avoids traditional outer drop shadows. Depth is an illusion created by two primary techniques: 1. Inset Highlights: A white inset shadow on cards gives them a glossy, 3D feel as if lit from within. This is a signature effect. 2. Atmospheric Gradients: Full-bleed pastel gradient washes make surfaces feel atmospheric and distant, pushing content forward by contrast.

Shape language: Border Radius Scale The system is defined by its soft, "pillowy" shapes, achieved with an aggressive border-radius scale. | Token | Value | Use | |---|---|---| | {rounded.xs} | 10px | Small icons and minor UI elements | | {rounded.sm} | 16px | Notification toasts, smaller interactive elements | | {rounded.md} | 24px | Medium-sized cards and panels | | {rounded.lg} | 32px | The signature radius for all primary cards and media frames | | {rounded.xl} | 40px | Primary CTA buttons | | {rounded.pill} | 50px | Larger, more prominent pill-shaped buttons | | {rounded.full} | 9999px | Small circular elements, fully-rounded ghost buttons | Sharp corners are intentionally absent from all user-facing components. The minimum radius is {rounded.xs} (10px), with the default for most containers being the very large {rounded.lg} (32px). This commitment to roundedness is a core personality trait.

Component language: Buttons button-primary — The main action button. Tangerine ({colors.primary}) background with white ({colors.on-primary}) text. Uses {rounded.xl} (40px) for a chunky, pill-like shape. button-secondary — A companion primary action. Hot pink ({colors.accent-secondary}) background with white text. Shares the same shape and typography as the primary button. These two buttons often appear as a pair. button-nav-ghost — A secondary button used in the top navigation. White ({colors.canvas-light}) fill with ink ({colors.ink}) text, and a fully-rounded ({rounded.full}) shape to stand out against text-only navigation links. Cards & Containers feature-card — A container for showcasing features or media. Uses a soft gray ({colors.surface-soft-light}) or a solid accent color fill, with the signature {rounded.lg} (32px) radius. The key feature is a glassy depth effect created by an inset white highlight shadow. notification-toast — A small, floating notification element. White ({colors.canvas-light}) fill, {rounded.sm} (16px) radius, and a subtle drop shadow to lift it off the pa...
```
