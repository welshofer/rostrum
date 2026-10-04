"""Independent DrawingML hard-break vertical-metric probes; no Rostrum geometry."""
from pathlib import Path
from io import BytesIO
import hashlib, json, struct, zipfile
from lxml import etree
from fontTools.ttLib import TTFont
from pptx import Presentation
from pptx.util import Pt
from pptx.enum.text import MSO_AUTO_SIZE

OUT=Path(__file__).resolve().parent
ROOT=next(p for p in OUT.parents if (p/'Package.swift').exists())
FONT=ROOT/'Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf'
A='http://schemas.openxmlformats.org/drawingml/2006/main'
P='http://schemas.openxmlformats.org/presentationml/2006/main'
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
def elem(name,**attrs):return etree.Element('{'+A+'}'+name,**{k:str(v) for k,v in attrs.items()})
def run(text,size=12):return dict(kind='run',text=text,size=size)
def br(size=None):return dict(kind='break',size=size)
def paragraph(nodes,default=None,end=None,spacing=None):return dict(nodes=nodes,default=default,end=end,spacing=spacing)
def pair(size):return [paragraph([run('A'),br(size),run('B')])]
def consecutive(first,second,default=None):return [paragraph([run('A'),br(first),br(second),run('B')],default=default)]
def trailing(end):return [paragraph([run('A'),br(36)],end=end),paragraph([run('Z')])]
def empty(end):return [paragraph([run('A')]),paragraph([],end=end),paragraph([run('Z')])]
cases=[]
def add(name,paragraphs,**kwargs):cases.append(dict(name=name,paragraphs=paragraphs,**kwargs))
for percent in [150,125]:
    for compat in [None,'0','1']:
        options={} if compat is None else dict(compatLnSpc=compat)
        nodes=[run('A',18),br(18),run('B',18),br(18),run('Z',18),br(18),run('A',18)]
        add(f'pct{percent}-18-four-compat'+('omitted' if compat is None else compat),[paragraph(nodes,spacing=dict(percent=percent))],**options)
assert len(cases)==6

def properties(name,size):
    node=elem(name,sz=round(size*100),b='0',i='0',lang='en-US')
    fill=elem('solidFill');fill.append(elem('srgbClr',val='000000'));node.append(fill)
    node.append(elem('latin',typeface=font_family))
    return node

deck=Presentation();deck.slide_width=Pt(720);deck.slide_height=Pt(720)
for index,case in enumerate(cases):
    font_family=case.get("font","DejaVu Sans")
    if index%6==0:slide=deck.slides.add_slide(deck.slide_layouts[6])
    x=30+350*(index%2);y=50+220*((index%6)//2);w=290;h=160
    label=slide.shapes.add_textbox(Pt(x),Pt(y-23),Pt(310),Pt(18));label.text=case['name']
    label.text_frame.paragraphs[0].runs[0].font.size=Pt(10)
    if case.get('table'):
        shape=slide.shapes.add_table(1,1,Pt(x),Pt(y),Pt(w),Pt(h))
        cell=shape.table.cell(0,0);cell.margin_left=cell.margin_right=cell.margin_top=cell.margin_bottom=0
        tf=cell.text_frame;pr=shape.table._tbl.tblPr
        for child in list(pr):
            if child.tag=='{'+A+'}tableStyleId':pr.remove(child)
        pr.set('firstRow','0');pr.set('bandRow','0')
    else:
        shape=slide.shapes.add_textbox(Pt(x),Pt(y),Pt(w),Pt(h));tf=shape.text_frame
    shape.name=case['name'];tf.margin_left=tf.margin_right=tf.margin_top=tf.margin_bottom=0
    tf.word_wrap=True;tf.auto_size=MSO_AUTO_SIZE.NONE
    body=tf._txBody;bodyPr=body.find('{'+A+'}bodyPr');bodyPr.set('anchor',case.get('anchor','t'))
    if 'compatLnSpc' in case:bodyPr.set('compatLnSpc',case['compatLnSpc'])
    for child in list(body):
        if child.tag in ['{'+A+'}p','{'+A+'}lstStyle']:body.remove(child)
    lst=elem('lstStyle');level=elem('lvl1pPr');level.append(properties('defRPr',case.get('listSize',18)));lst.append(level);body.append(lst)
    for specification in case['paragraphs']:
        p=elem('p');pr=elem('pPr',algn='l',lvl=0)
        spacing=specification.get('spacing')
        if spacing:
            line=elem('lnSpc')
            line.append(elem('spcPts',val=round(spacing['points']*100)) if 'points' in spacing else elem('spcPct',val=round(spacing['percent']*1000)))
            pr.append(line)
        if specification['default'] is not None:pr.append(properties('defRPr',specification['default']))
        p.append(pr)
        for token in specification['nodes']:
            if token['kind']=='break':
                node=elem('br')
                if token['size'] is not None:node.append(properties('rPr',token['size']))
            else:
                node=elem('r');node.append(properties('rPr',token['size']));text=elem('t');text.text=token['text'];node.append(text)
            p.append(node)
        if specification['end'] is not None:p.append(properties('endParaRPr',specification['end']))
        body.append(p)
    case.update(page=index//6,x=x,y=y,width=w,height=h)

# EOT v2.1, independently constructed from the licensed unmodified font.
font_bytes=FONT.read_bytes();font=TTFont(FONT);header=bytearray(82)
struct.pack_into('<IIII',header,0,0,len(font_bytes),0x00020001,0);header[26]=1
struct.pack_into('<IHH',header,28,400,font['OS/2'].fsType,0x504c)
names=bytearray()
for value in ['DejaVu Sans','Book','Version 2.37','DejaVu Sans']:
    encoded=value.encode('utf-16le');names+=struct.pack('<H',len(encoded))+encoded+b'\0\0'
eot=header+names+b'\0\0'+font_bytes;struct.pack_into('<I',eot,0,len(eot))
buffer=BytesIO();deck.save(buffer)
with zipfile.ZipFile(buffer) as source:parts={n:source.read(n) for n in source.namelist()}
pres=etree.fromstring(parts['ppt/presentation.xml']);pres.set('embedTrueTypeFonts','1');pres.set('saveSubsetFonts','0')
fonts=etree.Element('{'+P+'}embeddedFontLst');entry=etree.SubElement(fonts,'{'+P+'}embeddedFont')
etree.SubElement(entry,'{'+P+'}font').set('typeface','DejaVu Sans')
etree.SubElement(entry,'{'+P+'}regular').set('{'+R+'}id','rIdBreakProbeFont')
pres.insert(list(pres).index(pres.find('{'+P+'}defaultTextStyle')),fonts)
def xml(node):return etree.tostring(node,xml_declaration=True,encoding='UTF-8',standalone=True)
parts['ppt/presentation.xml']=xml(pres)
rels=etree.fromstring(parts['ppt/_rels/presentation.xml.rels'])
etree.SubElement(rels,'{http://schemas.openxmlformats.org/package/2006/relationships}Relationship',Id='rIdBreakProbeFont',Type=R+'/font',Target='fonts/break-probe.fntdata')
parts['ppt/_rels/presentation.xml.rels']=xml(rels)
ct=etree.fromstring(parts['[Content_Types].xml'])
etree.SubElement(ct,'{http://schemas.openxmlformats.org/package/2006/content-types}Default',Extension='fntdata',ContentType='application/x-fontdata')
parts['[Content_Types].xml']=xml(ct);parts['ppt/fonts/break-probe.fntdata']=eot
output=OUT/'native-spacing-final-v1.pptx'
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as target:
    for name,data in sorted(parts.items()):target.writestr(name,data)
(OUT/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
manifest=dict(source=output.name,sourceSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),slideCount=1,caseCount=len(cases),fontSHA256=hashlib.sha256(font_bytes).hexdigest(),font='DejaVu Sans 2.37 regular',primarySemantics='https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.break?view=openxml-3.0.1',scope='Independent exact/percentage line-spacing baseline matrix; generic30pt/exact48.75 controls are not the private imported specimen.')
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(output);print(manifest['sourceSHA256']);print('1 slide,6 cases')
