#!/usr/bin/env python3
"""Create the licensed outline font used to exercise missing-symbol previews."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parents[2]
assets = root / 'Lectern/Sources/LecternCore/Resources/LibraryLab'
font = TTFont(assets / 'DejaVuSans.ttf', recalcTimestamp=False)
options = subset.Options()
options.recalc_timestamp = False
options.layout_features = []
options.name_IDs = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=range(32, 127))
subsetter.subset(font)
for record in font['name'].names:
    names = {1: 'Rostrum Lab Latin', 2: 'Regular', 3: 'RostrumLabLatin-1',
             4: 'Rostrum Lab Latin', 6: 'RostrumLabLatin', 16: 'Rostrum Lab Latin', 17: 'Regular'}
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding())
font.save(assets / 'RostrumLabLatin.ttf')
