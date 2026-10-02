#!/usr/bin/env python3
"""Pin default-language Arabic output from HarfBuzz 14.4.0; no runtime dependency."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[2]
FIXTURE=ROOT/'Tests/RostrumTests/Fixtures/Typography'
SUPPORTED=['ب','بب','ببب','اب','با','باب','سلام','لا','لأ','لإ','لآ','لله','الله','مرحبا بالعالم','العربية','فارسی','پاکستان','اردو','كـتاب','ب\u200dب','ب\u200cب','ب\u200c\u200dب','ب\u200d\u200cب','ل\u200dا','ل\u200cا','ب\u200d','\u200dب','سلام ','  سلام','ا\u0654','بَ','مِّ','بَ\u200dب']
NEGATIVE=['سَلَام','سلام ABC','سلام אבג','سلام 123','سلام ١٢٣','(سلام)','سلام\u2067ABC\u2069']
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font',type=Path,default=FIXTURE/'DejaVuSans.ttf')
    parser.add_argument('--output',type=Path,default=FIXTURE/'arabic-harfbuzz-14.4.0.json')
    args=parser.parse_args()
    version=subprocess.check_output(['hb-shape','--version'],text=True).splitlines()[0]
    assert version=='hb-shape (HarfBuzz) 14.4.0'
    cases=[]
    for text in SUPPORTED+NEGATIVE:
        glyphs=json.loads(subprocess.check_output(['hb-shape',str(args.font),text,'--no-glyph-names','--output-format=json','--direction=rtl','--script=arab','--language=und']))
        cases.append({'text':text,'direction':'rtl','supported':text in SUPPORTED,'glyphs':glyphs})
    args.output.write_text(json.dumps({'engine':version,'fontSHA256':hashlib.sha256(args.font.read_bytes()).hexdigest(),'script':'arab','language':'und','cases':cases},ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
