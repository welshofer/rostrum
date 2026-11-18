import Foundation
import Testing
import Rostrum
@testable import KeynoteInterchange

@Suite struct KeyxDocumentTests {
    private func archive(main: String, manifest: String? = nil, presets: String? = nil,
                         entries: [(String, Data)] = []) throws -> Data {
        var writer = ZipWriter()
        writer.addFile(name: "main.json", data: Data(main.utf8))
        if let manifest { writer.addFile(name: "manifest.json", data: Data(manifest.utf8)) }
        if let presets { writer.addFile(name: "presets.json", data: Data(presets.utf8)) }
        for (name, data) in entries { writer.addFile(name: name, data: data) }
        return try writer.finalize()
    }

    @Test func preservesUnknownFieldsNumbersAndUnchangedEntries() throws {
        let main = """
        { "slides": [{"identifier":"one","note":{"string":"Before"},
          "vendor":{"huge":9007199254740993123456789,"precise":1.23000000000000000000000001e+7}}],
          "unknown":{"enabled":true} }
        """
        let manifest = #"{"package_version":"1.0", "vendor": "preserve"}"#
        let presets = " [ ] \n"
        let image = Data([0, 1, 2, 255])
        var document = try KeyxDocument(data: archive(main: main, manifest: manifest, presets: presets,
                                                     entries: [("Data/asset.bin", image), ("vendor/metadata", image)]))
        let untouched = try ZipReader(data: document.data())
        #expect(try untouched.data(forEntry: "main.json") == Data(main.utf8))
        try document.editSlide(at: 0) { $0.setNote(.value(KeyxText("After"))) }
        let edited = try document.data()
        #expect(try document.data() == edited)
        let zip = try ZipReader(data: edited)
        #expect(try zip.data(forEntry: "manifest.json") == Data(manifest.utf8))
        #expect(try zip.data(forEntry: "presets.json") == Data(presets.utf8))
        #expect(try zip.data(forEntry: "Data/asset.bin") == image)
        #expect(try zip.data(forEntry: "vendor/metadata") == image)
        let reopened = try KeyxDocument(data: edited)
        let slide = try #require(reopened.slides.first)
        #expect(try slide.note.value?.plainText == "After")
        #expect(slide.node["vendor"]?["huge"] == .number("9007199254740993123456789"))
        #expect(slide.node["vendor"]?["precise"] == .number("1.23000000000000000000000001e+7"))
        #expect(KeyxValue.number("9007199254740993.0").integer == 9_007_199_254_740_993)
        #expect(KeyxValue.number("100e-2").integer == 1)
        #expect(KeyxValue.number("100e-3").integer == nil)
    }

    @Test func inheritanceNullAndStylesheetReferencesAreDistinct() throws {
        var document = try KeyxDocument(data: archive(main: #"{"slides":[{}]}"#, presets: """
        [{"identifier":"base","properties":{"bold":true,"font_size":24}},
         {"identifier":"child","parent_identifier":"base","properties":{"bold":null}}]
        """))
        let node = KeyxNode(type: "character-properties", fields: ["preset_identifier": .string("child")])
        #expect(node.property("bold") == .inherited)
        #expect(try document.resolvedProperty("bold", on: node) == .cleared)
        #expect(try document.resolvedProperty("font_size", on: node) == .value(.number("24")))
        var override = node
        override.set("bold", to: .value(.bool(false)))
        #expect(try document.resolvedProperty("bold", on: override) == .value(.bool(false)))
        override.set("bold", to: .inherited)
        #expect(try document.resolvedProperty("bold", on: override) == .cleared)
        document.presentation["stylesheet"] = KeyxNode(type: "stylesheet", fields: [
            "character_styles": .array([KeyxNode(type: "stylesheet.character-style", fields: [
                "preset_identifier": .string("child"), "properties": .object([:]), "name": .string("Strong")
            ]).value])
        ]).value
        #expect(try document.resolvedProperty("font_size", on: node) == .value(.number("24")))
    }

    @Test func rejectsDuplicateMembersAndBoundsJSON() throws {
        #expect(throws: KeyxError.self) { try KeyxValue.parse(Data(#"{"a":1,"\u0061":2}"#.utf8)) }
        for invalid in ["01", "1e", "1.", "[1,]", "true false", #"{"a":"\uD800"}"#] {
            #expect(throws: KeyxError.self) { try KeyxValue.parse(Data(invalid.utf8)) }
        }
        var limits = KeyxLimits(); limits.jsonDepth = 2
        #expect(throws: KeyxError.self) { try KeyxValue.parse(Data("[[[[0]]]]".utf8), limits: limits) }
        #expect(throws: KeyxError.self) { try KeyxValue.number("nan").data() }
    }

    @Test func validatesVersionsWithoutDowngrading() throws {
        #expect(throws: KeyxError.self) {
            try KeyxDocument(data: archive(main: "bad JSON", manifest: #"{"package_version":"2.0"}"#))
        }
        var document = try KeyxDocument(data: archive(main: """
        {"slides":[{"layout":"blank"}],"theme":{"slide_layouts":[
          {"identifier":"blank","name":"Blank","version":"1.1"}]}}
        """))
        #expect(document.validate().filter { $0.severity == .error }.isEmpty)
        _ = try document.data()
        try document.editSlide(at: 0) { $0.node["version"] = .string("1.7") }
        #expect(throws: KeyxError.self) { try document.data() }
        #expect(try document.slides[0].node["version"] == .string("1.7"))
    }

    @Test func resourcesAreFlatCaseSensitiveAndBounded() throws {
        var document = try KeyxDocument(data: archive(main: #"{"slides":[{}]}"#))
        let resource = try document.addResource(Data([1, 2, 3]), filename: "Photo.png", identifier: "opaque")
        #expect(try document.resourceData(resource) == Data([1, 2, 3]))
        let absent = KeyxNode(type: "resource", fields: [
            "indirect": .object(["filename": .string("Photo.png"), "identifier": .string("OPAQUE")])
        ]).value
        #expect(throws: KeyxError.self) { try document.resourceData(absent) }
        #expect(throws: KeyxError.self) { try document.addResource(Data(), filename: "../escape") }
        let embedded = KeyxNode(type: "resource", fields: [
            "base64_encoded": .object(["filename": .string("test.bin"), "version": .string("2.0"), "string": .string("AQID")])
        ]).value
        #expect(try document.resourceData(embedded) == Data([1, 2, 3]))
        try document.editSlide(at: 0) {
            $0.setContents([KeyxSlideObject(canvas: .init(kind: "image", properties: KeyxNode(type: "image", fields: ["resource": absent])))])
        }
        #expect(throws: KeyxError.self) { try document.data() }
    }

    @Test func rejectsArchiveAmbiguityAndTraversal() throws {
        #expect(throws: KeyxError.self) {
            try KeyxDocument(data: archive(main: #"{"slides":[{}]}"#, entries: [("main.json", Data("{}".utf8))]))
        }
        #expect(throws: KeyxError.self) {
            try KeyxDocument(data: archive(main: #"{"slides":[{}]}"#, entries: [("Data/sub/item", Data())]))
        }
        #expect(throws: KeyxError.self) {
            try KeyxDocument(data: archive(main: #"{"slides":[{}]}"#, entries: [("../escape", Data())]))
        }
        var limits = KeyxLimits(); limits.uncompressedBytes = 5
        #expect(throws: (any Error).self) { try KeyxDocument(data: archive(main: #"{"slides":[{}]}"#), limits: limits) }
    }

    @Test func semanticChecksCatchCyclesAmbiguityAndBrokenLayouts() throws {
        for presets in [
            #"[{"identifier":"a","parent_identifier":"b","properties":{}},{"identifier":"b","parent_identifier":"a","properties":{}}]"#,
            #"[{"identifier":"a","properties":{}},{"identifier":"a","properties":{}}]"#
        ] {
            let document = try KeyxDocument(data: archive(main: #"{"slides":[{}]}"#, presets: presets))
            #expect(throws: KeyxError.self) { try document.data() }
        }
        let document = try KeyxDocument(data: archive(main: """
        {"slides":[{"identifier":"same","layout":"missing"},{"identifier":"same"}],
         "theme":{"slide_layouts":[{"identifier":"blank","name":"Blank"}]}}
        """))
        #expect(document.validate().contains { $0.message.contains("Duplicate identifier") })
        #expect(document.validate().contains { $0.message.contains("Unresolved slide layout") })
        #expect(throws: KeyxError.self) { try document.data() }
    }

    @Test func noteEditingIsTransactionalAndRichTextSurvives() throws {
        var document = try KeyxDocument(data: archive(main: #"{"slides":[{"identifier":"original"}]}"#))
        #expect(throws: KeyxError.self) {
            try document.editSlide(at: 0) {
                $0.identifier = "changed"
                throw KeyxError.invalid("Abort")
            }
        }
        #expect(try document.slides[0].identifier == "original")
        let text = KeyxText(runs: [
            KeyxTextRun("Hello ", style: KeyxNode(type: "character-properties", fields: ["bold": .bool(true)])),
            KeyxTextRun("world")
        ])
        try document.editSlide(at: 0) { $0.setNote(.value(text)) }
        let reopened = try KeyxDocument(data: document.data())
        #expect(try reopened.slides[0].note.value == text)
        #expect(try reopened.slides[0].note.value?.plainText == "Hello world")
    }

    @Test func rotationUsesPostRotationBoundingBox() {
        let geometry = KeyxGeometry(x: 10, y: 20, width: 100, height: 40, angle: 90)
        #expect(abs(geometry.centerX - 30) < 0.00001)
        #expect(abs(geometry.centerY - 70) < 0.00001)
        let largeRotation = KeyxGeometry(x: 0, y: 0, width: 100, height: 40, angle: .greatestFiniteMagnitude)
        #expect(largeRotation.rotatedWidth.isFinite && largeRotation.rotatedHeight.isFinite)
    }

    @Test func unusablePathsAreRejectedBeforeSaving() throws {
        for path in ["M 0 0 L", "L 0 0", "M 0 0 A 2 2 0 8 0 4 4", "M 1e999 0"] {
            let object = KeyxCanvasObject(kind: "shape", properties: KeyxNode(type: "shape", fields: [
                "path": .object(["bezier": .object(["path": .string(path)])])
            ]))
            let document = try KeyxDocument(presentation: KeyxNode(type: "presentation", fields: [
                "slides": .array([KeyxSlide(identifier: "path", contents: [KeyxSlideObject(canvas: object)]).node.value])
            ]))
            #expect(throws: KeyxError.self) { try document.data() }
        }
        #expect(KeyxPathValidation.isUsable("M 0 0 L 10 0 10 20 Z"))
        #expect(KeyxPathValidation.isUsable("m -.5 +.5 c 1 2 3 4 5 6 z"))
    }

    @Test func sparseTableIndicesResumeAfterThePreviousExplicitIndex() throws {
        let table = KeyxNode(type: "table", fields: [
            "number_of_columns": .integer(4), "number_of_rows": .integer(4),
            "content": .array([
                .object(["row_index": .integer(2), "cells": .array([
                    .object(["column_index": .integer(2), "value": .string("C3")]),
                    .object(["value": .string("D3")])
                ])]),
                .object(["cells": .array([.object(["value": .string("A4")])])])
            ])
        ])
        let document = try KeyxDocument(presentation: KeyxNode(type: "presentation", fields: [
            "slides": .array([KeyxSlide(identifier: "sparse", contents: [
                KeyxSlideObject(canvas: .init(kind: "table", properties: table))
            ]).node.value])
        ]))
        let reopened = try KeyxDocument(data: document.data())
        let grid = try #require(reopened.inspectSlide(at: 0).tables.first)
        #expect(grid[2] == ["", "", "C3", "D3"])
        #expect(grid[3] == ["A4", "", "", ""])
    }
}
