"""Deterministic synthetic PNGs for the documented supplied-image workflow."""
from pathlib import Path
import random, struct, zlib
names = 'title-hero div-botany anatomy fibonacci div-numbers div-ecology pollinator phytoremediation div-culture records div-grow harvest closing'.split()
out = Path(__file__).resolve().parent / 'sunflower-images'
out.mkdir(exist_ok=True)
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
for index, name in enumerate(names):
    width, height = (960, 540) if name.startswith('div-') or name in ['title-hero','closing'] else (640, 640)
    rng = random.Random(index)
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            noise = rng.randrange(32)
            raw.extend(((x * 255 // width + noise) % 256, (y * 255 // height + noise) % 256, (index * 19 + noise) % 256))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB',width,height,8,2,0,0,0)) + chunk(b'IDAT',zlib.compress(raw)) + chunk(b'IEND',b'')
    (out / (name + '.png')).write_bytes(png)
print(f'{len(names)} synthetic images; no model calls or credentials')
