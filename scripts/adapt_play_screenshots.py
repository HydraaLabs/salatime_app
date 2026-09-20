#!/usr/bin/env python3
"""Adapt existing Play artwork using complete, authentic device captures.

No generated artwork or text: headers/footers are retained as raster originals.
The old Android device area is cleared and a native app capture is placed intact
at its original aspect ratio. The caller must visually review every output.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZES = {'iphone': (1320, 2868), 'ipad': (2064, 2752),
         'android7': (1080, 1920), 'android10': (1440, 2560)}
NATIVE_SIZES = {**SIZES, 'android7': (1200, 1920), 'android10': (1600, 2560)}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def remove_old_device(image: Image.Image, position: int) -> Image.Image:
    """Fill only the old device/shadow rectangle from its background edges."""
    w, h = image.size
    if position == 1:
        box = (.095, .444, .671, 1.0)
    elif position == 2:
        box = (.249, .446, .828, 1.0)
    else:
        box = (.065, .193, .935, .955)
    x1, y1, x2, y2 = [round(v * (w if n % 2 == 0 else h)) for n, v in enumerate(box)]
    pixels = np.array(image.convert('RGB'), dtype=np.float32)
    left = np.median(pixels[y1:y2, max(0, x1 - 8):x1], axis=1)
    right = np.median(pixels[y1:y2, x2:min(w, x2 + 8)], axis=1)
    t = np.linspace(0, 1, x2 - x1)[None, :, None]
    pixels[y1:y2, x1:x2] = left[:, None] * (1 - t) + right[:, None] * t
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), 'RGB')


def background(source: Image.Image, position: int, family: str) -> Image.Image:
    tw, th = SIZES[family]
    clean = remove_old_device(source, position)
    # Uniform scale preserves typography, decorative shapes and logo proportions.
    scaled_h = round(source.height * tw / source.width)
    scaled = clean.resize((tw, scaled_h), Image.Resampling.LANCZOS)
    canvas = Image.new('RGB', (tw, th))
    canvas.paste(scaled, (0, 0))
    if scaled_h < th:
        canvas.paste(scaled.crop((0, scaled_h - 1, tw, scaled_h)).resize((tw, th - scaled_h)), (0, scaled_h))
    if position >= 3:
        # Reposition the original footer on the shorter iPad marketing canvas.
        footer = source.crop((0, round(source.height * .957), source.width, source.height))
        footer = footer.resize((tw, round(footer.height * tw / source.width)), Image.Resampling.LANCZOS)
        canvas.paste(footer, (0, th - footer.height))
    return canvas


def compose(source_path: Path, capture_path: Path, output: Path, family: str, position: int) -> dict:
    with Image.open(source_path) as im:
        source = im.convert('RGB')
    with Image.open(capture_path) as im:
        capture = im.convert('RGB')
    assert capture.size == NATIVE_SIZES[family], f'Wrong native capture dimensions: {capture_path}: {capture.size}'
    canvas = background(source, position, family)
    if family.startswith('android'):
        w, h = canvas.size
        outer_w = round(w * (.59 if position <= 2 else .79))
        x = (w - outer_w) // 2
        y = round(h * (.448 if position <= 2 else .205))
        border = round(w * .014)
    elif family == 'iphone':
        x, y, outer_w, border = ((110 if position == 1 else 300), 1000, 860, 18) if position <= 2 else (125, 470, 1070, 18)
    else:
        x, y, outer_w, border = ((175 if position == 1 else 515), 1110, 1220, 22) if position <= 2 else (310, 640, 1444, 22)
    inner_w = outer_w - border * 2
    inner_h = round(capture.height * inner_w / capture.width)
    outer_h = inner_h + border * 2
    assert x >= 0 and y >= 0 and x + outer_w <= canvas.width and y + outer_h <= canvas.height
    radius = 64 if family == 'iphone' else 48
    shadow = Image.new('RGBA', canvas.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x - 5, y + 10, x + outer_w + 5, y + outer_h + 16), radius=radius, fill=(0, 0, 0, 75))
    canvas = Image.alpha_composite(canvas.convert('RGBA'), shadow.filter(ImageFilter.GaussianBlur(16)))
    device = Image.new('RGBA', (outer_w, outer_h))
    draw = ImageDraw.Draw(device)
    draw.rounded_rectangle((0, 0, outer_w - 1, outer_h - 1), radius=radius, fill=(24, 28, 27), outline=(99, 111, 105), width=3)
    screen = capture.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
    mask = Image.new('L', screen.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, inner_w - 1, inner_h - 1), radius=max(1, radius - border), fill=255)
    device.paste(screen, (border, border), mask)
    canvas.alpha_composite(device, (x, y))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert('RGB').save(output, optimize=True)
    return {
        'position': position, 'family': family, 'path': str(output.resolve()),
        'sha256': digest(output), 'dimensions': list(canvas.size),
        'source_artwork': str(source_path.resolve()), 'source_artwork_sha256': digest(source_path),
        'native_capture': str(capture_path.resolve()), 'native_capture_sha256': digest(capture_path),
        'capture_size': list(capture.size), 'screen_box': [x + border, y + border, inner_w, inner_h],
        'method': 'Deterministic Pillow composition; original text/artwork; complete native screenshot at original aspect ratio; no AI',
        'visually_approved': False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--family', choices=SIZES, required=True)
    parser.add_argument('--position', type=int, choices=range(1, 8), required=True)
    args = parser.parse_args()
    print(json.dumps(compose(args.source, args.capture, args.output, args.family, args.position), indent=2))


if __name__ == '__main__':
    main()
