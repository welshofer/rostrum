#!/usr/bin/env python3
"""Owned GSUB chained-context formats 1/2/3 and nested extension oracle font."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
from make_lookup_oracle import font, u16, u32, coverage, classes, layout, FIXTURE

def single(old,new,fmt=2):
    return u16(1,6,new-old)+coverage([old]) if fmt==1 else u16(2,8,1,new)+coverage([old])
def rule(back,input,look,records):
    return u16(len(back),*back,len(input)+1,*input,len(look),*look,len(records))+b''.join(u16(*r) for r in records)
def context1(first=2,records=None):
    cov=coverage([first]); rules=rule([1],[4],[5],records or [(0,3)])
    return u16(1,8,1,8+len(cov))+cov+u16(1,4)+rules

def consuming_context():
    cov=coverage([3])
    a=rule([1],[4,5],[6],[(0,7),(2,10)])
    b=rule([1],[4],[5],[(0,7),(1,8)])
    return u16(1,8,1,14)+cov+u16(2,6,6+len(a))+a+b

def context2():
    cov=coverage([6]);back=classes({1:1}); inp=classes({6:1,7:2}); look=classes({8:1})
    offsets=[16,16+len(cov),16+len(cov)+len(back),16+len(cov)+len(back)+len(inp)]
    start=offsets[-1]+len(look)
    return u16(2,offsets[0],offsets[1],offsets[2],offsets[3],2,0,start)+cov+back+inp+look+u16(1,4)+rule([1],[2],[1],[(1,4)])

def context3(back,input,look,records):
    headerSize=2+2+2*len(back)+2+2*len(input)+2+2*len(look)+2+4*len(records)
    body=b'';offsets=[]
    for glyph in back+input+look:
        offsets.append(headerSize+len(body));body+=coverage([glyph])
    a=len(back);b=a+len(input)
    return u16(3,a,*offsets[:a],len(input),*offsets[a:b],len(look),*offsets[b:],len(records))+b''.join(u16(*r) for r in records)+body

def assemble(tables):
    directory=u32(0x10000)+u16(len(tables),128,3,0);body=b''
    for tag,data in sorted(tables.items()):
        padded=data+b'\0'*(-len(data)%4)
        checksum=sum(struct.unpack('>'+'I'*(len(padded)//4),padded))&0xffffffff
        directory+=tag.encode()+u32(checksum,12+16*len(tables)+len(body),len(data));body+=padded
    return directory+body

def make():
    raw=font();n=struct.unpack_from('>H',raw,4)[0]
    tables={}
    for p in range(12,12+16*n,16):
        tag=raw[p:p+4].decode();offset,length=struct.unpack_from('>II',raw,p+8);tables[tag]=raw[offset:offset+length]
    tables['GPOS']=layout('kern',[('!','#',0,0),('#','!',0,0)]).replace(b'latn',b'arab')
    tables['GDEF']=u16(1,0,12,0,0,0)+u16(1,0,97,*([1]*97))
    tables['cmap']=u16(0,1,3,10)+u32(12)+u16(12,0)+u32(28,0,1,0x627,0x64A,1)
    subtables=[(6,context1()),(6,context2()),(6,context3([13],[9,11],[18],[(1,6)])),
               (1,single(2,70)),(1,single(7,71)),(7,u16(1,1)+u32(8)+single(11,72,1)),
               (6,context3([],[11],[18],[(0,5)])),
               (4,u16(1,8,1,14)+coverage([3])+u16(1,4,75,2,4)),
               (1,single(75,76)),(6,consuming_context()),(1,single(5,77))]
    lookups=[u16(kind,0,1,8)+sub for kind,sub in subtables]
    scripts=u16(1)+b'arab'+u16(8,4,0,0,65535,1,0)
    features=u16(1)+b'ccmp'+u16(8,0,4,0,1,2,9)
    offsets=[];body=b''
    for lookup in lookups:offsets.append(2+2*len(lookups)+len(body));body+=lookup
    tables['GSUB']=u16(1,0,10,10+len(scripts),10+len(scripts)+len(features))+scripts+features+u16(len(lookups),*offsets)+body
    return assemble(tables)

TEXTS=['اةتثج','اةتث','ابتث','بتث','ابث','ابتب','اجحخ','جحخ','اجخ','سدرظ','درظ','سددظ']
def main():
    version=subprocess.check_output(['hb-shape','--version'],text=True).splitlines()[0]
    assert version=='hb-shape (HarfBuzz) 14.4.0'
    path=FIXTURE/'ArabicContexts.ttf';path.write_bytes(make())
    cases=[]
    for text in TEXTS:
        glyphs=json.loads(subprocess.check_output(['hb-shape',str(path),text,'--no-glyph-names','--output-format=json','--direction=rtl','--script=arab','--language=und']))
        cases.append({'text':text,'direction':'rtl','supported':True,'glyphs':glyphs})
    (FIXTURE/'arabic-contexts-harfbuzz-14.4.0.json').write_text(json.dumps({'engine':version,'fontSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'cases':cases},ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
