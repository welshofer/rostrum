from pathlib import Path
import zipfile,xml.etree.ElementTree as E,json,hashlib,posixpath
out=Path(__file__).resolve().parent
prior=out
source=prior/'theme-collision.pptx'
A='http://schemas.openxmlformats.org/drawingml/2006/main';P='http://schemas.openxmlformats.org/presentationml/2006/main';R='http://schemas.openxmlformats.org/officeDocument/2006/relationships';REL='http://schemas.openxmlformats.org/package/2006/relationships'
for n,v in [('a',A),('p',P),('r',R)]:E.register_namespace(n,v)
q=lambda ns,n:'{'+ns+'}'+n
sha=lambda b:hashlib.sha256(b).hexdigest()
with zipfile.ZipFile(source) as z: parts={n:z.read(n) for n in z.namelist()}
def relpath(p):return posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def related(p,kind):return next(posixpath.normpath(posixpath.join(posixpath.dirname(p),e.attrib['Target'])) for e in E.fromstring(parts[relpath(p)]) if e.attrib['Type'].endswith('/'+kind))
slide='ppt/slides/slide1.xml';layout=related(slide,'slideLayout');master=related(layout,'slideMaster');theme=related(master,'theme')
def xml(p):return E.fromstring(parts[p])
def save(p,x):parts[p]=E.tostring(x,encoding='utf-8',xml_declaration=True)
def image_rel(owner,rid,color):
 rp=relpath(owner);root=xml(rp) if rp in parts else E.Element(q(REL,'Relationships'))
 for e in list(root):
  if e.get('Id')==rid:root.remove(e)
 E.SubElement(root,q(REL,'Relationship'),Id=rid,Type=R+'/image',Target='../media/probe-'+color+'.png')
 E.register_namespace('',REL);save(rp,root)
def image_fill(rid):return E.fromstring(f'<a:blipFill xmlns:a="{A}" xmlns:r="{R}"><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></a:blipFill>')
roots={p:xml(p) for p in [slide,layout,master]}
for p,root in roots.items():
 tree=root.find(q(P,'cSld')).find(q(P,'spTree'))
 for e in list(tree):
  if e.tag not in [q(P,'nvGrpSpPr'),q(P,'grpSpPr')]:tree.remove(e)
 if p!=master:root.set('showMasterSp','1')
# Explicit local white prevents theme bgFillStyleLst from painting the page.
common=roots[slide].find(q(P,'cSld'))
for e in list(common):
 if e.tag==q(P,'bg'):common.remove(e)
common.insert(0,E.fromstring(f'<p:bg xmlns:p="{P}" xmlns:a="{A}"><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'))
theme_root=xml(theme);matrix=theme_root.find('.//'+q(A,'fmtScheme'))
for listname,rids in [('fillStyleLst',['rIdThemeRed']),('bgFillStyleLst',['rIdBackgroundCollision','rIdBackgroundMissing'])]:
 lst=matrix.find(q(A,listname))
 for i,rid in enumerate(rids):
  lst.remove(lst[i]);lst.insert(i,image_fill(rid));image_rel(theme,rid,'red')
save(theme,theme_root)
image_rel(slide,'rIdBackgroundCollision','blue')
image_rel(layout,'rIdLayoutBlue','blue');image_rel(master,'rIdMasterBlue','blue')
cases=[('bg-matrix-collision',slide,1001,None,[36,48,216,144],'red'),('bg-matrix-missing-slide-id',slide,1002,None,[324,48,216,144],'red'),('layout-direct-over-theme',layout,1,'rIdLayoutBlue',[36,288,216,144],'blue'),('master-direct-over-theme',master,1,'rIdMasterBlue',[324,288,216,144],'blue')]
manifest=[]
for i,(name,owner,idx,direct,frame,color) in enumerate(cases):
 x,y,w,h=[round(v*12700) for v in frame]
 shape=E.fromstring(f'<p:sp xmlns:p="{P}" xmlns:a="{A}" xmlns:r="{R}"><p:nvSpPr><p:cNvPr id="{20+i}" name="{name}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{w}" cy="{h}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:ln><a:noFill/></a:ln></p:spPr><p:style><a:lnRef idx="0"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="{idx}"><a:schemeClr val="accent1"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style></p:sp>')
 if direct:shape.find(q(P,'spPr')).insert(2,image_fill(direct))
 roots[owner].find(q(P,'cSld')).find(q(P,'spTree')).append(shape)
 manifest.append(dict(id=name,sourceOwner='/'+owner,selectedOwner='/'+(owner if direct else theme),fillRefIndex=idx,directRelationship=direct,framePoints=frame,expectedColor=color,expectedPNG_SHA256=sha(parts['ppt/media/probe-'+color+'.png'])))
for p,root in roots.items():save(p,root)
presentation=xml('ppt/presentation.xml');presentation.find(q(P,'sldSz')).set('cx',str(720*12700));presentation.find(q(P,'sldSz')).set('cy',str(540*12700));save('ppt/presentation.xml',presentation)
path=out/'native-theme-image-owners-v1.pptx'
with zipfile.ZipFile(path,'w') as z:
 for name,b in sorted(parts.items()):z.writestr(zipfile.ZipInfo(name,(2026,10,4,0,0,0)),b,compress_type=zipfile.ZIP_DEFLATED)
# Every XML member must remain parseable; all selected image references resolve.
for name,b in parts.items():
 if name.endswith(('.xml','.rels')):E.fromstring(b)
assert all(not any(e.get('Id')=='rIdBackgroundMissing' for e in E.fromstring(parts[relpath(o)])) for o in [slide])
(out/'inputs.json').write_text(json.dumps(dict(source=str(source),sourceSHA256=sha(source.read_bytes()),path=str(path),sha256=sha(path.read_bytes()),slides=1,pagePoints=[720,540],cases=manifest,scope='Resource owner and finite frame placement; no typography, new crop or transform calibration.'),indent=2)+'\n')
print(path);print(sha(path.read_bytes()))
