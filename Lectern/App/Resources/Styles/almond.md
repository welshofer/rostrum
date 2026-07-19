# Almond

**ID:** `almond`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#272420`
- `#0b2330`
- `#141312`
- `#575653`
- `#c4c4bc`
- `#9a9a91`
- `#faf9f8`
- `#f3f3f3`
- `#322e2a`
- `#e8e7e6`

## Typography

Families: "ABC Diatype, -apple-system, BlinkMacSystemFont, sans-serif", "TT Commons Pro, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Sprig

Design token description: A near-monochrome editorial system built on a warm bone-white canvas (faf9f8), where a near-black ink with a navy undertone (0b2330) carries all primary text and structure. The interface is deliberately quiet and undecorated, using hairline borders and generous spacing over overt ornamentation. Two custom type families define the voice — a geometric sans for editorial headings and a functional sans for UI controls, both at modest weights. The only chromatic moments are warm sunset gradients used as backdrops for hero sections. Components are defined by soft, pill-shaped radii (32px) and extremely large-radius cards (100px), creating a signature visual contrast between soft pills and nearly-circular surfaces.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system reads like a quiet, confident research notebook. It operates in a near-monochrome editorial register on a warm bone-white canvas ({colors.canvas} — faf9f8), using hairline borders ({colors.hairline} — e8e7e6) and a single near-black ink with a navy undertone ({colors.ink} — 0b2330) for almost all text and structure. The aesthetic is deliberately undecorated and spacious, trusting typography and shape to carry the visual identity. Typography is a conversation between two custom families: a geometric sans (ABC Diatype) for editorial moments (headings, body) and a functional sans (TT Commons Pro) for UI chrome (buttons, nav links). A key characteristic is the typographic restraint — headings use a medium weight (500) rather than a bold (700), giving the system a soft-spoken authority. Components are defined by soft, pill-shaped radii ({rounded.pill} — 32px) for interactive elements and an unusually large radius for content cards ({rounded.xl} — 100px). This contrast between pill-buttons and nearly-circular cards is a signature. The only chromatic color is a warm sunset gradient composed of gold, coral, and purple-gray ({colors.accent-dusk}, {colors.accent-ember}, {colors.a...

Color tokens:
- primary: #272420
- ink: #0b2330
- ink-strong: #141312
- body: #575653
- muted: #c4c4bc
- muted-strong: #9a9a91
- on-primary: #faf9f8
- canvas: #faf9f8
- surface-card: #f3f3f3
- surface-dark: #272420
- surface-dark-deep: #322e2a
- hairline: #e8e7e6
- hairline-soft: #dddcd9
- border-muted: #6e6d6a

Typography tokens:
- display-sm: family ABC Diatype, -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 500, line 1.2, tracking 0
- title-md: family ABC Diatype, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 500, line 1.2, tracking 0
- title-sm: family ABC Diatype, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 400, line 1.3, tracking 0
- body-lg: family TT Commons Pro, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.5, tracking 0
- body-md: family ABC Diatype, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- caption: family ABC Diatype, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.3, tracking 0
- button: family TT Commons Pro, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1, tracking 0
- nav-link: family TT Commons Pro, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0

Spacing tokens:
- xs: 8px
- sm: 16px
- md: 24px
- lg: 32px
- xl: 48px
- xxl: 64px
- section: 80px

Radius and shape tokens:
- xs: 4px
- pill: 32px
- xl: 100px
- xxl: 1600px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 6px 12px
- button-ghost: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 6px 12px, border: 1px solid {colors.hairline-soft}
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.nav-link}, height: 64px
- announcement-banner: backgroundColor: {colors.surface-dark}, textColor: {colors.on-primary}, typography: {typography.caption}, height: 40px
- badge: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.caption}, rounded: {rounded.xs}, padding: 4px 8px
- feature-card-large: backgroundColor: transparent, textColor: {colors.ink}, rounded: {rounded.xl}, padding: 48px
- cta-card-dark: backgroundColor: {colors.surface-dark}, textColor: {colors.on-primary}, typography: {typography.display-sm}, rounded: {rounded.xl}, padding: 64px

Color rationale: Primary & Ink - Espresso ({colors.primary} — 272420): The primary action color. A warm near-black used for filled button backgrounds and dark the source brand sections. - Ink ({colors.ink} — 0b2330): The workhorse near-black with a whisper of navy. Used for primary text, nav links, and strong borders. - Ink Strong ({colors.ink-strong} — 141312): A slightly warmer near-black used for display headings where a touch more warmth is needed. - On Primary ({colors.on-primary} — faf9f8): The warm off-white text color used on dark surfaces like {component.button-primary}. Same as canvas. the source brand - Canvas ({colors.canvas} — faf9f8): The base page background. A warm off-white that defines the entire system's atmosphere. - the source brand Card ({colors.surface-card} — f3f3f3): The first step up from the canvas, used for subtle elevated cards and badge backgrounds. - the source brand Dark ({colors.surface-dark} — 272420): The primary dark the source brand, same as the primary action color. Used for announcement banners and dark CTA cards. - the source brand Dark Deep ({colors.surface-dark-deep} — 322e2a): The deepest dark the source brand, used for footer-adjacent areas or image fram...

Typography rationale: Font Family The system uses a dual-typeface strategy to separate editorial and functional voices. - ABC Diatype: A geometric sans-serif for editorial type. It is used for all display headings, section titles, subheadings, and primary body copy. - TT Commons Pro: A functional sans-serif for UI chrome. It is used for button labels, navigation links, badges, and other small interface labels. Hierarchy | Token | Size | Weight | Line Height | Use | |---|---|---|---|---| | {typography.display-sm} | 40px | 500 | 1.2 | Large section headings | | {typography.title-md} | 32px | 500 | 1.2 | Section headings | | {typography.title-sm} | 24px | 400 | 1.3 | Subheadings | | {typography.body-lg} | 18px | 400 | 1.5 | UI text, larger body moments (TT Commons) | | {typography.body-md} | 16px | 400 | 1.5 | Default running-text (ABC Diatype) | | {typography.caption} | 14px | 400 | 1.3 | Small metadata, badge labels | | {typography.button} | 16px | 400 | 1 | All button labels (TT Commons) | | {typography.nav-link} | 16px | 400 | 1.5 | Top navigation menu items (TT Commons) | Principles Typographic restraint is a core principle. Display headings use weight 500, not a heavier bold, to maintain a quiet, co...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 48px · {spacing.xxl} 64px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) is used consistently between major content bands, creating a generous, editorial rhythm. - Card internal padding: {spacing.xl} (48px) for feature cards. - Gutters: {spacing.md} (24px) between cards in a grid; {spacing.xs} (8px) between inline UI elements. Grid & Container - Max content width: ~1200px centered. Hero and other specific bands can be full-bleed. - Editorial body: The page is predominantly single-column or two-column (text/visual split). All text is left-aligned, never centered. Whitespace Philosophy The system is spacious and editorial. It relies on generous, consistent whitespace ({spacing.section}) and hairline dividers to create structure and rhythm, rather than alternating background colors or heavy containers. The density is low, prioritizing readability and a calm, focused reading experience.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Canvas) | {colors.canvas} background | The base page floor. | | 1 (Card) | {colors.surface-card} background | Subtle elevated cards, badges. | | 2 (Divider) | 1px {colors.hairline} border | Hairline dividers between content bands. | | 3 (Dark the source brand) | {colors.surface-dark} background | Primary buttons, announcement banners, dark CTA sections. | | 4 (Atmospheric) | Warm gradient background | Hero sections, backdrops for key visuals. | The elevation philosophy intentionally avoids drop shadows. Depth and separation are achieved through subtle shifts in the source brand tone and the use of clean, 1px hairline dividers. Curvature ({rounded.xl}) and generous spacing also contribute to the sense of layered planes without resorting to shadows. The only "shadow-like" effect is the warm gradient halo, which provides depth through color, not blur.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Badges and small tags. | | {rounded.pill} | 32px | All buttons (primary and ghost), navigation containers. Creates a signature pill shape. | | {rounded.xl} | 100px | Large content cards, feature cards. A very large radius that makes cards feel soft and almost circular. | | {rounded.xxl} | 1600px | Special hero-level containers, creating an almost-flat edge on a large the source brand. | The shape language is a study in contrasts: small, functional elements are soft pills, while large content containers are defined by an extremely large, gentle curvature. The system avoids sharp, right-angled corners. Photography & Iconography The system uses candid, professional photography with a warm tone. Icons are functional, stroke-based, and rendered in {colors.ink}. All product visuals are shown as screenshots contained within a card that has the signature {rounded.xl} radius and is often set against the atmospheric warm gradient backdrop.

Component language: Buttons button-primary — The only filled button style. Used for the primary conversion action on any page. It has a {colors.primary} (272420) background with {colors.on-primary} (faf9f8) text. It is always a pill shape ({rounded.pill}) with compact {typography.button} text. button-ghost — The secondary button style. It has a transparent background with a 1px {colors.hairline-soft} border and {colors.ink} text. It shares the same pill shape ({rounded.pill}) and typography as the primary button. Navigation & Banners top-nav — The main site navigation. It sits on a {colors.canvas} background with no bottom border. It contains navigation links in {typography.nav-link} and a primary call-to-action using {component.button-primary}. announcement-banner — A thin, full-bleed bar above the main navigation for site-wide announcements. It uses a {colors.surface-dark} background with {colors.on-primary} text. Cards & Containers feature-card-large — The signature container for showcasing visuals or key content. It uses the large {rounded.xl} (100px) radius and often sits on top of the atmospheric warm gradient. cta-card-dark — The closing call-to-a...
```
