// Compile with -swift-version 5 to check existing clients' trailing closures.
// Swift 6 clients disambiguate by supplying measureObjectHeight: nil or by
// labeling validateObject explicitly (covered by the package's Swift 6 tests).
import Rostrum
import RostrumLayout

let deck = try Presentation()
var validated = false
_ = try TemplateLayoutEngine(presentation: deck).plan(title: "Compatible", columns: [],
    preferredTypes: ["obj"], object: "tbl") { frame, _ in
        precondition(frame.width > .zero)
        validated = true
    }
precondition(validated)
