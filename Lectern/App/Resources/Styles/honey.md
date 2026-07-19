# Honey

**ID:** `honey`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#ffdb5b`
- `#fff386`
- `#202020`
- `#ffffff`
- `#f3f3f3`
- `#3b3b3b`
- `#575656`
- `#343333`
- `#000000`

## Typography

Families: "BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Bumble

Design token description: A sunlit, magazine-style interface built on a monochrome-plus-one system. A structural near-black (202020) carries all typography, borders, and primary CTAs, creating a consistent foundation. A single warm, honey-yellow (ffdb5b) is reserved for full-bleed hero bands and large surface canvases, acting as an emotional high-availability connection system rather than a functional UI color. Geometry is soft and confident, with generous 16-24px radii on all major components and pill-shaped badges. The system's custom geometric sans-serif runs with slightly opened letter-spacing for a warm, unhurried cadence. Layouts use generous padding and whitespace over a bright white canvas, creating a comfortable rhythm where the UI recedes to let content and imagery lead.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: telecom/connectivity. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, SIM cards, cell towers, antennas, routers, call screens, or telecom product shots.

Overall visual personality: The system reads like a sunlit lifestyle magazine, built on a disciplined monochrome-plus-one philosophy. The entire interface is carried by a structural near-black ({colors.ink} — 202020) and a bright white canvas ({colors.canvas} — ffffff). Every primary action button, all body copy, and all borders use the same near-black ink, creating a simple, high-contrast foundation. A single accent, a vivid honey-yellow ({colors.primary} — ffdb5b), is reserved for large, emotional moments — full-bleed hero bands and feature card frames — and is never used for small, interactive UI elements. The geometry is soft and confident. A custom geometric sans-serif, BumbleSans, runs with consistently positive letter-spacing, giving it a warm, unhurried cadence. Radii are generous ({rounded.md} at 16px, {rounded.lg} at 24px), so no element feels sharp or aggressive. Cards lift off the page with a single, subtle drop shadow. The layout is comfortable and spacious, with generous card padding ({spacing.xl}) and section gaps ({spacing.section}) that prioritize readability and allow content to breathe. The result is a design that feels human and approachable, where the UI recedes to let imagery and messag...

Color tokens:
- primary: #ffdb5b
- primary-light: #fff386
- ink: #202020
- canvas: #ffffff
- surface-soft: #f3f3f3
- hairline: #3b3b3b
- muted: #575656
- on-dark: #ffffff
- on-primary-surface: #202020
- on-badge-text: #343333

Typography tokens:
- hero-display: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 68px, weight 700, line 1, tracking 1.36px
- display-lg: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 700, line 1.18, tracking 0.8px
- display-md: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 700, line 1.2, tracking 0.64px
- title-lg: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 600, line 1.25, tracking 0.43px
- title-md: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 600, line 1.33, tracking 0.32px
- body-lg: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 17px, weight 400, line 1.5, tracking 0.2px
- body-md: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 400, line 1.5, tracking 0.11px
- button: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 500, line 1.5, tracking 0.16px
- nav-link: family BumbleSans, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 500, line 1.5, tracking 0.16px

Spacing tokens:
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 64px

Radius and shape tokens:
- sm: 9px
- md: 16px
- lg: 24px
- pill: 1000px
- full: 1000px

Component tokens:
- button-primary: backgroundColor: {colors.ink}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.md}, padding: 14px 24px
- nav-pill-active: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, rounded: {rounded.md}, padding: 10px 22px
- hero-band: backgroundColor: {colors.primary}, textColor: {colors.on-primary-surface}, typography: {typography.hero-display}, padding: {spacing.section}
- feature-card-white: backgroundColor: {colors.canvas}, textColor: {colors.ink}, rounded: {rounded.lg}, padding: {spacing.xl}
- feature-card-accent: backgroundColor: {colors.primary-light}, textColor: {colors.ink}, rounded: {rounded.lg}, padding: 40px
- badge-pill: backgroundColor: {colors.canvas}, textColor: {colors.on-badge-text}, typography: {typography.body-md}, rounded: {rounded.pill}, padding: 8px 16px
- badge-pill-accent: backgroundColor: {colors.primary}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.pill}, padding: 8px 16px
- app-store-badge: backgroundColor: {colors.ink}, textColor: {colors.on-dark}, rounded: {rounded.sm}

Color rationale: Brand & Accent - Primary Yellow ({colors.primary} — ffdb5b): The sole brand color, a warm honey-yellow. Used exclusively for large surface areas like the hero band and feature card frames. It high-availability connection system brand warmth, not interactivity. - Primary Yellow Light ({colors.primary-light} — fff386): A lighter variant used for secondary card frames to provide tonal variation. Core UI - Ink ({colors.ink} — 202020): The foundational near-black. Used for all text, primary button backgrounds, borders, and dividers. It is the system's workhorse color. - Canvas ({colors.canvas} — ffffff): The default page and card background. Pure white, providing a bright, clean base for content. - On Dark ({colors.on-dark} — ffffff): Text color for use on {colors.ink} surfaces, such as the primary action button. Surface - Surface Soft ({colors.surface-soft} — f3f3f3): A subtle off-white for cards or sections that need to lift gently from the main canvas without relying on a shadow. Text & Borders - On Primary Surface ({colors.on-primary-surface} — 202020): Text color for use on yellow backgrounds, reusing the main ink token. - On Badge Text ({colors.on-badge-text} — 343333): A slightl...

Typography rationale: Font Family The system uses a single custom geometric sans-serif, BumbleSans, for the entire interface — from large display headlines to small button labels. This creates a cohesive and consistent typographic voice. A key characteristic is its slightly open letter-spacing, which is applied across all sizes to lend a warm, readable quality. - Substitute: If the primary font is unavailable, Inter or DM Sans provide a close geometric warmth. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 68px | 700 | 1.0 | 1.36px | Primary hero headlines | | {typography.display-lg} | 40px | 700 | 1.18 | 0.8px | Large section titles | | {typography.display-md} | 32px | 700 | 1.2 | 0.64px | Card headlines, product names | | {typography.title-lg} | 24px | 600 | 1.25 | 0.43px | Sub-section titles | | {typography.title-md} | 20px | 600 | 1.33 | 0.32px | Small card subheadings | | {typography.body-lg} | 17px | 400 | 1.5 | 0.2px | Main body copy | | {typography.body-md} | 15px | 400 | 1.5 | 0.11px | Captions, legal text, badge labels | | {typography.button} | 16px | 500 | 1.5 | 0.16px | Primary button labels | | {typography.na...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 64px. - Section gap (vertical): {spacing.section} (64px) is consistently used between major content blocks, creating a comfortable, unhurried page rhythm. - Card internal padding: {spacing.xl} (32px) is the standard for main content cards, ensuring ample whitespace around content. - Gutters: {spacing.lg} (24px) is used for gaps between elements within a component or grid. Grid & Container - Max content width: 1200px, centered. This provides a readable line-length for text and a constrained canvas for layouts. - Layout pattern: The structure follows a "full-bleed first" model. A full-width {component.hero-band} is followed by alternating white and yellow content sections. Within these sections, content is constrained to the 1200px max-width, often using 2-column grids for feature blocks.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, {component.hero-band}, footer | | Card | rgba(32, 32, 32, 0.12) 0px 1px 8px 0px | The single, subtle shadow used for {component.feature-card-white} to lift it from the canvas. | | Active Nav | No shadow, {colors.canvas} fill | The {component.nav-pill-active} floats on the page with color contrast, not depth. | The system's approach to depth is minimal and deliberate. Elevation is achieved with a single, very subtle shadow, used only on white cards that sit on the white canvas. There are no complex shadow stacks, colored shadows, or gradients. The primary method of separation is color blocking (yellow bands vs. white sections) and generous whitespace.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 9px | Small UI elements like app store badges. | | {rounded.md} | 16px | The standard radius for buttons and navigation pills. | | {rounded.lg} | 24px | The standard radius for all content cards. | | {rounded.pill} | 1000px | Used exclusively for small, decorative badges and tags. | | {rounded.full} | 1000px | Alias for pill, for circular elements if needed. | The shape language is consistently soft and rounded. Sharp corners are avoided entirely. The scale is simple and disciplined: 16px for interactive elements, 24px for containers, and a full pill for badges. This consistency reinforces the friendly, approachable feel of the interface.

Component language: Buttons & Navigation button-primary — The system's only filled action button. It uses a {colors.ink} background with {colors.on-dark} text, establishing a strong, high-contrast service access motif to action. With a {rounded.md} radius, it feels soft and accessible. This is the go-to button for all primary actions like 'Sign In' or 'Download'. nav-pill-active — Marks the current page in the top navigation. It's an inverse of the primary button: a {colors.canvas} pill with {colors.ink} text. This creates a clean, toggle-like relationship between navigation and primary actions. Containers & Bands hero-band — A full-bleed band with a {colors.primary} background, serving as the page's main brand statement. It contains oversized display text and is the primary vehicle for the system's warm, emotional color. feature-card-white — The standard content card. It has a {colors.canvas} background, a generous {rounded.lg} radius, and ample internal padding ({spacing.xl}). It lifts off the page with the system's single, subtle drop shadow. feature-card-accent — A variant card that uses a {colors.primary-light} background frame. This provides visual variety and reinforces the brand's warmth with...

Guardrails: Do - Use {colors.primary} for large, full-bleed background surfaces to inject brand warmth and punctuate page sections. - Use {component.button-primary} (dark fill, white text) for all primary service access motif to action. This is the system...
```
