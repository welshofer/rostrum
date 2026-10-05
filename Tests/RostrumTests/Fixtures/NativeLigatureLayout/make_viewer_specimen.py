"""Wrap actual emitted SVG with native-browser liga controls (not a PPT oracle)."""
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('svg', type=Path)
parser.add_argument('html', type=Path)
args = parser.parse_args()
svg = args.svg.read_text()
assert "font-feature-settings: 'liga' 0" in svg
html = '''<!doctype html><meta charset="utf-8"><title>Native Latin SVG policy</title>
<style>body{font:16px system-ui;margin:24px}section{max-width:900px}svg{width:100%;height:auto;border:1px solid #aaa}</style>
<h1>Actual renderer and viewer controls</h1>
<p>The first SVG is emitted by Rostrum. The other two retain identical geometry and embedded font,
changing only optional liga. TextLength constrains overall width; compare character extents/origins
and glyph outlines, not the total width alone. PowerPoint geometry is a separate oracle.</p>
'''
for identifier, title, value in [('actual', 'Actual renderer', svg),
                                  ('enabled', 'Same SVG with liga enabled', svg.replace("'liga' 0", "'liga' 1")),
                                  ('disabled', 'Same SVG with liga disabled', svg)]:
    html += f'<section id="{identifier}"><h2>{title}</h2>{value}</section>'
html += '''<pre id="results">Waiting for embedded font…</pre><script>
window.ligatureEvidence = () => Object.fromEntries(['actual','enabled','disabled'].map(id => {
 const node = document.querySelector('#'+id+' tspan');
 const box = r => ({x:r.x,y:r.y,width:r.width,height:r.height});
 return [id,{text:node.textContent,feature:getComputedStyle(node).fontFeatureSettings,
 font:getComputedStyle(node).fontFamily,length:node.getComputedTextLength(),
 characters:Array.from(node.textContent).map((text,i)=>({text,
 start:box(node.getExtentOfChar(i)),originX:node.getStartPositionOfChar(i).x,
 endX:node.getEndPositionOfChar(i).x}))}];
}));
document.fonts.ready.then(()=>document.getElementById('results').textContent=JSON.stringify(window.ligatureEvidence(),null,2));
</script>'''
args.html.write_text(html)
