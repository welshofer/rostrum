"""Capture native origins and independently transformed vector glyph ink.

PDF font-size metadata is retained, but is not the ink-size oracle. Exact raw
font outlines under independently parsed PDF graphics/text matrices determine
geometric ink. SVG-export paths are retained separately with conversion deltas.
Every visible source scalar must match both the PDF text trace and vector use.
"""
from pathlib import Path
from io import BytesIO
import hashlib, json, math, re
import xml.etree.ElementTree as ET
import fitz
from pypdf import PdfReader
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path

ROOT = Path(__file__).resolve().parent
REPO = Path('/path/to/user/Developer/rostrum')
FONT = REPO / 'Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf'
source = TTFont(FONT)
source_glyphs = source.getGlyphSet()
cmap = source.getBestCmap()
units = source['head'].unitsPerEm

def digest(data):
    return hashlib.sha256(data).hexdigest()

def signature(glyphs, name):
    pen = RecordingPen()
    glyphs[name].draw(pen)
    return digest(repr(pen.value).encode())

def bounds(glyphs, name):
    pen = BoundsPen(glyphs)
    glyphs[name].draw(pen)
    return pen.bounds

IDENTITY = (1, 0, 0, 1, 0, 0)

def multiply(left, right):
    a, b, c, d, e, f = left
    g, h, i, j, k, l = right
    return (a*g+c*h, b*g+d*h, a*i+c*j, b*i+d*j, a*k+c*l+e, b*k+d*l+f)

def transform(value):
    result = IDENTITY
    for name, values in re.findall(r'([A-Za-z]+)\(([^)]*)\)', value or ''):
        numbers = [float(v) for v in re.findall(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[Ee][-+]?\d+)?', values)]
        if name == 'matrix':
            assert len(numbers) == 6
            current = tuple(numbers)
        elif name == 'translate':
            assert 1 <= len(numbers) <= 2
            current = (1, 0, 0, 1, numbers[0], numbers[1] if len(numbers) == 2 else 0)
        elif name == 'scale':
            assert 1 <= len(numbers) <= 2
            current = (numbers[0], 0, 0, numbers[-1], 0, 0)
        else:
            raise AssertionError(f'Unverified vector transform: {name}')
        result = multiply(result, current)
    return result

def vector_glyphs(page):
    xml = page.get_svg_image(text_as_path=True)
    tree = ET.fromstring(xml)
    paths = {node.attrib['id']: node.attrib['d'] for node in tree.iter()
             if node.tag.endswith('}path') and 'id' in node.attrib}
    result = []
    def visit(node, inherited):
        matrix = multiply(inherited, transform(node.get('transform')))
        if node.tag.endswith('}use') and 'data-text' in node.attrib:
            char = node.attrib['data-text']
            href = node.attrib['{http://www.w3.org/1999/xlink}href'][1:]
            pen = BoundsPen(None)
            parse_path(paths[href], TransformPen(pen, matrix))
            result.append(dict(text=char, origin=[matrix[4], matrix[5]], matrix=list(matrix),
                               inkBounds=list(pen.bounds) if pen.bounds is not None else None,
                               pathSHA256=digest(paths[href].encode()), pathID=href))
        for child in node:
            visit(child, matrix)
    visit(tree, IDENTITY)
    return result, digest(xml.encode())

def raw_text_matrices(page):
    # Read PDF operators directly. Font-size metadata from texttrace and the
    # vector exporter are not used to derive these linear transforms.
    ctm = IDENTITY
    text_matrix = IDENTITY
    font_size = 1.0
    font_key = None
    horizontal_scale = 1.0
    rise = 0.0
    stack = []
    output = []
    page_height = float(page.mediabox.height)
    assert page.rotation == 0 and float(page.get('/UserUnit', 1)) == 1
    for operands, operator in page.get_contents().operations:
        values = lambda: tuple(float(value) for value in operands)
        if operator == b'q':
            stack.append((ctm, font_size, font_key, horizontal_scale, rise))
        elif operator == b'Q':
            ctm, font_size, font_key, horizontal_scale, rise = stack.pop()
        elif operator == b'cm':
            ctm = multiply(ctm, values())
        elif operator == b'BT':
            text_matrix = IDENTITY
        elif operator == b'Tm':
            text_matrix = values()
        elif operator == b'Tf':
            font_key, font_size = str(operands[0]), float(operands[1])
        elif operator == b'Tz':
            horizontal_scale = float(operands[0]) / 100
        elif operator == b'Ts':
            rise = float(operands[0])
        elif operator in [b'Td', b'TD', b'T*', b"'", b'"']:
            raise AssertionError(f'Unexpected text-position operator: {operator}')
        elif operator in [b'Tj', b'TJ']:
            assert font_key is not None
            font = page['/Resources']['/Font'][font_key].get_object()
            name = str(font['/BaseFont']).split('+')[-1].lstrip('/')
            matrix = multiply(multiply(ctm, text_matrix),
                              (font_size * horizontal_scale, 0, 0, font_size, 0, rise))
            top_down = [matrix[0], -matrix[1], matrix[2], -matrix[3], matrix[4], page_height-matrix[5]]
            output.append(dict(font=name, resource=font_key, operator=operator.decode(),
                               graphicsMatrix=list(ctm), textMatrix=list(text_matrix),
                               fontSizeOperator=font_size, horizontalScale=horizontal_scale,
                               textRise=rise, pageGlyphMatrix=top_down))
    assert not stack
    return output

manifest = json.loads((ROOT / 'manifest.json').read_text())
assert digest((ROOT / manifest['source']).read_bytes()) == manifest['sourceSHA256']
cases = json.loads((ROOT / 'cases.json').read_text())
assert len(cases) == manifest['caseCount'] == 24
assert len({case['name'] for case in cases}) == len(cases)
pdf = Path('/tmp/lectern-fidelity15-alignment-native/alternative-true/powerpoint.pdf')
assert digest(pdf.read_bytes()) == manifest['pdfSHA256']
doc = fitz.open(pdf)
assert len(doc) == manifest['slideCount'] == 5
fonts = {}
for page_index,page in enumerate(doc):
    for item in page.get_fonts():
        _, extension, _, data = doc.extract_font(item[0])
        if extension not in ['ttf', 'otf']:
            continue
        font = TTFont(BytesIO(data))
        fonts[(page_index,item[3].split('+')[-1])] = (font, digest(data))
page_vectors = [vector_glyphs(page) for page in doc]
reader = PdfReader(str(pdf))
raw_matrices = [raw_text_matrices(page) for page in reader.pages]
for index, page in enumerate(doc):
    (ROOT/f'page-{index+1}-content.txt').write_bytes(page.read_contents())
results = []
for case in cases:
    selected=manifest['faces'][case.get('face','regular')]
    selected_path=ROOT/selected['file']
    assert digest(selected_path.read_bytes())==selected['sha256']
    source=TTFont(selected_path);source_glyphs=source.getGlyphSet();cmap=source.getBestCmap();units=source['head'].unitsPerEm
    x, y, width, height = [case[k] for k in ['x', 'y', 'width', 'height']]
    authored = []
    for para in case['paragraphs']:
        for run in para['nodes']:
            if run['kind']=='break':continue
            assert run['kind'] == 'run'
            for char in run['text']:
                if char not in [' ', '\t']:
                    authored.append(dict(text=char, size=run['size'],
                                         effectiveSize=run['size'] * case.get('fontScale', 100) / 100,
                                         tracking=run.get('tracking', 0), color=run.get('color', '000000')))
    def within(origin):
        return x - .001 <= origin[0] <= x + width + .001 and y - .001 <= origin[1] <= y + height + .001
    chars = []
    space_traces = []
    for trace in doc[case['page']].get_texttrace():
        for scalar, glyph, origin, trace_bbox in trace['chars']:
            char = chr(scalar)
            if not within(origin):
                continue
            if char == ' ':
                space_traces.append(dict(origin=list(origin),pdfFont=trace['font'],pdfSize=trace['size']))
                continue
            chars.append(dict(text=char, glyphID=glyph, origin=list(origin),
                              pdfFont=trace['font'], pdfSize=trace['size'],
                              pdfColor=list(trace['color']), pdfCellBounds=list(trace_bbox)))
    vectors = [v for v in page_vectors[case['page']][0] if v['text'] != ' ' and within(v['origin'])]
    key = lambda record: (round(record['origin'][1], 3), record['origin'][0])
    chars.sort(key=key)
    vectors.sort(key=key)
    if case.get('tinyOmissionAudit') and (len(chars)!=len(authored) or len(vectors)!=len(authored)):
        observed=''.join(c['text'] for c in chars);expected=''.join(c['text'] for c in authored)
        assert len(chars)==len(vectors) and observed==''.join(v['text'] for v in vectors)
        cursor=0;omitted=[]
        for index,item in enumerate(authored):
            if cursor<len(observed) and item['text']==observed[cursor]:cursor+=1
            else:omitted.append(dict(scalarOffset=index,text=item['text']))
        assert cursor==len(observed),(case['name'],observed,expected)
        results.append(dict(name=case['name'],selectedFace=case.get('face','regular'),selectedFaceSHA256=selected['sha256'],expectedVisibleScalars=len(authored),consumedVisibleScalars=len(chars),omittedScalars=omitted,geometrySupport='unsupported: native tiny-size glyph omission',lines=[],rawTrace=chars,rawVectorUses=vectors))
        print(case['name'],'EXPLICIT UNSUPPORTED TINY OMISSION',omitted)
        continue
    assert len(chars) == len(vectors) == len(authored), (case['name'], len(chars), len(vectors), len(authored))
    output = []
    for actual, vector, expected in zip(chars, vectors, authored):
        char = expected['text']
        assert actual['text'] == vector['text'] == char, (case['name'], actual, vector, expected)
        assert all(abs(a-b) < .002 for a, b in zip(actual['origin'], vector['origin']))
        subset, _ = fonts[(case['page'],actual['pdfFont'])]
        subset_glyphs = subset.getGlyphSet()
        subset_name = subset.getGlyphOrder()[actual['glyphID']]
        assert subset['head'].unitsPerEm == units
        outline_match = signature(subset_glyphs, subset_name) == signature(source_glyphs, cmap[ord(char)])
        assert outline_match, (case['name'], char, actual['pdfFont'])
        source_bounds = bounds(source_glyphs, cmap[ord(char)])
        matrix = vector['matrix']
        # This bounded fixture is horizontal and unrotated. Fail rather than
        # reinterpret an unexpected affine glyph transform as a font-size rule.
        assert abs(matrix[1]) < 1e-8 and abs(matrix[2]) < 1e-8 and matrix[0] > 0 and matrix[3] < 0
        matches = [entry for entry in raw_matrices[case['page']]
                   if entry['font'] == actual['pdfFont']
                   and abs(entry['pageGlyphMatrix'][5] - actual['origin'][1]) < .002
                   and all(abs(a-b) < .00002 for a,b in zip(entry['pageGlyphMatrix'][:4],matrix[:4]))]
        assert matches, (case['name'], char, matrix, actual['pdfFont'])
        preceding=[entry for entry in matches if entry['pageGlyphMatrix'][4]<=actual['origin'][0]+.002]
        chosen=min(preceding or matches,key=lambda entry:abs(entry['pageGlyphMatrix'][4]-actual['origin'][0]))
        raw_matrix = chosen['pageGlyphMatrix']
        paint_x, paint_y = raw_matrix[0], -raw_matrix[3]
        expected_ink = [actual['origin'][0] + source_bounds[0] * paint_x / units,
                        actual['origin'][1] - source_bounds[3] * paint_y / units,
                        actual['origin'][0] + source_bounds[2] * paint_x / units,
                        actual['origin'][1] - source_bounds[1] * paint_y / units]
        # MuPDF's SVG path conversion can quantize an outline by a font
        # unit. Preserve that discrepancy; do not call it exact native ink.
        exported_ink_delta = [a-b for a,b in zip(vector['inkBounds'], expected_ink)]
        output.append(dict(text=char, x=actual['origin'][0]-x, baseline=actual['origin'][1]-y,
                           pdfFont=actual['pdfFont'], pdfSize=actual['pdfSize'], pdfColor=actual['pdfColor'],
                           rawPDFPaintScale=[paint_x,paint_y], vectorPaintScale=[matrix[0],-matrix[3]], vectorMatrix=matrix,
                           rawPDFTextMatrixRecord=chosen,
                           geometricInkBounds=[expected_ink[0]-x,expected_ink[1]-y,expected_ink[2]-x,expected_ink[3]-y],
                           vectorExporterInkDelta=exported_ink_delta,
                           vectorInkBounds=[vector['inkBounds'][0]-x, vector['inkBounds'][1]-y,
                                            vector['inkBounds'][2]-x, vector['inkBounds'][3]-y],
                           sourceGlyphMatches=outline_match, sourceGlyphBounds=list(source_bounds),
                           sourceAdvance=source['hmtx'][cmap[ord(char)]][0],
                           pathSHA256=vector['pathSHA256'], authored=expected))
    lines = []
    for item in output:
        if not lines or abs(lines[-1]['baseline']-item['baseline']) > .002:
            lines.append(dict(baseline=item['baseline'], visibleText='', characters=[]))
        lines[-1]['visibleText'] += item['text']
        lines[-1]['characters'].append(item)
    results.append(dict(name=case['name'], selectedFace=case.get('face','regular'), selectedFaceSHA256=selected['sha256'], expectedVisibleScalars=len(authored), consumedVisibleScalars=len(output), authoredSpaceCount=sum(n.get('text','').count(' ') for p in case['paragraphs'] for n in p['nodes']), observedSpaceTraces=space_traces, lines=lines))
    print(case['name'], [(line['visibleText'], round(line['baseline'],4)) for line in lines],
          'paint', sorted(set(tuple(c['vectorPaintScale']) for c in output)))
record = dict(source=manifest['source'], sourceSHA256=manifest['sourceSHA256'], pdf=pdf.name,
              pdfSHA256=digest(pdf.read_bytes()), sourceFaces=manifest['faces'],
              extraction='Exact source/subset outlines transformed using raw PDF graphics/text matrices, located at PDF texttrace origins. MuPDF SVG-export paths retained separately with their outline-quantization deltas. Ordinary spaces excluded from visible-scalar counts.',
              pageStreamSHA256=[digest(page.read_contents()) for page in doc], rawTextMatrices=raw_matrices,
              vectorExportSHA256=[entry[1] for entry in page_vectors],
              subsetSHA256={str(page)+':'+name: entry[1] for (page,name),entry in fonts.items()}, cases=results)
(ROOT/'native-alignment-metrics.json').write_text(json.dumps(record,separators=(',',':'))+'\n')
