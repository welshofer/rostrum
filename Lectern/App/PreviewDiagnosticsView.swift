import SwiftUI
import LecternCore

/// The same preview caveats belong beside generated and imported decks.
struct PreviewDiagnosticsView: View {
    let diagnostics: [SlidePreviewDiagnostics]

    var body: some View {
        DisclosureGroup("\(diagnostics.count) slide(s) with preview limitations") {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("These previews have known differences or missing content. Check affected slides in PowerPoint before presenting.")
                        .foregroundStyle(.secondary)
                    ForEach(diagnostics) { slide in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Slide \(slide.slideNumber)").fontWeight(.semibold)
                            ForEach(slide.messages, id: \.self) { message in
                                Text(message).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
            .frame(maxHeight: 180)
        }
    }
}
