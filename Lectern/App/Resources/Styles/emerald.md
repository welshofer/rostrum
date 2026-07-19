# Emerald

**ID:** `emerald`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Corporate

## Color palette

- `#00e05c`
- `#162136`
- `#2b3a57`
- `#657694`
- `#bfc7d9`
- `#000000`
- `#ffffff`
- `#f2f5fa`
- `#c1c9d8`
- `#0073d3`

## Typography

Families: "'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Wrike

Design token description: A clean, enterprise-confident design language anchored on a stark white canvas, where a single vivid lime green (00e05c) carries every primary CTA and brand accent. A deep midnight navy (162136) provides typographic authority for headlines and body text, while cool blue-gray neutrals create soft surface separation. Typography runs a single sans-serif stack with bold (700 weight) headlines. Components favor soft, generous radii with pill-shaped CTAs (40px) and rounded cards (20px), often elevated by a signature, soft drop-shadow. The system feels energetic and structured, like a productivity OS rather than a simple form-based tool.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: food/hospitality. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: food photography, dishes, plates, chefs, kitchens, menus, recipes, utensils, or dining scenes.

Overall visual personality: This design system is built on a stark white canvas punctuated by a single vivid lime green that acts as a power switch across the interface. The system uses a deep midnight navy for authority text and dark sections, with cool blue-gray neutrals providing soft surface separation rather than warm grays or heavy shadows. Typography is carried by a single sans-serif family at comfortable, 4px-grid spacing, with weight 700 headlines that command attention against whisper-thin 400 body text. Components are pill-shaped ({rounded.lg} — 40px radius) and card-soft ({rounded.md} — 20px radius), using one signature shadow hospitality-service structure that floats elements off the page. The overall feel is enterprise-confident but energetic — a work-management tool that looks like a productivity OS, not a form. Key Characteristics: - Single accent color: {colors.primary-accent} (00e05c) is the only chromatic accent. It is reserved for primary CTAs, active states, and single-word highlights in headlines. - Cool neutral palette: The system avoids warm grays, relying on {colors.ink} (navy), {colors.muted} (blue-gray), and {colors.surface-soft} (frosty blue-white) for its hierarchy. - Single font...

Color tokens:
- primary-accent: #00e05c
- ink: #162136
- ink-soft: #2b3a57
- muted: #657694
- hairline: #bfc7d9
- icon-strong: #000000
- canvas: #ffffff
- surface-soft: #f2f5fa
- shadow-tone: #c1c9d8
- accent-link: #0073d3
- disabled: #737a86
- on-primary: #ffffff
- on-dark: #ffffff

Typography tokens:
- hero-display: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 64px, weight 700, line 1.1, tracking -1px
- display-lg: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 700, line 1.2, tracking -0.5px
- title-lg: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 700, line 1.25, tracking 0
- title-md: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 700, line 1.3, tracking 0.3px
- title-sm: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 700, line 1.38, tracking 0.3px
- subheading: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 600, line 1.4, tracking 0.2px
- body-md: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0.2px
- body-sm: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.4, tracking 0.2px
- caption: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 600, line 1.6, tracking 1.5px
- button: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 600, line 1.2, tracking 0
- nav-link: family 'TT Norms Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0

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
- xs: 4px
- sm: 8px
- md: 20px
- lg: 40px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary-accent}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.lg}, padding: 14px 28px
- button-ghost: backgroundColor: transparent, textColor: {colors.accent-link}, typography: {typography.body-md}, padding: 8px
- top-announcement-bar: backgroundColor: {colors.primary-accent}, textColor: {colors.ink}, typography: {typography.body-sm}, padding: 8px 0
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}
- feature-card: backgroundColor: {colors.surface-soft}, textColor: {colors.muted}, typography: {typography.body-sm}, rounded: {rounded.md}, padding: 32px
- hero-band: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.hero-display}, padding: {spacing.section}
- media-card-elevated: backgroundColor: {colors.canvas}, rounded: {rounded.md}
- cta-band-dark: backgroundColor: {colors.ink}, textColor: {colors.on-dark}, typography: {typography.display-lg}, padding: {spacing.xxl}

Color rationale: Brand & Accent - Primary Accent ({colors.primary-accent} — 00e05c): The single, vivid lime green that defines the brand's energy. Used for primary CTA backgrounds, headline word highlights, and active state indicators. - Accent Link ({colors.accent-link} — 0073d3): A secondary blue used for ghost buttons and inline text links that offer a lower-priority action. Surface - Canvas ({colors.canvas} — ffffff): The default page background. Pure white, providing maximum contrast. - Surface Soft ({colors.surface-soft} — f2f5fa): A very light, cool-toned off-white used for feature card backgrounds and subtle section washes to differentiate content blocks from the main canvas. - Ink ({colors.ink} — 162136): A deep midnight navy used as a background for the final dark CTA band and footer sections. Text - Ink ({colors.ink} — 162136): The primary text color for headlines and important body copy on light surfaces. - Ink Soft ({colors.ink-soft} — 2b3a57): A slightly softer navy for secondary headings and card titles. - Muted ({colors.muted} — 657694): A cool steel blue-gray for helper text, secondary body copy, and muted labels. - Disabled ({colors.disabled} — 737a86): A muted gray for disabled...

Typography rationale: Font Family The system relies exclusively on a single sans-serif typeface, TT Norms Pro, for all UI roles. The fallback stack is a standard -apple-system, BlinkMacSystemFont, sans-serif. Hierarchy is achieved through a clear scale of size and weight, not by introducing new font families. - Headlines: Weight 700 for high-impact display and section titles. - Subheadings & Buttons: Weight 600 provides a step down for less critical titles and CTA labels. - Body & Captions: Weight 400 for all running text, descriptions, and helper copy. A signature element is the use of uppercase "eyebrows" ({typography.caption}) with wide letter-spacing (1.5px) to introduce content sections. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 64px | 700 | 1.1 | -1px | Main page H1 | | {typography.display-lg} | 48px | 700 | 1.2 | -0.5px | Section headlines in dark bands | | {typography.title-lg} | 32px | 700 | 1.25 | 0 | Major section titles | | {typography.title-md} | 24px | 700 | 1.3 | 0.3px | Feature card headlines | | {typography.title-sm} | 20px | 700 | 1.38 | 0.3px | Smaller card titles | | {typography.subheading} | 18px...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px), sometimes extending to 120px for major hero sections, creating a comfortable, un-cramped rhythm down the page. - Card internal padding: {spacing.xl} (32px) to {spacing.xxl} (48px) is common, ensuring content inside cards has ample breathing room. - Gutters: {spacing.lg} (24px) between cards in multi-column grids. Grid & Container - Max content width: ~1200px centered. - Structure: Most landing pages use a simple centered stack of full-bleed sections. The hero is often a two-column split (text left, media right). Feature sections use 2- or 3-column grids of equal-width cards. Whitespace Philosophy The system is comfortable and spacious. It trusts generous vertical spacing ({spacing.section}) between content bands and large internal padding within cards to create a calm, organized, and easy-to-scan hierarchy. Density is actively avoided.

Depth and hierarchy: The system's elevation model is defined by a single, signature shadow hospitality-service structure. It avoids multiple shadow tiers in favor of one consistent "floating sheet" effect. | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, text blocks, hero bands | | Soft Surface | {colors.surface-soft} background | Feature cards, section washes | | Hairline | 1px {colors.hairline} border | Inputs, dividers | | Elevated | Single shadow: rgba(24, 31, 56, 0.25) 0px 25px 45px -45px | Elevated media cards, sticky navigation on scroll | Depth comes from this single, soft shadow, which has a large negative spread. This means the shadow primarily appears at the bottom of an element, creating a subtle lift without a distracting halo effect around all sides.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small utility elements, tags | | {rounded.sm} | 8px | Input fields, nested buttons | | {rounded.md} | 20px | Standard content cards, media cards | | {rounded.lg} | 40px | Primary CTA buttons | | {rounded.pill} | 9999px | Pill-shaped tags, toggles | | {rounded.full} | 9999px / 50% | Avatars, decorative circles | The system's shape language is defined by soft, generous curves. The {rounded.lg} (40px) on primary buttons is a signature element, creating a friendly and approachable feel. {rounded.md} (20px) is the standard for most container cards, ensuring a consistent softness throughout the UI.

Component language: Buttons button-primary — The main conversion action. A filled {colors.primary-accent} background with {colors.on-primary} text. Uses {typography.button} and the signature {rounded.lg} (40px) shape. It is impossible to miss on the stark white canvas. button-ghost — A secondary, text-only action. Uses {colors.accent-link} for text color with no background or border. Often paired below a primary CTA as a lower-pressure alternative. Navigation & Banners top-announcement-bar — A full-bleed promotional strip above the main navigation. Uses a {colors.primary-accent} background with {colors.ink} text. top-nav — The primary site navigation. A simple {colors.canvas} bar with no bottom border, allowing it to sit cleanly on the page. Nav links use {typography.nav-link} in {colors.ink}. It may gain the system's single shadow hospitality-service structure on scroll. Cards & Containers hero-band — The primary above-the-fold section. A full-bleed {colors.canvas} band with a max-width container, typically in a two-column layout: a {typography.hero-display} headline on the left, and a {component.media-card-elevated} on the right. feature-card — Used in 3-column grids to describe features. Has a {co...

Guardrails: Do - Use {colors.primary-accen...
```
