from pathlib import Path
import zipfile,xml.etree.ElementTree as E,zlib,struct,hashlib,json
s=Path(__file__).resolve().parent;root=s.parent.parent
source=s.parent/'ImageOffice/image-mapping-v2.pptx'
A='http://schemas.openxmlformats.org/drawingml/2006/main';P='http://schemas.openxmlformats.org/presentationml/2006/main';R='http://schemas.openxmlformats.org/officeDocument/2006/relationships';REL='http://schemas.openxmlformats.org/package/2006/relationships';CT='http://schemas.openxmlformats.org/package/2006/content-types'
for n,v in [('a',A),('p',P),('r',R)]:E.register_namespace(n,v)
q=lambda ns,n:'{'+ns+'}'+n
sha=lambda b:hashlib.sha256(b).hexdigest()
def png(rgb):
 def chunk(t,b):return struct.pack('>I',len(b))+t+b+struct.pack('>I',zlib.crc32(t+b)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+bytes(rgb)*2)*2))+chunk(b'IEND',b'')
red=png((255,0,0));blue=png((0,0,255));(s/'theme-red.png').write_bytes(red);(s/'slide-blue.png').write_bytes(blue)
with zipfile.ZipFile(source) as z:original={n:z.read(n) for n in z.namelist()}
# Resolve actual first slide -> layout -> master -> theme rather than assuming IDs.
import posixpath
rels=lambda p:posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def related(parts,p,kind):
 return [posixpath.normpath(posixpath.join(posixpath.dirname(p),e.attrib['Target'])) for e in E.fromstring(parts[rels(p)]) if e.attrib['Type'].endswith('/'+kind)][0]
slide='ppt/slides/slide1.xml';layout=related(original,slide,'slideLayout');master=related(original,layout,'slideMaster');theme=related(original,master,'theme');rid='rIdOwnerProbe'
rows=[]
for mode in ['theme-collision','theme-missing-slide-id','direct-slide-control']:
 parts=dict(original);sx=E.fromstring(parts[slide]);tree=sx.find(q(P,'cSld')).find(q(P,'spTree'))
 for e in list(tree):
  if e.tag not in [q(P,'nvGrpSpPr'),q(P,'grpSpPr')]:tree.remove(e)
 direct=f'<a:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></a:blipFill>' if mode=='direct-slide-control' else ''
 shape=E.fromstring(f'''<p:sp xmlns:p="{P}" xmlns:a="{A}" xmlns:r="{R}"><p:nvSpPr><p:cNvPr id="2" name="owner-probe"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="1828800" cy="1828800"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{direct}<a:ln><a:noFill/></a:ln></p:spPr><p:style><a:lnRef idx="0"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style></p:sp>''');tree.append(shape);sx.set('showMasterSp','0');parts[slide]=E.tostring(sx,encoding='utf-8',xml_declaration=True)
 tx=E.fromstring(parts[theme]);lst=tx.find('.//'+q(A,'fillStyleLst'));lst.remove(lst[0]);lst.insert(0,E.fromstring(f'<a:blipFill xmlns:a="{A}" xmlns:r="{R}"><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></a:blipFill>'));parts[theme]=E.tostring(tx,encoding='utf-8',xml_declaration=True)
 for owner,color in [(theme,'red'),(slide,'blue')]:
  rp=rels(owner);rx=E.fromstring(parts[rp]) if rp in parts else E.Element(q(REL,'Relationships'))
  if owner==theme or mode!='theme-missing-slide-id':E.SubElement(rx,q(REL,'Relationship'),Id=rid,Type=R+'/image',Target='../media/probe-'+color+'.png')
  E.register_namespace('',REL);parts[rp]=E.tostring(rx,encoding='utf-8',xml_declaration=True)
 parts['ppt/media/probe-red.png']=red;parts['ppt/media/probe-blue.png']=blue
 cx=E.fromstring(parts['[Content_Types].xml'])
 if not any(e.get('Extension')=='png' for e in cx):E.SubElement(cx,q(CT,'Default'),Extension='png',ContentType='image/png')
 E.register_namespace('',CT);parts['[Content_Types].xml']=E.tostring(cx,encoding='utf-8',xml_declaration=True)
 # Keep source package members; make presentation single-slide for this bounded probe.
 px=E.fromstring(parts['ppt/presentation.xml']);ids=px.find(q(P,'sldIdLst'))
 for e in list(ids)[1:]:ids.remove(e)
 parts['ppt/presentation.xml']=E.tostring(px,encoding='utf-8',xml_declaration=True)
 target=s/(mode+'.pptx')
 with zipfile.ZipFile(target,'w') as z:
  for n,b in sorted(parts.items()):z.writestr(zipfile.ZipInfo(n,(2026,10,4,0,0,0)),b,compress_type=zipfile.ZIP_DEFLATED)
 rows.append(dict(mode=mode,path=str(target),sha256=sha(target.read_bytes()),expectedPNG_SHA256=sha(blue if mode=='direct-slide-control' else red)))
(s/'inputs.json').write_text(json.dumps(dict(template=str(source),templateSHA256=sha(source.read_bytes()),slide=slide,layout=layout,master=master,theme=theme,relationshipId=rid,themePNG_SHA256=sha(red),slidePNG_SHA256=sha(blue),inputs=rows),indent=2)+'\n')
