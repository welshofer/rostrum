# Fuchsia

**ID:** `fuchsia`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Bold

## Color palette

- `#4541fe`
- `#fe0f83`
- `#101722`
- `#f9f0ff`
- `#ffffff`
- `#d9c6ff`
- `#3f424e`
- `#6c6c7a`

## Typography

Families: "Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Violet Brushstroke

Design token description: A dark-anchored system built on a deep midnight-navy canvas (101722), where an electric-violet accent (4541fe) carries all primary actions and brand moments. Oversized, tightly-tracked headlines create an architectural feel, while generously rounded cards (42px) and pill-shaped buttons give the interface a soft, modern shape. A signature pink (fe0f83) to violet gradient ribbon provides a single, organic flourish against the otherwise geometric and flat surfaces. The visual rhythm alternates between deep dark, vivid accent, and soft lavender (f9f0ff) surfaces, avoiding plain white for a more deliberate, atmospheric feel.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system is a dark-anchored interface built on a deep, midnight-navy canvas ({colors.canvas-dark} — 101722). This foundation hosts oversized, confident headlines and is punctuated by a single, vivid electric-violet accent ({colors.primary} — 4541fe) that carries all primary CTAs and key visual moments. The typography is defined by a single font, Inter, used at extreme display sizes (up to 92px) with tight negative letter-spacing (-4.6px on {typography.display}) to give headlines a compressed, architectural weight. The overall feel is soft and modern, defined by two key shapes: generously rounded cards ({rounded.lg} — 42px) and fully pill-shaped buttons ({rounded.pill} — 9999px). A signature pink-to-violet gradient ribbon sweeps through hero sections, providing the only moment of organic, decorative energy in an otherwise flat, geometric UI. The visual rhythm alternates between three distinct surfaces: the dark {colors.canvas-dark}, the vivid {colors.primary}, and a soft, pale lavender {colors.canvas-light} used for breathing room. The system deliberately avoids plain white-on-white, ensuring every surface has a deliberate temperature and atmosphere. Key Characteristics: - Single...

Color tokens:
- primary: #4541fe
- primary-gradient-end: #fe0f83
- canvas-dark: #101722
- canvas-light: #f9f0ff
- surface-card: #ffffff
- surface-accent: #d9c6ff
- ink-on-dark: #ffffff
- ink-on-light: #101722
- body-on-light: #3f424e
- muted: #6c6c7a
- on-primary: #ffffff

Typography tokens:
- display: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 92px, weight 700, line 0.88, tracking -4.6px
- hero-display: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 72px, weight 700, line 1, tracking -3.6px
- display-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 64px, weight 700, line 1.1, tracking -3.2px
- display-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 36px, weight 700, line 1.15, tracking -1.8px
- title-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 700, line 1.3, tracking -1.2px
- body-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.4, tracking -0.8px
- caption: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 600, line 1.4, tracking -0.7px
- button: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 600, line 1, tracking -0.8px
- nav-link: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 600, line 1.4, tracking -0.7px

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
- md: 20px
- lg: 42px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-accent: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 10px 20px
- button-secondary-on-dark: backgroundColor: {colors.surface-card}, textColor: {colors.ink-on-light}, typography: {typography.button}, rounded: {rounded.pill}, padding: 14px 24px
- hero-band-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.ink-on-dark}, typography: {typography.hero-display}, padding: 80px
- accent-band: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.display-md}, padding: 80px
- testimonial-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink-on-light}, typography: {typography.body-md}, rounded: {rounded.lg}, padding: 32px
- top-nav-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.ink-on-dark}, typography: {typography.nav-link}, height: 64px
- chat-widget: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, rounded: {rounded.full}, height: 48px, width: 48px
- carousel-button: backgroundColor: {colors.canvas-dark}, textColor: {colors.ink-on-dark}, rounded: {rounded.full}, height: 40px, width: 40px

Color rationale: Brand & Accent - Electric Iris ({colors.primary} — 4541fe): The single, vivid accent color. Used for primary CTA backgrounds, full-bleed accent sections, and active nav indicators. - Hot Magenta ({colors.primary-gradient-end} — fe0f83): The warm endpoint of the signature decorative gradient. It is not used as a standalone color, only in conjunction with {colors.primary} in the gradient ribbon. Surface - Canvas Dark ({colors.canvas-dark} — 101722): The primary page floor. A deep midnight navy that serves as the anchor for hero sections, navigation, and other dark-themed content bands. - Canvas Light ({colors.canvas-light} — f9f0ff): A pale linen-lavender used for lighter, "breathing-room" sections between dark or accent blocks. Never pure white. - Surface Card ({colors.surface-card} — ffffff): The fill for all content cards, providing a clean interior surface that sits atop the lavender or dark canvases. - Surface Accent ({colors.surface-accent} — d9c6ff): A soft lilac tint used for secondary highlights, tags, or chip backgrounds. Text - Ink on Dark ({colors.ink-on-dark} — ffffff): Default text color on dark and accent surfaces. - Ink on Light ({colors.ink-on-light} — 101722): The...

Typography rationale: Font Family The system uses a single typeface, Inter, for all typographic roles. Hierarchy is created through dramatic shifts in size and weight, not by introducing a secondary display face. The fallback stack is a standard system UI list: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. Hierarchy The defining characteristic is the extremely tight letter-spacing (-0.05em) applied to all text, which becomes most pronounced at large display sizes, creating a dense, architectural feel. Line heights are also compressed, especially for headlines. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display} | 92px | 700 | 0.88 | -4.6px | Top-level hero headlines | | {typography.hero-display} | 72px | 700 | 1.0 | -3.6px | Standard hero headlines | | {typography.display-lg} | 64px | 700 | 1.1 | -3.2px | Major section titles | | {typography.display-md} | 36px | 700 | 1.15 | -1.8px | Section titles within accent bands | | {typography.title-lg} | 24px | 700 | 1.3 | -1.2px | Card titles and sub-headings | | {typography.body-md} | 16px | 400 | 1.4 | -0.8px | Default running text | | {typography.caption} | 14px | 600 | 1.4 | -...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) or greater. Accent bands and heroes use generous padding (up to 120px) to feel expansive. - Card internal padding: {spacing.xl} (32px) for most content cards. - Gutters: {spacing.lg} (24px) between cards in a carousel; {spacing.md} (16px) for internal element gaps. Grid & Container - Max content width: ~1200px. Content within {colors.canvas-light} sections is centered in this container. - Full-bleed sections: Hero bands ({colors.canvas-dark}) and accent bands ({colors.primary}) extend to the full viewport width, ignoring the content container. Whitespace Philosophy The system uses a rhythm of alternating full-bleed color bands. The space within these bands is generous, especially vertically, to let the oversized typography breathe. However, the space between elements inside cards is tighter ({spacing.md}), creating focused content blocks.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top nav, hero bands, accent bands, buttons | | Card surface | {colors.surface-card} background on a colored canvas | All primary content cards ({component.testimonial-card}) | | Soft drop shadow | rgba(23, 73, 77, 0.15) 0px 20px 30px 0px | Applied to cards to provide subtle lift off the {colors.canvas-light} background. | | Decorative glow | rgb(69, 65, 254) 40px 0px 576px 160px | A large, diffuse violet glow used occasionally behind featured cards on an accent background. Not a standard shadow. | The system's philosophy is primarily flat, relying on color-block contrast for separation. Shadows are minimal and used only to lift white cards off the light lavender canvas. Decorative Depth The primary source of depth is the gradient ribbon graphic, a sweeping S-curve that runs from {colors.primary} to {colors.primary-gradient-end}. It is a purely decorative element that sits behind hero headlines, creating a sense of motion and layering without relying on shadows or 3D effects.

Shape language: Border Radius Scale The shape language is defined by two extreme radii that are applied consistently. | Token | Value | Use | |---|---|---| | {rounded.sm} | 12px | Inputs | | {rounded.md} | 20px | Small interactive elements | | {rounded.lg} | 42px | All content cards ({component.testimonial-card}) | | {rounded.pill} | 9999px | All buttons ({component.button-primary-accent}, {component.button-secondary-on-dark}), tags, and chips | Iconography Icons are typically solid, single-color glyphs. The style is simple and geometric to complement the flat UI, with an equivalent stroke weight of 1.5-2px.

Component language: Navigation top-nav-dark — The primary site navigation. A flat, 64px tall bar with a {colors.canvas-dark} background. It contains menu links in {typography.nav-link} and a right-aligned {component.button-primary-accent}. Buttons button-primary-accent — The main vivid CTA. Pill-shaped ({rounded.pill}) with a {colors.primary} background and {colors.on-primary} text. Used for high-priority actions, especially in the navigation bar. button-secondary-on-dark — The primary CTA on dark hero sections. It's a "light" button, with a {colors.surface-card} background and {colors.ink-on-light} text. Also pill-shaped ({rounded.pill}). carousel-button — A small, circular, icon-only button used for navigating horizontal carousels. It has a {colors.canvas-dark} background with a {colors.ink-on-dark} arrow icon. Cards & Containers hero-band-dark — A full-bleed dark section that opens the page. It has a {colors.canvas-dark} background and features an oversized headline in {typography.hero-display}. It often contains the decorative gradient ribbon. accent-band — A full-bleed, high-energy section with a {colors.primary} background. Used to break the page rhythm and highlight key messages with {typograp...

Guardrails: Do - Use Inter at 700 weight with -0.05em letter-spaci...
```
