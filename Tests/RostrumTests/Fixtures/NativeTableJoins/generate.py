"""Independent absent-versus-applied table-style native discriminators."""
from pathlib import Path
from io import BytesIO
import hashlib,json,struct,zipfile
from lxml import etree
from pptx import Presentation
from pptx.util import Pt
from pptx.dml.color import RGBColor
from fontTools.ttLib import TTFont
OUT=Path(__file__).resolve().parent
ROOT=next(p for p in OUT.parents if (p/'Package.swift').exists())
FONT=ROOT/'Tests/RostrumTests/Fixtures/NativeListMarkers/fonts/DejaVuSans.ttf'
A='http://schemas.openxmlformats.org/drawingml/2006/main';P='http://schemas.openxmlformats.org/presentationml/2006/main';R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
MEDIUM='{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}';GRID='{5940675A-B579-460E-94D1-54222C63F5DA}';NONE='{2D5ABB26-0587-4C30-8999-92F81FD0307C}';CUSTOM='{51477201-257E-4E39-9283-B9AAD00E8017}'
def element(name,**attrs):return etree.Element('{'+A+'}'+name,**{k:str(v) for k,v in attrs.items()})
def solid(color):
 n=element('solidFill');n.append(element('srgbClr',val=color));return n
def line(name,color,width):
 n=element(name,w=round(width*12700),cap='flat',cmpd='sng',algn='ctr');n.append(solid(color));return n
def custom(name='tblStyle'):
 n=element(name,styleId=CUSTOM,styleName='Owned purple cyan control');whole=element('wholeTbl');style=element('tcStyle');borders=element('tcBdr')
 for edge in ['left','right','top','bottom','insideH','insideV']:
  wrapper=element(edge);wrapper.append(line('ln','00AACC',2));borders.append(wrapper)
 style.append(borders);fill=element('fill');fill.append(solid('CC44AA'));style.append(fill);whole.append(style);n.append(whole);return n
fontdata=FONT.read_bytes();font=TTFont(FONT)
fontheader=bytearray(82);struct.pack_into('<IIII',fontheader,0,0,len(fontdata),0x00020001,0);fontheader[26]=1
struct.pack_into('<IHH',fontheader,28,font['OS/2'].usWeightClass,font['OS/2'].fsType,0x504c)
names=bytearray()
for value in ['DejaVu Sans','Book',font['name'].getDebugName(5),'DejaVu Sans']:
 b=value.encode('utf-16le');names+=struct.pack('<H',len(b))+b+b'\0\0'
eot=fontheader+names+b'\0\0'+fontdata;struct.pack_into('<I',eot,0,len(eot))
def xml(n):return etree.tostring(n,xml_declaration=True,encoding='UTF-8',standalone=True)

def make_properties(size=14.5):
 rp=element('rPr',sz=round(size*100),kern=0,b=0,i=0,lang='en-US');rp.append(solid('000000'));rp.append(element('latin',typeface='DejaVu Sans'));return rp
specs=[
 dict(id='unequal-four-edges',rows=1,cols=1,edges=[[[1,2,3,4]]]),
 dict(id='missing-top-edge',rows=1,cols=1,edges=[[[1,3,None,2]]]),
 dict(id='mixed-shared-grid',rows=2,cols=2,edges=[[[1,2,1,3],[2,1,2,1]],[[1,3,3,2],[3,2,1,1]]]),
 dict(id='conflicting-shared-grid',rows=2,cols=2,edges=[[[1,2,1,3],[4,1,2,1]],[[1,3,5,2],[5,2,4,1]]]),
]
deck=Presentation();deck.slide_width=Pt(720);deck.slide_height=Pt(720);slide=deck.slides.add_slide(deck.slide_layouts[6]);slide.background.fill.solid();slide.background.fill.fore_color.rgb=RGBColor.from_string('DDEECC')
for i,case in enumerate(specs):
 x=30+350*(i%2);y=70+280*(i//2);w=111.01;h=160
 label=slide.shapes.add_textbox(Pt(x),Pt(y-28),Pt(310),Pt(20));label.text=case['id'];label.text_frame.paragraphs[0].runs[0].font.size=Pt(12);label.text_frame.paragraphs[0].runs[0].font.name='DejaVu Sans'
 shape=slide.shapes.add_table(case['rows'],case['cols'],Pt(x),Pt(y),Pt(w),Pt(h));shape.name=case['id'];table=shape.table
 pr=table._tbl.tblPr;pr.set('firstRow','0');pr.set('bandRow','0');pr.find('{'+A+'}tableStyleId').text=GRID
 cells=[]
 for row in range(case['rows']):
  for col in range(case['cols']):
   cell=table.cell(row,col);cell.margin_left=cell.margin_right=cell.margin_top=cell.margin_bottom=0
   cp=cell._tc.get_or_add_tcPr()
   for edge,width in zip(['lnL','lnR','lnT','lnB'],case['edges'][row][col]):
    if width is None:
     node=element(edge);node.append(element('noFill'))
    else:node=line(edge,'000000',width)
    cp.append(node)
   cp.append(element('noFill'))
   body=cell.text_frame._txBody
   for child in list(body):body.remove(child)
   bp=element('bodyPr',anchor='t',lIns=0,rIns=0,tIns=0,bIns=0,wrap='none');bp.append(element('normAutofit',fontScale=100000,lnSpcReduction=0));body.append(bp);body.append(element('lstStyle'))
   paragraph=element('p');paragraph.append(element('pPr',algn='ctr'));run=element('r');run.append(make_properties());t=element('t');t.text='Agjp';run.append(t);paragraph.append(run);body.append(paragraph)
   cells.append(dict(row=row,column=col,properties=etree.tostring(cp).decode(),text='Agjp'))
 case.update(page=0,x=x,y=y,width=w,height=h,cells=cells)
buf=BytesIO();deck.save(buf)
with zipfile.ZipFile(buf) as z:parts={n:z.read(n) for n in z.namelist()}
pres=etree.fromstring(parts['ppt/presentation.xml']);pres.set('embedTrueTypeFonts','1');pres.set('saveSubsetFonts','0');fonts=etree.Element('{'+P+'}embeddedFontLst');entry=etree.SubElement(fonts,'{'+P+'}embeddedFont');etree.SubElement(entry,'{'+P+'}font',typeface='DejaVu Sans');etree.SubElement(entry,'{'+P+'}regular').set('{'+R+'}id','rIdMarkerFont');pres.insert(list(pres).index(pres.find('{'+P+'}defaultTextStyle')),fonts);parts['ppt/presentation.xml']=xml(pres)
rel=etree.fromstring(parts['ppt/_rels/presentation.xml.rels']);etree.SubElement(rel,'{http://schemas.openxmlformats.org/package/2006/relationships}Relationship',Id='rIdMarkerFont',Type=R+'/font',Target='fonts/regular.fntdata');parts['ppt/_rels/presentation.xml.rels']=xml(rel);parts['ppt/fonts/regular.fntdata']=eot
ct=etree.fromstring(parts['[Content_Types].xml']);etree.SubElement(ct,'{http://schemas.openxmlformats.org/package/2006/content-types}Default',Extension='fntdata',ContentType='application/x-fontdata');parts['[Content_Types].xml']=xml(ct)
output=OUT/'native-table-joins-v1.pptx'
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
 for name,data in sorted(parts.items()):z.writestr(zipfile.ZipInfo(name,date_time=(2026,10,4,0,0,0)),data,compress_type=zipfile.ZIP_DEFLATED)
manifest=dict(source=output.name,sourceSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),cases=4,slides=1,fontSHA256=hashlib.sha256(fontdata).hexdigest(),scope='Opaque flat centered solid strokes, mixed widths and missing/shared edges; no native join model assumed.')
manifest['pdfSHA256']='36c33f2e3bf35ac8116bc5e4a47d74357f4774f63bfb7b75a055bb9970e94045'
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(OUT/'cases.json').write_text(json.dumps(specs,indent=2)+'\n')
with zipfile.ZipFile(output) as z:
 assert z.testzip() is None
 for name in z.namelist():
  if name.endswith(('.xml','.rels')):etree.fromstring(z.read(name))
assert len(Presentation(output).slides)==1
print(output);print(manifest['sourceSHA256'])
