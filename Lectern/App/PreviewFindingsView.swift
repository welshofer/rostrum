import SwiftUI
import LecternCore

/// Grouped preview limitations, with unverified-rendering notes kept apart so
/// a deck-wide caveat does not read as a problem on every slide.
struct PreviewFindingsView: View {
    let groups: [PreviewFindingGroup]
    var limitationNote = "These affect Lectern’s preview. The original PowerPoint content is preserved."

    var body: some View {
        let limitations = groups.filter { !$0.isVerificationNote }
        let verification = groups.filter(\.isVerificationNote)
        if !limitations.isEmpty {
            list(limitations, title: "Preview limitations", explanation: limitationNote)
        }
        if !verification.isEmpty {
            list(verification, title: "Fidelity verification notes",
                 explanation: "These rendering cases have not been verified against PowerPoint. They do not by themselves indicate missing or damaged content.")
        }
    }

    private func list(_ groups: [PreviewFindingGroup], title: String, explanation: String) -> some View {
        DisclosureGroup("\(title) (\(groups.count))") {
            Text(explanation).font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(groups) { group in
                Text("\(group.slideLabel): \(group.message)")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
