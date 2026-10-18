import SwiftUI
import LecternCore

/// Preview limitations grouped by issue, each naming the slides it affects.
struct PreviewLimitationsView: View {
    let warnings: [String]
    let slideCount: Int
    var note: String? = "These affect Lectern’s preview. The original PowerPoint content is preserved."

    var body: some View {
        let limitations = PreviewLimitation.grouped(warnings)
        DisclosureGroup("Preview limitations (\(limitations.count))") {
            VStack(alignment: .leading, spacing: 8) {
                if let note { Text(note).foregroundStyle(.secondary) }
                ForEach(limitations, id: \.self) { limitation in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(limitation.message)
                        Text(limitation.slideSummary(slideCount: slideCount))
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.caption)
            .textSelection(.enabled)
            .padding(.top, 4)
        }
    }
}
