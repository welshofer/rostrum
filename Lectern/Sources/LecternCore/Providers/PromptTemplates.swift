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

        Layout vocabulary (each slide has an "id", "layout", optional "title", "body", and "notes"):
        - title            body: { subtitle? }               (exactly one, first)
        - agenda           body: { items: [string] }         (at most one)
        - sectionHeader    body: { kicker? }
        - bullets          body: { bullets: [{ text, subBullets?: [string] }] }
        - twoColumn        body: { left: { heading, bullets: [string] }, right: {…} }
        - comparison       same shape as twoColumn
        - quote            body: { quote, attribution? }
        - bigNumber        body: { value, label }
        - closing          body: { callToAction?, contact? }  (at most one, last)

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
