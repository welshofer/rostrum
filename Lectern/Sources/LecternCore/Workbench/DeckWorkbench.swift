import Foundation
import Rostrum

/// A Sendable, read-only description of a PowerPoint document.
///
/// `Presentation` is deliberately not Sendable. `DeckWorkbench` owns it inside
/// an actor and returns this value model to the app.
public struct DeckInspection: Sendable, Equatable {
    public let sourceURL: URL
    public let fileName: String
    public let byteCount: Int
    public let documentKind: String
    public let slideCount: Int
    public let slideWidthEMU: Int
    public let slideHeightEMU: Int
    public let properties: DeckPropertyInspection
    public let themeFonts: [String]
    public let explicitFonts: [String]
    public let embeddedFonts: [String]
    public let masters: [MasterInspection]
    public let sections: [SectionInspection]
    public let slides: [SlideInspection]
    public let charts: [ChartInspection]
    public let validationIssues: [String]

    public init(
        sourceURL: URL,
        fileName: String,
        byteCount: Int,
        documentKind: String,
        slideCount: Int,
        slideWidthEMU: Int,
        slideHeightEMU: Int,
        properties: DeckPropertyInspection,
        themeFonts: [String],
        explicitFonts: [String],
        embeddedFonts: [String],
        masters: [MasterInspection],
        sections: [SectionInspection],
        slides: [SlideInspection],
        charts: [ChartInspection],
        validationIssues: [String]
    ) {
        self.sourceURL = sourceURL
        self.fileName = fileName
        self.byteCount = byteCount
        self.documentKind = documentKind
        self.slideCount = slideCount
        self.slideWidthEMU = slideWidthEMU
        self.slideHeightEMU = slideHeightEMU
        self.properties = properties
        self.themeFonts = themeFonts
        self.explicitFonts = explicitFonts
        self.embeddedFonts = embeddedFonts
        self.masters = masters
        self.sections = sections
        self.slides = slides
        self.charts = charts
        self.validationIssues = validationIssues
    }
}

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
}

public struct MasterInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let name: String
    public let layoutNames: [String]
    public let majorFont: String?
    public let minorFont: String?

    public var id: Int { index }
}

public struct SectionInspection: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let slideIndices: [Int]
}

public struct SlideInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let headline: String
    public let text: String
    public let layoutName: String
    public let masterName: String
    public let shapeCounts: [String: Int]
    public let notes: String
    public let comments: [CommentInspection]
    public let chartIndices: [Int]
    public let mediaCount: Int

    public var id: Int { index }
}

public struct CommentInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let author: String
    public let text: String
    public let replyCount: Int
    public let resolved: Bool

    public var id: Int { index }
}

public struct ChartInspection: Sendable, Equatable, Identifiable {
    public let index: Int
    public let slideIndex: Int
    public let title: String
    public let plotTypes: [String]
    public let categories: [String]
    public let series: [ChartSeriesInspection]
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

public enum DeckWorkbenchError: Error, Sendable, Equatable, CustomStringConvertible {
    case emptyFile
    case cannotOpen(String)
    case slideOutOfRange(Int)

    public var description: String {
        switch self {
        case .emptyFile:
            "The selected file is empty."
        case .cannotOpen(let message):
            "Rostrum could not open this PowerPoint file: \(message)"
        case .slideOutOfRange(let index):
            "Slide \(index + 1) is outside this deck."
        }
    }
}

/// Owns one opened presentation and is the only place it may be read or
/// mutated. The first slice is intentionally read-only; edit operations build
/// on this actor so `Presentation` never crosses an isolation boundary.
public actor DeckWorkbench {
    public let sourceURL: URL

    private let presentation: Presentation
    private let byteCount: Int
    private let embeddedFonts: [String]

    public init(data: Data, sourceURL: URL) throws {
        guard !data.isEmpty else { throw DeckWorkbenchError.emptyFile }
        do {
            let presentation = try Presentation(data: data)
            self.presentation = presentation
            self.sourceURL = sourceURL
            self.byteCount = data.count
            self.embeddedFonts = presentation.registerEmbeddedFonts().sorted()
        } catch {
            throw DeckWorkbenchError.cannotOpen(String(describing: error))
        }
    }

    /// Read the entire document into a Sendable inspection model.
    public func inspect() throws -> DeckInspection {
        let slides = try inspectedSlides()
        let charts = try inspectedCharts()
        let properties = presentation.documentProperties
        let themeFonts = [presentation.theme.majorFont, presentation.theme.minorFont]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        return DeckInspection(
            sourceURL: sourceURL,
            fileName: sourceURL.lastPathComponent,
            byteCount: byteCount,
            documentKind: Self.name(of: presentation.documentKind),
            slideCount: presentation.slides.count,
            slideWidthEMU: presentation.slideSize.width.rawValue,
            slideHeightEMU: presentation.slideSize.height.rawValue,
            properties: DeckPropertyInspection(
                title: properties.title,
                author: properties.author,
                subject: properties.subject,
                comments: properties.comments,
                keywords: properties.keywords,
                category: properties.category,
                company: properties.company,
                application: properties.application,
                created: properties.created,
                modified: properties.modified),
            themeFonts: Array(Set(themeFonts)).sorted(),
            explicitFonts: Self.explicitFonts(in: presentation).sorted(),
            embeddedFonts: embeddedFonts,
            masters: presentation.slideMasters.enumerated().map { index, master in
                MasterInspection(
                    index: index,
                    name: master.name,
                    layoutNames: master.layouts.map(\.name),
                    majorFont: master.theme?.majorFont,
                    minorFont: master.theme?.minorFont)
            },
            sections: presentation.sections.map {
                SectionInspection(id: $0.id, name: $0.name, slideIndices: $0.slideIndices)
            },
            slides: slides,
            charts: charts,
            validationIssues: try presentation.validate().map(\.description))
    }

    /// Render one slide on demand. Arbitrary decks can carry multi-megabyte
    /// photographs on their layouts, so eagerly embedding every image into
    /// every SVG would turn a contact sheet into hundreds of megabytes.
    public func renderSlide(at index: Int, pixelWidth: Int = 640) throws -> String {
        guard (0..<presentation.slides.count).contains(index) else {
            throw DeckWorkbenchError.slideOutOfRange(index)
        }
        return try presentation.renderSVG(slideAt: index, pixelWidth: pixelWidth)
    }

    private func inspectedSlides() throws -> [SlideInspection] {
        var chartIndex = 0
        return try (0..<presentation.slides.count).map { index in
            let slide = try presentation.slides.slide(at: index)
            let shapes = Self.flatten(slide.shapes.all)
            let textBlocks = shapes.compactMap(\.textFrame).map(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let slideCharts = slide.charts
            let indices = Array(chartIndex..<(chartIndex + slideCharts.count))
            chartIndex += slideCharts.count

            var counts: [String: Int] = [:]
            for shape in shapes {
                counts[Self.name(of: shape.kind), default: 0] += 1
            }

            return SlideInspection(
                index: index,
                headline: Self.headline(in: shapes) ?? "Slide \(index + 1)",
                text: textBlocks.joined(separator: "\n"),
                layoutName: slide.layout?.name ?? "Unknown layout",
                masterName: slide.master?.name ?? "",
                shapeCounts: counts,
                notes: slide.notesText,
                comments: slide.comments.enumerated().map { commentIndex, comment in
                    CommentInspection(
                        index: commentIndex,
                        author: comment.authorName ?? "Unknown",
                        text: comment.text,
                        replyCount: comment.replies.count,
                        resolved: comment.isResolved)
                },
                chartIndices: indices,
                mediaCount: shapes.compactMap { $0 as? Picture }.filter(\.isMedia).count)
        }
    }

    private func inspectedCharts() throws -> [ChartInspection] {
        var result: [ChartInspection] = []
        var chartIndex = 0
        for slideIndex in 0..<presentation.slides.count {
            let slide = try presentation.slides.slide(at: slideIndex)
            for chart in slide.charts {
                let data = chart.data
                let problem = data.flatMap { chart.replacementProblem(for: $0) }
                result.append(ChartInspection(
                    index: chartIndex,
                    slideIndex: slideIndex,
                    title: chart.title ?? "Chart \(chartIndex + 1)",
                    plotTypes: chart.plotTypes,
                    categories: chart.categories,
                    series: chart.series.enumerated().map { seriesIndex, series in
                        ChartSeriesInspection(
                            index: seriesIndex,
                            name: series.name,
                            values: series.values)
                    },
                    canReplaceData: data != nil && problem == nil,
                    replacementProblem: problem.map(String.init(describing:))))
                chartIndex += 1
            }
        }
        return result
    }

    private static func explicitFonts(in presentation: Presentation) -> [String] {
        var fonts = Set<String>()
        for slide in presentation.slides {
            for shape in flatten(slide.shapes.all) {
                for paragraph in shape.textFrame?.paragraphs ?? [] {
                    for run in paragraph.runs {
                        if let name = run.fontName, !name.isEmpty { fonts.insert(name) }
                    }
                }
            }
        }
        return Array(fonts)
    }

    private static func headline(in shapes: [Shape]) -> String? {
        var candidates: [(size: Double, text: String)] = []
        for shape in shapes {
            guard let frame = shape.textFrame else { continue }
            let text = frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let size = frame.paragraphs.flatMap(\.runs).compactMap(\.fontSize).max() ?? 0
            candidates.append((size, text))
        }
        return candidates.max {
            ($0.size, $0.text.count) < ($1.size, $1.text.count)
        }?.text.components(separatedBy: .newlines).first
    }

    private static func flatten(_ shapes: [Shape]) -> [Shape] {
        shapes.flatMap { shape in
            guard let group = shape as? GroupShape else { return [shape] }
            return [shape] + flatten(group.shapes)
        }
    }

    private static func name(of kind: DocumentKind) -> String {
        switch kind {
        case .presentation: "Presentation (.pptx)"
        case .template: "Template (.potx)"
        case .slideShow: "Slide show (.ppsx)"
        }
    }

    private static func name(of kind: ShapeKind) -> String {
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
