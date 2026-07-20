# Third-party licenses

## python-pptx

Rostrum began as a ground-up Swift port of
[python-pptx](https://github.com/scanny/python-pptx) and remains deeply
indebted to it — its API design, its layered architecture, and above all its
encoded knowledge of the Office Open XML schema.

Beyond design inspiration, **parts of Rostrum are mechanically derived from
python-pptx's source declarations**:

- `Sources/Rostrum/Schema/GeneratedSchema.swift` — element child-ordering and
  attribute tables extracted from python-pptx's `oxml`/`xmlchemy` descriptors
  by `Tools/extract-schema.py` + `Tools/rostrum-gen`.
- `Sources/Rostrum/Schema/PresetGeometry.swift` — preset shape names and
  adjustment values generated from python-pptx's `MSO_AUTO_SHAPE_TYPE`
  (`enum/shapes.py`).

Those portions are used under python-pptx's MIT License, reproduced in full
below as its terms require.

```
MIT License

Copyright (c) 2013 Steve Canny, https://github.com/scanny

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.
```

## ECMA-376 (Office Open XML)

The `.pptx` format Rostrum reads and writes is specified by
[ECMA-376](https://ecma-international.org/publications-and-standards/standards/ecma-376/),
which Ecma International makes available royalty-free. Rostrum implements the
specification; it includes no text from it.
