# Blossom

**ID:** `blossom`  
**Category:** commerce  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#ff385c`
- `#e00b41`
- `#ffd1da`
- `#c13515`
- `#b32505`
- `#460479`
- `#92174d`
- `#222222`
- `#3f3f3f`
- `#6a6a6a`

## Typography

Families: "'Airbnb Cereal VF', Circular, -apple-system, system-ui, Roboto, 'Helvetica Neue', sans-serif", "'Airbnb Cereal VF', Circular, sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Airbnb

Design token description: A warm, generous consumer marketplace anchored on a clean white canvas and the source brand Rausch (ff385c), the single brand voltage that carries every primary CTA, search-button orb, and rating dot. Type runs the source brand Cereal VF at modest weights — display sits at 22–28px in weight 500/600 rather than the heavy 700+ that fintech and enterprise systems use; the brand trusts photography and generous whitespace over typographic muscle. Three product entries (welcoming place-based environment, Experiences, Services) sit in the top nav with hand-illustrated 32-icon glyphs and "NEW" badges, signaling a marketplace expansion rather than a feature dump. Pill-shaped search bars ({rounded.full}), softly rounded property layered rectangular token motif ({rounded.lg} ~14px), and 32px button radii read as friendly and human — there is no hard corner anywhere except the body grid.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: travel/destination services, finance/banking, food/hospitality. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: beaches, hotels, homes, rental listings, passports, suitcases, boarding passes, airports, airplanes, or vacation scenes; credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content; food photography, dishes, plates, chefs, kitchens, menus, recipes, utensils, or dining scenes.

Overall visual personality: the source brand is the canonical example of a generous, photography-led consumer marketplace. The base canvas is pure white ({colors.canvas} — ffffff) with deep near-black ink ({colors.ink} — 222222) for headlines and body, and a single voltage of Rausch ({colors.primary} — ff385c) carrying every primary CTA, the search-button orb, the heart save state, and inline brand links. There is no secondary brand color in mainline marketing — the Luxe purple ({colors.luxe} — 460479) and Plus magenta ({colors.plus} — 92174d) tokens are sub-brand accents that only appear inside the source brand Luxe / Plus contexts. Type runs the source brand Cereal VF (a custom variable font the source brand licenses), with Circular as the historic in-house fallback and a system stack underneath. Cereal sits at modest weights — display headlines render at 22–28px in weight 500–600, not the heavy 700+ weights that financial or enterprise systems lean on. The hero h1 ("Inspiration for future getaways") on the homepage is just 28px / 700, which would feel small on a typical SaaS page; here it works because the layout leans on photography (city collage, property layered rectangular token motif) for visual weig...

Color tokens:
- primary: #ff385c
- primary-active: #e00b41
- primary-disabled: #ffd1da
- primary-error-text: #c13515
- primary-error-text-hover: #b32505
- luxe: #460479
- plus: #92174d
- ink: #222222
- body: #3f3f3f
- muted: #6a6a6a
- muted-soft: #929292
- hairline: #dddddd
- hairline-soft: #ebebeb
- border-strong: #c1c1c1

Typography tokens:
- display-xl: family 'the source brand Cereal VF', Circular, -apple-system, system-ui, Roboto, 'Helvetica Neue', sans-serif, size 28px, weight 700, line 1.43, tracking 0
- display-lg: family 'the source brand Cereal VF', Circular, sans-serif, size 22px, weight 500, line 1.18, tracking -0.44px
- display-md: family 'the source brand Cereal VF', Circular, sans-serif, size 21px, weight 700, line 1.43, tracking 0
- display-sm: family 'the source brand Cereal VF', Circular, sans-serif, size 20px, weight 600, line 1.20, tracking -0.18px
- title-md: family 'the source brand Cereal VF', Circular, sans-serif, size 16px, weight 600, line 1.25, tracking 0
- title-sm: family 'the source brand Cereal VF', Circular, sans-serif, size 16px, weight 500, line 1.25, tracking 0
- rating-display: family 'the source brand Cereal VF', Circular, sans-serif, size 64px, weight 700, line 1.1, tracking -1px
- body-md: family 'the source brand Cereal VF', Circular, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-sm: family 'the source brand Cereal VF', Circular, sans-serif, size 14px, weight 400, line 1.43, tracking 0
- caption: family 'the source brand Cereal VF', Circular, sans-serif, size 14px, weight 500, line 1.29, tracking 0
- caption-sm: family 'the source brand Cereal VF', Circular, sans-serif, size 13px, weight 400, line 1.23, tracking 0
- badge: family 'the source brand Cereal VF', Circular, sans-serif, size 11px, weight 600, line 1.18, tracking 0

Spacing tokens:
- xxs: 2px
- xs: 4px
- sm: 8px
- md: 12px
- base: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 64px

Radius and shape tokens:
- none: 0px
- xs: 4px
- sm: 8px
- md: 14px
- lg: 20px
- xl: 32px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.sm}, padding: 14px 24px, height: 48px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.sm}
- button-primary-disabled: backgroundColor: {colors.primary-disabled}, textColor: {colors.on-primary}, rounded: {rounded.sm}
- button-secondary: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.sm}, padding: 13px 23px, height: 48px
- button-tertiary-text: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}
- button-pill-rausch: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-sm}, rounded: {rounded.full}, padding: 10px 20px
- search-orb: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, rounded: {rounded.full}, height: 48px
- icon-button-circle: backgroundColor: {colors.surface-strong}, textColor: {colors.ink}, rounded: {rounded.full}, height: 32px

Color rationale: Brand & Accent - Rausch ({colors.primary} — ff385c): The single brand color. Used for primary CTA backgrounds (Reserve, Continue), the search orb, the heart save state on property layered rectangular token motif, and inline brand links. The most recognizable color in consumer aspirational spatial journey. - Rausch Active ({colors.primary-active} — e00b41): The press / pointer-down variant — slightly more saturated. Used on {component.button-primary-active}. - Rausch Disabled ({colors.primary-disabled} — ffd1da): A pale tint used on disabled CTAs. - Luxe Purple ({colors.luxe} — 460479): Sub-brand accent for the source brand Luxe. Only appears inside Luxe-branded surfaces — never in mainline marketing. - Plus Magenta ({colors.plus} — 92174d): Sub-brand accent for the source brand Plus. Same scoping as Luxe — sub-product only. Surface - Canvas ({colors.canvas} — ffffff): The default page floor for every public page. the source brand does not have a dark mode on the public web. - Surface Soft ({colors.surface-soft} — f7f7f7): The lightest fill — used on disabled fields, sub-nav hover backgrounds, and the inline search filter band. - Surface Strong ({colors.surface-strong} — f2f2f2): S...

Typography rationale: Font Family The system runs the source brand Cereal VF for everything — display, body, navigation, captions, microcopy. Fallbacks walk Circular, -apple-system, system-ui, Roboto, "Helvetica Neue", sans-serif. Circular is the historic in-house typeface still kept as the first non-variable fallback; system stacks back it up. There is no separate display family. The variable font carries the entire scale. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.rating-display} | 64px | 700 | 1.1 | -1px | welcoming place-based environment detail rating display ("4.81") | | {typography.display-xl} | 28px | 700 | 1.43 | 0 | Homepage h1 ("Inspiration for future getaways") | | {typography.display-lg} | 22px | 500 | 1.18 | -0.44px | welcoming place-based environment detail h1 ("Close to Fethiye Aliyah Bali welcoming place-based environment…") | | {typography.display-md} | 21px | 700 | 1.43 | 0 | Section heads inside welcoming place-based environment detail ("What this place offers") | | {typography.display-sm} | 20px | 600 | 1.20 | -0.18px | Sub-section titles ("Things to know") | | {typography.title-md} | 16px | 600 | 1.25 | 0 | City...

Layout system: Spacing System - Base unit: 4px (with 2px micro-step). - Tokens: {spacing.xxs} 2px · {spacing.xs} 4px · {spacing.sm} 8px · {spacing.md} 12px · {spacing.base} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 64px. - Section padding (vertical): {spacing.section} (64px) for major page bands; tighter than typical SaaS marketing (80–96px) because marketplace pages need higher layered rectangular token motif density per scroll. - layered rectangular token motif internal padding: {spacing.lg} (24px) for {component.host-card} and {component.reservation-card}; {spacing.base} (16px) for property-card meta block; {spacing.sm} (8px) for caption / date-row gutters. - Gutters: {spacing.base} (16px) between layered rectangular token motif in the homepage city grid; {spacing.lg} (24px) inside footer column gutters; {spacing.xs} (4px) on dense category-strip dividers. Grid & Container - Max content width: ~1280px centered on the homepage and editorial pages. welcoming place-based environment detail pages cap closer to 1080px to keep the photo banner and reservation rail readable. - City link grid (homepage footer): 6-column grid at desktop with each cell housin...

Depth and hierarchy: The system has essentially one shadow tier plus the flat baseline. - Flat (no shadow): Body, hero, footer, all editorial bands — 95% of surfaces. - layered rectangular token motif hover float: box-shadow: rgba(0, 0, 0, 0.02) 0 0 0 1px, rgba(0, 0, 0, 0.04) 0 2px 6px 0, rgba(0, 0, 0, 0.1) 0 4px 8px 0 — applied to property layered rectangular token motif on pointer hover, the search bar at rest, and the dropdown hospitality-service structure (account hospitality-service structure, language picker, date picker). This is the single shadow definition in the entire system. - Modal scrim: {colors.scrim} rendered at 50% opacity — the global modal backdrop. Used on date pickers, login dialogs, language picker. There are no progressive elevation tiers — the system either has the one shadow or none. Depth comes from photography, the white-on-white surface separation, and rounded-corner clipping rather than from layered shadows.

Component language: Buttons button-primary — Rausch fill, white text, 8px radius, 14×24px padding, 48px height, weight 500. The most common CTA across the system: "Reserve", "Continue", "Search", account-flow primaries. button-primary-active — The press state. Background flips to {colors.primary-active}. No transform, no shadow change. button-primary-disabled — Pale Rausch tint at ffd1da with white text. Cursor not-allowed. button-secondary — White fill with ink text and a 1px ink outline. 8px radius. Used for "Save", "Cancel", and inverse CTAs over Rausch surfaces. button-tertiary-text — Plain ink text, no surface, no border. Underlined on hover. Used for "Show more" type links and modal close labels. button-pill-rausch — A pill-shaped Rausch CTA used on featured cells (e.g., "Become a service relationship cue" sub-CTA) — 9999px radius, 10×20px padding, 14px label. Search Surface search-bar-pill — The signature global search bar. White fill, 9999px radius, 64px height, 1px...
```
