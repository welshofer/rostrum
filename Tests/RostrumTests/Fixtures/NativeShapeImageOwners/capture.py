"""Finite owner/rectangle oracle. No raster or font approximation model."""
from pathlib import Path
import fitz,json,hashlib,sys
pdf=Path(sys.argv[1]); target=Path(sys.argv[2]); target.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
doc=fitz.open(pdf);assert len(doc)==1
page=doc[0];paint=[]
for info in page.get_image_info(xrefs=True):
 xref=info['xref'];assert xref>0,'Inline image needs separate raw payload extraction'
 pix=fitz.Pixmap(doc,xref)
 if pix.colorspace.name!='DeviceRGB':pix=fitz.Pixmap(fitz.csRGB,pix)
 assert not pix.alpha
 pixels=pix.samples;colors=sorted(set(tuple(pixels[i:i+3]) for i in range(0,len(pixels),3)))
 assert len(colors)==1,('Nonuniform native image',xref,colors[:8])
 paint.append(dict(xref=xref,frame=list(info['bbox']),matrix=list(info['transform']),pixels=[pix.width,pix.height],rgb=list(colors[0]),decodedRGB_SHA256=sha(pixels),object=doc.xref_object(xref,compressed=False)))
content=b'\n'.join(doc.xref_stream(x) for x in page.get_contents());(target/'page-content.txt').write_bytes(content)
result=dict(pdf=str(pdf),pdfSHA256=sha(pdf.read_bytes()),pagePoints=[page.rect.width,page.rect.height],imagePaint=paint,rawContentSHA256=sha(content),scope='Decoded native image RGB and PDF image placement matrices. No text, crop, transform or universal raster claim.')
(target/'native-images.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'images':len(paint),'colors':[x['rgb'] for x in paint],'frames':[x['frame'] for x in paint]}))
