"""Independent kerning controls; PowerPoint PDF remains the document oracle."""
from pathlib import Path
import json,subprocess,hashlib
root=Path(__file__).resolve().parent
font=root/'fonts/DejaVuSans.ttf'
rows=[]
for enabled in [False,True]:
 command=['hb-shape',str(font),'AVATAR ToTo','--no-glyph-names','--output-format=json',f'--features=liga=0,kern={int(enabled)}']
 rows.append(dict(kerning=enabled,command=command,result=json.loads(subprocess.check_output(command,text=True))))
result=dict(version=subprocess.check_output(['hb-shape','--version'],text=True).splitlines()[0],fontSHA256=hashlib.sha256(font.read_bytes()).hexdigest(),text='AVATAR ToTo',controls=rows)
(root/'harfbuzz-controls.json').write_text(json.dumps(result,indent=2)+'\n')
