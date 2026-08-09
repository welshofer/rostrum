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

    /// PowerPoint's shrink-to-fit ladder, as it steps `a:normAutofit`: font
    /// scale falls in 7.5-point steps and line-spacing reduction kicks in as
    /// the scale drops, bottoming out at 25% scale / 20% reduction.
    static let autofitLadder: [(scale: Double, reduction: Double)] = [
        (100, 0), (92.5, 0), (85, 0),
        (77.5, 10), (70, 10),
        (62.5, 20), (55, 20), (50, 20), (45, 20),
        (40, 20), (35, 20), (30, 20), (25, 20),
    ]

    /// Find the first ladder step at which every paragraph, wrapped at its
    /// scaled size, fits inside `width` × `height` points. `fits == false`
    /// means even the floor step overflows (the returned floor values are
    /// still the best the format can express).
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
/// PowerPoint would apply so the text fits its frame.
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
    /// *computed* `a:normAutofit` — `fontScale`/`lnSpcReduction` chosen the
    /// way PowerPoint steps them — so the text fits inside `frame` (the
    /// owning shape's frame, minus this body's insets).
    ///
    /// Runs without an explicit size measure at `defaultPointSize`. Returns
    /// the chosen step; `fits == false` means the floor step still overflows
    /// and the content itself needs trimming.
    @discardableResult
    public func fitText(
        in frame: Rect, using metrics: FontMetrics,
        defaultPointSize: Double = 18, lineSpacing: Double = 1.0
    ) -> Autofit {
        let bodyPr = txBody.getOrAddChild("a:bodyPr", beforeAnyOf: ["a:lstStyle", "a:p"])
        // Bounded: an inset read from an opened deck is subtracted from the
        // frame below, and Int subtraction traps on underflow.
        func inset(_ name: String, _ fallback: Int) -> Int {
            bodyPr.coordinate(name) ?? fallback
        }
        let insets = Self.defaultInsets
        // The frame is file-supplied too when this is reached via
        // `shape.fitText()` on an opened deck.
        let bound = OOXMLBounds.coordinate
        let frameWidth = bound.contains(frame.width.rawValue) ? frame.width.rawValue : 0
        let frameHeight = bound.contains(frame.height.rawValue) ? frame.height.rawValue : 0
        let contentWidth = frameWidth
            - inset("lIns", insets.left) - inset("rIns", insets.right)
        let contentHeight = frameHeight
            - inset("tIns", insets.top) - inset("bIns", insets.bottom)

        let measured = paragraphs.map { paragraph in
            (text: paragraph.runs.map(\.text).joined(),
             pointSize: paragraph.runs.compactMap(\.fontSize).max() ?? defaultPointSize)
        }
        let result = TextMeasurer(metrics).autofit(
            paragraphs: measured.isEmpty ? [(text: "", pointSize: defaultPointSize)] : measured,
            width: Double(Swift.max(0, contentWidth)) / Double(EMU.perPoint),
            height: Double(Swift.max(0, contentHeight)) / Double(EMU.perPoint),
            lineSpacing: lineSpacing)
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
    /// Fit this shape's text to its own frame using real font metrics: the
    /// one-call form of `TextFrame.fitText(in:using:)`. Returns nil when the
    /// shape has no text body.
    @discardableResult
    public func fitText(
        using metrics: FontMetrics,
        defaultPointSize: Double = 18, lineSpacing: Double = 1.0
    ) -> Autofit? {
        textFrame?.fitText(in: frame, using: metrics,
                           defaultPointSize: defaultPointSize, lineSpacing: lineSpacing)
    }
}
