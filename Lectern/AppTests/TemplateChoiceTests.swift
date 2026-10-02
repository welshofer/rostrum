import Foundation
import Testing
import Rostrum
import LecternCore
@testable import Lectern

@MainActor
@Suite struct TemplateChoiceTests {
    @Test func templateImportIsSnapshotAndThemeSelectionClearsIt() async throws {
        let name = "LecternTemplateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let app = AppState(skipKeychain: true, defaults: defaults)
        let source = try Presentation()
        source.documentKind = .template
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).potx")
        try source.save(to: path)
        await app.attachTemplate(path)
        try FileManager.default.removeItem(at: path)
        #expect(app.selectedTemplate != nil)
        #expect(app.templateError == nil)
        #expect(!app.templateLoading)
        #expect(try Presentation(data: #require(app.selectedTemplate?.data)).documentKind == .template)
        app.selectStyle("cinnabarink")
        #expect(app.selectedTemplate == nil)
    }

    @Test func invalidImportKeepsCurrentSelection() async throws {
        let name = "LecternTemplateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let app = AppState(skipKeychain: true, defaults: defaults)
        let source = try Presentation()
        source.documentKind = .template
        app.selectedTemplate = try PowerPointTemplate(data: source.serializedData(), name: "Keep me")
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).potx")
        try Data("not a presentation".utf8).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        await app.attachTemplate(path)
        #expect(app.templateError != nil)
        #expect(app.selectedTemplate?.name == "Keep me")
    }
}
