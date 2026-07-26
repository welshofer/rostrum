import Foundation

/// The `a:graphicData@uri` values identifying what a graphic frame carries.
public enum GraphicDataURI {
    public static let table = "http://schemas.openxmlformats.org/drawingml/2006/table"
    public static let chart = ChartXML.nsC
    public static let diagram = SmartArt.nsDGM
    public static let ole = "http://schemas.openxmlformats.org/presentationml/2006/ole"
}

/// What a shape-tree child is: element name plus, for graphic frames, the
/// payload named by `a:graphicData@uri`. Cheap — deriving it allocates no
/// facade — so it is the right thing to filter and count on.
///
/// The two catch-all cases keep this enum stable: a payload Rostrum learns to
/// model later arrives as a recognized `uri` rather than a new case, so an
/// exhaustive `switch` in your code keeps compiling.
public enum ShapeKind: Hashable, Sendable {
    /// `p:sp` — an autoshape or text box.
    case autoShape
    /// `p:pic` — a picture.
    case picture
    /// `p:cxnSp` — a connector line.
    case connector
    /// `p:grpSp` — a group of shapes.
    case group
    /// `p:graphicFrame` holding a table.
    case table
    /// `p:graphicFrame` holding a chart.
    case chart
    /// `p:graphicFrame` holding a SmartArt diagram.
    case diagram
    /// `p:graphicFrame` holding a payload Rostrum does not model (OLE
    /// objects, ChartEx, and anything newer).
    case graphicFrame(uri: String)
    /// Anything else in the tree: `mc:AlternateContent`, `p:contentPart`, …
    case other(elementName: String)

    init(element: XML.Element) {
        switch element.name {
        case "p:sp": self = .autoShape
        case "p:pic": self = .picture
        case "p:cxnSp": self = .connector
        case "p:grpSp": self = .group
        case "p:graphicFrame":
            let uri = element.firstChild(named: "a:graphic")?
                .firstChild(named: "a:graphicData")?[attribute: "uri"] ?? ""
            switch uri {
            case GraphicDataURI.table: self = .table
            case GraphicDataURI.chart: self = .chart
            case GraphicDataURI.diagram: self = .diagram
            default: self = .graphicFrame(uri: uri)
            }
        default:
            self = .other(elementName: element.name)
        }
    }

    /// True for every `p:graphicFrame`, whatever it carries.
    public var isGraphicFrame: Bool {
        switch self {
        case .table, .chart, .diagram, .graphicFrame: return true
        default: return false
        }
    }

    /// The qualified OOXML element name this kind corresponds to.
    public var elementName: String {
        switch self {
        case .autoShape: return "p:sp"
        case .picture: return "p:pic"
        case .connector: return "p:cxnSp"
        case .group: return "p:grpSp"
        case .table, .chart, .diagram, .graphicFrame: return "p:graphicFrame"
        case .other(let name): return name
        }
    }

    /// The graphic-frame payload URI, for every graphic-frame kind.
    public var graphicDataURI: String? {
        switch self {
        case .table: return GraphicDataURI.table
        case .chart: return GraphicDataURI.chart
        case .diagram: return GraphicDataURI.diagram
        case .graphicFrame(let uri): return uri
        default: return nil
        }
    }
}
