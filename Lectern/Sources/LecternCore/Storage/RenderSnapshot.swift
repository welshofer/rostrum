import Foundation

/// Local accepted content and assets, never credentials or the original prompt.
/// A snapshot can reproduce a render without a network request or file grants.
public struct RenderSnapshot: Codable, Sendable {
    public var deck: DeckIR
    public var images: [String: Data]
    public var design: String?
    public var templateData: Data?
    public var templateName: String?
    public var masterID: String?
    public var notesEnabled: Bool
    public var useSmartArt: Bool

    public init(deck: DeckIR, images: [String: Data] = [:], design: String? = nil,
                template: PowerPointTemplate? = nil, notesEnabled: Bool = true, useSmartArt: Bool = false) {
        self.deck = deck; self.images = images; self.design = design
        templateData = template?.data; templateName = template?.name; masterID = template?.selectedMasterID
        self.notesEnabled = notesEnabled; self.useSmartArt = useSmartArt
    }

    public func template() throws -> PowerPointTemplate? {
        guard let templateData else { return nil }
        var value = try PowerPointTemplate(data: templateData, name: templateName ?? "Saved template")
        value.selectedMasterID = masterID
        return value
    }

    public func save(in directory: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("render-session-\(UUID().uuidString).json")
        let data = try JSONEncoder().encode(self)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do { try handle.write(contentsOf: data); try handle.close() }
        catch { try? handle.close(); try? fm.removeItem(at: url); throw error }
        #endif
        return url
    }

    public static func load(_ url: URL) throws -> RenderSnapshot {
        try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
