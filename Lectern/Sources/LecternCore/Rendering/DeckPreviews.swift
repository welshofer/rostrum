import Rostrum

/// A renderer finding copied into values the app can keep across actors,
/// without importing Rostrum or retaining a presentation's XML tree.
public struct PreviewFidelityIssue: Sendable, Equatable {
    public let code: String
    public let impact: String
    public let message: String
    public let partURI: String
    public let shapeID: String?
    public let path: String

    init(_ issue: FidelityIssue) {
        code = issue.code.rawValue
        impact = issue.impact.rawValue
        message = issue.message
        partURI = issue.location.partURI
        shapeID = issue.location.shapeID
        path = issue.location.path
    }
}

/// Known limitations of one preview, separate from plan warnings, schema
/// issues and content lost during deck construction. An empty diagnostic
/// list means no known gaps were detected, not that Office fidelity is proven.
public struct SlidePreviewDiagnostics: Sendable, Equatable, Identifiable {
    /// The original, one-based deck position, even when earlier previews fail.
    public let slideNumber: Int
    public var id: Int { slideNumber }
    public let layoutUnresolved: Bool
    public let masterUnresolved: Bool
    public let issues: [PreviewFidelityIssue]
    /// A render failure leaves the saved deck available and affects only this
    /// slide's thumbnail. Keep the error for inspection, not as a plan warning.
    public let failure: String?

    init(slideNumber: Int, problems: SlideRenderProblems = .init(), failure: String? = nil) {
        self.slideNumber = slideNumber
        layoutUnresolved = problems.layoutUnresolved
        masterUnresolved = problems.masterUnresolved
        issues = problems.fidelityIssues.map(PreviewFidelityIssue.init)
        self.failure = failure
    }

    /// Compact, stable display text. The complete findings above retain each
    /// source location; repeated messages at many shapes need only one row.
    public var messages: [String] {
        var result: [String] = []
        if failure != nil { result.append("Preview could not be rendered.") }
        if layoutUnresolved { result.append("The slide layout could not be loaded; its content is missing from this preview.") }
        if masterUnresolved { result.append("The slide master could not be loaded; its content is missing from this preview.") }
        var seen = Set(result)
        for issue in issues {
            // The specific broken-link messages above are more useful than
            // the renderer's combined layout/master finding, retained in issues.
            if issue.code == FidelityIssueCode.unresolvedInheritance.rawValue,
               layoutUnresolved || masterUnresolved { continue }
            if seen.insert(issue.message).inserted { result.append(issue.message) }
        }
        return result
    }
}

/// Shared by generation and inspection so neither path silently drops the
/// renderer's diagnostics. Each slide renders exactly once, permissively.
struct DeckPreviews {
    private(set) var svgs: [String] = []
    private(set) var titles: [String] = []
    private(set) var slideNumbers: [Int] = []
    private(set) var diagnostics: [SlidePreviewDiagnostics] = []

    mutating func append(slideAt index: Int, from presentation: Presentation) {
        do {
            let result = try presentation.renderSVGReportingProblems(slideAt: index, pixelWidth: 640)
            svgs.append(result.svg)
            titles.append((try? presentation.slides[index].title?.textFrame?.text) ?? "")
            slideNumbers.append(index + 1)
            if !result.problems.isEmpty {
                diagnostics.append(SlidePreviewDiagnostics(slideNumber: index + 1, problems: result.problems))
            }
        } catch {
            diagnostics.append(SlidePreviewDiagnostics(slideNumber: index + 1, failure: String(describing: error)))
        }
    }
}
