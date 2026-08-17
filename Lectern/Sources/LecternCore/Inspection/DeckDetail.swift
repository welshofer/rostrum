import Foundation
import Rostrum

/// The deeper reading of a deck: who wrote it, what type it is, which fonts it
/// leans on, how its masters are built, and what its charts actually plot.
///
/// `DeckInspection` answers "what is in this file"; these answer "and what is
/// it made of". They are plain values for the same reason `SlideDigest` is —
/// LecternCore is the app's entire API surface, so nothing below it crosses.

// MARK: - Document properties

public struct DeckPropertyInspection: Sendable, Equatable {
    public let title: String?
    public let author: String?
    public let subject: String?
    public let comments: String?
    public let keywords: String?
    public let category: String?
    public let company: String?
    public let application: String?
    public let created: Date?
    public let modified: Date?

    /// Nothing worth showing a person — every field a deck could name itself
    /// with came back empty.
    public var isEmpty: Bool {
        title == nil && author == nil && subject == nil && comments == nil
            && keywords == nil && category == nil && company == nil
            && application == nil && created == nil && modified == nil
    }
}

// MARK: - Masters

public struct MasterInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let name: String
    public let layoutNames: [String]
    public let majorFont: String?
    public let minorFont: String?

    public var id: Int { index }
}

// MARK: - Sections

public struct SectionInspection: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let slideIndices: [Int]

    public var slideCount: Int { slideIndices.count }
}

// MARK: - Comments

public struct CommentInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let author: String
    public let text: String
    public let replyCount: Int
    public let resolved: Bool

    public var id: Int { index }
}

// MARK: - Charts

public struct ChartInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let slideIndex: Int
    public let title: String
    public let plotTypes: [String]
    public let categories: [String]
    public let series: [ChartSeriesInspection]
    /// Whether Lectern could write new numbers back into this chart.
    public let canReplaceData: Bool
    public let replacementProblem: String?

    public var id: Int { index }
}

public struct ChartSeriesInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let name: String
    public let values: [Double?]

    public var id: Int { index }
}

// MARK: - Errors

/// Why a deck could not be inspected at all.
///
/// Distinct from a *finding*: a finding is a fact about a file that opened,
/// while these mean there was nothing to read.
public enum DeckInspectionError: Error, Sendable, Equatable, CustomStringConvertible {
    case emptyFile
    case cannotOpen(String)

    public var description: String {
        switch self {
        case .emptyFile:
            "The selected file is empty."
        case .cannotOpen(let message):
            "Rostrum could not open this PowerPoint file: \(message)"
        }
    }
}

// MARK: - Extraction

/// The single walk over an opened deck that produces everything
/// `DeckInspection` reports beyond its part counts.
///
/// One pass, because a sixty-slide deck with photographic media is seconds of
/// work and there is no reason to pay for it more than once.
enum DeckDetailExtractor {
    struct Result {
        var slideDetails: [Int: SlideDetail] = [:]
        var charts: [ChartInspection] = []
        var explicitFonts: Set<String> = []
        var issues: [String] = []
    }

    /// The per-slide facts that come from the slide itself rather than from
    /// Rostrum's outline.
    struct SlideDetail {
        var layoutName: String
        var masterName: String
        var shapeCounts: [String: Int]
        var comments: [CommentInspection]
        var mediaCount: Int
        var chartIndices: [Int]
    }

    static func walk(_ presentation: Presentation) -> Result {
        var result = Result()
        var chartIndex = 0

        for index in 0..<presentation.slides.count {
            let slide: Slide
            do {
                slide = try presentation.slides.slide(at: index)
            } catch {
                // One unreadable slide is a finding, not a failed inspection.
                result.issues.append("slide \(index + 1) cannot be resolved: \(error)")
                continue
            }

            let shapes = flatten(slide.shapes.all)

            var counts: [String: Int] = [:]
            for shape in shapes {
                counts[name(of: shape.kind), default: 0] += 1
                for paragraph in shape.textFrame?.paragraphs ?? [] {
                    for run in paragraph.runs {
                        if let font = run.fontName, !font.isEmpty {
                            result.explicitFonts.insert(font)
                        }
                    }
                }
            }

            let slideCharts = slide.charts
            let indices = Array(chartIndex..<(chartIndex + slideCharts.count))
            for chart in slideCharts {
                let data = chart.data
                let problem = data.flatMap { chart.replacementProblem(for: $0) }
                result.charts.append(ChartInspection(
                    index: chartIndex,
                    slideIndex: index,
                    title: chart.title ?? "Chart \(chartIndex + 1)",
                    plotTypes: chart.plotTypes,
                    categories: chart.categories,
                    series: chart.series.enumerated().map { seriesIndex, series in
                        ChartSeriesInspection(index: seriesIndex,
                                              name: series.name,
                                              values: series.values)
                    },
                    canReplaceData: data != nil && problem == nil,
                    replacementProblem: problem.map(String.init(describing:))))
                chartIndex += 1
            }

            result.slideDetails[index] = SlideDetail(
                layoutName: slide.layout?.name ?? "Unknown layout",
                masterName: slide.master?.name ?? "",
                shapeCounts: counts,
                comments: slide.comments.enumerated().map { commentIndex, comment in
                    CommentInspection(index: commentIndex,
                                      author: comment.authorName ?? "Unknown",
                                      text: comment.text,
                                      replyCount: comment.replies.count,
                                      resolved: comment.isResolved)
                },
                mediaCount: shapes.compactMap { $0 as? Picture }.filter(\.isMedia).count,
                chartIndices: indices)
        }
        return result
    }

    static func masters(of presentation: Presentation) -> [MasterInspection] {
        presentation.slideMasters.enumerated().map { index, master in
            MasterInspection(index: index,
                             name: master.name,
                             layoutNames: master.layouts.map(\.name),
                             majorFont: master.theme?.majorFont,
                             minorFont: master.theme?.minorFont)
        }
    }

    static func properties(of presentation: Presentation) -> DeckPropertyInspection {
        let properties = presentation.documentProperties
        return DeckPropertyInspection(title: properties.title,
                                      author: properties.author,
                                      subject: properties.subject,
                                      comments: properties.comments,
                                      keywords: properties.keywords,
                                      category: properties.category,
                                      company: properties.company,
                                      application: properties.application,
                                      created: properties.created,
                                      modified: properties.modified)
    }

    static func themeFonts(of presentation: Presentation) -> [String] {
        let fonts = [presentation.theme.majorFont, presentation.theme.minorFont]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return Array(Set(fonts)).sorted()
    }

    static func flatten(_ shapes: [Shape]) -> [Shape] {
        shapes.flatMap { shape in
            guard let group = shape as? GroupShape else { return [shape] }
            return [shape] + flatten(group.shapes)
        }
    }

    static func name(of kind: DocumentKind) -> String {
        switch kind {
        case .presentation: "Presentation (.pptx)"
        case .template: "Template (.potx)"
        case .slideShow: "Slide show (.ppsx)"
        }
    }

    static func name(of kind: ShapeKind) -> String {
        switch kind {
        case .autoShape: "Text / shape"
        case .picture: "Picture"
        case .connector: "Connector"
        case .group: "Group"
        case .table: "Table"
        case .chart: "Chart"
        case .diagram: "SmartArt"
        case .graphicFrame: "Other graphic"
        case .other: "Other"
        }
    }
}
