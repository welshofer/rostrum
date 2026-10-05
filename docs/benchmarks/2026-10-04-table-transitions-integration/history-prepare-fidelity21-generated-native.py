from pathlib import Path
import hashlib,json,zipfile,shutil,datetime
from lxml import etree as E
from pptx import Presentation
root=Path('/tmp/lectern-fidelity21-generated-native')
worker=Path('/tmp/lectern-transitions21-worker/native-candidates')
fixtures=Path('/Users/welshofer/.codex/worktrees/rostrum-tables/rostrum/Tests/RostrumTests/Fixtures/NativeTableTransitions')
expected={'alternative-false':'5c5d1898ff750097b00e79d20fa0ee60500adaedf204d6f2e30a228893d64d20','alternative-true':'33554e0538f198d8be0600eb9088f16c1486874f610345a204aa9a89635f7cd1'}
ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main'}
def sha(b):return hashlib.sha256(b).hexdigest()
def structure(n):return [n.tag,sorted(n.attrib.items()),n.text,n.tail,[structure(c) for c in n]]
def tables(z,index):
 r=E.fromstring(z.read(f'ppt/slides/slide{index}.xml'))
 return {g.find('p:nvGraphicFramePr/p:cNvPr',ns).get('name'):structure(g) for g in r.findall('.//p:graphicFrame',ns) if g.find('.//a:tbl',ns) is not None}
def texts(z,index):return E.fromstring(z.read(f'ppt/slides/slide{index}.xml')).xpath('//a:t/text()',namespaces=ns)
original=[]
for kind,name in [('vertical','native-table-transitions21-v1.pptx'),('horizontal','native-table-transitions21-horizontal-v1.pptx')]:
 z=zipfile.ZipFile(fixtures/kind/name)
 for i in [1,2]:original.append((tables(z,i),texts(z,i)))
for option,digest in expected.items():
 source=worker/option/'tableTransitions.pptx'; data=source.read_bytes();assert sha(data)==digest
 target=root/option;target.mkdir(parents=True,exist_ok=True)
 path=target/'tableTransitions.pptx';assert not path.exists();path.write_bytes(data)
 z=zipfile.ZipFile(path);assert z.testzip() is None
 p=Presentation(path);assert len(p.slides)==5
 count=0
 for i,(nodes,words) in enumerate(original,1):
  actual=tables(z,i);assert actual==nodes,(option,i,'table graphic frames differ')
  assert texts(z,i)==words,(option,i,'text differs')
  count+=len(nodes)
 assert count==14
 fonts={n:sha(z.read(n)) for n in z.namelist() if n.startswith('ppt/fonts/') and not n.endswith('/')}
 assert '7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954' in fonts.values(),fonts
 receipt={'createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'option':option,'source':str(source),'sourceSHA256':digest,'captureInput':str(path),'inputSHA256':sha(path.read_bytes()),'slides':5,'completeTableGraphicFramesExact':count,'firstFourPageTextExact':True,'embeddedFonts':fonts,'crc':'pass','externalReopen':'python-pptx','captureStatus':'pending','script':str(Path(__file__)),'scriptSHA256':sha(Path(__file__).read_bytes())}
 (target/'input-pins.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(option,count,digest)
