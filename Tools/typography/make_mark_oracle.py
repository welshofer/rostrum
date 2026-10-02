#!/usr/bin/env python3
"""Pin unhinted design-unit GPOS mark geometry with HarfBuzz 14.4.0.

FontTools is a development-only fixture assembler. MarkAttachments.ttf contains
owned empty outlines and synthetic rules, under the repository license.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'Tests/RostrumTests/Fixtures/Typography'
POSITIVE = ['بَ', 'بِ', 'بُ', 'بْ', 'بَبِ', 'بَ بُ', 'بَ\u200dب', 'مِّ',
            'x\u0301', 'x\u0301\u0300', 'q\u0301\u0323', 'x\u0302\u0301', 'x\u0301 x\u0300']
NEGATIVE = ['لَا', 'سَلَام', '\u0301', 'ff\u0301', 'i\u030B', 'שָׁ']

def owned_font(path):
    cmap = {32:'space', 65:'A', 86:'V', 102:'f', 105:'i', 113:'q', 120:'x',
            0x0301:'acute', 0x0300:'grave', 0x0323:'below', 0x0302:'circumflex'}
    order = ['.notdef'] + list(cmap.values()) + ['fi']
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order); fb.setupCharacterMap(cmap)
    fb.setupGlyf({name:TTGlyphPen(None).glyph() for name in order})
    # Nonzero mark metrics prove that the shaper, not hmtx, zeros advances.
    fb.setupHorizontalMetrics({name:(240 if name in ['acute','grave','below','circumflex'] else 600,0) for name in order})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({'familyName':'Rostrum Mark Oracle', 'styleName':'Regular'})
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
    fb.setupPost(); fb.setupMaxp()
    addOpenTypeFeaturesFromString(fb.font, '''
        languagesystem latn dflt;
        @Bases = [A V f i q x space];
        @Marks = [acute grave below circumflex];
        @Upper = [acute grave circumflex];
        markClass acute <anchor 40 100> @Above;
        markClass grave <anchor 60 80> @Above;
        markClass circumflex <anchor 50 90> @Above;
        markClass below <anchor 30 -20> @Below;
        table GDEF { GlyphClassDef @Bases, [fi], @Marks, ; } GDEF;
        feature liga { lookupflag IgnoreMarks; sub f i by fi; } liga;
        lookup Base useExtension {
            pos base @Bases <anchor 300 700> mark @Above <anchor 280 -100> mark @Below;
        } Base;
        lookup Stack useExtension {
            lookupflag MarkAttachmentType @Upper UseMarkFilteringSet @Marks;
            pos mark below <anchor 100 250> mark @Above;
            pos mark acute <anchor 100 250> mark @Above;
            pos mark grave <anchor 120 220> mark @Above;
            pos mark circumflex <anchor 130 270> mark @Above;
        } Stack;
        feature mkmk { lookup Stack; } mkmk;
        feature mark { lookup Base; } mark;
    ''')
    fb.font['head'].created = fb.font['head'].modified = 2082844800
    fb.font.recalcTimestamp = False
    fb.save(path)

def record(font, positive, negative=()):
    cases=[]
    for text in list(positive)+list(negative):
        arabic = any(0x0600 <= ord(c) <= 0x06ff for c in text)
        rtl = arabic or text.startswith('ש')
        args=['hb-shape',str(font),text,'--output-format=json','--no-glyph-names',
              '--direction='+('rtl' if rtl else 'ltr'),'--language=und']
        if arabic: args.append('--script=arab')
        cases.append({'text':text,'direction':'rtl' if rtl else 'ltr','supported':text in positive,
                      'glyphs':json.loads(subprocess.check_output(args))})
    return {'fontSHA256':hashlib.sha256(font.read_bytes()).hexdigest(), 'cases':cases}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local-font',type=Path)
    parser.add_argument('--local-output',type=Path)
    args=parser.parse_args()
    version=subprocess.check_output(['hb-shape','--version'],text=True).splitlines()[0]
    assert version=='hb-shape (HarfBuzz) 14.4.0'
    if args.local_font:
        assert args.local_output
        # Local evidence covers residual Latin marks. Proprietary Arabic GSUB2
        # and other unsupported requirements retain their existing diagnostics.
        data=record(args.local_font,[s for s in POSITIVE if s.startswith(('x','q'))])
        data.update(engine=version,fontPath=str(args.local_font.resolve()))
        args.local_output.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        return
    font=FIXTURE/'MarkAttachments.ttf'; owned_font(font)
    data={'engine':version,'fonts':{
        'DejaVuSans.ttf':record(FIXTURE/'DejaVuSans.ttf',POSITIVE,NEGATIVE),
        'MarkAttachments.ttf':record(font,['x́','x́̀','q̣́','x̂́','x́ x̀','AVx́'],['fí','́'])}}
    (FIXTURE/'marks-harfbuzz-14.4.0.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
