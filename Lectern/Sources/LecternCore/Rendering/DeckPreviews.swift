import Foundation
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
    private let otherWarnings: [String]

    init(slideNumber: Int, problems: SlideRenderProblems = .init(), failure: String? = nil) {
        self.slideNumber = slideNumber
        layoutUnresolved = problems.layoutUnresolved
        masterUnresolved = problems.masterUnresolved
        issues = problems.fidelityIssues.map(PreviewFidelityIssue.init)
        self.failure = failure
        otherWarnings = problems.unsupportedContent
    }

    /// Compact, stable display text. The complete findings above retain each
    /// source location; repeated messages at many shapes need only one row.
    public var messages: [String] {
        var result: [String] = []
        if failure != nil { result.append("Preview could not be rendered.") }
        if layoutUnresolved { result.append("The slide layout could not be loaded; its content is missing from this preview.") }
        if masterUnresolved { result.append("The slide master could not be loaded; its content is missing from this preview.") }
        result += otherWarnings
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
    private(set) var records: [SlidePreviewRecord] = []
    private(set) var diagnostics: [SlidePreviewDiagnostics] = []
    var svgs: [String] { records.map(\.displaySVG) }
    var titles: [String] { records.map(\.title) }
    var slideNumbers: [Int] { records.map(\.number) }
    var warnings: [String] { records.flatMap { r in r.warnings.map { "Slide \(r.number): \($0)" } } }

    /// The shared inspection profile. Callers register embedded fonts first;
    /// exact installed faces then fill any gaps, with an explicit preview-only
    /// fallback. Generation's measurement aliases never enter this registry.
    static func render(from presentation: Presentation, explicitFonts: Set<String>? = nil,
                       onProgress: (Int, Int) -> Void = { _, _ in }) throws -> DeckPreviews {
        try Task.checkCancellation()
        let families = try PipelineTrace.measure("preview.fontDiscovery") {
            try InspectionFonts.families(in: presentation, explicit: explicitFonts)
        }
        _ = PipelineTrace.measure("preview.installedFonts") {
            InstalledFonts.register(in: presentation, families: families + ["Arial", "Apple Symbols"])
        }
        presentation.fonts.previewFallbackFamily = "Arial"
        presentation.fonts.previewSymbolFallbackFamilies = ["Apple Symbols", "Arial"]
        let total = presentation.slides.count
        var result = DeckPreviews()
        onProgress(0, total)
        for index in 0..<total {
            try Task.checkCancellation()
            result.append(slideAt: index, from: presentation)
            onProgress(index + 1, total)
        }
        try Task.checkCancellation()
        return result
    }

    /// Preview the bytes we saved, with the same font setup as Inspect. Avoid
    /// the inspector's unrelated outline/schema work and keep preview failures
    /// from turning a successful save into a failed generation or recovery.
    static func savedDeck(at url: URL, failureContext: Presentation) -> DeckPreviews {
        do {
            try Task.checkCancellation()
            let presentation = try PipelineTrace.measure("preview.reopen") {
                try Presentation(data: Data(contentsOf: url),
                    limits: .init(totalUncompressedBytes: DeckInspector.defaultReadLimit))
            }
            _ = PipelineTrace.measure("preview.embeddedFonts") { presentation.registerEmbeddedFonts() }
            return try render(from: presentation)
        } catch is CancellationError {
            return DeckPreviews()
        } catch {
            var result = DeckPreviews()
            let geometry = SlidePreviewGeometry(width: failureContext.slideSize.width.inches,
                                                height: failureContext.slideSize.height.inches)
            for index in 0..<failureContext.slides.count {
                let title = (try? failureContext.slides[index].title?.textFrame?.text) ?? ""
                result.records.append(.init(number: index + 1, title: title, svg: nil,
                                            geometry: geometry, warnings: ["Preview unavailable."]))
                result.diagnostics.append(.init(slideNumber: index + 1, failure: String(describing: error)))
            }
            return result
        }
    }

    mutating func append(slideAt index: Int, from presentation: Presentation) {
        let title = (try? presentation.slides[index].title?.textFrame?.text) ?? ""
        let geometry = SlidePreviewGeometry(width: presentation.slideSize.width.inches, height: presentation.slideSize.height.inches)
        do {
            let result = try PipelineTrace.measure("preview.svg", slideNumber: index + 1) {
                try presentation.renderSVGReportingProblems(slideAt: index, pixelWidth: 640)
            }
            records.append(.init(number: index + 1, title: title, svg: result.svg, geometry: geometry, warnings: result.problems.messages))
            if !result.problems.isEmpty {
                diagnostics.append(SlidePreviewDiagnostics(slideNumber: index + 1, problems: result.problems))
            }
        } catch {
            records.append(.init(number: index + 1, title: title, svg: nil, geometry: geometry, warnings: ["Preview unavailable."]))
            diagnostics.append(SlidePreviewDiagnostics(slideNumber: index + 1, failure: String(describing: error)))
        }
    }
}
