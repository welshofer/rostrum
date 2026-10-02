#!/usr/bin/env python3
"""Pin local Calibri evidence and owned one-component GSUB cases with HB 14.4.0.
No proprietary font bytes are copied. --verify checks hashes and exact oracles.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
from make_lookup_oracle import font, u16, u32, gid, coverage, reference
ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'Tests/RostrumTests/Fixtures/Typography'
LOCAL = Path('/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts')
HASHES = {'Calibri.ttf': 'ea801e1f869b55464339058b1d4263d07cc074a18e20aa3ee1d07901423dee53',
          'Calibrib.ttf': 'ac1cf97565de97cdc322228d875dc18c1131656c5138173e2c6d8ac7a37aa7f2'}
TEXTS = ['AV', 'To WA', 'office', 'fi fl ffi ffl', 'Typography 123', 'HHH', 'AVATAR',
         'Table 01', 'Revenue ($)', '42.5%', 'First row', 'Last column', '1234567890',
         'WAVY Toffee', 'café naïve', 'cafe\u0301', 'ffiffiffi', '  spaced  text  ']
def owned(wrapped=False):
    data=font(); tables={}
    for i in range(struct.unpack_from('>H',data,4)[0]):
        tag,_,offset,size=struct.unpack_from('>4sIII',data,12+16*i)
        if tag not in [b'GDEF',b'GPOS',b'GSUB']: tables[tag]=data[offset:offset+size]
    scripts=u16(1)+b'latn'+u16(8,4,0,0,65535,1,0)
    features=u16(1)+b'liga'+u16(8,0,1,0)
    # f -> F, g -> g; both consume exactly one glyph, including the identity.
    sub=u16(1,10,2,18,26)+coverage([gid('f'),gid('g')])
    sub+=u16(1,4,gid('F'),1)+u16(1,4,gid('g'),1)
    lookup=u16(1,4)+u16(4,0,1,8)+sub
    tables[b'GSUB']=u16(1,0,10,10+len(scripts),10+len(scripts)+len(features))+scripts+features+lookup
    if wrapped:
        del tables[b'GSUB']
        tables[b'maxp']=u32(0x5000)+u16(128)
        tables[b'hhea']=tables[b'hhea'][:34]+u16(128)
        tables[b'hmtx']=u16(600,0)*128
        count=11000;power=8192
        tables[b'kern']=u16(0,1,0,14+6*count,1,count,power*6,13,(count-power)*6)
        tables[b'kern']+=b''.join(u16(key//128,key%128,-20) for key in range(count))
    directory=u32(0x10000)+u16(len(tables),128,3,0);body=b''
    for tag,content in sorted(tables.items()):
        padded=content+b'\0'*(-len(content)%4)
        checksum=sum(struct.unpack('>'+'I'*(len(padded)//4),padded))&0xffffffff
        directory+=tag+u32(checksum,12+16*len(tables)+len(body),len(content));body+=padded
    return directory+body

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font-directory',type=Path,default=LOCAL)
    parser.add_argument('--verify',action='store_true')
    args=parser.parse_args()
    version=subprocess.check_output(['hb-shape','--version'],text=True).splitlines()[0]
    assert version=='hb-shape (HarfBuzz) 14.4.0'
    target=FIXTURE/'SingleComponentLigature.ttf'
    content=owned()
    if args.verify: assert target.read_bytes()==content
    else: target.write_bytes(content)
    result={'engine':version,'fonts':[]}
    for name,expected in HASHES.items():
        path=args.font_directory/name
        actual=hashlib.sha256(path.read_bytes()).hexdigest()
        assert actual==expected,(name,actual,'does not match pinned font')
        result['fonts'].append({'fileName':name,'fontSHA256':actual,'cases':reference(path,TEXTS)})
    result['owned']={'fileName':target.name,'fontSHA256':hashlib.sha256(content).hexdigest(),
                     'cases':reference(target,['fg','gggg','ffff','gfgf','f g'])}
    target=FIXTURE/'WrappedKern.ttf'; content=owned(wrapped=True)
    if args.verify: assert target.read_bytes()==content
    else: target.write_bytes(content)
    result['wrapped']={'fileName':target.name,'fontSHA256':hashlib.sha256(content).hexdigest(),
                       'cases':reference(target,['AV','office','To WA','ffff','zzzz'])}
    encoded=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    output=FIXTURE/'calibri-harfbuzz-14.4.0.json'
    if args.verify: assert output.read_text()==encoded
    else: output.write_text(encoded)
if __name__=='__main__': main()
