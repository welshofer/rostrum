from pathlib import Path
import hashlib,json,struct,zlib,zipfile,xml.etree.ElementTree as E
r=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest()
def png(path):
 b=path.read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n';i=8;payload=b'';dimensions=None
 while i<len(b):
  n=struct.unpack('>I',b[i:i+4])[0];kind=b[i+4:i+8];value=b[i+8:i+8+n];crc=struct.unpack('>I',b[i+8+n:i+12+n])[0]
  assert zlib.crc32(kind+value)&0xffffffff==crc
  if kind==b'IHDR':dimensions=struct.unpack('>IIBBBBB',value);assert dimensions==(2,2,8,2,0,0,0)
  if kind==b'IDAT':payload+=value
  i+=n+12
 raw=zlib.decompress(payload);assert len(raw)==14 and raw[0]==raw[7]==0
 pixels=raw[1:7]+raw[8:14];assert len(set(tuple(pixels[j:j+3]) for j in range(0,12,3)))==1
 return pixels
red=png(r/'theme-red.png');blue=png(r/'slide-blue.png');assert red==bytes([255,0,0])*4 and blue==bytes([0,0,255])*4
names={'theme-collision':'theme-collision','theme-missing-slide-id':'theme-missing-slide-id','direct-slide-control':'direct-slide-control','background-and-inherited':'native-theme-image-owners-v1'}
count=0
for folder,source in names.items():
 d=r/folder;receipt=json.loads((d/'capture-receipt.json').read_text());native=json.loads((d/'native-images.json').read_text())
 assert sha((r/(source+'.pptx')).read_bytes())==receipt['inputSHA256']
 assert sha((d/'powerpoint.pdf').read_bytes())==receipt['pdfSHA256']==native['pdfSHA256']
 assert sha((d/'page-content.txt').read_bytes())==native['rawContentSHA256']
 assert receipt['sourceUnchanged'] and not receipt['sourceSaved'] and not receipt['repairDialogObserved']
 expected=[([72,72,216,216],[0,0,255] if source=='direct-slide-control' else [255,0,0])]
 if folder=='background-and-inherited':expected=[([324,288,540,432],[0,0,255]),([36,288,252,432],[0,0,255]),([36,48,252,192],[255,0,0]),([324,48,540,192],[255,0,0])]
 assert len(native['imagePaint'])==len(expected)
 for paint,(frame,rgb) in zip(native['imagePaint'],expected):
  assert paint['frame']==frame and paint['rgb']==rgb and paint['pixels']==[2,2]
  assert paint['decodedRGB_SHA256']==sha(red if rgb==[255,0,0] else blue)
  assert paint['matrix']==[frame[2]-frame[0],0,0,frame[3]-frame[1],frame[0],frame[1]]
  count+=1
 with zipfile.ZipFile(r/(source+'.pptx')) as z:
  assert z.read('ppt/media/probe-red.png')==(r/'theme-red.png').read_bytes()
  assert z.read('ppt/media/probe-blue.png')==(r/'slide-blue.png').read_bytes()
  for name in z.namelist():
   if name.endswith(('.xml','.rels')):E.fromstring(z.read(name))
print(json.dumps({'sourceDecks':4,'nativeImages':count,'decodedRGBExact':True,'matrixAndFramesExact':True,'sourceAndPDFPins':True,'pngCRCs':True}))
