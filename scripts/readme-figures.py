#!/usr/bin/env python3
# Copyright 2026 Christophe Jorssen; LPPL-1.3c-or-later.
"""Capture existing inline manual figures; never generate replacement examples.

Requires Poppler (pdftotext, pdftoppm) and Pillow for this maintainer task only.
The output PNGs are for GitHub and are excluded from the CTAN archive.
"""
from pathlib import Path
import hashlib
import json
import subprocess
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / 'build/manual/luapourbaix-manual.pdf'
WORK = ROOT / 'build/readme'
OUT = ROOT / 'doc/images'
WORK.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
text = subprocess.check_output(['pdftotext', '-layout', str(PDF), '-'], text=True)
pages = [' '.join(page.split()) for page in text.split('\f')]
figures = {
    'iron-water': 'Maxime chooses',
    'iodine-conventions': 'both choices side by side, without changing',
    'uranium-palettes': 'This is precisely her third solubility product',
}
provenance = {'manual_sha256': hashlib.sha256(PDF.read_bytes()).hexdigest(), 'figures': {}}
for name, anchor in figures.items():
    matches = [i+1 for i, page in enumerate(pages) if anchor in page]
    if len(matches) != 1:
        raise RuntimeError(f'Review manual anchor for {name}: {matches}')
    page = matches[0]
    target = WORK / name
    subprocess.run(['pdftoppm', '-f', str(page), '-l', str(page), '-r', '180',
                    '-singlefile', '-png', str(PDF), str(target)], check=True)
    with Image.open(target.with_suffix('.png')) as im:
        im = im.convert('RGB')
        # PGF manual codeexample result boxes have a pale yellow background.
        # Reject missing/fragmented boxes rather than capturing source listings.
        red, green, blue = im.split()
        mask = ImageChops.multiply(ImageChops.multiply(red.point(lambda x: 255 if x > 235 else 0),
                                            green.point(lambda x: 255 if x > 235 else 0)),
                              blue.point(lambda x: 255 if 160 < x < 225 else 0))
        box = mask.getbbox()
        if box is None or box[2]-box[0] < 500 or box[3]-box[1] < 250:
            raise RuntimeError(f'Review figure box for {name}')
        im.crop(box).save(OUT / (name+'.png'), optimize=True)
        provenance['figures'][name] = {'page': page, 'crop_pixels_at_180dpi': box}
(OUT / 'captures.json').write_text(json.dumps(provenance, indent=2)+'\n')
print('Captured three manual figures; visually review doc/images/*.png')
