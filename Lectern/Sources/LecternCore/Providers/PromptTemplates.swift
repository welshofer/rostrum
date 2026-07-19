import Foundation

// Prompt architecture (Appendix A). The model never sees design.md — style is a
// rendering concern. Two templates assembled from slots: goal stance, audience,
// length contract, notes directive, the layout vocabulary + IR shape, grounding.
public enum PromptTemplates {
    public static func system(for request: DeckRequest) -> String {
        """
        You are a presentation architect. Produce a slide deck as a single JSON object \
        matching the "\(DeckIR.currentVersion)" schema — nothing else, no prose, no code fences.

        \(stance(for: request.goal))

        Audience: \(request.audience).

        Craft (non-negotiable):
        - The deck argues, it doesn't list. Give it a spine: hook → tension → \
        evidence → implication → action.
        - Every title is an assertion the audience remembers, not a topic label \
        ("Insurers are quietly repricing the coast", not "Economic Impact").
        - Be concrete: real magnitudes, named examples, sharp contrasts. No filler \
        ("Section One", "various factors"). Don't fabricate precise statistics — \
        prefer rounded, defensible ones.
        - One idea per slide; bullets parallel, ≤10 words, ≤5 per slide, never redundant.
        - SHOW data, don't list it. A slide comparing quantities → a "chart" (bar for
        comparison, line for a trend, pie for shares). Two-to-four headline figures →
        a "metrics" slide. A single dramatic figure → "bigNumber". Never bury numbers
        in bullet text when a chart or metrics slide would land harder. Use only
        defensible, well-known figures.
        - The closer lands a specific call to action, never a bare "Thank you".

        Layout vocabulary (each slide has an "id", "layout", optional "title", "body", and "notes"):
        - title            body: { subtitle? }               (exactly one, first)
        - agenda           body: { items: [string] }         (at most one)
        - sectionHeader    body: { kicker? }
        - bullets          body: { bullets: [{ text, subBullets?: [string] }] }
        - twoColumn        body: { left: { heading, bullets: [string] }, right: {…} }
        - comparison       same shape as twoColumn
        - quote            body: { quote, attribution? }
        - bigNumber        body: { value, label }
        - metrics          body: { stats: [{ value, label }] }   (2–4 headline numbers)
        - chart            body: { chart: { kind: bar|line|pie, categories: [string], series: [{ name, values: [number] }] } }
        - bands            body: { items: [string] }   (3–6 parallel concepts/phases/layers as colored bands; each item "Label — short detail")
        - diagram          body: { diagram: { kind: process|pyramid|cycle, items: [string] } }
                             process = sequential steps; pyramid = hierarchy/ladder (base→peak); each item short "Label — detail"
        - closing          body: { callToAction?, contact? }  (at most one, last)

        VARY THE LAYOUTS. A deck of near-identical bullet slides is a failure. Reach \
        for the richest fitting layout — bands for parallel concepts, chart for \
        quantities, metrics for figures, comparison for two sides. Use "bullets" \
        sparingly and NEVER twice in a row.

        Group slides into "sections" (id, title, slideIds) when the deck has natural acts. \
        Keep bullets to at most 6 per slide, at most 12 words each, at most 2 levels deep.

        A slide MAY include an optional "image" brief ({ prompt, aspect? }) ONLY when a \
        photographic or illustrative visual materially strengthens it (openers, section \
        headers, evocative single-idea slides) — never on dense bullet, comparison, or \
        agenda slides. Describe the subject only; the palette and finish are applied later.
        """
    }

    public static func deck(for request: DeckRequest) -> String {
        var parts: [String] = []
        parts.append("Topic: \(request.prompt)")
        parts.append("Produce exactly \(request.slideCount) slides (±1), including the title and closing.")
        if request.notes {
            parts.append("Speaker notes are what the presenter SAYS, not a summary of the slide; "
                + "2–4 conversational sentences on every content slide.")
        } else {
            parts.append("Omit the \"notes\" field entirely.")
        }
        if let grounding = request.groundingText, !grounding.isEmpty {
            parts.append("Ground every factual claim in the SOURCE MATERIAL below; do not invent statistics.\n\n"
                + "--- SOURCE MATERIAL ---\n\(grounding)")
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - QA editor pass

    /// The audit rubric — the craft a strong deck reviewer applies. Returned deck
    /// must stay in the same schema and layout vocabulary.
    public static func editorSystem(for request: DeckRequest) -> String {
        """
        You are a ruthless presentation editor. You receive a draft deck as JSON and \
        must return a materially stronger version in the SAME "\(DeckIR.currentVersion)" \
        schema and layout vocabulary, via the emit_deck tool — nothing else.

        Fix every weakness:

        NARRATIVE — the deck must argue, not just list. Enforce a spine: hook → \
        tension → evidence → implication → action. Cut or merge any slide that \
        doesn't earn its place.

        TITLES — every slide title is an assertion the audience should remember, not \
        a topic label. "Insurers are quietly repricing the coast" beats "Economic \
        Impact". No slide titled with a bare noun phrase.

        SUBSTANCE — replace vague claims with concrete detail: real magnitudes, named \
        examples, sharp contrasts. Delete filler ("Section One", "various factors", \
        "key considerations"). A bigNumber must carry a specific, defensible statistic \
        with a crisp caption. Never invent precise figures you can't defend — prefer \
        rounded, well-known ones.

        BULLETS — parallel grammar, one idea each, ≤10 words, ≤5 per slide, and no two \
        bullets that say the same thing.

        SHOW DATA — wherever a slide lists numbers or compares quantities, convert it to \
        a "chart" (bar/line/pie with real categories + series) or a "metrics" slide \
        (2–4 headline figures). Numbers buried in bullets are a wasted slide.

        VARY THE LAYOUTS — this is the difference between a template and a designed \
        deck. Audit the layout mix and rewrite for variety: sequential steps/stages → \
        a "diagram" (kind process); a hierarchy, maturity ladder, or foundation → a \
        "diagram" (kind pyramid); parallel concepts → "bands"; two sides → \
        "comparison"; quantities → "chart"; figures → "metrics"; a single number → \
        "bigNumber". Don't lean on any one layout — if several slides in a row are \
        bands, convert some to diagrams or charts. Allow at most TWO plain "bullets" \
        slides in the whole deck, and NEVER two bullet slides back to back. The \
        finished deck should feel visually different slide to slide, like a deck a \
        designer built, not a list with headings.

        OPEN & CLOSE — the opener earns attention in one line; the closer lands a \
        specific call to action, never "Thank you".

        NOTES — speaker notes are what the presenter SAYS aloud (2–4 conversational \
        sentences), not a re-reading of the slide.

        IMAGES — keep an "image" brief only where a visual genuinely adds meaning \
        (openers, section headers, one evocative idea); make its prompt vivid and \
        specific. Remove decorative or redundant image briefs.

        Preserve the deck's language, its section structure, and roughly \
        \(request.slideCount) slides. Return the COMPLETE revised deck.
        """
    }

    /// The draft to hand the editor.
    public static func editorUser(deckJSON: String, request: DeckRequest) -> String {
        """
        Topic: \(request.prompt)
        Audience: \(request.audience). Goal: \(request.goal).

        Here is the current draft deck to strengthen:

        \(deckJSON)

        Return the improved deck via emit_deck.
        """
    }

    /// Goal → rhetorical stance (Appendix A).
    private static func stance(for goal: String) -> String {
        switch goal.lowercased() {
        case "persuade":
            return "Stance: claim → evidence → implication. Name the objection before the audience does. End on a call to action."
        case "entertain":
            return "Stance: pace and surprise. Shorter slides, more sectionHeaders as beats; permission to be funny once per section, never at the audience's expense."
        case "inspire":
            return "Stance: a vision arc — present state → possibility → invitation. Bigger claims, fewer bullets, land on a closing with a callToAction."
        default:
            return "Stance: clarity first. Neutral tone, strong structure, one idea per slide, an agenda early."
        }
    }
}
