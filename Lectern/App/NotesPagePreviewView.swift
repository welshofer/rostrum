import SwiftUI
import LecternCore

struct NotesPagePreviewView: View {
    let request: NotesPagePreviewRequest
    @Environment(\.dismiss) private var dismiss
    @State private var model = NotesPagePreviewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let preview = model.preview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !preview.diagnostics.messages.isEmpty {
                                DisclosureGroup("Notes preview limitations") {
                                    ForEach(preview.diagnostics.messages, id: \.self) { message in
                                        Text(message)
                                            .font(.caption).foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            SlidePreview(svg: preview.svg)
                                .aspectRatio(SlidePreviewGeometry(svg: preview.svg)?.aspectRatio ?? 8.5 / 11,
                                             contentMode: .fit)
                                .accessibilityLabel("Notes page for slide \(request.slideNumber)")
                        }
                        .padding()
                    }
                } else if let problem = model.problem {
                    ContentUnavailableView {
                        Label("Couldn't preview notes", systemImage: "doc.text")
                    } description: {
                        Text(problem)
                    } actions: {
                        Button("Try again") { model.load(request) }
                    }
                } else {
                    ProgressView("Rendering notes page…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Slide \(request.slideNumber) notes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { model.cancel(); dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, idealWidth: 620, minHeight: 480, idealHeight: 720)
        #endif
        .task(id: request) { model.load(request) }
        .onDisappear { model.cancel() }
    }
}
