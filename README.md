# Rostrum

A pure-Swift library for creating and editing PowerPoint (`.pptx`) files. No
dependencies — Rostrum owns its entire stack, from the zip container and
DEFLATE decoder up through the OPC packaging layer and the PresentationML
object model. Runs anywhere Swift runs: macOS, iOS, Linux.

Rostrum is a ground-up port of [python-pptx](https://github.com/scanny/python-pptx)
with a Swift-native API — and an explicit ambition to go beyond it (SmartArt,
theme/brand editing, and more; see [ROADMAP.md](ROADMAP.md)).

```swift
import Rostrum

let deck = try Presentation()          // one blank 16:9 slide
deck.slideSize = (width: .inches(10), height: .inches(7.5))
try deck.save(to: URL(filePath: "hello.pptx"))
```

## Status

Early. Today Rostrum can create a valid minimal deck that PowerPoint, Keynote
and python-pptx itself all open, and can read `.pptx` packages (STORED and
DEFLATE entries) losslessly at the part level. The slide/shape object model is
under active construction.

## Layers

| Layer | Location | python-pptx counterpart |
|---|---|---|
| Zip container (read/write, pure-Swift inflate) | `Sources/Rostrum/Zip` | Python's `zipfile` |
| XML DOM (parse/serialize, prefix-preserving) | `Sources/Rostrum/XML` | `lxml` |
| OPC packaging (parts, content types, relationships) | `Sources/Rostrum/OPC` | `pptx.opc` |
| PresentationML object model | `Sources/Rostrum/Presentation` | `pptx.parts` + API layer |

## Development

```sh
swift test
```
