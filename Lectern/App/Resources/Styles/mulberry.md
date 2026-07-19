# Mulberry

**ID:** `mulberry`  
**Category:** developer  
**Theme:** dark  
**Vibe:** Playful

## Color palette

- `#4a154b`
- `#481a54`
- `#611f69`
- `#592466`
- `#ffffff`
- `#1d1d1d`
- `#696969`
- `#1264a3`
- `#3860be`
- `#f4ede4`

## Typography

Families: "Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif", "Salesforce-Sans, system-ui, -apple-system, sans-serif". Weights: 400, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Slack

Design token description: a workplace messaging brand built on a deep aubergine primary, with cream-lavender hero gradients, blue inline links, and pill CTAs. The system pairs a proprietary humanist sans for display with a separate utility sans for body, and stages product UI mockups inside soft pastel-mesh hero composites that act as both decoration and feature explanation.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding.

Overall visual personality: Slacc's design language centers on a deep aubergine primary ({colors.primary}) — the brand's most enduring visual asset — applied as the dominant button color, the footer band, the featured pricing tier, and the brand wordmark. Around that aubergine the system stages an unusually delicate ecosystem: cream-lavender hero canvases with soft pastel-mesh gradients (peachy oranges, lavenders, dusty greens) that pulse behind floating product UI mockups, with the actual interface the source brand rendered in fine detail at 3:2 aspect. Typography splits between two proprietary humanist sans families. The display tier runs at 700 weight at sizes 32–64px with negative letter-spacing for tight optical density on hero headlines. The UI tier uses the second family at 400–700 with slightly relaxed leading (1.55) — the brand's body copy reads quietly without competing with the aubergine moments. Buttons are pill-shaped at 90px radius with an unusual amount of horizontal padding (28–30px), giving them a distinctly comfortable, almost over-padded feel. The primary aubergine pill is the only filled button in most contexts; secondary actions use a soft lavender pill ({colors.canvas-lavender}) which r...

Color tokens:
- primary: #4a154b
- primary-deep: #481a54
- primary-press: #611f69
- primary-tint: #592466
- on-primary: #ffffff
- ink: #1d1d1d
- ink-mute: #696969
- link-blue: #1264a3
- link-hover: #3860be
- canvas: #ffffff
- canvas-cream: #f4ede4
- canvas-lavender: #f9f0ff
- surface-elev: #ffffff
- surface-aubergine: #4a154b

Typography tokens:
- display-xxl: family Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 64px, weight 700, line 1.12, tracking -0.768px
- display-xl: family Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 58px, weight 600, line 1.25, tracking -0.464px
- display-lg: family Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 50px, weight 700, line 1.12, tracking -0.6px
- display-md: family Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 700, line 1.25, tracking -0.256px
- heading-lg: family Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 700, line 1.33, tracking -0.096px
- heading-md: family Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 22px, weight 600, line 1.4, tracking 0
- heading-sm: family Salesforce-Avant-Garde, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 600, line 1.56, tracking -0.0216px
- body-lg: family Salesforce-Sans, system-ui, -apple-system, sans-serif, size 18px, weight 400, line 1.55, tracking -0.0216px
- body-md: family Salesforce-Sans, system-ui, -apple-system, sans-serif, size 16px, weight 400, line 1.55, tracking 0
- body-strong: family Salesforce-Sans, system-ui, -apple-system, sans-serif, size 16px, weight 700, line 1.5, tracking 0.16px
- button-lg: family Salesforce-Sans, system-ui, -apple-system, sans-serif, size 18px, weight 700, line 1.0, tracking 0
- button-md: family Salesforce-Sans, system-ui, -apple-system, sans-serif, size 16px, weight 700, line 1.38, tracking 0.2px

Spacing tokens:
- xs: 4px
- sm: 8px
- md: 12px
- lg: 16px
- xl: 20px
- xxl: 24px
- huge: 28px

Radius and shape tokens:
- xs: 2px
- sm: 4px
- md: 8px
- lg: 12px
- xl: 16px
- xxl: 48px
- pill: 90px

Component tokens:
- button-primary-pill: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 14px 28px
- button-primary-pill-pressed: backgroundColor: {colors.primary-press}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 14px 28px
- button-secondary-pill: backgroundColor: {colors.canvas-lavender}, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 10px 30px
- button-outline-aubergine: backgroundColor: {colors.canvas}, textColor: {colors.primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 14px 28px
- button-outline-on-aubergine: backgroundColor: {colors.surface-aubergine}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 14px 28px
- text-input: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 10px 12px
- pill-cap-shade: backgroundColor: {colors.canvas-cream}, textColor: {colors.ink}, typography: {typography.micro-cap}, rounded: {rounded.pill}, padding: 4px 12px
- card-pricing: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.xl}, padding: 32px

Color rationale: Source pages: home (/), /features/channels, /pricing, /contact-sales. Brand & Accent - Aubergine ({colors.primary} — 4a154b): The brand's primary surface and CTA color. Deep, warm purple with a hint of ruby — used on filled buttons, the featured pricing tier, the footer band, and the brand wordmark. - Aubergine Deep ({colors.primary-deep} — 481a54): A near-identical sibling of {colors.primary} extracted from a different surface; treat as functionally equivalent. - Aubergine Press ({colors.primary-press} — 611f69): Pressed-state lift of the primary, slightly lighter and warmer. - Aubergine Tint ({colors.primary-tint} — 592466): Border accent on aubergine-on-aubergine surfaces. - Link Blue ({colors.link-blue} — 1264a3): Inline link color — saturated, slightly warm blue. The only chromatic alternative to aubergine in body type. - Link Hover ({colors.link-hover} — 3860be): A more saturated blue used on link hover state. Surface - Canvas White ({colors.canvas} — ffffff): Default content surface. - Canvas Cream ({colors.canvas-cream} — f4ede4): Warm off-white used on hero gradients and feature bands. Adds editorial warmth. - Canvas Lavender ({colors.canvas-lavender} — f9f0ff): Pale lave...

Typography rationale: Font Family The display tier is Salesforce Avant Garde — a proprietary humanist sans with broad apertures and a slightly geometric character. When unavailable, fall back to the system font stack (system-ui, -apple-system, BlinkMacSystemFont). The UI tier is Salesforce Sans — a separate proprietary face used for body, captions, and button labels. Same fallback chain. Both faces are proprietary and not freely available. Substitute with Inter (open-source via the source brand Fonts) at matching weights for both display and body — Inter is the closest open analogue across both tiers. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xxl} | 64px | 700 | 1.12 | -0.768px | Marketing hero headline | | {typography.display-xl} | 58px | 600 | 1.25 | -0.464px | Section openers | | {typography.display-lg} | 50px | 700 | 1.12 | -0.6px | Statistics callouts | | {typography.display-md} | 32px | 700 | 1.25 | -0.256px | Card / feature titles | | {typography.heading-lg} | 24px | 700 | 1.33 | -0.096px | Pricing tier names | | {typography.heading-md} | 22px | 600 | 1.4 | 0 | Sub-section heading | | {typography.heading-sm} | 18px |...

Layout system: Spacing System - Base unit: 8px (with 4 / 12 / 16 / 20 / 24 / 28 sub-tokens for fine vertical rhythm). - Tokens: {spacing.xs} 4px · {spacing.sm} 8px · {spacing.md} 12px · {spacing.lg} 16px · {spacing.xl} 20px · {spacing.xxl} 24px · {spacing.huge} 28px. - Section padding: 64–96px on marketing surfaces; tightens to 48px on transactional pages. - Card internal padding: 32px on pricing cards; 48px on aubergine band cards. Grid & Container - Marketing pages center in a ~1240px container with edge-bleeding pastel-mesh gradients escaping the container. - Pricing collapses 4-up → 2-up → 1-up at 992 / 768 breakpoints. - Statistics row: 3-column grid with massive 50px aubergine display numerals. Whitespace Philosophy The pastel-mesh gradients fill most of the negative space on marketing pages — sections feel expansive without being literally empty. On transactional pages the gradients drop, and whitespace reverts to traditional 48px-section breathing room.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 | Flat | Default surface | | 1 | box-shadow: rgba(0,0,0,0.1) 0 5px 20px 0 | Floating buttons on hero | | 2 | box-shadow: rgba(0,0,0,0.1) 0 0 32px 0 | Product UI mockup composites | | 3 | box-shadow: rgba(0,0,0,0.2) 0 1px 10px 0 | Toast / notification the source brand | | 4 | box-shadow: rgb(97,31,105) 0 0 0 1px inset | Aubergine inset border (button focus, special the source brand) | Decorative Depth The brand's depth language is the pastel-mesh gradient — peach, lavender, dusty green stops blurred together at large radii to create soft atmospheric backdrops behind product UI screenshots. The gradient is the brand's flavor of "depth without shadows": the eye perceives the product mockup as floating above a luminous backdrop without any literal lift.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 2px | Hairline tags, status pills (rare) | | {rounded.sm} | 4px | Form inputs | | {rounded.md} | 8px | Compact card the source brand, video frames | | {rounded.lg} | 12px | Mid-size cards, secondary surface | | {rounded.xl} | 16px | Pricing cards, feature cards | | {rounded.xxl} | 48px | Stat badge backdrops | | {rounded.pill} | 90px | All buttons | Photography Geometry The brand uses product UI screenshots more than photography. UI mockups sit on top of pastel-mesh gradients at roughly 4:3 aspect, with no shadow but with the gradient providing the "lift" the eye expects. Real photography appears in customer-logo strips and the occasional case-study card, treated as full-bleed inside {rounded.xl} containers.

Component language: Buttons button-primary-pill — the dominant CTA system-wide. - Background {colors.primary}, text {colors.on-primary}, type {typography.button-md}, padding 14px 28px, rounded {rounded.pill} 90px. - Pressed state button-primary-pill-pressed shifts background to {colors.primary-press}. button-secondary-pill — the soft lavender alternative. - Background {colors.canvas-lavender}, text {colors.ink}, padding 10px 30px, same pill geometry. Used as the second action beside the primary aubergine pill. button-outline-aubergine — outline variant on white surfaces. - Background {colors.canvas}, text {colors.primary}, 2px solid {colors.primary} border, same pill shape. button-outline-on-aubergine — outline on aubergine canvas. - Background {colors.surface-aubergine} (transparent over the surface), text {colors.on-primary}, 2px solid {colors.on-primary} border, same pill shape. Cards & Containers card-pricing — sta...
```
