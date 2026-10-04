import Foundation

/// Metrics-driven text layout: word wrapping, block height, and the
/// PowerPoint-style shrink-to-fit computation (`a:normAutofit`).
///
/// This replaces character-count guesswork with real advance widths. The
/// contract is honest rather than pixel-perfect: greedy word wrap on spaces
/// (character-level fallback for words wider than the box), no kerning or
/// shaping — see `FontMetrics` for the measurement model.
public struct TextMeasurer: Sendable {
    public let metrics: FontMetrics

    public init(_ metrics: FontMetrics) {
        self.metrics = metrics
    }

    /// The width of a single line of `text` at `pointSize`, in points.
    public func width(of text: String, pointSize: Double) -> Double {
        metrics.width(of: text, pointSize: pointSize)
    }

    /// Wrap `text` into lines no wider than `width` points: hard newlines are
    /// respected, then greedy word wrap on spaces (runs of spaces collapse to
    /// one). A word wider than the box breaks mid-word rather than
    /// overflowing. Every input, including "", yields at least one line.
    ///
    /// Widths are tracked as a running sum of advance units — measurement is
    /// a pure per-scalar sum, so adding one word's units is EXACTLY the width
    /// of re-measuring the whole line, without the quadratic re-walk.
    public func wrap(_ text: String, pointSize: Double, width: Double) -> [String] {
        var lines: [String] = []
        let spaceUnits = metrics.advance(of: " ")
        for hardLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let words = hardLine.split(separator: " ").map(String.init)
            guard !words.isEmpty else {
                lines.append("")
                continue
            }
            var current = ""
            var currentUnits = 0
            for word in words {
                let wordUnits = units(of: word)
                let candidateUnits = current.isEmpty
                    ? wordUnits : currentUnits + spaceUnits + wordUnits
                if points(candidateUnits, at: pointSize) <= width {
                    if !current.isEmpty { current += " " }
                    current += word
                    currentUnits = candidateUnits
                } else if current.isEmpty {
                    (current, currentUnits) = breakOversizedWord(
                        word, pointSize: pointSize, width: width, into: &lines)
                } else {
                    lines.append(current)
                    if points(wordUnits, at: pointSize) <= width {
                        current = word
                        currentUnits = wordUnits
                    } else {
                        (current, currentUnits) = breakOversizedWord(
                            word, pointSize: pointSize, width: width, into: &lines)
                    }
                }
            }
            lines.append(current)
        }
        return lines.isEmpty ? [""] : lines
    }

    /// The advance-unit sum of `text` — the integer half of `width(of:)`.
    private func units(of text: String) -> Int {
        var total = 0
        for scalar in text.unicodeScalars { total += metrics.advance(of: scalar) }
        return total
    }

    /// Advance units to points, converting exactly as `FontMetrics.width(of:)`
    /// does so the running-sum comparison matches a full re-measure.
    private func points(_ units: Int, at pointSize: Double) -> Double {
        Double(units) / Double(metrics.unitsPerEm) * pointSize
    }

    /// Character-break a word wider than the box, appending all full lines and
    /// returning the (possibly empty) remainder — and its advance units — to
    /// continue the current line. Always makes progress: at least one
    /// character per line.
    private func breakOversizedWord(
        _ word: String, pointSize: Double, width: Double, into lines: inout [String]
    ) -> (remainder: String, units: Int) {
        var current = ""
        var currentUnits = 0
        for character in word {
            var characterUnits = 0
            for scalar in character.unicodeScalars {
                characterUnits += metrics.advance(of: scalar)
            }
            let candidateUnits = currentUnits + characterUnits
            if !current.isEmpty, points(candidateUnits, at: pointSize) > width {
                lines.append(current)
                current = String(character)
                currentUnits = characterUnits
            } else {
                current.append(character)
                currentUnits = candidateUnits
            }
        }
        return (current, currentUnits)
    }

    /// The height of `text` wrapped into `width` points, in points.
    /// `lineSpacing` is a multiple of single spacing (1.0 = single).
    public func height(
        of text: String, pointSize: Double, width: Double, lineSpacing: Double = 1.0
    ) -> Double {
        Double(wrap(text, pointSize: pointSize, width: width).count)
            * metrics.lineHeight(pointSize: pointSize) * lineSpacing
    }

    // MARK: - Autofit

    /// Library search steps for `a:normAutofit`, evaluated against shared layout.
    /// These discrete candidates are not a claim about native PowerPoint
    /// choosing the same scale; the search ends at 25% / 20% reduction.
    static let autofitLadder: [(scale: Double, reduction: Double)] = [
        (100, 0), (92.5, 0), (85, 0),
        (77.5, 10), (70, 10),
        (62.5, 20), (55, 20), (50, 20), (45, 20),
        (40, 20), (35, 20), (30, 20), (25, 20),
    ]

    /// Find the first ladder step at which every paragraph, wrapped at its
    /// scaled size, fits inside `width` × `height` points. `fits == false`
    /// means even the floor step overflows (the returned floor values are
    /// the smallest candidate this search evaluates).
    public func autofit(
        paragraphs: [(text: String, pointSize: Double)],
        width: Double, height: Double, lineSpacing: Double = 1.0
    ) -> Autofit {
        for step in Self.autofitLadder {
            let spacing = lineSpacing * (1 - step.reduction / 100)
            let total = paragraphs.reduce(0.0) { sum, paragraph in
                sum + self.height(of: paragraph.text,
                                  pointSize: paragraph.pointSize * step.scale / 100,
                                  width: width, lineSpacing: spacing)
            }
            if total <= height + 0.01 {
                return Autofit(fontScale: step.scale,
                               lineSpacingReduction: step.reduction, fits: true)
            }
        }
        let floor = Self.autofitLadder[Self.autofitLadder.count - 1]
        return Autofit(fontScale: floor.scale,
                       lineSpacingReduction: floor.reduction, fits: false)
    }
}

/// A computed `a:normAutofit`: the font scale and line-spacing reduction
/// the library computes so the text fits its frame.
public struct Autofit: Sendable, Equatable {
    /// Percent, 100 = unscaled. Written as `fontScale` thousandths when < 100.
    public let fontScale: Double
    /// Percent, 0 = none. Written as `lnSpcReduction` thousandths when > 0.
    public let lineSpacingReduction: Double
    /// False when even the smallest expressible step still overflows.
    public let fits: Bool
}

// MARK: - Applying autofit to a text frame

extension TextFrame {
    /// PowerPoint's default text-frame insets (0.1" sides, 0.05" top/bottom),
    /// used when `a:bodyPr` doesn't override them.
    private static let defaultInsets = (left: 91_440, top: 45_720, right: 91_440, bottom: 45_720)

    /// Measure the frame's current text with real font metrics and write a
    /// *computed* `a:normAutofit` using the library's discrete scale/spacing
    /// search, so the shared layout fits inside `frame` (the
    /// owning shape's frame, minus this body's insets).
    /// Table cells are measured once at full size with their live cell padding
    /// and anchor. They return 100%/0% and do not modify XML: native cells ignore
    /// stored font scaling. Unsupported cell spacing reduction returns fits=false.
    ///
    /// Runs without an explicit size measure at `defaultPointSize`. Returns
    /// the chosen step; `fits == false` means the floor step still overflows
    /// and the content itself needs trimming.
    @discardableResult
    public func fitText(
        in frame: Rect, using metrics: FontMetrics,
        defaultPointSize: Double = 18, lineSpacing: Double = 1.0
    ) -> Autofit {
        fitRichText(in: frame, fonts: nil, fallbackMetrics: metrics,
                    defaultPointSize: defaultPointSize, lineSpacing: lineSpacing)
    }

    /// Fit mixed families/styles with the same explicit registry used by SVG.
    /// Supply the same theme and inherited paragraph styles to resolve placeholders.
    /// Cell frames measure full-size native geometry without writing autofit;
    /// overflow or unverified stored cell spacing reduction returns fits=false.
    @discardableResult
    public func fitText(in frame: Rect, fonts: FontLibrary, theme: Theme? = nil,
                        inheritedStyles: [XML.Element] = [], defaultPointSize: Double = 18,
                        lineSpacing: Double = 1) -> Autofit {
        fitRichText(in: frame, fonts: fonts, fallbackMetrics: nil, theme: theme,
                    inheritedStyles: inheritedStyles, defaultPointSize: defaultPointSize,
                    lineSpacing: lineSpacing)
    }

    fileprivate func fitRichText(in frame: Rect, fonts: FontLibrary?, fallbackMetrics: FontMetrics?,
                             theme: Theme? = nil, inheritedStyles: [XML.Element] = [],
                             defaultPointSize: Double, lineSpacing: Double) -> Autofit {
        let bound = OOXMLBounds.coordinate
        let width = Double(bound.contains(frame.width.rawValue) ? frame.width.rawValue : 0) / Double(EMU.perPoint)
        let height = Double(bound.contains(frame.height.rawValue) ? frame.height.rawValue : 0) / Double(EMU.perPoint)
        if let tableCell {
            let cell = tableCell.fittingContext(theme: theme)
            let vertical = ["vert", "vert270"].contains(cell.direction)
            let layout = RichTextLayout(textBody: txBody, width: vertical ? height : width,
                height: vertical ? width : height, fonts: fonts, fallbackMetrics: fallbackMetrics,
                theme: cell.theme, inheritedStyles: inheritedStyles.isEmpty ? cell.styles : inheritedStyles,
                defaultPointSize: defaultPointSize, lineSpacing: lineSpacing,
                fontScale: 100, lineSpacingReduction: 0, maxLines: 64,
                insets: cell.insets, verticalAnchor: cell.anchor, context: .tableCell)
            let unverifiedReduction = layout.diagnostics.contains(.unsupportedLayoutFeature("Native table line-spacing reduction is not verified"))
            return Autofit(fontScale: 100, lineSpacingReduction: 0, fits: layout.fits && !unverifiedReduction)
        }
        var result = Autofit(fontScale: 25, lineSpacingReduction: 20, fits: false)
        for step in TextMeasurer.autofitLadder {
            let layout = RichTextLayout(textBody: txBody, width: width, height: height,
                fonts: fonts, fallbackMetrics: fallbackMetrics, theme: theme,
                inheritedStyles: inheritedStyles, defaultPointSize: defaultPointSize,
                lineSpacing: lineSpacing, fontScale: step.scale, lineSpacingReduction: step.reduction, maxLines: 64)
            if layout.fits {
                result = Autofit(fontScale: step.scale, lineSpacingReduction: step.reduction, fits: true)
                break
            }
        }
        let bodyPr = txBody.getOrAddChild("a:bodyPr", beforeAnyOf: ["a:lstStyle", "a:p"])
        apply(result, to: bodyPr)
        return result
    }

    /// Write `autofit` into `a:bodyPr` as `a:normAutofit`, replacing any other
    /// member of the autofit choice group. A no-op result (100%, 0%) still
    /// writes the bare element — "shrink on overflow" stays enabled.
    private func apply(_ autofit: Autofit, to bodyPr: XML.Element) {
        bodyPr.removeChildren(named: "a:noAutofit")
        bodyPr.removeChildren(named: "a:spAutoFit")
        let element = bodyPr.getOrAddChild("a:normAutofit")
        element[attribute: "fontScale"] = autofit.fontScale >= 100
            ? nil : String(Int((autofit.fontScale * 1000).rounded()))
        element[attribute: "lnSpcReduction"] = autofit.lineSpacingReduction <= 0
            ? nil : String(Int((autofit.lineSpacingReduction * 1000).rounded()))
        part.markDirty()
    }
}

extension Shape {
    /// Fit with the deck's explicit face registry and resolved theme context.
    @discardableResult
    public func fitText(fonts: FontLibrary, theme: Theme? = nil,
                        inheritedStyles: [XML.Element] = [], defaultPointSize: Double = 18,
                        lineSpacing: Double = 1) -> Autofit? {
        let styles = inheritedStyles.isEmpty ? package.map {
            RichTextLayout.inheritedStyles(for: element, owner: part, package: $0)
        } ?? [] : inheritedStyles
        var resolvedTheme = theme
        if resolvedTheme == nil, let package,
           let layout = try? part.related(by: RelType.slideLayout, in: package),
           let master = try? layout.related(by: RelType.slideMaster, in: package),
           let themePart = try? master.related(by: RelType.theme, in: package) {
            resolvedTheme = Theme(part: themePart, master: master)
        }
        return textFrame?.fitText(in: frame, fonts: fonts, theme: resolvedTheme,
            inheritedStyles: styles, defaultPointSize: defaultPointSize, lineSpacing: lineSpacing)
    }

    /// Fit this shape's text to its own frame using real font metrics: the
    /// one-call form of `TextFrame.fitText(in:using:)`. Returns nil when the
    /// shape has no text body.
    @discardableResult
    public func fitText(
        using metrics: FontMetrics,
        defaultPointSize: Double = 18, lineSpacing: Double = 1.0
    ) -> Autofit? {
        let styles = package.map { RichTextLayout.inheritedStyles(for: element, owner: part, package: $0) } ?? []
        return textFrame?.fitRichText(in: frame, fonts: nil, fallbackMetrics: metrics,
            inheritedStyles: styles, defaultPointSize: defaultPointSize, lineSpacing: lineSpacing)
    }
}


extension TableCell {
    /// Resolve on each fitting operation so style, theme and cell edits remain live.
    fileprivate func fittingContext(theme: Theme?) -> (insets: (left: Double, top: Double, right: Double, bottom: Double), anchor: String, direction: String, styles: [XML.Element], theme: Theme?) {
        var resolvedTheme = theme
        if resolvedTheme == nil, let package,
           let layout = try? part.related(by: RelType.slideLayout, in: package),
           let master = try? layout.related(by: RelType.slideMaster, in: package),
           let themePart = try? master.related(by: RelType.theme, in: package) {
            resolvedTheme = Theme(part: themePart, master: master)
        }
        var properties = tc.firstChild(named: "a:tcPr") ?? XML.Element("a:tcPr")
        var styles: [XML.Element] = []
        if let owner, let resolvedTheme {
            let resolver = TableStyleResolver(table: owner, theme: resolvedTheme)
            outer: for row in resolver.grid.cells.indices {
                for column in resolver.grid.cells[row].indices where resolver.grid.cells[row][column] === tc {
                    let effective = resolver.effective(row: row, column: column)
                    properties = effective.properties; styles = [effective.text]
                    break outer
                }
            }
        }
        func inset(_ key: String, _ fallback: Int) -> Double {
            Double(properties.coordinate(key) ?? fallback) / Double(EMU.perPoint)
        }
        return ((inset("marL", 91440), inset("marT", 45720), inset("marR", 91440), inset("marB", 45720)),
                properties[attribute: "anchor"] ?? "t", properties[attribute: "vert"] ?? "horz", styles, resolvedTheme)
    }
}
