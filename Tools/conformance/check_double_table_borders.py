#!/usr/bin/env python3
"""Compare table-border SVGs with pinned Office PNG and PDF references.

Requires resvg-py 0.5.0 and Pillow 12.3.0. The unchanged whole-image gate is
0.5 percent differing pixels at channel tolerance16. Failures remain failures.
Run vector verification separately with --pdf using PyMuPDF1.27.2.3.
"""
import argparse, hashlib, io, json, math, sys, zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('svg_directory', type=Path)
parser.add_argument('fixture_directory', type=Path)
parser.add_argument('--styles', action='store_true')
parser.add_argument('--rtl', action='store_true')
parser.add_argument('--pdf', action='store_true')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
style_name = 'style-precedence-rtl' if args.rtl else 'style-precedence'
manifest = json.loads((args.fixture_directory / (style_name + '.json' if args.styles else 'manifest.json')).read_text())
source = args.fixture_directory / (style_name + '.pptx' if args.styles else 'double-borders.pptx')
if hashlib.sha256(source.read_bytes()).hexdigest() != manifest['sha256']: parser.error('source hash mismatch')
rows = []
if args.pdf:
    import fitz
    if fitz.VersionBind != '1.27.2.3': parser.error('requires PyMuPDF1.27.2.3')
    pdf = args.fixture_directory / 'powerpoint-16.113.3.pdf'
    if hashlib.sha256(pdf.read_bytes()).hexdigest() != manifest['pdfSHA256']: parser.error('PDF hash mismatch')
    doc = fitz.open(pdf)
    if len(doc) !=29 or any(tuple(p.rect) != (0,0,864,504) for p in doc): parser.error('unexpected PDF geometry')
    # No joins or coalescing: each page has exactly two blue component quads.
    # Compare their actual Office vector vertices, not raster-fitted positions.
    for n in range(1,25):
        actual = []
        root = ET.parse(args.svg_directory / f'Slide{n}.svg').getroot()
        for line in root.iter():
            if line.tag.split('}')[-1] != 'line' or line.get('stroke') != '#0000FF': continue
            x,y,u,v = [float(line.get(k))/12700 for k in ['x1','y1','x2','y2']]
            half = float(line.get('stroke-width'))/25400
            length = math.hypot(u-x,v-y); dx,dy = -(v-y)/length*half,(u-x)/length*half
            actual.extend([(x+dx,y+dy),(u+dx,v+dy),(u-dx,v-dy),(x-dx,y-dy)])
        expected = set()
        for drawing in doc[n-1].get_drawings():
            if drawing['fill'] != (0,0,1): continue
            for item in drawing['items']:
                if item[0] == 'l': expected.update(tuple(p) for p in item[1:])
                elif item[0] == 're':
                    rect=item[1];expected.update([tuple(rect.tl),tuple(rect.tr),tuple(rect.br),tuple(rect.bl)])
        maximum = max((min(math.dist(p,q) for q in actual) for p in expected), default=math.inf)
        reverse = max((min(math.dist(p,q) for q in expected) for p in actual), default=math.inf)
        rows.append({'slide':n,'maxVertexErrorPt':max(maximum,reverse),'passed':len(expected)==len(actual)==8 and max(maximum,reverse)<0.001})
    for n in range(25,30):
        # Native footer components coalesce across columns in Office. Compare
        # their union bounds and all horizontal band boundaries instead of
        # requiring the renderer to use identical primitive counts.
        expected=[]
        for drawing in doc[n-1].get_drawings():
            if not drawing['fill'] or not (335<drawing['rect'].y0<341) or drawing['rect'].y1>=342: continue
            for item in drawing['items']:
                if item[0]=='re': expected.append(tuple(item[1]))
        actual=[]
        for line in ET.parse(args.svg_directory/f'Slide{n}.svg').getroot().iter():
            if line.tag.split('}')[-1]!='line': continue
            x,y,u,v=[float(line.get(k))/12700 for k in ['x1','y1','x2','y2']]
            if y!=v or not 335<y<341: continue
            half=float(line.get('stroke-width'))/25400
            actual.append((x,y-half,u,y+half))
        def bounds(rectangles):
            return [min(r[0] for r in rectangles),max(r[2] for r in rectangles)] + sorted(set(round(v,3) for r in rectangles for v in [r[1],r[3]]))
        left,right=bounds(expected),bounds(actual)
        error=max(abs(a-b) for a,b in zip(left,right)) if len(left)==len(right) else math.inf
        rows.append({'slide':n,'maxBandBoundaryErrorPt':error,'passed':error<0.001})
else:
    from importlib.metadata import version
    from PIL import Image,ImageChops
    import resvg_py
    if version('resvg-py') != '0.5.0' or version('Pillow') != '12.3.0': parser.error('requires resvg-py0.5.0 and Pillow12.3.0')
    archive = args.fixture_directory / (style_name + '-png.zip' if args.styles else 'powerpoint-16.113.3-png.zip')
    if hashlib.sha256(archive.read_bytes()).hexdigest() != manifest['referenceZipSHA256']: parser.error('reference hash mismatch')
    with zipfile.ZipFile(archive) as z:
        for c in manifest['cases']:
            n=c['slide'];name=f'Slide{n}.png';raw=z.read(name)
            if hashlib.sha256(raw).hexdigest()!=manifest['pngSHA256'][name]:parser.error('PNG hash mismatch')
            svg_bytes=(args.svg_directory/f'Slide{n}.svg').read_bytes()
            root=ET.fromstring(svg_bytes)
            root.set('width','1200');root.set('height','700')
            candidate=Image.open(io.BytesIO(resvg_py.svg_to_bytes(svg_string=ET.tostring(root).decode(),width=1200,height=700))).convert('RGB')
            reference=Image.open(io.BytesIO(raw)).convert('RGB')
            if reference.size!=(1200,700):parser.error('unexpected PNG dimensions')
            channels=ImageChops.difference(candidate,reference).split()
            histogram=ImageChops.lighter(ImageChops.lighter(channels[0],channels[1]),channels[2]).histogram()
            differing=sum(histogram[17:]);fraction=differing/840000
            row={'slide':n,'svgSHA256':hashlib.sha256(svg_bytes).hexdigest(),'differingPixels':differing,'fraction':fraction,'maxChannelDelta':max(i for i,count in enumerate(histogram) if count),'passed':fraction<=0.005}
            if args.styles:
                # Only stable interiors: native double-line component center,
                # solid/direct center, and backgrounds four pixels either side.
                # Full-image failures above remain failures, independently.
                boundary = 4-c['boundary'] if c.get('rtl') else c['boundary']
                x,y=(100+250*boundary,250) if c['vertical'] else (300,150+80*c['boundary'])
                center=1 if c['region']=='lastRow' and c['variant'] in ['style-only','current-solid','current-none'] else 0
                points=[(x+d,y) if c['vertical'] else (x,y+d) for d in [-4,center,4]]
                errors=[max(abs(a-b) for a,b in zip(candidate.getpixel(point),reference.getpixel(point))) for point in points]
                row['boundaryProbes']=[{'point':point,'maxChannelDelta':error} for point,error in zip(points,errors)]
                row['boundaryPassed']=max(errors)<=1
            rows.append(row)
result={'mode':'OfficePDFVectorVertices' if args.pdf else 'OfficePNGWholeImage','channelTolerance':None if args.pdf else 16,'pixelFractionGate':None if args.pdf else 0.005,'passed':all(r['passed'] for r in rows),'cases':rows}
args.output.write_text(json.dumps(result,indent=2)+'\n')
print(f"{sum(r['passed'] for r in rows)}/{len(rows)} passed; {args.output}")
sys.exit(0 if result['passed'] else 1)
