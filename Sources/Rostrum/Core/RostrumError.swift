/// Errors thrown by Rostrum.
public enum RostrumError: Error, Equatable, CustomStringConvertible {
    /// The zip container is structurally invalid (bad signature, truncated record, CRC mismatch, …).
    case zipCorrupt(String)
    /// The zip container uses a feature Rostrum does not support yet (e.g. zip64, encryption, an exotic compression method).
    case zipUnsupported(String)
    /// A DEFLATE stream could not be decoded.
    case deflateCorrupt(String)
    /// An XML part could not be parsed.
    case xmlMalformed(String)
    /// The OPC package violates packaging rules ([Content_Types].xml missing, dangling relationship, …).
    case packageInvalid(String)
    /// A required part is absent from the package.
    case partMissing(String)
    /// The file is a valid OPC package but not a PresentationML document.
    case notAPresentation(String)
    /// A font's embedding permission (OS/2 fsType) forbids embedding it.
    case fontEmbeddingRestricted(String)
    /// A font file could not be parsed (truncated table, bad offset, unsupported cmap, …).
    case fontCorrupt(String)
    /// The entries a name resolves to declare more uncompressed bytes in total
    /// than the caller's `ZipReader.Limits` allows. Shadowed records are not
    /// counted: they can never be fetched, so they cost nothing. Distinct from `zipUnsupported` because this is
    /// the caller's own policy firing, not a capability Rostrum lacks: it is the
    /// one error here that retrying with a higher ceiling can resolve, and both
    /// numbers are carried so that decision can be made without parsing prose.
    case readBudgetExceeded(declared: UInt64, limit: Int)

    public var description: String {
        switch self {
        case .zipCorrupt(let m): return "corrupt zip archive: \(m)"
        case .zipUnsupported(let m): return "unsupported zip feature: \(m)"
        case .deflateCorrupt(let m): return "corrupt DEFLATE stream: \(m)"
        case .xmlMalformed(let m): return "malformed XML: \(m)"
        case .packageInvalid(let m): return "invalid OPC package: \(m)"
        case .partMissing(let m): return "missing package part: \(m)"
        case .notAPresentation(let m): return "not a PresentationML package: \(m)"
        case .fontEmbeddingRestricted(let m): return "font embedding is license-restricted: \(m)"
        case .fontCorrupt(let m): return "corrupt font file: \(m)"
        case .readBudgetExceeded(let declared, let limit):
            return "the archive's readable entries declare \(declared) uncompressed bytes, "
                + "over the \(limit)-byte read budget"
        }
    }
}
