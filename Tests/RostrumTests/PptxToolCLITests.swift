import Dispatch
import Foundation
import Testing
@testable import Rostrum

#if os(macOS) || os(Linux)

@Suite(.serialized)
struct PptxToolCLITests {
    private final class CachedBinary: @unchecked Sendable {
        let lock = NSLock()
        var url: URL?
    }

    private final class PipeReadBox: @unchecked Sendable {
        let handle: FileHandle
        var data = Data()
        init(_ handle: FileHandle) { self.handle = handle }
    }

    private static let binaryCache = CachedBinary()

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private struct CLIResult {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil,
        captureStdout: Bool = true
    ) throws -> CLIResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let currentDirectoryURL {
            process.currentDirectoryURL = currentDirectoryURL
        }
        process.standardInput = FileHandle.nullDevice
        let outPipe: Pipe? = captureStdout ? Pipe() : nil
        let errPipe = Pipe()
        if let outPipe {
            process.standardOutput = outPipe
        } else {
            process.standardOutput = FileHandle.nullDevice
        }
        process.standardError = errPipe
        try process.run()

        let outData: Data
        let errData: Data
        if let outPipe {
            let errBox = PipeReadBox(errPipe.fileHandleForReading)
            let errDone = DispatchSemaphore(value: 0)
            let errReader = Thread {
                errBox.data = errBox.handle.readDataToEndOfFile()
                errDone.signal()
            }
            errReader.start()
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            errDone.wait()
            errData = errBox.data
        } else {
            outData = Data()
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        }
        process.waitUntilExit()

        return CLIResult(
            status: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }

    /// Locate `pptx-tool` across Linux (`debug/`) and macOS (`RostrumPackageTests.xctest/...`),
    /// building `--product pptx-tool` once if `swift test` was invoked without building executables.
    private static func pptxToolExecutable() throws -> URL {
        binaryCache.lock.lock()
        defer { binaryCache.lock.unlock() }

        if let cached = binaryCache.url,
           FileManager.default.isExecutableFile(atPath: cached.path) {
            return cached
        }

        let rootPath = repoRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        var cursor = Bundle.module.bundleURL.deletingLastPathComponent()
        for _ in 0..<8 {
            let cursorPath = cursor.resolvingSymlinksInPath().standardizedFileURL.path
            guard cursorPath.hasPrefix(rootPrefix) else { break }
            let candidate = cursor.appendingPathComponent("pptx-tool")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                binaryCache.url = candidate
                return candidate
            }
            cursor.deleteLastPathComponent()
        }

        let envURL = URL(fileURLWithPath: "/usr/bin/env")
        let buildResult = try runProcess(
            executableURL: envURL,
            arguments: ["swift", "build", "--package-path", repoRoot.path, "--product", "pptx-tool"],
            captureStdout: false
        )
        try #require(
            buildResult.status == 0,
            "swift build --product pptx-tool failed (\(buildResult.status)): \(buildResult.stderr)"
        )

        let binResult = try runProcess(
            executableURL: envURL,
            arguments: ["swift", "build", "--package-path", repoRoot.path, "--show-bin-path"],
            captureStdout: true
        )
        try #require(
            binResult.status == 0,
            "swift build --show-bin-path failed (\(binResult.status)): \(binResult.stderr)"
        )
        let binDir = binResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        try #require(!binDir.isEmpty, "swift build --show-bin-path returned an empty path")
        let built = URL(fileURLWithPath: binDir).appendingPathComponent("pptx-tool")
        try #require(FileManager.default.isExecutableFile(atPath: built.path))
        binaryCache.url = built
        return built
    }

    private static func runCLI(
        _ arguments: [String],
        currentDirectoryURL: URL? = nil
    ) throws -> CLIResult {
        try runProcess(
            executableURL: try pptxToolExecutable(),
            arguments: arguments,
            currentDirectoryURL: currentDirectoryURL,
            captureStdout: true
        )
    }

    private static func withScratchDir(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pptx-tool-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    /// Build a valid `.pptx` archive carrying an intentionally corrupt DEFLATE orphan `.rels`
    /// entry so `Presentation(contentsOf:)` records a `readWarnings` diagnostic on open.
    private static func makeDeckWithCorruptOrphanRelsWarning(at url: URL) throws {
        let baseBytes = try Presentation().serializedData()
        let reader = try ZipReader(data: baseBytes)
        var writer = ZipWriter()
        for name in reader.entryNames {
            writer.addFile(name: name, data: try reader.data(forEntry: name))
        }
        // Inject a raw method=8 (DEFLATE) entry with invalid compressed bytes under an orphan .rels name.
        let invalidDeflate = Data([0xFF, 0xFF, 0xFF, 0xFF])
        writer.addFile(
            name: "ppt/slides/_rels/slide99.xml.rels",
            payload: ZipWriter.Payload(
                data: invalidDeflate,
                method: 8,
                size: 32,
                crc: CRC32.checksum(invalidDeflate)
            )
        )
        try writer.finalize().write(to: url)
    }

    @Test func rejectsUnknownMalformedMissingAndEmptyArgumentsWithExitCode2AndStderr() throws {
        try Self.withScratchDir { dir in
            let deckURL = dir.appendingPathComponent("sample.pptx")
            try Presentation().save(to: deckURL)
            let outDir = dir.appendingPathComponent("out", isDirectory: true)

            // 1. Unknown long/short flags (--strcit, -x) exit 2 with stderr diagnostic.
            let typoValidate = try Self.runCLI(["validate", deckURL.path, "--strcit"])
            #expect(typoValidate.status == 2)
            #expect(typoValidate.stderr.contains("--strcit"))

            let typoRender = try Self.runCLI(["render", deckURL.path, outDir.path, "--strcit"])
            #expect(typoRender.status == 2)
            #expect(typoRender.stderr.contains("--strcit"))

            let shortFlag = try Self.runCLI(["validate", deckURL.path, "-x"])
            #expect(shortFlag.status == 2)
            #expect(shortFlag.stderr.contains("-x"))

            // 2. Subcommand-inappropriate flags (--strict on inspect, --include-poster on render) exit 2.
            let strictOnInspect = try Self.runCLI(["inspect", deckURL.path, "--strict"])
            #expect(strictOnInspect.status == 2)
            #expect(strictOnInspect.stderr.contains("--strict"))

            let posterOnRender = try Self.runCLI(["render", deckURL.path, outDir.path, "--include-poster"])
            #expect(posterOnRender.status == 2)
            #expect(posterOnRender.stderr.contains("--include-poster"))

            // 3. Missing/malformed option values, boolean flags with =value, missing positionals,
            //    extra positionals, and empty "" positionals all exit 2 with stderr diagnostics.
            for badArgs in [
                ["inspect"],
                ["validate"],
                ["extract"],
                ["extract", deckURL.path],
                ["render"],
                ["render", deckURL.path],
                ["inspect", ""],
                ["validate", ""],
                ["extract", "", outDir.path],
                ["extract", deckURL.path, ""],
                ["render", "", outDir.path],
                ["render", deckURL.path, ""],
                ["validate", deckURL.path, "--max-uncompressed"],
                ["validate", deckURL.path, "--max-uncompressed="],
                ["validate", deckURL.path, "--max-uncompressed=-1"],
                ["validate", deckURL.path, "--max-uncompressed=abc"],
                ["validate", deckURL.path, "--max-uncompressed=0", "--max-uncompressed=1024"],
                ["render", deckURL.path, outDir.path, "--font"],
                ["render", deckURL.path, outDir.path, "--font="],
                ["render", deckURL.path, outDir.path, "--font", ""],
                ["render", deckURL.path, outDir.path, "--font", "--strict"],
                ["render", deckURL.path, outDir.path, "--strict=false"],
                ["render", deckURL.path, outDir.path, "--notes=true"],
                ["extract", deckURL.path, outDir.path, "--include-poster=true"],
                ["validate", deckURL.path, "extra.pptx"],
                ["extract", deckURL.path, outDir.path, "extra"],
                ["render", deckURL.path, outDir.path, "extra"],
            ] {
                let res = try Self.runCLI(badArgs)
                #expect(res.status == 2, "Expected exit 2 for args \(badArgs), got \(res.status)")
                #expect(!res.stderr.isEmpty, "Expected stderr message for args \(badArgs)")
            }

            // 4. Usage output documents render command and --max-uncompressed on render.
            let noArgs = try Self.runCLI([])
            #expect(noArgs.status == 2)
            #expect(noArgs.stdout.contains("pptx-tool render <file.pptx> <directory> [--font FONT_PATH ...] [--strict] [--notes] [--max-uncompressed BYTES]"))
            #expect(noArgs.stdout.contains("render    "))
        }
    }

    @Test func enforcesMaxUncompressedEndOfOptionsDashFilenameAndMissingFile() throws {
        try Self.withScratchDir { dir in
            let deckURL = dir.appendingPathComponent("budget.pptx")
            try Presentation().save(to: deckURL)

            // Both equals-form and space-separated --max-uncompressed enforce the 1024-byte ceiling.
            let tightEquals = try Self.runCLI(["validate", deckURL.path, "--max-uncompressed=1024"])
            #expect(tightEquals.status == 1)
            #expect(tightEquals.stdout.contains("INVALID:"))

            let tightSpace = try Self.runCLI(["validate", deckURL.path, "--max-uncompressed", "1024"])
            #expect(tightSpace.status == 1)
            #expect(tightSpace.stdout.contains("INVALID:"))

            // Flag before positional argument works in both forms.
            let unlimitedEquals = try Self.runCLI(["validate", "--max-uncompressed=0", deckURL.path])
            #expect(unlimitedEquals.status == 0)
            #expect(unlimitedEquals.stdout.contains("OK:"))

            let unlimitedSpace = try Self.runCLI(["validate", "--max-uncompressed", "0", deckURL.path])
            #expect(unlimitedSpace.status == 0)
            #expect(unlimitedSpace.stdout.contains("OK:"))

            // `--` end-of-options allows a `-`-prefixed relative filename that otherwise fails as an option.
            let dashName = "-dash-prefixed.pptx"
            try Presentation().save(to: dir.appendingPathComponent(dashName))
            let withoutEndOfOptions = try Self.runCLI(["validate", dashName], currentDirectoryURL: dir)
            #expect(withoutEndOfOptions.status == 2)
            #expect(withoutEndOfOptions.stderr.contains(dashName))

            let withEndOfOptions = try Self.runCLI(["validate", "--", dashName], currentDirectoryURL: dir)
            #expect(withEndOfOptions.status == 0)
            #expect(withEndOfOptions.stdout.contains("OK: \(dashName)"))

            // Nonexistent input path exits 2 (cannot read) on stderr rather than exit 1.
            let missing = try Self.runCLI(["inspect", dir.appendingPathComponent("does-not-exist.pptx").path])
            #expect(missing.status == 2)
            #expect(missing.stderr.contains("cannot read"))
        }
    }

    @Test func inspectSurfacesReadWarningsResolvesSymlinkBytesAndValidSubcommandsRemainIntact() throws {
        try Self.withScratchDir { dir in
            let warnDeckURL = dir.appendingPathComponent("orphan-warn.pptx")
            try Self.makeDeckWithCorruptOrphanRelsWarning(at: warnDeckURL)
            let expectedBytes = try Data(contentsOf: warnDeckURL).count
            #expect(expectedBytes > 1000)

            let inspected = try Self.runCLI(["inspect", warnDeckURL.path])
            #expect(inspected.status == 0)
            #expect(inspected.stdout.contains("bytes:     \(expectedBytes)"))
            #expect(inspected.stdout.contains("readWarnings: 1"))
            #expect(inspected.stdout.contains("slide99.xml.rels"))
            #expect(inspected.stdout.contains("validate:  OK"))

            // Symlinked .pptx reports the target archive's true byte size rather than the symlink path length.
            let symlinkURL = dir.appendingPathComponent("symlink-deck.pptx")
            try FileManager.default.createSymbolicLink(
                atPath: symlinkURL.path,
                withDestinationPath: warnDeckURL.lastPathComponent
            )
            let symlinkInspected = try Self.runCLI(["inspect", symlinkURL.path])
            #expect(symlinkInspected.status == 0)
            #expect(symlinkInspected.stdout.contains("file:      \(symlinkURL.path)"))
            #expect(symlinkInspected.stdout.contains("bytes:     \(expectedBytes)"))
            #expect(symlinkInspected.stdout.contains("readWarnings: 1"))

            // Verify valid render (--font=..., --notes, --strict) and extract (--include-poster) invocations.
            let richDeck = try Presentation()
            richDeck.theme.majorFont = "DejaVu Sans"
            richDeck.theme.minorFont = "DejaVu Sans"
            let slide = try richDeck.slides[0]
            let box = try slide.shapes.addTextBox(Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1)))
            box.textFrame?.text = "CLI smoke"
            box.textFrame?.paragraphs.first?.runs.first?.fontName = "DejaVu Sans"
            try slide.setNotes("Speaker note body")
            let richURL = dir.appendingPathComponent("rich.pptx")
            try richDeck.save(to: richURL)

            let fontURL = Self.repoRoot
                .appendingPathComponent("Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
            let renderDir = dir.appendingPathComponent("rendered", isDirectory: true)
            let renderSlide = try Self.runCLI([
                "render", richURL.path, renderDir.path,
                "--font=\(fontURL.path)", "--strict",
            ])
            #expect(renderSlide.status == 0, "render failed: \(renderSlide.stderr)")
            #expect(FileManager.default.fileExists(atPath: renderDir.appendingPathComponent("slide-01.svg").path))

            let renderNotes = try Self.runCLI([
                "render", richURL.path, renderDir.path,
                "--font", fontURL.path, "--notes",
            ])
            #expect(renderNotes.status == 0, "notes render failed: \(renderNotes.stderr)")
            #expect(FileManager.default.fileExists(atPath: renderDir.appendingPathComponent("notes-01.svg").path))

            let extractDir = dir.appendingPathComponent("extracted", isDirectory: true)
            let extracted = try Self.runCLI(["extract", richURL.path, extractDir.path, "--include-poster"])
            #expect(extracted.status == 0, "extract failed: \(extracted.stderr)")
            #expect(extracted.stdout.contains("wrote "))
        }
    }
}

#endif
