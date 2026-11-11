import Foundation

/// A slide-entry transition (`p:transition` on `p:sld`).
public struct SlideTransition: Hashable, Sendable {
    /// Four-way cardinal transition direction (`ST_TransitionSideDirectionType`).
    public enum Direction: String, CaseIterable, Hashable, Sendable {
        case left = "l", up = "u", right = "r", down = "d"
    }

    /// Eight-way transition direction (`ST_TransitionEightDirectionType`).
    public enum EightWayDirection: String, CaseIterable, Hashable, Sendable {
        case left = "l", up = "u", right = "r", down = "d"
        case leftUp = "lu", leftDown = "ld", rightUp = "ru", rightDown = "rd"
    }

    /// Four-corner diagonal transition direction (`ST_TransitionCornerDirectionType`).
    public enum CornerDirection: String, CaseIterable, Hashable, Sendable {
        case leftUp = "lu", leftDown = "ld", rightUp = "ru", rightDown = "rd"
    }

    /// Horizontal or vertical transition orientation (`ST_Direction`).
    public enum Orientation: String, CaseIterable, Hashable, Sendable {
        case horizontal = "horz", vertical = "vert"
    }

    /// Inward or outward transition direction (`ST_TransitionInOutDirectionType`).
    public enum InOutDirection: String, CaseIterable, Hashable, Sendable {
        case inward = "in", outward = "out"
    }

    /// Transition speed (`ST_TransitionSpeed`).
    public enum Speed: String, CaseIterable, Hashable, Sendable {
        case slow, medium = "med", fast
    }

    /// The visual transition effect child inside `p:transition`.
    public enum Effect: Hashable, Sendable {
        case cut(throughBlack: Bool = false)
        case fade(throughBlack: Bool = false)
        case push(Direction = .left)
        case wipe(Direction = .left)
        case split(orientation: Orientation = .horizontal, direction: InOutDirection = .outward)
        case cover(EightWayDirection = .left)
        case pull(EightWayDirection = .left)
        case strips(CornerDirection = .leftDown)
        case blinds(Orientation = .vertical)
        case checker(Orientation = .horizontal)
        case comb(Orientation = .horizontal)
        case randomBar(Orientation = .horizontal)
        case circle
        case diamond
        case dissolve
        case newsflash
        case plus
        case random
        case wedge
        case wheel(spokes: Int = 4)
        case zoom(InOutDirection = .outward)
        /// An unmodeled or extension transition element (e.g. inside `mc:AlternateContent`).
        case other(elementName: String)

        static let modeledChoiceNames: Set<String> = [
            "p:blinds", "p:checker", "p:circle", "p:comb", "p:cover",
            "p:cut", "p:diamond", "p:dissolve", "p:fade", "p:newsflash",
            "p:plus", "p:pull", "p:push", "p:random", "p:randomBar",
            "p:split", "p:strips", "p:wedge", "p:wheel", "p:wipe", "p:zoom",
        ]

        func makeElement() -> XML.Element? {
            switch self {
            case .cut(let throughBlack):
                return XML.Element("p:cut", attributes: throughBlack ? [("thruBlk", "1")] : [])
            case .fade(let throughBlack):
                return XML.Element("p:fade", attributes: throughBlack ? [("thruBlk", "1")] : [])
            case .push(let dir):
                return XML.Element("p:push", attributes: dir == .left ? [] : [("dir", dir.rawValue)])
            case .wipe(let dir):
                return XML.Element("p:wipe", attributes: dir == .left ? [] : [("dir", dir.rawValue)])
            case .split(let orientation, let direction):
                var attrs: [(String, String)] = []
                if orientation != .horizontal { attrs.append(("orient", orientation.rawValue)) }
                if direction != .outward { attrs.append(("dir", direction.rawValue)) }
                return XML.Element("p:split", attributes: attrs)
            case .cover(let dir):
                return XML.Element("p:cover", attributes: dir == .left ? [] : [("dir", dir.rawValue)])
            case .pull(let dir):
                return XML.Element("p:pull", attributes: dir == .left ? [] : [("dir", dir.rawValue)])
            case .strips(let dir):
                return XML.Element("p:strips", attributes: dir == .leftDown ? [] : [("dir", dir.rawValue)])
            case .blinds(let orient):
                return XML.Element("p:blinds", attributes: orient == .vertical ? [] : [("orient", orient.rawValue)])
            case .checker(let orient):
                return XML.Element("p:checker", attributes: orient == .horizontal ? [] : [("orient", orient.rawValue)])
            case .comb(let orient):
                return XML.Element("p:comb", attributes: orient == .horizontal ? [] : [("orient", orient.rawValue)])
            case .randomBar(let orient):
                return XML.Element("p:randomBar", attributes: orient == .horizontal ? [] : [("orient", orient.rawValue)])
            case .circle:
                return XML.Element("p:circle")
            case .diamond:
                return XML.Element("p:diamond")
            case .dissolve:
                return XML.Element("p:dissolve")
            case .newsflash:
                return XML.Element("p:newsflash")
            case .plus:
                return XML.Element("p:plus")
            case .random:
                return XML.Element("p:random")
            case .wedge:
                return XML.Element("p:wedge")
            case .wheel(let spokes):
                let valid = [1, 2, 3, 4, 8].contains(spokes) ? spokes : 4
                return XML.Element("p:wheel", attributes: valid == 4 ? [] : [("spokes", String(valid))])
            case .zoom(let dir):
                return XML.Element("p:zoom", attributes: dir == .outward ? [] : [("dir", dir.rawValue)])
            case .other:
                return nil
            }
        }

        init(element: XML.Element) {
            func isTrue(_ raw: String?) -> Bool { raw == "1" || raw == "true" }
            switch element.name {
            case "p:cut":
                self = .cut(throughBlack: isTrue(element[attribute: "thruBlk"]))
            case "p:fade":
                self = .fade(throughBlack: isTrue(element[attribute: "thruBlk"]))
            case "p:push":
                self = .push(element[attribute: "dir"].flatMap(Direction.init(rawValue:)) ?? .left)
            case "p:wipe":
                self = .wipe(element[attribute: "dir"].flatMap(Direction.init(rawValue:)) ?? .left)
            case "p:split":
                let orient = element[attribute: "orient"].flatMap(Orientation.init(rawValue:)) ?? .horizontal
                let dir = element[attribute: "dir"].flatMap(InOutDirection.init(rawValue:)) ?? .outward
                self = .split(orientation: orient, direction: dir)
            case "p:cover":
                self = .cover(element[attribute: "dir"].flatMap(EightWayDirection.init(rawValue:)) ?? .left)
            case "p:pull":
                self = .pull(element[attribute: "dir"].flatMap(EightWayDirection.init(rawValue:)) ?? .left)
            case "p:strips":
                self = .strips(element[attribute: "dir"].flatMap(CornerDirection.init(rawValue:)) ?? .leftDown)
            case "p:blinds":
                self = .blinds(element[attribute: "orient"].flatMap(Orientation.init(rawValue:)) ?? .vertical)
            case "p:checker":
                self = .checker(element[attribute: "orient"].flatMap(Orientation.init(rawValue:)) ?? .horizontal)
            case "p:comb":
                self = .comb(element[attribute: "orient"].flatMap(Orientation.init(rawValue:)) ?? .horizontal)
            case "p:randomBar":
                self = .randomBar(element[attribute: "orient"].flatMap(Orientation.init(rawValue:)) ?? .horizontal)
            case "p:circle": self = .circle
            case "p:diamond": self = .diamond
            case "p:dissolve": self = .dissolve
            case "p:newsflash": self = .newsflash
            case "p:plus": self = .plus
            case "p:random": self = .random
            case "p:wedge": self = .wedge
            case "p:wheel":
                let spokes = element.boundedInt("spokes", in: 1...8) ?? 4
                self = .wheel(spokes: spokes)
            case "p:zoom":
                self = .zoom(element[attribute: "dir"].flatMap(InOutDirection.init(rawValue:)) ?? .outward)
            default:
                self = .other(elementName: element.name)
            }
        }
    }

    public var effect: Effect?
    public var speed: Speed?
    public var advanceOnClick: Bool
    public var advanceAfterMilliseconds: Int?

    public init(
        _ effect: Effect? = .fade(),
        speed: Speed? = nil,
        advanceOnClick: Bool = true,
        advanceAfterMilliseconds: Int? = nil
    ) {
        self.effect = effect
        self.speed = speed
        self.advanceOnClick = advanceOnClick
        self.advanceAfterMilliseconds = advanceAfterMilliseconds.map { Swift.max(0, $0) }
    }

    public static let fade = SlideTransition(.fade())
    public static let cut = SlideTransition(.cut())
    public static let dissolve = SlideTransition(.dissolve)
    public static func push(_ direction: Direction = .left, speed: Speed? = nil) -> SlideTransition {
        SlideTransition(.push(direction), speed: speed)
    }
    public static func wipe(_ direction: Direction = .left, speed: Speed? = nil) -> SlideTransition {
        SlideTransition(.wipe(direction), speed: speed)
    }

    init(element: XML.Element) {
        let nonEffectNames: Set<String> = ["p:sndAc", "p:extLst"]
        let effectChild = element.childElements.first { !nonEffectNames.contains($0.name) }
        self.effect = effectChild.map(Effect.init(element:))
        self.speed = element[attribute: "spd"].flatMap(Speed.init(rawValue:))
        if let rawClick = element[attribute: "advClick"] {
            self.advanceOnClick = !(rawClick == "0" || rawClick == "false")
        } else {
            self.advanceOnClick = true
        }
        self.advanceAfterMilliseconds = element.boundedInt("advTm", in: 0...Int(Int32.max))
    }

    func apply(to element: XML.Element) {
        element[attribute: "spd"] = speed?.rawValue
        element[attribute: "advClick"] = advanceOnClick ? nil : "0"
        element[attribute: "advTm"] = advanceAfterMilliseconds.map { String(Swift.max(0, $0)) }

        let nonEffectNames: Set<String> = ["p:sndAc", "p:extLst"]
        if case .other(let preservedName) = effect,
           element.childElements.contains(where: { $0.name == preservedName }) {
            return
        }
        element.children.removeAll { node in
            guard case .element(let child) = node else { return false }
            return !nonEffectNames.contains(child.name)
        }
        if let effectElement = effect?.makeElement() {
            element.insertChild(effectElement, beforeAnyOf: ["p:sndAc", "p:extLst"])
        }
    }
}
