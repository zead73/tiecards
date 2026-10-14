#!/usr/bin/env python3
"""Ages the cream hearts and diamonds in assets/cards/ so they look like old
ivory: soft tea-coloured stains, yellowed edges and corners, a mottled tone, a
few foxing specks and a fine paper grain. The cream itself is kept; this only
lays a gentle tint over the paper. Symbols, corner numbers and the vampire
portraits stay crisp (only paper-coloured pixels are touched).

Run after make_courts.py (see make-art.sh). Every card gets its own stains, but
the same ones every time (seeded by its name), so rebuilds are identical.
Needs: numpy, PIL.   Usage: age_cards.py [--preview OUT.png]
"""
import glob, os, sys, zlib
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from recolor_cards import CREAM

CARDS = os.path.join(HERE, "..", "assets", "cards")
SUITS = ("hearts", "diamonds")
PANEL = (60, 82, 268, 384)            # the court portraits' panel (x0, y0, x1, y1): left alone
TEA = np.array((196, 156, 98), np.float32)       # stain colour
EDGE = np.array((206, 172, 112), np.float32)     # the yellowed edge
FOX = np.array((150, 100, 52), np.float32)       # foxing specks


def blur(a, r):
    im = Image.fromarray(np.clip(a * 255 + 128, 0, 255).astype(np.uint8))
    return (np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) - 128) / 255


def smooth_noise(rng, shape, r):
    n = blur(rng.uniform(-1, 1, shape).astype(np.float32), r)
    return n / (np.abs(n).max() + 1e-6)          # -1..1


def age(img, name, has_panel):
    a = np.asarray(img.convert("RGBA"), np.float32)
    H, W = a.shape[:2]
    rng = np.random.RandomState(zlib.crc32(name.encode()) & 0x7fffffff)
    rgb = a[..., :3]
    # which pixels are paper: close to the cream colour (soft, so edges blend)
    dist = np.sqrt(((rgb - np.array(CREAM, np.float32)) ** 2).sum(axis=2))
    paper = np.clip(1.4 - dist / 45.0, 0, 1) * (a[..., 3] / 255.0)
    if has_panel:
        x0, y0, x1, y1 = PANEL
        paper[y0:y1, x0:x1] = 0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    # the edges and corners go a little yellow-brown
    d = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy))
    edge = np.clip(1 - d / 46.0, 0, 1) ** 1.8
    edge *= 0.55 + 0.45 * (smooth_noise(rng, (H, W), 14) * 0.5 + 0.5)      # uneven
    cx = np.minimum(xx, W - 1 - xx) / 46.0
    cy = np.minimum(yy, H - 1 - yy) / 46.0
    corner = np.clip(1 - np.sqrt(cx ** 2 + cy ** 2), 0, 1) ** 1.5
    A_edge = np.clip(0.30 * edge + 0.22 * corner, 0, 0.5)

    # a mottled tone across the whole card
    mott = smooth_noise(rng, (H, W), 22)
    A_mott = np.clip(0.07 + 0.10 * mott, 0, 0.2)

    # two or three tea stains: a soft fill with a darker rim
    A_stain = np.zeros((H, W), np.float32)
    for _ in range(int(rng.randint(2, 4))):
        sx, sy = rng.uniform(0.1, 0.9) * W, rng.uniform(0.1, 0.9) * H
        R = rng.uniform(26, 62)
        wob = 1 + 0.18 * smooth_noise(rng, (H, W), 9)            # an uneven outline
        r = np.sqrt((xx - sx) ** 2 + (yy - sy) ** 2) / wob
        fill = np.exp(-(r / R) ** 2 * 1.6) * rng.uniform(0.10, 0.18)
        rim = np.exp(-((r - R * 0.85) / (R * 0.12)) ** 2) * rng.uniform(0.10, 0.20)
        A_stain = np.maximum(A_stain, fill + rim * (r < R * 1.1))

    # foxing: a few tiny brown specks
    A_fox = np.zeros((H, W), np.float32)
    for _ in range(int(rng.randint(14, 30))):
        fx, fy = int(rng.uniform(8, W - 8)), int(rng.uniform(8, H - 8))
        A_fox[max(0, fy - 1):fy + 2, max(0, fx - 1):fx + 2] = rng.uniform(0.25, 0.55)
    A_fox = np.asarray(Image.fromarray((A_fox * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9)),
                       np.float32) / 255 * 1.3

    A_tea = np.clip(np.maximum(A_stain, A_mott), 0, 0.4)
    out = rgb.copy()
    for A, col in ((A_tea, TEA), (A_edge, EDGE), (np.clip(A_fox, 0, 0.6), FOX)):
        w = (A * paper)[..., None]
        out = out * (1 - w) + col * w
    # a fine grain, and a faint fibre streak
    grain = rng.normal(0, 1, (H, W)).astype(np.float32)
    grain = grain * 0.5 + blur(grain, 1.2) * 1.5
    out *= (1 + 0.012 * grain * paper)[..., None]
    res = np.dstack([np.clip(out, 0, 255), a[..., 3]]).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    tiles = []
    n = 0
    for suit in SUITS:
        for path in sorted(glob.glob(os.path.join(CARDS, "card_%s_*.png" % suit))):
            name = os.path.basename(path)
            rank = int(name.split("_")[2].split(".")[0])
            img = Image.open(path)
            out = age(img, name, has_panel=rank >= 11)
            out.save(path)
            n += 1
            if preview and name in ("card_hearts_07.png", "card_diamonds_09.png", "card_hearts_13.png", "card_hearts_01.png"):
                tiles.append(out.resize((164, 232), Image.LANCZOS))
    print("aged %d cards" % n)
    if preview and tiles:
        sheet = Image.new("RGB", (len(tiles) * 174 + 10, 252), (20, 70, 40))
        for i, t in enumerate(tiles):
            sheet.paste(t, (10 + i * 174, 10), t)
        sheet.save(preview)


if __name__ == "__main__":
    sys.exit(main())
