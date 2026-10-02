import Foundation
import Rostrum

/// A validated, immutable snapshot. Generation never depends on a temporary
/// file-picker grant remaining alive, or on the source file changing mid-run.
public struct PowerPointTemplate: Sendable {
    public struct Master: Sendable, Identifiable {
        public let id: String
        public let name: String
        public let layoutNames: [String]
    }
    public let data: Data
    public let name: String
    public let masters: [Master]
    public var selectedMasterID: String?

    public init(data: Data, name: String) throws {
        let deck = try Presentation.fromTemplate(data: data)
        try deck.validateTemplateBindings()
        self.data = data
        self.name = name
        self.masters = deck.slideMasters.enumerated().map { index, master in
            Master(id: master.part.uri.value,
                   name: master.name.isEmpty ? "Master \(index + 1)" : master.name,
                   layoutNames: master.layouts.map(\.name))
        }
        self.selectedMasterID = masters.first?.id
    }
}
