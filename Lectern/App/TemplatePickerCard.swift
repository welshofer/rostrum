import SwiftUI
import UniformTypeIdentifiers
import LecternCore

struct TemplatePickerCard: View {
    let model: TemplateSelectionModel
    @State private var isChoosing = false
    @State private var pickerProblem: String?

    private static let contentTypes = ["potx", "pptx"].compactMap {
        UTType(filenameExtension: $0)
    }

    var body: some View {
        Card(title: "POWERPOINT TEMPLATE (OPTIONAL)", systemImage: "doc.badge.gearshape") {
            VStack(alignment: .leading, spacing: 12) {
                if let template = model.selected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name).font(.headline).lineLimit(2)
                            .textSelection(.enabled)
                        Text("\(template.widthInches.formatted(.number.precision(.fractionLength(0...2)))) × \(template.heightInches.formatted(.number.precision(.fractionLength(0...2)))) in · \(template.layoutCount) layouts")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Uses this template’s colors, fonts, and slide size. Its \(template.slideCount) existing slides are replaced with new content. Your original file stays unchanged.")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Lectern arranges new content using the first slide master. Placeholder positions and template backgrounds may differ in the generated deck.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Choose a .potx template or use a .pptx deck as a template. Without one, the selected style below sets the design.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if model.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Reading template…").font(.callout)
                    }
                }
                HStack {
                    Button(model.selected == nil ? "Choose Template…" : "Replace Template…") {
                        pickerProblem = nil
                        isChoosing = true
                    }
                    .disabled(model.isLoading)
                    if model.selected != nil || model.isLoading {
                        Button(model.isLoading ? "Cancel Import" : "Remove Template") {
                            if model.isLoading { model.cancelImport() } else { model.clear() }
                            pickerProblem = nil
                        }
                    }
                }
                if let problem = pickerProblem ?? model.problem {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                    if model.selected != nil {
                        Text("The previous template is still selected.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .fileImporter(isPresented: $isChoosing, allowedContentTypes: Self.contentTypes) { result in
            // Dismissing the system picker leaves the existing choice intact.
            if case .failure(let error) = result,
               (error as NSError).domain == NSCocoaErrorDomain,
               (error as NSError).code == NSUserCancelledError { return }
            pickerProblem = FileImportOutcome.handle(result) { model.select($0) }
        }
    }
}
