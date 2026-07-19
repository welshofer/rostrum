# Basalt

**ID:** `basalt`  
**Category:** developer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#101317`
- `#181c21`
- `#22272e`
- `#7395ae`
- `#93b3ca`
- `#4f6e84`
- `#e4e8ec`
- `#b3bcc4`
- `#737e88`
- `#2e353d`

## Typography

Families: Consolas, Verdana. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Consolas
- body: Verdana

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)
Design system name: Basalt
Design token description: Basalt is a terminal-grade technical system on volcanic black, #101317, with editor-panel surfaces #181c21 and #22272e ruled by #2e353d keylines — the layered greys of a well-themed IDE, never pure black. Text is ash-white: #e4e8ec primary, #b3bcc4 secondary, #737e88 for comments, paths, and metadata, exactly like a syntax theme's comment tone. The accent is steel-blue #7395ae for tokens that matter: headings' prompt markers, inline code keywords, primary chart series, and active states; it lifts to #93b3ca for fine strokes and small labels and drops to #4f6e84 for large fills and selection blocks. Headings are set in Consolas 700 — monospaced on purpose, so titles read like commands — often prefixed with a #7395ae glyph such as $, >, or //; Consolas 400 renders literals, code, and figures. Body text is Verdana 400 for maximum screen legibility at distance, with Verdana 600 for labels and emphasis. Alignment is column-exact, as if every slide were rendered in a character grid. The personality is a senior engineer's conference talk: precise, monochrome-plus-one, quietly confident, zero decoration.
STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.
Overall visual personality: an IDE-dark engineering console rendered in ash and steel-blue.
Reusable visual grammar extracted from DESIGN.md:
- Character-grid discipline: content aligns to a fixed column rhythm, echoing monospace layout even in Verdana passages.
- Titles read as commands: Consolas 700 with a steel-blue prompt glyph ($, >, //) at the left margin on every content slide.
- Panels #181c21/#22272e behave like editor splits — butted, keylined with #2e353d, never floating or shadowed.
- Code and literals always render in Consolas 400 on #22272e blocks with 16px padding and no rounding beyond 4px.
- Hierarchy uses weight and tone only: ash-white for signal, #b3bcc4 for support, #737e88 for comment-level asides.
- Steel-blue is a token color, not a wash: it marks the operative word, the active node, the current step.
- Diagrams prefer orthogonal connectors with 90-degree bends, like well-drawn architecture ASCII.
Chart and infographic grammar:
- Series order: steel #7395ae, light steel #93b3ca, ash #b3bcc4, deep steel #4f6e84; monochrome ramps beat rainbow categoricals.
- Dark-mode rules: gridlines #2e353d, axis labels Verdana 400 #b3bcc4, values Verdana 600 #e4e8ec; fine blue strokes use #93b3ca for contrast.
- Axis and tick labels may render in Consolas 400 when values are code-adjacent (versions, ports, latencies).
- Highlight exactly one series or point per chart in #93b3ca with a Consolas annotation; everything else recedes to greys.
Image and illustration grammar:
- Render slide-JSON subjects as technical and matter-of-fact: hardware, terminals, abstract systems in cool greys with steel-blue rim light.
- Screenshots and diagrams sit in #22272e editor frames with a #2e353d keyline and a #737e88 title-bar caption in Consolas.
- No lifestyle gloss; if atmosphere is needed, use basalt-textured dark abstracts graded to the palette.
Slide graphic system:
- Icons are 1.5px ash strokes drawn on a square grid, terminal-flavored (chevrons, brackets, nodes), with steel-blue for the active one.
- Dividers print an oversized Consolas 700 numeral in #4f6e84 with a #7395ae prompt glyph and a single keyline.
- Status and step markers are square, not round, filled #22272e with steel-blue borders when current.
```
