"""Independent OpenType controls; native PowerPoint remains the document oracle."""
from pathlib import Path
import json,subprocess
root=Path(__file__).parent
font=root.parent/'Typography/DejaVuSans.ttf'
cases=[]
for text in ['fi','fl','ff','ffi','ffl','office','office final waffle','AV office']:
 case={'text':text}
 for enabled in [False,True]:
  command=['hb-shape',str(font),text,'--no-glyph-names','--output-format=json',f'--features=liga={int(enabled)}']
  case['liga'+str(int(enabled))]=json.loads(subprocess.check_output(command,text=True))
 cases.append(case)
equivalence=[]
for text in ['officeZ','of','ficeZ']:
 entry={'text':text}
 for enabled in [False,True]:
  entry['kern'+str(int(enabled))]=json.loads(subprocess.check_output(['hb-shape',str(font),text,'--no-glyph-names','--output-format=json',f'--features=liga=0,kern={int(enabled)}'],text=True))
 assert entry['kern0']==entry['kern1']
 equivalence.append(entry)
result=dict(kerningEquivalence=equivalence,version=subprocess.check_output(['hb-shape','--version'],text=True).splitlines()[0],font='../Typography/DejaVuSans.ttf',cases=cases)
(root/'harfbuzz-controls.json').write_text(json.dumps(result,indent=2)+'\n')
