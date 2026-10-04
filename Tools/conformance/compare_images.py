#!/usr/bin/env python3
"""Compare a candidate PNG with a pinned independent reference.

The threshold is a test policy, not a claim of perceptual equivalence. Missing
images and size mismatches are failures; no automatic golden regeneration.
"""
import argparse, json
from PIL import Image, ImageChops

def compare(reference, candidate, channel_tolerance=16, fraction_tolerance=0.005):
    a, b = Image.open(reference).convert('RGBA'), Image.open(candidate).convert('RGBA')
    if a.size != b.size:
        return {'passed':False,'reason':'size mismatch','reference':a.size,'candidate':b.size}
    a = Image.alpha_composite(Image.new('RGBA', a.size, 'white'), a).convert('RGB')
    b = Image.alpha_composite(Image.new('RGBA', b.size, 'white'), b).convert('RGB')
    differences = list(ImageChops.difference(a,b).getdata())
    bad = sum(max(pixel) > channel_tolerance for pixel in differences)
    fraction = bad / len(differences)
    return {'passed':fraction <= fraction_tolerance, 'differingPixelFraction':fraction,
            'channelTolerance':channel_tolerance, 'fractionTolerance':fraction_tolerance}

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference');p.add_argument('candidate')
    p.add_argument('--channel-tolerance',type=int,default=16)
    p.add_argument('--fraction-tolerance',type=float,default=.005)
    a=p.parse_args()
    result=compare(a.reference,a.candidate,a.channel_tolerance,a.fraction_tolerance)
    print(json.dumps(result,indent=2));raise SystemExit(not result['passed'])
